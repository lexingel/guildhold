extends Node
## Screenshot regression capture (0.53): renders the key screens at a fixed
## seed into a folder, for tests/screens/compare.py to check against the
## approved images in tests/screens/golden. Needs a real window (not --headless):
##   Godot --path . tests/screens/capture.tscn -- <out_dir> [<w> <h>]
## Uses save slot 7 and restores the legacy file, like the other drivers.

var main: Control
var out := ""


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else "user://screens"
	var w := int(a[1]) if a.size() > 2 else 1280
	var h := int(a[2]) if a.size() > 2 else 800
	DirAccess.make_dir_recursive_absolute(out)
	var keep := FileAccess.get_file_as_bytes(GameState.LEGACY_PATH) if FileAccess.file_exists(GameState.LEGACY_PATH) else PackedByteArray()
	var reduce: bool = GameState.reduce_motion
	GameState.reduce_motion = true   # no shakes or sways mid-capture
	seed(12345)
	GameState.active_slot = 7
	GameState.reset()
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _wait(0.5)
	if a.size() > 3:   # a language to check for overflow (0.70): capture.tscn -- dir W H es
		GameState.language = a[3]
		GameState.apply_language()
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(w, h)
	await _wait(0.5)
	main.screen = "title"
	main.render()
	await _shot("title")
	GameState.guild_name = ""
	main.screen = "onboard"
	main.render()
	await _shot("onboard")

	seed(12345)
	GameState.reset()
	GameState.guild_name = "Golden"
	GameState.tips_off = true
	for r in ["warrior", "ranger", "mage", "cleric", "rogue"]:
		for tries in 200:
			var hero := Combat.gen_hero("B", 6)
			if GameData.hero_role(hero) == r:
				GameState.heroes.append(hero)
				break
	GameState.campaign_act = 2
	GameState.rifts_sealed = 4
	GameState.runs_started = 6
	GameState.coins = 600
	GameState.crystals = 90
	for rar in ["common", "rare", "legendary"]:
		GameState.items.append(Combat.gen_item(rar))
	for tab in ["camp", "roster", "inventory", "ledger", "management", "quests"]:
		main.screen = "camp"
		main.term_tab = tab
		main.render()
		await _shot("camp_" + tab)
	for sc in ["rift_hall", "settings"]:
		main.screen = sc
		main.render()
		await _shot(sc)
	var ids: Array[String] = []
	for hero in GameState.heroes.slice(0, 4):
		ids.append(hero.id)
	GameState.start_ladder_rift("F", ids, null)
	GameState.run["node_state"] = {}
	GameState.choose_node_type("combat")
	GameState.engage_node()
	main.screen = "rift_run"
	main.render()
	await _shot("fight")
	GameState.run = {}


	GameState.reduce_motion = reduce
	GameState.delete_slot(7)
	if keep.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.LEGACY_PATH))
	else:
		FileAccess.open(GameState.LEGACY_PATH, FileAccess.WRITE).store_buffer(keep)
	print("captured into ", out)
	get_tree().quit()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(n: String) -> void:
	GameState.pending_stories.clear()
	GameState.pending_toasts.clear()
	if main.visible:
		main.render()
	await _wait(1.2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(n + ".png"))
