extends "res://tests/base_test.gd"
## Hardships (0.67): Story / Standard / Hardship 1-10 stack through
## year_mult/year_add; the readout scales with them; Story keeps the haul safe
## and Resolve off; Laurels follow; the next level opens with an ending.


func run() -> void:
	seed(67)
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "T"
	GameState.vale_year = {}
	var ids: Array[String] = []
	for r in ["warrior", "ranger", "mage", "cleric"]:
		var h := Combat.gen_hero("C", 6)
		h.cls_id = r
		h.pool_id = r
		h.id = "h%d" % GameState.next_id
		GameState.next_id += 1
		Combat.refresh_stats(h)
		h.hp = Combat.max_hp(h)
		GameState.heroes.append(h)
		ids.append(h.id)
	GameState.runs_started = 5
	GameState.rifts_sealed = 5

	check(GameState.hardship == 0 and GameState.year_mult("foe_hp") == 1.0 and GameState.hardship_rec_mult() == 1.0, "Standard changes nothing")
	var d := GameState._apply_rift_rank_modifiers(GameData.DIFFICULTIES[1], "C")
	var hp0 := int(Combat.gen_monster(d, 2, "combat")["hp"])

	GameState.hardship = 3
	check(is_equal_approx(GameState.year_mult("foe_hp"), 1.1) and GameState.year_add("breach_sooner") == 2.0 and GameState.year_add("resolve_start") == -2.0, "Hardship 3 stacks levels 1-3")
	var hp3 := int(Combat.gen_monster(d, 2, "combat")["hp"])
	check(absf(float(hp3) / hp0 - 1.1) < 0.02, "foes have 10%% more HP (%d vs %d)" % [hp3, hp0])
	GameState.start_ladder_rift("C", ids, null)
	check(GameState.resolve_now() == GameData.RESOLVE_START - 2, "parties set out with 2 less Resolve")
	check(Combat.recommended_power("normal", "C") > int(GameData.find_rift_rank("C")["rec"]), "the readout asks for more power")
	GameState.run = {}

	GameState.hardship = 10
	check(is_equal_approx(GameState.year_mult("foe_dmg"), 1.1) and is_equal_approx(GameState.year_mult("rival_renown"), 1.2) and is_equal_approx(GameState.year_add("mend_cap"), -0.1) and is_equal_approx(GameState.campfire_heal_pct(), 0.15), "Hardship 10 has every level")
	var d10 := GameState._apply_rift_rank_modifiers(GameData.DIFFICULTIES[1], "C")
	check(d10["elite_chance_up"] and d10["boss_double_mechanic"], "more elites and two-mechanic bosses")

	GameState.hardship = -1
	GameState.start_ladder_rift("C", ids, null)
	check(is_equal_approx(GameState.year_mult("foe_hp"), 0.8) and not GameState.haul_at_risk() and not GameState.resolve_on(), "Story: weaker foes, the haul safe, no Resolve")
	check(Combat.recommended_power("normal", "C") < int(GameData.find_rift_rank("C")["rec"]), "Story's readout asks for less")
	GameState.run = {}

	# Laurels.
	GameState.campaign_act = 4
	GameState.hardship = 0
	var base := GameState.laurels_earned()
	GameState.hardship = 10
	var hard := GameState.laurels_earned()
	GameState.hardship = -1
	var story := GameState.laurels_earned()
	check(hard > base and story < base, "Laurels: more at Hardship 10 (%d), less in Story (%d), vs %d" % [hard, story, base])

	# What opens.
	GameState.legacy = {"guilds": [], "laurels": 0, "champions": {}}
	check(GameState.hardship_unlocked() == 0, "a first guild sees no Hardships")
	GameState.legacy["guilds"] = [{"act": 4, "hardship": 0, "ending": ""}]
	check(GameState.hardship_unlocked() == 1, "Act IV opens Hardship 1")
	GameState.legacy["guilds"].append({"act": 6, "hardship": 3, "ending": "renew"})
	check(GameState.hardship_unlocked() == 4, "an ending at Hardship 3 opens 4")
	GameState.hardship = 5
	GameState.save()
	GameState.load_save()
	check(GameState.hardship == 5 and int(GameState.slot_summary(9)["hardship"]) == 5, "the Hardship is saved and shown on the slot")
	GameState.hardship = 0
