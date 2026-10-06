extends "res://tests/base_test.gd"
## Heroes face right and foes face left: art drawn the other way is mirrored
## in the arena and the Endless Rift. And the Act I intro waits until the
## guild is founded (Settings opened from the naming screen used to show it).


func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().physics_frame


func run() -> void:
	check(GameData.faces_away("res://assets/monsters/hedge_warden.png") and GameData.faces_away("carrion_crier"), "wrong-way foes are listed (by path or key)")
	check(not GameData.faces_away("sub_acolyte") and not GameData.faces_away("res://assets/heroes/cleric.png"), "the redrawn heroes (0.50) all face the right way")
	check(not GameData.faces_away("ash_harrier") and not GameData.faces_away("sub_duskstalker"), "art that already faces the right way is left alone")
	check(GameData.faces_away("korrath") and GameData.faces_away("res://assets/monsters/spire_oracle.png"), "the right-facing bosses are mirrored too (0.51.2)")
	for key in GameData.SPRITE_FACES_AWAY:
		var known := GameData.MONSTER_SPRITE_PATH.has(key) or GameData.SUBCLASS_PORTRAIT_PATH.has(key) or ResourceLoader.exists("res://assets/heroes/%s.png" % key)
		check(known, "%s is a real sprite" % key)

	var main: Control = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _frames()
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = ""
	GameState.pending_stories.clear()
	GameState.pending_stories.append({"title": "Test Intro", "subtitle": "", "text": "..."})
	main._pre_settings_screen = "onboard"
	main.screen = "settings"
	main.render()
	await _frames()
	var shown := func() -> bool:
		return main.find_children("*", "Label", true, false).any(func(l): return str(l.text) == "Test Intro")
	check(not shown.call(), "no story over Settings before the guild is founded")
	GameState.guild_name = "Facing"
	main.screen = "camp"
	main.render()
	await _frames()
	check(shown.call(), "the intro shows once the guild exists")
	GameState.pending_stories.clear()

	# The turn-order strip mirrors the same art the arena does.
	var party: Array[Hero] = []
	var strip: Control = main._turn_order_strip({"party": party, "turn_idx": 0,
		"monsters": [{"name": "Carrion Crier", "hp": 10.0}, {"name": "Ash Harrier", "hp": 10.0}],
		"turn_order": [{"type": "monster", "id": 0}, {"type": "monster", "id": 1}]})
	var icons := strip.find_children("*", "TextureRect", true, false)
	check(icons.size() == 2 and icons[0].flip_h and not icons[1].flip_h, "turn-order icons: Carrion Crier mirrored, Ash Harrier not")
	strip.free()
	main.queue_free()
	await _frames()

	# Riftbreak: a foe walking down the road toward the camp (rightward) faces
	# the way it walks, like the Endless Rift's foes (0.51.2: they walked backwards).
	GameState.active_slot = 9
	GameState.reset()
	GameState.hire_starters()
	var dv := DefenseView.new()
	dv.setup("vale", 0, GameState.heroes.slice(0, 2), null, GameState.defense_opts())
	add_child(dv)
	await _frames()
	var base := {"tier": "combat", "route": 0, "d": 0.0, "pos": Vector2(100, 100), "hp": 10.0, "max_hp": 10.0, "dmg": 1.0, "speed": 1.0, "r": 10.0,
		"slow_t": 0.0, "slow": 0.0, "stun_t": 0.0, "burn_t": 0.0, "burn_dps": 0.0, "held_by": -1, "hit_cd": 0.5, "facing": 1.0, "dead": false, "flash": 0.0}
	var walker := base.duplicate()
	walker.merge({"id": 999, "name": "Gloom Stalker"}, true)
	var odd := base.duplicate()
	odd.merge({"id": 998, "name": "Korrath"}, true)
	dv.run.foes.append(walker)
	dv.run.foes.append(odd)
	dv._sync()
	check(dv._foe_nodes[999].flip_h and not dv._foe_nodes[998].flip_h, "a left-drawn foe heading right is mirrored, a right-drawn one isn't")
	walker["facing"] = -1.0
	dv._sync()
	check(not dv._foe_nodes[999].flip_h, "and heading left it's drawn as is")
	dv.queue_free()
	await _frames()
	GameState.delete_slot(9)
