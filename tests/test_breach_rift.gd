extends "res://tests/base_test.gd"
## Breach rifts (0.63): a broken rift is held in back-to-back fights of the
## normal combat (the tower defense is parked). Sealing it holds the breach;
## turning back loses it; either way it takes one day. Wardcraft softens it.


func run() -> void:
	seed(11)
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "T"
	GameState.campaign_act = GameData.BREACH_UNLOCK_ACT
	var ids: Array[String] = []
	for r in ["warrior", "ranger", "mage", "cleric"]:
		var h := Combat.gen_hero("C", 8)
		h.cls_id = r
		h.pool_id = r
		h.path = ""
		h.id = "h%d" % GameState.next_id
		GameState.next_id += 1
		GameState.heroes.append(h)
		ids.append(h.id)
	GameState.coins = 5000
	GameState.crystals = 500
	check(not GameData.DEFENSE_TD_ENABLED, "the tower defense is parked")

	# A broken Rank D breach: the party screen holds it.
	GameState.breach = {"rank": 2, "region": "marsh", "started": GameState.day, "breaks_on": GameState.day, "broken": true}
	check(GameState.breach_blocks_runs(), "a broken rift blocks rift runs")
	GameState.start_breach_rift(ids)
	var kinds: Array = (GameState.run["layers"] as Array).map(func(l): return l["options"][0])
	check(GameState.run.has("breach") and kinds == GameData.BREACH_RIFT_LAYERS, "a breach rift: a fight, an elite and a warden in a row (%s)" % [kinds])
	check(GameState.run_biome() == "marsh" and str(GameState.run["rift_rank"]) == "D", "in the breach's region, at its rank")

	# Wardcraft's Armory and Watchtower soften its foes.
	var hp0 := float(GameState._diff()["monster_hp"])
	var dmg0 := float(GameState._diff()["monster_dmg"])
	GameState.upgrades["def.armory"] = 2
	GameState.upgrades["def.watch"] = 1
	check(is_equal_approx(float(GameState._diff()["monster_hp"]), hp0 * 0.9), "Armory Lv2: breach foes -10% HP")
	check(is_equal_approx(float(GameState._diff()["monster_dmg"]), dmg0 * 0.9 * 0.96), "and Watchtower Lv1: -4% more damage")

	# Sealed: held, paid, one day, the best rank held recorded.
	GameState.pending_toasts.clear()
	var c0 := GameState.coins
	var day0 := GameState.day
	GameState.run["sealed"] = {"essence": 0, "fast_clear": false, "cache": 0, "flavor": ""}
	GameState.finish_run()
	check(not GameState.breach_active() and GameState.coins > c0, "sealing the breach rift holds it, for Gold")
	check(GameState.day == day0 + 1, "and it took one day, not two")
	check(GameState.riftbreak_best == 2, "the best rank held counts for the subclass gates")
	check(GameState.pending_toasts.any(func(t): return str(t["title"]) == "The breach is held!"), "with a toast")

	# Turning back: lost, at a cost.
	GameState.breach = {"rank": 2, "region": "marsh", "started": GameState.day, "breaks_on": GameState.day, "broken": true}
	GameState.start_breach_rift(ids)
	GameState.pending_toasts.clear()
	var e0 := GameState.crystals
	day0 = GameState.day
	GameState.retreat_now()
	check(not GameState.breach_active() and GameState.crystals < e0, "turning back loses the breach: Essence")
	check(GameState.day == day0 + 1, "a lost breach also takes one day")
	check(GameState.pending_toasts.any(func(t): return str(t["title"]) == "The breach overran the guild"), "told in a toast")

	# The Inverted City's gate holds one more elite.
	GameState.breach = {"rank": 6, "region": "city", "started": GameState.day, "breaks_on": GameState.day, "broken": true, "gate": true}
	GameState.start_breach_rift(ids)
	check((GameState.run["layers"] as Array).size() == GameData.GATE_RIFT_LAYERS.size(), "the gate: four fights")
	GameState.run = {}
	GameState.breach = {}
