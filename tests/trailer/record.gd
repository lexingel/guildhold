extends Node
## The narrated tour (2026-10-10): plays nine scenes, each as long as its
## narration line, for Godot's Movie Maker to record. Needs a real window:
##   (override.cfg: window/size/window_width_override=1920, window_height_override=1080)
##   Godot --path . --write-movie out.avi --fixed-fps 30 tests/trailer/record.tscn -- <durations.json>
##   Godot --path . tests/trailer/record.tscn -- <durations.json> shots <dir>   (one still per scene, to check)
## durations.json: [seconds per scene]. Uses save slot 7 and restores the legacy file.

var main: Control
var shots := ""
var overlay: CanvasLayer
var starts := {}   # scene -> its first frame's time in the movie (fixed fps), for the narration mix
var starts_path := ""
var END_LINE := "You can test it now in your browser, for free."   # the end card; the Turkish pass passes its own


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var dur: Array = JSON.parse_string(FileAccess.get_file_as_string(a[0])) if a.size() > 0 and a[0] != "" else [6, 6, 6, 6, 9, 7, 5, 6, 7, 5]
	var lang := ""
	var win := Vector2i(1920, 1080)
	for i in range(1, a.size()):   # end=<text> (the end card's line), lang=<code> (the game's language), shots <dir>
		if a[i].begins_with("end="):
			END_LINE = a[i].substr(4)
		elif a[i].begins_with("lang="):
			lang = a[i].substr(5)
		elif a[i].begins_with("size="):   # size=1280x800: the stills for the recruiting kit
			var wh := a[i].substr(5).split("x")
			win = Vector2i(int(wh[0]), int(wh[1]))
		elif a[i].begins_with("starts="):
			starts_path = a[i].substr(7)
		elif a[i] == "shots" and i + 1 < a.size():
			shots = a[i + 1]
			DirAccess.make_dir_recursive_absolute(shots)
	var keep := FileAccess.get_file_as_bytes(GameState.LEGACY_PATH) if FileAccess.file_exists(GameState.LEGACY_PATH) else PackedByteArray()
	seed(777)
	GameState.active_slot = 7
	GameState.reset()
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _wait(0.4)
	var music_bus := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(music_bus, true)   # sound effects only: the video lays one track under the narration
	var prev_lang: String = GameState.language
	if lang != "":
		GameState.language = lang
		GameState.apply_language()
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = win
	await _wait(0.3)
	GameState.tips_off = true

	# 1. The title.
	main.screen = "title"
	main.render()
	await _scene(dur[0], "1_title")

	# 2. Name it, a crest, the founding board.
	GameState.guild_name = ""
	main.pending_crest = 3
	main.screen = "onboard"
	starts["2a_onboard"] = Engine.get_process_frames() / 30.0
	var name := "The Ember Watch"
	for i in name.length() + 1:
		main.pending_guild_name = name.substr(0, i)
		main.render()
		await _wait(0.06)
	await _wait(maxf(0.5, dur[1] * 0.45 - name.length() * 0.06))
	await _shot("2a_onboard")
	GameState.reset()
	GameState.guild_name = name
	GameState.guild_crest = 3
	GameState.tips_off = true
	GameState.open_founding_board()
	_quiet()
	main.screen = "camp"
	main.term_tab = "recruits"
	main.render()
	await _scene(dur[1] * 0.55, "2b_founders")

	# A guild a few weeks in: the rest of the tour plays from here.
	_midgame()
	# 3. The hamlet.
	main.screen = "camp"
	main.term_tab = "camp"
	main.hub_cluster = ""
	main.render()
	await _scene(dur[2], "3_hamlet")

	# 4. The Rift Hall, then the road through a rift.
	main._ladder_pick = "B"
	main.screen = "rift_hall"
	main.render()
	await _scene(dur[3] * 0.4, "4a_rift_hall")
	GameState.start_ladder_rift("B", _party(), null)
	GameState.pending_stories.clear()
	(GameState.run["chosen"] as Dictionary).clear()   # the lane map, before the first room is picked
	GameState.run["node_kind"] = ""
	GameState.run["node_state"] = {}
	_quiet()
	main.screen = "rift_run"
	main.render()
	await _scene(dur[3] * 0.6, "4b_map")
	GameState.run = {}

	# 5. A fight on Auto: intents, a wind-up, Defend (from Rank C: a wind-up by round 2).
	GameState.start_ladder_rift("A", _party(), null)   # near the party's power, so the fight fills its scene
	GameState.pending_stories.clear()
	GameState.run["node_state"] = {}
	GameState.choose_node_type("combat")
	GameData.WOUND_SURE_ROUND = 1   # the wind-up comes in round 1, inside the scene
	GameState.engage_node()
	GameData.WOUND_SURE_ROUND = 2
	var cs: Dictionary = GameState.run["node_state"]["combat_state"]
	cs["_foes_first"] = true   # the foes open: their attacks are on screen from the start
	for m in cs["monsters"]:   # foes last long enough to show intents, a wind-up and a Defend
		m["max_hp"] = float(m["max_hp"]) * 4.0
		m["hp"] = float(m["max_hp"])
	main.screen = "rift_run"
	main._auto_battle = true
	GameState.combat_speed = 3.0   # a few rounds inside the scene (scene timers ignore time scale)
	Engine.time_scale = 3.0
	main.render()
	await _scene(dur[4], "5_fight")
	main._auto_battle = false
	GameState.combat_speed = 1.0
	Engine.time_scale = 1.0
	await _leave_fight()

	# 6. The boss's door, a haul at stake.
	GameState.start_ladder_rift("B", _party(), null)
	GameState.pending_stories.clear()
	GameState.run["pos"] = (GameState.run["layers"] as Array).size() - 1
	GameState.run["node_state"] = {}
	GameState.run["start_coins"] = GameState.coins - 640
	GameState.run["start_crystals"] = GameState.crystals - 210
	GameState.choose_node_type("boss")
	_quiet()
	main.screen = "rift_run"
	main.render()
	await _scene(dur[5], "6_boss_door")

	# 6b. The boss fight itself, on Auto.
	GameState.engage_node()
	main.screen = "rift_run"
	main._auto_battle = true
	GameState.combat_speed = 3.0
	Engine.time_scale = 3.0
	main.render()
	await _scene(dur[6], "6b_boss_fight")
	main._auto_battle = false
	GameState.combat_speed = 1.0
	Engine.time_scale = 1.0
	await _leave_fight()

	# 7. Payday and the rival.
	main.screen = "camp"
	main.term_tab = "ledger"
	main.render()
	await _scene(dur[7], "7_ledger")

	# 8. A hero's skill tree, then their Path.
	var pathed: Array = GameState.heroes.filter(func(h): return h.path != "")
	main.selected_hero_id = (pathed[0] if not pathed.is_empty() else GameState.heroes[0]).id
	main.screen = "camp"
	main.term_tab = "roster"
	main.roster_tab = "skills"
	main.render()
	await _scene(dur[8] * 0.55, "8a_skills")
	main.roster_tab = "path"
	main.render()
	await _scene(dur[8] * 0.45, "8b_path")

	# 9. The end card.
	main.screen = "title"
	main.render()
	_end_card()
	await _scene(dur[9] + 1.5, "9_end")

	AudioServer.set_bus_mute(music_bus, false)
	if lang != "":   # the player's own language back
		GameState.language = prev_lang
		GameState.apply_language()
	if starts_path != "":
		FileAccess.open(starts_path, FileAccess.WRITE).store_string(JSON.stringify(starts))
	GameState.delete_slot(7)
	if keep.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.LEGACY_PATH))
	else:
		FileAccess.open(GameState.LEGACY_PATH, FileAccess.WRITE).store_buffer(keep)
	get_tree().quit()


func _midgame() -> void:
	seed(4242)
	GameState.reset()
	GameState.guild_name = "The Ember Watch"
	GameState.guild_crest = 3
	GameState.tips_off = true
	GameState.campaign_act = 4
	GameState.rifts_sealed = 14
	GameState.best_rift_rank_sealed = 4
	GameState.runs_started = 24
	GameState.day = 26
	GameState.coins = 2400
	GameState.crystals = 900
	var roles := ["warrior", "ranger", "mage", "cleric", "rogue", "warrior"]
	for r in roles:
		for tries in 300:
			var hero := Combat.gen_hero("B", 8)
			if GameData.hero_role(hero) == r:
				hero.hp = Combat.max_hp(hero)
				GameState.heroes.append(hero)
				break
	for rar in ["rare", "epic", "legendary", "rare"]:
		GameState.items.append(Combat.gen_item(rar))
	for b in GameData.BRANCHES:   # a hall that has grown: higher-tier buildings
		for n in b["nodes"]:
			GameState.upgrades["%s.%s" % [b["id"], n["id"]]] = int(n["max"]) - 1
	for m in GameData.milestones():   # no achievement toasts mid-tour
		if not GameState.milestones_claimed.has(str(m["id"])):
			GameState.milestones_claimed.append(str(m["id"]))
	for f in GameData.FEATURE_UNLOCKS:
		if not GameState.features_seen.has(f):
			GameState.features_seen.append(f)
	_quiet()


## No story cards, toasts or achievements popping up over the tour.
func _quiet() -> void:
	GameState.check_milestones()
	GameState.check_feature_unlocks()
	GameState.pending_stories.clear()
	GameState.pending_toasts.clear()


## Ends the fight scene cleanly: let the turn finish, then leave the screen.
func _leave_fight() -> void:
	for i in 10:   # at most a second: the next scene's narration is waiting
		if not main._combat_animating:
			break
		await _wait(0.1)
	main._combat_animating = false
	GameState.run = {}
	main.screen = "camp"
	main.term_tab = "camp"
	main.render()
	await _wait(0.1)


func _party() -> Array[String]:
	var ids: Array[String] = []
	for h in GameState.heroes.slice(0, 4):
		h.hp = Combat.max_hp(h)
		ids.append(h.id)
	return ids


func _end_card() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 50
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.05, 0.09, 0.62)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	overlay.add_child(box)
	var t := Label.new()
	t.text = "GUILDHOLD"
	t.add_theme_font_override("font", load("res://assets/fonts/Cinzel-Bold.ttf"))
	t.add_theme_font_size_override("font_size", 96)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	for line in [END_LINE, "lexingel.github.io/guildhold"]:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 40)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	box.position = (get_viewport().get_visible_rect().size - box.get_combined_minimum_size()) / 2.0


func _scene(seconds: float, label: String) -> void:
	_quiet()
	starts[label] = Engine.get_process_frames() / 30.0   # Movie Maker runs one process frame per video frame
	if shots != "":
		await _wait(minf(1.5, seconds))
		await _shot(label)
		return
	await _wait(seconds)


func _shot(label: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join(label + ".png"))


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout   # real scene time, whatever the fight speed
