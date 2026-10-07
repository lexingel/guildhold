extends "res://tests/base_test.gd"
## Music pools: every track loads, and a new pick avoids the last one.


func run() -> void:
	for p in GameData.COMBAT_MUSIC + GameData.CAMP_MUSIC:
		check(ResourceLoader.exists(p) and load(p) is AudioStream, "%s loads" % p)
	check(GameData.COMBAT_MUSIC.size() >= 3 and GameData.CAMP_MUSIC.size() >= 3, "three combat tracks, three camp tracks")
	var last := str(GameData.CAMP_MUSIC[0])
	var repeats := 0
	for k in 30:
		var t := GameData.pick_track(GameData.CAMP_MUSIC, last)
		if t == last:
			repeats += 1
		last = t
	check(repeats == 0, "coming home never replays the same camp track")
	check(GameData.pick_track(["only"], "only") == "only", "a single-track pool still plays")
	# Region themes (0.59.1): one per region; the Descent and Act IV's finale play the Accord Hall's; the Tower the pool.
	for b in GameData.BIOMES:
		check(GameData.REGION_MUSIC.has(b), "%s has a theme" % b)
	check(GameData.run_track({"biome": "marsh"}) == GameData.REGION_MUSIC["marsh"] and GameData.run_track({"biome": "vale", "descent": 2}) == GameData.ACCORD_MUSIC 		and GameData.run_track({"biome": "glass", "finale": 4}) == GameData.ACCORD_MUSIC and GameData.run_track({"tower": 3}) == "", "which run plays which theme")
	# The next batch (0.60.2): a boss track only for bosses and pillars, never the Tower; only once its file is in.
	var any_boss := ResourceLoader.exists(GameData.BOSS_MUSIC)
	check(GameData.fight_track({"biome": "vale"}, "elite") == "" and GameData.fight_track({"tower": 3}, "boss") == "" 		and (GameData.fight_track({"biome": "vale"}, "boss") != "") == any_boss, "boss music: bosses and pillars, not elites or the Tower")
	check(GameData.camp_pool().size() >= GameData.CAMP_MUSIC.size() and GameData.camp_pool().all(func(t): return ResourceLoader.exists(t)), "the camp rotation only holds tracks that are in")
	# Ducking (0.59.3): music dips while a line is spoken and comes back after.
	var clip := ""
	for f in DirAccess.get_files_at("res://assets/voice"):
		if f.ends_with(".ogg"):
			clip = f
			break
	var was_on: bool = GameState.voice_on
	var was_lang: String = GameState.language
	GameState.voice_on = true
	GameState.language = "en"
	AudioManager.set_music_volume(0.5)
	var bus := AudioServer.get_bus_index("Music")
	var user_db := AudioServer.get_bus_volume_db(bus)
	AudioManager.play_voice("test:duck", [clip], true)
	await get_tree().create_timer(0.5).timeout
	check(AudioManager.music_ducked() and AudioServer.get_bus_volume_db(bus) < user_db - 6.0, "a spoken line ducks the music (%.1f dB vs %.1f)" % [AudioServer.get_bus_volume_db(bus), user_db])
	AudioManager.stop_voice()
	await get_tree().create_timer(0.5).timeout
	check(not AudioManager.music_ducked() and absf(AudioServer.get_bus_volume_db(bus) - user_db) < 0.1, "and it comes back to the player's volume when the line stops")
	GameState.voice_on = was_on
	GameState.language = was_lang
	AudioManager.set_music_volume(GameState.music_volume)
