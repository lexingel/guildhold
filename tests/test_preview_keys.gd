extends "res://tests/base_test.gd"
## 0.68: the hover preview (expected damage from an Attack or a foe skill,
## pure, agreeing with the kill check) and moving fight keys.


func run() -> void:
	seed(68)
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "T"
	var party: Array[Hero] = []
	for r in ["warrior", "ranger", "mage", "cleric"]:
		var h := Combat.gen_hero("C", 6)
		h.cls_id = r
		h.pool_id = r
		h.id = "h%d" % GameState.next_id
		GameState.next_id += 1
		Combat.refresh_stats(h)
		h.hp = Combat.max_hp(h)
		GameState.heroes.append(h)
		party.append(h)
	var d := GameState._apply_rift_rank_modifiers(GameData.DIFFICULTIES[1], "C")
	var st := Combat.start_combat(party, "combat", d, 1)
	var hp_before := float(st["monsters"][0]["hp"])
	var atk := Combat.preview_attack(st, party[0], 0)
	var bash := Combat.preview_skill(st, party[0], "skill:shield_bash", 0)
	check(atk > 0 and bash > 0 and float(st["monsters"][0]["hp"]) == hp_before, "Attack and Shield Bash preview their damage without touching the foe (%d, %d)" % [atk, bash])
	check(Combat.preview_skill(st, party[3], "skill:heal", 0) == 0, "a skill that doesn't strike previews nothing")
	st["monsters"][0]["hp"] = float(atk)
	check(Combat.attack_would_kill(st, party[0], 0), "the kill check agrees with the preview")
	st["monsters"][0]["hp"] = float(atk + 5)
	check(not Combat.attack_would_kill(st, party[0], 0), "and a little more HP survives it")

	# Moving keys.
	var saved := GameState.key_binds.duplicate()
	GameState.key_binds = {}
	check(GameState.bind_key("1", "Z") == "" and GameState.bound_key("1") == "Z" and GameState.unbind_key("Z") == "1" and GameState.unbind_key("1") == "", "Attack moved to Z: Z attacks, 1 no longer does")
	check(GameState.bind_key("2", "Z") != "" and GameState.bound_key("2") == "2", "a key already in use is refused")
	check(GameState.bind_key("1", "1") == "" and GameState.key_binds.is_empty() and GameState.unbind_key("1") == "1", "moving it back clears the binding")
	GameState.key_binds = saved
	GameState.save_settings()
