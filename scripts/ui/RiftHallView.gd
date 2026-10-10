class_name RiftHallView
extends GuildViews
## Going into a rift: the Rift Hall (ranks, gates, modes), the Tower of
## Trials, Party Assembly and the breach card. Split out of Main.gd in 0.69.2;
## Main extends this, and this calls only down the chain (render() is UiKit's
## virtual that Main overrides).


## Content column width: combat, the camp scene and the two-pane screens
## use the window's width; text-heavy screens stay at a readable measure.
func _column_width() -> float:
	var avail: float = get_viewport().get_visible_rect().size.x - 64.0
	if screen == "rift_run":
		return _battle_width()
	if screen == "title":
		return avail
	if screen == "camp" and ((term_tab == "camp" and hub_cluster == "") or term_tab in ["roster", "inventory", "bestiary"]):
		return clampf(avail, minf(760.0, avail), 1180.0)
	return clampf(avail, minf(700.0, avail), 860.0)


# ---------------- Rift Hall ----------------
## The Descent and the Lesser ranks are each a gate on the rift chamber's background
## art, clickable straight into Party Assembly — no intermediate detail view
## since there's nothing else to decide here, unlike Guild Management/
## Inventory's hubs. The chained third gateway in the art gets a hotspot too
## once GameState.greater_rift_unlocked() — inert (no hotspot at all) before that.
## The current act: its foe, objectives with progress, and the finale — open
## once every objective is met.
func _render_campaign_panel(v: Container) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"CardPanelEmber"
	var cv := _vbox(6)
	if GameState.campaign_done():
		cv.add_child(_label("The campaign is complete", 16))
		cv.add_child(_wrap_label("The Sky Beneath is behind you. Rifts still open: go deeper in the Descent, climb the rift ladder to SSS, take on quests, and finish what the Chronicle lists.", 12, true))
		panel.add_child(cv)
		v.add_child(panel)
		return
	var act := GameState.current_act()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var foe_icon := _icon(GameData.sprite_for_monster(str(act["boss"])), 44)
	head.add_child(foe_icon)
	var hv := _vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := _label(tr("Act %s — %s") % [tr(str(GameState._roman(int(act["act"])))), tr(str(act["name"]))], 17)
	t.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
	hv.add_child(t)
	hv.add_child(_label(tr("Foe: %s") % tr(str(act["foe"])), 12, true))
	head.add_child(hv)
	cv.add_child(head)
	for o in act["objectives"]:
		var met := GameState.campaign_objective_met(o)
		var prog := "" if str(o["type"]) == "map_rank" else " (%d/%d)" % [min(GameState.campaign_objective_progress(o), int(o["target"])), int(o["target"])]
		var ol := _label("%s %s%s" % [tr(str("✓" if met else "○")), tr(str(o["label"])), tr(str(prog))], 13)
		ol.add_theme_color_override("font_color", Palette.RANK_E if met else Palette.TEXT)
		cv.add_child(ol)
	var ready := GameState.finale_ready()
	var fb := _icon_domain_button("ember", GameData.CAMP_HUB_ICON_PATH["rift"], tr("Face the finale: %s") % tr(str(act["finale"])), func():
		pending_party.clear()
		_prefill_party = true
		screen = "party_assembly"
		_pending_diff_id = str(act["tier"])
		_pending_rift_rank = ""
		_pending_finale = true
		render()
	)
	fb.disabled = not ready
	fb.tooltip_text = tr("Recommended power %d") % GameState.finale_recommended_power() if ready else tr("Complete every objective above first")
	fb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cv.add_child(fb)
	var best := _best_party_power()
	var rec := GameState.finale_recommended_power()
	var due := GameState.advice_due(best)
	if ready or due:
		cv.add_child(_power_readout(best, rec, "Your best"))
		if due:   # Deadly: say what raises power, not just that it's short (also when too weak to meet the objectives)
			var advice: Array = GameState.power_advice()
			if advice.is_empty():
				var tip := _wrap_label(tr("Your best party is at %d%% of what the finale expects. Seal more rifts at your top rank for gear, evolve heroes at level 10, level your champion, and build the Drill Yard.") % int(round(100.0 * best / maxf(1.0, rec))), 12, true)
				tip.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
				cv.add_child(tip)
			else:   # the best next step in view (the dock is short); the rest on hover
				var al := _wrap_label(tr("Next step: %s") % str(advice[0]["text"]), 12)
				al.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
				if advice.size() > 1:
					al.tooltip_text = tr("Also: %s") % " ".join(advice.slice(1).map(func(a): return str(a["text"])))
					al.mouse_filter = Control.MOUSE_FILTER_STOP
				cv.add_child(al)
	panel.add_child(cv)
	v.add_child(panel)


func _render_rift_hall(v: VBoxContainer) -> void:
	var wide := _bleed_ui()
	if not wide:
		v.add_child(_label("Rift Hall", 20))
	if not GameState.heroes.is_empty():
		var f := GameState.payday_forecast()
		var msg := tr("Payday in %d day%s: %d Gold due, you have %d — ") % [int(f["days"]), tr(str(_pl(int(f["days"])))), int(f["bill"]), int(f["have"])]
		if int(f["short"]) == 0:
			msg += tr("covered.")
		elif int(f["runs"]) > 0:
			msg += tr("short %d; about %d rift%s at your recent pay (%d each) covers it.") % [int(f["short"]), int(f["runs"]), tr(str(_pl(int(f["runs"])))), int(f["per_run"])]
		else:
			msg += tr("short %d.") % int(f["short"])
		var pay_col: Color = Palette.COINS if int(f["short"]) == 0 else Palette.HAZARD
		if wide:
			# On the hall's stone it needs a dark backing to read.
			var chip := _rule_chip(msg, "", pay_col)
			(chip.get_child(0) as Label).add_theme_color_override("font_color", pay_col)
			chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			v.add_child(chip)
		else:
			var fl := _wrap_label(msg, 12)
			fl.add_theme_color_override("font_color", pay_col)
			v.add_child(fl)
	if GameState.breach_active():
		v.add_child(_breach_card())
	_coach(v, "rift_hall", "Choosing a rift", "Rifts come in ranks, F to SSS. Seal a rank to open the next. The readout compares your best party's power with what the rift expects — Deadly, Risky, Even or Favored. Your very first rift is a shorter training run.")
	if _ladder_pick == "" or GameState.ladder_rank_lock(_ladder_pick) != "":
		_ladder_pick = GameState.highest_open_rank()

	var unlocked := GameState.greater_rift_unlocked()
	var go := func(rank_id: String):
		pending_party.clear()
		_prefill_party = true
		_pending_tower = false
		_pending_descent = false
		_pending_breach = false
		_pending_daily = _ladder_twist and GameState.daily_available()
		screen = "party_assembly"
		_pending_rift_rank = rank_id
		_pending_diff_id = str(GameData.find_rift_rank(rank_id)["base"])
		_pending_finale = false
		render()
	# The two rift gates in the art: the Lesser ranks (F-D) on the left, the
	# Greater ranks (C-SSS) on the chained archway once Act II opens them.
	var best_of := func(base: String) -> String:
		var out := ""
		for r in GameData.RIFT_RANKS:
			if str(r["base"]) == base and GameState.ladder_rank_lock(str(r["id"])) == "":
				out = str(r["id"])
		return out
	var lesser_pick: String = _ladder_pick if str(GameData.find_rift_rank(_ladder_pick)["base"]) == "lesser" else best_of.call("lesser")
	var endless_open := GameState.endless_unlocked()
	var greater_pick: String = _ladder_pick if str(GameData.find_rift_rank(_ladder_pick)["base"]) == "greater" else best_of.call("greater")
	var greater_open: bool = unlocked and greater_pick != ""
	# Each gate: [its name, its area on the old 700x340 stage, the gate in the
	# 320x200 art, where it leads (an empty Callable while it's locked)].
	# The big centre portal is the ranked rifts, the small left one the
	# Descent (playtest 2026-10-09: the main way in should be the biggest).
	var gates := [
		[tr("The Descent") + ("" if endless_open else tr(" — locked")), Rect2(0, 0, 230, 340), Rect2(18, 65, 68, 98),
			_rift_mode_defs(go)[0][3] if endless_open else Callable()],
		[tr("Rank %s Rift") % tr(str(lesser_pick)), Rect2(230, 0, 240, 340), Rect2(110, 20, 97, 130), go.bind(lesser_pick)],
		[tr("Rank %s Rift") % tr(str(greater_pick)) if greater_open else (tr("Ranks C-SSS — locked") if not unlocked else tr("Rank C — %s") % tr(str(GameState.ladder_rank_lock("C")))),
			Rect2(470, 0, 230, 340), Rect2(230, 30, 78, 140), go.bind(greater_pick) if greater_open else Callable()],
	]
	var best := _best_party_power()
	if wide:
		_rift_hall_wide(v, gates, best, go)
		return
	if _compact():
		# The phone canvas: no gate art to scroll past; the act and the ladder side by side, the other modes under them.
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 8)
		_render_campaign_panel(cols)
		(cols.get_child(cols.get_child_count() - 1) as Control).custom_minimum_size.x = 250
		var ladder := _ladder_card(best, go)
		ladder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(ladder)
		v.add_child(cols)
		v.add_child(_rift_mode_rows(best, go))
		return

	var scene := Control.new()
	scene.custom_minimum_size = HUB_SCENE
	scene.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bg := TextureRect.new()
	bg.texture = load(GameData.RIFTHALL_BG)
	bg.custom_minimum_size = HUB_SCENE
	bg.size = HUB_SCENE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scene.add_child(bg)
	for g in gates:
		var area := _hub_rect(g[1])
		var cb: Callable = g[3]
		if cb.is_valid():
			var native_rect: Rect2 = g[2]
			var hotspot := _camp_area_hotspot(area, Rect2(native_rect.position * HUB_ART_SCALE, native_rect.size * HUB_ART_SCALE), str(g[0]), cb)
			hotspot.position = area.position
			scene.add_child(hotspot)
		else:
			var lock_plaque := _camp_plaque(str(g[0]))
			lock_plaque.position = Vector2(area.position.x + (area.size.x - lock_plaque.size.x) * 0.5, area.end.y - lock_plaque.size.y - 6)
			scene.add_child(lock_plaque)
	v.add_child(scene)
	_render_campaign_panel(v)
	v.add_child(_ladder_card(best, go))
	v.add_child(_rift_mode_cards(best, go))


## Height of the Rift Hall's bottom row of cards on a landscape window.
const RIFT_DOCK_H := 236.0
## The hall's floor, continued below the art on a tall window.
const RIFTHALL_FLOOR := Color(0.34, 0.32, 0.26)


## The Rift Hall on a landscape window: the hall fills it (torches flicker,
## the portal breathes and sheds motes), its gates are the way in, and the
## campaign, the rift ladder and the other modes sit along the bottom.
func _rift_hall_wide(v: VBoxContainer, gates: Array, best: int, go: Callable) -> void:
	var native := Vector2(320, 200)
	var win := get_viewport().get_visible_rect().size
	# Always the hall's full width: the side gates are the way in, so they
	# must never be cropped. A window taller than the art (a square browser
	# window) carries the floor on below it, where the cards sit anyway.
	var s := win.x / native.x
	var h := roundf(native.y * s)
	var r := Rect2(Vector2(0.0, minf(0.0, roundf((win.y - h) * 0.3))), Vector2(win.x, h))
	var at := func(p: Vector2) -> Vector2: return r.position + p * s
	if r.end.y < win.y:
		var fg := Gradient.new()
		fg.colors = PackedColorArray([RIFTHALL_FLOOR, RIFTHALL_FLOOR.darkened(0.6)])
		var ft := GradientTexture2D.new()
		ft.gradient = fg
		ft.fill_from = Vector2(0.5, 0.0)
		ft.fill_to = Vector2(0.5, 1.0)
		ft.width = 4
		ft.height = 64
		var floor_fill := TextureRect.new()
		floor_fill.texture = ft
		floor_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		floor_fill.stretch_mode = TextureRect.STRETCH_SCALE
		floor_fill.position = Vector2(0.0, r.end.y - 2.0)
		floor_fill.size = Vector2(win.x, win.y - r.end.y + 2.0)
		floor_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scene_art.add_child(floor_fill)
	_art_rect(GameData.RIFTHALL_BG, r, _scene_art)
	for p in [Vector2(13, 70), Vector2(100, 78), Vector2(219, 77), Vector2(308, 70)]:
		_glow(_scene_art, at.call(p), 18.0 * s, Color(1.0, 0.6, 0.25, 0.4), "flicker")
	_glow(_scene_art, at.call(Vector2(160, 88)), 58.0 * s, Color(0.6, 0.3, 1.0, 0.3), "pulse")
	_glow(_scene_art, at.call(Vector2(52, 118)), 26.0 * s, Color(0.3, 0.8, 1.0, 0.22), "pulse")
	_motes(_scene_art, Rect2(at.call(Vector2(125, 50)), Vector2(70, 95) * s), Color(0.8, 0.6, 1.0, 0.8), 26, Vector2(0, -16), 3.5, Vector2(2, 4), 25.0)
	_motes(_scene_art, Rect2(at.call(Vector2(0, 140)), Vector2(320, 60) * s), Color(1.0, 0.8, 0.6, 0.35), 18, Vector2(6, -3), 8.0, Vector2(2, 3))
	# Name plaques stand at each gate's foot, or just above the cards.
	var plaque_floor := win.y - 20.0 - RIFT_DOCK_H - 10.0
	for g in gates:
		var nr: Rect2 = g[2]
		var gr := Rect2(at.call(nr.position), nr.size * s)
		var cb: Callable = g[3]
		if cb.is_valid():
			var hotspot := _camp_area_hotspot(gr, gr, str(g[0]), cb, false)
			hotspot.position = gr.position
			_scene_ui.add_child(hotspot)
		var plaque := _camp_plaque(str(g[0]))
		plaque.position = Vector2(roundf(gr.get_center().x - plaque.size.x * 0.5), roundf(minf(gr.end.y, plaque_floor) - plaque.size.y - 4.0))
		_scene_ui.add_child(plaque)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	var dock := ScrollContainer.new()
	dock.custom_minimum_size.y = RIFT_DOCK_H
	dock.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_render_campaign_panel(row)
	(row.get_child(row.get_child_count() - 1) as Control).custom_minimum_size.x = 280
	var ladder := _ladder_card(best, go)
	ladder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ladder)
	var modes := _rift_mode_rows(best, go)
	modes.custom_minimum_size.x = 330
	row.add_child(modes)
	dock.add_child(row)
	v.add_child(dock)


## The modes besides the ladder: [name, what it is, recommended power,
## where it leads, why it's locked ("" when open), button text].
func _rift_mode_defs(go: Callable) -> Array:
	var descend := func():
		go.call(GameState.descent_rank())
		_pending_descent = true
		_pending_daily = false
		render()
	var defs := [
		["The Descent", tr("Turn-based, with your heroes: depth after depth, each harder; lost champions wait in pillars · deepest %d") % GameState.descent_best, Combat.recommended_power("", GameState.descent_rank()), descend,
			"" if GameState.endless_unlocked() else tr("Opens when you complete Act II"), "Assemble party"],
		["Tower of Trials", tr("100 fixed floors · best floor %d") % GameState.tower_best, GameState.tower_recommended_power(maxi(1, GameState.tower_next_floor())),
			func(): screen = "tower"; render(), "" if GameState.feature_unlocked("tower") else tr("Opens when you complete Act I"), "Enter the Tower"],
	]
	return defs


## The other modes as cards: what each is, how your strongest party measures
## up, and the button to go.
func _rift_mode_cards(best: int, go: Callable) -> HFlowContainer:
	var cards := HFlowContainer.new()
	cards.alignment = FlowContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 10)
	for cd in _rift_mode_defs(go).filter(func(d): return str(d[4]) == ""):   # a mode not yet revealed isn't shown
		var card := PanelContainer.new()
		card.custom_minimum_size.x = 270
		var cv := _vbox(6)
		cv.add_child(_label(str(cd[0]), 16))
		cv.add_child(_label(str(cd[1]), 12, true))
		if str(cd[4]) != "":
			cv.add_child(_wrap_label(str(cd[4]), 12, true))
			card.modulate = Color(1, 1, 1, 0.6)
		else:
			var pr := _power_readout(best, int(cd[2]), "Your best party")
			pr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(pr)
			var b := _icon_domain_button("ember", GameData.CAMP_HUB_ICON_PATH["rift"], str(cd[5]), cd[3])
			b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			cv.add_child(b)
		card.add_child(cv)
		cards.add_child(card)
	return cards


## The other modes as compact rows, for the Rift Hall's bottom row of cards.
func _rift_mode_rows(best: int, go: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"CardPanelViolet"
	var col := _vbox(8)
	var open := _rift_mode_defs(go).filter(func(d): return str(d[4]) == "")   # a mode not yet revealed isn't shown
	if open.is_empty():
		col.add_child(_wrap_label("Other ways into the rifts open as the story goes on.", 12, true))
	for cd in open:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var tv := _vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Two short lines each (what it is is the name's tooltip) so all three fit.
		var name_l := _label(str(cd[0]), 15)
		name_l.tooltip_text = str(cd[1])
		name_l.mouse_filter = Control.MOUSE_FILTER_STOP
		tv.add_child(name_l)
		var locked := str(cd[4]) != ""
		if locked:
			var why := _label(str(cd[4]), 12, true)
			why.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			why.clip_text = true
			why.tooltip_text = why.text
			why.mouse_filter = Control.MOUSE_FILTER_STOP
			tv.add_child(why)
		else:
			tv.add_child(_power_readout(best, int(cd[2]), "Your best"))
		row.add_child(tv)
		if locked:
			row.modulate = Color(1, 1, 1, 0.6)
		else:
			var b := _button("Go", cd[3])
			b.tooltip_text = str(cd[5])
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)
		col.add_child(row)
	p.add_child(col)
	return p


## The rift ladder: one button per rank (locked ones say why), and the picked
## rank's floors, foes, rewards, extra rules and power readout.
func _ladder_card(best: int, go: Callable) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanelEmber"
	var cv := _vbox(8)
	cv.add_child(_label("Rift Ladder", 17))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	var next_locked := ""
	for r in GameData.RIFT_RANKS:
		var rid := str(r["id"])
		var lock := GameState.ladder_rank_lock(rid)
		if lock != "" and next_locked == "":
			next_locked = tr("Next: Rank %s — %s") % [tr(str(rid)), tr(str(lock))]
		var b := _button(rid, func(): _ladder_pick = rid; render())
		b.custom_minimum_size = Vector2(46, 40)
		b.toggle_mode = true
		b.button_pressed = rid == _ladder_pick
		b.add_theme_color_override("font_color", Palette.rank_color(rid))
		if lock != "":
			# Still in its rank's colour, just softer, so the whole ladder
			# ahead reads at a glance.
			b.disabled = true
			b.add_theme_color_override("font_disabled_color", Color(Palette.rank_color(rid), 0.6))
			b.tooltip_text = tr("Rank %s — %s") % [tr(str(rid)), tr(str(lock))]
		elif GameState.best_rift_rank_sealed >= GameData.rift_rank_index(rid):
			b.tooltip_text = tr("Rank %s — sealed") % tr(str(rid))
		row.add_child(b)
	cv.add_child(row)
	if GameState.key_region_open():   # Pip's Key: the player picks the region
		var reg := HFlowContainer.new()
		reg.add_theme_constant_override("h_separation", 6)
		reg.add_child(_label("Pip's Key:", 12, true))
		var seen := {}
		for r_id in [""] + GameState.open_regions():
			if seen.has(r_id):
				continue
			seen[r_id] = true
			var rb := _button(tr("Any region") if r_id == "" else tr(str(GameData.BIOMES[r_id]["name"])), func(id=r_id):
				GameState.chosen_region = id
				GameState.save()
				render())
			rb.toggle_mode = true
			rb.button_pressed = GameState.chosen_region == r_id or (r_id == "" and not GameState.open_regions().has(GameState.chosen_region))
			reg.add_child(rb)
		cv.add_child(reg)
	var rank: Dictionary = GameData.find_rift_rank(_ladder_pick)
	var base: Dictionary = GameData.DIFFICULTIES[0]
	for d in GameData.DIFFICULTIES:
		if d["id"] == rank["base"]:
			base = d
	var rules: Array[String] = []
	for k in GameData.RIFT_RANK_RULE_TEXT:
		if rank.get(k, false):
			rules.append(tr(str(GameData.RIFT_RANK_RULE_TEXT[k])))
	var t := _label(tr("Rank %s · %d floors") % [tr(str(_ladder_pick)), int(base["floors"])], 15)
	t.add_theme_color_override("font_color", Palette.rank_color(_ladder_pick))
	var go_row := HBoxContainer.new()
	go_row.add_theme_constant_override("separation", 10)
	var pick_col := _vbox(2)
	pick_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick_col.add_child(t)
	var pr := _power_readout(best, Combat.recommended_power("", _ladder_pick), "Your best party")
	pr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pick_col.add_child(pr)
	go_row.add_child(pick_col)
	var b := _icon_domain_button("ember", GameData.CAMP_HUB_ICON_PATH["rift"], "Assemble party", go.bind(_ladder_pick))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go_row.add_child(b)
	cv.add_child(go_row)
	var foes := tr("Foes: base") if float(rank["hp"]) == 1.0 else tr("Foes: ×%s health, ×%s damage") % [tr(str(rank["hp"])), tr(str(rank["dmg"]))]
	cv.add_child(_wrap_label(tr("%s%s · Rewards ×%s%s") % [tr(str(base["name"])) + " · ", tr(str(foes)), tr(str(rank["reward"])), tr(str((" · " + ", ".join(rules)) if not rules.is_empty() else ""))], 12, true))
	var stakes := _stakes_line(_ladder_pick)
	if stakes != "":
		var sl := _wrap_label(stakes, 12)
		sl.add_theme_color_override("font_color", Palette.HAZARD)
		cv.add_child(sl)
	if GameState.feature_unlocked("daily"):
		cv.add_child(_daily_twist_row())
	if next_locked != "":
		cv.add_child(_label(next_locked, 12, true))
	card.add_child(cv)
	return card


## What a Rank `rid` rift puts at stake (0.68, GameData.WOUND_* / FALL_*): "" below Rank C.
func _stakes_line(rid: String) -> String:
	var i := GameData.rift_rank_index(rid)
	if not GameData.STAKES_ON or GameState.hardship < 0 or i < GameData.rift_rank_index(GameData.WOUND_FROM_RANK):
		return ""
	var bits: Array[String] = [tr("Heavy blows wound.")]
	var falls := GameState.rifts_sealed >= GameData.FALL_COST_SEALS
	if falls:
		bits.append(tr("A fall can scar and drop gear."))
	if i >= GameData.rift_rank_index(GameData.WOUND_PERSIST_RANK):
		bits.append(tr("Wounds last until a campfire."))
		bits.append(tr("Road foes are tougher and strike first unless the party starts a fight with %d Momentum.") % GameData.ROAD_INITIATIVE)
	if falls and i >= GameData.rift_rank_index(GameData.FALL_DEATH_FROM_RANK):
		bits.append(tr("A twice-scarred hero can die."))
	return " ".join(bits)


# ---------------- Tower of Trials ----------------
## The next floor (its fight, rules, reward and the party's odds), the climb
## around it, and the ten guardians with their relics.
func _render_tower(v: VBoxContainer) -> void:
	v.add_child(_label("Tower of Trials", 20))
	var title := GameState.tower_title()
	v.add_child(_label(tr("Best floor %d / %d%s") % [GameState.tower_best, GameData.TOWER_FLOORS, ("  ·  " + tr(title)) if title != "" else ""], 13, true))
	_coach(v, "tower", "The Tower", "Every floor is always the same fight — if you lose, study it, change your party and come back. Heroes fight at full HP and leave exactly as they came, so a loss costs nothing. Each floor pays the first time you clear it; every 10th floor is a guardian with its own relic.")
	var f := GameState.tower_next_floor()
	if f == 0:
		var days_left := 7 - int(fmod(Time.get_unix_time_from_system(), 604800.0) / 86400.0)
		var done := _wrap_label(tr("You've cleared this week's ladder. Floors %d–%d reshuffle their rules in %d day%s.") % [GameData.TOWER_WEEKLY_FROM, GameData.TOWER_FLOORS, days_left, tr(str(_pl(days_left)))], 14)
		done.add_theme_color_override("font_color", Palette.RANK_E)
		v.add_child(done)
	else:
		v.add_child(_tower_floor_card(GameState.tower_floor_info(f)))
		v.add_child(_tower_strip(f))
	v.add_child(_hsep())
	v.add_child(_label("Guardians", 16))
	for gf in GameData.TOWER_BOSSES:
		var boss: Dictionary = GameData.TOWER_BOSSES[gf]
		var rdef: Dictionary = GameData.TOWER_RELICS[gf]
		var done_g := GameState.tower_best >= int(gf)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var ic := _icon(GameData.sprite_for_monster(str(boss["name"])), 32)
		if not done_g:
			ic.modulate = Color(1, 1, 1, 0.45)
		row.add_child(ic)
		var fl := _label(tr("Floor %d") % int(gf), 13, true)
		fl.custom_minimum_size.x = 64
		row.add_child(fl)
		var nm := _label(str(boss["name"]), 13)
		nm.custom_minimum_size.x = 170
		row.add_child(nm)
		var rl := _label(("✓ " if done_g else "") + tr(str(rdef["name"])), 13)
		rl.add_theme_color_override("font_color", Palette.RANK_E if done_g else Palette.RANK_S)
		rl.tooltip_text = str(rdef["desc"])
		rl.mouse_filter = Control.MOUSE_FILTER_STOP
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rl)
		v.add_child(row)
	var titles := GameData.TOWER_TITLES.map(func(e): return ("✓ " if GameState.tower_best >= int(e[0]) else "") + tr("%s (floor %d)") % [tr(str(e[1])), int(e[0])])
	v.add_child(_wrap_label(tr("Titles: ") + ", ".join(titles), 12, true))


func _tower_floor_card(info: Dictionary) -> Control:
	var f := int(info["floor"])
	var boss: Dictionary = info["boss"]
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"CardPanelEmber" if not boss.is_empty() else &"CardPanelViolet"
	var cv := _vbox(6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	if not boss.is_empty():
		head.add_child(_icon(GameData.sprite_for_monster(str(boss["name"])), 48))
	var hv := _vbox(2)
	var t := _label(tr("Floor %d") % f, 22)
	t.add_theme_font_override("font", DISPLAY_FONT)
	t.add_theme_color_override("font_color", Palette.EMBER_BRIGHT if not boss.is_empty() else Palette.TEXT)
	hv.add_child(t)
	var kind_name: String = {"boss": tr("Guardian: ") + str(boss.get("name", "")), "elite": "Elite fight", "combat": "Fight"}[str(info["kind"])]
	hv.add_child(_label("%s  ·  %s%s" % [tr(str(kind_name)), tr(str(GameData.BIOMES[str(info["biome"])]["name"])), tr(str(tr("  ·  weekly ladder") if info["weekly"] else ""))], 12, true))
	head.add_child(hv)
	cv.add_child(head)
	if not boss.is_empty():
		cv.add_child(_wrap_label(str(boss["line"]), 12, true))
		for mid in boss["mechanics"]:
			var bm: Dictionary = GameData.BOSS_MECHANICS.filter(func(x): return x["id"] == mid)[0]
			cv.add_child(_wrap_label("%s — %s" % [tr(str(bm["name"])), tr(str(bm["desc"]))], 13))
	for r in info["rules"]:
		var rl := _wrap_label(tr("Rule · %s — %s") % [tr(str(r["name"])), tr(str(r["desc"]))], 13)
		rl.add_theme_color_override("font_color", Palette.HAZARD)
		cv.add_child(rl)
	if info["rules"].is_empty() and boss.is_empty():
		cv.add_child(_label("No special rules on this floor.", 12, true))
	var cap := int(info["party_cap"])
	var pr := _power_readout(_best_party_power(cap), GameState.tower_recommended_power(f), "Your best party")
	pr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(pr)
	cv.add_child(_tower_reward_line(info))
	var b := _icon_domain_button("ember", GameData.CAMP_HUB_ICON_PATH["rift"], tr("Assemble party (up to %d)") % cap, func():
		pending_party.clear()
		_prefill_party = true
		_pending_tower = true
		screen = "party_assembly"
		render()
	)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cv.add_child(b)
	panel.add_child(cv)
	return panel


func _tower_reward_line(info: Dictionary) -> Control:
	var f := int(info["floor"])
	var rw: Dictionary = info["reward"]
	var first := f > GameState.tower_best
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_label(tr("First clear:") if first else tr("This week's re-clear:"), 13))
	row.add_child(_icon(GameData.CURRENCY_ICON_PATH["coins"], 16))
	row.add_child(_label("+%d" % (int(rw["coins"]) if first else int(rw["coins"]) / 2), 13))
	row.add_child(_icon(GameData.CURRENCY_ICON_PATH["crystals"], 16))
	row.add_child(_label("+%d" % (int(rw["crystals"]) if first else int(rw["crystals"]) / 2), 13))
	var rdef: Dictionary = rw["relic"]
	if first and not rdef.is_empty():
		var rl := _label("+ %s" % tr(str(rdef["name"])), 13)
		rl.add_theme_color_override("font_color", Palette.RANK_S)
		rl.tooltip_text = str(rdef["desc"])
		rl.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(rl)
	return row


## A strip of floor chips around the next one: cleared, next, and a few ahead
## (guardians in ember, rules in the tooltip).
func _tower_strip(next_f: int) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for f in range(maxi(1, next_f - 3), mini(GameData.TOWER_FLOORS, next_f + 8) + 1):
		var info := GameState.tower_floor_info(f)
		var chip := PanelContainer.new()
		var st := StyleBoxFlat.new()
		var guardian: bool = not (info["boss"] as Dictionary).is_empty()
		st.bg_color = Palette.SURFACE3 if f == next_f else Palette.SURFACE2
		st.border_color = Palette.EMBER_BRIGHT if f == next_f else (Palette.EMBER if guardian else Palette.LINE)
		st.set_border_width_all(2 if f == next_f or guardian else 1)
		st.set_corner_radius_all(6)
		st.set_content_margin_all(6)
		chip.add_theme_stylebox_override("panel", st)
		chip.custom_minimum_size = Vector2(52, 44)
		var cleared := f < next_f
		var l := _label(("✓ " if cleared else "") + str(f), 14, cleared)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(l)
		var tip := tr("Floor %d — %s") % [f, tr(str(info["boss"]["name"]) if guardian else (tr("Elite fight") if info["kind"] == "elite" else tr("Fight")))]
		for r in info["rules"]:
			tip += "\n%s: %s" % [tr(str(r["name"])), tr(str(r["desc"]))]
		chip.tooltip_text = tip
		flow.add_child(chip)
	return flow


## The ladder's daily twist: a box to take today's rule and starting boon
## on the next ladder rift, or where the streak stands once it's done.
func _daily_twist_row() -> Control:
	var info := GameState.daily_info()
	var boon: Dictionary = GameData.find_boon(str(info["boon"]))
	var bonus := GameData.DAILY_CLEAR_CRYSTALS + GameData.DAILY_CLEAR_CRYSTALS_PER_ACT * mini(GameState.campaign_act, 3)
	var streak := (tr(" · streak %d") % GameState.daily_streak) if GameState.daily_streak > 0 else ""
	if not GameState.daily_available():
		return _label(tr("Today's twist is done%s. A new one tomorrow.") % streak, 12, true)
	var cb := CheckBox.new()
	cb.text = tr("Today's twist: %s, start with %s · +%d Essence%s") % [tr(str(info["rule"]["name"])), tr(str(boon["name"])), bonus, streak]
	cb.button_pressed = _ladder_twist
	cb.add_theme_font_size_override("font_size", ui_size(12))
	cb.add_theme_color_override("font_color", Palette.RANK_S)
	cb.add_theme_color_override("font_pressed_color", Palette.RANK_S)
	cb.tooltip_text = tr("Rule: %s\nStarting boon: %s (%s)\nOne try a day, any rank. Every guild faces the same twist today; seal it for +%d Essence and a longer streak.") % [tr(str(info["rule"]["desc"])), tr(str(boon["name"])), tr(str(boon["desc"])), bonus]
	cb.toggled.connect(func(on: bool): _ladder_twist = on)
	return cb


# ---------------- Party Assembly ----------------
var _prefill_party := false   # the next party assembly opens on GameState.last_party


func _render_party_assembly(v: VBoxContainer) -> void:
	# It opens on the last party that went out (whoever's still ready, in their
	# rows): picking the same four for every Tower floor was a chore.
	if _prefill_party:
		_prefill_party = false
		# A new guild's first party: its starters, rather than four empty slots.
		var prev: Array = GameState.last_party if not GameState.last_party.is_empty() or GameState.runs_started > 0 else GameState.heroes.map(func(x): return x.id)
		for id in prev:
			var lh := GameState.find_hero(id)
			if lh and not lh.is_champion and not lh.is_downed() and not lh.is_away() and not pending_party.has(id) and pending_party.size() < _party_cap():
				pending_party.append(id)
	if GameState.breach_blocks_runs():
		# A broken rift comes first: this party goes to hold it (0.63).
		_pending_breach = true
		_pending_rift_rank = GameState.breach_rank_id()   # the readout measures the breach's rank
		_pending_diff_id = str(GameData.find_rift_rank(_pending_rift_rank)["base"])
		_pending_tower = false
		_pending_descent = false
		_pending_daily = false
		_pending_finale = false
	var tower_info := GameState.tower_floor_info(GameState.tower_next_floor()) if _pending_tower else {}
	if _pending_breach:
		var gate := GameState.breach.has("gate")
		var bt := _label(tr("Hold the breach — Rank %s near %s") % [tr(GameState.breach_rank_id()), GameState.breach_place()], 20)
		bt.add_theme_color_override("font_color", Palette.HAZARD)
		v.add_child(bt)
		v.add_child(_wrap_label(tr("%d fights in a row with no camp, shop or campfire between them, the last against the breach's warden. Hold, and the guild is paid; fall or turn back, and it costs part of your Essence and of the Gold above the coming bill, and damages a building. Up to 4 heroes; it takes the day.") % (GameData.GATE_RIFT_LAYERS if gate else GameData.BREACH_RIFT_LAYERS).size(), 12, true))
	elif _pending_daily:
		var dinfo := GameState.daily_info()
		v.add_child(_label(tr("Rank %s Rift — today's twist: %s") % [tr(str(_pending_rift_rank)), tr(str(dinfo["rule"]["name"]))], 20))
		v.add_child(_wrap_label(tr("Rule: %s Starting boon: %s (%s). Sealing it pays +%d Essence. Up to 4 heroes.") % [tr(str(dinfo["rule"]["desc"])), tr(str(GameData.find_boon(str(dinfo["boon"]))["name"])), tr(str(GameData.find_boon(str(dinfo["boon"]))["desc"])), GameData.DAILY_CLEAR_CRYSTALS + GameData.DAILY_CLEAR_CRYSTALS_PER_ACT * mini(GameState.campaign_act, 3)], 12, true))
	elif _pending_tower:
		v.add_child(_label(tr("Tower of Trials — Floor %d") % int(tower_info["floor"]), 20))
		var rules: Array = tower_info["rules"]
		v.add_child(_wrap_label(tr("Up to %d heroes. Everyone fights at full HP and leaves as they came.%s") % [_party_cap(), tr(str((tr(" Rules: ") + ", ".join(rules.map(func(r): return "%s (%s)" % [tr(str(r["name"])), tr(str(r["desc"]))]))) if not rules.is_empty() else ""))], 12, true))
	elif _pending_descent:
		v.add_child(_label(tr("The Descent — Rank %s") % tr(GameState.descent_rank()), 20))
		v.add_child(_wrap_label(tr("Depths of %d floors, each harder and better paid than the last. Every second depth ends at a pillar where a lost champion waits. Climb out whenever you like and keep everything; fall, and lose half of what the Descent earned. Up to 4 heroes; it costs a day.") % GameData.DESCENT_FLOORS, 12, true))
	elif _pending_finale and not GameState.current_act().is_empty():
		v.add_child(_label(tr("Finale — %s") % tr(str(GameState.current_act()["finale"])), 20))
		v.add_child(_wrap_label(tr("A harder %s Rift that ends in %s. Up to 4 heroes.") % [tr(str(GameState.current_act()["tier"]).capitalize()), tr(str(GameState.current_act()["boss"]))], 12, true))
	else:
		v.add_child(_label("Assemble Party (up to 4)", 20))
	_coach(v, "party", "Pick your party", "Pick who goes, then Enter the Rift. The front row takes most of the hits; the back row is attacked far less.")
	# The party stands on four slots facing the foes, each hero set Front or
	# Back with a small F/B switch. An empty slot's + opens a picker; a hero
	# can also be dragged from the roster onto a slot (onto someone: a swap).
	if not GameState.heroes.is_empty():
		v.add_child(_loadout_row())   # above the slots: a saved party is the quick way in
	v.add_child(_formation_stage())
	if GameState.heroes.is_empty():
		v.add_child(_label("No heroes yet — recruit some under Roster > Recruits first."))
	else:
		var bench_head := HBoxContainer.new()
		bench_head.add_theme_constant_override("separation", 10)
		var bl := _label("Roster — click a hero to add them, or drag them onto a slot", 12, true)
		bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bench_head.add_child(bl)
		# One click to a full party: the strongest ready heroes.
		var ready: Array = GameState.heroes.filter(func(x): return not pending_party.has(x.id) and not x.is_champion and not x.is_downed() and not x.is_away())
		ready.sort_custom(func(a, b): return Combat.power_of(a) > Combat.power_of(b))
		var fill := _button("Add strongest", func():
			for x in ready:
				if pending_party.size() >= _party_cap():
					break
				pending_party.append(x.id)   # in the row they stood in last (a new hero: their role's)
			render())
		fill.tooltip_text = tr("Fill the party with your strongest ready heroes, each in the row they stood in last.")
		fill.disabled = ready.is_empty() or pending_party.size() >= _party_cap()
		bench_head.add_child(fill)
		var clear := _button("Clear", func():
			pending_party.clear()
			render())
		clear.disabled = pending_party.is_empty()
		bench_head.add_child(clear)
		v.add_child(bench_head)
		var bench_flow := HFlowContainer.new()
		bench_flow.add_theme_constant_override("h_separation", 8)
		bench_flow.add_theme_constant_override("v_separation", 8)
		for bh in GameState.heroes:
			if not bh.is_champion:
				bench_flow.add_child(_bench_tile(bh))
		v.add_child(bench_flow)
	if _slot_pick >= 0:
		_slot_picker_overlay()

	if not GameState.champions.is_empty():
		v.add_child(_hsep())
		_coach(v, "overseer", "Your overseer", "A champion never fights in a rift run. They oversee it: their Boon lifts the whole party, and any hero can spend a turn on their Call. (In the Endless Rift champions are the party; in a defense you steer one.)")
		v.add_child(_overseer_picker())
	v.add_child(_hsep())

	var launch := _party_launch_bar()
	v.add_child(launch)
	v.move_child(launch, 1)


var _slot_pick := -1   # the slot whose hero picker is open (-1: none)


## Puts hero `id` on slot `index`: onto a hero standing there (a party member
## swaps places with them; a roster hero takes the slot and the one there
## goes home), or onto an empty slot. Heroes keep the row they stood in last.
func _place_hero(id: String, index: int) -> void:
	if GameState.find_hero(id) == null:
		return
	var here := str(pending_party[index]) if index < pending_party.size() else ""
	if here == id:
		return
	if here != "":
		var j := pending_party.find(id)
		pending_party[index] = id
		if j >= 0:
			pending_party[j] = here
		return
	if pending_party.has(id):   # to an empty slot: the end of the line
		pending_party.erase(id)
	elif pending_party.size() >= _party_cap():
		return
	pending_party.append(id)


## The party's slots in a line facing the foes (the party cap's worth).
func _formation_stage() -> Control:
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Palette.SURFACE2
	st.border_color = Palette.VIOLET_DEEP
	st.set_border_width_all(1)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", st)
	var col := _vbox(6)
	var head := _wrap_label("F = Front row: takes most of the enemy's attacks.   B = Back row: attacked far less.", 12, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var small := _compact()
	var cap := _party_cap()
	var avail: float = minf(_column_width(), get_viewport().get_visible_rect().size.x - 40.0)
	var slot_w := clampf((avail - 90.0) / maxf(4.0, cap) - 10.0, 120.0, 190.0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	# Rows fill toward their side (playtest 2026-10-09): the back row from the
	# left, the front row from the right next to the foes. A slot keeps its
	# hero's place in pending_party; an empty one adds to the end.
	var shown: Array = []
	shown.resize(cap)
	shown.fill("")
	var back_n := 0
	var front_n := 0
	for id in pending_party:
		var ph := GameState.find_hero(str(id))
		if ph and ph.formation == "back" and back_n < cap:
			shown[back_n] = str(id)
			back_n += 1
		elif front_n < cap:
			shown[cap - 1 - front_n] = str(id)
			front_n += 1
	for i in cap:
		var sid := str(shown[i])
		row.add_child(_party_slot(pending_party.find(sid) if sid != "" else pending_party.size(), sid, slot_w, small))
	var foes := _label("Foes ›", 13, true)
	foes.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(foes)
	col.add_child(row)
	panel.add_child(col)
	return panel


## One slot: the hero standing there (sprite, name, level and role, HP,
## power, the F/B switch; × sends them home, a click swaps someone in) or a
## big + to pick one. A hero dropped on it lands here.
func _party_slot(index: int, hid: String, w: float, small: bool) -> Control:
	var h := GameState.find_hero(hid) if hid != "" else null
	var zone := DropZone.new()
	var st := StyleBoxFlat.new()
	var base := Palette.SURFACE if h == null else Palette.SURFACE3
	st.bg_color = base
	st.border_color = Palette.MUTED2 if h == null else (Palette.EMBER if h.formation == "front" else Palette.VIOLET)
	st.set_border_width_all(2 if h != null else 1)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(6)
	zone.add_theme_stylebox_override("panel", st)
	zone.custom_minimum_size = Vector2(w, 160 if small else 214)
	zone.can_accept = func(data) -> bool:
		return typeof(data) == TYPE_DICTIONARY and data.get("kind", "") == "party_hero"
	zone.on_drop = func(data) -> void:
		_place_hero(str(data.get("hero_id", "")), index)
		render()
	# A click anywhere on the slot (bar F, B and ×) opens the picker.
	zone.clicked = func():
		_slot_pick = index
		render()
	zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zone.mouse_entered.connect(func(): st.bg_color = base.lightened(0.06))
	zone.mouse_exited.connect(func(): st.bg_color = base)
	var col := _vbox(2)
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	if h == null:
		var plus := _label("+", 44 if not small else 32)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.add_theme_color_override("font_color", Palette.MUTED)
		col.add_child(plus)
		var hint := _label("Add a hero", 12, true)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(hint)
	else:
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_PASS
		top.add_theme_constant_override("separation", 2)
		for r in ["front", "back"]:   # the F/B switch
			var rb := Button.new()
			rb.text = tr("Front row" if r == "front" else "Back row").left(1)   # F/B (Ö/A in Turkish)
			rb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			rb.toggle_mode = true
			rb.button_pressed = h.formation == r
			rb.custom_minimum_size = Vector2(28, 24)
			rb.add_theme_font_size_override("font_size", 12)
			rb.theme_type_variation = (&"ButtonEmber" if r == "front" else &"ButtonViolet") if h.formation == r else &""
			rb.tooltip_text = tr("Front row: takes most of the enemy's attacks") if r == "front" else tr("Back row: attacked far less")
			rb.pressed.connect(func(row_id=r):
				GameState.set_hero_formation(hid, row_id)
				render())
			top.add_child(rb)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(spacer)
		var x := _button("×", func():
			pending_party.erase(hid)
			render())
		x.flat = true
		x.tooltip_text = tr("Send home")
		top.add_child(x)
		col.add_child(top)
		var portrait := GameData.portrait_for_hero(h.cls_id, h.pool_id)
		if portrait != "":
			var icon := DragIcon.new()
			icon.texture = _icon_trimmed(portrait, 96).texture
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.custom_minimum_size = Vector2(64, 64) if small else Vector2(96, 96)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.drag_payload = {"kind": "party_hero", "hero_id": h.id}
			icon.mouse_default_cursor_shape = Control.CURSOR_MOVE
			_hero_look(icon, h)
			col.add_child(icon)
		var nm := _label(h.name.split(" the ")[0], 14 if not small else 12)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(nm)
		var info := _label(tr("Lv%d %s · %d/%d HP") % [h.level, tr(str(GameData.hero_role(h).capitalize())), h.hp, Combat.max_hp(h)], 11, true)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if h.hp < Combat.max_hp(h) * 0.5:
			info.add_theme_color_override("font_color", Palette.HAZARD)
		col.add_child(info)
		var pw := _label(tr("Power %d") % Combat.power_of(h), 11, true)
		pw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(pw)
		var natural := str(GameData.ROLE_POSITION.get(GameData.hero_role(h), {}).get("row", "front"))
		if natural != h.formation:
			var off := _wrap_label(tr("Fights best in Front") if natural == "front" else tr("Fights best in Back"), 11)
			off.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			off.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
			col.add_child(off)
		zone.tooltip_text = _position_text(h)
	zone.add_child(col)
	return zone


## A roster hero under the slots: click to add them (or send them home),
## drag onto a slot; those in the party are marked with their row.
func _bench_tile(h: Hero) -> Control:
	var in_party := pending_party.has(h.id)
	var away := h.is_downed() or h.is_away()
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Palette.SURFACE3 if in_party else Palette.SURFACE
	st.border_color = Palette.EMBER if in_party else Palette.SURFACE
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", st)
	if not away:
		var hit := Button.new()
		hit.flat = true
		var clear := StyleBoxEmpty.new()
		for sn in ["normal", "hover", "pressed", "focus", "disabled"]:
			hit.add_theme_stylebox_override(sn, clear)
		hit.mouse_filter = Control.MOUSE_FILTER_PASS
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.tooltip_text = tr("Click to send home") if in_party else tr("Click to add to the party, or drag onto a slot")
		hit.disabled = not in_party and pending_party.size() >= _party_cap()
		hit.pressed.connect(func():
			if in_party:
				pending_party.erase(h.id)
			elif pending_party.size() < _party_cap():
				pending_party.append(h.id)
			render())
		card.add_child(hit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE   # clicks fall through to `hit`
	var portrait := GameData.portrait_for_hero(h.cls_id, h.pool_id)
	if portrait != "":
		var icon := DragIcon.new()
		icon.texture = _icon_trimmed(portrait, 40).texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(40, 40)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_hero_look(icon, h)
		if not away:
			icon.drag_payload = {"kind": "party_hero", "hero_id": h.id}
			icon.mouse_default_cursor_shape = Control.CURSOR_MOVE
			icon.clicked = func():
				if in_party:
					pending_party.erase(h.id)
				elif pending_party.size() < _party_cap():
					pending_party.append(h.id)
				render()
		else:
			icon.modulate = Color(1, 1, 1, 0.4)
		row.add_child(icon)
	var col := _vbox(0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.custom_minimum_size.x = 120
	col.add_child(_label(h.name.split(" the ")[0], 12))
	var sub := tr("Lv%d %s · Power %d") % [h.level, tr(str(GameData.hero_role(h).capitalize())), Combat.power_of(h)]
	if away:
		sub = tr("Out %d run%s") % [h.down_runs, tr(str(_pl(h.down_runs)))] if h.down_runs > 0 else (_training_tag(h) if not h.training.is_empty() else tr("Away %d run%s") % [h.busy_runs, tr(str(_pl(h.busy_runs)))])
	elif in_party:
		sub = tr("In the party · Front") if h.formation == "front" else tr("In the party · Back")
	col.add_child(_label(sub, 10, true))
	row.add_child(col)
	card.add_child(row)
	return card


## The hero picker for a slot: every ready hero as a button (strongest
## first). Picking a party member swaps them into this slot.
func _slot_picker_overlay() -> void:
	var index := _slot_pick
	var here := str(pending_party[index]) if index < pending_party.size() else ""
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := Button.new()   # a click outside closes it
	var dim_st := StyleBoxFlat.new()
	dim_st.bg_color = Color(0, 0, 0, 0.62)
	for sn in ["normal", "hover", "pressed", "focus"]:
		dim.add_theme_stylebox_override(sn, dim_st)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.pressed.connect(func():
		_slot_pick = -1
		render())
	overlay.add_child(dim)
	# The whole pop-up scrolls on a small window; clicks beside the box reach
	# `dim` (so the scroll and centering don't take mouse input themselves).
	var outer := ScrollContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(outer)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(center)
	var vp := get_viewport().get_visible_rect().size
	var box := PanelContainer.new()
	box.theme_type_variation = &"CardPanelViolet"
	box.custom_minimum_size.x = minf(700.0, vp.x - 40.0)
	center.add_child(box)
	var col := _vbox(10)
	box.add_child(col)
	var head := _label("Choose a hero" if here == "" else "Swap in a hero", 20)
	head.add_theme_font_override("font", DISPLAY_FONT)
	head.add_theme_color_override("font_color", Palette.RANK_S)
	col.add_child(head)
	# An empty slot lists the bench; a filled one also offers the party (a swap).
	var pool: Array = GameState.heroes.filter(func(x): return not x.is_champion and not x.is_downed() and not x.is_away() and x.id != here and (here != "" or not pending_party.has(x.id)))
	pool.sort_custom(func(a, b): return Combat.power_of(a) > Combat.power_of(b))
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for x in pool:
		var b := Button.new()
		b.custom_minimum_size = Vector2(205, 56)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var portrait := GameData.portrait_for_hero(x.cls_id, x.pool_id)
		if portrait != "":
			b.icon = _icon_trimmed(portrait, 40).texture
			b.add_theme_constant_override("icon_max_width", 36)
		var tag := ""
		if pending_party.has(x.id):
			tag = tr(" · swaps places")
		b.text = "%s\n%s" % [tr(str(x.name.split(" the ")[0])), tr("Lv%d %s · Power %d") % [x.level, tr(str(GameData.hero_role(x).capitalize())), Combat.power_of(x)] + tag]
		b.add_theme_font_size_override("font_size", 12)
		b.disabled = here == "" and not pending_party.has(x.id) and pending_party.size() >= _party_cap()
		b.pressed.connect(func(id=x.id):
			_place_hero(id, index)
			_slot_pick = -1
			render())
		grid.add_child(b)
	if pool.is_empty():
		col.add_child(_wrap_label("No other hero is ready to go.", 13, true))
	else:
		col.add_child(grid)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	if here != "":
		foot.add_child(_button("Send this one home", func():
			pending_party.erase(here)
			_slot_pick = -1
			render()))
	foot.add_child(_button("Cancel", func():
		_slot_pick = -1
		render()))
	col.add_child(foot)
	_combat_hotkeys["Escape"] = func():
		_slot_pick = -1
		render()
	root.add_child(overlay)


## Saved loadouts: a slot's button puts its party on the rows (each hero in
## their saved row; anyone recovering, away or over the cap is left out and
## named); Save stores the party above in that slot.
func _loadout_row() -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 14)
	row.add_theme_constant_override("v_separation", 6)
	var head := _label("Loadouts", 12, true)
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(head)
	var party_ids: Array = pending_party.filter(func(id): return not str(id).begins_with("champ:"))
	for i in GameState.party_presets.size():
		var names: Array = []
		for entry in GameState.party_presets[i]:
			var h := GameState.find_hero(str(entry[0]))
			if h:
				names.append(tr(str(h.name.split(" the ")[0])))
		var shown := ", ".join(names.slice(0, 3)) + (" +%d" % (names.size() - 3) if names.size() > 3 else "")
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		var load_b := _button(tr("%d · %s") % [i + 1, shown] if not names.is_empty() else tr("%d · empty") % (i + 1), func():
			var res := GameState.load_party_preset(i, _party_cap())
			pending_party.assign(res["ids"])
			if not (res["missing"] as Array).is_empty():
				_flavor_toast = tr("Left out (recovering, away or over the cap): %s") % ", ".join(res["missing"])
			render())
		load_b.disabled = names.is_empty()
		load_b.tooltip_text = tr("Load this party, each hero in their saved row.")
		load_b.add_theme_font_size_override("font_size", 13)
		box.add_child(load_b)
		var save_b := _button("Save", func():
			GameState.save_party_preset(i, party_ids)
			_flavor_toast = tr("Loadout %d saved.") % (i + 1)
			render())
		save_b.flat = true
		save_b.disabled = party_ids.is_empty()
		save_b.tooltip_text = tr("Save the party above, with their rows, as loadout %d.") % (i + 1)
		save_b.add_theme_font_size_override("font_size", 12)
		box.add_child(save_b)
		row.add_child(box)
	return row


## Who oversees this run: a champion's Boon for the whole party and their
## Call (any hero can spend a turn on it), or none.
func _overseer_picker() -> Control:
	var box := _vbox(6)
	var cur := GameState.overseer
	box.add_child(_label(tr("Overseer: %s") % (GameData.champion_full_name(cur) if cur != "" else tr("none")), 14))
	if cur != "":
		var call := GameState.champion_call_of(cur)
		box.add_child(_wrap_label(tr("Boon: %s  ·  Call: %s — %s") % [GameState.champion_boon_text(cur), tr(str(call["name"])), tr(str(call["desc"]))], 12, true))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	for id in GameState.champion_roll:
		if not GameState.champion_unlocked(id):
			continue
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = id == cur
		b.text = str(GameData.champion_def(id)["name"])
		b.tooltip_text = GameState.champion_boon_text(id)
		b.pressed.connect(func(i=id): GameState.set_overseer(i); render())
		row.add_child(b)
	var none := Button.new()
	none.toggle_mode = true
	none.button_pressed = cur == ""
	none.text = tr("None")
	none.pressed.connect(func(): GameState.set_overseer(""); render())
	row.add_child(none)
	box.add_child(row)
	return box


## The top of Party Assembly: party power against the recommendation, any
## wounded members, and Enter the Rift — up where it's seen, not below the
## roster and options.
func _party_launch_bar() -> Control:
	var bar := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Palette.SURFACE2
	st.border_color = Palette.VIOLET_DEEP
	st.set_border_width_all(1)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(10)
	bar.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var info := _vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var going: Array = []
	for h in GameState.heroes:
		if pending_party.has(h.id):
			going.append(h)
	var rec_power: int = GameState.tower_recommended_power(GameState.tower_next_floor()) if _pending_tower else GameState.finale_recommended_power() if _pending_finale else Combat.recommended_power(_pending_diff_id, _pending_rift_rank)
	var pr := _power_readout(Combat.party_power(going), rec_power)
	pr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(pr)
	var res_parts: Array[String] = []   # Resonance (0.62): shared elements
	var counts := Combat.resonance_counts(going)
	for el in counts:
		if int(counts[el]) >= 2 and GameData.RESONANCE_TEXT.has(el):
			res_parts.append(tr("%s ×%d: %s") % [tr(str(el)), int(counts[el]), tr(str(GameData.RESONANCE_TEXT[el][1 if int(counts[el]) >= 3 else 0]))])
	if not res_parts.is_empty():
		var rl := _wrap_label(tr("Resonance — %s") % " · ".join(res_parts), 12)
		rl.add_theme_color_override("font_color", Palette.CRYSTALS)
		info.add_child(rl)
	var hurt: Array = going.filter(func(h): return h.hp < Combat.max_hp(h) * 0.5)
	if pending_party.is_empty():
		info.add_child(_label("Add at least one hero to the party.", 12, true))
	elif not hurt.is_empty() and not _pending_tower:
		var hl := _wrap_label(tr("Wounded: %s — they start the rift hurt.") % tr(str(", ".join(hurt.map(func(h): return "%s (%d/%d)" % [tr(str(h.name.split(" the ")[0])), h.hp, Combat.max_hp(h)])))), 12)
		hl.add_theme_color_override("font_color", Palette.HAZARD)
		info.add_child(hl)
	# Fight stakes (0.68): name every hero a fall could kill here, before the run.
	var srank := "" if (_pending_tower or _pending_descent or _pending_breach or _pending_daily or GameState.hardship < 0 or not GameData.STAKES_ON) 		else (GameState.highest_open_rank() if _pending_finale else _pending_rift_rank)
	if srank != "" and GameState.rifts_sealed >= GameData.FALL_COST_SEALS:
		for h in going:
			if GameState.death_risk(h, srank):
				var dl := _wrap_label(tr("%s has two scars: a fall here can kill them.") % tr(str(h.name.split(" the ")[0])), 12)
				dl.add_theme_color_override("font_color", Palette.HAZARD)
				info.add_child(dl)
	row.add_child(info)
	var enter := _icon_domain_button("violet", GameData.CAMP_HUB_ICON_PATH["rift"], tr("Begin the trial") if _pending_tower else tr("Enter the Rift"), func():
		if pending_party.is_empty():
			return
		var chosen: Relic = null   # 0.66: no starting relic choice any more
		var ids: Array[String] = []
		ids.assign(pending_party)
		if _pending_breach:
			GameState.start_breach_rift(ids)
		elif _pending_tower:
			GameState.start_tower(ids)
		elif _pending_descent:
			GameState.start_descent(ids, chosen)
		elif _pending_daily:
			GameState.start_daily(_pending_rift_rank, ids, chosen)
		elif _pending_finale:
			GameState.start_finale(ids, chosen)
		elif _pending_rift_rank != "":
			GameState.start_ladder_rift(_pending_rift_rank, ids, chosen)
		else:
			GameState.start_run(_pending_diff_id, ids, chosen)
		_pending_finale = false
		_pending_tower = false
		_pending_descent = false
		_pending_daily = false
		_pending_breach = false
		_pending_rift_rank = ""
		screen = "rift_run"
		render()
		_play_rift_entry_flash()
	)
	enter.disabled = pending_party.is_empty()
	enter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(enter)
	bar.add_child(row)
	return bar


# ---------------- Breaches ----------------


## The swelling or broken rift, at the top of the Rift Hall: a one-line
## strip while it swells, a card with Defend once it breaks.
func _breach_card() -> PanelContainer:
	var broken := GameState.breach_broken()
	if not broken:
		var days := GameState.breach_days_left()
		var r := tr(GameState.breach_rank_id())
		var chip := _rule_chip(tr("⚠ A Rank %s rift near %s breaks in %d day%s — seal a Rank %s rift or higher to close it") % [r, GameState.breach_place(), days, tr(str(_pl(days))), r],
			tr("Or let it break and hold it: back-to-back fights with no camp between them (Guild > Manage > Wardcraft softens them)."), Palette.EMBER_BRIGHT)
		(chip.get_child(0) as Label).add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		return chip
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.16, 0.05, 0.06, 0.95) if broken else Color(0.12, 0.08, 0.16, 0.95)
	st.border_color = Palette.HAZARD if broken else Palette.EMBER_BRIGHT
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var col := _vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var rank := tr(GameState.breach_rank_id())
	if broken:
		var t := _label(tr("The rift has broken! Rank %s near %s") % [rank, GameState.breach_place()], 17)
		t.add_theme_color_override("font_color", Palette.HAZARD)
		col.add_child(t)
		col.add_child(_wrap_label(tr("Monsters are pouring out. Rift runs wait until your guild defends."), 13))
		var b := _icon_domain_button("ember", GameData.CAMP_HUB_ICON_PATH["rift"], tr("Defend"), func(): screen = "defense"; render())
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	return card
