extends "res://tests/base_test.gd"
## Fight stakes (0.68): what a fall costs from Rank C.

func _guild() -> void:
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "F"
	GameState.rifts_sealed = 5
	GameState.heroes.clear()
	GameState.items.clear()
	for i in 4:
		var h := Combat.gen_hero("B", 6)
		h.id = "f%d" % i
		h.cls_id = "warrior"
		h.quirks.clear()
		h.hp = Combat.max_hp(h)
		GameState.heroes.append(h)


func _ids() -> Array[String]:
	var out: Array[String] = []
	for h in GameState.heroes:
		out.append(h.id)
	return out


func _wear(h: Hero) -> Item:
	var it := Combat.gen_item("common", "", "B")
	it.equipped_to = h.id
	it.equipped_idx = 0
	GameState.items.append(it)
	return it


func run() -> void:
	seed(9)
	_guild()
	var h: Hero = GameState.heroes[0]
	GameState.start_ladder_rift("B", _ids(), null)
	var no_cleric := GameState.fall_scar_chance(h)
	check(is_equal_approx(no_cleric, 0.2) or GameState.current_party().any(func(x): return GameData.hero_path_id(x) in ["warding", "aegis"]), "Rank B: a 20%% scar chance (%.2f)" % no_cleric)
	GameState.heroes[3].cls_id = "cleric"
	check(GameState.fall_scar_chance(h) < no_cleric * 0.51, "a cleric in the party halves it")

	# The drop: one worn piece, back with a seal.
	var it := _wear(h)
	var lines := GameState.fall_costs(h)
	check(not GameState.items.has(it) and GameState.run["dropped"].has(h.id), "a fall leaves a worn piece in the rift")
	check(lines.any(func(l): return l.contains(it.name)), "the fight log says so")
	var second := _wear(h)
	GameState.fall_costs(h)
	check(GameState.items.has(second), "only one drop per hero per run")
	GameState.run["sealed"] = {}
	GameState.finish_run()
	check(GameState.items.any(func(x): return x.name == it.name and x.equipped_to == "") or GameState.items.size() == 2, "a seal brings it home (slot taken: to the pack)")

	var it2 := _wear(GameState.heroes[1])
	GameState.start_ladder_rift("B", _ids(), null)
	GameState.fall_costs(GameState.heroes[1])
	GameState.retreat_now()
	check(not GameState.items.any(func(x): return x.name == it2.name and x.rarity == it2.rarity and x.equipped_to == GameState.heroes[1].id), "a retreat leaves it behind")

	# Death: only from SS, only with two scars.
	var scarred: Hero = GameState.heroes[2]
	scarred.quirks.clear()
	for q in GameData.quirks_from("scar").slice(0, GameData.SCARS_MAX):
		scarred.quirks.append(str(q))
	check(not GameState.death_risk(scarred, "S") and GameState.death_risk(scarred, "SS"), "death risk only from Rank SS, with two scars")
	check(not GameState.death_risk(GameState.heroes[0], "SSS"), "no death risk with fewer scars")
	GameData.FALL_DEATH_CHANCE = 1.0
	GameState.start_ladder_rift("SS", _ids(), null)
	GameState.fall_costs(scarred)
	check(not GameState.run["hero_ids"].has(scarred.id), "a slain hero leaves the party at once")
	GameState.retreat_now()
	check(GameState.find_hero(scarred.id) == null and str(GameState.fallen[0]["name"]) == scarred.name, "and the roster at the run's end, into the memorial")
	GameData.FALL_DEATH_CHANCE = 0.5

	# The safety net.
	GameState.rifts_sealed = 2
	_wear(GameState.heroes[0])
	GameState.start_ladder_rift("SS", _ids(), null)
	check(GameState.fall_costs(GameState.heroes[0]).is_empty(), "no fall costs before three seals")
	GameState.retreat_now()
	GameState.rifts_sealed = 5
	GameState.start_ladder_rift("D", _ids(), null)
	check(GameState.fall_costs(GameState.heroes[0]).is_empty(), "no fall costs below Rank C")
	GameState.retreat_now()
	GameState.delete_slot(9)
