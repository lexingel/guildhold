extends "res://tests/base_test.gd"
## Staged unlocks, coach tips and the training rift.


func run() -> void:
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "T"
	check(not GameState.feature_unlocked("quests") and not GameState.feature_unlocked("inventory"), "a new guild starts with features locked")
	check(GameState.feature_unlocked("roster") and GameState.feature_unlocked("recruits"), "core screens always open")
	# Training rift: only the first run.
	var ids: Array[String] = []
	for r in ["E", "E"]:
		var h := Combat.gen_hero(r, 1)
		h.id = "h%d" % GameState.next_id
		GameState.next_id += 1
		GameState.heroes.append(h)
		ids.append(h.id)
	GameState.start_run("lesser", ids, null)
	check(GameState.run.get("training", false) and GameState.run["layers"].size() == GameData.TRAINING_RIFT["floors"], "first run is a %d-floor training rift" % GameData.TRAINING_RIFT["floors"])
	check(GameState.run["layers"].all(func(l): return not (l["options"] as Array).has("elite")), "no elites in the training rift")
	check(int(GameState._diff()["monster_hp"]) < int(GameData.DIFFICULTIES[0]["monster_hp"]), "training foes are weaker")
	# The guided first fight: plain foes, a scripted wind-up in round 2, and
	# actions tick the steps.
	GameState.run["node_state"] = {}
	GameState.choose_node_type("combat")
	GameState.engage_node()
	var st: Dictionary = GameState.run["node_state"]["combat_state"]
	for m in st["monsters"]:
		m["hp"] = 9999.0
		m["max_hp"] = 9999.0
		m["dmg"] = 0.0
	check((st["intents"] as Dictionary).values().all(func(it): return str(it["kind"]) == "attack"), "no special moves in the training fight")
	var h0: Hero = GameState.find_hero(ids[0])
	GameState.set_hero_action(h0.id, "attack", 0)
	check(GameState.hints_seen.has("tut_attack"), "attacking ticks the first step")
	var winding := false
	for i in 40:
		GameState.resolve_turn_now()
		if int(st["round_num"]) == 2 and (st["monsters"] as Array).any(func(m): return m.get("_winding", false) or m.get("_charged", false)):
			winding = true
			break
	check(winding, "round 2 shows a scripted wind-up")
	GameState.set_hero_action(h0.id, "defend")
	check(GameState.hints_seen.has("tut_windup"), "defending against it ticks the wind-up step")
	GameState.finish_run()
	GameState.start_run("lesser", ids, null)
	check(not GameState.run.get("training", false), "second run is a normal rift")
	GameState.finish_run()
	# Unlock announcements.
	GameState.pending_toasts.clear()
	GameState.rifts_sealed = 1
	var fresh := GameState.check_feature_unlocks()
	check(fresh.has("quests") and not fresh.has("management") and not fresh.has("crafting"), "the first seal opens quests only %s" % [fresh])
	check(GameState.pending_toasts.size() == 1 and str(GameState.pending_toasts[0]["text"]).contains("Quests"), "one combined unlock toast")
	check(GameState.check_feature_unlocks().is_empty(), "announced only once")
	# The reveal schedule (0.65): seals first, then the acts.
	GameState.pending_stories.clear()
	GameState.rifts_sealed = 2
	var second := GameState.check_feature_unlocks()
	check(second.has("training") and second.has("management") and second.size() == 2, "the second seal opens the Training Yard and the hall's rooms %s" % [second])
	check(GameState.pending_stories.size() == 2 and str(GameState.pending_stories[0]["subtitle"]).contains("Wen"), "brought in by Wen, as story cards")
	GameState.rifts_sealed = 3
	check(GameState.check_feature_unlocks() == ["requests"], "the third opens hero requests")
	check(not GameState.feature_unlocked("forge") and not GameState.feature_unlocked("rival") and not GameState.feature_unlocked("tower"), "the Smithy, the rival and the Tower wait")
	GameState.rifts_sealed = 9
	check(GameState.check_feature_unlocks().is_empty(), "seals alone open nothing more")
	GameState.campaign_act = 2
	GameState.act_since = GameState.day
	var act2 := GameState.check_feature_unlocks()
	check(act2.has("forge") and act2.has("relics") and not act2.has("rival"), "the end of Act I opens the Smithy and relics %s" % [act2])
	GameState.day += 1
	var act2b := GameState.check_feature_unlocks()
	check(act2b.has("rival") and act2b.has("resolve"), "a day into Act II: the rival, Resolve and the haul %s" % [act2b])
	GameState.day += 1
	check(GameState.check_feature_unlocks() == ["hall_rooms"], "two days in: more rooms")
	GameState.campaign_act = 3
	GameState.act_since = GameState.day
	var act3 := GameState.check_feature_unlocks()
	check(act3.has("crafting") and act3.has("hall_research") and not act3.has("daily") and not act3.has("tower"), "Act III: reforge and the research rooms %s" % [act3])
	GameState.day += 1
	check(GameState.check_feature_unlocks() == ["daily"], "then the Daily twist")
	GameState.campaign_act = 4
	check(GameState.check_feature_unlocks() == ["tower"], "Act IV: the Tower")
	GameState.campaign_act = 1
	GameState.rifts_sealed = 0
	check(GameState.feature_unlocked("management"), "an announced feature stays open")
	# Tips.
	check(GameState.hint_pending("battle"), "tip pending")
	GameState.dismiss_hint("battle")
	check(not GameState.hint_pending("battle"), "dismissed tip stays gone")
	GameState.tips_off = true
	check(not GameState.hint_pending("party"), "tips off hides every tip")
	# Save round-trip + old-save seeding.
	GameState.save()
	GameState.load_save()
	check(GameState.hints_seen.has("battle") and GameState.tips_off and GameState.runs_started == 2, "tips and run count saved")
	var d: Dictionary = JSON.parse_string(GameState.export_save_text())
	d.erase("features_seen")
	d.erase("runs_started")
	GameState.import_save_text(JSON.stringify(d), 9)
	GameState.load_save()
	GameState.pending_toasts.clear()
	check(GameState.check_feature_unlocks().is_empty(), "an old guild isn't spammed with unlock toasts")
	check(GameState.runs_started >= 1, "an old guild doesn't get a training rift")
