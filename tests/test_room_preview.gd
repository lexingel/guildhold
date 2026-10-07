extends "res://tests/base_test.gd"
## The room screen (0.61.4) shows the foes ahead before Engage: the preview
## must be the same roll Engage makes, and must not change it.


func run() -> void:
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "T"
	var ids: Array[String] = []
	for i in 3:
		var h := Combat.gen_hero("D", 4)
		h.id = "h%d" % GameState.next_id
		GameState.next_id += 1
		GameState.heroes.append(h)
		ids.append(h.id)
	GameState.runs_started = 3
	GameState.rifts_sealed = 3
	GameState.start_run("greater", ids, null)
	for floor_i in 3:
		GameState.run["node_state"] = {}
		GameState.choose_node_type("elite" if floor_i == 1 else "combat")
		var seen: Array = GameState.preview_foes().map(func(m): return str(m["name"]))
		var again: Array = GameState.preview_foes().map(func(m): return str(m["name"]))
		check(not seen.is_empty() and seen == again, "floor %d: the preview is stable (%s)" % [floor_i, str(seen)])
		GameState.engage_node()
		var fought: Array = GameState.run["node_state"]["combat_state"]["monsters"].map(func(m): return str(m["name"]))
		check(seen == fought, "floor %d: Engage brings the foes the room showed" % floor_i)
		GameState.run["pos"] = int(GameState.run["pos"]) + 1
	GameState.run = {}
	GameState.reset()
