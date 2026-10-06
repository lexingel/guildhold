extends "res://tests/base_test.gd"
## Art, music and voice work where they should (0.51): every path the code
## names exists, every image and sound loads, animation frames line up with
## their still, and each screen plays its music and speaks its lines.

const EXTS := ["png", "ogg", "wav", "mp3", "tres", "tscn", "gdshader", "ttf", "otf"]


func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().physics_frame


func _files(dir: String, exts: Array, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in exts:
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_files(dir.path_join(d), exts, out)


func _size(path: String) -> Vector2i:
	var t: Texture2D = load(path)
	return Vector2i(t.get_width(), t.get_height()) if t else Vector2i.ZERO


func run() -> void:
	# 1. Every literal path in the code and scenes exists.
	var sources: Array = []
	_files("res://scripts", ["gd"], sources)
	_files("res://scenes", ["tscn"], sources)
	_files("res://theme", ["tres", "gdshader"], sources)
	var re := RegEx.create_from_string("res://[A-Za-z0-9_./\\-]+\\.(" + "|".join(EXTS) + ")")
	var broken: Array[String] = []
	var named := 0
	for src in sources:
		for m in re.search_all(FileAccess.get_file_as_string(src)):
			named += 1
			if not ResourceLoader.exists(m.get_string()):
				broken.append("%s in %s" % [m.get_string(), str(src).get_file()])
	check(named > 300 and broken.is_empty(), "%d asset paths named in the code, all exist %s" % [named, broken])

	# 2. Every image loads; every sound loads and has length.
	var images: Array = []
	_files("res://assets", ["png"], images)
	var bad_img: Array[String] = []
	for p in images:
		if not (load(p) is Texture2D):
			bad_img.append(str(p))
	check(images.size() > 3000 and bad_img.is_empty(), "%d images load %s" % [images.size(), bad_img.slice(0, 10)])
	var sounds: Array = []
	_files("res://assets/audio", ["ogg", "wav"], sounds)
	_files("res://assets/voice", ["ogg"], sounds)
	var bad_snd: Array[String] = []
	for p in sounds:
		var s = load(p)
		if not (s is AudioStream) or s.get_length() < (0.02 if "/sfx/" in str(p) else 0.2):   # a click is short; a line or a track isn't
			bad_snd.append(str(p))
	check(sounds.size() > 180 and bad_snd.is_empty(), "%d sounds load and have length %s" % [sounds.size(), bad_snd])
	for track in GameData.CAMP_MUSIC + GameData.COMBAT_MUSIC:
		check((load(track) as AudioStream).get_length() > 30.0, "%s is a full track" % str(track).get_file())
	for key in GameData.SFX_PATH:
		check(ResourceLoader.exists(str(GameData.SFX_PATH[key])), "sound %s exists" % key)

	# 3. Animation frames match their still, so nothing jumps mid-swing.
	var jumps: Array[String] = []
	var anim: Array = []
	_files("res://assets/heroes/subclass_anim", ["png"], anim)
	_files("res://assets/monsters/anim", ["png"], anim)
	var still_of := {}
	for p in anim:
		var f := str(p).get_file().get_basename()   # <key>_<action>_<n>
		var parts := f.rsplit("_", true, 2)
		var key := parts[0]
		if not still_of.has(key):
			var own0 := str(p).get_base_dir().path_join("%s_%s_0.png" % [key, parts[1]])
			var still := own0   # frame 0 is the still itself unless the set keeps its own (0.53)
			if not ResourceLoader.exists(own0):
				if "/monsters/" in str(p):
					still = "res://assets/monsters/%s.png" % key
				elif key.begins_with("champ_"):
					still = GameData.champion_portrait(key.trim_prefix("champ_"))
				else:
					still = str(GameData.SUBCLASS_PORTRAIT_PATH.get(key, own0))
			still_of[key] = _size(still)
		if _size(p) != still_of[key]:
			jumps.append(f)
	check(anim.size() > 2000 and jumps.is_empty(), "%d attack/hit/skill frames match their first frame %s" % [anim.size(), jumps.slice(0, 10)])
	var walks: Array = []
	_files("res://assets/survivors/walk", ["png"], walks)
	var odd_walk: Array[String] = []
	for p in walks:
		var s := _size(p)
		if s.x > 64 or s.y > 64:
			odd_walk.append(str(p).get_file())
	check(walks.size() > 1000 and odd_walk.is_empty(), "%d walk frames fit the 64px cell %s" % [walks.size(), odd_walk.slice(0, 10)])

	# 4. Music and voice play where they should.
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _frames()
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "Media"
	GameState.hire_starters()
	GameState.pending_stories.clear()
	GameState.pending_toasts.clear()
	var was_on: bool = GameState.voice_on
	var was_lang: String = GameState.language
	GameState.voice_on = true
	GameState.language = "en"

	main.screen = "camp"
	main.term_tab = "camp"
	main.render()
	await _frames()
	check(AudioManager._current_music_path in GameData.CAMP_MUSIC, "the camp plays a camp track")

	GameState.pending_stories.append(GameState._act_intro_card(1))
	main.render()
	await _frames()
	check(AudioManager.voice_speaking("story:"), "a story card is read aloud")
	GameState.pending_stories.clear()
	main.render()
	await _frames()
	check(not AudioManager.voice_speaking("story:"), "and the reading stops when it's dismissed")

	GameState.payday_report = {"day": 7, "paid": 100, "scene": "first"}
	main.term_tab = "ledger"
	main.render()
	await _frames()
	check(AudioManager.voice_speaking("payday:"), "the pay table speaks on the Ledger")
	AudioManager.stop_voice()

	GameState.rival_name = "The Iron Chorus"
	GameState.rival_event = {"type": "snatch", "quest": "", "day": GameState.day, "ps": "P.S. Keep your walls up. The Hollow came for the Vale once, the night the old guilds fell, and it will come again."}
	main.render()
	await _frames()
	check(AudioManager.voice_speaking("letter:"), "the rival's letter is read out")
	AudioManager.stop_voice()
	GameState.rival_event = {}

	GameState.language = "tr"
	GameState.pending_stories.append(GameState._act_intro_card(2))
	main.render()
	await _frames()
	check(not AudioManager.voice_speaking(), "in Turkish the cards stay silent")
	GameState.pending_stories.clear()
	GameState.language = "en"

	var ids: Array[String] = []
	for h in GameState.heroes:
		ids.append(h.id)
	GameState.runs_started = 3
	GameState.start_ladder_rift("F", ids, null)
	GameState.run["node_state"] = {}
	GameState.choose_node_type("combat")
	GameState.engage_node()
	main.screen = "rift_run"
	main.render()
	await _frames()
	check(AudioManager._current_music_path in GameData.COMBAT_MUSIC, "a fight plays a combat track")
	GameState.run = {}
	main.screen = "camp"
	main.term_tab = "camp"
	main.render()
	await _frames()
	check(AudioManager._current_music_path in GameData.CAMP_MUSIC, "and coming home plays a camp track again")

	var sv := SurvivorsView.new()
	sv.setup(GameState.heroes.slice(0, 3), "vale")
	add_child(sv)
	await _frames()
	check(AudioManager._current_music_path in GameData.COMBAT_MUSIC, "the Endless Rift plays a combat track")
	sv.queue_free()
	var dv := DefenseView.new()
	dv.setup("vale", 0, GameState.heroes.slice(0, 2), null, GameState.defense_opts())
	add_child(dv)
	await _frames()
	check(AudioManager._current_music_path in GameData.COMBAT_MUSIC, "Riftbreak plays a combat track")
	dv.queue_free()

	GameState.voice_on = was_on
	GameState.language = was_lang
	AudioManager.stop_voice()
	main.queue_free()
	await _frames()
	GameState.delete_slot(9)
