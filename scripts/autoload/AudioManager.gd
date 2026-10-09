extends Node
## Owns all music/SFX playback — two dedicated buses (Music, SFX) exist under
## Master (see default_bus_layout.tres) purely so a future settings screen
## can expose independent volume sliders via AudioServer directly, without
## this script needing to know a settings UI exists.
##
## Every call here gates on ResourceLoader.exists() and no-ops if a path
## isn't there yet — the same "safe to wire in before the asset exists"
## contract GameData.hero_anim_frames/monster_anim_frames already use, so
## call sites can reference GameData.SFX_PATH / COMBAT_MUSIC / CAMP_MUSIC entries for tracks
## that haven't been sourced yet without erroring.

const CROSSFADE_MIN_DB := -40.0

var _music_players: Array[AudioStreamPlayer] = []
var _current_music_idx := 0
var _current_music_path := ""
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
## Spoken lines (assets/voice): the narrator's story cards, the pay table,
## rival letters. A clip is found by its English text (VoiceLines), so a card
## plays whatever voiced lines it shows, in order, with no ids threaded
## through the story code. English only, and GameState.voice_on.
const VOICE_DIR := "res://assets/voice/"
const VOICE_GAP := 0.35   # seconds between two lines of one scene
var _voice_player: AudioStreamPlayer
var _voice_queue: Array[String] = []
var _voice_key := ""
var _voice_heard := {}   # moments already spoken this session (a re-render doesn't replay them)
var _voice_found := {}   # text -> its clips (a card is matched once)


func _ready() -> void:
	_build_cue_layer()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		add_child(p)
		_music_players.append(p)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = "Voice"
	add_child(_voice_player)
	_voice_player.finished.connect(func():
		var key := _voice_key
		await get_tree().create_timer(VOICE_GAP).timeout
		if key == _voice_key:
			_voice_next())


## Crossfades to `path` over `fade_time` seconds; pass "" to just fade out
## whatever's playing. Repeat calls with the same path are a no-op (a screen
## re-render shouldn't restart its own music). Forces the loaded stream's own
## `loop` flag on regardless of import defaults, rather than trusting the
## format's default (AudioStreamOggVorbis/AudioStreamWAV both expose it),
## so a track always loops here without needing a matching .import tweak.
func play_music(path: String, fade_time: float = 1.0, loop: bool = true) -> void:
	if path == _current_music_path:
		return
	if path != "" and not ResourceLoader.exists(path):
		return
	var old_player := _music_players[_current_music_idx]
	var had_old := old_player.playing
	_current_music_idx = 1 - _current_music_idx
	var new_player := _music_players[_current_music_idx]
	_current_music_path = path
	if had_old:
		var fade_out := create_tween()
		fade_out.tween_property(old_player, "volume_db", CROSSFADE_MIN_DB, fade_time)
		fade_out.tween_callback(old_player.stop)
	if path == "":
		return
	var stream: AudioStream = load(path)
	if "loop" in stream:
		stream.loop = loop   # the opening's track plays once
	new_player.stream = stream
	new_player.volume_db = CROSSFADE_MIN_DB
	new_player.play()
	var fade_in := create_tween()
	fade_in.tween_property(new_player, "volume_db", 0.0, fade_time)


## Seconds into `path` if it's the track playing now, else -1.0 (the
## opening cinematic follows its narrated track by this, not by the clock).
func music_position(path: String) -> float:
	var p := _music_players[_current_music_idx]
	if path != _current_music_path or not p.playing:
		return -1.0
	return p.get_playback_position() + AudioServer.get_time_since_last_mix()


func stop_music(fade_time: float = 1.0) -> void:
	play_music("", fade_time)


## One-shot SFX from a round-robin pool so two quick hits in the same round
## don't cut each other off the way a single shared AudioStreamPlayer would.
func play_sfx(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var p := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = load(path)
	p.play()


## `linear` is 0.0-1.0 (what a settings slider would hand in) — converted to
## the dB scale AudioServer actually uses.
func set_music_volume(linear: float) -> void:
	_music_user_db = linear_to_db(clampf(linear, 0.0001, 1.0))
	_apply_music_bus()


## Music dips under a spoken line (0.59.3): voice and music were mixed at the
## same loudness, so lines were lost under a loud track. The dip holds
## through the short gaps between one scene's lines and lifts when it ends.
const DUCK_DB := -9.0
const DUCK_TIME := 0.25
var _music_user_db := 0.0
var _duck_db := 0.0
var _duck_tween: Tween


func _apply_music_bus() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _music_user_db + _duck_db)


func _duck(on: bool) -> void:
	var target := DUCK_DB if on else 0.0
	if is_equal_approx(_duck_db, target) and (_duck_tween == null or not _duck_tween.is_running()):
		return
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(func(db: float): _duck_db = db; _apply_music_bus(), _duck_db, target, DUCK_TIME)


func music_ducked() -> bool:
	return _duck_db < -0.5


func set_master_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(linear, 0.0001, 1.0)))


func set_sfx_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(clampf(linear, 0.0001, 1.0)))


func set_voice_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear_to_db(clampf(linear, 0.0001, 1.0)))


## The voiced lines inside `text`, in reading order (clip files). A line
## inside a longer voiced one isn't counted twice.
func voice_clips_in(text: String) -> Array[String]:
	if _voice_found.has(text):
		return _voice_found[text]
	var hits := []
	for line in VoiceLines.LINES:
		var at := text.find(str(line[0]))
		if at >= 0:
			hits.append([at, str(line[0]).length(), str(line[1])])
	hits.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] > b[1]))
	var out: Array[String] = []
	var reach := -1
	for h in hits:
		if int(h[0]) >= reach:
			out.append(str(h[2]))
			reach = int(h[0]) + int(h[1])
	_voice_found[text] = out
	return out


## The clip for exactly this line ("" if it isn't voiced): one line of a
## pay-table scene, where a short line could sit inside another's text.
func voice_clip_for(line: String) -> String:
	for l in VoiceLines.LINES:
		if str(l[0]) == line:
			return str(l[1])
	return ""


func voice_wanted() -> bool:
	return GameState.voice_on and GameState.language == "en"


## Speaks `clips` once for the moment `key` (a card, a payday, a letter);
## `again` replays it (a Listen button). Starting one moment stops another.
func play_voice(key: String, clips: Array, again := false) -> void:
	if clips.is_empty() or not voice_wanted() or (_voice_heard.has(key) and not again):
		return
	_voice_heard[key] = true
	_voice_player.stop()
	_voice_key = key
	_voice_queue.assign(clips)
	_voice_next()


## Stops the voice if it's speaking `key_prefix`'s moment (any, for "").
func stop_voice(key_prefix := "") -> void:
	if _voice_key != "" and _voice_key.begins_with(key_prefix):
		_voice_player.stop()
		_voice_queue.clear()
		_voice_key = ""
		_duck(false)


func voice_speaking(key_prefix := "") -> bool:
	return _voice_key != "" and _voice_key.begins_with(key_prefix) and (_voice_player.playing or not _voice_queue.is_empty())


func _voice_next() -> void:
	while not _voice_queue.is_empty():
		var path: String = VOICE_DIR + str(_voice_queue.pop_front())
		if ResourceLoader.exists(path):
			_voice_player.stream = load(path)
			_voice_player.play()
			_duck(true)
			return
	_voice_key = ""
	_duck(false)


# ---------------- Hearing aid ----------------
## A sound that carries information: plays GameData.SFX_PATH[key], and with
## Settings > Hearing aid on also shows `caption` (e.g. "[Heavy blow on
## Bryn]") and, for the biggest moments, pulses the screen's edges in
## `pulse` colour. A sound with no caption still plays as usual.
func cue(key: String, caption: String = "", pulse: Color = Color(0, 0, 0, 0)) -> void:
	play_sfx(str(GameData.SFX_PATH.get(key, "")))
	if not GameState.hearing_aid:
		return
	if caption != "":
		_show_caption(caption)
	if pulse.a > 0.0:
		_pulse_edges(pulse)


const CAPTION_TIME := 2.4
const CAPTIONS_MAX := 4
const PULSE_GAP := 0.6   # at most one edge pulse this often (no strobing)

var _captions: VBoxContainer
var _pulse: TextureRect
var _pulse_at := -10.0


## Captions stack above the bottom edge; the pulse is a ring of colour at
## the window's edges. Both on a layer over everything that keeps running
## while the camp UI is switched off (the Endless Rift).
func _build_cue_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.08, 0.5)
	gt.width = 128
	gt.height = 128
	_pulse = TextureRect.new()
	_pulse.texture = gt
	_pulse.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pulse.stretch_mode = TextureRect.STRETCH_SCALE
	_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pulse.modulate.a = 0.0
	layer.add_child(_pulse)
	_pulse.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_captions = VBoxContainer.new()
	_captions.theme = preload("res://theme/guild_theme.tres")
	_captions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_captions.alignment = BoxContainer.ALIGNMENT_END
	_captions.add_theme_constant_override("separation", 4)
	layer.add_child(_captions)
	_captions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_captions.offset_left = -300
	_captions.offset_right = 300
	_captions.offset_top = -330
	_captions.offset_bottom = -150


func _show_caption(text: String) -> void:
	# The same sound again while its caption is up: count it instead of
	# stacking a duplicate.
	for c in _captions.get_children():
		if c.get_meta("text", "") == text:
			var n := int(c.get_meta("count", 1)) + 1
			c.set_meta("count", n)
			(c.get_child(0) as Label).text = "%s ×%d" % [text, n]
			_fade_caption(c)
			return
	while _captions.get_child_count() >= CAPTIONS_MAX:
		var old := _captions.get_child(0)
		_captions.remove_child(old)
		old.queue_free()
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.03, 0.02, 0.06, 0.85)
	st.set_corner_radius_all(10)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	pill.add_theme_stylebox_override("panel", st)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	pill.add_child(l)
	pill.set_meta("text", text)
	_captions.add_child(pill)
	_fade_caption(pill)


func _fade_caption(pill: Control) -> void:
	if pill.has_meta("tween"):
		var old: Tween = pill.get_meta("tween")
		if old and old.is_valid():
			old.kill()
	pill.modulate.a = 1.0
	var tw := pill.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(CAPTION_TIME)
	tw.tween_property(pill, "modulate:a", 0.0, 0.5)
	tw.tween_callback(pill.queue_free)
	pill.set_meta("tween", tw)


func _pulse_edges(color: Color) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _pulse_at < PULSE_GAP:
		return
	_pulse_at = now
	# Softer with Reduce motion on, still there: it's information, not flair.
	var peak := 0.4 if GameState.reduce_motion else 0.65
	_pulse.self_modulate = Color(color, 1.0)
	_pulse.modulate.a = 0.0
	var tw := _pulse.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_pulse, "modulate:a", peak, 0.08)
	tw.tween_property(_pulse, "modulate:a", 0.0, 0.45)
