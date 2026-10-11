class_name CodexView
extends RecordsView
## The Codex: the bestiary, the compendium (Paths, items, relics, crafting,
## systems), the Hall of Guilds and the Chronicle. Split out of GuildViews.gd
## in 0.69.2; calls only down the chain.


## Pure checklist, no reward tied to completion — three sections (Monsters,
## Bosses, Hazards) each grayed-out/silhouetted until GameState's matching
## _seen/_defeated array records it, full color once encountered. Reuses
## existing art everywhere (monster sprites, HAZARD_BG illustrations) — no
## new generation beyond the one hub icon.
const MONSTER_ABILITY_DESC := {
	"poison": "poisons its target for a few rounds",
	"healer": "heals its allies each round",
	"shielded": "starts the fight behind a ward",
	"frenzy": "hits harder when badly hurt",
	"drain": "heals itself from the damage it deals",
	"reflect": "reflects part of the damage it takes",
}


## A card per creature: art and what it does once you've met it, a dark
## silhouette and "???" until then.
func _render_bestiary(v: VBoxContainer) -> void:
	v.add_child(_label("Bestiary", 20))
	var groups := [
		["Monsters", GameData.MONSTER_NAMES, "Monster"],
		["Elites", GameData.ELITE_NAMES, "Elite"],
		["Rift Wardens", GameData.BOSS_NAMES, "Boss"],
	]
	for g in groups:
		var names: Array = g[1]
		var seen_n: int = names.filter(func(n): return GameState.bestiary_seen(n)).size()
		v.add_child(_label(tr("%s — %d/%d met") % [tr(str(g[0])), seen_n, names.size()], 15))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		for mname in names:
			flow.add_child(_bestiary_card(str(mname), str(g[2])))
		v.add_child(flow)
		v.add_child(_hsep())

	v.add_child(_label(tr("Hazards — %d/%d met") % [GameData.HAZARD_TYPES.filter(func(h): return GameState.hazards_seen.has(str(h["id"]))).size(), GameData.HAZARD_TYPES.size()], 15))
	var hflow := HFlowContainer.new()
	hflow.add_theme_constant_override("h_separation", 8)
	hflow.add_theme_constant_override("v_separation", 8)
	for hz in GameData.HAZARD_TYPES:
		var seen: bool = GameState.hazards_seen.has(str(hz["id"]))
		var card := PanelContainer.new()
		card.custom_minimum_size.x = 180
		var cv := _vbox(4)
		var art := _banner(GameData.HAZARD_BG.get(str(hz["id"]), ""), 156, 70)
		if not seen:
			art.modulate = Color(0.2, 0.2, 0.25)
		cv.add_child(art)
		cv.add_child(_label(str(hz["name"]) if seen else "???", 13))
		if seen:
			var mult := float(hz["dmg_mult"])
			var sev := _label(tr("%s · finds %s") % [tr(str(_hazard_severity_label(mult))), tr(str(tr("Gold") if str(hz["bonus_type"]) == "coins" else tr("Essence")))], 12)
			sev.add_theme_color_override("font_color", _hazard_severity_color(mult))
			cv.add_child(sev)
		card.add_child(cv)
		hflow.add_child(card)
	v.add_child(hflow)


func _bestiary_card(mname: String, tier: String) -> PanelContainer:
	var seen: bool = GameState.bestiary_seen(mname)   # this guild, or any before it
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 0)
	var cv := _vbox(3)
	var art := _sprite_fit(GameData.sprite_for_monster(mname), 90.0 / 200.0, 156.0)
	if not seen:
		art.modulate = Color(0.08, 0.07, 0.12)
	var art_row := CenterContainer.new()
	art_row.custom_minimum_size.y = 94
	art_row.add_child(art)
	cv.add_child(art_row)
	var nl := _label(mname if seen else "???", 13)
	cv.add_child(nl)
	if seen and not GameState.monsters_seen.has(mname):
		cv.add_child(_label("Met by a past guild", 11, true))
	var tl := _label(tier, 12, true)
	tl.add_theme_color_override("font_color", Palette.ELITE if tier != "Monster" else Palette.MUTED)
	cv.add_child(tl)
	if seen:
		var ability: Dictionary = GameData.MONSTER_ABILITIES.get(mname, {})
		if not ability.is_empty():
			cv.add_child(_wrap_label("%s — %s" % [tr(str(ability["name"])), tr(str(MONSTER_ABILITY_DESC.get(str(ability["kind"]), "")))], 12, true))
		var kit: Array = Combat.monster_kit({"name": mname, "tier": {"Monster": "combat", "Elite": "elite", "Boss": "boss"}.get(tier, "combat"), "ability": ability})
		if not kit.is_empty():
			cv.add_child(_wrap_label(tr("Telegraphs: %s") % tr(str(", ".join(kit.map(func(k): return str(GameData.INTENT_INFO[k]["name"]))))), 12, true))
		elif tier == "Boss":
			var beaten: bool = GameState.bosses_defeated.has(mname) or (GameState.legacy.get("beaten", []) as Array).has(mname)
			cv.add_child(_wrap_label(tr("Brings a random warden mechanic each fight. %s") % tr(str((tr("Defeated.") if beaten else tr("Not yet defeated.")))), 12, true))
	card.add_child(cv)
	return card


## Codex › Paths (0.62): every Path of a role with its moves, and every
## subclass (open, or what unlocks its training). Twists on hover.
func _render_compendium_paths(v: VBoxContainer) -> void:
	v.add_child(_wrap_label("Heroes are hired as base classes and train into a Path at the Training Yard: stage 1 at Rank D, stage 2 at Rank B, stage 3 at Rank S. Each subclass is a stage of one Path with its own Twist. Unlocked subclasses are remembered; a new guild can carry them over with Laurels.", 12, true))
	var role_row := HBoxContainer.new()
	role_row.add_theme_constant_override("separation", 6)
	for role in GameData.ROLE_KIND:
		var rb := _button(tr(str(role).capitalize()), func(r=str(role)): _codex_role = r; render())
		rb.toggle_mode = true
		rb.button_pressed = _codex_role == role
		role_row.add_child(rb)
	v.add_child(role_row)
	var known := 0
	for sid in GameData.SUBCLASS_UNLOCK:
		if GameState.subclass_unlocked(str(sid)):
			known += 1
	v.add_child(_label(tr("%d of %d subclasses unlocked") % [known, GameData.SUBCLASS_UNLOCK.size()], 12, true))
	for pid in GameData.role_paths(_codex_role):
		var p: Dictionary = GameData.PATHS[pid]
		var card := PanelContainer.new()
		card.theme_type_variation = &"CardPanel"
		var col := _vbox(3)
		var nm := _label(tr("%s — %s") % [tr(str(p["name"])), tr(str(p["blurb"]))], 15)
		nm.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
		col.add_child(nm)
		for ln in [["Rule", p["rule"], 1], ["Technique", p["technique"], 2], ["Signature", p["signature"], 3]]:
			col.add_child(_wrap_label(tr("Stage %d · %s, %s: %s") % [int(ln[2]), tr(str(ln[0])), tr(str(ln[1]["name"])), _cap(tr(str(ln[1]["desc"])))], 11))
		col.add_child(_wrap_label(tr("Legend (%s): %s") % [tr(str(GameData.find_class(str(GameData.LEGENDS[_codex_role]))["name"])), _cap(tr(str(p["legend"])))], 11, true))
		var subs := HFlowContainer.new()
		subs.add_theme_constant_override("h_separation", 6)
		subs.add_theme_constant_override("v_separation", 4)
		for st in 3:
			for sid in p["stages"][st]:
				var open := GameState.subclass_unlocked(str(sid))
				var chip := _label(tr("%s %s") % [tr(str(GameData.find_class(str(sid))["name"])), "I".repeat(st + 1)] + ("" if open else tr(" (locked)")), 11, not open)
				chip.tooltip_text = tr("Twist: %s") % tr(str(GameData.SUBCLASS_TWIST.get(sid, "")))
				if not open:
					chip.tooltip_text += "\n" + tr("Unlock: %s") % GameState.subclass_unlock_text(str(sid))
				chip.mouse_filter = Control.MOUSE_FILTER_STOP
				subs.add_child(chip)
		col.add_child(subs)
		card.add_child(col)
		v.add_child(card)


func _compendium_tab_row(v: VBoxContainer) -> void:
	var row := HFlowContainer.new()   # wraps on the phone canvas
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	for entry in [["chronicle", "Chronicle"], ["truths", "Truths"], ["accounts", "Accounts"], ["paths", "Paths"], ["items", "Items"], ["relics", "Relics"], ["crafting", "Crafting"], ["systems", "Systems"]]:
		var tid: String = entry[0]
		var tlabel: String = entry[1]
		var btn := _icon_button("", tlabel, func(id=tid):
			compendium_tab = id
			render()
		)
		btn.disabled = compendium_tab == tid
		row.add_child(btn)
	v.add_child(row)
	v.add_child(_hsep())


func _render_compendium(v: VBoxContainer) -> void:
	v.add_child(_label("Compendium", 20))
	_compendium_tab_row(v)
	match compendium_tab:
		"chronicle": _render_chronicle(v)
		"truths": _render_truths(v)
		"accounts": _render_accounts(v)
		"items": _render_compendium_items(v)
		"relics": _render_compendium_relics(v)
		"crafting": _render_compendium_crafting(v)
		"paths": _render_compendium_paths(v)
		_: _render_compendium_systems(v)


## The Broken Accord as far as the guild knows it: the world everyone knows,
## what each sealed finale revealed, the Grandmaster's ledger pages found in
## rifts, and what the freed champions remember.
## Past guilds (GameState.legacy): crest, name, how they ended, what they left.
func _render_hall_of_guilds(v: VBoxContainer) -> void:
	var hall: Array = GameState.legacy.get("guilds", [])
	if hall.is_empty():
		return
	v.add_child(_label(tr("Hall of Guilds · %d Laurels") % int(GameState.legacy.get("laurels", 0)), 16))
	var recs: Array[String] = []   # the Hall's records
	var most_l: Dictionary = hall[0]
	var most_o: Dictionary = hall[0]
	var best_t: Dictionary = hall[0]
	for g in hall:
		if int(g.get("laurels", 0)) > int(most_l.get("laurels", 0)):
			most_l = g
		if (g.get("oaths", []) as Array).size() > (most_o.get("oaths", []) as Array).size():
			most_o = g
		if int(g.get("best_tide", 0)) > int(best_t.get("best_tide", 0)):
			best_t = g
	recs.append(tr("most Laurels: %d, %s") % [int(most_l.get("laurels", 0)), str(most_l["name"])])
	if not (most_o.get("oaths", []) as Array).is_empty():
		recs.append(tr("most oaths kept: %d, %s") % [(most_o["oaths"] as Array).size(), str(most_o["name"])])
	if int(best_t.get("best_tide", 0)) > 0:
		recs.append(tr("most tides held: %d, %s") % [int(best_t["best_tide"]), str(best_t["name"])])
	v.add_child(_wrap_label(tr("Records — %s") % "; ".join(recs), 12, true))
	for g in hall:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var crest := int(g.get("crest", 1))
		row.add_child(_icon(GameData.CREST_PATH[clampi(crest - 1, 0, GameData.CREST_PATH.size() - 1)], 32))
		var col := _vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_label(_past_guild_title(g), 14))
		col.add_child(_wrap_label(_past_guild_line(g), 12, true))
		row.add_child(col)
		v.add_child(row)
	v.add_child(_hsep())


## A past guild's name and founding charter (Hall of Guilds, camp banners).
func _past_guild_title(g: Dictionary) -> String:
	var fd := str(g.get("founding", "free"))
	return str(g["name"]) + ("" if fd == "free" else "  ·  " + tr(str(GameData.FOUNDINGS.get(fd, {}).get("name", ""))))


## A past guild's record: its ending, day, rifts, Laurels, who it left behind.
func _past_guild_line(g: Dictionary) -> String:
	var how := tr("Renewed the Accord") if str(g.get("ending", "")) == "renew" else tr("Broke the Accord") if str(g.get("ending", "")) == "break" else tr("Rewrote the Terms") if str(g.get("ending", "")) == "rewrite" else tr("Retired in Act %s") % tr(GameState._roman(maxi(1, int(g.get("act", 1)) - 1)))
	var names: Array = g.get("remembered", [])
	var kept: Array = g.get("oaths", [])
	var oath_txt := (tr(" · oaths kept: %d") % kept.size()) if not kept.is_empty() else ""
	oath_txt += {"both": tr(" · kept the doors open"), "ours": tr(" · closed the doors")}.get(str(g.get("sky", "")), "")
	oath_txt += {"read": tr(" · read the first page aloud"), "burn": tr(" · burned the first page")}.get(str(g.get("epilogue", "")), "")
	return tr("%s · day %d · %d rifts sealed · +%d Laurels%s") % [how, int(g.get("day", 0)), int(g.get("rifts", 0)), int(g.get("laurels", 0)),
		((tr(" · remembered: %s") % ", ".join(names)) if not names.is_empty() else "") + oath_txt]


## The Unwritten Accord: what the player has pieced together, across every
## guild. Known truths, the fragments behind them, and hints for the rest.
func _render_truths(v: VBoxContainer) -> void:
	var known: Array = GameState.legacy.get("truths", [])
	var found: Array = GameState.legacy.get("fragments", [])
	v.add_child(_label(tr("Truths · %d of %d known · %d fragments found") % [known.size(), GameData.TRUTHS.size(), found.size()], 16))
	v.add_child(_wrap_label("Fragments turn up in rifts, letters, relics and at the pay table, and they're kept for every guild after this one. Any two of a truth's fragments make it known. Some only turn up after a past guild did something.", 12, true))
	for arc in GameData.LORE_ARCS:
		v.add_child(_hsep())
		var head := _label(str(arc[1]), 15)
		head.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
		v.add_child(head)
		for t in GameData.TRUTHS:
			var td: Dictionary = GameData.TRUTHS[t]
			if str(td["arc"]) != str(arc[0]):
				continue
			var frags: Array = GameData.FRAGMENTS.keys().filter(func(id): return str(GameData.FRAGMENTS[id]["truth"]) == t and found.has(id))
			if known.has(t):
				v.add_child(_label("✓ " + tr(str(td["text"])), 14))
				if str(td.get("opens", "")) != "":
					v.add_child(_wrap_label(tr("Opens: %s") % tr(str(td["opens"])), 12))
			else:
				v.add_child(_label("○ ???", 14, true))
				v.add_child(_wrap_label(tr(str(td["hint"])) if not frags.is_empty() else tr("Nothing found yet."), 12, true))
			for id in frags:
				var fv := _vbox(0)
				fv.add_child(_label("    " + tr(str(GameData.FRAGMENTS[id]["title"])), 12))
				var ft := _wrap_label(GameState.fragment_text(str(id)), 11, true)
				fv.add_child(ft)
				v.add_child(fv)


## The witnesses: each one's version of the Night of Breaking, struck
## through or confirmed as truths come in.
func _render_accounts(v: VBoxContainer) -> void:
	v.add_child(_label("Accounts", 16))
	v.add_child(_wrap_label("Everyone tells the Night of Breaking their own way. What each witness has told you, across every guild. A truth you learn strikes a claim through, or confirms it.", 12, true))
	var unheard := 0
	for w in GameData.WITNESSES:
		var heard: Array = (w["claims"] as Array).filter(func(c): return GameState.claim_heard(str(c["id"])))
		if heard.is_empty():
			unheard += 1
			continue
		v.add_child(_hsep())
		var head := _label(str(w["name"]), 14)
		head.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
		v.add_child(head)
		for c in heard:
			var st := GameState.claim_status(c)
			var line := tr(str(c["text"]))
			match st:
				"struck":
					v.add_child(_rich_line("✗ [s]%s[/s]  [i]%s[/i]" % [line, tr("struck through")], 13))
				"confirmed":
					v.add_child(_rich_line("✓ %s  [i]%s[/i]" % [line, tr("confirmed")], 13))
				"half":
					v.add_child(_rich_line("≈ %s  [i]%s[/i]" % [line, tr("half true")], 13))
				_:
					v.add_child(_rich_line("? %s" % line, 13, true))
	if unheard > 0:
		v.add_child(_hsep())
		v.add_child(_label(tr("%d empty chair%s: witnesses you haven't heard yet") % [unheard, tr(str(_pl(unheard)))], 12, true))


func _render_chronicle(v: VBoxContainer) -> void:
	var watch := _button("Watch the opening", func(): call("_play_cinematic", false))
	watch.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(watch)
	_render_hall_of_guilds(v)
	if GameState.accord_ending != "":
		v.add_child(_label(tr("What this guild can still finish · +%d Laurels each") % GameData.BOARD_LAURELS, 16))
		for l in GameState.board_lines():
			var done := GameState.board_done(str(l["id"]))
			var ll := _label(("✓ " if done else "○ ") + tr(str(l["label"])), 13, not done)
			v.add_child(ll)
		if GameState.accord_ending == "break":
			v.add_child(_label(tr("Tides of the Open Hollow: %d held of %d") % [GameState.tides_held, GameState.tide_count], 12, true))
		v.add_child(_hsep())
	v.add_child(_label("The world", 16))
	for e in GameData.CHRONICLE_WORLD:
		v.add_child(_label(str(e[0]), 14))
		v.add_child(_wrap_label(str(e[1]), 12, true))

	v.add_child(_hsep())
	v.add_child(_label("The story so far", 16))
	for r in GameData.CHRONICLE_REVEALS:
		var act := int(r["act"])
		if GameState.campaign_act > act:
			var t := _label(str(r["title"]), 14)
			t.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
			v.add_child(t)
			v.add_child(_wrap_label(str(r["text"]), 13))
		else:
			v.add_child(_label(tr("??? — seal Act %s's finale") % tr(GameState._roman(act)), 13, true))
	if GameState.accord_ending != "":   # how the guild ended it (Act IV)
		var e: Array = GameData.CHRONICLE_ENDING[GameState.accord_ending]
		var et := _label(str(e[0]), 14)
		et.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
		v.add_child(et)
		var etext := tr(str(e[1]))
		v.add_child(_wrap_label(etext % tr(GameState.accord_hero) if etext.contains("%s") else etext, 13))
	else:
		v.add_child(_label(tr("??? — seal Act %s's finale") % tr(GameState._roman(4)), 13, true))

	var pages: Array = GameData.LEDGER_PAGES
	v.add_child(_hsep())
	v.add_child(_label(tr("The Grandmaster's ledger — %d/%d pages") % [GameState.accord_pages, pages.size()], 16))
	v.add_child(_wrap_label("Pages turn up in sealed rifts as the campaign goes on; a finale always yields one.", 11, true))
	for i in mini(GameState.accord_pages, pages.size()):
		v.add_child(_wrap_label(str(pages[i]["text"]), 13))
	var missing := pages.size() - GameState.accord_pages
	if missing > 0:
		v.add_child(_label(tr("%d page%s still missing") % [missing, tr(str(_pl(missing)))], 12, true))

	var freed: Array = GameState.champion_roll.filter(func(id): return GameState.champion_unlocked(str(id)))
	v.add_child(_hsep())
	v.add_child(_label(tr("What the champions remember — %d/%d freed") % [freed.size(), GameState.champion_roll.size()], 16))
	if freed.is_empty():
		v.add_child(_wrap_label("Each act's finale frees a champion of the old guilds; more wait in pillars of light in the Descent and Rank B+ rifts.", 12, true))
	for id in freed:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var pic := _icon_trimmed(GameData.champion_portrait(str(id)), 40)
		pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(pic)
		var col := _vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_label(GameData.champion_full_name(str(id)), 13))
		col.add_child(_wrap_label(tr(str(GameData.CHAMPION_MEMORY.get(str(id), ""))), 12, true))
		row.add_child(col)
		v.add_child(row)


func _render_compendium_items(v: VBoxContainer) -> void:
	v.add_child(_wrap_label("Items are hero-bound gear. Weapon items fill a hero's weapon slots (1, or 2 for a dual-wield class); Armor and Focus items share one \"gear\" slot pool that grows with hero rank. A Common rolls one stat, a Rare one bigger stat and a named effect, an Epic two stats and a stronger effect (some effects only come on Epics). Legendaries are unique.", 12, true))
	for category in GameData.ITEM_CATEGORIES:
		v.add_child(_hsep())
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.add_child(_icon(str(GameData.ITEM_CATEGORY_ICON_PATH.get(category, "")), 28))
		head.add_child(_label(str(GameData.ITEM_CATEGORY_LABEL.get(category, category)), 16))
		v.add_child(head)
		var stats: Array = GameData.ITEM_CATEGORY_KINDS.get(category, []).map(func(k): return tr(str(_KIND_LABEL.get(k, k))))
		v.add_child(_wrap_label(tr("Stats: %s") % ", ".join(stats), 13))
		for e in GameData.ITEM_EFFECTS.get(category, []):
			v.add_child(_rich_line("[b]%s[/b]%s — %s" % [tr(str(e["name"])), tr(" (Epic)") if e.get("epic", false) else "", tr(str(Combat.describe_effect(e)))], 12))


func _render_compendium_relics(v: VBoxContainer) -> void:
	v.add_child(_wrap_label("Relics bend a rule for the whole guild: each is one of a kind, found from Act I's finale on (finales, an elite's loot, a rift shop, events, the Tower). They sit on the Relic Altar (Inventory), 3 slots and more with the Relic Vault. Path relics are different: a hero of the relic's Path carries it, and it works while they fight.", 12, true))

	# Legendaries: the fixed relics, each with where it comes from. Ones the
	# guild has never held stay dark, but their source shows (a thing to chase).
	GameState.note_relics_found()
	var legends: Array = []
	for u in GameData.UNIQUE_RELICS:
		legends.append([u, "An act's finale, an elite, a rift shop or an event"])
	for f in GameData.TOWER_RELICS:
		legends.append([GameData.TOWER_RELICS[f], tr("Tower of Trials, floor %d guardian") % int(f)])
	var found_n: int = legends.filter(func(e): return GameState.relics_found.has(str(e[0]["id"]))).size()
	v.add_child(_hsep())
	v.add_child(_label(tr("Legendaries — %d/%d found") % [found_n, legends.size()], 16))
	var w: float = v.custom_minimum_size.x if v.custom_minimum_size.x > 0.0 else get_viewport().get_visible_rect().size.x - 80.0
	var grid := GridContainer.new()
	grid.columns = clampi(int(w / 280.0), 1, 4)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for e in legends:
		grid.add_child(_legendary_card(e[0], str(e[1])))
	v.add_child(grid)


func _legendary_card(u: Dictionary, source: String) -> PanelContainer:
	var found: bool = GameState.relics_found.has(str(u["id"]))
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var path := "res://assets/relics/u_%s.png" % str(u["id"])
	var ic := _icon(path if ResourceLoader.exists(path) else str(GameData.RELIC_TYPE_ICON_PATH.get(str(u["type"]), "")), 40)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if not found:
		ic.modulate = Color(0.08, 0.07, 0.12)
	row.add_child(ic)
	var col := _vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nl := _label(tr(str(u["name"])) if found else "???", 13)
	if found:
		nl.add_theme_color_override("font_color", ITEM_RARITY_COLOR["legendary"])
	col.add_child(nl)
	if found:
		col.add_child(_wrap_label(tr(str(u["desc"])), 12))
	col.add_child(_wrap_label(tr(source), 12, true))
	row.add_child(col)
	card.add_child(row)
	return card


func _render_compendium_crafting(v: VBoxContainer) -> void:
	v.add_child(_wrap_label("The Smithy combines three spare items of one category and rarity into one of the next rarity up (from Act III).", 12, true))
	v.add_child(_hsep())
	for rarity in GameState.CRAFT_RARITY_UP:
		var up := str(GameState.CRAFT_RARITY_UP[rarity])
		var line := _rich_line(tr("[color=#%s]3 × %s[/color]  →  [color=#%s]1 × %s[/color]   [color=#%s](numbers × %s)[/color]") % [
			(ITEM_RARITY_COLOR[rarity] as Color).to_html(false), tr(str(rarity).capitalize()),
			(ITEM_RARITY_COLOR[up] as Color).to_html(false), tr(up.capitalize()),
			Palette.MUTED.to_html(false), str(GameData.find_rarity(up)["mult"])], 14)
		v.add_child(line)
	for rule in [
		"Items: three of the same category (Weapon, Armor or Focus). The new item rolls fresh stats at the best rank among the three.",
		"Relics aren't combined: each is a rule of its own.",
		"Equipped gear never goes in. Legendaries can't be crafted or fed in: they are fixed finds.",
	]:
		v.add_child(_wrap_label("• " + tr(rule), 12, true))

	# What the guild could craft right now.
	var groups := {}
	for it in GameState.items:
		if it.equipped_to == "" and GameState.CRAFT_RARITY_UP.has(it.rarity):
			var k := "%s · %s" % [tr(str(GameData.ITEM_CATEGORY_LABEL.get(it.category, it.category))), tr(str(it.rarity).capitalize())]
			groups[k] = int(groups.get(k, 0)) + 1
	var ready: Array = groups.keys().filter(func(k): return int(groups[k]) >= 3)
	v.add_child(_hsep())
	v.add_child(_label(tr("Ready now — %d") % ready.size(), 16))
	if ready.is_empty():
		v.add_child(_wrap_label("Nothing yet: no three spare pieces of one kind and rarity.", 12, true))
	for k in ready:
		v.add_child(_wrap_label(tr("%s: %d spare, %d craft%s") % [k, int(groups[k]), int(groups[k]) / 3, tr(str(_pl(int(groups[k]) / 3)))], 13))
	if not ready.is_empty() and GameState.feature_unlocked("crafting"):
		var go := _button("Open the Smithy", func(): screen = "crafting_hall"; render())
		go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(go)


var _codex_topic := ""   # the Systems topic open in the Codex


func _render_compendium_systems(v: VBoxContainer) -> void:
	var entries := [
		["The Accord Hall", "Your camp was an Accord hall once. Its 13 rooms are rebuilt with Gold, a few at a time as the guild grows: Operations after two seals, Infrastructure, Logistics and Wardcraft in Act II, Research in Act III. Every level adds its effect and a little upkeep; some levels unlock a perk (a first-strike bonus, a boss Essence cache, extra relic slots…). Guild Tier, and the hall's art, track total levels. At the end of Acts I, III and V you are offered two of the six wings and build one, 3 of 6 per guild. A room damaged by a breach works a level lower until you repair it with Gold."],
		["Daily twist", "From Act III, the Rift Ladder offers a twist each day: a rule and a starting boon that come from the date, so every guild faces the same one. Tick it and your next ladder rift (any rank) carries it; one try a day. Sealing it pays bonus Essence and grows your streak. Records (Guild > Records) track achievements, lifetime statistics and your last 30 runs; the Memorial remembers heroes lost for good."],
		["Hero voices", "A hero's born quirk sets their personality (Bold, Quick, Stoic, Nervous, Devout or Scholarly), shown on their sheet. They speak up in fights when they land a big kill, hang on at low health or see an ally fall, and one of them sums up every win."],
		["Boss phases", "Every boss changes once it drops to half health: Call the Horde (two foes join), Fury (hits 20% harder and winds up more often) or Last Bastion (a ward worth 12% of its health). Its plate shows which, and the warning bar calls it out as it gets close, so save burst and Defend for the turn."],
		["Elite affixes", "Elites roll an affix: Vampiric, Thorned, Shielded, Venomous, Juggernaut, Blazing, Hasted (acts twice) or Commander (brings two escorts). Rank B+ rifts give them two. Hover the badges on their plate to read them."],
		["Boons", "Beating an elite in a rift offers 1 of 3 boons that last until that rift ends. Boons come in seven families (Ember, Frost, Blood, Steel, Storm, Shadow, Holy); owning 2 of a family adds a set bonus and 4 a strong capstone, so a run can grow into a build. Not offered in the Tower."],
		["Guild Orders", "Lv2 of the Infirmary, Drill Yard, Trade Network and Scouts' Lodge each unlock an order you can call inside a rift: Supply Drop (heal 35% between fights), Rally (act first and hit 30% harder this round), Requisition (reroll a fight's loot) and Scout Ahead (reroll a fork). 1 order per rift, 2 at Renowned tier, 3 at Legendary."],
		["Rift Ladder", "Rifts come in ranks, F to SSS. F-D are Lesser rifts, C and up Greater rifts (open after Act I). Each rank hits harder than the last and pays more; from B up they add rules (more elites, harsher hazards, fewer shops, bosses with two mechanics). Seal a rank to open the next. Gear drops at the rank of the rift it came from."],
		["Bonds", "Heroes who seal rifts together grow a bond: level 1, 2 and 3 after 2, 5 and 10 rifts. Each level adds 2% party damage while both stand in a fight (up to the cap). Bonds show on the hero sheet's History tab."],
		["Ability Awakening", "Spend Skill Points once to give a hero's Ability a secondary effect (by ability: +2 Momentum back, a lingering debuff, a party dodge boost, a self-shield, or a small damage stack)."],
		["Formation", "Heroes stand in the front or back row. Foes aim most attacks at the front row; Snipes hunt the back. Warriors and rogues hit at half strength with a basic attack from the back row, and some skills need a row. Move (7) switches rows for a turn. Back-row foes take less damage from attacks."],
		["Controls", "Keyboard: 1-5 switch camp tabs; in a fight 1 Attack, 2-4 skills, 5 Defend, M opens More (6 Guard, 7 Move, 8 Tonics, 9 Call; their keys work either way), Space repeats the last action, Tab cycles targets, A toggles Auto, Esc goes back. Gamepad: D-pad and A work every menu, B goes back, LB/RB switch camp tabs. In a fight A repeats the last action, X Defends, Y uses the Ability, LB/RB the two skills, Start opens More (Guard, Move, Tonics, Call), the D-pad cycles targets, Select toggles Auto."],
		["Momentum and skills", "Momentum is the party's shared pool (up to 10, starting at 3). Each basic attack adds 1, each kill 1, and each hit taken while Defending or Guarding 1 (2 for a heavy blow). Every hero has two role skills (Lv1 and Lv6) and their subclass Ability (Lv3). Skills cost 2-4 Momentum, Abilities 4."],
		["Enemy moves", "Each round a foe shows its next move above its health bar: an attack on a hero, a wind-up (a heavy blow next round), or a special move: Sweep (hits everyone), Snipe (the most-hurt back-row hero), Curse (40% less damage for 2 rounds), Ward, Mend or Roar. Shield Bash stuns a foe; Shield Bash and Frost Nova break wind-ups."],
		["Designed encounters", "About six regular fights in ten are one of a region's named encounters (Scarecrow Line, Reed Snipers, Forge Guard...), groups whose members play off each other: a warder shielding a brute, a healer behind a wall, snipers behind a tank. The name and a tactical hint open the fight log; hover the round label to read the hint again."],
		["Rift bosses", "Each boss is always the same fight. Vaelith's Harvest hits everyone and heals her, and she calls a Crier and a Warden at half health. Nyxara's Drowning Tide chills and weakens the party. Korrath's Sunder tears the wards off the front row. Drevok Brands a hero to take 50% more damage and calls fire cultists. Sythrane Immolates the party while she regenerates and enrages. Their signature moves are telegraphed like any other."],
		["Bestiary", "Every monster, boss, and hazard you've encountered is tracked as a silhouette-to-full-color reveal — pure record-keeping, no reward tied to completion."],
		["Tower of Trials", "Opens with Act IV, in the Rift Hall. 100 fixed floors, one fight each: a floor is always the same fight, so a loss is something to plan around. Heroes fight at full HP and leave as they came (no downing, scars or days passing). Most floors carry a rule (armored or burning foes, a swarm, a party cap). Every 10th floor is a guardian that gives a unique relic, and floors 10/25/50/75/100 earn guild titles. Only a first clear pays; floors 91-100 reshuffle their rules every week and pay half for a re-clear."],
		["Foes & regions", "Each rift is in a region (the Vale, the Marshes, the Ashen Wastes) with its own foes. Some foes wind up a heavy blow a turn ahead (x2.5, stuns unless the target Defends); armored foes shrug off part of every basic attack (each hit chips the armor; abilities ignore it); fire foes can burn and frost foes can chill (act late). A Field Tonic cleanses burn, chill, poison and stun."],
		["Campaign", "Six acts, each ending in a finale rift against a named foe. Meet an act's objectives (shown in the Rift Hall) to open its finale; sealing it pays a reward and a unique relic. Act I opens Greater Rifts, Act II the Descent."],
		["Relics", "Relics bend rules: each is one of a kind, found from Act I's finale on (finales, elites, shops, events and the Tower's guardians), and sits on the Relic Altar for the whole guild. Stats live on gear. A sealed Rank D+ rift offers a Path relic instead, carried by a hero of that Path (one each) and passed between them at camp; it works while they fight. Declining one pays the seal's Essence."],
		["Quirks", "Everything personal about a hero beyond class, skills and gear: at most one born quirk (it sets their voice), up to 2 scars from falling in a Rank C+ rift or a perilous expedition (a lasting mark with a small upside), and quirks earned by what they've done. Bad born quirks and scars can be treated for Gold at the Arcane Lab."],
		["Breaches", "From Act II a rift swells every so often: a rank, a place and a countdown in days (Rift Hall and the camp's status board). Seal a rift of that rank or higher before it runs out to close it, for a little Essence. Otherwise it breaks, and every rift run waits until your guild holds it: a breach rift of back-to-back fights (a fight, an elite and the breach's warden; the Inverted City's gate adds an elite) with no camp, shop or campfire between them. Ranks below S break out in a region; from S up they break at your camp. Holding pays Gold and Essence. Falling or turning back costs a share of your Essence and of the Gold beyond the coming payday's wages, and damages a building (two at the camp). The Accord Hall's Wardcraft rooms soften all of it."],
		["Champions", "Each new guild meets twelve champions, drawn from a pool of twenty-four: three are freed at the end of Acts I, II and III, and nine are lost, each held in a pillar of light (in the Descent, and in ladder rifts from Rank B; reach one to free them). A champion never joins the roster. In rift runs one oversees the party: their Boon lifts everyone, and any hero can spend a turn on their Call (once a rift, twice from level 3). Essence levels them up (to 5)."],
		["Attributes", "Might (damage, HP), Agility (speed, dodge, first strike) and Focus (ability power, mend). Heroes gain 3 points per level to spend on the Roster's Hero tab; gear adds more, and better gear needs a minimum in its attribute to equip. Train up to 8 extra points at the Training Yard, or reset a hero's points for 5 Essence per level (gear they no longer qualify for comes off)."],
		["Quests & Milestones", "The quest board posts 6 quests (hunts, boss bounties, rift seals, trials); take up to 3 at a time. Unaccepted postings are replaced every 3 days (a day passes with each rift run or rest). Milestones are a static checklist, auto-granted the moment they're met. A rare escort NPC can also tag along on a fight — surviving pays a small bonus."],
		["Wages, morale and the rival", "Every 7 days (a day = one rift run or rest) heroes draw wages by rank and level, and every hall room level costs upkeep; see Guild > Ledger. Unpaid upkeep costs Renown. The Training Yard trains only a few attribute points a week (more with the Drill Yard), and a feast seats a limited number of heroes, lowest morale first (more with the Trade Network). The unpaid lose morale, and a hero unpaid twice in a row, or at rock-bottom morale on payday, walks out. Morale (0-100) rises with sealed rifts and feasts and falls with defeats, knockouts, idle weeks and failed contracts: Inspired heroes deal +10% damage, Shaken -10%, Breaking -20%. Taken contracts are due in 6-10 days. A rival guild gains Renown daily, and once a week it may make a move you answer before payday: court one of your heroes (match their offer, or they choose, staying only at morale 50 or above), dare you to seal a rift by payday (Renown rides on it), or go for a posted contract (take it on or lose it). Requests and the rival's moves pop up at camp and wait in the Ledger, whose week board shows each day to payday. At payday, the leader on Renown gets the better recruits. Every 28 days, whichever guild gained more Renown wins a prize."] if GameState.rival_present() else ["Wages and morale", "Every 7 days (a day = one rift run or rest) heroes draw wages by rank and level, and every hall room level costs upkeep; see Guild > Ledger. Unpaid upkeep costs Renown. The Training Yard trains only a few attribute points a week (more with the Drill Yard), and a feast seats a limited number of heroes, lowest morale first (more with the Trade Network). The unpaid lose morale, and a hero unpaid twice in a row, or at rock-bottom morale on payday, walks out. Morale (0-100) rises with sealed rifts and feasts and falls with defeats, knockouts, idle weeks and failed contracts: Inspired heroes deal +10% damage, Shaken -10%, Breaking -20%. Taken contracts are due in 6-10 days. Hero requests pop up at camp and wait in the Ledger, whose week board shows each day to payday."],   # no rivals in Act I (0.70)
		["Hero requests", "Twice a week a hero may ask for something: time off, a raise, Gold for kit, a Training Yard slot, a partner, a rift of their own, your side in a feud, and more. Saying yes costs something and can leave them a title, a quirk or a bond; saying no costs morale. Answer in the Ledger before payday, or it counts as a no."],
		["Expeditions", "From two seals, the Quest board's Expeditions tab posts three jobs off the map: a safe one, a hard one and (from Act II) a perilous one, each with a Need in power, a length of 1-3 days and a party of up to 3. Heroes you send are away for those days and still draw wages. The odds show before they go: 50% at the Need, better above it. Success pays in full; a partial pays half and someone comes back hurt; a failure pays nothing and hurts the party, and on a perilous job it can leave a scar. Every class and every Path brings something on the road, once per party: a warrior's muscle and a ranger's scouting raise the odds, a mage appraises (+50% Essence), a rogue pockets more (+25% Gold), a cleric halves the hurt, and each Path adds its own. Heroes are gone for the whole days while rifts and breaches go on without them. Everyone learns on the road, as at the Training Yard. One party out at a time, two with a Scouts' Lodge at level 3."],
		["Camp events", "On about a third of days something happens at camp, and each is a choice: a travelling merchant, a renowned hero who drills one of yours, a wandering recruit, a relic peddler, a smith's apprentice, a scholar; a festival, refugees, a debt, the rival's quartermaster. Threats (fire, fever, bandits, a storm, a rift tremor) are foretold the evening before (the status board and the week's calendar): pay, send a hero who stays home that day, or take the loss. An event left unanswered takes its last option the next day. Act I brings only opportunities."],
		["Wounds and falls", "From Rank C a landed heavy blow (a wind-up's strike) or any hit worth a quarter of a hero's max HP wounds them: half the damage also comes off their max HP, and no healing refills it (up to 60%). A hero who Defends, is Guarded or dodges is never wounded, and every ordinary fight from Rank C has a wind-up to answer by round 2. Up to Rank A wounds close when the fight ends; from Rank S they last the whole run (a campfire's Rest halves them, a shrine closes some), so a party meets the boss with what it has left. A hero who falls in a Rank C+ rift (after your third seal) may keep a scar (15% at C, up to 35% at SS; a cleric, Warding and Aegis heroes and the Healers' Wing lower it) and drops one piece of worn gear in the rift, back home only if the party seals it. From Rank SS a hero who already has two scars can die when they fall; the Party screen names them before you go. Never in training, the Daily, the Tower, the Descent, breach rifts or Story."],
		["The deep road", "From Rank S the ordinary fights between you and the boss are harder: their foes have half again the health and hit half again as hard, and every hit a hero takes unguarded leaves a small trace on their max HP that lasts the run. Momentum decides who strikes first: a party that starts the fight with 5 Momentum or more keeps the initiative; with less, every foe acts first in round 1. Momentum left after a won fight on the road carries into the next one, so spending it to finish fast and banking it to strike first is a choice every fight."],
		["The rift map", "A ranked rift is a map of lanes: Ranks F-E have 3, D-B 4, A and up 5. Each node leads on to its own lane and one or both neighbours on the next floor, so plan a route: an elite on the way to a treasure, a shop before the boss. Every route ends at a campfire before the boss. Anvils temper a worn piece for free, a Path's shrine teaches the party (its Path's heroes most), and a trainer's echo gives one hero a level. From Rank S, floors more than two ahead are unseen unless a Trapper or a Stalker scouts."],
	]
	# One topic at a time, picked from a row of names (playtest 2026-10-09:
	# all of them in one column was a wall of text).
	var shown: Array = entries.filter(func(e): return not e.is_empty())
	var names: Array = shown.map(func(e): return str(e[0]))
	if not names.has(_codex_topic):
		_codex_topic = str(names[0])
	var picker := HFlowContainer.new()
	picker.add_theme_constant_override("h_separation", 6)
	picker.add_theme_constant_override("v_separation", 6)
	for n in names:
		var b := _button(str(n), func(t=n):
			_codex_topic = str(t)
			render())
		b.toggle_mode = true
		b.button_pressed = n == _codex_topic
		picker.add_child(b)
	v.add_child(picker)
	var entry: Array = shown[names.find(_codex_topic)]
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanelViolet"
	var cc := _vbox(8)
	cc.add_child(_label(str(entry[0]), 18))
	cc.add_child(_rich_line(tr(str(entry[1])), 14))
	card.add_child(cc)
	v.add_child(card)
