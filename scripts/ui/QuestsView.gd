class_name QuestsView
extends RiftRunView
## The Quest board (postings, contracts, expeditions) and Milestones. Split
## out of GuildViews.gd in 0.69.2; calls only down the chain.


# ---------------- Quests: Guild Board & Milestones ----------------
const INK := Color("3b2414")
const INK_SOFT := Color("6b4a2e")
const QUEST_CATEGORY := {"hunt": "Hunt", "elite": "Hunt", "bounty": "Wanted", "seal_rank": "Seal the Rift",
	"seal_greater": "Seal the Rift", "trial_small": "Trial", "trial_flawless": "Trial", "craft": "Supply", "flawless_win": "Trial"}


## The Guild Board: quests pinned as parchment notes on a wooden board —
## taken ones first (red pin, TAKEN stamp), then this posting's offers.
var _quest_view := "contracts"   # the Quest board's tab: contracts | expeditions
var _exp_pick := {}   # posting index -> hero ids picked for it


func _render_quests(v: VBoxContainer) -> void:
	if GameState.expeditions_open():
		var tabs := HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 6)
		for t in [["contracts", "Contracts"], ["expeditions", tr("Expeditions") + (" (%d out)" % GameState.expeditions.size() if not GameState.expeditions.is_empty() else "")]]:
			var b := _button(str(t[1]), func(id=str(t[0])):
				_quest_view = id
				render())
			b.toggle_mode = true
			b.button_pressed = _quest_view == t[0]
			tabs.add_child(b)
		v.add_child(tabs)
		if _quest_view == "expeditions":
			_render_expeditions(v)
			return
	var board_w: float = v.custom_minimum_size.x
	var taken: Array = GameState.active_quests()
	var posted: Array = GameState.guild_board.filter(func(q): return str(q["status"]) == "posted")
	var failed: Array = GameState.guild_board.filter(func(q): return str(q["status"]) == "failed")
	var notes: Array = taken + failed + posted
	var cols := 3 if board_w >= 600.0 else 2
	var pad_x := roundf(board_w * 0.075)
	var gap := 16.0
	var note_w := floorf((board_w - pad_x * 2.0 - gap * (cols - 1)) / cols)
	var board := PanelContainer.new()
	board.custom_minimum_size.x = board_w
	var bst := StyleBoxTexture.new()
	bst.texture = load(GameData.QUEST_BOARD_BG)
	bst.content_margin_left = pad_x
	bst.content_margin_right = pad_x
	bst.content_margin_top = 34.0
	bst.content_margin_bottom = 46.0
	board.add_theme_stylebox_override("panel", bst)
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bcol := _vbox(14)
	board.add_child(bcol)
	# The header, chalked onto a plank at the top.
	var head := _vbox(0)
	var title := _label("Quests", 22)
	title.add_theme_color_override("font_color", Color("f1e2c0"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	var days_left: int = max(0, GameState.board_refresh_day - GameState.day)
	var sub := _label(tr("Day %d  ·  Taken %d/%d  ·  new postings in %d day%s") % [GameState.day, taken.size(), GameData.QUEST_ACTIVE_MAX, days_left, tr(str(_pl(days_left)))], 13)
	sub.add_theme_color_override("font_color", Color("e0cfa8"))
	sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	sub.add_theme_constant_override("shadow_offset_y", 1)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.tooltip_text = "A day passes with every rift run or rest. Unaccepted postings are replaced when the board refreshes; quests you've taken stay."
	sub.mouse_filter = Control.MOUSE_FILTER_STOP
	head.add_child(sub)
	bcol.add_child(head)
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", int(gap))
	grid.add_theme_constant_override("v_separation", int(gap))
	for q in notes:
		grid.add_child(_quest_note(q, note_w, 0.0, taken.size()))
	bcol.add_child(grid)
	if notes.is_empty():
		var empty := _label(tr("Nothing posted — new postings in %d day%s.") % [days_left, tr(str(_pl(days_left)))], 14)
		empty.add_theme_color_override("font_color", Color("e0cfa8"))
		bcol.add_child(empty)
	v.add_child(board)
	v.add_child(_hsep())

	v.add_child(_label("Milestones", 16))
	for m in GameData.milestones():
		var mid := str(m["id"])
		var claimed: bool = GameState.milestones_claimed.has(mid)
		var mprogress := GameState.milestone_progress(m)
		var mtarget := int(m["target"])
		var status := tr("Claimed") if claimed else "%d/%d" % [min(mprogress, mtarget), mtarget]
		v.add_child(_wrap_label("%s [%s]" % [tr(str(m["label"])), tr(str(status))], 12, claimed))
	v.add_child(_hsep())


## One quest as a pinned parchment note.
func _quest_note(q: Dictionary, w: float, h: float, taken_count: int) -> Control:
	var status := str(q["status"])
	var type := str(q["type"])
	var progress := GameState.quest_progress(q)
	var target := int(q["target"])
	var done := status == "active" and progress >= target
	var note := PanelContainer.new()
	note.custom_minimum_size = Vector2(w, maxf(h, 230.0))
	var paper := StyleBoxTexture.new()
	var paper_by_cat := {"Hunt": "quest_note_torn", "Wanted": "quest_note_poster"}
	paper.texture = load("res://assets/ui/%s.png" % paper_by_cat.get(QUEST_CATEGORY.get(type, ""), "quest_note"))
	paper.content_margin_left = 18.0
	paper.content_margin_right = 18.0
	paper.content_margin_top = 26.0
	paper.content_margin_bottom = 18.0
	if status == "failed":
		paper.modulate_color = Color(0.7, 0.68, 0.66)
	note.add_theme_stylebox_override("panel", paper)
	note.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var col := _vbox(4)
	var cat := _label(str(QUEST_CATEGORY.get(type, "Quest")).to_upper() if type == "bounty" else str(QUEST_CATEGORY.get(type, "Quest")), 18 if type == "bounty" else 16)
	cat.add_theme_font_override("font", DISPLAY_FONT)
	cat.add_theme_color_override("font_color", Color("7a1f14") if type == "bounty" else INK)
	cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cat)
	if type == "bounty":
		var mug := TextureRect.new()
		mug.texture = load(GameData.sprite_for_monster(str(q["param"])))
		mug.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mug.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mug.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mug.custom_minimum_size = Vector2(0, 56)
		col.add_child(mug)
	var desc := GameState.quest_desc(q)
	desc = desc.substr(desc.find(": ") + 2) if desc.find(": ") >= 0 else desc
	var dl := _wrap_label(desc[0].to_upper() + desc.substr(1), 13)
	dl.add_theme_color_override("font_color", INK)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(dl)
	if status == "active" and not done and q.has("due"):
		var left := int(q["due"]) - GameState.day
		var due := _label(tr("Due in %d day%s") % [left, tr(str(_pl(left)))] if left > 0 else tr("Due today"), 12)
		due.add_theme_color_override("font_color", Color("b3261e") if left <= 2 else INK)
		due.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(due)
	elif status == "posted":
		var takes := _label(tr("%d days once taken") % int(GameData.QUEST_DUE_DAYS.get(int(q.get("diff", 1)), 6)), 11)
		takes.add_theme_color_override("font_color", INK)
		takes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(takes)
	var stars := _label("★".repeat(int(q["diff"])) + "☆".repeat(3 - int(q["diff"])), 13)
	stars.add_theme_color_override("font_color", Color("9a5a12"))
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars.tooltip_text = "Difficulty"
	stars.mouse_filter = Control.MOUSE_FILTER_STOP
	col.add_child(stars)
	var rl := _wrap_label(tr("Reward: ") + GameState.quest_reward_desc(q["reward"]), 12)
	rl.add_theme_color_override("font_color", INK_SOFT)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(rl)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill)
	match status:
		"posted":
			var full := taken_count >= GameData.QUEST_ACTIVE_MAX
			var take := _button("Take on", func(id=str(q["id"])):
				var err := GameState.accept_quest(id)
				if err != "":
					push_warning(err)
				render()
			)
			take.disabled = full
			take.tooltip_text = tr("You already have %d quests — finish or abandon one first") % GameData.QUEST_ACTIVE_MAX if full else tr("Only progress made after taking it counts")
			take.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			col.add_child(take)
		"active":
			if done:
				var claim := _icon_domain_button("ember", GameData.BUTTON_ICON_PATH["confirm"], "Claim reward", func(id=str(q["id"])):
					GameState.claim_quest(id)
					render()
				)
				claim.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				col.add_child(claim)
			else:
				var pr := _label("%d / %d" % [progress, target], 12)
				pr.add_theme_color_override("font_color", INK)
				pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				col.add_child(pr)
				var bar := _flat_bar(target, progress, w - 60, 6, Color("8a3a1a"))
				bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				col.add_child(bar)
				var ab := _button("Abandon", func(id=str(q["id"])):
					GameState.abandon_quest(id)
					render()
				)
				ab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				ab.add_theme_font_size_override("font_size", 14)
				col.add_child(ab)
		"failed":
			var rm := _button("Take it down", func(id=str(q["id"])):
				GameState.abandon_quest(id)
				render()
			)
			rm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			col.add_child(rm)
	note.add_child(col)
	# Pin and stamp on an overlay over the content (a container child fills it).
	var deco := Control.new()
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(deco)
	# The pin: red on quests you've taken, brass on postings.
	var pin := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("b3261e") if status == "active" else (Color("777777") if status == "failed" else Color("c89b3c"))
	ps.set_corner_radius_all(8)
	ps.border_color = Color(0, 0, 0, 0.55)
	ps.set_border_width_all(2)
	pin.add_theme_stylebox_override("panel", ps)
	pin.size = Vector2(16, 16)
	pin.position = Vector2((w - 36.0) * 0.5 - 8, -20)
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.add_child(pin)
	# A stamp across the corner for taken / done / failed.
	var stamp_text := tr("DONE") if done else (tr("TAKEN") if status == "active" else (tr("FAILED") if status == "failed" else ""))
	if stamp_text != "":
		var st := _label(stamp_text, 18)
		st.add_theme_font_override("font", DISPLAY_FONT)
		st.add_theme_color_override("font_color", Color(0.2, 0.55, 0.2, 0.8) if done else (Color(0.7, 0.12, 0.1, 0.6) if status == "active" else Color(0.25, 0.25, 0.25, 0.75)))
		st.position = Vector2(-4, 4)
		st.rotation = deg_to_rad(-14)
		if not done:
			st.add_theme_font_size_override("font_size", 14)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deco.add_child(st)
	return note


var _mgmt_last := "ops"   # the Management branch opened last (the strip opens on it)


## Keepers of the Vale: the seven old Accord halls, what each costs and
## gives, and Restore.
func _render_accord_halls(v: VBoxContainer) -> void:
	v.add_child(_label(tr("Keepers of the Vale · %d/%d halls restored") % [GameState.halls_restored.size(), GameData.ACCORD_HALLS.size()], 18))
	v.add_child(_wrap_label("The rifts are shut. The old Accord guilds' halls stand empty across the Vale; restore them, and each keeps giving.", 12, true))
	for h in GameData.ACCORD_HALLS:
		var id := str(h["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var done := GameState.halls_restored.has(id)
		var pic_path := "res://assets/halls/%s.png" % id
		if ResourceLoader.exists(pic_path):   # the hall as it stands: dim until restored
			var pic := TextureRect.new()
			pic.texture = load(pic_path)
			pic.custom_minimum_size = Vector2(96, 60)
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			pic.modulate = Color.WHITE if done else Color(0.55, 0.55, 0.6)
			row.add_child(pic)
		var col := _vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := _label(tr(str(h["name"])), 14)
		if done:
			nm.add_theme_color_override("font_color", Palette.RANK_S)
		col.add_child(nm)
		col.add_child(_label(tr(str(h["bonus"])), 12, true))
		row.add_child(col)
		if done:
			row.add_child(_label("Restored", 12, true))
		else:
			var c := GameState.hall_cost(id)
			var lock := GameState.hall_lock(id)
			var b := _button(tr("Restore · %d Gold · %d Essence") % [int(c[0]), int(c[1])], func(k=id):
				_flavor_toast = GameState.restore_hall(k)
				render())
			b.disabled = lock != ""
			b.tooltip_text = lock
			row.add_child(b)
		v.add_child(row)
	v.add_child(_hsep())


const TIDE_PIC := "res://assets/halls/open_hollow.png"


## A heading (or just a Listen button, for "") over a voiced moment: it speaks
## once when first shown, and Listen plays it again. Nothing when the moment
## has no clips, or spoken lines are off or not in this language.
func _voice_heading(text: String, key: String, clips: Array[String]) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if text != "":
		row.add_child(_label(text, 12, true))
	if clips.is_empty() or not AudioManager.voice_wanted():
		return row
	var b := _button(tr("Listen"), func(): AudioManager.play_voice(key, clips, true))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 11)
	b.tooltip_text = tr("Hear it again")
	row.add_child(b)
	if GameState.pending_stories.is_empty():   # a story card on top speaks first; this waits for the next look
		AudioManager.play_voice(key, clips)
	return row


## The Open Hollow (Break): the tides so far, and tidewalls to raise.
func _render_open_hollow(v: VBoxContainer) -> void:
	v.add_child(_label(tr("The Open Hollow · %d tides held of %d") % [GameState.tides_held, GameState.tide_count], 18))
	if ResourceLoader.exists(TIDE_PIC):
		var pic := TextureRect.new()
		pic.texture = load(TIDE_PIC)
		pic.custom_minimum_size = Vector2(0, 150)   # fills the column width, any screen
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		v.add_child(pic)
	v.add_child(_wrap_label("The Hollow is out. A tide breaks every week, and each one held makes the next stronger. Every tidewall holds a little of it back.", 12, true))
	var next := 1.0 + GameData.TIDE_GROWTH * GameState.tides_held
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var col := _vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_label(tr("Tidewalls: %d") % GameState.tidewalls, 14))
	col.add_child(_label(tr("The next tide: %d%% of the first one's strength, %d%% against your walls") % [int(round(next * 100.0)), int(round(next / GameState.tidewall_factor() * 100.0))], 12, true))
	row.add_child(col)
	var c := GameState.tidewall_cost()
	var b := _button(tr("Raise a tidewall · %d Gold · %d Essence") % [int(c[0]), int(c[1])], func():
		_flavor_toast = GameState.raise_tidewall()
		render())
	b.disabled = GameState.tidewall_lock() != ""
	b.tooltip_text = GameState.tidewall_lock() if b.disabled else tr("Every tide is %d%% weaker against the guild for each wall.") % int(round(GameData.TIDEWALL_STEP * 100.0))
	row.add_child(b)
	v.add_child(row)
	v.add_child(_hsep())


## The endowment: spare Gold set aside for the next guild, as Laurels.
func _render_endowment(v: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var col := _vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_label(tr("Endow the next guild · %d so far") % GameState.endowments, 14))
	col.add_child(_wrap_label("Dobbs sets coin aside for whoever founds the next guild. Each Laurel costs more than the last.", 12, true))
	row.add_child(col)
	var b := _button(tr("+1 Laurel · %d Gold") % GameState.endow_cost(), func():
		_flavor_toast = GameState.endow()
		render())
	b.disabled = GameState.coins < GameState.endow_cost()
	row.add_child(b)
	v.add_child(row)
	v.add_child(_hsep())


## The hall's wings (Hall Works): the ones built, and the two on offer at the
## end of Acts I, III and V (one of them can be built). A guild ends with 3.
func _render_hall_works(v: VBoxContainer) -> void:
	var built: Array = GameData.HALL_WORKS.filter(func(w): return GameState.has_wing(str(w["id"])))
	var head := _label(tr("Wings · %d/%d built") % [built.size(), GameData.WINGS_MAX], 16)
	v.add_child(head)
	for w in built:
		var l := _wrap_label("%s (%s): %s" % [tr(str(w["name"])), tr(str(w["identity"])), tr(str(w["bonus"]))], 12)
		l.add_theme_color_override("font_color", Palette.RANK_S)
		v.add_child(l)
	if GameState.wing_offer.is_empty():
		var next: Array = GameData.WING_ACTS.filter(func(a): return GameState.campaign_act < int(a))
		if built.size() < GameData.WINGS_MAX and not next.is_empty():
			v.add_child(_wrap_label(tr("The next wing is offered at the end of Act %s: a choice of two, built with Gold.") % tr(str(GameState._roman(int(next[0]) - 1))), 12, true))
		v.add_child(_hsep())
		return
	v.add_child(_wrap_label("Two wings could stand again. Build one: the other stays a ruin, so choose what kind of guild you are.", 12, true))
	var grid := GridContainer.new()
	grid.columns = 1 if _narrow() else 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for id in GameState.wing_offer:
		var w: Dictionary = GameData.HALL_WORKS.filter(func(x): return x["id"] == id)[0]
		var card := PanelContainer.new()
		card.theme_type_variation = &"CardPanel"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col := _vbox(4)
		col.add_child(_label("%s · %s" % [tr(str(w["name"])), tr(str(w["identity"]))], 14))
		col.add_child(_wrap_label(tr(str(w["bonus"])), 12, true))
		var lock := GameState.hall_work_lock(str(id))
		var b := _icon_button(GameData.CURRENCY_ICON_PATH["coins"], tr("Build · %d Gold") % GameState.hall_work_cost(), func(k=str(id)):
			var err := GameState.build_hall_work(k)
			render()
			if err == "":
				_payoff(tr("%s rebuilt") % tr(str(w["name"])), tr(str(w["bonus"])), Palette.COINS, "level_up")
		)
		b.disabled = lock != ""
		b.tooltip_text = lock
		col.add_child(b)
		card.add_child(col)
		grid.add_child(card)
	v.add_child(grid)
	v.add_child(_hsep())


func _render_management(v: VBoxContainer) -> void:
	if GameState.keepers():
		_render_accord_halls(v)
	elif GameState.accord_ending == "break":
		_render_open_hollow(v)
	if GameState.legacy_written:   # spare Gold, after the halls or the walls
		_render_endowment(v)
	_render_hall_works(v)
	# Only the rooms already revealed (GameData.BRANCH_FEATURE).
	var open: Array = GameData.BRANCHES.filter(func(br): return GameState.feature_unlocked(str(GameData.BRANCH_FEATURE.get(br["id"], ""))))
	if mgmt_branch == "":
		mgmt_branch = _mgmt_last
	if not open.any(func(br): return br["id"] == mgmt_branch):
		mgmt_branch = str(open[0]["id"])
	_mgmt_last = mgmt_branch
	v.add_child(_label("Rooms · rebuilt with Gold; each level adds upkeep", 13, true))
	if open.size() > 1:
		v.add_child(_hub_strip(GameData.MANAGEMENT_BG, open.map(func(br): return [str(br["id"]), tr(str(br["name"])).trim_suffix(tr(" Branch"))]), mgmt_branch, func(id):
			mgmt_branch = id
			render()))
	var branch: Dictionary = {}
	for b in GameData.BRANCHES:
		if b["id"] == mgmt_branch:
			branch = b
	v.add_child(_label("%s — %s" % [tr(str(branch["name"])), tr(str(branch["sub"]))], 16))
	var grid := GridContainer.new()
	grid.columns = 1 if _narrow() else 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for n in branch["nodes"]:
		grid.add_child(_management_node_card(branch, n))
	v.add_child(grid)
	v.add_child(_hsep())
	v.add_child(_reset_guild_button())


func _reset_guild_button() -> Control:
	var reset_btn := _icon_button("res://assets/skills/shard_green.png", "Click again to confirm reset" if confirm_reset else "Reset Guild", func():
		if not confirm_reset:
			confirm_reset = true
			render()
			get_tree().create_timer(3.0).timeout.connect(func():
				confirm_reset = false
				if screen == "camp" and term_tab == "management":
					render()
			)
			return
		confirm_reset = false
		GameState.reset()
		GameState.save()
		screen = "onboard"
		render()
	)
	reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return reset_btn


## One upgrade node as a card — icon/name header, a level progress bar
## (replaces the old "(Lvl 2/5)" text-only readout), current + next-level
## effect text, then the Upgrade/capstone action — instead of a single
## full-width text row, so a branch's 4-5 nodes read as a grid of cards
## rather than a stack of near-identical lines.
func _management_node_card(branch: Dictionary, n: Dictionary) -> PanelContainer:
	var key := "%s.%s" % [branch["id"], n["id"]]
	var cur := int(GameState.upgrades.get(key, 0))   # as built; a damaged building works lower (GameState.lvl)
	var node_max := int(n["max"])
	var gold := str(n.get("currency", "")) == "gold"
	var maxed := cur >= node_max
	var icon_path: String = GameData.MANAGEMENT_NODE_ICON.get(key, "")

	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanelViolet"
	card.custom_minimum_size.x = 330
	var cv := _vbox(5)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	if icon_path != "":
		header.add_child(_icon(icon_path, 28))
	var nm := _label(str(n["name"]), 15)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(nm)
	header.add_child(_label(tr("Lv %d/%d") % [cur, node_max], 12, true))
	cv.add_child(header)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = node_max
	bar.value = cur
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Palette.SURFACE
	bar_bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Palette.VIOLET_BRIGHT if maxed else Palette.VIOLET
	bar_fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", bar_fill)
	cv.add_child(bar)

	var now := _wrap_label(Combat.describe_node_effect(n["id"], GameState.lvl(key)), 13)
	now.add_theme_color_override("font_color", Palette.TEXT if cur > 0 else Palette.MUTED)
	cv.add_child(now)
	if int(GameState.damaged.get(key, 0)) > 0:
		var dmg := _wrap_label(tr("Damaged in a Riftbreak: works at Lv %d until repaired.") % GameState.lvl(key), 12)
		dmg.add_theme_color_override("font_color", Palette.HAZARD)
		cv.add_child(dmg)
		var rb := _button(tr("Repair a level — %d Gold") % GameState.repair_cost(key), func(k=key, nm=str(n["name"])):
			GameState.repair_building(k)
			render()
			_payoff(tr("%s repaired") % tr(nm), tr("Works at Lv %d") % GameState.lvl(k), Palette.COINS, "craft"))
		rb.disabled = GameState.coins < GameState.repair_cost(key)
		cv.add_child(rb)
	cv.add_child(_wrap_label(tr("Each level: %s · upkeep +%d Gold a week") % [tr(str(n["every"])), GameData.UPKEEP_PER_LEVEL], 11, true))
	var perks: Dictionary = n["perks"]
	for pl in perks:
		var got := cur >= int(pl)
		var is_order := str(perks[pl]).begins_with("Order:")
		var pr := _wrap_label(tr("%s Lv%d — %s") % [tr(str("✓" if got else ("⚑" if is_order else "★"))), int(pl), tr(str(perks[pl]))], 12)
		pr.add_theme_color_override("font_color", Palette.RANK_E if got else (Palette.EMBER_BRIGHT if is_order else Palette.RANK_S))
		cv.add_child(pr)

	var building: Array = GameData.HAMLET_BUILDINGS.filter(func(hb): return str(hb.get("node", "")) == key)
	if not building.is_empty():
		cv.add_child(_wrap_label(tr("⌂ Camp: the %s is rebuilt at Lv3 and Lv5 (now tier %d/3)") % [tr(str(building[0]["name"])), GameState.hamlet_tier(building[0])], 11, true))
	else:
		cv.add_child(_wrap_label("⌂ Camp: every level grows the Guild Hall (guild tier)", 11, true))

	if not maxed:
		var cost := GameState.room_cost(key)
		var next_perk := str(perks.get(cur + 1, ""))
		var ub := _icon_button(icon_path, (tr("Upgrade to Lv%d — %d Gold") if gold else tr("Upgrade to Lv%d — %d Essence")) % [cur + 1, cost], func(k=key, nm=str(n["name"]), nid=str(n["id"]), perk=next_perk):
			var err := GameState.upgrade_node(k)
			if err != "":
				push_warning(err)
			render()
			if err == "":
				var lv := int(GameState.upgrades.get(k, 0))
				_payoff(tr("%s — Lv%d") % [tr(nm), lv], tr(perk) if perk != "" else tr(str(Combat.describe_node_effect(nid, lv))), Palette.EMBER_BRIGHT, "unlock")
		)
		ub.disabled = (GameState.coins if gold else GameState.crystals) < cost
		ub.tooltip_text = tr("Next: %s%s") % [tr(str(Combat.describe_node_effect(n["id"], cur + 1))), tr(str((tr("\nUnlocks: ") + next_perk) if next_perk != "" else ""))]
		cv.add_child(ub)
	else:
		var ml := _label("Fully upgraded", 12)
		ml.add_theme_color_override("font_color", Palette.RANK_E)
		cv.add_child(ml)

	card.add_child(cv)
	return card


## Expeditions (2026-10-09 playtest): the parties out, then the postings.
## Pick up to the posting's size from the heroes at camp; the odds update as
## you pick.
func _render_expeditions(v: VBoxContainer) -> void:
	if GameState.expedition_board.is_empty() and GameState.expeditions.is_empty():
		GameState.roll_expedition_board()
	v.add_child(_wrap_label(tr("Send heroes on a job off the map. They are gone for its whole days and still draw wages, while rifts and breaches go on without them. Success pays in full; a partial pays half and someone comes back hurt; a failure pays nothing and hurts the party. Every class and Path brings something (hover a hero); each counts once, so a mixed party does best. Parties out at once: %d.") % GameState.expedition_cap(), 12, true))
	for x in GameState.expeditions:
		var e := GameState.expedition_def(str(x["id"]))
		var names: Array = []
		for hid in x["hero_ids"]:
			var xh := GameState.find_hero(str(hid))
			names.append(tr(str(xh.name.split(" the ")[0])) if xh else "?")
		var card := PanelContainer.new()
		card.theme_type_variation = &"CardPanelViolet"
		var col := _vbox(4)
		col.add_child(_label(tr("Out: %s") % tr(str(e.get("name", ""))), 15))
		col.add_child(_label(tr("%s · back in %d day%s · %d%% odds") % [", ".join(names), int(x["left"]), tr(str(_pl(int(x["left"])))), int(round(float(x["chance"]) * 100))], 12, true))
		card.add_child(col)
		v.add_child(card)
	if GameState.expedition_board.is_empty():
		v.add_child(_label("Nothing posted until the board is renewed.", 13, true))
		return
	var full := GameState.expeditions.size() >= GameState.expedition_cap()
	var idle: Array = GameState.heroes.filter(func(h): return not h.is_champion and h.is_available())
	var grid := GridContainer.new()
	grid.columns = 1 if _narrow() else 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for i in GameState.expedition_board.size():
		var p: Dictionary = GameState.expedition_board[i]
		var e := GameState.expedition_def(str(p["id"]))
		var tier := int(e["tier"])
		var picked: Array = (_exp_pick.get(i, []) as Array).filter(func(hid): return idle.any(func(h): return h.id == hid))
		var card := PanelContainer.new()
		card.theme_type_variation = &"CardPanelEmber" if tier == 2 else &"CardPanel"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col := _vbox(5)
		col.add_child(_label(tr(str(e["name"])), 15))
		var tl := _label(tr("%s · %d day%s · up to %d hero%s · Need %d") % [tr(str(GameData.EXPEDITION_TIER_NAME[tier])), int(e["days"]), tr(str(_pl(int(e["days"])))), int(e["size"]), tr(str(GameData.pl(int(e["size"]), "es"))), int(p["need"])], 12)
		tl.add_theme_color_override("font_color", Palette.HAZARD if tier == 2 else (Palette.EMBER_BRIGHT if tier == 1 else Palette.good()))
		col.add_child(tl)
		col.add_child(_wrap_label(tr(str(e["text"])), 12, true))
		var pay := tr("Pays %d Gold") % int(p["gold"]) + (tr(", %d Essence") % int(p["essence"]) if int(p["essence"]) > 0 else "")
		var item_roll: Array = GameData.EXPEDITION_ITEM[tier]
		if str(item_roll[0]) != "":
			pay += tr(", %d%% chance of an item") % int(round(float(item_roll[1]) * 100))
		col.add_child(_wrap_label(pay, 12))
		if tier >= GameData.EXPEDITION_SCAR_TIER:
			var risk := _wrap_label("A failure here can leave a lasting scar.", 12)
			risk.add_theme_color_override("font_color", Palette.HAZARD)
			col.add_child(risk)
		var picks := HFlowContainer.new()
		picks.add_theme_constant_override("h_separation", 4)
		picks.add_theme_constant_override("v_separation", 4)
		for h in idle:
			var on: bool = picked.has(h.id)
			var hb := _button(tr("%s Lv%d") % [tr(str(h.name.split(" the ")[0])), h.level], func(idx=i, hid=h.id):
				var cur: Array = (_exp_pick.get(idx, []) as Array).duplicate()
				if cur.has(hid):
					cur.erase(hid)
				elif cur.size() < int(GameState.expedition_def(str(GameState.expedition_board[idx]["id"]))["size"]):
					cur.append(hid)
				_exp_pick[idx] = cur
				render())
			hb.toggle_mode = true
			hb.button_pressed = on
			hb.tooltip_text = tr("%s · power %d") % [tr(str(GameData.hero_role(h).capitalize())), Combat.power_of(h)] + "\n" + "\n".join(GameState.expedition_bonuses([h.id])["lines"])
			picks.add_child(hb)
		if idle.is_empty():
			picks.add_child(_label("Nobody at camp is free.", 12, true))
		col.add_child(picks)
		if not picked.is_empty():
			var bl := _wrap_label("\n".join(GameState.expedition_bonuses(picked)["lines"]), 12)
			bl.add_theme_color_override("font_color", Palette.good())
			col.add_child(bl)
			# A hero ready for a Path course needs others to cover the party while they train (the sim, 0.67.3).
			var left := idle.size() - picked.size() - 1
			var ready: Array = idle.filter(func(h): return not picked.has(h.id) and GameState.subclass_training_options(h).any(func(o): return str(o["lock"]) == "" and not bool(o["change"])))
			if not ready.is_empty() and left < 4:
				var wl := _wrap_label(tr("%s is ready for a Path course. With these away, only %d hero%s would be left for the rifts while they train.") % [tr(str(ready[0].name.split(" the ")[0])), left, tr(str(GameData.pl(left, "es")))], 12)
				wl.add_theme_color_override("font_color", Palette.HAZARD)
				col.add_child(wl)
		var odds :=GameState.expedition_chance(p, picked) if not picked.is_empty() else 0.0
		var send := _icon_domain_button("violet", GameData.BUTTON_ICON_PATH["confirm"], tr("Send them (%d%% odds)") % int(round(odds * 100)) if not picked.is_empty() else tr("Pick who goes"), func(idx=i, ids=picked):
			var err := GameState.send_expedition(idx, ids)
			if err != "":
				_flavor_toast = err
			_exp_pick = {}
			render())
		send.disabled = picked.is_empty() or full
		if full:
			send.tooltip_text = tr("Every expedition party is out")
		col.add_child(send)
		card.add_child(col)
		grid.add_child(card)
	v.add_child(grid)
