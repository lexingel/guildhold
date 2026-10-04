extends "res://scripts/autoload/game_state/GameStateCore.gd"
## GameState, part 1b: the Unwritten Accord (GameData.FRAGMENTS, TRUTHS,
## WITNESSES). What the player has found lives in the legacy, so it carries
## from guild to guild: legacy.fragments, legacy.truths, legacy.claims, and
## legacy.hesper_posted. The branches a guild took are in `branches`.


func _lore_list(key: String) -> Array:
	if legacy.is_empty():
		load_legacy()
	if not legacy.has(key):
		legacy[key] = []
	return legacy[key]


func fragment_known(id: String) -> bool:
	return _lore_list("fragments").has(id)


func truth_known(id: String) -> bool:
	return _lore_list("truths").has(id)


func claim_heard(id: String) -> bool:
	return _lore_list("claims").has(id)


## Hesper took the forty-first post (branch B5) and no guild has brought her
## home yet: she is gone from the pay table.
func hesper_posted() -> bool:
	if legacy.is_empty():
		load_legacy()
	return bool(legacy.get("hesper_posted", false))


## `text`, or its GameData.HESPER_POSTED_ALT version while Hesper holds the post.
func hesper_alt(key: String, text: String) -> String:
	return str(GameData.HESPER_POSTED_ALT[key]) if hesper_posted() and GameData.HESPER_POSTED_ALT.has(key) else text


## Whether fragment `f` can turn up now. `ctx`: the sealed rift's
## {"region", "rank"} for seal-found fragments.
func lore_gate(f: Dictionary, ctx: Dictionary = {}) -> bool:
	var g: Dictionary = f.get("gate", {})
	if g.has("region") and str(ctx.get("region", "")) != str(g["region"]):
		return false
	if g.has("rank_min") and int(ctx.get("rank", -1)) < GameData.rift_rank_index(str(g["rank_min"])):
		return false
	if g.has("truth") and not truth_known(str(g["truth"])):
		return false
	if g.has("rival") and rival_name != str(g["rival"]):
		return false
	if g.has("charter") and founding != str(g["charter"]):
		return false
	if g.has("branch"):
		var b := str(g["branch"]).split(":")
		if str(branches.get(b[0], "")) != b[1]:
			return false
	if g.has("pages") and accord_pages < int(g["pages"]):
		return false
	if g.has("hall") and not _hall_has(str(g["hall"])):
		return false
	if hesper_posted() and (f.get("lines", []) as Array).any(func(l): return str(l[0]) == "Hesper"):
		return false   # she isn't at the pay table
	return true


## A guild in the Hall of Guilds did `what`.
func _hall_has(what: String) -> bool:
	var hall: Array = legacy.get("guilds", [])
	match what:
		"spared_vaelith":
			return hall.any(func(g): return str((g.get("branches", {}) as Dictionary).get("vaelith", "")) == "spared")
	return false


## Fragments not yet found that could turn up through `channel` (at event `on`).
func _lore_open(channel: String, on: String = "", ctx: Dictionary = {}) -> Array:
	var out: Array = []
	for id in GameData.FRAGMENTS:
		var f: Dictionary = GameData.FRAGMENTS[id]
		if str(f["channel"]) != channel or fragment_known(id) or (on != "" and str(f.get("on", "")) != on):
			continue
		if lore_gate(f, ctx):
			out.append(id)
	return out


## Finds fragment `id`: kept in the legacy, a toast, its witness claim, and
## any truth it completes. Returns its text (a payday scene's lines joined).
func find_fragment(id: String) -> String:
	var f: Dictionary = GameData.FRAGMENTS.get(id, {})
	if f.is_empty() or fragment_known(id):
		return ""
	_lore_list("fragments").append(id)
	lore_found_here.append(id)
	if f.has("claim"):
		hear_claim(str(f["claim"]))
	pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("A fragment: %s") % tr(str(f["title"])),
		"text": tr("Kept in Library > Codex > Truths, for this guild and every guild after it.")})
	_check_truths()
	save_legacy()
	return fragment_text(id)


## A fragment's words: its text, or its pay-table lines.
static func fragment_text(id: String) -> String:
	var f: Dictionary = GameData.FRAGMENTS.get(id, {})
	if f.has("text"):
		return str(f["text"])
	return " ".join((f.get("lines", []) as Array).map(func(l): return "%s: %s" % [str(l[0]), str(l[1])]))


## Any TRUTH_NEEDS of a truth's fragments make it known.
func _check_truths() -> void:
	for t in GameData.TRUTHS:
		if truth_known(t):
			continue
		var have := 0
		for id in GameData.FRAGMENTS:
			if str(GameData.FRAGMENTS[id]["truth"]) == t and fragment_known(id):
				have += 1
		if have >= GameData.TRUTH_NEEDS:
			_lore_list("truths").append(t)
			var opens := str(GameData.TRUTHS[t].get("opens", ""))
			pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("A truth"),
				"text": tr(str(GameData.TRUTHS[t]["text"])) + ("" if opens == "" else " " + tr(opens))})
			_news(tr("A truth: %s") % tr(str(GameData.TRUTHS[t]["text"])))


func hear_claim(id: String) -> void:
	if id != "" and not claim_heard(id):
		_lore_list("claims").append(id)
		save_legacy()


## A claim's standing: "unheard", "open", or its verdict once its truth is known.
func claim_status(c: Dictionary) -> String:
	if not claim_heard(str(c["id"])):
		return "unheard"
	return str(c["verdict"]) if truth_known(str(c.get("truth", ""))) else "open"


## An event that can carry a fragment (echo, finale, crossing, line, hall,
## ending). Returns the found fragment's text to add to the event's card, or "".
func lore_event(channel: String, on: String) -> String:
	var open := _lore_open(channel, on)
	return find_fragment(str(open[0])) if not open.is_empty() else ""


## The ledger's claims, heard as its pages are found.
func hear_ledger_claims() -> void:
	for id in GameData.CLAIM_PAGES:
		if accord_pages >= int(GameData.CLAIM_PAGES[id]):
			hear_claim(id)


## A sealed rift may turn up a fragment (relic-, seal- or ledger-found);
## `region` and `rank` (a rift rank index) are the rift's. Returns the
## fragment's id, or "".
func lore_on_seal(region: String, rank: int) -> String:
	var ctx := {"region": region, "rank": rank}
	var open: Array = _lore_open("relic", "", ctx) + _lore_open("seal", "", ctx) + _lore_open("ledger", "", ctx)
	if open.is_empty():
		return ""
	if lore_dry < GameData.LORE_PITY and randf() >= GameData.LORE_SEAL_CHANCE:
		lore_dry += 1
		return ""
	lore_dry = 0
	var id := str(open[randi() % open.size()])
	var f: Dictionary = GameData.FRAGMENTS[id]
	if str(f["channel"]) == "relic":   # the fragment rides on a relic
		var r := Combat.gen_relic("common")
		r.id = "rl" + str(next_id)
		next_id += 1
		r.name = str(f["relic"])
		r.lore = id
		relics.append(r)
	find_fragment(id)
	return id


## A pay-table scene from the story web, or "": a fragment's lines
## ("lore:<id>"), Hesper's last claim ("claim:hesper_unread"), or while
## Hesper holds the post, the guild missing her ("hesper_posted").
func lore_payday_scene(last: String) -> String:
	if last.begins_with("lore") or last.begins_with("claim") or last == "hesper_posted":
		return ""
	var open := _lore_open("payday")
	if not open.is_empty() and randf() < GameData.LORE_PAYDAY_CHANCE:
		var id := str(open[randi() % open.size()])
		find_fragment(id)
		return "lore:" + id
	if not hesper_posted() and accord_pages >= 3 and not claim_heard("hesper_unread") and randf() < GameData.LORE_PAYDAY_CHANCE:
		hear_claim("hesper_unread")
		return "claim:hesper_unread"
	if hesper_posted() and randf() < 0.25:
		return "hesper_posted"
	return ""


## A scene's [[speaker, line], ...] (GameData.PAYDAY_SCENES, or the story
## web's); Hesper's lines drop out while she holds the post.
func payday_scene_lines(scene: String) -> Array:
	var lines: Array = []
	if scene.begins_with("lore:"):
		lines = GameData.FRAGMENTS.get(scene.trim_prefix("lore:"), {}).get("lines", [])
	elif scene == "claim:hesper_unread":
		lines = GameData.HESPER_UNREAD_SCENE
	elif scene == "hesper_posted":
		lines = GameData.HESPER_POSTED_SCENE
	else:
		lines = GameData.PAYDAY_SCENES.get(scene, [])
	if hesper_posted():
		lines = lines.filter(func(l): return str(l[0]) != "Hesper")
	return lines


## The postscript to the rival's weekly letter: Orla Venn's claims in order,
## or a letter-found fragment. "" for none.
func lore_letter_ps() -> String:
	var seq: Array = GameData.RIVAL_CLAIM_LETTERS.get(rival_name, [])
	for entry in seq:
		if claim_heard(str(entry[0])):
			continue
		if str(entry[1]) == "":   # this claim rides on its fragment
			var fr: Array = _lore_open("letter").filter(func(id): return str(GameData.FRAGMENTS[id].get("claim", "")) == str(entry[0]))
			return find_fragment(str(fr[0])) if not fr.is_empty() else ""
		hear_claim(str(entry[0]))
		return str(entry[1])
	var open := _lore_open("letter")
	return find_fragment(str(open[0])) if not open.is_empty() else ""
