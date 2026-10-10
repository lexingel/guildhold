extends "res://scripts/autoload/game_state/GameStateRuns.gd"
## Riftbreaks (docs/design/riftbreak.md, numbers in GameDataBreach): a rift
## swells, counts down in days, and is either sealed in time or breaks. A
## broken rift blocks rift runs until the guild holds it (a breach rift), and
## resolve_breach() pays out or takes its toll: Gold and Essence, damaged
## buildings (see lvl()) and wounded heroes.


func breach_unlocked() -> bool:
	return campaign_act >= GameData.BREACH_UNLOCK_ACT


func breach_active() -> bool:
	return not breach.is_empty()


func breach_broken() -> bool:
	return not breach.is_empty() and bool(breach.get("broken", false))


## A broken rift has to be defended before any other rift run.
func breach_blocks_runs() -> bool:
	return breach_broken()


func breach_days_left() -> int:
	return maxi(0, int(breach.get("breaks_on", day)) - day)


func breach_rank_id() -> String:
	return str(GameData.RIFT_RANKS[int(breach.get("rank", 0))]["id"])


## Where it breaks, for text: "your camp" or the region's name.
func breach_place() -> String:
	var region := str(breach.get("region", "vale"))
	return tr("your camp") if region == "camp" else tr(str(GameData.BIOMES.get(region, GameData.BIOMES["vale"])["name"]))


func breach_warn_days() -> int:
	return GameData.BREACH_WARN + (1 if lvl("def.watch") >= 1 else 0) + (1 if lvl("def.watch") >= 3 else 0) \
		+ int(founding_rule("breach_warn", 0)) + (1 if str(branches.get("key", "")) == "broken" else 0)


## A breach rift (0.63): the breach's rank, its region when it's a rift
## region, and fixed floors with no camp, shop or campfire between them.
func start_breach_rift(hero_ids: Array[String]) -> void:
	if not breach_broken():
		return
	var rank := breach_rank_id()
	start_run(str(GameData.find_rift_rank(rank)["base"]), hero_ids, null, rank)
	if run.is_empty():
		return
	run["breach"] = true
	var region := str(breach.get("region", ""))
	if GameData.BIOMES.has(region):
		run["biome"] = region
	run["layers"] = (GameData.GATE_RIFT_LAYERS if breach.has("gate") else GameData.BREACH_RIFT_LAYERS).map(func(k): return {"options": [k]})
	run["chosen"] = {}
	run["node_kind"] = ""
	run["node_state"] = {}
	auto_resolve_single_option()
	save()
	state_changed.emit()


## Breach foes' [HP, damage] multipliers: a tide's strength over the
## tidewalls, less Wardcraft (Armory: both; Watchtower: damage).
func breach_foe_mult() -> Array:
	var m := (tide_strength() / tidewall_factor()) if breach.has("tide") else 1.0
	m *= 1.0 - 0.05 * lvl("def.armory")
	return [m, m * (1.0 - 0.04 * lvl("def.watch"))]


## A breach rift's end: the breach held or lost (resolve_breach without its
## day; the run's own day passes after), told in a toast.
func _breach_outcome(held: bool) -> void:
	var gate := breach.has("gate")
	var out := resolve_breach({"held": held}, false)
	if held:
		var text := tr("+%d Gold, +%d Essence.") % [int(out["coins"]), int(out["crystals"])]
		if out.has("laurels"):
			text += " " + tr("+%d Laurels.") % int(out["laurels"])
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("The gate held!") if gate else tr("The breach is held!"), "text": text})
	else:
		var lost := tr("Lost %d Gold and %d Essence.") % [int(out["lost_coins"]), int(out["lost_crystals"])]
		if not (out["damaged"] as Array).is_empty():
			lost += " " + tr("Damaged: %s.") % ", ".join(out["damaged"])
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("The breach overran the guild"), "text": lost})


## Rewards scale with the breach's ladder rank (and a tide's strength).
func breach_scale() -> float:
	return (1.0 + GameData.BREACH_RANK_SCALE * int(breach.get("rank", 0))) * tide_strength()


## How much the guild's tidewalls divide a tide's strength by.
func tidewall_factor() -> float:
	return 1.0 + GameData.TIDEWALL_STEP * tidewalls


## The next tidewall's [Gold, Essence].
func tidewall_cost() -> Array:
	return [int(GameData.TIDEWALL_COST[0]) + int(GameData.TIDEWALL_COST_STEP[0]) * tidewalls,
		int(GameData.TIDEWALL_COST[1]) + int(GameData.TIDEWALL_COST_STEP[1]) * tidewalls]


## "" if a tidewall can be raised now, else why not.
func tidewall_lock() -> String:
	if accord_ending != "break":
		return tr("Only a guild that broke the Accord faces the tides")
	var c := tidewall_cost()
	if coins < int(c[0]) or crystals < int(c[1]):
		return tr("Needs %d Gold and %d Essence") % [int(c[0]), int(c[1])]
	return ""


func raise_tidewall() -> String:
	var lock := tidewall_lock()
	if lock != "":
		return lock
	var c := tidewall_cost()
	coins -= int(c[0])
	crystals -= int(c[1])
	tidewalls += 1
	_news(tr("A tidewall is raised against the Open Hollow (%d in all).") % tidewalls)
	save()
	state_changed.emit()
	return ""


## How much stronger this tide is than the first (1.0 for a normal breach).
func tide_strength() -> float:
	return 1.0 + GameData.TIDE_GROWTH * int(breach.get("held_before", int(breach.get("tide", 1)) - 1))


var _resolving := false


func _on_day_passed() -> void:
	check_completion_board()
	if _resolving:
		return
	if breach.is_empty() and gate_due():   # Act VI: the Inverted City's gate, whatever the ending
		_swell_gate()
		return
	if breach.has("gate"):
		if not breach_broken() and day >= int(breach["breaks_on"]):
			breach["broken"] = true
			pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("The gate is under attack!"),
				"text": tr("Something has climbed the cords to the Inverted City's gate. Defend it before your next rift run.")})
		return
	if not breach_unlocked() or keepers():   # the Accord renewed or rewritten: the rifts stay shut
		return
	if breach.is_empty():
		if breach_next_day < 0:
			breach_next_day = day + GameData.BREACH_FIRST_DELAY
		elif day >= breach_next_day:
			_swell_breach()
		return
	if not breach_broken() and day >= int(breach["breaks_on"]):
		breach["broken"] = true
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("The rift has broken!"),
			"text": tr("Monsters pour out near %s. Defend before your next rift run.") % breach_place()})
		_news(tr("A Rank %s rift broke near %s.") % [tr(breach_rank_id()), breach_place()])


## Act VI's gate defense: due until held.
func gate_due() -> bool:
	var act := current_act()
	return not act.is_empty() and int(act["act"]) == 6 and gates_held == 0 and not pending_stories.any(func(c): return str(c.get("kind", "")) == "brannoch")


func _swell_gate() -> void:
	breach = {"rank": GameData.rift_rank_index("SS" if str(branches.get("brannoch", "")) == "freed" else "S"), "region": "city", "started": day, "breaks_on": day + GameData.GATE_WARN, "broken": false, "gate": true}
	pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("The City's gate"),
		"text": tr("Something is climbing the cords to close the Inverted City's gate. It reaches the gate in %d days: hold it.") % GameData.GATE_WARN})


## A new breach: your best sealed rank, sometimes one above if it's open.
func _swell_breach() -> void:
	if accord_ending == "break":   # the Open Hollow: a tide, stronger each time
		tide_count += 1
		var tr_idx := GameData.rift_rank_index(GameData.TIDE_RANK)
		breach = {"rank": tr_idx, "region": "camp" if tr_idx >= GameData.rift_rank_index(GameData.BREACH_CAMP_RANK) else pick_biome(),
			"started": day, "breaks_on": day + GameData.TIDE_WARN, "broken": false, "tide": tide_count, "held_before": tides_held}
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("Tide %d of the Open Hollow") % tide_count,
			"text": tr("It breaks over %s in %d days, %d%% stronger than the first. A tide can't be sealed away; it has to be held.") % [breach_place(), breach_days_left(), int(round((tide_strength() - 1.0) * 100.0))]})
		return
	var best := maxi(0, best_rift_rank_sealed)
	var idx := best
	if randf() < GameData.BREACH_UP_CHANCE and best + 1 < GameData.RIFT_RANKS.size() and ladder_rank_lock(str(GameData.RIFT_RANKS[best + 1]["id"])) == "":
		idx = best + 1
	if str(branches.get("key", "")) == "kept":   # B4: the doors know who has the key
		idx = mini(idx + 1, GameData.RIFT_RANKS.size() - 1)
	var camp := idx >= GameData.rift_rank_index(GameData.BREACH_CAMP_RANK)
	breach = {"rank": idx, "region": "camp" if camp else pick_biome(), "started": day, "breaks_on": day + breach_warn_days(), "broken": false}
	pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("A rift is swelling"),
		"text": tr("A Rank %s rift near %s breaks in %d days. Seal a Rank %s rift or higher before then, or prepare to defend.") % [tr(breach_rank_id()), breach_place(), breach_days_left(), tr(breach_rank_id())]})


## Sealing a ladder rift at or above the breach's rank closes it in time.
func _on_rift_sealed(rank_idx: int) -> void:
	if not breach_active() or breach_broken() or rank_idx < int(breach["rank"]) or breach.has("tide") or breach.has("gate"):
		return
	var ess := int(round(GameData.BREACH_PREVENT_ESSENCE * breach_scale()))
	crystals += ess
	pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("The swelling rift is closed"),
		"text": tr("Sealing that rift closed it before it broke. +%d Essence.") % ess})
	_news(tr("A swelling Rank %s rift was closed in time.") % tr(breach_rank_id()))
	_close_breach()


func _close_breach() -> void:
	breach = {}
	var wait := randi_range(GameData.BREACH_EVERY_MIN, GameData.BREACH_EVERY_MAX)
	wait -= int(founding_rule("breach_sooner", 0)) + int(year_add("breach_sooner"))   # the Hollow knows the Last of the Accord; restless years
	if sworn("long_watch"):
		wait = maxi(2, wait / 2)
	# The Accord broken: a tide breaks every week (it swells TIDE_WARN days
	# before, and holding it takes a day).
	breach_next_day = day + (GameData.TIDE_DAYS - GameData.TIDE_WARN - 1 if accord_ending == "break" else wait)


## The defense's outcome. result: {held: bool, integrity: 0-1 kept,
## fallen: [hero ids of posted heroes who fell; wounded only on a loss]}. Returns what happened, for the results screen:
## {held, coins, crystals, lost_coins, lost_crystals, damaged: [names], wounded: [names]}.
## A defense takes the guild's day.
func resolve_breach(result: Dictionary, take_day := true) -> Dictionary:
	var held := bool(result.get("held", false))
	if take_day:   # a breach rift's day passes in finish_run instead
		_resolving = true   # the day passing below mustn't tick breaches
		pass_time()   # the defense takes the day; its wounds come after
		_resolving = false
	var out := {"held": held, "coins": 0, "crystals": 0, "lost_coins": 0, "lost_crystals": 0, "damaged": [], "wounded": []}
	# Defenders who fell are only hurt for real when the defense is lost.
	for hid in ([] if held else result.get("fallen", [])):
		var h := find_hero(str(hid))
		if h and h.down_runs == 0:
			knock_out(h)
			(out["wounded"] as Array).append(h.name)
	if held:
		var keep := clampf(float(result.get("integrity", 1.0)), 0.0, 1.0)
		var quarter := 1.0 + 0.1 * lvl("def.engineering")   # Wardcraft's Quartermaster
		out["coins"] = int(round(GameData.BREACH_HELD_GOLD * breach_scale() * (0.5 + 0.5 * keep) * year_mult("breach_pay") * quarter))
		out["crystals"] = int(round(GameData.BREACH_HELD_ESSENCE * breach_scale() * (0.5 + 0.5 * keep) * year_mult("breach_pay") * quarter))
		coins += int(out["coins"])
		crystals += int(out["crystals"])
		if breach.has("gate"):
			gates_held += 1
			_news(tr("The Inverted City's gate held."))
			lore_event("gate", "held")   # the story web: relief coming
		if breach.has("tide"):
			tides_held += 1
			_add_postgame_laurels(GameData.TIDE_LAURELS, {"best_tide": tides_held})
			out["laurels"] = GameData.TIDE_LAURELS
		_news(tr("The guild held against a Rank %s Riftbreak.") % tr(breach_rank_id()))
		riftbreak_best = maxi(riftbreak_best, GameData.rift_rank_index(breach_rank_id()))
	else:
		# Never the coming payday's wages: the loss comes out of what's above the bill.
		var share: float = (GameData.TIDE_LOSS_SHARE if breach.has("tide") else GameData.BREACH_LOSS_SHARE) * (1.0 - 0.1 * lvl("def.palisade"))
		out["lost_coins"] = int(maxi(0, coins - int(payday_forecast()["bill"])) * share)
		out["lost_crystals"] = int(crystals * share)
		coins -= int(out["lost_coins"])
		crystals -= int(out["lost_crystals"])
		for k in (2 if str(breach.get("region", "")) == "camp" and lvl("def.palisade") < 5 else 1):
			var name := _damage_building()
			if name != "":
				(out["damaged"] as Array).append(name)
		_news(tr("A Rank %s Riftbreak overran the defenders.") % tr(breach_rank_id()))
	_close_breach()
	save()
	state_changed.emit()
	return out


## Damages one working Guild Management building (a level lost until
## repaired). Returns its name, or "" if nothing is built.
func _damage_building() -> String:
	var working: Array = []
	for b in GameData.BRANCHES:
		for n in b["nodes"]:
			var key := "%s.%s" % [b["id"], n["id"]]
			if lvl(key) > 0:
				working.append([key, str(n["name"])])
	if working.is_empty():
		return ""
	var pick: Array = working[randi() % working.size()]
	damaged[pick[0]] = int(damaged.get(pick[0], 0)) + 1
	return tr(str(pick[1]))


func repair_cost(key: String) -> int:
	return GameData.BREACH_REPAIR_BASE + GameData.BREACH_REPAIR_STEP * int(upgrades.get(key, 0))


## Repairs one damaged level of a building. "" on success, else why not.
func repair_building(key: String) -> String:
	if int(damaged.get(key, 0)) <= 0:
		return tr("Nothing to repair.")
	var cost := repair_cost(key)
	if coins < cost:
		return tr("Not enough Gold.")
	coins -= cost
	damaged[key] = int(damaged[key]) - 1
	if int(damaged[key]) <= 0:
		damaged.erase(key)
	save()
	state_changed.emit()
	return ""


## What ending the day will bring (the End day button, 0.59): payday, the
## trainees and the downed who are done tomorrow, a rift about to break.
func day_preview() -> Array[String]:
	var out: Array[String] = []
	var bill := weekly_wages() + upkeep()
	if days_to_payday() == 1:
		out.append(tr("Payday: a bill of %d Gold (you have %d)") % [bill, coins] if coins >= bill else tr("Payday: a bill of %d Gold, %d short") % [bill, bill - coins])
	else:
		out.append(tr("Payday in %d day%s") % [days_to_payday() - 1, GameData.pl(days_to_payday() - 1)])
	for h in trainees():
		if int(h.training["left"]) <= 1:
			out.append(tr("%s finishes training") % h.name.split(" the ")[0])
	for h in heroes:
		if h.down_runs > 0 and h.down_runs <= 1 + int(founding_rule("recover", 0)):
			out.append(tr("%s is back on their feet") % h.name.split(" the ")[0])
	if breach_active() and not breach_broken() and breach_days_left() <= 1:
		out.append(tr("The rift near %s breaks open") % breach_place())
	if not camp_omen.is_empty():   # a foretold threat strikes (0.64)
		out.append(tr("%s (foretold)") % tr(str(GameData.CAMP_EVENTS[str(camp_omen["id"])]["title"])))
	return out


# ---------------- Camp events (0.64) ----------------
## The world acts on its own days: at most one event a day (GameData.
## CAMP_EVENTS). A threat is foretold the day before. An event left
## unanswered when the next day comes takes its last option.


## Event amounts grow with the act.
func camp_scale() -> float:
	return 1.0 + 0.6 * (clampi(campaign_act, 1, 6) - 1)


func camp_gold(base: int) -> int:
	return int(round(base * camp_scale()))


func camp_day() -> void:
	if not run.is_empty() or heroes.is_empty():
		return   # a day passing mid-rift (carrying someone out) brings no event
	if not camp_event.is_empty() and int(camp_event["day"]) < day:
		answer_camp_event(camp_event_options().size() - 1)   # no answer: the last option
	if not camp_omen.is_empty():
		if int(camp_omen["day"]) <= day:
			var id := str(camp_omen["id"])
			camp_omen = {}
			if camp_event_possible(id):
				_offer_camp_event(id)
		return
	if not camp_event.is_empty() or randf() >= GameData.CAMP_EVENT_CHANCE:
		return
	var pool: Array = []
	var total := 0.0
	for id in GameData.CAMP_EVENTS:
		var ev: Dictionary = GameData.CAMP_EVENTS[id]
		if campaign_act < 2 and str(ev["kind"]) != "opportunity":
			continue   # Act I: opportunities only
		if campaign_act < int(ev.get("min_act", 1)) or day - int(camp_event_last.get(id, -999)) < GameData.CAMP_EVENT_COOLDOWN:
			continue
		if not camp_event_possible(id):
			continue
		pool.append(id)
		total += float(ev["weight"])
	if pool.is_empty():
		return
	var roll := randf() * total
	var pick := str(pool[0])
	for id in pool:
		roll -= float(GameData.CAMP_EVENTS[id]["weight"])
		if roll <= 0.0:
			pick = str(id)
			break
	camp_event_last[pick] = day
	if str(GameData.CAMP_EVENTS[pick]["kind"]) == "threat":
		camp_omen = {"id": pick, "day": day + 1}
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("An omen"), "text": tr(str(GameData.CAMP_EVENTS[pick]["omen"])) + " " + tr("Something will come of it tomorrow.")})
		_news(tr(str(GameData.CAMP_EVENTS[pick]["omen"])))
	else:
		_offer_camp_event(pick)


## Whether event `id` can happen with the guild as it is.
func camp_event_possible(id: String) -> bool:
	match id:
		"smith":
			return _camp_smith_item() != null
		"rival_buyer":
			return _camp_spare_item() != null and rival_name != ""
		"visitor":
			return not _camp_trainees().is_empty()
		"wanderer":
			return heroes.size() < hero_slot_cap()
		"fire", "storm":
			return not _built_buildings().is_empty()
	return true


func _offer_camp_event(id: String) -> void:
	var data := {}
	match id:
		"merchant":
			var wares: Array = []
			for rar in ["rare", "rare", "epic"]:
				var it := Combat.gen_item(rar, "", str(GameData.RIFT_RANKS[clampi(best_rift_rank_sealed, 0, GameData.RIFT_RANKS.size() - 1)]["id"]) if best_rift_rank_sealed >= 0 else "F")
				wares.append({"item": it.to_dict(), "price": camp_gold(35 if rar == "rare" else 80), "sold": false})
			data["wares"] = wares
		"visitor":
			data["who"] = GameData.CAMP_VISITORS[randi() % GameData.CAMP_VISITORS.size()]
			data["ids"] = _camp_trainees().slice(0, 2).map(func(h): return h.id)
		"wanderer":
			var ri := clampi(best_rift_rank_sealed + 1, 1, 5)
			var rec := Combat.gen_recruit(str(GameData.RANKS[ri]["id"]))
			data["hero"] = rec.to_dict()
			data["price"] = int(round(float(GameData.RANKS[ri]["cost"]) * 0.75))
		"peddler":   # a unique relic (0.66), else an epic item
			var ware := unique_or_epic()
			data["relic" if str(ware["loot_type"]) == "relic" else "item"] = ware["obj"].to_dict()
			data["price"] = camp_gold(160)
		"smith":
			data["item"] = _camp_smith_item().id
		"rival_buyer":
			var sp := _camp_spare_item()
			data["item"] = sp.id
			data["price"] = int(round(15.0 * float(GameData.find_rarity(sp.rarity)["mult"]) * 2.0 * camp_scale()))
		"fire", "storm":
			var built := _built_buildings()
			data["building"] = built[randi() % built.size()]
	camp_event = {"id": id, "day": day, "data": data}
	_news(camp_event_title() + ".")


func _built_buildings() -> Array:
	var out: Array = []
	for br in GameData.BRANCHES:
		for n in br["nodes"]:
			if lvl("%s.%s" % [br["id"], n["id"]]) > 0:
				out.append("%s.%s" % [br["id"], n["id"]])
	return out


func _building_name(key: String) -> String:
	for br in GameData.BRANCHES:
		for n in br["nodes"]:
			if "%s.%s" % [br["id"], n["id"]] == key:
				return tr(str(n["name"]))
	return key


## The heroes a visitor would drill: at camp, not champions, lowest level first.
func _camp_trainees() -> Array:
	var out: Array = idle_heroes().filter(func(h): return not h.is_champion and h.hp > 0)
	out.sort_custom(func(a, b): return a.level < b.level)
	return out


## The worn piece with the most forging left (a smith's half-price offer).
func _camp_smith_item() -> Item:
	var best: Item = null
	for it in items:
		if it.equipped_to != "" and forge_cost(it) > 0 and (best == null or it.forge_level < best.forge_level):
			best = it
	return best


## The best unworn item (the rival's quartermaster wants it).
func _camp_spare_item() -> Item:
	var best: Item = null
	for it in items:
		if it.equipped_to == "" and (best == null or float(GameData.find_rarity(it.rarity)["mult"]) > float(GameData.find_rarity(best.rarity)["mult"])):
			best = it
	return best


## An idle hero fit for a job: `roles` limits who ("" = anyone), strongest first.
func _camp_helper(roles: Array = []) -> Hero:
	var out: Array = idle_heroes().filter(func(h): return not h.is_champion and h.hp > 0 and (roles.is_empty() or roles.has(GameData.hero_role(h))))
	out.sort_custom(func(a, b): return Combat.power_of(a) > Combat.power_of(b))
	return out[0] if not out.is_empty() else null


func camp_event_title() -> String:
	if camp_event.is_empty():
		return ""
	return tr(str(GameData.CAMP_EVENTS[str(camp_event["id"])]["title"]))


func camp_event_text() -> String:
	var id := str(camp_event["id"])
	var d: Dictionary = camp_event.get("data", {})
	var t := tr(str(GameData.CAMP_EVENTS[id]["text"]))
	match id:
		"visitor":
			return t % tr(str(d["who"]))
		"wanderer":
			var h := Hero.from_dict(d["hero"])
			return t % [tr(h.rank), tr(str(h.cls_id.capitalize()))]
		"smith":
			var it := find_item(str(d["item"]))
			return t % (tr(it.name) if it else "?")
		"rival_buyer":
			var it2 := find_item(str(d["item"]))
			return t % [tr(rival_name), tr(it2.name) if it2 else "?"]
		"fire", "storm":
			return t % _building_name(str(d["building"]))
	return t


## [[button text, why it can't be chosen ("" when it can)], ...]; the last
## is what happens with no answer.
func camp_event_options() -> Array:
	if camp_event.is_empty():
		return []
	var id := str(camp_event["id"])
	var d: Dictionary = camp_event.get("data", {})
	var gold := func(n: int) -> String: return "" if coins >= n else tr("Needs %d Gold") % n
	var ess := func(n: int) -> String: return "" if crystals >= n else tr("Needs %d Essence") % n
	var out: Array = []
	match id:
		"merchant":
			for w in d["wares"]:
				var it := Item.from_dict(w["item"])
				out.append([tr("Buy %s (%d Gold)") % [tr(it.name), int(w["price"])], tr("Sold") if w["sold"] else gold.call(int(w["price"]))])
			out.append([tr("Send them on"), ""])
		"visitor":
			for hid in d["ids"]:
				var h := find_hero(str(hid))
				out.append([tr("Drill %s (%d Essence)") % [h.name.split(" the ")[0] if h else "?", camp_gold(40)], ess.call(camp_gold(40)) if h else tr("Gone")])
			out.append([tr("Thank them"), ""])
		"wanderer":
			out.append([tr("Hire them (%d Gold)") % int(d["price"]), tr("Roster is full.") if heroes.size() >= hero_slot_cap() else gold.call(int(d["price"]))])
			out.append([tr("Let them go"), ""])
		"peddler":
			var ware_name := str((d["relic"] if d.has("relic") else d["item"])["name"])
			out.append([tr("Buy %s (%d Gold)") % [tr(ware_name), int(d["price"])], gold.call(int(d["price"]))])
			out.append([tr("Send them on"), ""])
		"smith":
			var it3 := find_item(str(d["item"]))
			var half := int(ceil(forge_cost(it3) * 0.5)) if it3 else 0
			out.append([tr("Temper it (%d Gold)") % half, gold.call(half) if it3 and half > 0 else tr("Gone")])
			out.append([tr("Not today"), ""])
		"scholar":
			out.append([tr("Pay for the lecture (%d Gold)") % camp_gold(60), gold.call(camp_gold(60))])
			out.append([tr("Not today"), ""])
		"festival":
			out.append([tr("Pay for the feast (%d Gold)") % camp_gold(50), gold.call(camp_gold(50))])
			out.append([tr("Stay away"), ""])
		"refugees":
			out.append([tr("Shelter them (%d Gold)") % camp_gold(45), gold.call(camp_gold(45))])
			out.append([tr("Send them on"), ""])
		"debt":
			out.append([tr("Pay the debt (%d Gold)") % camp_gold(70), gold.call(camp_gold(70))])
			out.append([tr("Refuse"), ""])
		"rival_buyer":
			out.append([tr("Sell it (%d Gold)") % int(d["price"]), "" if find_item(str(d["item"])) else tr("Gone")])
			out.append([tr("Refuse"), ""])
		"fire":
			out.append([tr("Pay a bucket line (%d Gold)") % camp_gold(80), gold.call(camp_gold(80))])
			out.append(_camp_helper_option([], tr("%s fights the fire (busy today)")))
			out.append([tr("Let it burn (the building is damaged)"), ""])
		"fever":
			out.append([tr("Pay a healer (%d Gold)") % camp_gold(70), gold.call(camp_gold(70))])
			out.append(_camp_helper_option(["cleric"], tr("%s tends the sick (busy today)")))
			out.append([tr("Let it run (a hero is laid up 2 days)"), ""])
		"bandits":
			out.append([tr("Pay them off (%d Gold)") % camp_gold(60), gold.call(camp_gold(60))])
			out.append(_camp_helper_option(["warrior", "rogue"], tr("%s drives them off (busy today)")))
			out.append([tr("Let them take it (15% of the Gold above the bill)"), ""])
		"storm":
			out.append([tr("Pay to shore up (%d Gold)") % camp_gold(60), gold.call(camp_gold(60))])
			out.append(_camp_helper_option([], tr("%s holds the roof (busy today)")))
			out.append([tr("Ride it out (the building is damaged)"), ""])
		"tremor":
			out.append([tr("Hire sellswords (%d Gold)") % camp_gold(90), gold.call(camp_gold(90))])
			out.append(_camp_helper_option([], tr("%s fights it (busy today, comes back hurt; Essence)")))
			out.append([tr("Let it roam (Essence lost, the camp damaged)"), ""])
		_:
			for o in GameData.CAMP_EVENTS[id].get("opts", []):
				var only_resolve: bool = (o.get("fx", {}) as Dictionary).keys() == ["resolve"]
				if o.has("hero"):
					out.append(_camp_helper_option(o["hero"], tr(str(o["label"]))))
				elif o.has("gold") and only_resolve and not resolve_counts():   # Resolve that wouldn't count isn't sold (0.65)
					out.append([tr(str(o["label"])) % camp_gold(int(o["gold"])), tr("Resolve doesn't count yet")])
				elif o.has("gold"):
					out.append([tr(str(o["label"])) % camp_gold(int(o["gold"])), gold.call(camp_gold(int(o["gold"])))])
				elif o.has("ess"):
					out.append([tr(str(o["label"])) % camp_gold(int(o["ess"])), ess.call(camp_gold(int(o["ess"])))])
				else:
					out.append([tr(str(o["label"])), ""])
	return out


func _camp_helper_option(roles: Array, label: String) -> Array:
	var h := _camp_helper(roles)
	if h == null:
		var who := tr("No idle cleric") if roles == ["cleric"] else (tr("No idle warrior or rogue") if not roles.is_empty() else tr("No idle hero"))
		return [label % tr("A hero"), who]
	return [label % h.name.split(" the ")[0], ""]


## Takes option `k` of today's event. "" on success, else why not.
func answer_camp_event(k: int) -> String:
	note_milestone("first camp event")
	if camp_event.is_empty():
		return ""
	var opts := camp_event_options()
	if k < 0 or k >= opts.size():
		return ""
	if str(opts[k][1]) != "":
		return str(opts[k][1])
	var id := str(camp_event["id"])
	var d: Dictionary = camp_event.get("data", {})
	var last := k == opts.size() - 1
	var done := true
	var note := ""
	match id:
		"merchant":
			if not last:
				var w: Dictionary = d["wares"][k]
				coins -= int(w["price"])
				var it := Item.from_dict(w["item"])
				it.id = "it%d" % next_id
				next_id += 1
				items.append(it)
				w["sold"] = true
				note = tr("Bought: %s.") % tr(it.name)
				done = (d["wares"] as Array).all(func(x): return x["sold"])
		"visitor":
			if not last:
				var h := find_hero(str(d["ids"][k]))
				crystals -= camp_gold(40)
				if h.level < 10:
					Combat.gain_xp(h, Combat.xp_to_next(h.level, h.rank) - h.xp)
				else:
					h.attr_points += GameData.ATTR_PER_STEP
				note = tr("%s trained with %s.") % [h.name.split(" the ")[0], tr(str(d["who"]))]
		"wanderer":
			if not last:
				coins -= int(d["price"])
				var rec := Hero.from_dict(d["hero"])
				rec.id = "h%d" % next_id
				next_id += 1
				heroes.append(rec)
				note = tr("%s joins the guild.") % rec.name
		"peddler":
			if not last:
				coins -= int(d["price"])
				var ware: Variant = Relic.from_dict(d["relic"]) if d.has("relic") else Item.from_dict(d["item"])
				_grant_loot({"loot_type": "relic" if d.has("relic") else "item", "obj": ware})
				note = tr("Bought: %s.") % tr(ware.name)
		"smith":
			if not last:
				var it2 := find_item(str(d["item"]))
				var half := int(ceil(forge_cost(it2) * 0.5))
				coins += forge_cost(it2) - half   # forge_item takes the full price
				forge_item(it2.id)
				note = tr("%s is tempered.") % tr(it2.name)
		"scholar":
			if not last:
				coins -= camp_gold(60)
				for h2 in _camp_trainees():
					Combat.gain_xp(h2, int(round(Combat.xp_to_next(h2.level, h2.rank) * 0.3)))
				note = tr("Every hero at camp learned something.")
		"festival":
			if not last:
				coins -= camp_gold(50)
				for h3 in heroes:
					change_morale(h3, 10)
				add_reputation(2)
				note = tr("The guild feasts with the village: morale up.")
			else:
				for h3 in heroes:
					change_morale(h3, -3)
		"refugees":
			if not last:
				coins -= camp_gold(45)
				add_reputation(5)
				note = tr("The families are sheltered. Word travels: +5 Renown.")
		"debt":
			if not last:
				coins -= camp_gold(70)
			else:
				add_reputation(-5)
				note = tr("The guild's name suffers: -5 Renown.")
		"rival_buyer":
			if not last:
				var it4 := find_item(str(d["item"]))
				coins += int(d["price"])
				items.erase(it4)
				rival_renown += 3
				note = tr("Sold, and %s grows stronger.") % tr(rival_name)
		"fire", "storm", "fever", "bandits", "tremor":
			note = _camp_threat(id, k, d)
		_:
			note = _camp_opt(GameData.CAMP_EVENTS[id]["opts"][k])
	if note != "":
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": camp_event_title(), "text": note})
	if done:
		camp_event = {}
	save()
	state_changed.emit()
	return ""


## A data-driven option (0.66): pay, send a hero, roll its chance, apply its effects.
func _camp_opt(o: Dictionary) -> String:
	if o.has("gold"):
		coins -= camp_gold(int(o["gold"]))
	if o.has("ess"):
		crystals -= camp_gold(int(o["ess"]))
	if o.has("hero"):
		var h := _camp_helper(o["hero"])
		if h:
			h.busy_runs = maxi(h.busy_runs, 1)
	var won := not o.has("chance") or randf() < float(o["chance"])
	var notes: Array = _camp_fx(o.get("fx", {}) if won else o.get("fail", {}))
	var told := str(o.get("note" if won else "fail_note", ""))
	return tr(told) if told != "" else " ".join(notes)


## Camp effects; returns what happened, a line each.
func _camp_fx(fx: Dictionary) -> Array:
	var out: Array = []
	for k in fx:
		var v = fx[k]
		match k:
			"coins":
				coins += camp_gold(int(v))
				out.append(tr("%+d Gold.") % camp_gold(int(v)))
			"crystals":
				crystals += camp_gold(int(v))
				out.append(tr("%+d Essence.") % camp_gold(int(v)))
			"renown":
				add_reputation(int(v))
				out.append(tr("%+d Renown.") % int(v))
			"morale_all":
				for h in heroes:
					if not h.is_champion:
						change_morale(h, int(v))
				out.append(tr("Morale up.") if int(v) > 0 else tr("Morale down."))
			"resolve":
				if resolve_counts():
					next_resolve = clampi(next_resolve + int(v), -GameData.RESOLVE_MAX, GameData.RESOLVE_MAX)
					out.append(tr("%+d Resolve for the next party.") % int(v))
			"tonic":
				add_tonic("healing", int(v))
			"xp_camp":
				for h in _camp_trainees():
					_xp_share(h, float(v))
			"item", "relic":
				var lt: Dictionary = {"loot_type": "item", "obj": Combat.gen_item(str(v))} if k == "item" else unique_or_epic()
				_grant_loot(lt)
				out.append(tr("You receive: %s.") % tr(str(lt["obj"].name)))
	return out


## A threat's answer: 0 = pay, 1 = send a hero, 2 = take the loss.
func _camp_threat(id: String, k: int, d: Dictionary) -> String:
	var costs := {"fire": 80, "fever": 70, "bandits": 60, "storm": 60, "tremor": 90}
	if k == 0:
		coins -= camp_gold(int(costs[id]))
		return tr("Paid, and it passed.")
	if k == 1:
		var h := _camp_helper(["cleric"] if id == "fever" else (["warrior", "rogue"] if id == "bandits" else []))
		h.busy_runs = maxi(h.busy_runs, 1)
		var who := h.name.split(" the ")[0]
		if id == "bandits":
			var bounty := camp_gold(25)
			coins += bounty
			return tr("%s drove them off and took their purse: +%d Gold.") % [who, bounty]
		if id == "tremor":
			var ess := camp_gold(20)
			crystals += ess
			h.hp = maxi(1, int(Combat.max_hp(h) * 0.5))
			return tr("%s closed the tear, hurt but alive: +%d Essence.") % [who, ess]
		return tr("%s saw to it.") % who
	match id:
		"fire", "storm":
			damaged[str(d["building"])] = int(damaged.get(str(d["building"]), 0)) + 1
			return tr("The %s is damaged: it works a level lower until repaired.") % _building_name(str(d["building"]))
		"fever":
			var sick: Array = heroes.filter(func(x): return not x.is_champion and x.down_runs == 0 and x.hp > 0)
			sick.shuffle()
			var names: Array = []
			for x in sick.slice(0, 1):
				x.down_runs = maxi(x.down_runs, 2)
				names.append(x.name.split(" the ")[0])
			return tr("Laid up with fever for 2 days: %s.") % ", ".join(names) if not names.is_empty() else ""
		"bandits":
			var lost := int(maxi(0, coins - int(payday_forecast()["bill"])) * 0.15)
			coins -= lost
			return tr("The bandits took %d Gold.") % lost
		"tremor":
			var lost_e := int(crystals * 0.05)
			crystals -= lost_e
			var dmg := _damage_building()
			return tr("It roamed the camp: -%d Essence%s.") % [lost_e, tr(", the %s damaged") % dmg if dmg != "" else ""]
	return ""


## ---------------- Expeditions (2026-10-09 playtest) ----------------
## Idle heroes sent off the map for 1-3 days (GameData.EXPEDITIONS). They are
## away (busy_runs) the whole time, wages still run; on the last day the
## outcome is rolled: success pays in full, partial pays half and wounds one,
## failure pays nothing and wounds everyone (a perilous job can scar).
func expeditions_open() -> bool:
	return feature_unlocked("training")


func expedition_cap() -> int:
	return 1 + (1 if lvl("log.scouts") >= 3 else 0)


func expedition_def(id: String) -> Dictionary:
	for e in GameData.EXPEDITIONS:
		if str(e["id"]) == id:
			return e
	return {}


## Three postings: a safe, a hard and (from Act II) a perilous job, priced
## from the guild's own heroes: the lower third's hero power x the party size
## x EXPEDITION_NEED[tier] (the sim, 2026-10-09: priced for the next ladder
## rank, the heroes left at camp had 10-30% odds all game). Pay is a fight's
## coin and Essence per hero-day (EXPEDITION_GOLD / ESSENCE) at the rank those
## same heroes could run: the highest sealed rank whose Recommended power four
## of them reach (paid at the best rank sealed, a big bench farmed SSS pay with
## Rank F heroes: 100k Gold in 45 days). Rolled with the quest board.
func roll_expedition_board() -> void:
	expedition_board = []
	var powers: Array = heroes.filter(func(h): return not h.is_champion).map(func(h): return Combat.power_of(h))
	powers.sort()
	var ref: float = float(powers[powers.size() / 3]) if not powers.is_empty() else 50.0
	var rank := "F"
	for i in clampi(best_rift_rank_sealed + 1, 1, GameData.RIFT_RANKS.size()):
		var rid := str(GameData.RIFT_RANKS[i]["id"])
		if Combat.recommended_power("", rid) <= ref * 4.0:
			rank = rid
	var rr := GameData.find_rift_rank(rank)
	var base: Dictionary = GameData.DIFFICULTIES.filter(func(d): return str(d["id"]) == str(rr["base"]))[0]
	var coin := (float(base["coin"][0]) + float(base["coin"][1])) * 0.5 * float(rr["reward"])
	var ess := (float(base["crystal"][0]) + float(base["crystal"][1])) * 0.5 * float(rr["reward"])
	for tier in [0, 1, 2 if campaign_act >= 2 else randi() % 2]:
		var pool: Array = GameData.EXPEDITIONS.filter(func(e): return int(e["tier"]) == tier and not expedition_board.any(func(p): return str(p["id"]) == str(e["id"])))
		var e: Dictionary = pool.pick_random()
		var days := int(e["days"])
		expedition_board.append({"id": str(e["id"]), "rank": rank,
			"need": maxi(1, int(round(ref * float(e["size"]) * float(GameData.EXPEDITION_NEED[tier])))),
			"gold": int(round(coin * float(GameData.EXPEDITION_GOLD[tier]) * float(e["size"]) * days)),
			"essence": int(round(ess * float(GameData.EXPEDITION_ESSENCE[tier]) * float(e["size"]) * days))})


## What a party brings (GameData.EXPEDITION_BONUS): each class and Path once.
## {odds, odds_perilous, gold, ess, item, xp, soften: added; hurt, scar:
## multiplied; lines: ["Scout: +10% odds", ...]}.
func expedition_bonuses(hero_ids: Array) -> Dictionary:
	var out := {"odds": 0.0, "odds_perilous": 0.0, "gold": 0.0, "ess": 0.0, "item": 0.0, "xp": 0.0, "soften": 0.0, "hurt": 1.0, "scar": 1.0, "lines": []}
	var seen := {}
	for hid in hero_ids:
		var h := find_hero(str(hid))
		if h == null:
			continue
		var path := h.path if h.path != "" else GameData.path_of(h.pool_id)
		for key in [GameData.hero_role(h), path]:
			if key == "" or seen.has(key) or not GameData.EXPEDITION_BONUS.has(key):
				continue
			seen[key] = true
			var b: Dictionary = GameData.EXPEDITION_BONUS[key]
			for k in b:
				if k == "label":
					continue
				if k in ["hurt", "scar"]:
					out[k] = float(out[k]) * float(b[k])
				else:
					out[k] = float(out[k]) + float(b[k])
			(out["lines"] as Array).append(tr(str(b["label"])) + ": " + expedition_bonus_text(b))
	return out


func expedition_bonus_text(b: Dictionary) -> String:
	var bits: Array[String] = []
	for k in b:
		var v := float(b[k]) if k != "label" else 0.0
		match k:
			"odds": bits.append(tr("+%d%% odds") % int(round(v * 100)))
			"odds_perilous": bits.append(tr("+%d%% odds on a perilous job") % int(round(v * 100)))
			"gold": bits.append(tr("+%d%% Gold") % int(round(v * 100)))
			"ess": bits.append(tr("+%d%% Essence") % int(round(v * 100)))
			"item": bits.append(tr("+%d%% item chance") % int(round(v * 100)))
			"xp": bits.append(tr("+%d%% XP for the party") % int(round(v * 100)))
			"hurt": bits.append(tr("%d%% less chance of being hurt") % int(round((1.0 - v) * 100)))
			"scar": bits.append(tr("%d%% less chance of a scar") % int(round((1.0 - v) * 100)))
			"soften": bits.append(tr("a failure turns partial half the time"))
	return ", ".join(bits)


## The odds for `hero_ids` on posting `p`: 50% at the Need, +50% per Need over
## it, plus what the party brings; 10-95%.
func expedition_chance(p: Dictionary, hero_ids: Array) -> float:
	var power := 0
	for hid in hero_ids:
		var h := find_hero(str(hid))
		if h:
			power += Combat.power_of(h)
	var bon := expedition_bonuses(hero_ids)
	var perilous := int(expedition_def(str(p["id"])).get("tier", 0)) >= 2
	var c := 0.5 + 0.5 * (float(power) / maxf(1.0, float(p["need"])) - 1.0) + float(bon["odds"]) + (float(bon["odds_perilous"]) if perilous else 0.0)
	return clampf(c, 0.1, 0.95)


## "" on success, else why not.
func send_expedition(index: int, hero_ids: Array) -> String:
	if not expeditions_open():
		return tr("Expeditions open with the Training Yard")
	if index < 0 or index >= expedition_board.size():
		return tr("No such posting")
	if expeditions.size() >= expedition_cap():
		return tr("Every expedition party is out")
	var p: Dictionary = expedition_board[index]
	var e := expedition_def(str(p["id"]))
	if hero_ids.is_empty() or hero_ids.size() > int(e["size"]):
		return tr("Send 1 to %d heroes") % int(e["size"])
	for hid in hero_ids:
		var h := find_hero(str(hid))
		if h == null or h.is_champion or not h.is_available():
			return tr("Someone can't go")
	var days := int(e["days"])
	for hid in hero_ids:
		find_hero(str(hid)).busy_runs = days
	var x := p.duplicate()
	x["hero_ids"] = hero_ids.duplicate()
	x["left"] = days
	x["total"] = days
	x["chance"] = expedition_chance(p, hero_ids)
	expeditions.append(x)
	expedition_board.remove_at(index)
	save()
	state_changed.emit()
	return ""


func _expedition_day() -> void:
	for x in expeditions.duplicate():
		x["left"] = int(x["left"]) - 1
		if int(x["left"]) <= 0:
			expeditions.erase(x)
			_expedition_return(x)


func _expedition_return(x: Dictionary) -> void:
	var e := expedition_def(str(x["id"]))
	var tier := int(e.get("tier", 0))
	var party: Array[Hero] = []
	for hid in x["hero_ids"]:
		var h := find_hero(str(hid))
		if h:
			party.append(h)
	if party.is_empty():
		return
	var bon := expedition_bonuses(x["hero_ids"])
	var r := randf()
	var chance := float(x.get("chance", 0.5))
	var outcome := "success" if r < chance else ("partial" if r < chance + (1.0 - chance) * 0.5 else "failure")
	if outcome == "failure" and randf() < float(bon["soften"]):
		outcome = "partial"
	var share: float = float({"success": 1.0, "partial": 0.5, "failure": 0.0}[outcome])
	var lines: Array[String] = []
	var g := int(round(int(x["gold"]) * share * (1.0 + float(bon["gold"]))))
	var ess := int(round(int(x["essence"]) * share * (1.0 + float(bon["ess"]))))
	if g > 0:
		coins += g
		lines.append(tr("+%d Gold") % g)
	if ess > 0:
		crystals += ess
		lines.append(tr("+%d Essence") % ess)
	var item_roll: Array = GameData.EXPEDITION_ITEM[tier]
	if outcome == "success" and str(item_roll[0]) != "" and randf() < float(item_roll[1]) + float(bon["item"]):
		var it := Combat.gen_item(str(item_roll[0]), "", str(x.get("rank", "")))
		_grant_loot({"loot_type": "item", "obj": it})
		lines.append(tr("found: %s") % tr(str(it.name)))
	# Wounds: one hero on a partial, everyone on a failure; a cleric and some Paths lower the odds.
	var guard := float(bon["hurt"])
	var hurt: Array[Hero] = []
	if outcome == "partial":
		hurt.append(party.pick_random())
	elif outcome == "failure":
		hurt.assign(party.filter(func(_h): return randf() < guard))
	for h in hurt:
		h.hp = mini(h.hp, maxi(1, int(round(Combat.max_hp(h) * GameData.EXPEDITION_WOUND_HP))))
		lines.append(tr("%s comes back hurt") % tr(str(h.name.split(" the ")[0])))
		if outcome == "failure" and tier >= GameData.EXPEDITION_SCAR_TIER and not has_wing("healers") and randf() < GameData.EXPEDITION_SCAR_CHANCE * guard * float(bon["scar"]):
			var scar := Combat.roll_scar(h)
			if scar != "":
				h.quirks.append(scar)
				lines.append(tr("%s keeps a scar: %s") % [tr(str(h.name.split(" the ")[0])), tr(str(scar))])
	# The road teaches: a third of a level a day, as at the Training Yard.
	var cap := train_level_cap()
	for h in party:
		if h.level < cap:
			Combat.gain_xp(h, int(ceil(Combat.xp_to_next(h.level, h.rank) * GameData.TRAIN_XP_SHARE * int(x["total"]) * (1.0 + float(bon["xp"])))))
		h.history["expeditions"] = int(h.history.get("expeditions", 0)) + 1
	var title := tr(str(e.get("name", "")))
	var head: String = {"success": tr("Dobbs: \"They're back, and it paid.\""), "partial": tr("Dobbs: \"Back with half of it and a limp.\""), "failure": tr("Dobbs: \"Back with nothing. Get the bandages.\"")}[outcome]
	if lines.is_empty():
		lines.append(tr("nothing to show for it"))
	push_toast(party[0], title, head + " " + ", ".join(lines) + ".")
	_news(tr("Expedition: %s, %s.") % [title, {"success": tr("a success"), "partial": tr("half done"), "failure": tr("a failure")}[outcome]])
