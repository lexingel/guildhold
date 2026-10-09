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
	GameState.delete_slot(9)
