extends "res://tests/base_test.gd"
## Attribute reset for Essence (Crystals).

func run() -> void:
	seed(5)
	GameState.active_slot = 9
	GameState.reset()
	var h := Combat.gen_hero("D", 6)
	h.id = "h1"
	GameState.heroes.append(h)
	GameState.active_slot = 9
	GameState.guild_name = "T"
	GameState.heroes.clear()
	GameState.heroes.append(h)
	var spent: int = GameState.attr_points_spent(h)
	var budget := GameData.attr_budget(GameData.rank_index("D"), 6)
	check(spent == budget, "a Rank D Lv6 hero has spent its %d points (%d)" % [budget, spent])
	GameState.crystals = 20
	check(GameState.respec_attrs("h1") == "Not enough Essence" and h.attr_points == 0, "can't afford: nothing changes")
	GameState.crystals = 80
	check(GameState.respec_attrs("h1") == "" and GameState.crystals == 20 and h.attr_points == budget, "reset refunds %d points for 60 Essence" % budget)
	check(h.attrs == GameData.role_attrs(GameData.hero_role(h)), "attrs back to the role spread")
	check(GameState.respec_attrs("h1") == "Nothing to reset", "second reset refused (nothing spent)")
	GameState.auto_assign_attrs("h1")
	GameState.crystals = 80
