extends "res://tests/base_test.gd"
## Paths (0.62): base-class recruits, levels 1-10 per rank, evolving resets
## the level, subclass training at the Training Yard (stages at D/B/S,
## unlocks, changing Path), the role + Path trees, and old-save migration.


func _guild() -> void:
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "T"
	GameState.coins = 100000
	GameState.crystals = 100000


func run() -> void:
	seed(62)
	_guild()

	# --- Data: every subclass sits in exactly one Path stage, or is a role's Legend.
	var placed := {}
	for pid in GameData.PATHS:
		var p: Dictionary = GameData.PATHS[pid]
		check((p["stages"] as Array).size() == 3 and (p["stages"] as Array).all(func(st): return not (st as Array).is_empty()), "%s has a subclass at every stage" % pid)
		for st in p["stages"]:
			for sid in st:
				check(not placed.has(sid), "%s is in one Path" % sid)
				placed[sid] = true
				check(str(GameData.find_class(str(sid))["role"]) == str(p["role"]), "%s matches its Path's role" % sid)
				check(GameData.SUBCLASS_TWIST.has(sid), "%s has a Twist" % sid)
	for role in GameData.LEGENDS:
		placed[GameData.LEGENDS[role]] = true
	check(placed.size() == GameData.CLASS_POOL.size(), "all %d subclasses placed (%d)" % [GameData.CLASS_POOL.size(), placed.size()])
	check(GameData.SUBCLASS_UNLOCK.size() == GameData.CLASS_POOL.size(), "every subclass has an unlock entry")

	# --- Recruits are base classes with their lower ranks' points.
	var r := Combat.gen_recruit("C")
	check(GameData.is_base_class(r.pool_id) and r.name.ends_with(r.cls_id.capitalize()), "a recruit is a base class (%s)" % r.name)
	check(r.level == 1 and r.attr_points == GameData.attr_budget(3, 1) and r.skill_points == GameData.sp_budget(3, 1) + 3 * GameData.HIRED_SP_PER_RANK, "a Rank C hire brings %d attribute and %d skill points" % [r.attr_points, r.skill_points])
	check(GameData.subclass_stage(r.pool_id) == 0 and not Combat.qualifies_for_ability(r), "a base class has no Path stage and no Ability")
	check(GameData.hero_role_skills(r).size() == 2 and GameData.hero_role_skills(Combat.gen_recruit("F")).size() == 1, "role skills by rank: one at F, both from E")

	# --- Levels 1-10 per rank; evolving resets to 1.
	var h := Combat.gen_recruit("F", "warrior")
	GameState.heroes.append(h)
	var p1 := Combat.power_of(h)
	while h.level < 10:
		Combat.gain_xp(h, Combat.xp_to_next(h.level, h.rank))
	check(h.level == 10 and h.skill_points == GameData.sp_budget(0, 10) and h.attr_points == GameData.attr_budget(0, 10), "levels 4, 7, 10 give the rank's points")
	Combat.gain_xp(h, 99999)
	check(h.level == 10, "level stops at 10 within a rank")
	check(Combat.power_of(h) > p1, "levels make the hero stronger")
	var hp10 := h.base_hp
	check(GameState.evolve_hero(h.id) == "" and h.rank == "E" and h.level == 1 and h.seasoned == 1, "evolving: Rank E, level 1, Seasoned")
	check(h.base_hp >= hp10, "the new rank's level 1 is at least as strong (%d -> %d)" % [hp10, h.base_hp])
	check(GameState.coins == 100000 - int(GameData.EVOLVE_COST["E"][0]) and GameState.crystals == 100000 - int(GameData.EVOLVE_COST["E"][1]), "evolving costs Gold and Essence")
	var xp0 := h.xp
	Combat.gain_xp(h, 10)
	check(h.xp - xp0 == int(round(10 * GameState.xp_mult() * (1.0 + GameData.XP_BOOST))), "+%d%% XP after evolving" % int(GameData.XP_BOOST * 100))
	var raised := Combat.gen_recruit("E", "warrior")
	raised.pool_id = h.pool_id
	Combat.refresh_stats(raised)
	check(h.base_hp > raised.base_hp, "a raised hero outgrows a hired one of the same rank (%d vs %d)" % [h.base_hp, raised.base_hp])

	# --- Subclass training: opens at D, unlocks, days at the yard.
	check(GameState.subclass_training_options(h).all(func(o): return str(o["lock"]) != ""), "Rank E can't train yet")
	h.rank = "D"
	GameState.check_subclass_unlocks()
	var opts: Array = GameState.subclass_training_options(h)
	check(opts.size() == GameData.role_paths("warrior").reduce(func(n, pid): return n + (GameData.PATHS[pid]["stages"][0] as Array).size(), 0), "stage 1 offers every warrior Path's first stage")
	var open_ids: Array = opts.filter(func(o): return str(o["lock"]) == "").map(func(o): return str(o["id"]))
	check(open_ids.has("footman") and open_ids.has("squire") and not open_ids.has("bulwark"), "first subclasses open, the rest locked (%s)" % str(open_ids))
	check(str(GameState.subclass_unlock_text("bulwark")).contains("10"), "a lock says what opens it")
	var g0 := GameState.coins
	check(GameState.start_subclass_training(h.id, "footman") == "" and not h.training.is_empty() and GameState.coins == g0 - 500, "training starts and is paid up front")
	for d in 3:
		GameState._train_day()
	check(h.pool_id == "footman" and h.path == "shieldwall" and h.name.ends_with("Footman") and h.training.is_empty(), "three days later: a Footman on Shieldwall")
	check(Combat.qualifies_for_ability(h), "the subclass brings its Ability")
	check(GameData.hero_tree_summaries(h).size() == 2 and bool(GameData.hero_tree_summaries(h)[-1]["path"]), "role tree + Path tree")

	# --- Unlocks from deeds, remembered in the legacy.
	GameState.tower_best = 10
	var fresh := GameState.check_subclass_unlocks()
	check(fresh.has("bulwark") and (GameState.legacy.get("subclasses", []) as Array).has("bulwark"), "Tower floor 10 unlocks the Bulwark, kept for later guilds")

	# --- Stage 2 at Rank B; changing Path refunds the old Path tree.
	h.rank = "B"
	GameState.campaign_act = 3
	GameState.check_subclass_unlocks()
	var pk := str(GameData.PATHS["shieldwall"]["kind"])
	h.skill_points = 10
	GameState.learn_skill(h.id, pk, "edge")
	var learned := 0
	for n in GameData.KIND_SKILL_PACKAGE[pk]:
		if GameState.learn_skill(h.id, pk, str(n["id"])) == "":
			learned += 1
	var sp_left := h.skill_points
	var o2: Array = GameState.subclass_training_options(h).filter(func(o): return str(o["id"]) == "berserker")
	check(not o2.is_empty() and bool(o2[0]["change"]) and int(o2[0]["cost"]["days"]) == 4 * GameData.PATH_CHANGE_MULT, "another Path's stage 2 is a change of Path at double time")
	check(GameState.start_subclass_training(h.id, "berserker") == "", "start the change")
	for d in 8:
		GameState._train_day()
	check(h.pool_id == "berserker" and h.path == "bloodrage", "now a Berserker on Bloodrage")
	check(learned == 0 or h.skill_points > sp_left, "the old Path tree's points came back (%d -> %d)" % [sp_left, h.skill_points])

	# --- Save migration from version 3: subclass kept as trained, skills refunded.
	_guild()
	var old := Combat.gen_hero("C", 10)
	old.path = ""
	old.seasoned = 0
	old.skill_points = 0
	old.skills = {"edge": true}
	GameState.migrate_hero_to_paths(old)
	check(old.path != "" and GameData.subclass_stage(old.pool_id) > 0, "a migrated hero keeps their subclass on its Path")
	check(old.skills.is_empty() and old.skill_points == GameData.sp_budget(3, 10) - (GameData.ABILITY_AWAKENING_COST if old.ability_awakened else 0), "skills refunded at the new budget")
	check(old.seasoned == 3, "Seasoned for every rank above F")
	GameState.reset()
