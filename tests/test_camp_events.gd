extends "res://tests/base_test.gd"
## Camp events (0.64): at most one a day; Act I sees opportunities only; a
## threat is foretold the day before; every event is a choice, and one left
## unanswered takes its last option the next day.


func _hero(role: String, rank := "C", level := 5) -> Hero:
	var h := Combat.gen_hero(rank, level)
	h.cls_id = role
	h.pool_id = role
	h.path = ""
	h.id = "h%d" % GameState.next_id
	GameState.next_id += 1
	Combat.refresh_stats(h)
	h.hp = Combat.max_hp(h)
	GameState.heroes.append(h)
	return h


func run() -> void:
	seed(21)
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "T"
	var war := _hero("warrior")
	var cle := _hero("cleric")
	GameState.coins = 100000   # paid all along: no walkouts
	GameState.crystals = 5000
	GameState.best_rift_rank_sealed = 2

	# Act I: only opportunities, and never more than one at a time.
	GameState.campaign_act = 1
	var kinds := {}
	for i in 60:
		GameState.pass_time()
		if not GameState.camp_event.is_empty():
			kinds[str(GameData.CAMP_EVENTS[str(GameState.camp_event["id"])]["kind"])] = true
		if not GameState.camp_omen.is_empty():
			kinds["threat"] = true
	check(kinds.keys() == ["opportunity"], "Act I: opportunities only (%s)" % [kinds.keys()])

	# A threat: foretold, it strikes the next day with three answers. (Clear
	# what the 60 days left behind: requests, courses, fevers.)
	GameState.hero_request = {}
	GameState.rival_event = {}
	GameState.heroes.clear()   # the rival may have poached some over those days
	GameState.heroes.append(war)
	GameState.heroes.append(cle)
	for x in GameState.heroes:
		x.busy_runs = 0
		x.down_runs = 0
		x.training = {}
		x.hp = Combat.max_hp(x)
	GameState.campaign_act = 3
	GameState.camp_event = {}
	GameState.upgrades["ops.drill"] = 2
	GameState.camp_omen = {"id": "fire", "day": GameState.day + 1}
	check(GameState.day_preview().any(func(l): return str(l).contains("Fire!")), "the day preview names a foretold threat")
	GameState.pass_time()
	check(str(GameState.camp_event.get("id", "")) == "fire" and GameState.camp_omen.is_empty(), "the foretold fire strikes")
	var opts: Array = GameState.camp_event_options()
	check(opts.size() == 3 and str(opts[1][1]) == "", "pay, send a hero, or let it burn")
	var g0 := GameState.coins
	check(GameState.answer_camp_event(0) == "" and GameState.coins == g0 - GameState.camp_gold(80) and GameState.camp_event.is_empty(), "paying puts it out")

	# Unanswered: the last option applies the next day (here: a damaged building).
	GameState.camp_event = {"id": "storm", "day": GameState.day, "data": {"building": "ops.drill"}}
	GameState.pass_time()
	check(GameState.lvl("ops.drill") == 1, "an unanswered storm damages its building")

	# A hero sent to a threat is busy for the day; the fever needs a cleric.
	GameState.camp_event = {"id": "fever", "day": GameState.day, "data": {}}
	opts = GameState.camp_event_options()
	check(str(opts[1][0]).contains(cle.name.split(" the ")[0]), "the fever: a cleric tends the sick")
	GameState.answer_camp_event(1)
	check(cle.busy_runs == 1 and cle.is_away(), "and is busy for the day")
	GameState.pass_time()
	check(cle.busy_runs == 0, "back the next day")

	# Bandits with a warrior home: driven off, for a purse.
	if not GameState.heroes.has(war):   # the rival's poaching is another test's business
		GameState.heroes.append(war)
	GameState.camp_event = {"id": "bandits", "day": GameState.day, "data": {}}
	g0 = GameState.coins
	GameState.answer_camp_event(1)
	check(GameState.coins == g0 + GameState.camp_gold(25) and war.busy_runs == 1, "a warrior drives the bandits off, for a purse")

	# Opportunities: the merchant's wares and a wandering recruit.
	GameState._offer_camp_event("merchant")
	var n0 := GameState.items.size()
	g0 = GameState.coins
	GameState.answer_camp_event(0)
	check(GameState.items.size() == n0 + 1 and GameState.coins < g0 and not GameState.camp_event.is_empty(), "buying one ware leaves the merchant open")
	check(str(GameState.camp_event_options()[0][1]) == "Sold", "the sold piece is gone")
	GameState.answer_camp_event(3)
	check(GameState.camp_event.is_empty(), "sending the merchant on ends it")
	var h0 := GameState.heroes.size()
	GameState._offer_camp_event("wanderer")
	GameState.answer_camp_event(0)
	check(GameState.heroes.size() == h0 + 1 and GameData.is_base_class(GameState.heroes[-1].pool_id), "a wandering recruit joins, a base class")

	# A visitor drills a hero up a level.
	GameState._offer_camp_event("visitor")
	var trainee := GameState.find_hero(str(GameState.camp_event["data"]["ids"][0]))
	var lv := trainee.level
	GameState.answer_camp_event(0)
	check(trainee.level == lv + 1 or lv >= 10, "the visitor drills a hero up a level")

	# Saved and loaded with the guild.
	GameState.camp_omen = {"id": "storm", "day": GameState.day + 1}
	GameState._offer_camp_event("festival")
	GameState.save()
	GameState.load_save()
	check(str(GameState.camp_event.get("id", "")) == "festival" and str(GameState.camp_omen.get("id", "")) == "storm", "today's event and a foretold threat survive a save")
	GameState.camp_event = {}
	GameState.camp_omen = {}
