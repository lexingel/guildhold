class_name GuildViews
extends CodexView
## Camp-side screens: the camp hub, recruits, champions, medical bay,
## Training Yard, crafting and guild management. Records, the Codex and the
## Quest board live in the parents (RecordsView, CodexView, QuestsView).

# ---------------- Terminal ----------------
func _render_camp_screen(v: VBoxContainer) -> void:
	var tier := Combat.guild_tier_info()
	var tier_name := str(tier["name"])
	# Guild Tier is purely derived (not stored), so "just reached a new tier"
	# is detected by comparing against the last tier seen at render time —
	# UI-only state, not persisted, same as _flavor_toast above.
	if _last_guild_tier_name != "" and _last_guild_tier_name != tier_name:
		GameState.pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("Guild tier reached"), "text": GameData.narrative_line("guild_tier_reached")})
	_last_guild_tier_name = tier_name

	if term_tab == "camp":
		if GameState.runs_started == 0:
			_coach(v, "welcome", "Welcome to your guild", "Rifts are tearing open across the land. First, sign three founders from the recruit board (Roster > Recruits); then head to the Rift Hall (key 3) to seal a rift.")
		elif GameState.runs_started >= 1 and GameState.run.is_empty():
			_coach(v, "after_first_run", "Back at camp", "Equip what you found on the Roster's Hero tab (key 1), spend skill points under Skills, and hire more heroes when you can afford them. Every rift run or rest is one day.")
		_render_camp(v)
		return
	var tab_feature: String = {"inventory": "inventory", "medical": "medical", "bestiary": "bestiary", "quests": "quests", "management": "management", "champions": "champions", "training": "training"}.get(term_tab, "")
	if tab_feature != "" and not GameState.feature_unlocked(tab_feature):
		_locked_feature(v, tab_feature)
		return

	match term_tab:
		"inventory": _render_inventory(v)
		"recruits": _render_recruits(v)
		"champions": _render_champions(v)
		"medical": _render_medical_bay(v)
		"training": _render_training_yard(v)
		"management": _render_management(v)
		"bestiary": _render_bestiary(v)
		"compendium": _render_compendium(v)
		"records": _render_records(v)
		"memorial": _render_memorial(v)
		"ledger": _render_ledger(v)
		"quests": _render_quests(v)
		_: _render_roster(v)


## The guild hub: 6 large, distinct painted buildings (Darkest-Dungeon-style
## reference) instead of either the earlier 11-tiny-prop scene (2 props got
## stuck standing in for destinations their art didn't read as) or the
## card-grid that replaced it (functional, but flat/impersonal). Fewer,
## bigger objects fixes what the first attempt got wrong: every building
## here is large enough to render with a real distinct silhouette. A
## building that covers more than one destination (Command Tent, Rift Gate,
## Trading Post, Scholar's Lodge) opens a small in-place picker
## (_render_hub_cluster) instead of needing precise sub-hotspots on the
## painted art — sidesteps the exact coordinate-precision problem that
## caused the mismatched props last time.
func _render_camp(v: VBoxContainer) -> void:
	if hub_cluster != "":
		_render_hub_cluster(v)
		return

	var bleed := _bleed_ui()
	var win := get_viewport().get_visible_rect().size
	var native: Vector2 = GameData.HAMLET_SIZE
	# Framed (portrait window): a whole-number scale keeps the pixels square.
	# Full-window: the village spans the window's width standing on its
	# bottom edge, and its night sky carries on up behind the menus.
	var whole: float = maxf(1.0, floorf(v.custom_minimum_size.x / native.x))
	if bleed:
		whole = minf(win.x / native.x, (win.y - 150.0) / 125.0)
	var SCENE_SIZE := (native * whole).round()
	var sc := Vector2(whole, whole)
	var scene := Control.new()   # the clickable buildings and their plaques
	var art_host: Control = scene   # the picture, tinted by the day/night drift
	if bleed:
		var origin := Vector2(roundf((win.x - SCENE_SIZE.x) * 0.5), win.y - SCENE_SIZE.y)
		scene.position = origin
		scene.size = SCENE_SIZE
		scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scene_ui.add_child(scene)
		art_host = Control.new()
		art_host.position = origin
		art_host.size = SCENE_SIZE
		art_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scene_art.add_child(art_host)
		var sky := ColorRect.new()
		sky.color = GameData.HAMLET_SKY
		sky.position = -origin
		sky.size = win
		sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_host.add_child(sky)
	else:
		scene.custom_minimum_size = SCENE_SIZE
		scene.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var bg := TextureRect.new()
	bg.texture = load(GameData.HAMLET_BG)
	bg.custom_minimum_size = SCENE_SIZE
	bg.size = SCENE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art_host.add_child(bg)
	_start_daynight_cycle(art_host if bleed else bg)

	_hang_banners(bg, scene, sc)
	# Buildings are children of the backdrop (so the day/night tint reaches
	# them); their click areas and plaques go on the scene above.
	var badges := _camp_badges()
	var targets := _hamlet_targets()
	var plaques: Array = []
	for b in GameData.HAMLET_BUILDINGS:
		var tex: Texture2D = load(GameState.hamlet_texture(b))
		var size := tex.get_size() * sc / GameData.HAMLET_ART_SCALE
		var anchor: Vector2 = b["pos"]
		var rect := Rect2(Vector2(anchor.x * sc.x - size.x * 0.5, anchor.y * sc.y - size.y), size)
		var art := TextureRect.new()
		art.texture = tex
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.position = rect.position
		art.size = rect.size
		bg.add_child(art)
		if b["id"] == "drill":
			_place_trainees(art, sc.x / GameData.HAMLET_ART_SCALE * 0.6)   # people at the buildings' full density stood taller than the tents
		if b["id"] == "campfire":
			_start_ember_loop(scene, Vector2(anchor.x * sc.x, (anchor.y - 16.0) * sc.y))
			continue
		if not GameState.feature_unlocked(str(HAMLET_FEATURE.get(b["id"], ""))):   # where it leads isn't revealed yet: just scenery
			continue
		var tip := tr(str(b["name"])) + (tr(" — the %s") % tr(str(b["building"])) if b.has("building") else "")
		if str(b.get("tier", "")) == "node":
			tip += tr(" — tier %d/3 (%s Lv%d; grows at Lv3 and Lv5)") % [GameState.hamlet_tier(b), tr(str(GameData.find_branch_node(str(b["node"]))["name"])), GameState.lvl(str(b["node"]))]
		elif b["tier"] == "guild":
			tip += tr(" — grows with your guild tier")
		elif b["tier"] == "act":
			tip += tr(" — grows with the campaign")
		var hotspot := _camp_area_hotspot(rect, rect, tip, targets.get(b["id"], func(): pass), false)
		hotspot.position = rect.position
		scene.add_child(hotspot)
		plaques.append([str(b["name"]), rect, b["row"] == "back", str(PLAQUE_BADGE.get(b["id"], "")), hotspot.get_child(1)])

	# Names show on hover once the player knows the camp. They stay up for
	# the first runs, on touch screens (no hover there), and on a building
	# with something to do (its count badge hangs off the name).
	var all_names := GameState.runs_started <= 3 or _compact() or DisplayServer.is_touchscreen_available()
	for pq in plaques:
		var prect: Rect2 = pq[1]
		var plaque := _camp_plaque(str(pq[0]))
		var py: float = prect.position.y - plaque.size.y - 2.0 if pq[2] else minf(prect.end.y - plaque.size.y - 2.0, SCENE_SIZE.y - plaque.size.y - 2.0)
		plaque.position = Vector2(clampf(prect.get_center().x - plaque.size.x * 0.5, 2.0, SCENE_SIZE.x - plaque.size.x - 2.0), py)
		scene.add_child(plaque)
		var badge: Array = badges.get(str(pq[3]), [])
		if not badge.is_empty():
			var chip := _count_badge(str(badge[0]), str(badge[1]))
			chip.position = plaque.position + Vector2(plaque.size.x - 10.0, -12.0)
			scene.add_child(chip)
		elif not all_names:
			plaque.modulate.a = 0.0
			var hot: Button = pq[4]
			hot.mouse_entered.connect(func(): create_tween().tween_property(plaque, "modulate:a", 1.0, 0.12))
			hot.mouse_exited.connect(func(): create_tween().tween_property(plaque, "modulate:a", 0.0, 0.12))

	# The night moving: stars twinkling across the sky, mist drifting past
	# the hills, fireflies over the grass, the campfire's light flickering.
	var sky_top := -art_host.position.y if bleed else 0.0
	_motes(art_host, Rect2(Vector2(-art_host.position.x if bleed else 0.0, sky_top), Vector2(win.x if bleed else SCENE_SIZE.x, 50.0 * whole - sky_top)),
		Color(1, 1, 1, 0.9), 34, Vector2.ZERO, 3.0, Vector2(maxf(2.0, whole * 0.8), maxf(3.0, whole)))
	_motes(art_host, Rect2(Vector2(0, 95.0 * whole), Vector2(SCENE_SIZE.x, 40.0 * whole)), Color(0.75, 0.75, 0.95, 0.07), 9, Vector2(9, 0), 22.0, Vector2(2.5, 4.5), 8.0, true)
	_motes(art_host, Rect2(Vector2(0, 135.0 * whole), Vector2(SCENE_SIZE.x, 40.0 * whole)), Color(0.85, 1.0, 0.45, 0.9), 16, Vector2(12, 0), 4.0, Vector2(maxf(2.0, whole * 0.7), maxf(2.0, whole)))
	var fire: Vector2 = GameData.HAMLET_BUILDINGS.filter(func(b): return b["id"] == "campfire")[0]["pos"]
	_glow(art_host, Vector2(fire.x, fire.y - 14.0) * whole, 34.0 * whole, Color(1.0, 0.55, 0.2, 0.3), "flicker")

	# The status board (with the getting-started steps) top-left over the
	# scene; below it on a narrow screen. Full-window: under the menus.
	if bleed:
		var board_w := _guild_status_board()
		board_w.custom_minimum_size.x = 360
		board_w.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		board_w.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		v.add_child(board_w)
		return
	var board := _guild_status_board()
	if _narrow():
		v.add_child(scene)
		v.add_child(board)
	else:
		board.position = Vector2(10, 10)
		board.custom_minimum_size.x = minf(360.0, SCENE_SIZE.x * 0.42)
		scene.add_child(board)
		v.add_child(scene)


## The reveal each building waits for before it can be clicked.
const HAMLET_FEATURE := {"drill": "training", "infirmary": "medical", "board": "quests", "market": "inventory", "vault": "relics"}


## Which tab's badge each building wears (its count of things to do).
const PLAQUE_BADGE := {"scouts": "recruits", "barracks": "roster", "infirmary": "medical", "lab": "crafting", "vault": "inventory", "board": "quests"}


## Where each hamlet building leads.
## Past guilds' banners, behind the buildings: the newest few, oldest
## first. Hover shows the guild's record; a click opens the Hall of Guilds.
func _hang_banners(bg: Control, scene: Control, sc: Vector2) -> void:
	var past: Array = GameState.legacy.get("guilds", [])
	past = past.slice(maxi(0, past.size() - GameData.BANNER_X.size()))
	for i in past.size():
		var g: Dictionary = past[i]
		var crest := clampi(int(g.get("crest", 1)), 1, GameData.CREST_PATH.size())
		var top := Vector2(float(GameData.BANNER_X[i]), 96.0) * sc
		var pole := ColorRect.new()
		pole.color = Color("3b2a1e")
		pole.position = top
		pole.size = Vector2(1, 54) * sc
		pole.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(pole)
		var bar := ColorRect.new()
		bar.color = pole.color
		bar.position = top + Vector2(-6, 1) * sc
		bar.size = Vector2(13, 1) * sc
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(bar)
		var cloth := Polygon2D.new()
		cloth.color = GameState.banner_cloth(str(g.get("colour", "crest")), crest)
		var pts := PackedVector2Array()
		for p in [Vector2(-5, 2), Vector2(6, 2), Vector2(6, 19), Vector2(0.5, 15), Vector2(-5, 19)]:
			pts.append(top + p * sc)
		cloth.polygon = pts
		bg.add_child(cloth)
		var icon := TextureRect.new()
		icon.texture = load(GameData.CREST_PATH[crest - 1])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = top + Vector2(-4, 4) * sc
		icon.size = Vector2(9, 9) * sc
		bg.add_child(icon)
		var rect := Rect2(top + Vector2(-6, 0) * sc, Vector2(13, 54) * sc)
		var hot := _camp_area_hotspot(rect, Rect2(rect.position, Vector2(13, 20) * sc),
			_past_guild_title(g) + "\n" + _past_guild_line(g), func():
				term_tab = "compendium"
				compendium_tab = "chronicle"
				render(), false)
		hot.position = rect.position
		scene.add_child(hot)


## The Training Yard's trainees (0.58), one at each station, pacing in front
## of it, a little finer than the buildings (standing still with reduced motion).
func _place_trainees(yard: Control, px: float) -> void:
	var trainees := GameState.trainees()
	var n := GameState.training_slots()
	for i in mini(trainees.size(), n):
		var h: Hero = trainees[i]
		var key := WalkSprites.hero_key(h, GameData.hero_role(h))
		var s := WalkSprites.make(key, px)
		s.material = UiKit.look_material(GameState.look_for(h))
		var away := GameData.faces_away(key)
		s.flip_h = away
		var home := Vector2(yard.size.x * (i + 0.5) / n, yard.size.y - 3.0 * px)
		s.position = home
		yard.add_child(s)
		if GameState.reduce_motion:
			s.stop()
			continue
		var tw := s.create_tween().set_loops()
		var step := 7.0 * px
		tw.tween_callback(func(): s.flip_h = away)
		tw.tween_property(s, "position:x", home.x + step, 1.1)
		tw.tween_callback(func(): s.flip_h = not away)
		tw.tween_property(s, "position:x", home.x - step, 2.2)
		tw.tween_callback(func(): s.flip_h = away)
		tw.tween_property(s, "position:x", home.x, 1.1)


func _hamlet_targets() -> Dictionary:
	return {
		"scouts": func(): term_tab = "recruits"; render(),
		"hall": func(): hub_cluster = "guild_hall"; render(),
		"lab": func(): hub_cluster = "arcane_lab"; render(),
		"barracks": func(): term_tab = "roster"; render(),
		"infirmary": func(): term_tab = "medical"; render(),
		"drill": func(): term_tab = "training"; render(),
		"board": func(): term_tab = "quests"; render(),
		"gate": func(): screen = "rift_hall"; render(),
		"market": func(): term_tab = "inventory"; inv_category = "items"; render(),
		"vault": func(): term_tab = "inventory"; inv_category = "relics"; render(),
	}


## What needs you right now: each line opens where to act on it.
func _guild_status_board() -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(Palette.INK, 0.8)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", st)
	var col := _vbox(0)
	var head := _label("Guild status", 15)
	head.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
	col.add_child(head)
	if not GameState.heroes.is_empty():
		col.add_child(_week_strip())
	# The first-guild checklist rides here (it was a second card): the next
	# step still to do, opening where to do it.
	var guide := _getting_started_steps()
	if not guide.is_empty():
		var gap := Control.new()
		gap.custom_minimum_size.y = 4
		col.add_child(gap)
		var gh := HBoxContainer.new()
		var gl := _label(tr("Getting started — %d/%d") % [int(guide["done"]), int(guide["total"])], 12)
		gl.tooltip_text = "\n".join((guide["steps"] as Array).map(func(s): return "○ " + tr(str(s[0]))))
		gl.mouse_filter = Control.MOUSE_FILTER_STOP
		gl.add_theme_color_override("font_color", Palette.MUTED)
		gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gh.add_child(gl)
		var hide := LinkButton.new()
		hide.text = tr("Hide")
		hide.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
		hide.add_theme_font_size_override("font_size", 12)
		hide.add_theme_color_override("font_color", Palette.MUTED)
		hide.tooltip_text = tr("Hide the getting-started steps")
		hide.pressed.connect(func():
			GameState.guide_hidden = true
			GameState.save()
			render())
		gh.add_child(hide)
		col.add_child(gh)
	# Three goals, always in view (0.53): what moves the story, what makes the
	# guild stronger, and one thing worth doing on the side.
	var goals := _guild_goals()
	for g in goals:
		var gb := Button.new()
		gb.flat = true
		gb.text = "%s  %s" % [tr(str(g[0])), tr(str(g[1]))]
		gb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		gb.add_theme_font_size_override("font_size", 14)
		gb.add_theme_color_override("font_color", g[2])
		gb.add_theme_color_override("font_hover_color", Palette.EMBER_BRIGHT)
		gb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		gb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var gt := StyleBoxEmpty.new()
		gt.content_margin_top = 1
		gt.content_margin_bottom = 1
		for sn in ["normal", "hover", "pressed", "focus"]:
			gb.add_theme_stylebox_override(sn, gt)
		gb.tooltip_text = tr(str(g[1]))
		gb.pressed.connect(g[3])
		col.add_child(gb)
	if not goals.is_empty():
		col.add_child(_hsep())
	var lines: Array = (guide.get("steps", []) as Array).slice(0, 1) + _guild_status_lines()
	if lines.is_empty():
		col.add_child(_label("All quiet. The rifts are waiting.", 12, true))
	for ln in lines.slice(0, 7 if not guide.is_empty() else 6):
		var b := Button.new()
		b.flat = true
		b.text = ("○  " if ln.size() > 3 else "›  ") + tr(str(ln[0]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		# One colour for the list, red only for what's urgent (it used five).
		b.add_theme_color_override("font_color", Palette.HAZARD if ln[1] == Palette.HAZARD else Palette.TEXT)
		b.add_theme_color_override("font_hover_color", Palette.EMBER_BRIGHT)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var tight := StyleBoxEmpty.new()
		tight.content_margin_top = 1
		tight.content_margin_bottom = 1
		for sn in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(sn, tight)
		b.tooltip_text = str(ln[0])
		b.pressed.connect(ln[2])
		col.add_child(b)
	p.add_child(col)
	return p


## This week: days to payday, the bill against the treasury, and what the
## guild has made since the last one. Click for the Ledger.
func _week_strip() -> Control:
	var f := GameState.payday_forecast()
	var box := _vbox(1)
	var top := _label(tr("This week · payday in %d day%s") % [int(f["days"]), tr(str(_pl(int(f["days"]))))], 12)
	top.add_theme_color_override("font_color", Palette.MUTED)
	box.add_child(top)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	bar.max_value = maxi(1, int(f["bill"]))
	bar.value = mini(int(f["have"]), int(f["bill"]))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.RANK_E if int(f["short"]) == 0 else Palette.HAZARD
	var back := StyleBoxFlat.new()
	back.bg_color = Color(Palette.LINE, 0.6)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	box.add_child(bar)
	var bill := tr("Bill %d (wages %d + upkeep %d) · %s") % [int(f["bill"]), int(f["wages"]), int(f["upkeep"]), tr(str("covered" if int(f["short"]) == 0 else tr("short %d") % int(f["short"])))]
	var bl := _label(bill, 12)
	bl.add_theme_color_override("font_color", Palette.COINS if int(f["short"]) == 0 else Palette.HAZARD)
	box.add_child(bl)
	var since := int(f["since"])
	box.add_child(_label(tr("Since last payday: %s%d Gold") % [tr(str("+" if since >= 0 else "")), since], 11, true))
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.tooltip_text = tr("Wages go out every %d days, heroes in roster order, then facility upkeep. Unpaid heroes lose morale; unpaid upkeep costs Renown. Click for the Ledger.") % GameData.PAYDAY_DAYS
	box.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			term_tab = "ledger"
			render())
	return box


## [text, colour, action] for the status board, most urgent first.
func _guild_status_lines() -> Array:
	var out: Array = []
	var go_term := func(tab: String): return func(): term_tab = tab; render()
	var go_screen := func(s: String): return func(): screen = s; render()
	if GameState.heroes.is_empty():
		out.append(["Hire your first hero in Recruits", Palette.EMBER_BRIGHT, go_term.call("recruits")])
	if GameState.breach_broken():
		out.append([tr("The rift has broken! Defend near %s") % GameState.breach_place(), Palette.HAZARD, go_screen.call("defense")])
	elif GameState.breach_active():
		var dl := GameState.breach_days_left()
		out.append([tr("A Rank %s rift breaks in %d day%s") % [tr(GameState.breach_rank_id()), dl, tr(str(_pl(dl)))], Palette.EMBER_BRIGHT, go_screen.call("rift_hall")])
	if not GameState.damaged.is_empty():
		out.append([tr("%d building%s damaged: repair in Manage") % [GameState.damaged.size(), tr(str(_pl(GameState.damaged.size())))], Palette.HAZARD, go_term.call("management")])
	if not GameState.camp_event.is_empty():
		out.append([GameState.camp_event_title() + tr(" — answer today"), Palette.EMBER_BRIGHT, go_term.call("ledger")])
	if not GameState.camp_omen.is_empty():
		out.append([tr("Tomorrow: %s") % tr(str(GameData.CAMP_EVENTS[str(GameState.camp_omen["id"])]["title"])), Palette.HAZARD, go_term.call("ledger")])
	if not GameState.heroes.is_empty():
		if not GameState.hero_request.is_empty():
			out.append([GameState.request_title() + tr(" — answer before payday"), Palette.EMBER_BRIGHT, go_term.call("ledger")])
		if not GameState.rival_event.is_empty():
			out.append([GameState.rival_event_title() + (tr(" — by payday") if GameState.rival_event.get("accepted", false) else tr(" — answer before payday")), Palette.RANK_S, go_term.call("ledger")])
		var low := GameState.heroes.filter(func(h): return h.morale < 40)
		if not low.is_empty():
			out.append([tr("%d hero%s with low morale") % [low.size(), tr(str(_pl(low.size(), "es")))], Palette.HAZARD, go_term.call("ledger")])
		var due_soon := GameState.guild_board.filter(func(q): return str(q["status"]) == "active" and GameState.quest_progress(q) < int(q["target"]) and int(q.get("due", 1 << 30)) - GameState.day <= 2)
		if not due_soon.is_empty():
			out.append([tr("%d contract%s due within 2 days") % [due_soon.size(), tr(str(_pl(due_soon.size())))], Palette.HAZARD, go_term.call("quests")])
	var claimable := GameState.guild_board.filter(func(q): return GameState.quest_progress(q) >= int(q["target"]))
	if not claimable.is_empty() and GameState.feature_unlocked("quests"):
		out.append([tr("%d quest%s ready to claim") % [claimable.size(), tr(str(_pl(claimable.size())))], Palette.RANK_E, go_term.call("quests")])
	var down := GameState.heroes.filter(func(h): return h.is_downed())
	var hurt := GameState.heroes.filter(func(h): return GameState.needs_recovery(h) and not h.is_downed())
	if not down.is_empty() or not hurt.is_empty():
		var bits: Array[String] = []
		if not down.is_empty():
			bits.append(tr("%d recovering") % down.size())
		if not hurt.is_empty():
			bits.append(tr("%d wounded") % hurt.size())
		var free := GameState.medical_bed_cap() - GameState.occupied_beds()
		out.append([tr("%s · %d bed%s free") % [tr(str(", ".join(bits))), free, tr(str(_pl(free)))], Palette.HAZARD if not down.is_empty() else Palette.MUTED, go_term.call("medical")])
	var sp := GameState.heroes.filter(func(h): return h.skill_points > 0 or h.attr_points > 0)
	if not sp.is_empty():
		out.append([tr("%d hero%s with points to spend") % [sp.size(), tr(str(_pl(sp.size(), "es")))], Palette.TEXT, go_term.call("roster")])
	if GameState.feature_unlocked("management"):
		var best := ""
		var best_cost := 1 << 30
		for br in GameData.BRANCHES:
			for n in br["nodes"]:
				var key := "%s.%s" % [br["id"], n["id"]]
				var c := GameState.room_cost(key)
				if c > 0 and c < best_cost and GameState.room_open(key):
					best_cost = c
					best = tr("%s Lv%d") % [tr(str(n["name"])), int(GameState.upgrades.get(key, 0)) + 1]
		if best != "" and GameState.coins >= best_cost:
			out.append([tr("Room ready to build: %s (%d Gold)") % [tr(str(best)), best_cost], Palette.COINS, go_term.call("management")])
	if not GameState.wing_offer.is_empty():
		out.append([tr("A wing of the hall is on offer (%d Gold)") % GameState.hall_work_cost(), Palette.COINS if GameState.coins >= GameState.hall_work_cost() else Palette.MUTED, go_term.call("management")])
	return out


## The board's three goals (0.53): [tag, text, colour, action] for the story,
## growing stronger, and one optional thing. Empty before the first hero.
func _guild_goals() -> Array:
	if GameState.heroes.is_empty():
		return []
	var out: Array = []
	var go_term := func(tab: String): return func(): term_tab = tab; render()
	var go_screen := func(s: String): return func(): screen = s; render()
	var act := GameState.current_act()
	if act.is_empty():
		out.append(["Story", tr("The campaign is done: push the Descent and the ladder to SSS"), Palette.EMBER_BRIGHT, go_screen.call("rift_hall")])
	elif GameState.finale_ready():
		out.append(["Story", tr("Face the finale: %s") % tr(str(act["finale"])), Palette.EMBER_BRIGHT, go_screen.call("rift_hall")])
	else:
		for o in act["objectives"]:
			if not GameState.campaign_objective_met(o):
				var prog := "" if str(o["type"]) == "map_rank" else " (%d/%d)" % [mini(GameState.campaign_objective_progress(o), int(o["target"])), int(o["target"])]
				out.append(["Story", tr("Act %s: %s%s") % [tr(str(GameState._roman(int(act["act"])))), tr(str(o["label"])), tr(str(prog))], Palette.EMBER_BRIGHT, go_screen.call("rift_hall")])
				break
	# Grow: the Act panel's advice once the guild is stuck (advice_due) or has
	# Gold/Essence lying idle (spare_wealth), else the rank to climb.
	var behind := GameState.advice_due(_best_party_power()) or GameState.spare_wealth()
	var advice: Array = GameState.power_advice() if behind else []
	if not advice.is_empty():
		var a: Dictionary = advice[0]
		var where: Callable = {"evolve": go_term.call("roster"), "recruit": go_term.call("recruits"), "drill": go_term.call("management"), "hall_work": go_term.call("management"), "train": go_term.call("training"), "forge": go_term.call("roster"), "relic": go_term.call("inventory"), "management": go_term.call("management"), "champion": go_term.call("champions")}.get(str(a["kind"]), go_term.call("roster"))
		out.append(["Grow", str(a["text"]), Palette.TEXT, where])
	else:
		out.append(["Grow", tr("Seal a Rank %s rift: better gear, more Essence") % tr(GameState.highest_open_rank()), Palette.TEXT, go_screen.call("rift_hall")])
	# Optional: a lost champion, else a contract, else the Tower.
	if GameState.feature_unlocked("champions") and GameState.next_lost_champion() != "":
		out.append(["Optional", tr("Find a lost champion in the Descent or a Rank B+ rift"), Palette.MUTED, go_screen.call("rift_hall")])
	elif GameState.feature_unlocked("quests") and GameState.guild_board.any(func(q): return str(q["status"]) == "posted"):
		out.append(["Optional", tr("Take a contract from the Quest board"), Palette.MUTED, go_term.call("quests")])
	elif GameState.feature_unlocked("tower") and GameState.tower_next_floor() > 0:
		out.append(["Optional", tr("Tower of Trials: floor %d next") % GameState.tower_next_floor(), Palette.MUTED, go_screen.call("tower")])
	return out


## The small in-place picker a multi-destination building opens instead of
## navigating straight away — reuses _hub_card for visual consistency with
## anything else card-styled in the game.
func _render_hub_cluster(v: VBoxContainer) -> void:
	var title := ""
	var entries: Array = []
	match hub_cluster:
		"guild_hall":
			title = "Guild Hall"
			entries = [
				[GameData.CAMP_HUB_ICON_PATH["management"], "Accord Hall", func(): hub_cluster = ""; term_tab = "management"; render()],
				["res://assets/skills/gem_blue_a.png", "Ledger", func(): hub_cluster = ""; term_tab = "ledger"; render()],
				[GameData.CAMP_HUB_ICON_PATH["compendium"], "Codex", func(): hub_cluster = ""; term_tab = "compendium"; render()],
				["res://assets/skills/trophy.png", "Records", func(): hub_cluster = ""; term_tab = "records"; render()],
				["res://assets/skills/helm.png", "Memorial", func(): hub_cluster = ""; term_tab = "memorial"; render()],
			]
		"arcane_lab":
			title = "Arcane Lab"
			entries = [
				[GameData.CAMP_HUB_ICON_PATH["crafting"], "Smithy", func(): hub_cluster = ""; screen = "crafting_hall"; render()],
				[GameData.CAMP_HUB_ICON_PATH["bestiary"], "Bestiary", func(): hub_cluster = ""; term_tab = "bestiary"; render()],
			]
	v.add_child(_label(title, 18))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var entry_feature := {"Accord Hall": "management", "Smithy": "forge", "Bestiary": "bestiary"}
	for entry in entries:
		var fid: String = entry_feature.get(str(entry[1]), "")
		if fid == "" or GameState.feature_unlocked(fid):   # a destination not revealed yet isn't shown
			row.add_child(_hub_card(entry[0], entry[1], entry[2]))
	v.add_child(row)


## A champion's card: portrait, Boon, Call and story, with Oversee and Level
## up; a champion not yet freed is a silhouette with where to find them.
func _champion_card(id: String) -> PanelContainer:
	var d := GameData.champion_def(id)
	var freed := GameState.champion_unlocked(id)
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanelEmber" if GameState.overseer == id else &"CardPanel"
	card.custom_minimum_size.x = 320
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var pic := _icon_trimmed(GameData.champion_portrait(id), 96)
	if not freed:
		pic.modulate = Color(0.05, 0.04, 0.08, 0.9)
	row.add_child(pic)
	var col := _vbox(3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not freed:
		col.add_child(_label("???", 15))
		var act := GameState.champion_roll.find(id) + 1
		var hint := ""
		if act >= 1 and act <= GameData.CHAMPION_STORY_ACTS:
			hint = tr("Freed at the end of Act %s.") % tr(str(GameState._roman(act)))
		else:
			for e in GameState.lost_champions():
				if str(e[0]) == id:
					hint = tr("Lost in the Endless Rift: their light waits in a pillar of the Descent, or of a Rank B+ rift.")
		col.add_child(_wrap_label(hint, 12, true))
		row.add_child(col)
		card.add_child(row)
		return card
	var lv := GameState.champion_level(id)
	var nm := _label(GameData.champion_full_name(id), 15)
	nm.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
	col.add_child(nm)
	col.add_child(_label(tr("%s · Level %d/%d") % [tr(str(d["role"]).capitalize()), lv, GameData.CHAMPION_LEVEL_MAX], 12, true))
	var boon := _wrap_label(tr("Boon: ") + GameState.champion_boon_text(id), 12)
	boon.add_theme_color_override("font_color", Palette.good())
	col.add_child(boon)
	var call := GameState.champion_call_of(id)
	var times := 2 if lv >= GameData.CHAMPION_EXTRA_CALL_LEVEL else 1
	col.add_child(_wrap_label(tr("Call: %s — %s (%s)") % [tr(str(call["name"])), tr(str(call["desc"])), tr("twice a rift") if times == 2 else tr("once a rift")], 12))
	var lore := _wrap_label(tr(str(d.get("lore", ""))), 11, true)
	lore.tooltip_text = GameState.champion_memory_line(id)   # the Broken Accord: what they remember (also in the Chronicle)
	lore.mouse_filter = Control.MOUSE_FILTER_STOP
	col.add_child(lore)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	var oversee := _button(tr("Overseeing") if GameState.overseer == id else tr("Oversee rifts"), func(i=id):
		GameState.set_overseer(i)
		render()
	)
	oversee.disabled = GameState.overseer == id
	oversee.tooltip_text = tr("The overseer's Boon lifts the whole party in every rift run, and any hero can spend their turn on the Call.")
	btns.add_child(oversee)
	var cost := GameState.champion_level_cost(id)
	if cost >= 0:
		var up := _button(tr("Level up — %d Essence") % cost, func(i=id):
			var err := GameState.level_champion(i)
			if err != "":
				push_warning(err)
			render()
			if err == "":
				_payoff(tr("%s reaches level %d") % [GameData.champion_full_name(i), GameState.champion_level(i)], tr("Boon and Call grow stronger"), Palette.CRYSTALS, "level_up")
		)
		up.disabled = GameState.crystals < cost
		up.tooltip_text = tr("Each level: Boon and Call +%d%%. At level %d the Call works twice a rift.") % [int(GameData.CHAMPION_LEVEL_POWER * 100), GameData.CHAMPION_EXTRA_CALL_LEVEL]
		btns.add_child(up)
	col.add_child(btns)
	row.add_child(col)
	card.add_child(row)
	return card


func _render_champions(v: VBoxContainer) -> void:
	_coach(v, "champions", "Champions", "Champions are freed by the story and rescued from pillars of light in the Descent and Rank B+ rifts. One oversees your rift runs: the whole party gets their Boon, and any hero can spend a turn on their Call. Spend Essence here to level them up.")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(_label("Champions", 20))
	var ech := _label(tr("Essence: %d") % GameState.crystals, 15)
	ech.add_theme_color_override("font_color", Palette.CRYSTALS)
	ech.tooltip_text = tr("Spend it to level up champions.")
	ech.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ech)
	v.add_child(head)
	var freed := GameState.champion_roll.filter(func(i): return GameState.champion_unlocked(i)).size()
	v.add_child(_wrap_label(tr("%d of %d champions found. Every new guild meets a different twelve.") % [freed, GameState.champion_roll.size()], 12, true))
	# A grid, so every card lines up (a flow sized each row to its own cards).
	var grid := GridContainer.new()
	grid.columns = 1 if _narrow() else 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for id in GameState.champion_roll:
		var c := _champion_card(id)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(c)
	v.add_child(grid)


func _render_recruits(v: VBoxContainer) -> void:
	if GameState.signing_founders():
		var fp := PanelContainer.new()
		fp.theme_type_variation = &"CardPanelEmber"
		var fc := _vbox(4)
		fc.add_child(_label(tr("Sign your founders: %d to go") % GameState.founding_picks, 16))
		fc.add_child(_wrap_label(tr("Every founder signs free and brings their first week's wages. A party of four needs someone in front and someone who heals. Free rerolls left: %d.") % GameState.founding_rerolls, 13))
		fp.add_child(fc)
		v.add_child(fp)
	_coach(v, "recruits", "Hiring heroes", "Recruit heroes below; higher ranks are stronger.")
	v.add_child(_wrap_label(tr("New faces arrive every day and wait a few days; payday fills the board. Each reroll or commission doubles the next until payday (back to %d Gold).%s") % [GameState.recruit_reroll_base(), tr(" The rival may sign your best offer first.") if GameState.feature_unlocked("rival") else ""], 12, true))
	v.add_child(_wrap_label(tr("Rank odds: %s%s") % [tr(str(GameData.rank_odds_text())), tr(str(tr("  ·  Scouts' Lodge: a C+ recruit is assured each payday") if GameState.headhunter_guarantee() else ""))], 11, true))
	v.add_child(_hsep())

	v.add_child(_label(tr("Hero Recruits — %d/%d roster slots") % [GameState.heroes.size(), GameState.hero_slot_cap()]))
	if GameState.heroes.size() >= GameState.hero_slot_cap():
		var full := _wrap_label(tr("Your roster is full. The Barracks (Guild > Manage > Operations) adds 2 slots a level; you can also let a hero go from the Ledger."), 13)
		full.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
		v.add_child(full)
	elif GameState.recruit_pool.is_empty():
		v.add_child(_wrap_label(tr("No one is looking for work right now. New faces arrive every day."), 13, true))
	# Ask for a role instead of rerolling until one turns up.
	var com := HFlowContainer.new()
	com.add_theme_constant_override("h_separation", 6)
	com.add_theme_constant_override("v_separation", 6)
	var cl := _label(tr("Commission a recruit (%d Gold):") % GameState.commission_cost(), 12, true)
	cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	com.add_child(cl)
	for role in ["warrior", "rogue", "ranger", "mage", "cleric"]:
		var cb := _button(tr(role.capitalize()), func(r=role):
			var err := GameState.commission_recruit(r)
			if err != "":
				push_warning(err)
			render()
		)
		cb.disabled = GameState.coins < GameState.commission_cost()
		cb.tooltip_text = tr("A %s joins the offers at the usual rank odds (the last offer leaves).") % tr(role)
		com.add_child(cb)
	v.add_child(com)
	for h in GameState.recruit_pool:
		var rank := GameData.find_rank(h.rank)
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Palette.SURFACE2
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_right = 8
		style.corner_radius_bottom_left = 8
		style.content_margin_left = 8.0
		style.content_margin_top = 6.0
		style.content_margin_right = 8.0
		style.content_margin_bottom = 6.0
		card.add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_framed_portrait(h.cls_id, h.pool_id, 56.0, GameState.look_for(h)))
		var mid := _vbox(2)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.add_child(_label(h.name, 13))
		var price := tr("free") if GameState.signing_founders() else tr("%d Gold") % int(rank["cost"])
		mid.add_child(_label(tr("Rank %s %s · %s · Power %d · %d HP · wage %d/week") % [tr(str(h.rank)), tr(str(h.cls_id.capitalize())), price, Combat.power_of(h), Combat.max_hp(h), GameState.wage_of(h)], 11, true))
		mid.add_child(_recruit_traits(h))
		# 0.62: a base class; what a hire brings and which trainings it can start.
		var brings := tr("Brings %d skill and %d attribute points") % [h.skill_points, h.attr_points] if h.skill_points + h.attr_points > 0 else tr("A fresh recruit")
		var ri := GameData.rank_index(h.rank)
		var ready_stages := 0
		for st in range(1, 4):
			if ri >= GameData.rank_index(str(GameData.STAGE_RANK[st])):
				ready_stages = st
		var trains := tr("trains a Path at Rank D") if ready_stages == 0 else tr("ready for stage %d training") % 1
		mid.add_child(_label(tr("%s · %s") % [brings, trains], 10, true))
		row.add_child(mid)
		var left := GameState.offer_days_left(h)
		var stay := _label(tr("Last day") if left <= 0 else (tr("Leaves tomorrow") if left == 1 else tr("Leaves in %d days") % left), 12, left > 1)
		if left <= 1:
			stay.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
		stay.tooltip_text = tr("Waits on the board until day %d, then takes work elsewhere.") % (GameState.day + left)
		stay.mouse_filter = Control.MOUSE_FILTER_STOP
		stay.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not GameState.signing_founders():   # the founding board waits for you
			row.add_child(stay)
		var free_rr := GameState.signing_founders() and GameState.founding_rerolls > 0
		var rr := _button(tr("Reroll (free, %d left)") % GameState.founding_rerolls if free_rr else tr("Reroll (%d Gold)") % GameState.recruit_reroll_cost(), func(id=h.id):
			var err := GameState.reroll_recruit_offer(id)
			if err != "":
				push_warning(err)
			render()
		)
		rr.disabled = not free_rr and GameState.coins < GameState.recruit_reroll_cost()
		rr.tooltip_text = tr("Swap this offer for a new face. The next reroll costs double, until payday.")
		row.add_child(rr)
		var hire := _icon_domain_button("ember", GameData.CAMP_HUB_ICON_PATH["recruits"], "Recruit", func(id=h.id, nm=h.name, rk=h.rank):
			var err := GameState.recruit_hero(id)
			if err != "":
				push_warning(err)
			render()
			if err == "":
				_payoff(tr("%s joins the guild!") % tr(str(nm.split(" the ")[0])), tr("Rank %s") % tr(str(rk)), Palette.rank_color(str(rk)), "level_up")
		)
		var why := tr("Roster is full.") if GameState.heroes.size() >= GameState.hero_slot_cap() else (tr("Not enough Gold.") if GameState.coins < int(rank["cost"]) else "")
		hire.disabled = why != ""
		hire.tooltip_text = why
		row.add_child(hire)
		card.add_child(row)
		v.add_child(card)


## A recruit's make-up at a glance: their attributes (the one they lean
## on stands out) and their born quirk, so two offers of a rank differ.
func _recruit_traits(h: Hero) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	var top := ""
	for a in ["might", "agility", "focus"]:
		if top == "" or int(h.attrs.get(a, 0)) > int(h.attrs.get(top, 0)):
			top = a
	var tip := tr("Leans on %s. Might: damage and HP · Agility: speed, dodge, first strike · Focus: ability power, mending.") % tr(top.capitalize())
	for a in ["might", "agility", "focus"]:
		var al := _label("%s %d" % [tr(a.capitalize()), int(h.attrs.get(a, 0))], 11, a != top)
		if a == top:
			al.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
		al.tooltip_text = tip
		al.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(al)
	for q in h.quirks:
		var t := GameData.quirk(q)
		var chip := _label(q, 11)
		chip.add_theme_color_override("font_color", Palette.HAZARD if t.get("treatable", false) else Palette.good())
		chip.tooltip_text = "%s — %s" % [tr(str(q)), tr(str(GameState.quirk_text(q)))]
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(chip)
	return row


func _render_medical_bay(v: VBoxContainer) -> void:
	v.add_child(_label(tr("Medical Bay — %d/%d beds occupied") % [GameState.occupied_beds(), GameState.medical_bed_cap()], 16))
	if GameState.field_triage_available():
		v.add_child(_wrap_label("Field Triage: once per rift, get a downed hero back up mid-rift.", 12, true))
	# Wider and taller than the hub strip on a PC screen (playtest 2026-10-09).
	var mw := minf(get_viewport().get_visible_rect().size.x - 64.0, 860.0)
	var med := _banner(GameData.MEDICAL_BG, mw, roundf(mw * (0.3 if _narrow() else 0.42)))
	med.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(med)

	var bedded: Array[Hero] = []
	bedded.assign(GameState.heroes.filter(func(h): return GameState.needs_recovery(h) and h.bedded))
	var waiting: Array[Hero] = []
	waiting.assign(GameState.heroes.filter(func(h): return GameState.needs_recovery(h) and not h.bedded))
	var free := GameState.medical_bed_cap() - GameState.occupied_beds()

	# The beds as cards (they used to be drawn at fixed spots on the picture,
	# which put them and their labels off it on a narrow window).
	var beds := HFlowContainer.new()
	beds.add_theme_constant_override("h_separation", 8)
	beds.add_theme_constant_override("v_separation", 8)
	for i in GameState.medical_bed_cap():
		var card := PanelContainer.new()
		card.theme_type_variation = &"CardPanelViolet"
		card.custom_minimum_size = Vector2(190, 0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var bed_icon := _icon(GameData.BED_ICON, 40)
		row.add_child(bed_icon)
		var col := _vbox(0)
		if i < bedded.size():
			var h: Hero = bedded[i]
			col.add_child(_label(h.name.split(" the ")[0], 13))
			col.add_child(_label(tr("%d/%d HP · %s") % [h.hp, Combat.max_hp(h), tr(_recovery_text(h, true))], 11, true))
		else:
			bed_icon.modulate = Color(1, 1, 1, 0.45)
			col.add_child(_label(tr("Empty bed"), 13, true))
		row.add_child(col)
		card.add_child(row)
		beds.add_child(card)
	v.add_child(beds)

	if not waiting.is_empty():
		v.add_child(_label(tr("Recovering without a bed (slower):"), 13))
		for h in waiting:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			var info := _wrap_label(tr("%s — %d/%d HP (%s) · %s") % [tr(str(h.name)), h.hp, Combat.max_hp(h), tr("downed") if h.is_downed() else tr("wounded"), tr(str(_recovery_text(h, false)))], 12)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(info)
			var put := _icon_domain_button("ember", "res://assets/skills/heart.png", "Put in a bed", func(id=h.id):
				GameState.assign_to_bed(id)
				render()
			)
			put.disabled = free <= 0
			put.tooltip_text = tr("Every bed is taken") if free <= 0 else tr("A downed hero comes back a run sooner; a wounded one is fully healed after the next run.")
			row.add_child(put)
			v.add_child(row)

	# Time only passes when a run ends — resting passes it without one.
	v.add_child(_hsep())
	var rest := _icon_button("res://assets/skills/heart.png", "Rest the guild (pass one run's time)", func():
		GameState.rest_guild()
		render()
	)
	rest.tooltip_text = "Heroes recover as if a run had ended."
	rest.disabled = not GameState.run.is_empty()
	v.add_child(rest)
	v.add_child(_wrap_label(tr("Recovery counts rift runs, not real time: a downed hero sits out %d run(s) (a bed takes one off); a wounded hero regains %d%% HP each run (all of it in a bed).") % [GameState.recovery_runs(), int(GameData.WOUND_HEAL_PER_RUN * 100)], 12, true))


var _train_program := {}   # hero id -> the program picked on the Training Yard screen


## The Training Yard (0.58): its stations (who is training what, with a
## Recall), then every hero free to train with a program and 1-3 days.
func _render_training_yard(v: VBoxContainer) -> void:
	var trainees := GameState.trainees()
	v.add_child(_label(tr("Training Yard — %d/%d stations in use") % [trainees.size(), GameState.training_slots()], 16))
	v.add_child(_wrap_label(tr("Each day a hero spends here: +1 point in their program (up to %d trained per hero). Courses of 2 or 3 days also give XP, up to your best hero's level (Lv%d). Trainees sit out runs; a day passes with every run or rest. Upgrade the Drill Yard for more stations.") % [GameData.ATTR_TRAIN_CAP, GameState.train_level_cap()], 12, true))
	var stations := HFlowContainer.new()
	stations.add_theme_constant_override("h_separation", 8)
	stations.add_theme_constant_override("v_separation", 8)
	for i in GameState.training_slots():
		var card := PanelContainer.new()
		card.theme_type_variation = &"CardPanelViolet"
		card.custom_minimum_size = Vector2(230, 0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var col := _vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i < trainees.size():
			var h: Hero = trainees[i]
			row.add_child(_hero_icon(h, 40))
			col.add_child(_label(h.name.split(" the ")[0], 13))
			var t: Dictionary = h.training
			var prog := str(t["program"])
			var prog_name := tr(str(GameData.find_class(prog.trim_prefix("subclass:")).get("name", ""))) if prog.begins_with("subclass:") else (tr("Mastery %d") % (h.mastery + 1) if prog == "mastery" else tr(str(GameData.ATTR_LABEL.get(prog, prog))))
			col.add_child(_label(tr("%s · day %d of %d") % [prog_name, int(t["total"]) - int(t["left"]) + 1, int(t["total"])], 11, true))
			row.add_child(col)
			var back := _button("Recall", func(id=h.id):
				var refund := GameState.recall_training(id)
				_flavor_toast = tr("Recalled: %d Essence back for the days not started.") % refund if refund > 0 else ""
				render()
			)
			back.tooltip_text = tr("Days done are kept; today's training and its fee are lost, the days not started are refunded.")
			back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(back)
		else:
			col.add_child(_label(tr("Free station"), 13, true))
			row.add_child(col)
		card.add_child(row)
		stations.add_child(card)
	v.add_child(stations)

	var free: Array = GameState.heroes.filter(func(h): return not h.is_champion and h.training.is_empty())
	if free.is_empty():
		return
	_render_subclass_training(v, free)
	_render_mastery(v, free)
	v.add_child(_hsep())
	v.add_child(_label(tr("Send a hero to train"), 14))
	var room := GameState.training_free() > 0
	for h in free:
		var row := HFlowContainer.new()   # wraps on the phone canvas
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 4)
		row.add_child(_hero_icon(h, 32))
		var info := _vbox(0)
		info.custom_minimum_size.x = 170
		info.add_child(_label(tr("%s · Lv%d") % [h.name.split(" the ")[0], h.level], 13))
		var why := "" if h.is_available() and not (GameState.run.get("hero_ids", []) as Array).has(h.id) else (tr("in a rift") if (GameState.run.get("hero_ids", []) as Array).has(h.id) else tr("not fit to train"))
		info.add_child(_label(why if why != "" else tr("Trained %d/%d") % [h.attr_trained, GameData.ATTR_TRAIN_CAP], 11, true))
		row.add_child(info)
		# Program: the hero's role attribute first.
		var spread: Array = GameData.ROLE_ATTR_SPREAD.get(GameData.hero_role(h), ["might"])
		var pick := str(_train_program.get(h.id, spread[0]))
		for a in GameData.ATTRIBUTES:
			var pb := _button(tr(str(GameData.ATTR_LABEL[a])), func(id=h.id, at=a): _train_program[id] = at; render())
			pb.toggle_mode = true
			pb.button_pressed = a == pick
			pb.tooltip_text = tr(str(GameData.ATTR_DESC[a]))
			row.add_child(pb)
		for d in GameData.TRAIN_DAYS:
			var db := _icon_button(GameData.CURRENCY_ICON_PATH["crystals"], tr("%d day%s · %d") % [d, tr(str(_pl(d))), GameState.train_fee(h, d)], func(id=h.id, days=d, at=pick):
				var err := GameState.start_training(id, at, days)
				_flavor_toast = err
				render()
			)
			db.disabled = why != "" or not room or GameState.crystals < GameState.train_fee(h, d)
			db.tooltip_text = tr("%d day%s of %s: +%d point%s%s") % [d, tr(str(_pl(d))), tr(str(GameData.ATTR_LABEL[pick])), mini(d, GameData.ATTR_TRAIN_CAP - h.attr_trained), tr(str(_pl(mini(d, GameData.ATTR_TRAIN_CAP - h.attr_trained)))), tr(" and XP") if d >= 2 and h.level < GameState.train_level_cap() else ""]
			row.add_child(db)
		v.add_child(row)


## Path Mastery (0.65): heroes who've finished their Path train ranks here,
## a day and Essence each; every rank makes their Path rule 4% stronger.
func _render_mastery(v: VBoxContainer, free: Array) -> void:
	var done: Array = free.filter(func(h): return h.path != "" and GameData.subclass_stage(h.pool_id) >= 1)
	if done.is_empty():
		return
	v.add_child(_hsep())
	v.add_child(_label(tr("Path Mastery"), 14))
	v.add_child(_wrap_label(tr("A hero on a Path can master it: each rank makes their Path rule %d%% stronger, for a day at the yard. Each Path stage opens more ranks (3, 6, then all %d).") % [int(round(GameData.MASTERY_STEP * 100)), GameData.MASTERY_MAX], 12, true))
	for h in done:
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_child(_hero_icon(h, 32))
		var path: Dictionary = GameData.PATHS.get(GameData.hero_path_id(h), {})
		var info := _vbox(0)
		info.custom_minimum_size.x = 220
		info.add_child(_label(tr("%s · %s") % [h.name.split(" the ")[0], tr(str(path.get("rule", {}).get("name", "")))], 13))
		info.add_child(_label(tr("Mastery %d/%d · +%d%%") % [h.mastery, GameState.mastery_cap(h), int(round(GameData.MASTERY_STEP * h.mastery * 100))], 11, true))
		row.add_child(info)
		if h.mastery < GameData.MASTERY_MAX:
			var lock := GameState.mastery_lock(h)
			var b := _icon_button(GameData.CURRENCY_ICON_PATH["crystals"], tr("Rank %d · %d Essence") % [h.mastery + 1, GameState.mastery_cost(h)], func(id=h.id):
				_flavor_toast = GameState.train_mastery(id)
				render())
			b.disabled = lock != ""
			b.tooltip_text = lock if lock != "" else tr("%s: %s") % [tr(str(path.get("rule", {}).get("name", ""))), tr(str(path.get("rule", {}).get("desc", "")))]
			row.add_child(b)
		v.add_child(row)


## Subclass training (0.62): heroes who've reached a stage's rank (D, B, S)
## train into a subclass of a Path here. Pick a hero, then a subclass.
func _render_subclass_training(v: VBoxContainer, free: Array) -> void:
	var ready: Array = free.filter(func(h): return GameState.next_training_stage(h) > 0 and GameData.rank_index(h.rank) >= GameData.rank_index(str(GameData.STAGE_RANK[GameState.next_training_stage(h)])))
	v.add_child(_hsep())
	v.add_child(_label(tr("Subclass training"), 14))
	v.add_child(_wrap_label(tr("At Rank D a hero can train into a Path's first subclass, at Rank B the second, at Rank S the third (or a Legend). New subclasses unlock with acts, Tower floors and deeds (Codex › Paths)."), 12, true))
	if ready.is_empty():
		v.add_child(_label(tr("No hero is ready yet: the first training opens at Rank D."), 12, true))
		return
	if not ready.any(func(h): return h.id == _subclass_hero_id):
		_subclass_hero_id = ready[0].id
	var pick_row := HFlowContainer.new()
	pick_row.add_theme_constant_override("h_separation", 6)
	pick_row.add_theme_constant_override("v_separation", 6)
	for h in ready:
		var hb := _button(tr("%s · Rank %s · stage %d") % [h.name.split(" the ")[0], tr(h.rank), GameState.next_training_stage(h)], func(id=h.id): _subclass_hero_id = id; render())
		hb.toggle_mode = true
		hb.button_pressed = h.id == _subclass_hero_id
		pick_row.add_child(hb)
	v.add_child(pick_row)
	var hero: Hero = ready.filter(func(h): return h.id == _subclass_hero_id)[0]
	var grid := GridContainer.new()
	grid.columns = 1 if _narrow() else 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for o in GameState.subclass_training_options(hero):
		grid.add_child(_subclass_option_card(hero, o))
	v.add_child(grid)


func _subclass_option_card(h: Hero, o: Dictionary) -> PanelContainer:
	var sid := str(o["id"])
	var cls := GameData.find_class(sid)
	var path: Dictionary = GameData.PATHS.get(str(o["path"]), {})
	var lock := str(o["lock"])
	var unlocked := GameState.subclass_unlocked(sid)
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var pic := _icon_trimmed(GameData.portrait_for_hero(str(cls.get("role", "")), sid), 48)
	if not unlocked:
		pic.modulate = Color(0.1, 0.08, 0.14, 0.9)
	row.add_child(pic)
	var col := _vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := tr("%s · %s") % [tr(str(cls.get("name", sid))), tr(str(path.get("name", "")))]
	if GameData.is_legend(sid):
		title = tr("%s · Legend") % tr(str(cls.get("name", sid)))
	var nm := _label(title, 13)
	if bool(o["change"]):
		nm.text += tr(" (change Path)")
	col.add_child(nm)
	var what := ""
	match int(o["stage"]):
		1: what = tr("Rule, %s: %s") % [tr(str(path["rule"]["name"])), _cap(tr(str(path["rule"]["desc"])))]
		2: what = tr("Technique, %s: %s") % [tr(str(path["technique"]["name"])), _cap(tr(str(path["technique"]["desc"])))]
		3: what = (tr("Legend: %s") % _cap(tr(str(path.get("legend", ""))))) if GameData.is_legend(sid) else tr("Signature, %s: %s") % [tr(str(path["signature"]["name"])), _cap(tr(str(path["signature"]["desc"])))]
	col.add_child(_wrap_label(what, 11, true))
	if GameData.SUBCLASS_TWIST.has(sid):
		var tw := _wrap_label(tr("Twist: %s") % tr(str(GameData.SUBCLASS_TWIST[sid])), 11)
		tw.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
		col.add_child(tw)
	var c: Dictionary = o["cost"]
	var btn := _icon_button(GameData.CURRENCY_ICON_PATH["coins"], tr("Train · %d Gold · %d Essence · %d days") % [int(c["gold"]), int(c["essence"]), int(c["days"])], func(id=h.id, pid=sid):
		var err := GameState.start_subclass_training(id, pid)
		_flavor_toast = err
		render())
	btn.disabled = lock != ""
	btn.tooltip_text = lock
	col.add_child(btn)
	if lock != "":
		col.add_child(_wrap_label(lock, 11, true))
	row.add_child(col)
	card.add_child(row)
	return card


## "back in 2 runs" / "full after next run" — recovery in runs, not seconds.
func _recovery_text(h: Hero, bedded: bool) -> String:
	if h.is_downed():
		return tr("back in %d run%s") % [h.down_runs, tr(str(_pl(h.down_runs)))]
	if bedded:
		return tr("full after next run")
	return tr("+%d%% HP per run") % int(GameData.WOUND_HEAL_PER_RUN * 100)


## Plays a short "pop into existence" reveal on a freshly-appended icon
## (the item/relic Crafting Hall just produced) before the caller's render()
## replaces the whole screen — scale up from tiny + a bright flash, not a
## looping effect since it only ever plays once per craft.
func _play_craft_flourish(v: VBoxContainer, icon_path: String) -> void:
	AudioManager.play_sfx(GameData.SFX_PATH["craft"])
	var rect := _icon(icon_path, 40)
	var wrap := _wrap_icon(rect)
	wrap.scale = Vector2(0.2, 0.2)
	wrap.modulate = Color(1.6, 1.5, 1.9)
	v.add_child(wrap)
	var tween := create_tween()
	tween.tween_property(wrap, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(wrap, "modulate", Color(1, 1, 1), 0.4)
	await _await_or_timeout(tween.finished, 1.0)


## A workbench hub for turning excess common/rare loot into something better
## instead of just selling it: feed 3 unequipped items (same category+rarity)
## or 3 unequipped relics (same type+rarity) into one craft for 1 of the next
## rarity up. Reuses Combat.gen_item/gen_relic entirely — no new loot tables.
## "2/3 — need 1 more" until a craft is possible, then how many crafts.
func _craft_count(count: int) -> String:
	if count < 3:
		return tr("%d/3 — need %d more") % [count, 3 - count]
	return tr("%d owned — ready to craft%s") % [count, tr(str(" (x%d)" % (count / 3) if count >= 6 else ""))]


## The Smithy (0.66): one screen for gear's four actions. Temper the
## lineup's gear (Gold), combine three spare items into one of the next
## rarity, reforge a spare item's stat line (its card), salvage for Essence.
## Combine and reforge come with the apprentice (Act III).
func _render_crafting_hall(v: VBoxContainer) -> void:
	v.add_child(_label("The Smithy", 20))
	var scene := _hub_banner(GameData.CRAFTING_BG, 160)
	scene.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(scene)
	var full := GameState.feature_unlocked("crafting")

	# Temper: what the heroes wear, least tempered first.
	v.add_child(_label("Temper", 16))
	v.add_child(_wrap_label(tr("Every rolled stat on a piece grows %d%% a temper, up to %d. Each costs more than the last.") % [int(GameData.FORGE_STEP * 100), GameData.FORGE_MAX], 12, true))
	var worn: Array = GameState.items.filter(func(it): return it.equipped_to != "" and GameState.forge_cost(it) > 0)
	worn.sort_custom(func(a, b): return GameState.forge_cost(a) < GameState.forge_cost(b))
	if worn.is_empty():
		v.add_child(_label("Everything the heroes wear is fully tempered.", 12, true))
	for it in worn.slice(0, 8):
		var who := GameState.find_hero(it.equipped_to)
		var cost := GameState.forge_cost(it)
		var tb := _icon_button(GameData.CURRENCY_ICON_PATH["coins"], tr("Temper · %d Gold") % cost, func(id=it.id):
			_flavor_toast = GameState.forge_item(id)
			render())
		tb.disabled = GameState.coins < cost
		v.add_child(_info_row(tr("%s's %s — tempered %d/%d") % [tr(str(who.name.split(" the ")[0])) if who else "?", tr(_loot_display_name(it)), it.forge_level, GameData.FORGE_MAX], 13, [tb], _icon(GameData.item_icon(it), 20)))

	# Combine: three spare items of a category and rarity.
	v.add_child(_hsep())
	v.add_child(_label("Combine", 16))
	if not full:
		v.add_child(_wrap_label("Combining and reforging come with the smith's apprentice, in Act III.", 12, true))
	else:
		v.add_child(_wrap_label("Three spare items of one category and rarity become one of the next rarity up.", 12, true))
		var groups: Dictionary = {}
		for it in GameState.items:
			if it.equipped_to == "" and GameState.CRAFT_RARITY_UP.has(it.rarity):
				var key := "%s|%s" % [it.category, it.rarity]
				groups[key] = int(groups.get(key, 0)) + 1
		if groups.is_empty():
			v.add_child(_label("No spare Common or Rare items.", 12, true))
		for key in groups.keys():
			var parts: PackedStringArray = key.split("|")
			var category: String = parts[0]
			var rarity: String = parts[1]
			var count: int = groups[key]
			var next_rarity: String = str(GameState.CRAFT_RARITY_UP[rarity])
			var cb := _icon_button(GameData.CAMP_HUB_ICON_PATH["crafting"], tr("Combine → %s") % tr(str(GameData.find_rarity(next_rarity)["name"])), func(c=category, r=rarity):
				if _crafting_animating:
					return
				_crafting_animating = true
				if GameState.state_changed.is_connected(_on_state_changed):
					GameState.state_changed.disconnect(_on_state_changed)
				GameState.craft_items(c, r)
				await _play_craft_flourish(v, GameData.ITEM_CATEGORY_ICON_PATH[c])
				if not GameState.state_changed.is_connected(_on_state_changed):
					GameState.state_changed.connect(_on_state_changed)
				_crafting_animating = false
				render())
			cb.disabled = count < 3
			v.add_child(_info_row("%s %s — %s" % [tr(str(GameData.find_rarity(rarity)["name"])), tr(str(GameData.ITEM_CATEGORY_LABEL[category])), tr(str(_craft_count(count)))], 13, [cb], _icon(GameData.ITEM_CATEGORY_ICON_PATH[category], 20), count < 3))

	# Spare gear: reforge (on its card) or salvage.
	v.add_child(_hsep())
	v.add_child(_label("Spare gear", 16))
	var spare: Array = GameState.items.filter(func(it): return it.equipped_to == "")
	spare.sort_custom(func(a, b): return GameData.find_rarity(a.rarity)["mult"] < GameData.find_rarity(b.rarity)["mult"])
	if spare.is_empty():
		v.add_child(_label("No spare gear.", 12, true))
	for it in spare.slice(0, 12):
		var acts: Array[Control] = []
		if full and it.unique_id == "":
			acts.append(_button("Reforge…", func(id=it.id): selected_item_id = id; render()))
		var sb := _icon_button(GameData.CURRENCY_ICON_PATH["crystals"], tr("Salvage +%d") % GameState.salvage_value(it), func(id=it.id):
			GameState.salvage_item(id)
			render())
		acts.append(sb)
		v.add_child(_info_row(tr(_loot_display_name(it)), 13, acts, _icon(GameData.item_icon(it), 20)))
	if spare.size() > 12:
		v.add_child(_label(tr("…and %d more in the Inventory.") % (spare.size() - 12), 12, true))
	var sel: Array = GameState.items.filter(func(it): return it.id == selected_item_id)
	if not sel.is_empty():
		_item_modal(sel[0])
