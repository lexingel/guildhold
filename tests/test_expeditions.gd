extends "res://tests/base_test.gd"
## Expeditions (2026-10-09 playtest): the board, sending, the days away and
## the three outcomes.

func run() -> void:
	seed(11)
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "T"
	GameState.heroes.clear()
	for i in 3:
		var h := Combat.gen_hero("D", 4)
		h.id = "h%d" % (i + 1)
		h.hp = Combat.max_hp(h)
		GameState.heroes.append(h)
	GameState.rifts_sealed = 0
	check(not GameState.expeditions_open(), "closed before the Training Yard")
	GameState.rifts_sealed = 2
	check(GameState.expeditions_open(), "open with the Training Yard")
	GameState.campaign_act = 2
	GameState.roll_expedition_board()
	var tiers: Array = GameState.expedition_board.map(func(p): return int(GameState.expedition_def(str(p["id"]))["tier"]))
	check(GameState.expedition_board.size() == 3 and tiers == [0, 1, 2], "three postings: safe, hard, perilous")
	check(GameState.expedition_board.all(func(p): return int(p["need"]) > 0 and int(p["gold"]) > 0), "each has a Need and pays Gold")

	# Odds rise with power; too many heroes is refused.
	var safe: Dictionary = GameState.expedition_board[0]
	var one := GameState.expedition_chance(safe, ["h1"])
	var size := int(GameState.expedition_def(str(safe["id"]))["size"])
	var more := GameState.expedition_chance(safe, ["h1", "h2"]) if size >= 2 else one
	check(one >= 0.1 and one <= 0.95 and more >= one, "odds between 10%% and 95%%, more heroes better (%d%% -> %d%%)" % [int(one * 100), int(more * 100)])
	check(GameState.send_expedition(0, ["h1", "h2", "h3", "h1"]) != "", "too many heroes is refused")
	# Every class and Path brings something, once per party.
	var war := Combat.gen_recruit("F", "warrior")
	var war2 := Combat.gen_recruit("F", "warrior")
	var rog := Combat.gen_recruit("F", "rogue")
	GameState.heroes.append_array([war, war2, rog])
	var b1 := GameState.expedition_bonuses([war.id])
	var b2 := GameState.expedition_bonuses([war.id, war2.id])
	var b3 := GameState.expedition_bonuses([war.id, rog.id])
	check(float(b1["odds"]) > 0.0 and float(b2["odds"]) == float(b1["odds"]) and float(b3["gold"]) > 0.0 and (b3["lines"] as Array).size() == 2, "a warrior adds odds (once), a rogue adds Gold")
	check(GameData.CLASSES.all(func(c): return GameData.EXPEDITION_BONUS.has(str(c["id"]))) and GameData.PATHS.keys().all(func(k): return GameData.EXPEDITION_BONUS.has(k)), "every class and every Path has a bonus")
	for h in [war, war2, rog]:
		GameState.heroes.erase(h)

	# Send the safe job: the heroes are away until it returns.
	var days := int(GameState.expedition_def(str(safe["id"]))["days"])
	var c0 := GameState.coins
	GameState.find_hero("h1").level = 2   # under the best hero's level: the road can teach them
	var xp0 := GameState.find_hero("h1").xp + GameState.find_hero("h1").level * 1000
	check(GameState.send_expedition(0, ["h1"]) == "" and not GameState.find_hero("h1").is_available(), "sent: the hero is away")
	check(GameState.send_expedition(0, ["h2"]) == "Every expedition party is out", "one party out at a time")
	GameState.expeditions[0]["chance"] = 1.0   # a sure thing, to check the pay
	for d in days:
		GameState.pass_time()
	var h1 := GameState.find_hero("h1")
	check(GameState.expeditions.is_empty() and h1.is_available(), "back after %d day%s" % [days, "" if days == 1 else "s"])
	check(h1.xp + h1.level * 1000 > xp0 and int(h1.history.get("expeditions", 0)) == 1, "the road teaches")
	# The pay, without a day's other business: a sure success.
	GameState.roll_expedition_board()
	GameState.send_expedition(0, ["h2"])
	GameState.expeditions[0]["chance"] = 1.0
	var pay := int(GameState.expeditions[0]["gold"])
	c0 = GameState.coins
	for d in 3:
		GameState._expedition_day()
	check(GameState.expeditions.is_empty() and GameState.coins >= c0 + pay, "a success pays its Gold (+%d)" % (GameState.coins - c0))

	# A perilous failure: everyone hurt, and it can scar.
	var hurt_scarred := false
	for trial in 20:
		GameState.roll_expedition_board()
		for h in GameState.heroes:
			h.hp = Combat.max_hp(h)
			h.busy_runs = 0
			h.quirks = h.quirks.filter(func(q): return GameData.quirk(q).get("origin", "") != "scar")
		var ids: Array = []
		for h in GameState.heroes:
			if GameData.hero_role(h) != "cleric":
				ids.append(h.id)
		var peril: int = GameState.expedition_board.find(GameState.expedition_board.filter(func(p): return int(GameState.expedition_def(str(p["id"]))["tier"]) == 2)[0])
		ids = ids.slice(0, 3)
		GameState.send_expedition(peril, ids)
		GameState.expeditions[0]["chance"] = 0.0
		var g0 := GameState.coins
		for d in 3:
			GameState._expedition_day()
		var all_hurt := true
		var scarred := false
		for hid in ids:
			var h := GameState.find_hero(str(hid))
			all_hurt = all_hurt and h.hp < Combat.max_hp(h)
			scarred = scarred or h.quirks.any(func(q): return GameData.quirk(q).get("origin", "") == "scar")
		if all_hurt and GameState.coins == g0 and scarred:
			hurt_scarred = true
			break
	check(hurt_scarred, "a perilous failure hurts the party and can leave a scar")

	# The card warns when sending would leave fewer than four to cover a hero
	# ready for a Path course (0.67.3: the sim's casual guilds stalled on it).
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame
	GameState.active_slot = 9
	GameState.reset()
	GameState.rifts_sealed = 2
	GameState.campaign_act = 2
	GameState.coins = 50000
	GameState.crystals = 50000
	for i in 5:
		var r := Combat.gen_recruit("D")
		r.id = "r%d" % i
		r.hp = Combat.max_hp(r)
		GameState.heroes.append(r)
	var ready: Array = GameState.heroes.filter(func(h): return GameState.subclass_training_options(h).any(func(o): return str(o["lock"]) == ""))
	check(not ready.is_empty(), "a Rank D recruit is ready for a Path course")
	GameState.roll_expedition_board()
	var warned := func(pick: Array) -> bool:
		main._exp_pick = {0: pick}
		var v := VBoxContainer.new()
		main._render_expeditions(v)
		var hit := v.find_children("*", "Label", true, false).any(func(l): return str(l.text).contains("ready for a Path course"))
		v.free()
		return hit
	var spare: Array = GameState.heroes.filter(func(h): return h != ready[0]).map(func(h): return h.id)
	check(not warned.call([]), "no warning before anyone is picked")
	check(warned.call([spare[0]]), "picking one of five warns: three left while the fifth trains")
	main.queue_free()
	GameState.delete_slot(9)
