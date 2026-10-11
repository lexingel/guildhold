class_name RecordsView
extends QuestsView
## Records (achievements, stats, history), the Memorial, the week board and
## the Ledger (treasury, payroll, rival). Split out of GuildViews.gd in 0.69.2;
## calls only down the chain.


# ---------------- Records & Memorial ----------------

func _render_records(v: VBoxContainer) -> void:
	v.add_child(_label("Records", 20))
	var done := GameData.milestones(GameState.rival_present()).filter(func(m): return GameState.milestones_claimed.has(str(m["id"]))).size()
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for t in [["achievements", tr("Achievements %d/%d") % [done, GameData.milestones(GameState.rival_present()).size()]], ["stats", "Statistics"], ["history", "Run history"]]:
		var b := _button(str(t[1]), func(id=t[0]):
			records_tab = id
			render()
		)
		b.toggle_mode = true
		b.button_pressed = records_tab == t[0]
		tabs.add_child(b)
	v.add_child(tabs)
	if not GameState.vale_year.is_empty():
		var yl := _wrap_label(tr("The Vale this year: %s") % ", ".join(GameState.vale_year_lines(GameState.vale_year).map(func(l): return l[0])), 13)
		yl.tooltip_text = "\n".join(GameState.vale_year_lines(GameState.vale_year).map(func(l): return "%s: %s" % [l[0], l[1]]))
		yl.mouse_filter = Control.MOUSE_FILTER_STOP
		v.add_child(yl)
	if not GameState.oaths.is_empty():
		var sworn_l := _wrap_label(tr("Oaths sworn: %s") % ", ".join(GameState.oaths.map(func(o): return tr(str(GameData.OATHS.get(o, {}).get("name", o))))), 13)
		sworn_l.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
		v.add_child(sworn_l)
	match records_tab:
		"stats": _render_stats(v)
		"history": _render_history(v)
		_: _render_achievements(v)
	if GameState.can_retire():
		v.add_child(_hsep())
		v.add_child(_label("Retire the guild", 15))
		v.add_child(_wrap_label("A guild can retire once Act II is done: it joins the Hall of Guilds, leaves Laurels for your next guild, and up to two of its heroes come back as champions. Its save slot is freed.", 12, true))
		var rb := _button("Retire this guild…", func():
			set("_retire_open", true)
			render())
		rb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(rb)


var _show_done_achievements := false


## Unfinished achievements first, each with a progress bar; the done ones
## fold into one line (playtest 2026-10-09: the full list was a wall of text).
func _render_achievements(v: VBoxContainer) -> void:
	var all: Array = GameData.milestones(GameState.rival_present())
	var done: Array = all.filter(func(m): return GameState.milestones_claimed.has(str(m["id"])))
	var grid := GridContainer.new()
	grid.columns = 1 if _narrow() else 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	for m in all.filter(func(m): return not done.has(m)):
		grid.add_child(_achievement_tile(m, false))
	v.add_child(grid)
	var tb := _button(tr("Hide the %d done") % done.size() if _show_done_achievements else tr("Show the %d done") % done.size(), func():
		_show_done_achievements = not _show_done_achievements
		render())
	tb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tb.disabled = done.is_empty()
	v.add_child(tb)
	if _show_done_achievements:
		var dgrid := GridContainer.new()
		dgrid.columns = grid.columns
		dgrid.add_theme_constant_override("h_separation", 12)
		dgrid.add_theme_constant_override("v_separation", 8)
		for m in done:
			dgrid.add_child(_achievement_tile(m, true))
		v.add_child(dgrid)


func _achievement_tile(m: Dictionary, got: bool) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := _vbox(4)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var mark := _label("✓" if got else "○", 15)
	mark.add_theme_color_override("font_color", Palette.RANK_E if got else Palette.MUTED)
	top.add_child(mark)
	var lab := _wrap_label(str(m["label"]), 13)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(lab)
	col.add_child(top)
	var rw: Dictionary = m["reward"]
	var bits: Array[String] = []
	for k in ["coins", "crystals", "reputation"]:
		if int(rw.get(k, 0)) > 0:
			bits.append("+%d %s" % [int(rw[k]), tr(str({"coins": "Gold", "crystals": "Essence", "reputation": "Renown"}[k]))])
	var prog := mini(GameState.milestone_progress(m), int(m["target"]))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	if not got:
		var bar := _hp_bar(prog, int(m["target"]), 120)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		foot.add_child(bar)
		foot.add_child(_label("%d/%d" % [prog, int(m["target"])], 12, true))
	var rl := _label(", ".join(bits), 12, true)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(rl)
	col.add_child(foot)
	card.add_child(col)
	return card


func _render_stats(v: VBoxContainer) -> void:
	var kills := 0
	var top_foe := ""
	var top_n := 0
	for k in GameState.monster_kill_counts:
		var n := int(GameState.monster_kill_counts[k])
		kills += n
		if n > top_n:
			top_n = n
			top_foe = str(k)
	var best_hero := ""
	var best_p := 0
	for h in GameState.heroes:
		if Combat.power_of(h) > best_p:
			best_p = Combat.power_of(h)
			best_hero = tr("%s (power %d)") % [tr(str(h.name.split(" the ")[0])), best_p]
	var rows := [
		["Days passed", str(GameState.day)],
		["Runs finished", str(GameState.runs_finished)],
		["Rifts sealed", str(GameState.rifts_sealed)],
		["Monsters defeated", str(kills)],
		["Elites / Bosses defeated", "%d / %d" % [GameState.elites_won, GameState.bosses_won]],
		["Flawless fights", str(GameState.flawless_wins)],
		["Feats done", str(GameState.feats_done)],
		["Campaign", "complete" if GameState.campaign_done() else tr("Act %s") % tr(str(GameState._roman(GameState.campaign_act)))],
		["Tower of Trials, best floor", str(GameState.tower_best)],
		["Daily twists sealed", tr("%d (streak %d)") % [GameState.daily_clears, GameState.daily_streak]],
		["Items and relics crafted", str(GameState.crafts_performed)],
		["Renown", str(GameState.reputation)],
		["Heroes lost", str(GameState.heroes_lost_total)],
		["Strongest hero", best_hero if best_hero != "" else "—"],
		["Most-defeated foe", "%s (%d)" % [tr(str(top_foe)), top_n] if top_foe != "" else "—"],
	]
	# Tiles, the number big and the name under it (it was a 2-column wall).
	var grid := GridContainer.new()
	grid.columns = 2 if _narrow() else 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for r in rows:
		var tile := PanelContainer.new()
		tile.theme_type_variation = &"CardPanel"
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tc := _vbox(2)
		var val := _wrap_label(str(r[1]), 18)
		val.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
		tc.add_child(val)
		tc.add_child(_wrap_label(str(r[0]), 12, true))
		tile.add_child(tc)
		grid.add_child(tile)
	v.add_child(grid)


func _render_history(v: VBoxContainer) -> void:
	if GameState.run_history.is_empty():
		v.add_child(_label(tr("No runs yet. Your last %d runs will be listed here.") % GameData.RUN_HISTORY_MAX, 13, true))
		return
	for e in GameState.run_history:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var res := str(e["result"])
		var rl := _label(res, 13)
		rl.custom_minimum_size.x = 80
		rl.add_theme_color_override("font_color", Palette.good() if res == "Sealed" else (Palette.HAZARD if res == "Defeated" else Palette.MUTED))
		row.add_child(rl)
		var what := tr("Day %d · %s · floor %s") % [int(e["day"]), tr(str(e["kind"])), tr(str(e["floor"]))]
		if e.has("time"):
			what = tr("Day %d · %s · %d:%02d · %d kills") % [int(e["day"]), tr(str(e["kind"])), int(e["time"]) / 60, int(e["time"]) % 60, int(e.get("kills", 0))]
		var wl := _label(what, 13)
		wl.custom_minimum_size.x = 300
		row.add_child(wl)
		row.add_child(_label(tr("%+d Gold  %+d Essence") % [int(e["coins"]), int(e["crystals"])], 12, true))
		var tip := tr("Party: ") + ", ".join(e["heroes"])
		if not (e.get("boons", []) as Array).is_empty():
			tip += tr("\nBoons: ") + ", ".join((e["boons"] as Array).map(func(b): return str(GameData.find_boon(str(b)).get("name", b))))
		row.tooltip_text = tip
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		v.add_child(row)


func _render_memorial(v: VBoxContainer) -> void:
	v.add_child(_label("Memorial", 20))
	v.add_child(_wrap_label("Heroes lost for good. Their names stay with the guild.", 13, true))
	if GameState.fallen.is_empty():
		v.add_child(_label("No one has fallen. May it stay that way.", 14))
		return
	for f in GameState.fallen:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var portrait := GameData.portrait_for_hero(str(f["cls_id"]), str(f["pool_id"]))
		if portrait != "":
			var ic := _icon_trimmed(portrait, 44)
			ic.modulate = Color(0.55, 0.55, 0.6)
			row.add_child(ic)
		var col := _vbox(2)
		col.add_child(_label(tr("%s — Rank %s, Level %d") % [tr(str(f["name"])) + (", " + tr(str(f["title"])) if str(f.get("title", "")) != "" else ""), tr(str(f["rank"])), int(f["level"])], 14))
		col.add_child(_wrap_label(tr("%s, on day %d. %d rift%s sealed, %d foe%s felled.") % [tr(str(f["cause"])), int(f["day"]), int(f["rifts"]), tr(str(_pl(int(f["rifts"])))), int(f["kills"]), tr(str(_pl(int(f["kills"]))))], 12, true))
		if str(f.get("line", "")) != "":   # Wen's line (the Guildhold Chronicle)
			var wl := _wrap_label("“%s”  — %s" % [str(f["line"]), "Wen"], 12)
			wl.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
			col.add_child(wl)
		row.add_child(col)
		v.add_child(row)


## A matter waiting for your answer: a hero's request ("request") or the
## rival's move ("rival"), with faces, the story, and the two answers. In the
## camp pop-up (`popup`) it also offers Decide later.
func _matter_card(kind: String, popup: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"CardPanelEmber" if kind == "request" else &"CardPanelViolet"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var faces := _vbox(6)
	var title := ""
	var body := ""
	var opts: Array = []   # [[text, why disabled or ""], ...]
	var foot := ""
	var answer: Callable
	if kind == "request":
		var req: Dictionary = GameState.hero_request
		for id in req["ids"]:
			var h := GameState.find_hero(str(id))
			if h:
				faces.add_child(_hero_icon(h, 64))
		title = GameState.request_title()
		body = GameState.request_text()
		var ro: Array = GameState.request_options()
		opts = [[ro[0], GameState.request_blocked()], [ro[1], ""]]
		foot = "No answer by payday counts as a no."
		answer = GameState.answer_request
	elif kind == "event":   # a camp event (0.64): options by index, not yes/no
		var eid := str(GameState.camp_event["id"])
		var cd: Dictionary = GameState.camp_event.get("data", {})
		var art := ""
		if eid == "wanderer":
			var rec := Hero.from_dict(cd["hero"])
			faces.add_child(_hero_icon(rec, 64))
		elif eid == "merchant":
			for w in cd["wares"]:
				if not w["sold"]:
					faces.add_child(_item_tile(Item.from_dict(w["item"]), 48))
		else:
			art = {"opportunity": "res://assets/skills/star.png", "dilemma": "res://assets/skills/eye_gem.png"}.get(str(GameData.CAMP_EVENTS[eid]["kind"]), "res://assets/skills/gem_red.png")
			faces.add_child(_icon(art, 48))
		title = GameState.camp_event_title()
		body = GameState.camp_event_text()
		var heard := "%s:%d" % [eid, int(GameState.camp_event.get("day", 0))]
		if heard != _matter_heard:   # once per event (0.69)
			_matter_heard = heard
			var ek := str(GameData.CAMP_EVENTS[eid]["kind"])
			AudioManager.play_sfx(GameData.SFX_PATH["camp_omen" if ek == "threat" else ("camp_dilemma" if ek == "dilemma" else "camp_event")])
		opts = GameState.camp_event_options()
		var lastopt: String = str(opts[opts.size() - 1][0]) if not opts.is_empty() else ""
		foot = tr("No answer by tomorrow: %s.") % lastopt.to_lower() if lastopt != "" else ""
		answer = GameState.answer_camp_event
	else:
		var ev: Dictionary = GameState.rival_event
		var lead := GameState.rival_leader()
		faces.add_child(_icon_trimmed(str(lead["portrait"]), 64))
		if str(ev["type"]) == "poach":
			var h := GameState.find_hero(str(ev["hero"]))
			if h:
				faces.add_child(_hero_icon(h, 48))
		title = GameState.rival_event_title()
		body = GameState.rival_event_text()
		opts = GameState.rival_event_options()
		foot = {"poach": "No answer by payday: they choose for themselves.", "challenge": "No answer by payday counts as declining.",
			"snatch": "No answer by payday: they take it."}.get(str(ev["type"]), "")
		if ev.get("accepted", false):
			foot = tr("%d day%s to payday.") % [GameState.days_to_payday(), tr(str(_pl(GameState.days_to_payday())))]
		answer = GameState.answer_rival
	row.add_child(faces)
	var col := _vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := _wrap_label(title, 16)
	t.add_theme_color_override("font_color", Palette.EMBER_BRIGHT if kind in ["request", "event"] else Palette.RANK_S)
	col.add_child(t)
	col.add_child(_wrap_label(body, 13))
	var letter := GameState.rival_letter() if kind == "rival" else ""
	if letter != "":   # the leader's own note (the Charter War)
		var ll := _wrap_label(letter, 13)
		ll.add_theme_color_override("font_color", Palette.RANK_S)
		col.add_child(ll)
		var said := AudioManager.voice_clips_in(letter)
		if not said.is_empty():
			col.add_child(_voice_heading("", "letter:" + letter.left(60), said))
	var btns := HFlowContainer.new()
	btns.add_theme_constant_override("h_separation", 8)
	btns.add_theme_constant_override("v_separation", 6)
	for k in opts.size():
		var yes := k == 0
		var b := _button(str(opts[k][0]), func():
			var err: String = answer.call(k) if kind == "event" else answer.call(yes)
			if err != "":
				_flavor_toast = err
				AudioManager.play_sfx(GameData.SFX_PATH["ui_error"])
			render())
		if str(opts[k][1]) != "":
			b.disabled = true
			b.tooltip_text = str(opts[k][1])
		btns.add_child(b)
	if popup:
		btns.add_child(_button("Decide later", func():
			if kind == "request":
				GameState.hero_request["seen"] = true
			elif kind == "event":
				GameState.camp_event["seen"] = true
			else:
				GameState.rival_event["seen"] = true
			GameState.save()
			render()))
	col.add_child(btns)
	if foot != "":
		col.add_child(_wrap_label(foot + (tr(" Answer in Guild > Ledger.") if popup else ""), 11, true))
	row.add_child(col)
	p.add_child(row)
	return p


## The matter the camp should pop up now: "request", "rival" or "" (each
## once, until it's answered or put off with Decide later).
func _unseen_matter() -> String:
	if not GameState.camp_event.is_empty() and not GameState.camp_event.get("seen", false):
		return "event"
	if not GameState.hero_request.is_empty() and not GameState.hero_request.get("seen", false):
		return "request"
	if not GameState.rival_event.is_empty() and not GameState.rival_event.get("seen", false):
		return "rival"
	return ""


## The week at a glance: a tile per day from today to payday (a day is a rift run
## or a rest), each with what falls on it.
func _week_board() -> Control:
	var today := GameState.day
	var payday := today + GameState.days_to_payday()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var f := GameState.payday_forecast()
	for d in range(today, payday + 1):
		var events: Array = []   # [short text, colour, full text]
		if d == payday:
			events.append([tr("Payday · %d Gold") % int(f["bill"]), Palette.HAZARD if int(f["short"]) > 0 else Palette.COINS,
				tr("Wages %d + upkeep %d Gold; you have %d.") % [GameState.weekly_wages(), GameState.upkeep(), GameState.coins]])
			if not GameState.hero_request.is_empty():
				events.append([tr("Request closes"), Palette.EMBER_BRIGHT, GameState.request_title()])
			if not GameState.rival_event.is_empty():
				events.append([tr("Dare due") if GameState.rival_event.get("accepted", false) else tr("Rival waits"), Palette.RANK_S, GameState.rival_event_title()])
		if d == today and not GameState.camp_event.is_empty():
			events.append([GameState.camp_event_title(), Palette.EMBER_BRIGHT, GameState.camp_event_text()])
		if not GameState.camp_omen.is_empty() and int(GameState.camp_omen["day"]) == d:
			events.append([tr("Foretold: %s") % tr(str(GameData.CAMP_EVENTS[str(GameState.camp_omen["id"])]["title"])), Palette.HAZARD, tr(str(GameData.CAMP_EVENTS[str(GameState.camp_omen["id"])]["omen"]))])
		for q in GameState.active_quests():
			if int(q.get("due", -1)) == d:
				events.append([tr("Contract due"), Palette.HAZARD, GameState.quest_desc(q)])
		if GameState.breach_active() and not GameState.breach_broken() and int(GameState.breach.get("breaks_on", -1)) == d:
			events.append([tr("Rift breaks"), Palette.HAZARD, tr("A Rank %s rift breaks near %s.") % [tr(GameState.breach_rank_id()), GameState.breach_place()]])
		if d > 0 and d % GameData.CONTEST_DAYS == 0 and GameState.rival_present():
			events.append([tr("Contest ends"), Palette.RANK_S, tr("The month's Renown contest with %s ends.") % tr(str(GameState.rival_name))])
		var tile := PanelContainer.new()
		tile.theme_type_variation = &"CardPanelEmber" if d == today else &"CardPanel"
		# A day with nothing on it is just its name: three tall cards, two of
		# them empty, made the week look busier than it was.
		if events.is_empty() and d != today:
			tile.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size = Vector2(84, 0)
		var tv := _vbox(2)
		var head := _label(tr("Today") if d == today else tr("Day %d") % d, 13)
		head.add_theme_color_override("font_color", Palette.EMBER_BRIGHT if d == today else Palette.MUTED)
		tv.add_child(head)
		var tips: Array[String] = []
		for e in events:
			var l := _label(str(e[0]), 12)
			l.add_theme_color_override("font_color", e[1])
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tv.add_child(l)
			tips.append(str(e[2]))
		if events.is_empty() and d > today:
			tv.add_child(_label(tr("in %d day%s") % [d - today, tr(str(_pl(d - today)))], 11, true))
		tile.add_child(tv)
		tile.tooltip_text = "\n".join(tips)
		row.add_child(tile)
	row.tooltip_text = tr("A day passes with every rift run or rest.")
	return row


## The Ledger: the week board, what waits for an answer,
## the treasury against payday (and the weekly feast), the payroll (each
## hero's pay rate, morale and Dismiss), the rival and standings, and news.


func _render_ledger(v: VBoxContainer) -> void:
	v.add_child(_label("Guild Ledger", 20))
	_coach(v, "ledger", "Paying the guild", tr("A day passes with every rift run or rest; wages are due every %d days. An unpaid hero loses %d morale, and a hero unpaid twice in a row, or at rock-bottom morale on payday, walks out. Every Guild Management level also costs %d Gold a week in upkeep.") % [GameData.PAYDAY_DAYS, -GameData.MORALE_UNPAID, GameData.UPKEEP_PER_LEVEL])
	v.add_child(_week_board())
	if not GameState.camp_event.is_empty():
		v.add_child(_matter_card("event"))
	if not GameState.hero_request.is_empty():
		v.add_child(_matter_card("request"))
	if not GameState.rival_event.is_empty():
		v.add_child(_matter_card("rival"))
	v.add_child(_treasury_card())
	v.add_child(_payroll_card())
	if GameState.rival_present():   # no rivals yet in Act I (0.70)
		v.add_child(_rival_card())

	if not GameState.guild_news.is_empty():
		v.add_child(_hsep())
		v.add_child(_label("Guild news", 16))
		for line in GameState.guild_news:
			v.add_child(_wrap_label(str(line), 12, true))


## A Ledger figure: a big number over a small caption.
func _ledger_figure(value: String, caption: String, color: Color, tip: String = "") -> Control:
	var col := _vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := _label(value, 22)
	n.add_theme_color_override("font_color", color)
	col.add_child(n)
	col.add_child(_label(caption, 12, true))
	if tip != "":
		col.tooltip_text = tip
		col.mouse_filter = Control.MOUSE_FILTER_STOP
	return col


## The vault against the coming payday, the last payday, and the week's
## feast and training.
func _treasury_card() -> PanelContainer:
	var f := GameState.payday_forecast()
	var bill := int(f["bill"])
	var after := GameState.coins - bill
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanelEmber" if after < 0 else &"CardPanel"
	var cv := _vbox(8)
	cv.add_child(_label("Treasury", 16))
	var figs := HBoxContainer.new()
	figs.add_theme_constant_override("separation", 16)
	figs.add_child(_ledger_figure(str(GameState.coins), tr("Gold in the vault"), Palette.COINS))
	figs.add_child(_ledger_figure(str(bill), tr("Payday in %d day%s") % [int(f["days"]), tr(str(_pl(int(f["days"]))))], Palette.TEXT,
		tr("Wages %d + upkeep %d Gold (%d a week per hall room level).") % [int(f["wages"]), int(f["upkeep"]), GameData.UPKEEP_PER_LEVEL]))
	figs.add_child(_ledger_figure(str(after) if after >= 0 else tr("short %d") % -after, tr("Left after payday"), Palette.good() if after >= 0 else Palette.HAZARD))
	var since := int(f["since"])
	figs.add_child(_ledger_figure("%+d" % since, tr("Since last payday"), Palette.TEXT if since >= 0 else Palette.HAZARD, tr("Gold gained or spent since the last payday.")))
	cv.add_child(figs)
	var bar := _flat_bar(maxi(1, bill), mini(GameState.coins, bill), 0.0, 8.0, Palette.RANK_E if after >= 0 else Palette.HAZARD)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.tooltip_text = tr("The vault against the bill.")
	cv.add_child(bar)
	if after < 0:
		var fix := tr("Put some heroes on half pay below")
		if int(f["runs"]) > 0:
			fix = tr("About %d rift run%s at your recent pay would cover it, or put some heroes on half pay below") % [int(f["runs"]), tr(str(_pl(int(f["runs"]))))]
		var fl := _wrap_label(fix + ".", 12)
		fl.add_theme_color_override("font_color", Palette.HAZARD)
		cv.add_child(fl)
	var rep: Dictionary = GameState.payday_report
	if not rep.is_empty():
		var bits: Array[String] = [tr("%d Gold paid") % int(rep.get("paid", 0))]
		if not (rep.get("unpaid", []) as Array).is_empty():
			bits.append(tr("unpaid: %s") % tr(str(", ".join(rep["unpaid"]))))
		if not (rep.get("left", []) as Array).is_empty():
			bits.append(tr("walked out: %s") % tr(str(", ".join(rep["left"]))))
		cv.add_child(_wrap_label(tr("Last payday (day %d): %s.") % [int(rep.get("day", 0)), tr(str("; ".join(bits)))], 12, true))
		var scene: Array = GameState.payday_scene_lines(str(rep.get("scene", "")))
		if not scene.is_empty():
			# The Guildhold Chronicle: the cast at the pay table.
			var talk := _vbox(2)
			var clips: Array[String] = []   # the voiced lines (the ones that name a past guild or hero aren't)
			for ln in scene:
				var clip := AudioManager.voice_clip_for(str(ln[1]))
				if clip != "":
					clips.append(clip)
			talk.add_child(_voice_heading("At the pay table", "payday:%d:%s" % [int(rep.get("day", 0)), str(rep.get("scene", ""))], clips))
			var names := {"guild": str(rep.get("past", "")), "hero": str(rep.get("past_hero", ""))}
			for ln in scene:
				var face_path := "res://assets/npc/%s.png" % str(ln[0]).to_lower()   # Wen, Dobbs, Hesper, Pip
				var face := "[img=22x22]%s[/img] " % face_path if ResourceLoader.exists(face_path) else ""
				talk.add_child(_rich_line("%s[color=#%s]%s[/color]  %s" % [face, Palette.EMBER_BRIGHT.to_html(false), tr(str(ln[0])), tr(str(ln[1])).format(names)], 13))
			talk.tooltip_text = tr(GameState.hesper_alt("tooltip", "Wen keeps the guild's chronicle, Dobbs keeps its books, and Old Hesper is the last of an Accord guild: she had a fever on the Night of Breaking and missed it."))
			talk.mouse_filter = Control.MOUSE_FILTER_STOP
			cv.add_child(talk)
	var acts := HFlowContainer.new()
	acts.add_theme_constant_override("h_separation", 14)
	acts.add_theme_constant_override("v_separation", 6)
	var feast := _button(tr("Hold a feast · %d Gold") % GameState.feast_cost(), func():
		var err := GameState.hold_feast()
		if err != "":
			_flavor_toast = err
		render()
	)
	feast.disabled = not GameState.feast_ready() or GameState.coins < GameState.feast_cost()
	feast.tooltip_text = tr("+%d morale for up to %d heroes, lowest morale first. Once a week.") % [GameData.FEAST_MORALE, GameState.feast_seats()] if GameState.feast_ready() else tr("Already feasted this week — the next one after payday.")
	acts.add_child(feast)
	var tl := _label(tr("Training Yard: %d of %d stations in use") % [GameState.trainees().size(), GameState.training_slots()], 12, true)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	acts.add_child(tl)
	cv.add_child(acts)
	card.add_child(cv)
	return card


const PAY_RATE_LABEL := {"half": "Half", "full": "Full", "bonus": "Bonus"}


## Every hero's pay, set here: the weekly trade of Gold against morale.
## Rows run in pay order (the roster's): when Gold runs short, the bottom of
## the list goes unpaid.
func _payroll_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanelViolet"   # its own box, like the rival's (playtest 2026-10-09)
	var cv := _vbox(8)
	var head := HBoxContainer.new()
	var hl := _label("Payroll", 16)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	var wl := _label(tr("%d Gold a week") % GameState.weekly_wages(), 14)
	wl.add_theme_color_override("font_color", Palette.COINS)
	head.add_child(wl)
	cv.add_child(head)
	var half: Array = GameData.PAY_RATES["half"]
	var bonus: Array = GameData.PAY_RATES["bonus"]
	hl.tooltip_text = tr("Half pay saves Gold but costs %d morale each payday; a bonus pays %d%% more for +%d morale. Wages go out top to bottom while the Gold lasts.") % [-int(half[1]), int(round((float(bonus[0]) - 1.0) * 100.0)), int(bonus[1])]
	hl.mouse_filter = Control.MOUSE_FILTER_STOP
	hl.text = tr("Payroll") + "  ⓘ"
	var unpaid := GameState.unpaid_if_payday_now()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	var picked := StyleBoxFlat.new()
	picked.bg_color = Palette.VIOLET_DEEP
	picked.set_corner_radius_all(4)
	picked.content_margin_left = 8
	picked.content_margin_right = 8
	picked.content_margin_top = 4
	picked.content_margin_bottom = 4
	for h in GameState.heroes:
		var short: bool = unpaid.has(h.id)
		var who := HBoxContainer.new()
		who.add_theme_constant_override("separation", 8)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.add_child(_hero_icon(h, 36))
		var names := _vbox(0)
		names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var nl := _label(tr(str(h.name.split(" the ")[0])), 14)
		names.add_child(nl)
		var sub := _label(tr("Rank %s · Lv%d") % [tr(str(h.rank)), h.level] + (tr(" · unpaid if payday came now") if short else ""), 11, not short)
		if short:
			sub.add_theme_color_override("font_color", Palette.HAZARD)
		names.add_child(sub)
		who.add_child(names)
		grid.add_child(who)

		var mc := _vbox(3)
		mc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tier: Array = GameData.morale_tier(h.morale)
		var mcol: Color = Palette.good() if h.morale >= 80 else (Palette.MUTED if h.morale >= 40 else Palette.HAZARD)
		mc.add_child(_flat_bar(100, h.morale, 130.0, 6.0, mcol))
		var ml := _label(tr("Morale %d · %s%s%s") % [h.morale, tr(str(tier[1])), tr(str((tr(" (%+d%% damage)") % int(round(float(tier[2]) * 100))) if float(tier[2]) != 0.0 else "")), tr(" · unpaid %d week%s") % [h.unpaid_weeks, tr(str(_pl(h.unpaid_weeks)))] if h.unpaid_weeks > 0 else ""], 11, true)
		ml.add_theme_color_override("font_color", mcol)
		mc.tooltip_text = tr("Sealing a rift +%d · a lost rift %d · knocked out %d · unpaid %d · a week without a rift %d · a failed contract %d · a feast +%d") % [GameData.MORALE_SEAL, GameData.MORALE_DEFEAT, GameData.MORALE_KNOCKOUT, GameData.MORALE_UNPAID, GameData.MORALE_IDLE_WEEK, GameData.MORALE_QUEST_FAILED, GameData.FEAST_MORALE]
		mc.mouse_filter = Control.MOUSE_FILTER_STOP
		mc.add_child(ml)
		grid.add_child(mc)

		var seg := HBoxContainer.new()
		seg.add_theme_constant_override("separation", 2)
		seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var hid: String = h.id
		for rate in ["half", "full", "bonus"]:
			var r: Array = GameData.PAY_RATES[rate]
			var b := _button(tr("%s %d") % [tr(str(PAY_RATE_LABEL[rate])), GameState.wage_at(h, rate)], func(): GameState.set_pay_rate(hid, rate); render())
			b.add_theme_font_size_override("font_size", 13)
			b.tooltip_text = tr("%s: %d Gold a week%s.") % [tr(str(PAY_RATE_LABEL[rate])), GameState.wage_at(h, rate), tr(", %+d morale each payday") % int(r[1]) if int(r[1]) != 0 else ""]
			if GameState.pay_rate_of(h) == rate:
				for sn in ["normal", "hover", "pressed", "focus"]:
					b.add_theme_stylebox_override(sn, picked)
			seg.add_child(b)
		grid.add_child(seg)

		var confirming: bool = _dismiss_confirm == hid
		var db := _button(tr("Confirm: let them go") if confirming else tr("Dismiss"), func():
			if _dismiss_confirm != hid:
				_dismiss_confirm = hid
			else:
				_dismiss_confirm = ""
				var err := GameState.dismiss_hero(hid)
				if err != "":
					_flavor_toast = err
			render()
		)
		db.flat = not confirming
		db.add_theme_font_size_override("font_size", 12)
		db.tooltip_text = "They leave the guild for good; their gear goes back to the stockpile. No more wages."
		db.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(db)
	cv.add_child(grid)
	card.add_child(cv)
	return card


## The rival guild, this month's Renown contest and the guild standings.
func _rival_card() -> PanelContainer:
	var rival := PanelContainer.new()
	rival.theme_type_variation = &"CardPanelViolet"
	var rv := _vbox(6)
	var rlead := GameState.rival_leader()
	var rhead := HBoxContainer.new()
	rhead.add_theme_constant_override("separation", 10)
	rhead.add_child(_icon(str(rlead["crest"]), 40))
	rhead.add_child(_icon_trimmed(str(rlead["portrait"]), 64))
	var rnames := _vbox(0)
	rnames.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rnames.add_child(_label(tr("Rival: %s") % tr(str(GameState.rival_name)), 16))
	rnames.add_child(_label(tr("Led by %s") % tr(str(rlead["leader"])), 12, true))
	rhead.add_child(rnames)
	rv.add_child(rhead)
	var lead := GameState.reputation - GameState.rival_renown
	var rl := _label(tr("Renown — you %d · them %d (%s)") % [GameState.reputation, GameState.rival_renown, tr("you lead by %d") % lead if lead > 0 else (tr("they lead by %d") % -lead if lead < 0 else tr("level"))], 14)
	rl.add_theme_color_override("font_color", Palette.good() if lead > 0 else (Palette.HAZARD if lead < 0 else Palette.TEXT))
	rl.tooltip_text = tr("Renown is the one race with the rival. They gain it every day and sometimes take a posted contract before you do. At payday the leader gets the pick of next week's recruits (one more offer for you, or one fewer). Seal rifts and finish contracts to gain it; failed contracts and unpaid upkeep cost it.")
	rl.mouse_filter = Control.MOUSE_FILTER_STOP
	rv.add_child(rl)
	var cs := GameState.contest_status()
	var cl := _label(tr("This month: Renown gained — you %d · them %d · %d day%s left. Prize: %d Gold, %d Renown.") % [int(cs["ours"]), int(cs["theirs"]), int(cs["days_left"]), tr(str(_pl(int(cs["days_left"])))), GameData.CONTEST_PRIZE["coins"], GameData.CONTEST_PRIZE["reputation"]], 13)
	cl.add_theme_color_override("font_color", Palette.good() if int(cs["ours"]) > int(cs["theirs"]) else (Palette.HAZARD if int(cs["ours"]) < int(cs["theirs"]) else Palette.TEXT))
	rv.add_child(cl)
	if GameState.feature_unlocked("rival"):
		cl.tooltip_text = tr("The Crown's herald counts Renown toward the Royal Charter: one guild, every contract, for a generation.")
		cl.mouse_filter = Control.MOUSE_FILTER_STOP
	rv.add_child(_hsep())
	rv.add_child(_label("Guild Standings", 14))
	var table := GridContainer.new()
	table.columns = 4
	table.add_theme_constant_override("h_separation", 18)
	table.add_theme_constant_override("v_separation", 4)
	for head in ["", "Guild", "Renown", "Tower floor"]:
		table.add_child(_label(head, 12, true))
	var rows: Array = GameState.guild_standings()
	for k in rows.size():
		var r: Dictionary = rows[k]
		var col: Color = Palette.EMBER_BRIGHT if r["you"] else Palette.TEXT
		for cell in ["#%d" % (k + 1), tr(str(r["name"])) + (tr(" (you)") if r["you"] else (tr(" — rival") if r["name"] == GameState.rival_name else "")),
				str(r["renown"]), str(r["tower"])]:
			var l := _label(cell, 13)
			l.add_theme_color_override("font_color", col)
			table.add_child(l)
	rv.add_child(table)
	table.tooltip_text = tr("The other guilds' records grow every day. Top the Renown column for an achievement.")
	table.mouse_filter = Control.MOUSE_FILTER_STOP
	rival.add_child(rv)
	return rival


## The first-guild checklist for the status board, each step ticking off
## from real game state: {done, total, steps: [text, colour, action, true]}
## for the steps still to do. Empty once every step is done, the guild has
## sealed a few rifts, or the player hides it.
func _getting_started_steps() -> Dictionary:
	if GameState.guide_hidden or GameState.rifts_sealed >= 3:
		return {}
	var go := func(tab: String, sub: String): return func(): term_tab = tab; roster_tab = sub; render()
	var hall := func(): screen = "rift_hall"; render()
	var steps := [
		[tr("Sign your founders (Roster > Recruits): %d to go") % GameState.founding_picks, not GameState.signing_founders(), go.call("recruits", "")],
		["Assemble a party in the Rift Hall and enter a rift", not GameState.monsters_seen.is_empty(), hall],
		["Equip an item on a hero (Roster > Heroes)", GameState.items.any(func(it): return it.equipped_to != ""), go.call("roster", "hero")],
		["Spend a skill point (Roster > Heroes > Skills)", GameState.heroes.any(func(h): return h.skills.values().has(true)), go.call("roster", "skills")],
		["Seal your first rift by beating its boss", GameState.rifts_sealed >= 1, hall],
	]
	var todo := steps.filter(func(s): return not s[1]).map(func(s): return [s[0], Palette.TEXT, s[2], true])
	if todo.is_empty():
		return {}
	return {"done": steps.size() - todo.size(), "total": steps.size(), "steps": todo}


## Notification counts per camp building: {building label: [badge text,
## tooltip]} — only for things the player can act on right now.
func _camp_badges() -> Dictionary:
	var out := {}
	var needy: Array[String] = []
	for h in GameState.heroes:
		var reasons: Array[String] = []
		if h.skill_points > 0:
			reasons.append(tr("%d SP") % h.skill_points)
		if GameState.evolve_lock(h) == "":
			reasons.append(tr("can evolve"))
		if h.training.is_empty() and GameState.subclass_training_options(h).any(func(o): return str(o["lock"]) == ""):
			reasons.append(tr("can train a subclass"))
		for st in ["weapon", "gear"]:
			if _first_free_slot(h, st) >= 0 and GameState.items.any(func(it): return it.equipped_to == "" and it.slot_type() == st and GameState.item_fits_hero(it, h)):
				reasons.append(tr("empty %s slot") % tr(str(st)))
				break
		if not reasons.is_empty():
			needy.append("%s: %s" % [tr(str(h.name.split(" the ")[0])), tr(str(", ".join(reasons)))])
	if not needy.is_empty():
		out["roster"] = [str(needy.size()), "\n".join(needy)]
	var hurt := GameState.heroes.filter(func(h): return GameState.needs_recovery(h) and not h.bedded)
	if not hurt.is_empty():
		out["medical"] = [str(hurt.size()), tr("%d hero(es) wounded or downed") % hurt.size()]
	if GameState.heroes.size() < GameState.hero_slot_cap():
		var affordable := GameState.recruit_pool.filter(func(h): return GameState.coins >= int(GameData.find_rank(h.rank)["cost"]))
		if not affordable.is_empty():
			out["recruits"] = [str(affordable.size()), tr("%d recruit(s) you can afford") % affordable.size()]
	var craftable := 0
	var groups := {}
	for it in GameState.items:
		if it.equipped_to == "" and it.rarity in ["common", "rare"]:
			var k := "i:%s:%s" % [tr(str(it.category)), tr(str(it.rarity))]
			groups[k] = int(groups.get(k, 0)) + 1
	for k in groups:
		craftable += int(groups[k]) / 3
	if craftable > 0:
		if GameState.feature_unlocked("crafting"):
			out["crafting"] = [str(craftable), tr("%d combine(s) ready at the Smithy") % craftable]
	var free_relic_slots := GameState.relic_slot_cap() - Combat.equipped_relics().size()
	var spare_relics := GameState.relics.filter(func(r): return not r.equipped).size()
	if free_relic_slots > 0 and spare_relics > 0:
		out["inventory"] = [str(min(free_relic_slots, spare_relics)), tr("%d relic slot(s) empty — equip a relic under Items > Relics") % free_relic_slots]
	var claimable := GameState.guild_board.filter(func(q): return GameState.quest_progress(q) >= int(q["target"]))
	if not claimable.is_empty():
		out["quests"] = [str(claimable.size()), tr("%d quest(s) ready to claim") % claimable.size()]
	return out
