extends "res://tests/base_test.gd"
## The haul (0.56): a run's earnings are only safe once the party is home.
## Falling drops half, fleeing a fight a quarter; leaving between floors
## keeps it all; a new guild (under 3 seals) loses nothing.


func _run(sealed: int, earned: int) -> void:
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "T"
	var h := Combat.gen_hero("F", 1)
	h.id = "h%d" % GameState.next_id
	GameState.next_id += 1
	GameState.heroes.append(h)
	var ids: Array[String] = [h.id]
	GameState.runs_started = 3
	GameState.rifts_sealed = sealed
	GameState.start_run("greater", ids, null)
	GameState.coins += earned
	GameState.crystals += earned / 2


func _lose() -> void:
	GameState.engage_node()
	var st: Dictionary = GameState.run["node_state"]["combat_state"]
	for m in st["monsters"]:
		m["dmg"] = 999
	GameState.quick_fight()


func run() -> void:
	_run(3, 200)
	var c0 := GameState.coins
	check(GameState.haul_at_risk() and GameState.haul() == Vector2i(200, 100), "200 Gold and 100 Essence earned this run")
	_lose()
	check(not bool(GameState.run["node_state"]["result"].get("won", true)), "the party falls")
	check(GameState.coins == c0 - 100 and GameState.run["haul_lost"] == [100, 50], "falling loses half the haul (%s)" % str(GameState.run.get("haul_lost")))
	GameState.save()
	GameState.load_save()
	GameState.finish_run()
	check(GameState.coins == c0 - 100, "and only once, even after a reload on the defeat screen")

	_run(3, 200)
	c0 = GameState.coins
	GameState.engage_node()
	GameState.combat_retreat()
	check(GameState.coins == c0 - 50, "fleeing a fight drops a quarter")
	GameState.finish_run()

	_run(3, 200)
	c0 = GameState.coins
	GameState.retreat_now()
	check(GameState.coins == c0, "leaving between floors keeps it all")

	_run(2, 200)
	c0 = GameState.coins
	_lose()
	check(not GameState.haul_at_risk() and GameState.coins == c0, "a guild under 3 seals loses nothing")
	GameState.finish_run()
	GameState.delete_slot(9)
