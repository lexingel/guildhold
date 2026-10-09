extends "res://scripts/autoload/game_state/GameStateLore.gd"
## GameState, part 2: heroes — recruiting, the Champion, bonds, skills, traits, attributes.


## Queues a portrait pop-up (Main drains these on its next render).
func push_toast(h: Hero, title: String, text: String) -> void:
	pending_toasts.append({"cls_id": h.cls_id, "pool_id": h.pool_id, "title": title, "text": text})


func _bond_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


func bond_rifts(a: String, b: String) -> int:
	return int(bonds.get(_bond_key(a, b), 0))


## Gives `h` every earned quirk (GameData.QUIRKS, origin "earned") their
## history now qualifies for; returns "X earned Bosskiller!" lines.
func check_earned_quirks(h: Hero) -> Array[String]:
	var gained: Array[String] = []
	for q in GameData.quirks_from("earned"):
		var t := GameData.quirk(q)
		if not h.quirks.has(q) and int(h.history.get(t["stat"], 0)) >= int(t["need"]):
			h.quirks.append(q)
			gained.append(tr("%s earned %s!") % [tr(str(h.name)), tr(str(q))])
			push_toast(h, tr("Quirk earned: %s") % tr(str(q)), "%s — %s" % [tr(str(h.name.split(" the ")[0])), tr(str(quirk_text(q)))])
	return gained


## Gives `h` quirk `q` (a granted request, 0.66) with a toast; "" if they had it.
func give_quirk(h: Hero, q: String) -> String:
	if h.quirks.has(q) or not GameData.QUIRKS.has(q):
		return ""
	h.quirks.append(q)
	push_toast(h, tr("Quirk: %s") % tr(q), "%s — %s" % [tr(str(h.name.split(" the ")[0])), tr(str(quirk_text(q)))])
	return tr("%s gains %s.") % [tr(str(h.name.split(" the ")[0])), tr(q)]


## Gives `h` a title (0.66); "" if they had it.
func give_title(h: Hero, t: String) -> String:
	if h.titles.has(t):
		return ""
	h.titles.append(t)
	push_toast(h, tr("Title earned: %s") % tr(t), tr(str(h.name)))
	return tr("%s is now called %s.") % [tr(str(h.name.split(" the ")[0])), tr(t)]


## Every deed title (GameData.TITLE_DEEDS) `h` now qualifies for.
func check_titles(h: Hero) -> Array[String]:
	var out: Array[String] = []
	for d in GameData.TITLE_DEEDS:
		if not h.titles.has(str(d["title"])) and int(h.history.get(str(d["stat"]), 0)) >= int(d["need"]) and (not d.has("none") or int(h.history.get(str(d["none"]), 0)) == 0):
			out.append(give_title(h, str(d["title"])))
	return out


## A hero's newest title, or "".
func hero_title(h: Hero) -> String:
	return tr(str(h.titles[-1])) if not h.titles.is_empty() else ""


## Renames a hero's first name (0.66); "" or why not. The class part stays.
func rename_hero(hero_id: String, first: String) -> String:
	var h := find_hero(hero_id)
	first = first.strip_edges()
	if h == null:
		return tr("No such hero.")
	if first.length() < 2 or first.length() > 14:
		return tr("A name needs 2 to 14 letters.")
	if first.to_lower().contains(" the ") or first.contains("%"):
		return tr("That name can't be used.")
	var parts := h.name.split(" the ", true, 1)
	h.name = first + (" the " + parts[1] if parts.size() > 1 else "")
	save()
	state_changed.emit()
	return ""


## "+10% damage; +15% dodge while below 40% HP" for a quirk.
func quirk_text(q: String) -> String:
	var t := GameData.quirk(q)
	var parts: Array[String] = []
	var stats: Dictionary = t.get("stats", {})
	for kind in stats:
		parts.append(Combat.describe_skill(kind, float(stats[kind])))
	for e in t.get("effects", []):
		parts.append(Combat.describe_effect(e))
	return "; ".join(parts)


## Treats a treatable quirk (a bad born quirk or a scar) at the Arcane Lab.
func treat_quirk(hero_id: String, q: String) -> String:
	if lvl("res.lab") < 1:
		return tr("Build the Arcane Lab first")
	var h := find_hero(hero_id)
	if not h or not h.quirks.has(q) or not GameData.quirk(q).get("treatable", false):
		return ""
	var cost := quirk_treat_cost()
	if coins < cost:
		return tr("Need %d Gold") % cost
	coins -= cost
	h.quirks.erase(q)
	h.hp = mini(h.hp, Combat.max_hp(h))
	save()
	state_changed.emit()
	return ""


func quirk_treat_cost() -> int:
	return int(round(GameData.QUIRK_TREAT_COST * (1.0 - respec_fee_reduction())))


## Heroes who'd look identical (the same portrait: the same subclass, or
## Champions of one role) get different colour variants. The earliest in the
## roster keeps the art as drawn, the next the first free variant, and so on;
## a hero keeps theirs until an evolution changes their portrait.
func refresh_looks() -> void:
	var taken := {}   # portrait -> {look: true}
	for h in heroes:
		var art := GameData.hero_portrait(h)
		var t: Dictionary = taken.get(art, {})
		if h.look_of != art or t.has(h.look):
			h.look = _free_look(t)
			h.look_of = art
		t[h.look] = true
		taken[art] = t


## The variant a hero would wear on joining (a recruit offer's preview).
func look_for(h: Hero) -> int:
	if h.quirks.has("Hollow-born"):   # the Sky Beneath: the far side shows
		return GameData.HOLLOW_LOOK
	if heroes.has(h):
		return h.look
	var art := GameData.hero_portrait(h)
	var t := {}
	for o in heroes:
		if o.look_of == art:
			t[o.look] = true
	return _free_look(t)


func _free_look(taken: Dictionary) -> int:
	var k := 0
	while taken.has(k):
		k += 1
	return k


func find_hero(hero_id: String) -> Hero:
	for h in heroes:
		if h.id == hero_id:
			return h
	return null


## Saved loadouts (party_presets): a party with each hero's row, to load in
## one click on any party screen.
func save_party_preset(i: int, hero_ids: Array) -> void:
	if i < 0 or i >= party_presets.size():
		return
	var out: Array = []
	for id in hero_ids:
		var h := find_hero(str(id))
		if h and not h.is_champion:
			out.append([h.id, h.formation])
	party_presets[i] = out
	save()


## A loadout's heroes who can go now, set in their saved rows, up to `cap`:
## {ids, missing (first names of the ones who can't)}.
func load_party_preset(i: int, cap: int) -> Dictionary:
	var ids: Array[String] = []
	var missing: Array[String] = []
	if i < 0 or i >= party_presets.size():
		return {"ids": ids, "missing": missing}
	for entry in party_presets[i]:
		var h := find_hero(str(entry[0]))
		if h == null:
			continue
		if h.is_downed() or h.is_away() or ids.size() >= cap:
			missing.append(h.name.split(" the ")[0])
			continue
		h.formation = str(entry[1])
		ids.append(h.id)
	return {"ids": ids, "missing": missing}


func gen_recruit_offer(force_rank: String = "") -> Hero:
	var h := Combat.gen_recruit(force_rank if force_rank != "" else Combat.weighted_rank())
	if hollowborn_open() and randf() < GameData.HOLLOWBORN_CHANCE:   # the Sky Beneath: the doors are open
		h.quirks = h.quirks.filter(func(q): return GameData.QUIRKS.get(q, {}).get("origin", "") != "born")
		h.quirks.append("Hollow-born")
	elif _hall_has("kept") and randf() < GameData.ACCORD_SWORN_CHANCE:   # a past guild kept the Accord
		h.quirks = h.quirks.filter(func(q): return GameData.QUIRKS.get(q, {}).get("origin", "") != "born")
		h.quirks.append("Accord-Sworn")
	elif _hall_has("broke") and randf() < GameData.TIDE_HARDENED_CHANCE:   # ... or broke it
		h.quirks = h.quirks.filter(func(q): return GameData.QUIRKS.get(q, {}).get("origin", "") != "born")
		h.quirks.append("Tide-Hardened")
	_maybe_heir(h)
	return h


## A remembered hero's child, now and then: a family trait (the Heir quirk)
## and their parent's name in their history. One heir on the board at a time.
func _maybe_heir(h: Hero) -> void:
	if recruit_pool.any(func(x): return x.history.has("heir_of")) or randf() >= GameData.HEIR_CHANCE:
		return
	var parents: Array = []
	for g in legacy.get("guilds", []):
		for n in g.get("remembered", []):
			if str(n) != "Hesper":
				parents.append("%s of %s" % [str(n), str(g.get("name", ""))])
	if parents.is_empty():
		return
	h.history["heir_of"] = str(parents[randi() % parents.size()])
	h.quirks.append("Heir")


## Flags pending_s_rank_reveal whenever a blind roll (recruit offer, Champion
## reroll/init) lands Rank S — Main.render() consumes it once, the same way
## it already consumes _flavor_toast, so the celebration shows up wherever
## the player is instead of only on the Recruits screen.
func _maybe_flag_s_rank(h: Hero, source: String) -> void:
	if h.rank == "S":
		pending_s_rank_reveal = {"name": h.name, "cls_id": h.cls_id, "pool_id": h.pool_id, "source": source}


## A full board (a new guild, or an old save without one).
func refresh_recruit_pool() -> void:
	recruit_pool = []
	recruit_until = {}
	recruit_top_up()


## Puts a recruit on the board for a few days (`stay` -1 = the usual roll).
func _post_offer(h: Hero, stay: int = -1, at: int = -1) -> void:
	if stay < 0:
		stay = randi_range(int(GameData.RECRUIT_STAY[0]), int(GameData.RECRUIT_STAY[1]))
	if at < 0:
		recruit_pool.append(h)
	else:
		recruit_pool.insert(at, h)
	recruit_until[h.id] = day + stay
	_maybe_flag_s_rank(h, "recruit")


func _drop_offer(h: Hero) -> void:
	recruit_pool.erase(h)
	recruit_until.erase(h.id)


## Days an offer still waits: 0 = its last day.
func offer_days_left(h: Hero) -> int:
	return int(recruit_until.get(h.id, day)) - day


## Payday: the week's new faces fill the board (the Scouts' Lodge assures a
## C+ among them) and rerolls are back to their first price.
func recruit_top_up() -> void:
	while recruit_pool.size() < recruit_offer_count():
		_post_offer(gen_recruit_offer())
	if headhunter_guarantee() and not recruit_pool.is_empty() and not recruit_pool.any(func(h): return GameData.rank_index(h.rank) >= GameData.rank_index("C")):
		var good_ranks := ["C", "B", "A", "S"]
		_drop_offer(recruit_pool[recruit_pool.size() - 1])
		_post_offer(gen_recruit_offer(good_ranks[randi() % good_ranks.size()]))
	if bool(founding_rule("ranger_offer", false)) and not recruit_pool.is_empty() and not recruit_pool.any(func(h): return h.cls_id == "ranger"):   # Vaelith's Rangers
		var ranger := gen_recruit_offer()
		for i in 40:
			if ranger.cls_id == "ranger":
				break
			ranger = gen_recruit_offer()
		if ranger.cls_id == "ranger":
			_drop_offer(recruit_pool[0])
			_post_offer(ranger)
	recruit_rerolls = 0


## A day on the recruit board: offers whose time is up move on, the rival may
## sign the best one, and a new face arrives (two on a thin board). The board
## used to refill whole after every seal, so rerolling was the only choice.
func recruit_day() -> void:
	for h in recruit_pool.duplicate():
		if offer_days_left(h) < 0:
			_drop_offer(h)
	if not recruit_pool.is_empty() and feature_unlocked("rival") and randf() < GameData.RIVAL_SIGN_CHANCE * year_mult("rival_signs"):
		var best: Hero = recruit_pool[0]
		for h in recruit_pool:
			if GameData.rank_index(h.rank) > GameData.rank_index(best.rank):
				best = h
		_drop_offer(best)
		_news(tr("%s signed %s (Rank %s) off your recruit board.") % [tr(str(rival_name)), tr(str(best.name.split(" the ")[0])), tr(str(best.rank))])
	var arrivals := 2 if recruit_pool.size() * 2 < recruit_offer_count() else 1
	for i in arrivals:
		if recruit_pool.size() < recruit_offer_count():
			_post_offer(gen_recruit_offer())


## A recruit of the role you ask for, at the usual rank odds, for
## COMMISSION_COST_MULT x the reroll fee. Rerolling the board until a cleric
## turned up was the only way to look for one ("spamming Gold"). The new
## offer goes first; the last one leaves, so the board keeps its size.
func commission_recruit(role: String) -> String:
	var cost := commission_cost()
	if coins < cost:
		return tr("Not enough Gold.")
	var rank := Combat.weighted_rank()
	var h := Combat.gen_recruit(rank, role)
	if h == null:
		return tr("No %s answered; try another role") % tr(role)
	coins -= cost
	recruit_rerolls += 1
	_post_offer(h, -1, 0)
	if recruit_pool.size() > recruit_offer_count():
		_drop_offer(recruit_pool[recruit_pool.size() - 1])
	save()
	state_changed.emit()
	return ""


func commission_cost() -> int:
	return recruit_reroll_cost() * GameData.COMMISSION_COST_MULT


func recruit_hero(offer_id: String) -> String:
	var idx := -1
	for i in recruit_pool.size():
		if recruit_pool[i].id == offer_id:
			idx = i
			break
	if idx < 0:
		return ""
	if heroes.size() >= hero_slot_cap():
		return tr("Roster is full.")
	var offer := recruit_pool[idx]
	var rank := GameData.find_rank(offer.rank)
	var founder := signing_founders()
	var cost := 0 if founder else int(rank["cost"])
	if coins < cost:
		return tr("Not enough Gold.")
	coins -= cost
	var is_dupe := heroes.any(func(h): return h.pool_id == offer.pool_id)
	if guild_mentor():   # Barracks Lv3: recruits join a level higher
		offer.level = 2
		Combat.refresh_stats(offer)
		offer.hp = Combat.max_hp(offer)
	heroes.append(offer)
	_drop_offer(offer)   # the next face arrives tomorrow (it used to be replaced on the spot)
	if founder:   # a founder pays their own first week, and the last one opens the usual board
		coins += wage_of(offer)
		founding_picks -= 1
		if founding_picks <= 0:
			founding_rerolls = 0
			refresh_recruit_pool()
		save()
		state_changed.emit()
		return ""
	if is_dupe:
		var refund := int(round(float(rank["cost"]) * 0.5))
		coins += refund
	save()
	state_changed.emit()
	return ""


## Champions for hire: fills the offers if there are none.
func reroll_recruit_offer(offer_id: String) -> String:
	var idx := -1
	for i in recruit_pool.size():
		if recruit_pool[i].id == offer_id:
			idx = i
			break
	if idx < 0:
		return ""
	if signing_founders() and founding_rerolls > 0:   # the founding board's free rerolls: another Rank F
		founding_rerolls -= 1
		_drop_offer(recruit_pool[idx])
		_post_offer(Combat.gen_recruit("F"), 60, idx)
		save()
		state_changed.emit()
		return ""
	if coins < recruit_reroll_cost():
		return tr("Not enough Gold.")
	coins -= recruit_reroll_cost()
	recruit_rerolls += 1
	_drop_offer(recruit_pool[idx])
	_post_offer(gen_recruit_offer(), -1, idx)
	save()
	state_changed.emit()
	return ""


# ---------------- Champions ----------------
## This guild's champions: GameData.CHAMPION_ROLL drawn from the pool. The
## first CHAMPION_STORY_ACTS are freed at the end of Acts I-III, the rest are
## lost in the Endless Rift (see lost_champions).
func roll_champions() -> void:
	var ids: Array = GameData.CHAMPIONS.keys()
	ids.shuffle()
	champion_roll.assign(ids.slice(0, GameData.CHAMPION_ROLL))
	# Up to two heroes from the player's past guilds wait among the lost: one
	# who took the forty-first post at the deepest pillar, others near the top.
	var past: Array = GameData.LEGACY_CHAMPIONS.keys()
	if past.is_empty():
		return   # (and no extra random draws, so seeded rolls stay as they were)
	past.shuffle()
	var posts: Array = past.filter(func(k): return GameData.LEGACY_CHAMPIONS[k].get("post", false))
	var others: Array = past.filter(func(k): return not GameData.LEGACY_CHAMPIONS[k].get("post", false))
	var picked: Array = (posts.slice(0, 1) + others).slice(0, GameData.LEGACY_HEROES)
	var shallow: Array = range(GameData.CHAMPION_STORY_ACTS, mini(GameData.CHAMPION_STORY_ACTS + GameData.LEGACY_SHALLOW, champion_roll.size()))
	shallow.shuffle()
	for k in picked:
		var at: int = champion_roll.size() - 1 if GameData.LEGACY_CHAMPIONS[k].get("post", false) else int(shallow.pop_back())
		champion_roll[at] = str(k)


## The champion freed at the end of Act `act`, or "".
func story_champion(act: int) -> String:
	return champion_roll[act - 1] if act >= 1 and act <= mini(GameData.CHAMPION_STORY_ACTS, champion_roll.size()) else ""


## How strong the Endless Rift's foes are for this guild (see THREAT_BASE).
func endless_threat() -> float:
	var freed := lost_champions().filter(func(e): return champion_unlocked(str(e[0]))).size()
	var acts_after := maxi(0, campaign_act - 3)   # the rift opens once Act II is done
	return minf(GameData.THREAT_MAX, GameData.THREAT_BASE + GameData.THREAT_PER_RESCUE * freed + GameData.THREAT_PER_ACT * acts_after)


## [[id, depth seconds], ...]: this guild's champions lost in the Endless Rift.
func lost_champions() -> Array:
	var out: Array = []
	for i in range(GameData.CHAMPION_STORY_ACTS, champion_roll.size()):
		out.append([champion_roll[i], int(GameData.CHAMPION_DEPTHS[mini(i - GameData.CHAMPION_STORY_ACTS, GameData.CHAMPION_DEPTHS.size() - 1)])])
	return out


func champion_unlocked(id: String) -> bool:
	return champions.has(id)


func champion_level(id: String) -> int:
	return int(champions.get(id, 0))


## Frees a champion (the first one freed also takes up overseeing).
func unlock_champion(id: String) -> void:
	if id == "" or champions.has(id):
		return
	champions[id] = 1
	if overseer == "":
		overseer = id


## Essence to raise `id` one level, or -1 at the top.
func champion_level_cost(id: String) -> int:
	var lv := champion_level(id)
	return int(GameData.CHAMPION_LEVEL_COST[lv]) if lv >= 1 and lv < GameData.CHAMPION_LEVEL_MAX else -1


func level_champion(id: String) -> String:
	var cost := champion_level_cost(id)
	if cost < 0:
		return tr("Already at the top level.")
	if crystals < cost:
		return tr("Not enough Essence.")
	crystals -= cost
	champions[id] = champion_level(id) + 1
	save()
	state_changed.emit()
	return ""


func set_overseer(id: String) -> void:
	if id != "" and not champions.has(id):
		return
	overseer = id
	save()
	state_changed.emit()


## The champion overseeing this run ("" outside a run or with none).
func run_overseer() -> String:
	return str(run.get("overseer", "")) if not run.is_empty() else ""


## The overseer's party-wide Boon for `kind` during a run.
func champion_boon(kind: String) -> float:
	var id := run_overseer()
	var b: Dictionary = GameData.champion_def(id).get("boon", {})
	if b.is_empty() or str(b["kind"]) != kind:
		return 0.0
	return float(b["value"]) * GameData.champion_power(champion_level(id))


func champion_boon_text(id: String) -> String:
	var b: Dictionary = GameData.champion_def(id).get("boon", {})
	if b.is_empty():
		return ""
	return tr("%s — party %s") % [tr(str(b["name"])), tr(str(Combat.describe_skill(str(b["kind"]), float(b["value"]) * GameData.champion_power(maxi(1, champion_level(id))))))]


## `id`'s Call at their level, Ability-shaped {name, effect, value, desc}.
## A multiplier (x1.25) grows on its bonus, anything else on its value.
func champion_call_of(id: String) -> Dictionary:
	var c: Dictionary = (GameData.champion_def(id).get("call", {}) as Dictionary).duplicate()
	if c.is_empty():
		return c
	var k := GameData.champion_power(maxi(1, champion_level(id)))
	var v := float(c["value"])
	c["value"] = 1.0 + (v - 1.0) * k if v > 1.0 and str(c["effect"]).ends_with("_mult") else v * k
	return c


## The overseer's Call (any hero can spend their turn on it). `_h` is kept
## for the combat code's call sites.
func champion_call(_h: Hero = null) -> Dictionary:
	return champion_call_of(run_overseer())


func champion_calls_allowed() -> int:
	var id := run_overseer()
	if id == "":
		return 0
	var n := 2 if champion_level(id) >= GameData.CHAMPION_EXTRA_CALL_LEVEL else 1
	return n + (1 if Combat.party_has_unique_relic("crown_of_oaths") else 0)


func champion_calls_left() -> int:
	return maxi(0, champion_calls_allowed() - int(run.get("champion_calls", 0)))


func champion_call_ready(_h: Hero = null) -> bool:
	return not run.is_empty() and champion_calls_left() > 0


## A champion as a fighter for the Endless Rift: rank CHAMPION_RANK, as
## experienced as the guild's best hero, stronger with their own level.
func champion_hero(id: String) -> Hero:
	var d := GameData.champion_def(id)
	var role := str(d.get("role", "warrior"))
	var template: Dictionary = {}
	for c in GameData.CLASS_POOL:
		if str(c["role"]) == role and str(c["rank"]) == GameData.CHAMPION_RANK:
			template = c
			break
	if template.is_empty():
		template = GameData.CLASS_POOL.filter(func(c): return str(c["role"]) == role)[0]
	var rank := GameData.find_rank(GameData.CHAMPION_RANK)
	var h := Hero.new()
	h.id = "champ:" + id
	h.name = str(d.get("name", id))
	h.is_champion = true
	h.cls_id = role
	h.pool_id = "champ_" + id
	h.rank = GameData.CHAMPION_RANK
	h.type = str(template.get("type", ""))
	var boon: Dictionary = d.get("boon", {})
	h.innate_kind = str(boon.get("kind", template.get("kind", "dmg_pct")))
	h.innate_value = Combat.innate_value_for(template, GameData.rank_index(GameData.CHAMPION_RANK))
	h.flavor = str(d.get("lore", ""))
	var lv := 1
	for o in heroes:
		lv = maxi(lv, o.level)
	h.level = lv
	var grow := pow(1.0 + GameData.LEVEL_GROWTH, lv - 1) * (1.0 + GameData.CHAMPION_LEVEL_STATS * (maxi(1, champion_level(id)) - 1))
	h.base_hp = int(round(30.0 * float(template["hp_ratio"]) * float(rank["mult"]) * grow))
	h.base_dmg = int(round(8.0 * float(template["dmg_ratio"]) * float(rank["mult"]) * grow))
	h.base_spd = int(round(float(GameData.find_role(role)["base_spd"]) * float(rank["mult"])))
	h.formation = str(GameData.ROLE_POSITION.get(role, {}).get("row", "front"))
	h.attrs = GameData.role_attrs(role)
	h.attr_points = (lv - 1) * GameData.ATTR_POINTS_PER_LEVEL
	Combat.auto_spend_attrs(h)
	h.hp = Combat.max_hp(h)
	return h

func current_party() -> Array[Hero]:
	var out: Array[Hero] = []
	for id in run.get("hero_ids", []):
		var h := find_hero(id)
		if h:
			out.append(h)
	return out


## The next rank for a hero ("" at S).
func next_rank_of(h: Hero) -> String:
	var ri := GameData.rank_index(h.rank)
	return str(GameData.RANKS[ri + 1]["id"]) if ri + 1 < GameData.RANKS.size() else ""


## [Gold, Essence] to evolve `h` to the next rank, or [] at S.
func evolve_cost(h: Hero) -> Array:
	var nr := next_rank_of(h)
	return (GameData.EVOLVE_COST.get(nr, []) as Array) if nr != "" else []


## "" if `h` can evolve now, else why not.
func evolve_lock(h: Hero) -> String:
	if h.is_champion:
		return tr("Champions don't evolve")
	var nr := next_rank_of(h)
	if nr == "":
		return tr("Already Rank S")
	if h.level < 10:
		return tr("Must be Level 10 to evolve")
	var gate := evolve_rank_gate(nr)
	if gate != "":
		return gate
	var c := evolve_cost(h)
	if coins < int(c[0]) or crystals < int(c[1]):
		return tr("Needs %d Gold and %d Essence") % [int(c[0]), int(c[1])]
	return ""


## Evolving (0.62): the next rank, back to level 1 with +XP_BOOST XP for the
## next XP_BOOST_RUNS rift runs, and a Seasoned rank (+2% HP and damage for
## good). The subclass doesn't change: that's trained at the Training Yard.
## `_unused` keeps the old (hero, subclass) call shape working.
func evolve_hero(hero_id: String, _unused: String = "") -> String:
	var h := find_hero(hero_id)
	if not h:
		return ""
	var lock := evolve_lock(h)
	if lock != "":
		return lock
	var c := evolve_cost(h)
	coins -= int(c[0])
	crystals -= int(c[1])
	h.rank = next_rank_of(h)
	h.level = 1
	h.xp = 0
	h.seasoned += 1
	h.xp_boost_runs = GameData.XP_BOOST_RUNS
	h.innate_value = Combat.hero_innate_value(GameData.find_class(h.pool_id), GameData.rank_index(h.rank))
	Combat.refresh_stats(h)
	h.hp = Combat.max_hp(h)
	var opens := ""
	for st in range(1, 4):
		if GameData.STAGE_RANK[st] == h.rank:
			opens = tr(" · stage %d training opens") % st
	push_toast(h, tr("Evolved — Rank %s") % tr(str(h.rank)), tr("%s is level 1 again, with +%d%% XP for %d rift runs%s.") % [tr(str(h.name.split(" the ")[0])), int(GameData.XP_BOOST * 100), GameData.XP_BOOST_RUNS, opens])
	save()
	state_changed.emit()
	return ""


## B/A/S evolutions need a rift of that rank sealed once; "" if met.
func evolve_rank_gate(rank_id: String) -> String:
	if rank_id in ["B", "A", "S"] and best_rift_rank_sealed < GameData.rift_rank_index(rank_id):
		return tr("Seal a Rank %s rift first") % tr(str(rank_id))
	return ""


## A hero topped up to a buffed max_hp during a run (a boon's +hp_pct, say)
## would otherwise be left with hp above their real max back at camp.
func _clamp_hp_to_max() -> void:
	for h in heroes:
		h.battered = false   # back at camp, the field patch-up no longer holds them back
		h.hp = min(h.hp, Combat.max_hp(h))


## The skill points `h` has spent in the tree of `kind` (keys "<kind>:<node>").
func tree_points_spent(h: Hero, kind: String) -> int:
	var total := 0
	for n in GameData.KIND_SKILL_PACKAGE.get(kind, []) + GameData.rift_nodes(kind) + ([GameData.keystone_node(kind)] if not GameData.keystone_node(kind).is_empty() else []):
		if h.skills.get(GameData.skill_storage_key(kind, str(n["id"])), false):
			total += skill_node_cost(h, kind, n)
	return total


## A finished subclass training (0.62): the hero becomes `pool_id` on `path`
## (a Legend keeps the hero's Path). Changing Path refunds the old Path
## tree's skill points when it isn't also the role tree.
func apply_subclass(h: Hero, pool_id: String, path: String = "") -> void:
	note_milestone("first Path")
	if h.path_relic != "" and path != "" and str(GameData.find_unique_relic(h.path_relic).get("path", "")) != path:
		set_down_path_relic(h)   # a relic of the old Path (0.66)
	var cls := GameData.find_class(pool_id)
	if cls.is_empty():
		return
	var new_path := GameData.path_of(pool_id)
	if new_path == "":
		new_path = path if path != "" else h.path
	var role := GameData.hero_role(h)
	var role_kind := str(GameData.ROLE_KIND.get(role, ""))
	if h.path != "" and new_path != h.path:
		var old_kind := str(GameData.PATHS.get(h.path, {}).get("kind", ""))
		if old_kind != "" and old_kind != role_kind and old_kind != str(GameData.PATHS[new_path]["kind"]):
			h.skill_points += tree_points_spent(h, old_kind)
			for key in h.skills.keys():
				if str(key).begins_with(old_kind + ":"):
					h.skills.erase(key)
	h.pool_id = pool_id
	h.path = new_path
	h.type = str(cls["type"])
	h.flavor = str(cls["flavor"])
	h.innate_kind = str(cls["kind"])
	h.innate_value = Combat.hero_innate_value(cls, GameData.rank_index(h.rank))
	h.name = "%s the %s" % [h.name.split(" the ")[0], str(cls["name"]).trim_prefix("The ")]
	Combat.refresh_stats(h)
	h.hp = Combat.max_hp(h)
	var st := GameData.subclass_stage(pool_id)
	push_toast(h, tr("Trained: %s") % tr(str(cls["name"])), tr("%s is a %s now (%s, stage %d).") % [tr(str(h.name.split(" the ")[0])), tr(str(cls["name"])), tr(str(GameData.PATHS[new_path]["name"])), st])
	if st == 2:   # the Path's first fork into a calling: a scene (the Guildhold Chronicle)
		var scene := str(GameData.CALLING_SCENES.get(GameData.hero_voice(h), GameData.CALLING_SCENES["stoic"]))
		if hesper_posted() and scene.contains("Hesper"):   # she's at the forty-first post
			scene = str(GameData.CALLING_SCENES["stoic"])
		pending_stories.append({"title": tr("A calling: %s") % tr(str(cls["name"])), "subtitle": tr(str(h.name)),
			"text": tr(scene) % [tr(str(h.name.split(" the ")[0])), tr(str(cls["name"]))]})


## A hero from before Paths (save version < 4): their subclass becomes a
## trained stage of its Path, level 1-10 within their rank, Seasoned for every
## rank above F, skill points refunded at the new per-rank budget, and any
## attribute points the new budget adds over what they already spent.
func migrate_hero_to_paths(h: Hero) -> void:
	if h.is_champion:
		return
	var ri := GameData.rank_index(h.rank)
	h.level = clampi(h.level, 1, 10)
	h.seasoned = ri
	var role := GameData.hero_role(h)
	if not GameData.is_base_class(h.pool_id):
		h.path = GameData.path_of(h.pool_id)
		if h.path == "":   # a Legend: the role's first Path
			h.path = str(GameData.role_paths(role)[0])
		var cls := GameData.find_class(h.pool_id)
		h.name = "%s the %s" % [h.name.split(" the ")[0], str(cls.get("name", role.capitalize())).trim_prefix("The ")]
	h.prior_pool_id = ""
	h.prior_innate_kind = ""
	h.prior_innate_value = 0.0
	h.skills = {}
	h.skill_points = maxi(0, GameData.sp_budget(ri, h.level) - (GameData.ABILITY_AWAKENING_COST if h.ability_awakened else 0))
	var base := GameData.role_attrs(role)
	var spent := 0
	for a in GameData.ATTRIBUTES:
		spent += int(h.attrs.get(a, base[a])) - int(base[a])
	spent -= h.attr_trained
	h.attr_points = maxi(h.attr_points, GameData.attr_budget(ri, h.level) - spent)
	Combat.refresh_stats(h)
	h.hp = mini(maxi(h.hp, 1), Combat.max_hp(h))


## `kind` identifies which of the hero's unlocked trees `skill_id` belongs
## to (a bare node id — "cap", "mastery", ...) — ignored for the universal
## Tier-1 roots ("edge"/"hide"), which are shared across every tree.
func learn_skill(hero_id: String, kind: String, skill_id: String) -> String:
	var h := find_hero(hero_id)
	if not h:
		return ""
	var n := GameData.find_skill_node(kind, skill_id, h.cls_id)
	var key := GameData.skill_storage_key(kind, skill_id)
	if n.is_empty() or h.skills.get(key, false):
		return ""
	var gate := GameData.node_lock(h, kind, n)
	if gate != "":
		return gate
	for req in n["requires"]:
		if not h.skills.get(GameData.skill_storage_key(kind, req), false):
			return tr("Learn the prerequisite skill(s) first")
	if not n.get("requires_any", []).is_empty() and not n["requires_any"].any(func(r): return h.skills.get(GameData.skill_storage_key(kind, r), false)):
		return tr("Master one of this tree's paths first")
	for excl in n.get("excludes", []):
		if h.skills.get(GameData.skill_storage_key(kind, excl), false):
			return tr("Locked out — you already chose the other path")
	if n.has("rift_rank") and best_rift_rank_sealed < GameData.rift_rank_index(str(n["rift_rank"])):
		return tr("Seal a Rank %s or higher rift first") % tr(str(n["rift_rank"]))
	if n.get("stone", false) and crystals < GameData.STONEBOUND_CRYSTALS:
		return tr("Needs %d Essence") % GameData.STONEBOUND_CRYSTALS
	var cost := skill_node_cost(h, kind, n)
	if h.skill_points < cost:
		return tr("Not enough Skill Points")
	h.skill_points -= cost
	if n.get("stone", false):
		crystals -= GameData.STONEBOUND_CRYSTALS
	h.skills[key] = true
	save()
	state_changed.emit()
	return ""


## Spends SP once to make a hero's existing Active Ability trigger more
## often (see GameData's Ability Awakening doc comment) — a second SP sink
## next to the skill tree, not a replacement for it. One-time per hero:
## already-awakened is a no-op refusal, not a stacking cooldown reduction.
## A Tier-3 fork costs 1 SP less (never below 1) for a hero whose trait
## already leans into its stat, or whose scar the fork would shore up.
func skill_node_cost(h: Hero, kind: String, n: Dictionary) -> int:
	var cost := int(n.get("cost", 0))
	if int(n.get("tier", 0)) == 3 and fork_discounted(h, str(n.get("kind", ""))):
		cost = max(1, cost - 1)
	return cost


## A quirk that leans into `stat` (a boost, or a scar that wounds it) makes
## that fork's tier-3 node cheaper.
func fork_discounted(h: Hero, stat: String) -> bool:
	for q in h.quirks:
		var t := GameData.quirk(q)
		var v := float(t.get("stats", {}).get(stat, 0.0))
		if (v > 0.0 and t["origin"] != "scar") or (v < 0.0 and t["origin"] == "scar"):
			return true
	return false


func awaken_ability(hero_id: String) -> String:
	var h := find_hero(hero_id)
	if not h:
		return ""
	if not Combat.qualifies_for_ability(h):
		return tr("This hero has no Active Ability yet")
	if h.ability_awakened:
		return tr("Already awakened")
	if h.skill_points < GameData.ABILITY_AWAKENING_COST:
		return tr("Not enough Skill Points")
	h.skill_points -= GameData.ABILITY_AWAKENING_COST
	h.ability_awakened = true
	save()
	state_changed.emit()
	return ""


## For a KIND_SKILL_PACKAGE finisher's `combo_kind` field (GameData doc
## comment above KIND_SKILL_PACKAGE) — true if some OTHER current-run party
## member has reached `kind`'s own Tier-3 capstone (cap or cap_alt; the
## asymmetric kinds' cap_third/no-fork shapes still resolve through "cap").
func party_has_other_kind_capstone(exclude_hero_id: String, kind: String) -> bool:
	if run.is_empty():
		return false
	for hid in run.get("hero_ids", []):
		if str(hid) == exclude_hero_id:
			continue
		var h2 := find_hero(str(hid))
		if not h2:
			continue
		if h2.skills.get(GameData.skill_storage_key(kind, "cap"), false) or h2.skills.get(GameData.skill_storage_key(kind, "cap_alt"), false):
			return true
	return false


## Real SP cost of a set of learned skill keys — sums each node's actual
## `cost`, not just a count of learned nodes (those differ, since Tier-3/4
## nodes cost more SP than Tier-1/2 ones — counting nodes instead of summing
## cost under-refunded a hero who'd learned any higher-tier node).
func _skill_keys_sp_cost(keys: Array, h: Hero = null) -> int:
	var total := 0
	for key in keys:
		var key_str := str(key)
		if not key_str.contains(":"):
			total += int(GameData.find_skill_node("", key_str).get("cost", 0))
		else:
			var parts := key_str.split(":", true, 1)
			if parts.size() == 2:
				var n := GameData.find_skill_node(parts[0], parts[1])
				total += skill_node_cost(h, parts[0], n) if h else int(n.get("cost", 0))
	return total


func respec_cost(spent_sp: int) -> int:
	return int(round(float(20 + 10 * spent_sp) * (1.0 - respec_fee_reduction())))


## Coin cost to respec a hero's `kind` tree right now (or every tree, if
## `kind` is empty) — same accounting respec_hero() itself uses, exposed so
## the UI can show the real price on the button instead of guessing.
func tree_respec_cost(h: Hero, kind: String = "") -> int:
	var target_keys: Array = []
	for key in h.skills.keys():
		if h.skills[key] and (kind == "" or str(key).begins_with("%s:" % tr(str(kind)))):
			target_keys.append(key)
	return respec_cost(_skill_keys_sp_cost(target_keys, h))


## `kind` empty respecs every tree at once (and the universal Tier-1 roots);
## given, only that one tree's own nodes clear — the universal roots and any
## other tree's progress are untouched. A hero holds at most 2 trees at once
## (see Hero.prior_pool_id), so "just this one" is a real, much cheaper
## option next to nuking everything to fix one fork choice.
func respec_hero(hero_id: String, kind: String = "") -> String:
	var h := find_hero(hero_id)
	if not h:
		return ""
	var target_keys: Array = []
	for key in h.skills.keys():
		if not h.skills[key]:
			continue
		if kind == "" or str(key).begins_with("%s:" % tr(str(kind))):
			target_keys.append(key)
	if target_keys.is_empty():
		return ""
	var spent_sp := _skill_keys_sp_cost(target_keys, h)
	var cost := respec_cost(spent_sp)
	if coins < cost:
		return tr("Need %d Gold") % cost
	coins -= cost
	h.skill_points += spent_sp
	for key in target_keys:
		h.skills.erase(key)
	save()
	state_changed.emit()
	return ""


## A Legendary item's locked_role/locked_subclasses restricts who can equip
## it — empty on both means no restriction (every normal item, and most
## Legendaries).
## Has this hero enough of the item's attribute to equip it?
func attr_req_met(it: Item, h: Hero) -> bool:
	return it.attr_req <= 0 or Combat.hero_attr(h, it.attr) - (it.attr_bonus if it.equipped_to == h.id else 0) >= it.attr_req


func auto_assign_attrs(hero_id: String) -> void:
	var h := find_hero(hero_id)
	if not h or h.attr_points <= 0:
		return
	Combat.auto_spend_attrs(h)
	save()
	state_changed.emit()


## Points a hero has put into attributes beyond their role's starting spread.
func attr_points_spent(h: Hero) -> int:
	var base := GameData.role_attrs(GameData.hero_role(h))
	var n := 0
	for a in GameData.ATTRIBUTES:
		n += int(h.attrs.get(a, GameData.ATTR_BASELINE)) - int(base[a])
	return max(n, 0)


func attr_respec_cost(h: Hero) -> int:
	return h.level * GameData.RESPEC_CRYSTALS_PER_LEVEL


## Refunds every spent attribute point for Crystals. Gear whose requirement
## the hero no longer meets comes off (otherwise a reset could keep gear on
## that the new build couldn't equip).
func respec_attrs(hero_id: String) -> String:
	var h := find_hero(hero_id)
	if not h:
		return tr("Can't reset this hero")
	var refund := attr_points_spent(h)
	if refund <= 0:
		return tr("Nothing to reset")
	var cost := attr_respec_cost(h)
	if crystals < cost:
		return tr("Not enough Essence")
	crystals -= cost
	h.attrs = GameData.role_attrs(GameData.hero_role(h))
	h.attr_points += refund
	for it in items:
		if it.equipped_to == h.id and not attr_req_met(it, h):
			it.equipped_to = ""
			it.equipped_idx = -1
	save()
	state_changed.emit()
	return ""


## Heroes on a Training Yard course.
func trainees() -> Array[Hero]:
	var out: Array[Hero] = []
	out.assign(heroes.filter(func(h): return not h.training.is_empty()))
	return out


func training_free() -> int:
	return maxi(0, training_slots() - trainees().size())


## The Essence a course costs, all days paid up front.
func train_fee(h: Hero, days: int) -> int:
	return (GameData.TRAIN_FEE + GameData.TRAIN_FEE_PER_LEVEL * h.level) * days


## The level training XP stops at: the guild's best (non-champion) hero.
func train_level_cap() -> int:
	var best := 1
	for h in heroes:
		if not h.is_champion:
			best = maxi(best, h.level)
	return best


## Sends a hero to the Training Yard: `program` is an attribute, `days` one
## of TRAIN_DAYS. "" on success, else why not. `free` waives the fee (a
## hero's own request).
func start_training(hero_id: String, program: String, days: int, free := false) -> String:
	var h := find_hero(hero_id)
	if not h or h.is_champion:
		return tr("Can't train this hero")
	if not h.training.is_empty():
		return tr("Already training")
	if not GameData.ATTRIBUTES.has(program) or not GameData.TRAIN_DAYS.has(days):
		return tr("Pick a program and a length")
	if not h.is_available() or (run.get("hero_ids", []) as Array).has(h.id):
		return tr("Not here to train")
	if training_free() <= 0:
		return tr("Every station is taken")
	var fee := 0 if free else train_fee(h, days)
	if crystals < fee:
		return tr("Not enough Essence")
	crystals -= fee
	h.training = {"program": program, "left": days, "total": days, "fee": 0, "essence": fee / days}
	save()
	state_changed.emit()
	return ""


## ---- Path relics on heroes (0.66) ----
## Heroes who could carry Path relic `uid`: the guild's heroes on its Path.
func path_relic_bearers(uid: String) -> Array:
	var pid := str(GameData.find_unique_relic(uid).get("path", ""))
	return heroes.filter(func(h): return not h.is_champion and h.path != "" and GameData.hero_path_id(h) == pid)


## Gives Path relic `uid` to hero `hero_id` (one of its bearers), or, with
## "", to the strongest bearer not carrying one; with none, to the chest. A
## relic the hero already carried goes to the chest. Returns who got it ("" = the chest).
func give_path_relic(uid: String, hero_id: String = "") -> String:
	path_relic_chest.erase(uid)
	for x in heroes:
		if x.path_relic == uid:
			x.path_relic = ""
	var bearers := path_relic_bearers(uid)
	var h: Hero = null
	if hero_id != "":
		var pick: Array = bearers.filter(func(x): return x.id == hero_id)
		h = pick[0] if not pick.is_empty() else null
	else:
		for x in bearers:
			if x.path_relic == "" and (h == null or GameData.rank_index(x.rank) * 10 + x.level > GameData.rank_index(h.rank) * 10 + h.level):
				h = x
	if h == null:
		path_relic_chest.append(uid)
		return ""
	if h.path_relic != "":
		path_relic_chest.append(h.path_relic)
	h.path_relic = uid
	return h.id


## Puts hero `h`'s Path relic in the chest (they left, or changed Path).
func set_down_path_relic(h: Hero) -> void:
	if h.path_relic != "":
		path_relic_chest.append(h.path_relic)
		h.path_relic = ""


## Passing a relic at camp (the hero page): "" or why not.
func carry_path_relic(uid: String, hero_id: String) -> String:
	if not run.is_empty() and (run.get("hero_ids", []) as Array).has(hero_id):
		return tr("They're on a rift right now")
	if not path_relic_bearers(uid).any(func(x): return x.id == hero_id):
		return tr("Only a hero of its Path can carry it")
	give_path_relic(uid, hero_id)
	save()
	state_changed.emit()
	return ""


## ---- Path Mastery (0.65) ----
## "" if `h` can train their next Mastery rank now, else why not.
func mastery_lock(h: Hero) -> String:
	if h == null or h.is_champion or h.path == "" or GameData.subclass_stage(h.pool_id) < 1:
		return tr("Train a Path first")
	if h.mastery >= GameData.MASTERY_MAX:
		return tr("Mastered")
	if h.mastery >= mastery_cap(h):
		return tr("The next Path stage opens rank %d") % (h.mastery + 1)
	if not h.training.is_empty():
		return tr("Already training")
	if not h.is_available() or (run.get("hero_ids", []) as Array).has(h.id):
		return tr("Not here to train")
	if training_free() <= 0:
		return tr("Every station is taken")
	if crystals < mastery_cost(h):
		return tr("Needs %d Essence") % mastery_cost(h)
	return ""


## The highest Mastery rank `h`'s Path stage allows (GameData.MASTERY_BY_STAGE).
func mastery_cap(h: Hero) -> int:
	return int(GameData.MASTERY_BY_STAGE[clampi(GameData.subclass_stage(h.pool_id), 0, 3)])


func mastery_cost(h: Hero) -> int:
	return GameData.MASTERY_ESSENCE * (h.mastery + 1)


## A day at the yard for the next Mastery rank. "" on success, else why not.
func train_mastery(hero_id: String) -> String:
	var h := find_hero(hero_id)
	var lock := mastery_lock(h)
	if lock != "":
		return lock
	var cost := mastery_cost(h)
	crystals -= cost
	h.training = {"program": "mastery", "left": 1, "total": 1, "fee": 0, "essence": cost}
	save()
	state_changed.emit()
	return ""


## The hero whose next Mastery rank is cheapest and trainable now (the advice), or null.
func mastery_pick() -> Hero:
	var pick: Hero = null
	for h in heroes:
		if mastery_lock(h) == "" and (pick == null or mastery_cost(h) < mastery_cost(pick)):
			pick = h
	return pick


## Calls a hero back early: the days already done are kept, the day in
## progress and its fee are lost, the days not started are refunded.
func recall_training(hero_id: String) -> int:
	var h := find_hero(hero_id)
	if not h or h.training.is_empty():
		return 0
	var days_back := maxi(0, int(h.training["left"]) - 1)
	coins += int(h.training["fee"]) * days_back   # old saves' Gold courses
	var refund := int(h.training.get("essence", 0)) * days_back
	crystals += refund
	h.training = {}
	save()
	state_changed.emit()
	return refund


## A day passes at the yard (from pass_time): +1 point in each trainee's
## program while under the cap, XP on longer courses, and the course ends.
func _train_day() -> void:
	var cap := train_level_cap()
	for h in trainees():
		var t: Dictionary = h.training
		var a := str(t["program"])
		var subclass := a.begins_with("subclass:")
		var mastery := a == "mastery"
		if not subclass and not mastery and h.attr_trained < GameData.ATTR_TRAIN_CAP:
			h.attrs[a] = int(h.attrs.get(a, GameData.ATTR_BASELINE)) + 1
			h.attr_trained += 1
		if int(t["total"]) >= 2 and h.level < cap:
			Combat.gain_xp(h, int(ceil(Combat.xp_to_next(h.level, h.rank) * GameData.TRAIN_XP_SHARE)))
		t["left"] = int(t["left"]) - 1
		if int(t["left"]) <= 0:
			h.training = {}
			if subclass:
				apply_subclass(h, a.trim_prefix("subclass:"), str(t.get("path", "")))
			elif mastery:
				h.mastery = mini(GameData.MASTERY_MAX, h.mastery + 1)
				push_toast(h, tr("Path Mastery"), tr("%s reaches Mastery %d: their Path rule is %d%% stronger.") % [tr(str(h.name.split(" the ")[0])), h.mastery, int(round(GameData.MASTERY_STEP * h.mastery * 100))])
			else:
				push_toast(h, tr("Training done"), tr("%s is back from the Training Yard.") % tr(str(h.name.split(" the ")[0])))
		h.history["trained_days"] = int(h.history.get("trained_days", 0)) + 1


func spend_attr_point(hero_id: String, a: String) -> void:
	var h := find_hero(hero_id)
	if not h or h.attr_points <= 0 or not GameData.ATTRIBUTES.has(a):
		return
	h.attrs[a] = int(h.attrs.get(a, GameData.ATTR_BASELINE)) + 1
	h.attr_points -= 1
	save()
	state_changed.emit()


func item_fits_hero(it: Item, h: Hero) -> bool:
	if it.locked_role != "" and h.cls_id != it.locked_role:
		return false
	if not it.locked_subclasses.is_empty() and not it.locked_subclasses.has(h.pool_id):
		return false
	return true
