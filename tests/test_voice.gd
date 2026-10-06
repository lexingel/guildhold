extends "res://tests/base_test.gd"
## Spoken lines (0.51): every clip exists, every voiced text is still in the
## game's data (a rewrite would silence it), and the moments that speak find
## their lines in order.


func _strings(v, out: Array) -> void:
	match typeof(v):
		TYPE_STRING:
			out.append(v)
		TYPE_ARRAY:
			for x in v:
				_strings(x, out)
		TYPE_DICTIONARY:
			for k in v:
				_strings(v[k], out)


func run() -> void:
	var data: Array = []
	var s: Script = GameData.get_script()
	while s:
		var consts := s.get_script_constant_map()
		for k in consts:
			_strings(consts[k], data)
		s = s.get_base_script()
	var missing: Array[String] = []
	var stale: Array[String] = []
	for line in VoiceLines.LINES:
		if not ResourceLoader.exists(AudioManager.VOICE_DIR + str(line[1])):
			missing.append(str(line[1]))
		if not data.any(func(t): return str(t).contains(str(line[0]))):
			stale.append(str(line[1]))
	check(VoiceLines.LINES.size() >= 150 and missing.is_empty(), "%d spoken lines, every clip exists %s" % [VoiceLines.LINES.size(), missing])
	check(stale.is_empty(), "every voiced text is still in the game's data %s" % [stale])

	# Story cards: the narrator, in reading order, without double counting.
	GameState.active_slot = 9
	GameState.reset()
	var intro: Dictionary = GameState._act_intro_card(1)
	check(AudioManager.voice_clips_in(str(intro["text"])).has("CAMPAIGN_0_.intro.ogg"), "Act I's intro card speaks")
	check(AudioManager.voice_clips_in(str(GameData.CHARTER_TURN["text"])) == ["CHARTER_TURN.ogg"], "the Charter's card speaks one line")
	check(AudioManager.voice_clips_in(str(GameData.PROLOGUE["text"])) == ["PROLOGUE.ogg"] and AudioManager.voice_clips_in(str(GameData.ACCORD_PROLOGUE["text"])) == ["ACCORD_PROLOGUE.ogg"], "both prologue cards are read (when the opening is skipped)")
	check(AudioManager.voice_clips_in(GameState.champion_memory_line("brannoch")).size() == 1, "Brannoch remembers aloud")
	# The pay table: each line by itself; a line naming a past guild stays silent.
	var first: Array = GameData.PAYDAY_SCENES["first"]
	check(first.all(func(ln): return AudioManager.voice_clip_for(str(ln[1])) != ""), "the first payday's three lines are voiced")
	check(AudioManager.voice_clip_for(str(GameData.PAYDAY_SCENES["past_paytable"][0][1])) == "", "a line with a guild's name in it isn't")
	# Rival letters: the note and its postscript.
	var ps := "P.S. Keep your walls up. The Hollow came for the Vale once, the night the old guilds fell, and it will come again."
	check(AudioManager.voice_clips_in("A note.\n\n" + ps).size() == 1, "Orla's postscript is voiced")

	# Off, or not English: nothing plays.
	var was_on: bool = GameState.voice_on
	var was_lang: String = GameState.language
	GameState.voice_on = false
	AudioManager.play_voice("test:off", ["CHARTER_TURN.ogg"])
	check(not AudioManager.voice_speaking("test:"), "spoken lines off: silence")
	GameState.voice_on = true
	GameState.language = "tr"
	AudioManager.play_voice("test:tr", ["CHARTER_TURN.ogg"])
	check(not AudioManager.voice_speaking("test:"), "in Turkish: silence")
	GameState.language = "en"
	AudioManager.play_voice("test:en", ["CHARTER_TURN.ogg"])
	check(AudioManager.voice_speaking("test:en"), "in English it speaks")
	AudioManager.play_voice("test:en", ["CHARTER_TURN.ogg"])
	check(AudioManager.voice_speaking("test:en"), "a re-render doesn't restart it")
	AudioManager.stop_voice("test:")
	check(not AudioManager.voice_speaking(), "and it stops")
	GameState.voice_on = was_on
	GameState.language = was_lang
	GameState.delete_slot(9)
