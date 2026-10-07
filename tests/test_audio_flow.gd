extends "res://tests/base_test.gd"
## Voice and music from the opening to a run and home (0.59.3): the narrated
## opening is never cut into by a re-render or a story card, a spoken line
## ducks the music, and each place plays its own track.


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func run() -> void:
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _wait(0.3)
	GameState.active_slot = 9
	GameState.reset()
	var was_on: bool = GameState.voice_on
	var was_lang: String = GameState.language
	GameState.voice_on = true
	GameState.language = "en"
	GameState.guild_name = "Flow"
	GameState.hire_starters()
	GameState.apply_founding("free")
	main.screen = "camp"
	main._play_cinematic(true)
	await _wait(0.5)
	var opening := AudioManager._current_music_path
	check(opening.contains("opening"), "the opening plays its narrated track (%s)" % opening.get_file())
	GameState.state_changed.emit()
	main.render()
	await _wait(0.6)
	check(AudioManager._current_music_path == opening and not AudioManager.voice_speaking(), "a re-render mid-opening neither changes the track nor starts a card's narration")
	for c in main.get_children():
		if c is Cinematic:
			c._finish(true)
	await _wait(0.6)
	check(not AudioManager._current_music_path.contains("opening"), "skipped: the opening's track is gone (%s)" % AudioManager._current_music_path.get_file())
	if AudioManager.voice_speaking():
		check(AudioManager.music_ducked(), "the prologue card speaks over ducked music")
	GameState.pending_stories.clear()
	main.render()
	await _wait(0.5)
	check(not AudioManager.voice_speaking() and not AudioManager.music_ducked(), "the card dismissed: quiet voice, music back up")
	var ids: Array[String] = []
	for h in GameState.heroes:
		ids.append(h.id)
	GameState.runs_started = 3
	GameState.start_ladder_rift("F", ids, null)
	main.screen = "rift_run"
	main.render()
	await _wait(0.4)
	check(AudioManager._current_music_path == GameData.run_track(GameState.run), "the rift's map plays its region's theme")
	GameState.pending_stories.append({"title": str(GameData.CAMPAIGN[0]["name"]), "text": str(GameData.CAMPAIGN[0]["outro"])})
	main.render()
	await _wait(0.6)
	check(AudioManager.voice_speaking() and AudioManager.music_ducked() and AudioManager._current_music_path == GameData.run_track(GameState.run), "an act's card speaks over the region's theme, ducked")
	GameState.pending_stories.clear()
	GameState.run = {}
	main.screen = "camp"
	main.term_tab = "camp"
	main.render()
	await _wait(0.5)
	check(AudioManager._current_music_path in GameData.camp_pool() and not AudioManager.voice_speaking(), "home again: a camp track, nothing speaking")
	main.queue_free()
	GameState.voice_on = was_on
	GameState.language = was_lang
	GameState.delete_slot(9)
