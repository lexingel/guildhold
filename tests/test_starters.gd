extends "res://tests/base_test.gd"
## A new guild starts with a balanced trio, so the first step is a rift.


func run() -> void:
	for s in 5:
		seed(100 + s)
		GameState.active_slot = 9
		GameState.reset()
		GameState.hire_starters()
		var roles: Array = GameState.heroes.map(func(h): return GameData.hero_role(h))
		check(GameState.heroes.size() == 3 and GameState.heroes.all(func(h): return h.rank == "F"), "three Rank F starters (seed %d)" % s)
		check(roles.has("warrior") and roles.has("cleric") and (roles.has("ranger") or roles.has("mage")), "a warrior, a cleric and a ranged hero %s" % [roles])
		var ids := {}
		for h in GameState.heroes:
			ids[h.id] = true
		check(ids.size() == 3, "each with their own id")
		check(GameState.coins >= int(GameState.payday_forecast()["bill"]), "and the first payday is covered (%d Gold for a %d bill)" % [GameState.coins, int(GameState.payday_forecast()["bill"])])

	# The founding board (2026-10-09): six Rank F offers, every role; three
	# sign free and bring their week's wages; three free rerolls.
	seed(321)
	GameState.active_slot = 9
	GameState.reset()
	GameState.open_founding_board()
	var roles2: Array = GameState.recruit_pool.map(func(h): return GameData.hero_role(h))
	check(GameState.heroes.is_empty() and GameState.recruit_pool.size() == GameData.FOUNDING_OFFERS and GameState.recruit_pool.all(func(h): return h.rank == "F"), "six Rank F offers, nobody handed over")
	check(GameData.CLASSES.all(func(c): return roles2.has(str(c["id"]))), "every role on the founding board %s" % [roles2])
	var c0 := GameState.coins
	check(GameState.reroll_recruit_offer(GameState.recruit_pool[0].id) == "" and GameState.coins == c0 and GameState.founding_rerolls == GameData.FOUNDING_REROLLS - 1, "a founding reroll is free")
	for i in GameData.FOUNDING_PICKS:
		GameState.recruit_hero(GameState.recruit_pool[0].id)
	check(GameState.heroes.size() == 3 and not GameState.signing_founders() and GameState.coins == c0 + GameState.weekly_wages(), "three founders sign free and pay their first week")
	check(GameState.recruit_pool.size() == GameState.recruit_offer_count(), "then the usual board")
