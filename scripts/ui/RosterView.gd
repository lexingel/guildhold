class_name RosterView
extends UiKit
## Roster (hero card, skill trees, equip slots) and Inventory screens.

func _sorted_heroes() -> Array[Hero]:
	var out: Array[Hero] = []
	out.assign(GameState.heroes)
	match roster_sort:
		"power":
			out.sort_custom(func(a, b): return Combat.power_of(a) > Combat.power_of(b))
		"level":
			out.sort_custom(func(a, b): return a.level > b.level)
		"rank":
			out.sort_custom(func(a, b): return float(GameData.find_rank(a.rank)["mult"]) > float(GameData.find_rank(b.rank)["mult"]))
	return out


func _render_roster(v: VBoxContainer) -> void:
	if GameState.heroes.is_empty():
		v.add_child(_label("No heroes recruited yet."))
		return

	var still_here: Array[Hero] = []
	still_here.assign(GameState.heroes.filter(func(h): return h.id == selected_hero_id))
	if still_here.is_empty():
		selected_hero_id = ""

	# Two panes: the hero list on the left, the selected hero's card on the
	# right — stacked on the narrow canvas, with the list wrapping into rows.
	var split: BoxContainer = VBoxContainer.new() if _narrow() else HBoxContainer.new()
	split.add_theme_constant_override("separation", 14)
	var left: Container
	if _narrow():
		left = HFlowContainer.new()
		left.add_theme_constant_override("h_separation", 6)
		left.add_theme_constant_override("v_separation", 6)
	else:
		left = _vbox(6)
		left.custom_minimum_size.x = 300
	var right := _vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left)
	split.add_child(right)
	v.add_child(split)

	var sort_btn := _sort_cycle_button(roster_sort, [
		{"id": "power", "label": "Power"},
		{"id": "level", "label": "Level"},
		{"id": "rank", "label": "Rank"},
	], func(new_id): roster_sort = new_id)
	sort_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(sort_btn)
	var sorted := _sorted_heroes()
	if selected_hero_id == "":
		selected_hero_id = sorted[0].id
		still_here.assign([sorted[0]])
	for hh in sorted:
		left.add_child(_roster_row(hh))
	right.add_child(_hero_card(still_here[0]))


## The hero's Path (0.62, its own tab since 0.62.1): three stage cards
## (rule, Technique, Signature; dim until trained) and the subclass's Twist.
## A base class sees its role's three Paths instead.
func _path_panel(cv: VBoxContainer, h: Hero) -> void:
	if h.is_champion:
		return
	var pid := h.path if h.path != "" else GameData.path_of(h.pool_id)
	if pid == "" or not GameData.PATHS.has(pid):
		cv.add_child(_label(tr("Base class · no Path yet"), 14))
		cv.add_child(_wrap_label(tr("At Rank D this hero can train into one of these Paths at the Training Yard."), 11, true))
		var opts: Array[Control] = []
		for rp in GameData.role_paths(GameData.hero_role(h)):
			var rd: Dictionary = GameData.PATHS[rp]
			opts.append(_stage_card(_cap(tr(str(rd["blurb"]))), tr(str(rd["name"])), tr("%s: %s") % [tr(str(rd["rule"]["name"])), _cap(tr(str(rd["rule"]["desc"])))], true))
		cv.add_child(_card_row(opts))
		return
	var p: Dictionary = GameData.PATHS[pid]
	var stage := GameData.subclass_stage(h.pool_id)
	var head := _label(tr("%s — %s") % [tr(str(p["name"])), tr(str(p["blurb"]))], 14)
	head.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
	cv.add_child(head)
	var cards: Array[Control] = []
	for ln in [[1, "Rule", p["rule"]], [2, "Technique", p["technique"]], [3, "Signature", p["signature"]]]:
		var have: bool = stage >= int(ln[0])
		var d: Dictionary = ln[2]
		var desc := _cap(tr(str(d["desc"])))
		if int(ln[0]) == 3 and GameData.is_legend(h.pool_id):
			desc += " " + tr("Legend: %s") % _cap(tr(str(p["legend"])))
		var tag := tr("%s · stage %d") % [tr(str(ln[1])), int(ln[0])] if have else tr("%s · trained at Rank %s") % [tr(str(ln[1])), tr(str(GameData.STAGE_RANK[int(ln[0])]))]
		cards.append(_stage_card(tag, tr(str(d["name"])), desc, have))
	cv.add_child(_card_row(cards))
	if GameData.SUBCLASS_TWIST.has(h.pool_id):
		var tw := _wrap_label(tr("Twist (%s): %s") % [tr(str(GameData.find_class(h.pool_id).get("name", ""))), tr(str(GameData.SUBCLASS_TWIST[h.pool_id]))], 12)
		tw.add_theme_color_override("font_color", Palette.COINS)
		cv.add_child(tw)


## Cards side by side (stacked on a phone).
func _card_row(cards: Array[Control]) -> BoxContainer:
	var row: BoxContainer = VBoxContainer.new() if _narrow() else HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for c in cards:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(c)
	return row


## One stage of a Path: a small tag, the name, what it does; dim until trained.
func _stage_card(tag: String, title: String, desc: String, have: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Palette.SURFACE
	st.border_color = Palette.EMBER_DEEP if have else Palette.LINE
	st.set_border_width_all(1)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", st)
	var v := _vbox(2)
	v.add_child(_label(tag, 11, true))
	var t := _label(title, 14)
	if have:
		t.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
	v.add_child(t)
	var d := _wrap_label(desc, 11, not have)
	d.custom_minimum_size.x = 120
	v.add_child(d)
	card.add_child(v)
	if not have:
		card.modulate = Color(1, 1, 1, 0.6)
	return card


## Rank, level and evolving (0.62): XP to the next level, and at level 10 the
## Evolve button with its Gold and Essence; a pointer to the Training Yard
## when a subclass training is open for this hero.
func _rank_panel(cv: VBoxContainer, h: Hero) -> void:
	if h.is_champion:
		return
	cv.add_child(_hsep())
	var nr := GameState.next_rank_of(h)
	var xp_line := tr("Rank %s · Lv%d") % [tr(h.rank), h.level]
	if h.level < 10:
		xp_line += tr(" · %d/%d XP to Lv%d") % [h.xp, Combat.xp_to_next(h.level, h.rank), h.level + 1]
	elif nr != "":
		xp_line += tr(" · ready to evolve to Rank %s") % tr(nr)
	if h.xp_boost_runs > 0:
		xp_line += tr(" · +%d%% XP for %d more run%s") % [int(GameData.XP_BOOST * 100), h.xp_boost_runs, tr(str(_pl(h.xp_boost_runs)))]
	var xl := _label(xp_line, 12)
	if h.seasoned > 0:
		xl.tooltip_text = tr("Seasoned: +%d%% HP and damage for %d rank%s climbed") % [int(round(GameData.SEASONED_PER_RANK * 100 * h.seasoned)), h.seasoned, tr(str(_pl(h.seasoned)))]
		xl.mouse_filter = Control.MOUSE_FILTER_STOP
	cv.add_child(xl)
	var xb := _hp_bar(h.xp if h.level < 10 else 1, Combat.xp_to_next(h.level, h.rank) if h.level < 10 else 1, 260.0)
	(xb.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Palette.VIOLET
	xb.tooltip_text = xl.tooltip_text
	xb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cv.add_child(xb)
	if nr != "" and h.level >= 10 and screen != "rift_run":
		var c := GameState.evolve_cost(h)
		var lock := GameState.evolve_lock(h)
		var eb := _icon_button("res://assets/skills/star.png", tr("Evolve to Rank %s · %d Gold · %d Essence") % [tr(nr), int(c[0]), int(c[1])], func(id=h.id):
			var err := GameState.evolve_hero(id)
			if err != "":
				_flavor_toast = err
			else:
				_flavor_toast = GameData.narrative_line("hero_evolved")
			render())
		eb.disabled = lock != ""
		eb.tooltip_text = lock if lock != "" else tr("Back to level 1 at Rank %s: stronger for good, +%d%% XP for %d rift runs.") % [tr(nr), int(GameData.XP_BOOST * 100), GameData.XP_BOOST_RUNS]
		cv.add_child(eb)
		if lock != "":
			cv.add_child(_label(lock, 11, true))
	var st := GameState.next_training_stage(h)
	if st > 0 and GameData.rank_index(h.rank) >= GameData.rank_index(str(GameData.STAGE_RANK[st])) and screen != "rift_run":
		cv.add_child(_icon_button("res://assets/skills/sword_a.png", tr("Train stage %d at the Training Yard") % st, func(id=h.id):
			_subclass_hero_id = id
			screen = "camp"
			term_tab = "training"
			render()))


## A hero's page: header, tabs (Hero · Skills · History) and the open tab.
## The Roster shows it beside the list; a rift shows it for the party
## (see _render_rift_hero_page), where camp-only actions stay hidden.
func _hero_card(h: Hero) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanelViolet"
	var cv := _vbox(4)
	var voice := GameData.hero_voice(h)
	# A heading and one line of facts (they were three boxed chips in a boxed
	# title bar); each number appears once on the page.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	if _rename_id == h.id:   # rename (0.66): the first name only
		var le := LineEdit.new()
		le.name = "RenameField"
		le.text = h.name.split(" the ")[0]
		le.max_length = 14
		le.custom_minimum_size.x = 160
		le.select_all_on_focus = true
		var commit := func(_t := ""):
			var err := GameState.rename_hero(h.id, le.text)
			if err != "":
				_flavor_toast = err
			else:
				_rename_id = ""
			render()
		le.text_submitted.connect(commit)
		head.add_child(le)
		head.add_child(_button(tr("Save"), commit))
		head.add_child(_button(tr("Cancel"), func(): _rename_id = ""; render()))
		le.call_deferred("grab_focus")
	else:
		var nm := _label(h.name, 18)
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(nm)
		var ttl := GameState.hero_title(h)
		if ttl != "":
			var tl := _label(ttl, 14)
			tl.add_theme_color_override("font_color", Palette.RANK_S)
			tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tl.tooltip_text = tr("Titles: %s") % ", ".join(h.titles.map(func(t): return tr(str(t))))
			tl.mouse_filter = Control.MOUSE_FILTER_STOP
			head.add_child(tl)
		if not h.is_champion:
			var rb := _button(tr("Rename"), func(): _rename_id = h.id; render())
			rb.flat = true
			rb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head.add_child(rb)
	var facts := _rich_line("%s · [color=#%s]%s[/color] · %s" % [tr("Lv%d %s") % [h.level, tr(str(h.cls_id.capitalize()))], Palette.rank_color(h.rank).to_html(false), tr("Rank %s") % tr(str(h.rank)), tr("Power %d") % Combat.power_of(h)], 14, true)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(facts)
	var hpb := _hp_bar(h.hp, Combat.max_hp(h), 150.0)
	hpb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hpb.tooltip_text = tr("%d/%d HP") % [h.hp, Combat.max_hp(h)]
	head.add_child(hpb)
	cv.add_child(head)

	# Tabs (Overview · Gear · Skills · History) instead of one long card that
	# stacked every section. A dot marks a tab with something to act on:
	# unequipped gear that fits, or unspent SP / an available evolution.
	var can_grow := GameState.evolve_lock(h) == "" or GameState.subclass_training_options(h).any(func(o): return str(o["lock"]) == "")
	var fitting_items: Array[Item] = []
	fitting_items.assign(GameState.items.filter(func(it): return it.equipped_to == "" and GameState.item_fits_hero(it, h)))
	if roster_tab in ["overview", "gear"]:
		roster_tab = "hero"
	if expanded_slot.begins_with(h.id + ":"):
		roster_tab = "hero"
	var tab_defs := [
		["hero", "Hero", h.attr_points > 0 or fitting_items.any(func(it): return _first_free_slot(h, it.slot_type()) >= 0 and GameState.attr_req_met(it, h))],
		["path", "Path", can_grow],
		["skills", "Skills", h.skill_points > 0],
		["history", "History", false],
	]
	if h.is_champion:
		tab_defs.remove_at(1)
		if roster_tab == "path":
			roster_tab = "hero"
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	for td in tab_defs:
		var tb := _button(tr(str(td[1])) + ("  •" if td[2] else ""), func(t=str(td[0])):
			roster_tab = t
			if t == "skills" and expanded_skill_tree_kind == "":
				expanded_skill_tree_kind = str(GameData.hero_tree_summaries(h)[-1]["kind"])
			render()
		)
		tb.toggle_mode = true
		tb.button_pressed = roster_tab == td[0]
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_row.add_child(tb)
	cv.add_child(tab_row)
	cv.add_child(_hsep())

	match roster_tab:
		"skills":
			var build := _build_bb(h)
			var pl := _rich_line(tr("Passive — ") + _passive_bb(h.pool_id) + ("    " + tr("Build: ") + build if build != "" else ""), 12)
			pl.tooltip_text = _position_text(h)
			cv.add_child(pl)
			var arch := Combat.hero_main_arch(h)
			if arch != "":
				cv.add_child(_wrap_label(tr("%s twist on every skill: %s.") % [tr(str(GameData.ARCHETYPES[arch])), tr(str(GameData.ARCH_TWIST[arch]))], 11, true))
			cv.add_child(_hsep())
			var shown_skills: Array = (GameData.ROLE_SKILLS.get(h.cls_id, []) as Array).duplicate()
			var tech := GameData.hero_technique(h)   # stage 2: the Path's Technique takes the second slot
			if not tech.is_empty() and shown_skills.size() >= 2:
				shown_skills[1] = tech
			for sk in shown_skills:
				var sk_row := HBoxContainer.new()
				sk_row.add_theme_constant_override("separation", 8)
				var sic := _icon(str(sk["icon"]), 28)
				var sk_rank := 1 if int(sk["level"]) > 1 else 0   # 0.62: the second skill comes at Rank E
				if GameData.rank_index(h.rank) < sk_rank:
					sic.modulate = Color(1, 1, 1, 0.4)
				sk_row.add_child(sic)
				var sk_mid := _vbox(0)
				sk_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var cost_txt := tr("costs HP") if int(sk["cost"]) == 0 else tr("%d Momentum") % int(sk["cost"])
				sk_mid.add_child(_label(tr("%s: %s · %s%s") % [tr("Technique") if sk.get("technique", false) else tr("Skill"), tr(str(sk["name"])), cost_txt, tr(str("" if str(sk["row"]) == "any" else tr(" · %s row") % tr(str(sk["row"]))))], 12))
				sk_mid.add_child(_wrap_label(tr(str(sk["desc"])), 11, true))
				sk_row.add_child(sk_mid)
				if GameData.rank_index(h.rank) < sk_rank:
					sk_row.add_child(_label(tr("Unlocks at Rank %s") % tr(str(GameData.RANKS[sk_rank]["id"])), 11, true))
				cv.add_child(sk_row)
			if GameData.SUBCLASS_ABILITIES.has(h.pool_id):
				var ab: Dictionary = GameData.SUBCLASS_ABILITIES[h.pool_id]
				var ab_row := HBoxContainer.new()
				ab_row.add_theme_constant_override("separation", 8)
				ab_row.add_child(_icon(GameData.ability_icon(h.pool_id), 28))
				var ab_mid := _vbox(0)
				ab_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				ab_mid.add_child(_label(tr("Ability: %s") % tr(str(ab["name"])), 12))
				ab_mid.add_child(_wrap_label(GameData.ability_desc(h.pool_id), 11, true))
				ab_row.add_child(ab_mid)
				if h.ability_awakened:
					ab_row.add_child(_label(tr("Awakened (%s)") % tr(str(GameData.awakening_bonus_text(h.pool_id))), 11, true))
				else:
					ab_row.add_child(_icon_button("res://assets/skills/gem_red.png", tr("Awaken (%d SP, %s)") % [GameData.ABILITY_AWAKENING_COST, tr(str(GameData.awakening_bonus_text(h.pool_id)))], func(id=h.id):
						var err := GameState.awaken_ability(id)
						if err != "":
							push_warning(err)
						render()
					))
				cv.add_child(ab_row)

			# One pill per tree the hero has unlocked — evolving keeps every past
			# stage's tree reachable instead of replacing it, so a heavily-evolved
			# hero can have several; only one tree's grid shows at a time (accordion
			# style) to avoid stacking multiple full grids on screen at once.
			var tree_summaries: Array = GameData.hero_tree_summaries(h)
			if not _skill_tree_closed and not tree_summaries.is_empty() and not tree_summaries.any(func(ts): return ts["kind"] == expanded_skill_tree_kind):
				expanded_skill_tree_kind = str(tree_summaries[0]["kind"])   # the tree used to hide behind a button
			var pills := HBoxContainer.new()
			pills.add_theme_constant_override("separation", 6)
			for summary in tree_summaries:
				var kind: String = summary["kind"]
				var is_open: bool = expanded_skill_tree_kind == kind
				pills.add_child(_icon_button("res://assets/skills/eye_gem.png", tr("Hide %s") % tr(str(summary["label"])) if is_open else str(summary["label"]), func(k=kind):
					expanded_skill_tree_kind = "" if expanded_skill_tree_kind == k else k
					_skill_tree_closed = expanded_skill_tree_kind == ""
					render()
				))
			cv.add_child(pills)

			if not expanded_skill_tree_kind.is_empty() and tree_summaries.any(func(s): return s["kind"] == expanded_skill_tree_kind):
				cv.add_child(_hsep())
				var spl := _label(tr("Skill Points: %d") % h.skill_points, 15)
				if h.skill_points > 0:
					spl.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
				spl.text += "  (?)"
				spl.tooltip_text = tr("A glowing node can be learned now: click it. Each shows its cost in skill points (SP); a hero earns one per level. Lines lead from what a node needs. Path nodes are one choice: taking one locks the others. Hover a node for what it does.")
				spl.mouse_filter = Control.MOUSE_FILTER_STOP
				cv.add_child(spl)
				_render_skill_tree_graph(cv, h, expanded_skill_tree_kind)
				# Per-tree, not "respec everything" — a hero holds at most 2 trees
				# (current + one prior evolution stage), so undoing just the one
				# fork choice you regret no longer means nuking the other tree too.
				var tree_prefix := "%s:" % tr(str(expanded_skill_tree_kind))
				var tree_spent := h.skills.keys().any(func(k): return h.skills[k] and str(k).begins_with(tree_prefix))
				if tree_spent and screen != "rift_run":
					cv.add_child(_icon_button(GameData.BUTTON_ICON_PATH["dice"], tr("Respec this tree (%d Gold)") % GameState.tree_respec_cost(h, expanded_skill_tree_kind), func(id=h.id, k=expanded_skill_tree_kind):
						var err := GameState.respec_hero(id, k)
						if err != "":
							push_warning(err)
						render()
					))
		"path":
			_path_panel(cv, h)
			_path_relic_panel(cv, h)
			_rank_panel(cv, h)
		"history":
			var who := _label(tr("%s · Morale %d %s") % [tr(str(GameData.VOICE_NAME[voice])), h.morale, tr(str(GameData.morale_tier(h.morale)[1]))], 13)
			who.tooltip_text = tr("Personality (from their born quirk) — e.g. “%s”") % tr(str(GameData.BARKS[voice]["victory"][0]))
			who.mouse_filter = Control.MOUSE_FILTER_STOP
			cv.add_child(who)
			cv.add_child(_hsep())
			var hist_lines := _history_lines(h)
			for line in hist_lines:
				cv.add_child(_rich_line(line, 12, true))
			if hist_lines.is_empty():
				cv.add_child(_label("No deeds yet — send this hero into a rift.", 11, true))
		_:
			_render_hero_sheet(cv, h, fitting_items)

	card.add_child(cv)
	return card


## The hero sheet: a paper doll (weapons left, the hero in the middle, gear
## right), attributes and every stat beside it, and the gear this hero can
## use underneath — equip by clicking a slot or dragging a tile onto it.
func _render_hero_sheet(cv: VBoxContainer, h: Hero, fitting_items: Array[Item]) -> void:
	var sheet: BoxContainer = VBoxContainer.new() if _narrow() else HBoxContainer.new()
	sheet.add_theme_constant_override("separation", 18)
	var doll := HBoxContainer.new()
	doll.add_theme_constant_override("separation", 10)
	var wcol := _vbox(6)
	wcol.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in GameData.weapon_slots(h.pool_id):
		wcol.add_child(_equip_slot_frame(h, "weapon", i, 58.0))
	doll.add_child(wcol)
	var mid := _vbox(6)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	var stage := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Palette.SURFACE
	st.set_corner_radius_all(10)
	st.set_content_margin_all(10)
	stage.add_theme_stylebox_override("panel", st)
	stage.custom_minimum_size = Vector2(170, 220)
	var cc := CenterContainer.new()
	var portrait := GameData.portrait_for_hero(h.cls_id, h.pool_id)
	if portrait != "":
		cc.add_child(_hero_icon(h, 190))
	stage.add_child(cc)
	mid.add_child(stage)
	var changes := GameState.equip_best_changes(h)
	if changes > 0:
		var eb := _button(tr("Equip best (%d)") % changes, func(id=h.id):
			var before := Combat.power_of(h)
			GameState.equip_best(id)
			GameState.pending_toasts.append({"cls_id": h.cls_id, "pool_id": h.pool_id, "title": tr("Equipped best gear"), "text": tr("Power %d → %d") % [before, Combat.power_of(h)]})
			render())
		eb.tooltip_text = "Fill this hero's slots with the strongest free gear that fits them. Gear worn by other heroes is left alone."
		mid.add_child(eb)
	doll.add_child(mid)
	var gcol := _vbox(6)
	gcol.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in GameData.gear_slots(h.rank):
		gcol.add_child(_equip_slot_frame(h, "gear", i, 58.0))
	# The next gear slot, locked, with the rank that opens it.
	for r in range(GameData.rank_index(h.rank) + 1, GameData.RANKS.size()):
		var rid := str(GameData.RANKS[r]["id"])
		if GameData.gear_slots(rid) > GameData.gear_slots(h.rank):
			var locked := _vbox(2)
			locked.tooltip_text = tr("Another gear slot opens at rank %s") % tr(str(rid))
			locked.mouse_filter = Control.MOUSE_FILTER_STOP
			var fr := _icon(GameData.RARITY_FRAME_PATH["common"], 58)
			fr.stretch_mode = TextureRect.STRETCH_SCALE
			fr.modulate = Color(1, 1, 1, 0.3)
			fr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			locked.add_child(fr)
			var ll := _label(tr("Rank %s") % tr(str(rid)), 12, true)
			ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ll.mouse_filter = Control.MOUSE_FILTER_IGNORE
			locked.add_child(ll)
			gcol.add_child(locked)
			break
	doll.add_child(gcol)
	sheet.add_child(doll)

	var side := _vbox(10)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(_attr_panel(h))
	side.add_child(_stat_panel(h))
	sheet.add_child(side)
	cv.add_child(sheet)

	if expanded_slot.begins_with("%s:weapon:" % h.id) or expanded_slot.begins_with("%s:gear:" % h.id):
		var parts := expanded_slot.split(":")
		_equip_picker_modal(h, parts[1], int(parts[2]))

	cv.add_child(_hsep())
	if fitting_items.is_empty():
		cv.add_child(_label("No unequipped gear this hero can use.", 12, true))
	else:
		var usable := fitting_items.filter(func(it): return GameState.attr_req_met(it, h)).size()
		cv.add_child(_label(tr("Unequipped gear that fits · %d usable%s — drag onto a slot, or click a slot") % [usable, tr(" · %d need more attributes") % (fitting_items.size() - usable) if fitting_items.size() > usable else ""], 12, true))
		var sorted := fitting_items.duplicate()
		sorted.sort_custom(func(x, y): return _rarity_rank(x.rarity) > _rarity_rank(y.rarity))
		var inv_flow := HFlowContainer.new()
		inv_flow.add_theme_constant_override("h_separation", 6)
		inv_flow.add_theme_constant_override("v_separation", 6)
		for it in sorted:
			inv_flow.add_child(_item_tile(it, 48, h))
		cv.add_child(inv_flow)

	cv.add_child(_quirk_row(h))


## The hero's quirks as chips (good ones in the healthy colour, wounds in
## the danger colour), with Treat on the treatable ones.
func _quirk_row(h: Hero) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	var head := _label("Quirks:", 12, true)
	row.add_child(head)
	if h.quirks.is_empty():
		row.add_child(_label("none yet", 12, true))
	for q in h.quirks:
		var t := GameData.quirk(q)
		var bad: bool = t.get("treatable", false)
		# Styled like the role tags (a coloured diamond, an underlined name with a
		# hover card): as plain labels they didn't read as hoverable.
		var chip := _rich_line(_bb(Palette.HAZARD if bad else Palette.good(), "◆") + " [u]" + _bb(Palette.TEXT, tr(str(q))) + "[/u]", 12)
		chip.autowrap_mode = TextServer.AUTOWRAP_OFF
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var origin := tr(str({"born": "born with it", "scar": "a scar", "earned": "earned", "hollow": "from the far side", "accord": "sworn to the Accord a past guild kept", "tide": "hardened by the tides a past guild let in"}.get(str(t.get("origin", "")), "")))
		if str(t.get("origin", "")) == "heir":
			origin = tr("child of %s") % str(h.history.get("heir_of", "?"))
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.mouse_default_cursor_shape = Control.CURSOR_HELP
		var tip_lines: Array[String] = [_bb(Palette.TEXT, tr(str(q))) + "  " + _bb(Palette.MUTED, "(" + origin + ")"), _bb(Palette.TEXT, tr(str(GameState.quirk_text(q))))]
		_rich_tip(chip, "\n".join(tip_lines))
		row.add_child(chip)
		if bad and GameState.lvl("res.lab") >= 1:
			row.add_child(_icon_button("res://assets/skills/potion_blue.png", tr("Treat (%d Gold)") % GameState.quirk_treat_cost(), func(id=h.id, qq=q):
				var err := GameState.treat_quirk(id, qq)
				if err != "":
					push_warning(err)
				render()
			))
	return row


## Might / Agility / Focus with a + per attribute while there are points to
## spend, and Auto (the role's usual spread).
const _ATTR_SHORT := {"dmg_pct": "dmg", "hp_pct": "HP", "speed_pct": "speed", "dodge_pct": "dodge",
	"first_round_pct": "first strike", "ability_power": "ability power", "mend_pct": "mend"}


func _attr_panel(h: Hero) -> PanelContainer:
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0)   # on the card itself; an ember edge only while points wait
	st.border_color = Palette.EMBER_DEEP
	st.set_border_width_all(1 if h.attr_points > 0 else 0)   # an edge only while points wait
	st.set_corner_radius_all(8)
	st.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", st)
	var v := _vbox(4)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(_label("Attributes", 15))
	# The same controls whether or not points are left, only disabled: the
	# panel used to shrink on the last point, moving the + under the cursor.
	var pts := _label(tr("%d point%s to spend") % [h.attr_points, tr(str(_pl(h.attr_points)))] if h.attr_points > 0 else tr("No points to spend"), 13, h.attr_points <= 0)
	if h.attr_points > 0:
		pts.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
	pts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(pts)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var auto := _button("Auto", func(id=h.id): GameState.auto_assign_attrs(id); render())
	auto.tooltip_text = tr("Spend them the %s way") % tr(str(GameData.hero_role(h).capitalize()))
	auto.disabled = h.attr_points <= 0
	head.add_child(auto)
	v.add_child(head)
	for a in GameData.ATTRIBUTES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.tooltip_text = "%s — %s" % [tr(str(GameData.ATTR_LABEL[a])), tr(str(GameData.ATTR_DESC[a]))]
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var nl := _label(GameData.ATTR_LABEL[a], 14)
		nl.custom_minimum_size.x = 76
		row.add_child(nl)
		var total := Combat.hero_attr(h, a)
		var gear: int = total - int(h.attrs.get(a, GameData.ATTR_BASELINE))
		var vl := _label(str(total), 15)
		vl.custom_minimum_size.x = 28
		row.add_child(vl)
		if gear != 0:
			row.add_child(_label(tr("(%+d gear)") % gear, 12, true))
		var sp2 := Control.new()
		sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp2)
		var per: Dictionary = GameData.ATTR_EFFECTS[a]
		var bits: Array[String] = []
		var long_bits: Array[String] = []
		for k in per:
			var val: float = (total - GameData.ATTR_BASELINE) * float(per[k]) * 100.0
			if is_zero_approx(val):
				continue
			long_bits.append(Combat.describe_skill(str(k), val / 100.0))
			if val >= 1.0:   # the sheet lists real gains; the rest is in the tooltip
				bits.append("%+.0f%% %s" % [val, tr(str(_ATTR_SHORT.get(k, k)))])
		row.tooltip_text += tr("\n%d is the baseline: above it adds, below it takes a little away.\n") % GameData.ATTR_BASELINE + "\n".join(long_bits)
		row.add_child(_attr_bar(total))
		var note := ", ".join(bits) if not bits.is_empty() else (tr("at the baseline") if total == GameData.ATTR_BASELINE else (tr("below the baseline") if total < GameData.ATTR_BASELINE else tr("small gains")))
		var nlab := _label(note, 12, true)
		nlab.custom_minimum_size.x = clampf(_text_w(note, 12) + 2.0, 150.0, 290.0)
		nlab.clip_text = true   # a long effect line (Spanish) shortens instead of widening the page (0.70)
		nlab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nlab.tooltip_text = note
		nlab.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(nlab)
		var plus := _button("+", func(id=h.id, at=a): GameState.spend_attr_point(id, at); render())
		plus.custom_minimum_size = Vector2(36, 30)
		plus.tooltip_text = "+1 %s" % tr(str(GameData.ATTR_LABEL[a]))
		plus.disabled = h.attr_points <= 0
		row.add_child(plus)
		v.add_child(row)
	# The Training Yard (0.58) and a full reset (Essence).
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	if not h.is_champion and screen != "rift_run":   # training and resets wait for camp
		var yard := _icon_button("res://assets/skills/sword_slash.png", _training_tag(h) if not h.training.is_empty() else tr("Training Yard (%d/%d trained)") % [h.attr_trained, GameData.ATTR_TRAIN_CAP], func():
			term_tab = "training"
			render()
		)
		yard.tooltip_text = tr("Send heroes to the Training Yard for 1-3 days: +1 attribute point a day, and XP on longer courses.")
		foot.add_child(yard)
	var fsp := Control.new()
	fsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(fsp)
	var refund := GameState.attr_points_spent(h)
	if refund > 0 and not h.is_champion and screen != "rift_run":
		var cost := GameState.attr_respec_cost(h)
		var reset: Button
		if _confirm_respec_id == h.id:
			reset = _icon_button(GameData.CURRENCY_ICON_PATH["crystals"], tr("Confirm — %d") % cost, func(id=h.id):
				_confirm_respec_id = ""
				var err := GameState.respec_attrs(id)
				if err != "":
					push_warning(err)
				render()
			)
			foot.add_child(_button("Keep", func(): _confirm_respec_id = ""; render()))
		else:
			reset = _icon_button(GameData.CURRENCY_ICON_PATH["crystals"], tr("Reset %d") % cost, func(id=h.id):
				_confirm_respec_id = id
				render()
			)
			reset.disabled = GameState.crystals < cost
		reset.tooltip_text = tr("Refund all %d spent points for %d Essence (you have %d)") % [refund, cost, GameState.crystals]
		foot.add_child(reset)
	# Let a hero go from their own page too (0.59.2; it was only on the Ledger's payroll).
	if screen != "rift_run":
		var confirming := _dismiss_confirm == h.id
		var db := _button(tr("Confirm: let them go") if confirming else tr("Dismiss"), func(id=h.id):
			if _dismiss_confirm != id:
				_dismiss_confirm = id
			else:
				_dismiss_confirm = ""
				var err := GameState.dismiss_hero(id)
				if err != "":
					_flavor_toast = err
			render()
		)
		db.flat = not confirming
		db.tooltip_text = tr("They leave the guild for good; their gear goes back to the stockpile. No more wages.")
		var why := tr("They're on a rift right now") if (GameState.run.get("hero_ids", []) as Array).has(h.id) else (tr("The guild needs at least one hero") if GameState.heroes.size() <= 1 else "")
		if why != "":
			db.disabled = true
			db.tooltip_text = why
		foot.add_child(db)
		if confirming:
			foot.add_child(_button("Keep", func(): _dismiss_confirm = ""; render()))
	if foot.get_child_count() > 1:
		v.add_child(foot)
	panel.add_child(v)
	return panel


## An attribute as a bar: a tick at the baseline, filled warm above it and
## grey below it, so a low score reads as "not much yet", not as a penalty.
func _attr_bar(total: int) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(90, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := maxf(25.0, total)
	bar.draw.connect(func():
		var w := bar.size.x
		bar.draw_rect(Rect2(0, 0, w, 10), Color(Palette.INK, 0.8))
		var base_x := w * GameData.ATTR_BASELINE / top
		var x := w * clampf(total / top, 0.0, 1.0)
		if total >= GameData.ATTR_BASELINE:
			bar.draw_rect(Rect2(0, 1, base_x, 8), Palette.GUNMETAL)
			bar.draw_rect(Rect2(base_x, 1, x - base_x, 8), Palette.EMBER_BRIGHT)
		else:
			bar.draw_rect(Rect2(0, 1, x, 8), Palette.GUNMETAL)
		bar.draw_rect(Rect2(base_x - 1, 0, 2, 10), Palette.TEXT))
	return bar


## HP, damage and speed, then every bonus the hero has — hover any line for
## where it comes from.
func _stat_panel(h: Hero) -> PanelContainer:
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0)   # no box in the box: a heading and spacing group it
	st.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", st)
	var v := _vbox(4)
	v.add_child(_label("Stats", 15))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 3)
	var add := func(name: String, value: String, tip: String):
		var nl := _label(name, 12, true)
		var vl := _label(value, 13)
		if tip != "":
			_rich_tip(nl, tip)
			_rich_tip(vl, tip)
		grid.add_child(nl)
		grid.add_child(vl)
	add.call("HP", "%d / %d" % [h.hp, Combat.max_hp(h)], _stat_breakdown_card(h, "hp_pct", Combat.hero_skill_total(h, "hp_pct")))
	add.call("Damage", str(Combat.dmg_of(h)), _stat_breakdown_card(h, "dmg_pct", Combat.hero_skill_total(h, "dmg_pct")))
	add.call("Speed", "%.1f" % Combat.spd_of(h), _stat_breakdown_card(h, "speed_pct", Combat.hero_skill_total(h, "speed_pct")))
	for kind in GameData.BUILD_KINDS:
		if kind in ["dmg_pct", "hp_pct", "speed_pct"]:
			continue
		var total := Combat.hero_skill_total(h, kind)
		if absf(total) < 0.01:   # under 1% changes nothing you'd notice; it's still in the breakdown
			continue
		add.call(str(_KIND_LABEL.get(kind, kind)), "%+.0f%%" % (total * 100.0), _stat_breakdown_card(h, kind, total))
	v.add_child(grid)
	panel.add_child(v)
	return panel


## One skill node as a compact hex tile (icon + short name caption) instead
## of a full-width text row — hover/long-press for the full effect text and
## gating reason via tooltip. A ready-to-learn node glows (via _action_slot's
## `selected`), a learned one gets a warm gold tint, anything else just dims.
## `kind` identifies which of the hero's unlocked trees `n` belongs to (used
## to compute Hero.skills's namespaced storage key) — irrelevant for the
## universal Tier-1 roots, which GameData.skill_storage_key leaves bare.
func _skill_node_tile(h: Hero, kind: String, n: Dictionary) -> Control:
	var skill_id: String = n["id"]
	var key := GameData.skill_storage_key(kind, skill_id)
	var learned: bool = h.skills.get(key, false)
	# Trees open by rank and Path stage since 0.62 (GameState.learn_skill checks
	# the same); the old level gate locked every level-1 recruit out.
	var lock := GameData.node_lock(h, kind, n)
	var missing_level: bool = lock != ""
	var missing_prereq := false
	for req in n["requires"]:
		if not h.skills.get(GameData.skill_storage_key(kind, req), false):
			missing_prereq = true
	if not n.get("requires_any", []).is_empty() and not n["requires_any"].any(func(r): return h.skills.get(GameData.skill_storage_key(kind, r), false)):
		missing_prereq = true
	var locked_out := false
	for excl in n.get("excludes", []):
		if h.skills.get(GameData.skill_storage_key(kind, excl), false):
			locked_out = true
	var cost := GameState.skill_node_cost(h, kind, n)
	var missing_sp: bool = h.skill_points < cost
	var missing_rift: bool = n.has("rift_rank") and GameState.best_rift_rank_sealed < GameData.rift_rank_index(str(n["rift_rank"]))
	var missing_stone: bool = n.get("stone", false) and GameState.crystals < GameData.STONEBOUND_CRYSTALS
	var can_learn := not learned and not missing_level and not missing_prereq and not missing_sp and not locked_out and not missing_rift and not missing_stone

	var node_name := func(id) -> String: return tr(str(GameData.find_skill_node(kind, str(id), h.cls_id).get("name", id)))
	var reason := "Learned"
	if not learned:
		if locked_out:
			reason = tr("Locked out: you took %s. A Path is one choice; respec the tree to switch.") % ", ".join((n.get("excludes", []) as Array).filter(func(x): return h.skills.get(GameData.skill_storage_key(kind, x), false)).map(node_name))
		elif missing_level:
			reason = lock
		elif missing_prereq:
			var need: Array = (n["requires"] as Array).filter(func(r): return not h.skills.get(GameData.skill_storage_key(kind, r), false)).map(node_name)
			reason = (tr("Learn %s first") % tr(" and ").join(need)) if not need.is_empty() else (tr("Learn one of %s first") % tr(" or ").join((n.get("requires_any", []) as Array).map(node_name)))
		elif missing_rift:
			reason = tr("Seal a Rank %s+ rift first") % tr(str(n["rift_rank"]))
		elif missing_stone:
			reason = tr("Needs %d Essence") % GameData.STONEBOUND_CRYSTALS
		elif missing_sp:
			reason = tr("Needs %d SP") % cost
		else:
			reason = tr("Learn (%d SP%s)") % [cost, tr(" + %d Essence") % GameData.STONEBOUND_CRYSTALS if n.get("stone", false) else ""]
		if cost < int(n["cost"]):
			reason += "\nCheaper: your quirks suit this path"

	var combo_line := ""
	if n.has("combo_kind"):
		var combo_active := learned and GameState.party_has_other_kind_capstone(h.id, str(n["combo_kind"]))
		combo_line = tr("\n%s+%s if a party ally has reached %s's capstone") % [
			"(Active) " if combo_active else "",
			Combat.describe_skill(str(n["kind"]), float(n.get("combo_bonus", 0.0))),
			str(n["combo_kind"]),
		]
	# The cost sits on the tile (it was only in the tooltip).
	var tile := _action_slot(str(n["icon"]), "" if learned else tr("%d SP") % cost, can_learn, not can_learn and not learned, func(hid=h.id, k=kind, sid=skill_id):
		var err := GameState.learn_skill(hid, k, sid)
		if err != "":
			push_warning(err)
		render()
	, 60.0, str(n["name"]), GameData.SKILL_NODE_FRAME_PATH, "%s\n%s\n%s%s" % [str(n["name"]), _node_effect_text(n), reason, combo_line], {}, Palette.EMBER_DEEP if can_learn else Palette.SURFACE3)
	if learned:
		tile.modulate = Color(1.15, 1.02, 0.68)
	var card := "[b]%s[/b]\n%s\n%s%s" % [str(n["name"]).replace("[", "[lb]"), _node_effect_text(n).replace("[", "[lb]"), _bb(Palette.MUTED, reason), combo_line.replace("[", "[lb]")]
	for c in tile.get_children():
		if c is BaseButton:
			_rich_tip(c, card + _kw_footer(card))
	return tile


## One tree, as a 4-column grid (Tier 1 → Tier 2 → Path → Mastery) instead
## of a flat scrolling list. Tier 1/Tier 2 alignment is unchanged — each
## singly-gated Tier-2 node sits in the same row as the Tier-1 node its
## `requires` points at; a Tier-2 node needing BOTH roots (or neither) gets
## its own row below. Tier 3 is normally a hard-exclusive fork (nodes that
## each `excludes` the others), placed one per row so "Path" reads as
## options stacked rather than one column; Tier 4 holds each fork's own
## finisher, found the same way — whichever Tier-4 node's `requires` points
## at that row's Tier-3 node. Fork rows are sized off `max(tier1, tier3)`,
## not tier1 alone, so a kind with more forks than the usual 2 (dodge_pct's
## 3-way fork) still gets a row for its extra fork+finisher pair instead of
## that pair silently never rendering.
const COL_W := 84.0   # skill tree column width (tile + room for its caption)


func _render_skill_tree_graph(cv: VBoxContainer, h: Hero, kind: String) -> void:
	var tree: Array = GameData.tier1_for_role(h.cls_id) + GameData.KIND_SKILL_PACKAGE.get(kind, [])
	var tier1: Array = tree.filter(func(n): return int(n["tier"]) == 1)
	var tier2: Array = tree.filter(func(n): return int(n["tier"]) == 2)
	var tier3: Array = tree.filter(func(n): return int(n["tier"]) == 3)
	var tier4: Array = tree.filter(func(n): return int(n["tier"]) == 4)

	# 5th column: the tree's keystone (row 0) and the role signature (row 1).
	var tier5: Array = ([GameData.keystone_node(kind), GameData.signature_node(h.cls_id)] + GameData.rift_nodes(kind)).filter(func(n): return not n.is_empty())

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 10)
	# Column headers are the grid's own first row (they used to be a separate
	# HBox that spread across the full width and drifted off the columns).
	for col_label in ["Tier 1", "Tier 2", "Path", "Mastery", "Keystone & Rift"]:
		var lbl := _label(col_label, 11, true)
		lbl.custom_minimum_size.x = COL_W
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(lbl)
	# Every cell is centered in a fixed-width column; `tiles` remembers each
	# node's tile so the link lines can find it.
	var tiles := {}
	var cell := func(n: Dictionary) -> Control:
		var c := CenterContainer.new()
		c.custom_minimum_size.x = COL_W
		if not n.is_empty():
			var tile := _skill_node_tile(h, kind, n)
			tiles[str(n["id"])] = tile
			c.add_child(tile)
		return c

	var singly_gated_tier2: Array = tier2.filter(func(n): return (n["requires"] as Array).size() == 1)
	var other_tier2: Array = tier2.filter(func(n): return (n["requires"] as Array).size() != 1)
	var fork_rows: int = max(tier1.size(), tier3.size())
	var row_count: int = max(max(fork_rows, 1) + other_tier2.size(), tier5.size())

	for row_i in row_count:
		if row_i < fork_rows:
			if row_i < tier1.size():
				var t1: Dictionary = tier1[row_i]
				grid.add_child(cell.call(t1))
				var dep := singly_gated_tier2.filter(func(n): return (n["requires"] as Array).has(t1["id"]))
				grid.add_child(cell.call(dep[0] if not dep.is_empty() else {}))
			else:
				grid.add_child(cell.call({}))
				grid.add_child(cell.call({}))
			if row_i < tier3.size():
				var fork: Dictionary = tier3[row_i]
				grid.add_child(cell.call(fork))
				var finisher := tier4.filter(func(n): return (n["requires"] as Array).has(fork["id"]))
				grid.add_child(cell.call(finisher[0] if not finisher.is_empty() else {}))
			else:
				grid.add_child(cell.call({}))
				grid.add_child(cell.call({}))
		else:
			grid.add_child(cell.call({}))
			grid.add_child(cell.call(other_tier2[row_i - fork_rows] if row_i - fork_rows < other_tier2.size() else {}))
			grid.add_child(cell.call({}))
			grid.add_child(cell.call({}))
		grid.add_child(cell.call(tier5[row_i] if row_i < tier5.size() else {}))

	# Prerequisite links, drawn behind the tiles (SkillTreeLines).
	var lines := SkillTreeLines.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var learned := func(id: String) -> bool: return h.skills.get(GameData.skill_storage_key(kind, id), false)
	for n in tree + tier5:
		var nid := str(n["id"])
		# The role signature hangs off the Tier-1 roots, which would draw a
		# line straight across the whole tree — its tooltip says what it needs.
		if not tiles.has(nid) or nid in ["signature", "stonebound"]:
			continue
		for r in n.get("requires", []) + n.get("requires_any", []):
			if tiles.has(str(r)):
				var state := 2 if learned.call(str(r)) and learned.call(nid) else (1 if learned.call(str(r)) else 0)
				lines.edges.append([tiles[str(r)], tiles[nid], state])
	# A MarginContainer stacks its children over the same rect, so the lines
	# layer sits exactly behind the grid and sizes itself with it.
	var holder := MarginContainer.new()
	holder.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	holder.add_child(lines)
	holder.add_child(grid)
	cv.add_child(holder)
	grid.sort_children.connect(lines.queue_redraw)


## One hero in the Roster list: portrait, name, level/class, an HP bar and
## their build chip, with a dot when they have something to act on (unspent
## SP, gear that fits an empty slot). The selected row is outlined.
func _roster_row(h: Hero) -> Control:
	var selected := selected_hero_id == h.id
	var b := _button("", func(id=h.id):
		selected_hero_id = id
		expanded_slot = ""
		render()
	)
	b.custom_minimum_size = Vector2(300, 64)
	b.toggle_mode = true
	b.button_pressed = selected
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait_path := GameData.portrait_for_hero(h.cls_id, h.pool_id)
	if portrait_path != "":
		var pi := _hero_icon(h, 48)
		pi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not h.is_available():
			pi.modulate = Color(0.5, 0.5, 0.5, 0.8)
		row.add_child(pi)
	var col := _vbox(2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	var nm := _label(h.name.split(" the ")[0], 14)
	if selected:
		nm.add_theme_color_override("font_color", Palette.VIOLET_BRIGHT)
	top.add_child(nm)
	var arch := _main_arch(h)
	if arch != "":
		var chip := _rich_line(_arch_chip(arch), 12)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(chip)
	col.add_child(top)
	col.add_child(_label(tr("Lv%d %s (%s) · %d/%d HP%s") % [h.level, tr(str(h.cls_id.capitalize())), tr(str(h.rank)), h.hp, Combat.max_hp(h), tr(str((tr(" · away %d run%s") % [h.busy_runs, tr(str(_pl(h.busy_runs)))]) if h.busy_runs > 0 else (" · " + _training_tag(h) if not h.training.is_empty() else "")))], 12, true))
	col.add_child(_flat_bar(Combat.max_hp(h), h.hp, 170, 4, _hp_color(float(h.hp) / float(max(1, Combat.max_hp(h))))))
	row.add_child(col)
	var needs := h.skill_points > 0
	for st in ["weapon", "gear"]:
		if _first_free_slot(h, st) >= 0 and GameState.items.any(func(it): return it.equipped_to == "" and it.slot_type() == st and GameState.item_fits_hero(it, h)):
			needs = true
	if needs:
		var dot := _count_badge("!", "Unspent skill points or gear that fits an empty slot")
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
	b.add_child(row)
	return b


## One equip-slot frame for the Roster paper-doll: a rarity-tinted border
## (RARITY_FRAME_PATH — "common" when empty) with the equipped item's category
## icon centered inside (blank when empty) and a short caption underneath
## (the item's first name word, or "Weapon"/"Gear" when empty) so the slot
## reads without opening anything. Clicking toggles this slot's inline
## equip-picker below the row — same expand/collapse pattern already used for
## the Skills button and Medical Bay's bed picker.
func _equip_slot_frame(h: Hero, slot_type: String, idx: int, size: float = 56.0) -> Control:
	var equipped := _find_equipped_at(h.id, slot_type, idx)
	var slot_key := "%s:%s:%d" % [tr(str(h.id)), tr(str(slot_type)), idx]
	var is_open := expanded_slot == slot_key
	var label_text := equipped.name.split(" ")[0] if equipped else (tr("Weapon") if slot_type == "weapon" else tr("Gear"))
	var icon_path: String = GameData.item_icon(equipped) if equipped else ""
	var cb := func():
		expanded_slot = "" if is_open else slot_key
		render()
	var can_accept := func(data):
		if typeof(data) != TYPE_DICTIONARY or data.get("kind", "") != "inventory_item":
			return false
		if data.get("slot_type", "") != slot_type:
			return false
		var candidate := GameState.find_item(str(data.get("item_id", "")))
		return candidate != null and GameState.item_fits_hero(candidate, h) and GameState.attr_req_met(candidate, h)
	var on_drop := func(data):
		GameState.equip_item(h.id, slot_type, idx, str(data.get("item_id", "")))
		render()
	var drop_target := {"can_accept": can_accept, "on_drop": on_drop}
	var frame_path: String = GameData.RARITY_FRAME_PATH.get(equipped.rarity, "") if equipped else ""
	return _action_slot(icon_path, "", is_open, false, cb, size, label_text, frame_path, _item_card(equipped, h) if equipped else "", drop_target)


## The picker for the open equip slot: a pop-up with what's worn there
## (and Unequip), then a card for every free item that fits this hero and
## slot, each with how it compares to the worn one. Esc or a click outside
## closes it.
func _equip_picker_modal(h: Hero, slot_type: String, idx: int) -> void:
	var close := func():
		expanded_slot = ""
		render()
	_combat_hotkeys["Escape"] = close
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		dim.set_offset(side, -80)   # past root's page margins
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		dim.set_offset(side, 80)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close.call())
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var vs := get_viewport_rect().size
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanelViolet"
	card.custom_minimum_size.x = minf(836.0, vs.x - 48.0)
	var cv := _vbox(12)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var title := _label(tr("%s — choose a weapon") % h.name.split(" the ")[0] if slot_type == "weapon" else tr("%s — choose gear") % h.name.split(" the ")[0], 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_icon_button(GameData.BUTTON_ICON_PATH["back"], "Close", close))
	cv.add_child(head)
	var equipped := _find_equipped_at(h.id, slot_type, idx)
	if equipped:
		var wear := HBoxContainer.new()
		wear.add_theme_constant_override("separation", 10)
		wear.add_child(_item_tile(equipped, 40, h))
		var wl := _vbox(0)
		wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wl.add_child(_label(tr("Wearing"), 11, true))
		var wn := _label(tr(str(_loot_display_name(equipped))), 14)
		wn.add_theme_color_override("font_color", ITEM_RARITY_COLOR.get(equipped.rarity, Palette.TEXT))
		wl.add_child(wn)
		wear.add_child(wl)
		var fcost := GameState.forge_cost(equipped)
		if fcost > 0 and GameState.feature_unlocked("forge"):   # the Forge, on the gear a hero wears
			var fb := _icon_button(GameData.CURRENCY_ICON_PATH["coins"], tr("Temper %d/%d · %d Gold") % [equipped.forge_level + 1, GameData.FORGE_MAX, fcost], func(iid=equipped.id):
				var err := GameState.forge_item(iid)
				if err != "":
					_flavor_toast = err
				render())
			fb.disabled = GameState.coins < fcost
			fb.tooltip_text = tr("Every rolled stat on this item grows %d%%. Each temper costs more than the last.") % int(GameData.FORGE_STEP * 100)
			wear.add_child(fb)
		wear.add_child(_icon_button("res://assets/skills/armor_chest.png", "Unequip", func(hid=h.id, st=slot_type, i=idx):
			GameState.equip_item(hid, st, i, "")
			render()))
		cv.add_child(wear)
		cv.add_child(_hsep())
	var candidates: Array = GameState.items.filter(func(it): return it.equipped_to == "" and it.slot_type() == slot_type and GameState.item_fits_hero(it, h))
	candidates.sort_custom(func(x, y):
		var ux := GameState.attr_req_met(x, h)
		var uy := GameState.attr_req_met(y, h)
		return ux and not uy if ux != uy else _rarity_rank(x.rarity) > _rarity_rank(y.rarity))
	if candidates.is_empty():
		cv.add_child(_label(tr("No unequipped %s this hero can use.") % tr(str(("weapons" if slot_type == "weapon" else "gear"))), 13, true))
	else:
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		for it in candidates:
			grid.add_child(_equip_choice_card(h, it, slot_type, idx))
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var per_row := maxi(1, int((card.custom_minimum_size.x - 24.0) / 260.0))
		sc.custom_minimum_size.y = minf(300.0 * ceili(float(candidates.size()) / per_row), minf(470.0, vs.y - 280.0))
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(grid)
		cv.add_child(sc)
	card.add_child(cv)
	center.add_child(card)
	root.add_child(overlay)


## How equipping `it` into slot idx changes `h`: [text, better?] per stat
## (every build stat is better higher, whatever its wording says), then the
## situational effects gained (better) and lost (worse).
func _compare_lines(it: Item, h: Hero, idx: int) -> Array:
	var current: Item = _find_equipped_at(h.id, it.slot_type(), idx) if idx >= 0 else null
	var a := _item_stat_map(it)
	var b := _item_stat_map(current)
	var out: Array = []
	for kind in GameData.BUILD_KINDS:
		var d: float = float(a.get(kind, 0.0)) - float(b.get(kind, 0.0))
		if absf(d) >= 0.001:
			out.append([Combat.describe_skill(kind, d), d > 0.0])
	for e in (GameData.find_unique_item(it.unique_id).get("effects", []) if it.unique_id != "" else it.effects):
		out.append([tr("gains: ") + Combat.describe_effect(e), true])
	if current:
		for e in (GameData.find_unique_item(current.unique_id).get("effects", []) if current.unique_id != "" else current.effects):
			out.append([tr("loses: ") + Combat.describe_effect(e), false])
	return out


## One free item in the picker: icon, name, slot and attribute need, how it
## compares with what's worn (gains green, losses red), and Equip. The full
## description is on hover.
func _equip_choice_card(h: Hero, it: Item, slot_type: String, idx: int) -> PanelContainer:
	var usable := GameState.attr_req_met(it, h)
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.custom_minimum_size.x = 250
	var v := _vbox(6)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(_item_tile(it, 44, h))
	var names := _vbox(1)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := _wrap_label(tr(str(_loot_display_name(it))), 13)
	nm.add_theme_color_override("font_color", ITEM_RARITY_COLOR.get(it.rarity, Palette.TEXT))
	names.add_child(nm)
	var sub := tr(str(GameData.ITEM_CATEGORY_LABEL[it.category]))
	if it.attr_req > 0:
		sub += " · " + tr("needs %d %s") % [it.attr_req, tr(str(GameData.ATTR_LABEL[it.attr]))]
	var sl := _label(sub, 11, true)
	if not usable:
		sl.add_theme_color_override("font_color", Palette.HAZARD)
	names.add_child(sl)
	top.add_child(names)
	v.add_child(top)
	var dp := GameState.power_delta(h, it, idx)
	var pwl := _label(tr("Power %+d") % dp, 14)
	pwl.add_theme_color_override("font_color", Palette.RANK_E if dp > 0 else (Palette.HAZARD if dp < 0 else Palette.MUTED))
	v.add_child(pwl)
	for e in it.effects:
		if (e as Dictionary).has("name"):
			var el := _wrap_label("★ %s — %s" % [tr(str(e["name"])), tr(str(Combat.describe_effect(e)))], 12)
			el.add_theme_color_override("font_color", Palette.EMBER_BRIGHT)
			v.add_child(el)
	var cmp := _compare_lines(it, h, idx).filter(func(c): return not (str(c[0]).begins_with(tr("gains: ")) and it.effects.any(func(e): return (e as Dictionary).has("name"))))
	for k in mini(cmp.size(), 5):
		var l := _wrap_label(str(cmp[k][0]), 11)
		l.add_theme_color_override("font_color", Palette.RANK_E if cmp[k][1] else Palette.HAZARD)
		v.add_child(l)
	if cmp.size() > 5:
		v.add_child(_label(tr("+%d more (hover)") % (cmp.size() - 5), 11, true))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var eb := _icon_button(GameData.item_icon(it), "Equip", func(hid=h.id, st=slot_type, i=idx, iid=it.id):
		GameState.equip_item(hid, st, i, iid)
		expanded_slot = ""
		render())
	eb.disabled = not usable
	if not usable:
		eb.tooltip_text = tr("Needs %d %s") % [it.attr_req, tr(str(GameData.ATTR_LABEL[it.attr]))]
	v.add_child(eb)
	card.add_child(v)
	_rich_tip(card, _item_card(it, h, idx))
	return card


var _inv_last := "items"   # the Inventory section opened last (the strip opens on it)


func _render_inventory(v: VBoxContainer) -> void:
	if inv_category == "":
		inv_category = _inv_last
	_inv_last = inv_category
	var loose_n: int = GameState.items.filter(func(it): return it.equipped_to == "").size()
	v.add_child(_hub_strip(GameData.INVENTORY_BG, [["items", tr("Items  %d") % loose_n], ["relics", tr("Relics  %d") % GameState.relics.size()], ["supplies", tr("Supplies  %d") % GameState.tonic_count()]], inv_category, func(id):
		inv_category = id
		inv_view = "supplies" if id == "supplies" else "gear"
		render()))
	match inv_category:
		"relics": _render_inventory_relics(v)
		"supplies":
			inv_view = "supplies"
			_render_inventory_items(v)
		_: _render_inventory_items(v)


func _render_inventory_items(v: VBoxContainer) -> void:
	var loose: Array = GameState.items.filter(func(it): return it.equipped_to == "")
	if inv_view == "supplies":
		_render_inventory_supplies(v)
		return

	# "Worn" lists what the heroes carry (playtest 2026-10-09: the arsenal
	# was invisible here); a click opens the wearer's page.
	var worn: Array = GameState.items.filter(func(it): return it.equipped_to != "" and GameState.find_hero(it.equipped_to) != null)
	var unequipped_items: Array[Item] = []
	unequipped_items.assign(worn if inv_filter == "worn" else loose.filter(func(it): return inv_filter == "all" or it.category == inv_filter))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	for f in [["all", "All"], ["weapon", "Weapons"], ["armor", "Armor"], ["focus", "Focus"], ["worn", "Worn"]]:
		var n: int = worn.size() if f[0] == "worn" else loose.filter(func(it): return f[0] == "all" or it.category == f[0]).size()
		var chip := _button("%s %d" % [tr(str(f[1])), n], func(id=str(f[0])):
			inv_filter = id
			render()
		)
		chip.toggle_mode = true
		chip.button_pressed = inv_filter == f[0]
		head.add_child(chip)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(_sort_cycle_button(inv_sort, [
		{"id": "rarity", "label": "Rarity"},
		{"id": "value", "label": "Value"},
		{"id": "name", "label": "Name"},
	], func(new_id): inv_sort = new_id))
	v.add_child(head)
	match inv_sort:
		"rarity":
			unequipped_items.sort_custom(func(a, b): return _rarity_rank(a.rarity) > _rarity_rank(b.rarity))
		"value":
			unequipped_items.sort_custom(func(a, b): return a.value > b.value)
		"name":
			unequipped_items.sort_custom(func(a, b): return a.name < b.name)
	if unequipped_items.is_empty():
		v.add_child(_label("Nobody wears anything yet." if inv_filter == "worn" else "No unequipped items here — loot drops in rifts.", 13, true))
		return
	v.add_child(_label("What your heroes wear. Click one to open its wearer's page." if inv_filter == "worn" else "Click an item to see it and equip it.  + fills someone's empty slot.", 12, true))
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for it in unequipped_items:
		grid.add_child(_inv_tile(it))
	v.add_child(grid)
	var sel: Array = loose.filter(func(it): return it.id == selected_item_id)
	if sel.is_empty():
		selected_item_id = ""
	else:
		_item_modal(sel[0])


## One inventory tile: rarity-framed icon, name, and the attribute it adds.
func _inv_tile(it: Item) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(112, 146)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func(id=it.id):
		selected_item_id = id
		render()
	)
	var col := _vbox(3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	var box := Control.new()
	box.custom_minimum_size = Vector2(60, 60)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := _icon(GameData.RARITY_FRAME_PATH.get(it.rarity, GameData.RARITY_FRAME_PATH["common"]), 60)
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)
	var ic := _icon(GameData.item_icon(it), 44)
	ic.position = Vector2(8, 8)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ic)
	_rarity_letter(box, it.rarity, 60)
	var note := _loot_fit_note(it, false, GameState.heroes)
	if str(note[0]).begins_with("Fills") and it.equipped_to == "":
		var dot := _count_badge("+", str(note[0]))
		dot.position = Vector2(46, -6)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		(dot.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Palette.RANK_E
		box.add_child(dot)
	col.add_child(box)
	var nl := _label(_loot_display_name(it), 12)
	nl.add_theme_color_override("font_color", ITEM_RARITY_COLOR.get(it.rarity, Palette.TEXT))
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.max_lines_visible = 3
	nl.custom_minimum_size.x = 100
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(nl)
	if it.attr != "" and it.attr_bonus > 0:
		var al := _label("+%d %s" % [it.attr_bonus, tr(str(GameData.ATTR_LABEL[it.attr]))], 12, true)
		al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		al.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(al)
	b.add_child(col)
	b.tooltip_text = tr("%s — click for details") % tr(str(_loot_display_name(it)))
	var wearer := GameState.find_hero(it.equipped_to) if it.equipped_to != "" else null
	if wearer:
		var wl := _label(tr("Worn by %s") % tr(str(wearer.name.split(" the ")[0])), 11, true)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(wl)
		b.custom_minimum_size.y += 16
		for c in b.pressed.get_connections():
			b.pressed.disconnect(c["callable"])
		b.pressed.connect(func(hid=wearer.id):
			selected_hero_id = hid
			term_tab = "roster"
			render())
		_rich_tip(b, _item_card(it))
	return b


## The selected item as a pop-up over the screen: its full card, who can
## equip it, and Sell. Esc, Close or a click outside dismisses it.
func _item_modal(it: Item) -> void:
	var close := func():
		selected_item_id = ""
		render()
	_combat_hotkeys["Escape"] = close
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		dim.set_offset(side, -80)   # past root's page margins
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		dim.set_offset(side, 80)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close.call()
	)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanelViolet"
	card.custom_minimum_size.x = 440
	var cv := _vbox(10)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var box := Control.new()
	box.custom_minimum_size = Vector2(72, 72)
	var frame := _icon(GameData.RARITY_FRAME_PATH.get(it.rarity, GameData.RARITY_FRAME_PATH["common"]), 72)
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	box.add_child(frame)
	var ic := _icon(GameData.item_icon(it), 54)
	ic.position = Vector2(9, 9)
	box.add_child(ic)
	top.add_child(box)
	var desc := _rich_line(_item_card(it), 13)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.custom_minimum_size.x = 340
	top.add_child(desc)
	cv.add_child(top)
	if it.lore != "":   # a keepsake: a fragment of the Vale's story rides on it (0.66)
		cv.add_child(_wrap_label(GameState.fragment_text(it.lore), 12, true))
	var slot := it.slot_type()
	var equip_row := HFlowContainer.new()
	equip_row.add_theme_constant_override("h_separation", 6)
	equip_row.add_theme_constant_override("v_separation", 6)
	var blocked: Array[String] = []
	for h2 in GameState.heroes:
		if not GameState.item_fits_hero(it, h2):
			continue
		var target_idx := _best_swap_slot(h2, slot)
		if target_idx < 0:
			continue
		if not GameState.attr_req_met(it, h2):
			blocked.append(h2.name.split(" the ")[0])
			continue
		var verb := tr("Equip → %s") if _first_free_slot(h2, slot) >= 0 else tr("Swap → %s")
		equip_row.add_child(_icon_button(GameData.item_icon(it), verb % h2.name.split(" the ")[0], func(hid=h2.id, iid=it.id, idx=target_idx):
			selected_item_id = ""
			GameState.equip_item(hid, slot, idx, iid)
			render()
		))
	if equip_row.get_child_count() > 0:
		cv.add_child(_label("Equip on", 13, true))
		cv.add_child(equip_row)
	if not blocked.is_empty():
		cv.add_child(_wrap_label(tr("Needs %d %s: %s") % [it.attr_req, tr(str(GameData.ATTR_LABEL.get(it.attr, it.attr))), tr(str(", ".join(blocked)))], 12, true))
	# The Forge: Gold tempers any item, equipped or not.
	var fcost := GameState.forge_cost(it)
	var forge_row := HBoxContainer.new()
	forge_row.visible = GameState.feature_unlocked("forge")
	forge_row.add_theme_constant_override("separation", 8)
	var fl := _label(tr("Forge — tempered %d/%d") % [it.forge_level, GameData.FORGE_MAX], 13, true)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	forge_row.add_child(fl)
	if fcost > 0:
		var fb := _icon_button(GameData.CURRENCY_ICON_PATH["coins"], tr("Temper +%d%% stats · %d Gold") % [int(GameData.FORGE_STEP * 100), fcost], func(id=it.id):
			var err := GameState.forge_item(id)
			if err != "":
				_flavor_toast = err
			render()
		)
		fb.disabled = GameState.coins < fcost
		fb.tooltip_text = tr("Every rolled stat on this item grows %d%%. Each temper costs more than the last.") % int(GameData.FORGE_STEP * 100)
		forge_row.add_child(fb)
	cv.add_child(forge_row)
	if it.unique_id == "" and GameState.feature_unlocked("crafting"):
		var rcost := GameState.reforge_cost(it)
		cv.add_child(_label(tr("Reforge — reroll one stat (%d Essence)") % rcost, 13, true))
		var ref_row := HFlowContainer.new()
		ref_row.add_theme_constant_override("h_separation", 6)
		ref_row.add_theme_constant_override("v_separation", 6)
		var lines := [it.kind, it.secondary_kind, it.tertiary_kind]
		for li in lines.size():
			if str(lines[li]) == "":
				continue
			var rb := _icon_button(GameData.CURRENCY_ICON_PATH["crystals"], (tr("Reroll %s value") if li == 0 else tr("Reroll %s")) % _KIND_LABEL.get(lines[li], lines[li]), func(id=it.id, l=li):
				var err := GameState.reforge_item(id, l)
				if err != "":
					push_warning(err)
				render()
			)
			rb.disabled = GameState.crystals < rcost
			rb.tooltip_text = tr("The value rerolls; the kind stays.") if li == 0 else tr("Rerolls into any stat this item doesn't already have (or the same one).")
			ref_row.add_child(rb)
		cv.add_child(ref_row)
	cv.add_child(_hsep())
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	bottom.add_child(_icon_button(GameData.CURRENCY_ICON_PATH["coins"], "Sell", func(id=it.id):
		selected_item_id = ""
		GameState.sell_item(id)
		render()
	))
	if GameState.feature_unlocked("forge") and it.equipped_to == "":   # the Smithy's salvage (0.66)
		bottom.add_child(_icon_button(GameData.CURRENCY_ICON_PATH["crystals"], tr("Salvage +%d") % GameState.salvage_value(it), func(id=it.id):
			selected_item_id = ""
			GameState.salvage_item(id)
			render()
		))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sp)
	bottom.add_child(_icon_button(GameData.BUTTON_ICON_PATH["back"], "Close", close))
	cv.add_child(bottom)
	card.add_child(cv)
	center.add_child(card)
	root.add_child(overlay)


func _render_inventory_supplies(v: VBoxContainer) -> void:
	v.add_child(_label(_no_keys(tr("Tonics — belt %d/%d · drink one in a fight on a hero's turn (Tonics, key 8)") % [GameState.tonic_count(), GameData.TONIC_CAP]), 16))
	for def in GameData.TONIC_TYPES:
		var tid: String = def["id"]
		var buy := _icon_button(GameData.CURRENCY_ICON_PATH["coins"], "Buy", func():
			var err := GameState.buy_tonic(tid)
			if err != "":
				_flavor_toast = err
			render()
		)
		buy.disabled = GameState.tonic_count() >= GameData.TONIC_CAP or GameState.coins < int(def["cost"])
		v.add_child(_info_row(tr("%s (%d Gold) — %s · carrying %d") % [tr(str(def["name"])), int(def["cost"]), tr(str(def["desc"])), GameState.tonic_count(tid)], 12, [buy], _icon(str(def["icon"]), 24)))


## Inventory → Relics: the Relic Altar. Equipped relics sit in the altar's
## slots, and the rest of the collection as a
## grid of tiles; clicking any relic opens its card in a pop-up.
func _render_inventory_relics(v: VBoxContainer) -> void:
	var equipped := Combat.equipped_relics()
	var cap := GameState.relic_slot_cap()
	var altar := PanelContainer.new()
	altar.theme_type_variation = &"CardPanelViolet"
	var av := _vbox(10)
	av.add_child(_label(tr("Relic Altar — %d/%d slots · every relic empowers the whole party") % [equipped.size(), cap], 16))
	var slots := HFlowContainer.new()
	slots.add_theme_constant_override("h_separation", 10)
	slots.add_theme_constant_override("v_separation", 10)
	for i in cap:
		slots.add_child(_relic_slot_card(equipped[i] if i < equipped.size() else null))
	av.add_child(slots)
	var carried := GameState.heroes.filter(func(h): return h.path_relic != "").size()
	if carried > 0 or not GameState.path_relic_chest.is_empty():   # Path relics (0.66): on heroes, not the altar
		var pl := _wrap_label(tr("Path relics: %d carried by heroes, %d in the chest. A hero of the relic's Path takes one on their Path tab.") % [carried, GameState.path_relic_chest.size()], 12, true)
		pl.tooltip_text = "\n".join(GameState.path_relic_chest.map(func(u): return tr(str(GameData.find_unique_relic(str(u)).get("name", "")))))
		av.add_child(pl)
	altar.add_child(av)
	v.add_child(altar)

	var rest: Array = GameState.relics.filter(func(r): return not r.equipped)
	rest.sort_custom(func(a, b): return _rarity_rank(a.rarity) > _rarity_rank(b.rarity))
	v.add_child(_label(tr("Collection (%d)") % rest.size(), 16))
	if rest.is_empty():
		v.add_child(_label("No spare relics: each is one of a kind, from finales, elites, shops and events.", 12, true))
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for r in rest:
		grid.add_child(_relic_tile(r))
	v.add_child(grid)
	var sel: Array = GameState.relics.filter(func(r): return r.id == selected_item_id)
	if not sel.is_empty():
		_relic_modal(sel[0])


func _relic_effect_lines(r: Relic) -> Array[String]:
	var out: Array[String] = []
	if r.unique_id != "":
		out.append(str(GameData.find_unique_relic(r.unique_id).get("desc", "")))
	else:
		for s in r.specials:
			out.append(str(s["label"]))
		if not r.trigger.is_empty():
			out.append(Combat.describe_effect(r.trigger, true))
	return out


## An altar slot: the equipped relic's icon, name and effects, or an empty socket.
func _relic_slot_card(r: Relic) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(270, 130)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if r == null:
		b.disabled = true
		var e := _label("Empty slot — pick a relic from your collection", 12, true)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.custom_minimum_size.x = 220
		row.add_child(e)
		b.add_child(row)
		return b
	b.pressed.connect(func(id=r.id):
		selected_item_id = id
		render()
	)
	row.add_child(_relic_icon_box(r, 56))
	var col := _vbox(2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := _label(_loot_display_name(r), 13)
	nm.add_theme_color_override("font_color", ITEM_RARITY_COLOR.get(r.rarity, Palette.TEXT))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size.x = 170
	col.add_child(nm)
	col.add_child(_label(_relic_kind_line(r), 12, true))
	var lines := _relic_effect_lines(r)
	for line in lines:
		var l := _label(("• " if lines.size() > 1 else "") + line, 12)
		l.custom_minimum_size.x = 190
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)
	row.add_child(col)
	b.add_child(row)
	b.tooltip_text = tr("%s\n%s\nClick for details") % [_loot_display_name(r), "\n".join(lines)]
	return b


## The Path relic a hero carries (0.66), and the chest's relics of their
## Path they could take instead. Passed at camp, not in a rift.
func _path_relic_panel(cv: VBoxContainer, h: Hero) -> void:
	if h.is_champion or h.path == "":
		return
	var pid := GameData.hero_path_id(h)
	var spare: Array = GameState.path_relic_chest.filter(func(uid): return str(GameData.find_unique_relic(str(uid)).get("path", "")) == pid)
	for x in GameState.heroes:   # or one a fellow of the Path carries
		if x != h and x.path_relic != "" and str(GameData.find_unique_relic(x.path_relic).get("path", "")) == pid:
			spare.append(x.path_relic)
	if h.path_relic == "" and spare.is_empty():
		return
	cv.add_child(_hsep())
	cv.add_child(_label("Path relic", 14))
	if h.path_relic != "":
		var d := GameData.find_unique_relic(h.path_relic)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := _wrap_label("%s — %s" % [tr(str(d.get("name", ""))), tr(str(d.get("desc", "")))], 12)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var down := _button("To the chest", func(id=h.id):
			var x := GameState.find_hero(id)
			GameState.set_down_path_relic(x)
			GameState.save()
			render())
		down.disabled = (GameState.run.get("hero_ids", []) as Array).has(h.id)
		row.add_child(down)
		cv.add_child(row)
	for uid in spare:
		var d2 := GameData.find_unique_relic(str(uid))
		var holder: Array = GameState.heroes.filter(func(x): return x.path_relic == str(uid))
		var b := _button(tr("Carry %s%s") % [tr(str(d2.get("name", ""))), tr(" (from %s)") % tr(str(holder[0].name.split(" the ")[0])) if not holder.is_empty() else ""], func(u=str(uid), id=h.id):
			_flavor_toast = GameState.carry_path_relic(u, id)
			render())
		b.tooltip_text = tr(str(d2.get("desc", "")))
		cv.add_child(b)


func _relic_icon_box(r: Relic, size: int) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(size, size)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := _icon(GameData.RARITY_FRAME_PATH.get(r.rarity, GameData.RARITY_FRAME_PATH["common"]), size)
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)
	var inner := int(size * 0.72)
	var ic := _icon(GameData.relic_icon(r), inner)
	ic.position = Vector2((size - inner) * 0.5, (size - inner) * 0.5)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ic)
	var gem := _icon(GameData.RELIC_TYPE_ICON_PATH.get(r.type, ""), 18)
	gem.position = Vector2(size - 16, size - 16)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gem)
	return box


## "Unique relic", "Tower relic", "Endless relic" (0.66: relics are rules, no levels).
func _relic_kind_line(r: Relic) -> String:
	if GameData.TOWER_RELICS.values().any(func(d): return d["id"] == r.unique_id):
		return tr("Tower relic")
	if GameData.ENDLESS_RELICS.values().any(func(d): return d["id"] == r.unique_id):
		return tr("Endless relic")
	return tr("Unique relic")


## A collection tile: framed icon with the element gem, name and kind.
func _relic_tile(r: Relic) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(112, 134)
	b.pressed.connect(func(id=r.id):
		selected_item_id = id
		render()
	)
	var col := _vbox(3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	var box := _relic_icon_box(r, 60)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(box)
	var nl := _label(_loot_display_name(r), 12)
	nl.add_theme_color_override("font_color", ITEM_RARITY_COLOR.get(r.rarity, Palette.TEXT))
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.max_lines_visible = 2
	nl.custom_minimum_size.x = 100
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(nl)
	var ll := _label(_relic_kind_line(r), 11, true)
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(ll)
	b.add_child(col)
	b.tooltip_text = tr("%s — click for details") % tr(str(_loot_display_name(r)))
	return b


## A relic's full card over the screen: effects, level, and every action.
func _relic_modal(r: Relic) -> void:
	var close := func():
		selected_item_id = ""
		render()
	_combat_hotkeys["Escape"] = close
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		dim.set_offset(side, -80)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		dim.set_offset(side, 80)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close.call()
	)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanelViolet"
	card.custom_minimum_size.x = 460
	var cv := _vbox(8)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.add_child(_relic_icon_box(r, 76))
	var tcol := _vbox(3)
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := _label(_loot_display_name(r), 16)
	nm.add_theme_color_override("font_color", ITEM_RARITY_COLOR.get(r.rarity, Palette.TEXT))
	tcol.add_child(nm)
	tcol.add_child(_label(_relic_kind_line(r), 12, true))
	top.add_child(tcol)
	cv.add_child(top)
	var effects := _vbox(4)
	var def := GameData.find_unique_relic(r.unique_id)
	effects.add_child(_wrap_label(tr(str(def.get("desc", ""))) if not def.is_empty() else r.desc(), 13))
	if r.combo_with != "":
		var partner := str(GameData.find_unique_relic(r.combo_with).get("name", ""))
		effects.add_child(_wrap_label(tr("Combo: stronger with %s%s") % [tr(str(partner)), tr(str(" (active!)" if Combat.party_has_unique_relic(r.combo_with) else ""))], 12, true))
	cv.add_child(effects)
	cv.add_child(_hsep())
	var acts := HFlowContainer.new()
	acts.add_theme_constant_override("h_separation", 6)
	acts.add_theme_constant_override("v_separation", 6)
	var used := Combat.equipped_relics().size()
	if r.equipped:
		acts.add_child(_icon_button(GameData.relic_icon(r), "Unequip", func(id=r.id):
			GameState.toggle_equip_relic(id)
			render()
		))
	else:
		var eb := _icon_domain_button("ember", GameData.relic_icon(r), "Place on the altar", func(id=r.id):
			GameState.toggle_equip_relic(id)
			selected_item_id = ""
			render()
		)
		eb.disabled = used >= GameState.relic_slot_cap()
		eb.tooltip_text = tr("Every altar slot is full — take a relic off first") if eb.disabled else ""
		acts.add_child(eb)
	if not r.equipped:
		acts.add_child(_icon_button(GameData.CURRENCY_ICON_PATH["coins"], "Sell", func(id=r.id):
			selected_item_id = ""
			GameState.sell_relic(id)
			render()
		))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acts.add_child(sp)
	acts.add_child(_icon_button(GameData.BUTTON_ICON_PATH["back"], "Close", close))
	cv.add_child(acts)
	card.add_child(cv)
	center.add_child(card)
	root.add_child(overlay)
