extends "res://tests/base_test.gd"
## The lane map (0.65): ranked rifts have lanes (3/4/5 by rank) linked floor
## to floor; only nodes linked from where the party stands can be taken;
## every route meets a campfire before the boss; the route survives a save;
## the anvil, shrine and echo nodes work; the Descent keeps its forks.


func run() -> void:
	seed(31)
	GameState.active_slot = 9
	GameState.reset()
	reveal_all()
	GameState.guild_name = "T"
	var ids: Array[String] = []
	for r in ["warrior", "ranger", "mage", "cleric"]:
		var h := Combat.gen_hero("C", 6)
		h.cls_id = r
		h.pool_id = r
		h.path = ""
		h.id = "h%d" % GameState.next_id
		GameState.next_id += 1
		Combat.refresh_stats(h)
		h.hp = Combat.max_hp(h)
		GameState.heroes.append(h)
		ids.append(h.id)
	GameState.runs_started = 5   # past the training rift
	GameState.coins = 5000

	# Lanes and length by rank.
	for pair in [["F", 3, 7], ["C", 4, 8], ["A", 5, 8 + int(GameData.RANK_EXTRA_FLOORS.get("A", 0))], ["S", 5, 8 + int(GameData.RANK_EXTRA_FLOORS.get("S", 0))]]:
		var d := GameState._apply_rift_rank_modifiers(GameData.DIFFICULTIES[0 if GameData.find_rift_rank(pair[0])["base"] == "lesser" else 1], pair[0])
		var layers := Combat.build_layers(d)
		var widest := 0
		for l in layers:
			widest = maxi(widest, (l["options"] as Array).size())
		check(widest == int(pair[1]) and layers.size() == int(pair[2]), "Rank %s: %d lanes, %d floors (%d, %d)" % [pair[0], pair[1], pair[2], widest, layers.size()])

	# Every route: each node reachable, a campfire right before the boss.
	var dc := GameState._apply_rift_rank_modifiers(GameData.DIFFICULTIES[1], "B")
	for trial in 20:
		var layers := Combat.build_layers(dc)
		var ok := true
		for i in range(1, layers.size()):
			var prev: Array = layers[i - 1]["next"]
			for t in (layers[i]["options"] as Array).size():
				if not prev.any(func(x): return (x as Array).has(t)):
					ok = false
		if trial == 0 or not ok:
			check(ok and layers[-2]["options"] == ["campfire"] and layers[-1]["options"] == ["boss"], "map %d: every node reachable, a campfire before the boss" % trial)

	# Walking it: only linked nodes on the next floor.
	GameState.start_ladder_rift("B", ids, null)
	check(int(GameState.run["pos"]) == 0 and GameState.current_node_kind() == "combat", "it opens on a fight")
	GameState.advance_node()
	var first: Array = GameState.reachable_options()
	check(first.size() == (GameState.run["layers"][1]["options"] as Array).size(), "from the opening fight, every lane of floor 2")
	GameState.choose_node(int(first[0]))
	var linked: Array = (GameState.run["layers"][1]["next"] as Array)[int(first[0])]
	GameState.advance_node()
	var reach2: Array = GameState.reachable_options()
	check(reach2.size() == linked.size() and reach2.all(func(i): return linked.has(i)), "then only the nodes its links lead to")
	var off: Array = range((GameState.run["layers"][2]["options"] as Array).size()).filter(func(i): return not reach2.has(i))
	if not off.is_empty():
		GameState.choose_node(int(off[0]))
		check(int(GameState.run.get("at", {}).get(2, -1)) != int(off[0]), "an unlinked node can't be taken")
	GameState.choose_node(int(reach2[0]))
	check(int(GameState.run["at"][2]) == int(reach2[0]), "the route is remembered")
	GameState.save()
	GameState.load_save()
	check(GameState.run.has("at") and int(GameState.run["at"][2]) == int(reach2[0]), "and survives a save")

	# The new nodes.
	GameState.run["node_state"] = {}
	GameState.run["chosen"][int(GameState.run["pos"])] = "echo"
	GameState.ensure_lane_node()
	var war := GameState.find_hero(ids[0])
	var lv := war.level
	GameState.train_with_echo(war.id)
	check(war.level == lv + 1 and GameState.run["node_state"]["done"], "the echo: a level for one hero")
	GameState.run["node_state"] = {}
	GameState.run["chosen"][int(GameState.run["pos"])] = "anvil"
	GameState.ensure_lane_node()
	var it := Combat.gen_item("rare")
	it.id = "itx"
	it.equipped_to = war.id
	GameState.items.append(it)
	var c0 := GameState.coins
	GameState.use_anvil("itx")
	check(it.forge_level == 1 and GameState.coins == c0, "the anvil: a free Forge level")
	GameState.run["node_state"] = {}
	GameState.run["chosen"][int(GameState.run["pos"])] = "shrine"
	GameState.ensure_lane_node()
	check(GameData.PATHS.has(str(GameState.run["node_state"]["path"])), "a shrine belongs to a Path")
	# Robbing it (2026-10-09): Gold now, Resolve lost.
	var g0 := GameState.coins
	var r0 := int(GameState.run.get("resolve", 0))
	GameState.take_shrine_offerings()
	check(GameState.coins > g0 and GameState.run["node_state"]["done"] and (not GameState.resolve_on() or int(GameState.run["resolve"]) < r0), "the offerings: Gold, at a price in Resolve")
	GameState.run = {}
	# Tips (2026-10-09): "Help a little" keeps only the key tips.
	GameState.hints_seen = []
	GameState.set_tips_mode("key")
	check(GameState.hint_pending("battle") and not GameState.hint_pending("ledger"), "Help a little: the first fight's tip, not the ledger's")
	GameState.set_tips_mode("off")
	check(not GameState.hint_pending("battle") and GameState.tips_mode() == "off", "No tips: none")
	GameState.set_tips_mode("all")

	# The Descent keeps its two-way forks.
	GameState.best_rift_rank_sealed = 4
	GameState.start_descent(ids, null)
	check(not (GameState.run["layers"] as Array).any(func(l): return (l as Dictionary).has("next")), "the Descent keeps its forks")
	GameState.run = {}
