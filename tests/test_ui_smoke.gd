extends "res://tests/base_test.gd"
## Draws every screen once, headless, so a script error in UI code fails the
## suite (the runner and CI fail on any SCRIPT ERROR): each camp tab and
## sub-tab, the Rift Hall and party screen, settings and the title with
## Feedback open, and a ranked fight (More, the Guard picker, the victory
## screen).


## Waits on physics frames: a headless process frame can outrun the fixed
## physics tick.
func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().physics_frame


func _show(main: Node, scr: String, tab: String = "") -> void:
	main.screen = scr
	if tab != "":
		main.term_tab = tab
	main.render()
	await _frames()


func run() -> void:
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _frames()
	# Main loads the real save on boot; the test works in slot 9 instead.
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "Smoke"
	GameState.campaign_act = 3
	GameState.rifts_sealed = 5
	GameState.best_rift_rank_sealed = 5
	GameState.day = 12
	GameState.coins = 900
	GameState.crystals = 300
	var ids: Array[String] = []
	var party: Array = []
	for r in ["B", "B", "A", "B"]:
		var h := Combat.gen_hero(r, 22)
		h.id = "h%d" % GameState.next_id
		GameState.next_id += 1
		GameState.heroes.append(h)
		ids.append(h.id)
		party.append(h)
	for i in 6:
		var it := Combat.gen_item(["common", "rare", "epic", "legendary"][i % 4])
		it.id = "i%d" % GameState.next_id
		GameState.next_id += 1
		GameState.items.append(it)
	GameState.relics.append(Combat.relic_from_unique(GameData.UNIQUE_RELICS[0]))
	GameState.add_tonic("healing")
	GameState.refresh_recruit_pool()
	GameState.hero_request = {"type": "feud", "ids": [ids[0], ids[1]], "day": 10}
	GameState.pending_stories.clear()
	main.selected_hero_id = ids[0]

	var drawn := 0
	for tab in ["camp", "roster", "recruits", "medical", "inventory", "management", "ledger", "quests", "records", "memorial", "bestiary", "compendium"]:
		await _show(main, "camp", tab)
		drawn += 1
	for rt in ["skills", "history", "hero"]:
		main.roster_tab = rt
		await _show(main, "camp", "roster")
	for cat in ["items", "relics", "supplies", ""]:
		main.inv_category = cat
		await _show(main, "camp", "inventory")
	for rec in ["stats", "history", "achievements"]:
		main.records_tab = rec
		await _show(main, "camp", "records")
	for cl in ["guild_hall", "arcane_lab", ""]:
		main.hub_cluster = cl
		await _show(main, "camp", "camp")
	# Full-window scenes: the camp's buildings sit on the art layer and the UI
	# above lets clicks through; other screens keep a normal UI over a backdrop.
	await _show(main, "camp", "camp")
	check(main._scene_ui.get_child_count() > 0 and main.root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the camp fills the window and its buildings take clicks")
	# A click that changes state and redraws at once builds the screen once, not again at frame end (0.69.1).
	GameState.state_changed.emit()
	main.render()
	var built: Node = main.root.get_child(main.root.get_child_count() - 1)
	await _frames()
	check(is_instance_valid(built) and not built.is_queued_for_deletion(), "a state change plus a direct redraw rebuilds the screen once")
	# The small gate leads straight down the Descent.
	await _show(main, "rift_hall")
	var gate: Array = main.find_children("*", "Button", true, false).filter(func(b): return b.tooltip_text == "The Descent")
	if not gate.is_empty():
		gate[0].pressed.emit()
		await _frames()
	check(not gate.is_empty() and main.screen == "party_assembly" and main._pending_descent, "the small gate leads down the Descent")
	await _show(main, "camp", "camp")

	# Past guilds' banners: the newest six hang in camp; a click opens the Hall of Guilds.
	GameState.legacy["guilds"] = []
	for i in 7:
		GameState.legacy["guilds"].append({"name": "Banner Guild %d" % i, "crest": i % 8 + 1, "ending": "renew", "day": 40, "rifts": 30, "laurels": 20})
	await _show(main, "camp", "camp")
	var banners: Array = main._scene_ui.find_children("*", "Button", true, false).filter(func(b): return b.tooltip_text.begins_with("Banner Guild"))
	check(banners.size() == 6 and not banners.any(func(b): return b.tooltip_text.begins_with("Banner Guild 0")), "the camp hangs the newest six past guilds' banners")
	if not banners.is_empty():
		banners[0].pressed.emit()
		await _frames()
	check(main.term_tab == "compendium" and main.compendium_tab == "chronicle", "a banner opens the Hall of Guilds")
	GameState.legacy["guilds"] = []
	# The story web's tabs: a known truth with its fragments, a struck claim.
	GameState.legacy["fragments"] = ["f_corin", "f_face", "f_orla_deserter"]
	GameState.legacy["truths"] = ["t_squad"]
	GameState.legacy["claims"] = ["orla_deserter", "orla_attack"]
	main.compendium_tab = "truths"
	await _show(main, "camp", "compendium")
	var tlabels: Array = main.root.find_children("*", "Label", true, false).map(func(l): return l.text)
	check(tlabels.any(func(t): return t.contains("four posts in a row")) and tlabels.any(func(t): return t.contains("Corin")), "the Truths tab shows a known truth and its fragments")
	main.compendium_tab = "accounts"
	await _show(main, "camp", "compendium")
	var rich: Array = main.root.find_children("*", "RichTextLabel", true, false).map(func(l): return l.text)
	check(rich.any(func(t): return t.contains("[s]") or t.contains("deserter")), "the Accounts tab lists Orla Venn's claims")
	for key in ["fragments", "truths", "claims"]:
		GameState.legacy.erase(key)
	main.compendium_tab = "chronicle"
	await _show(main, "camp", "roster")
	check(main._scene_ui.get_child_count() == 0 and main._ambient_layer.get_child_count() > 0 and main.root.mouse_filter != Control.MOUSE_FILTER_IGNORE, "a camp tab gets a drifting backdrop and a normal UI")
	main._feedback_open = true
	for scr in ["rift_hall", "tower", "crafting_hall", "settings", "title", "load_game", "credits"]:
		await _show(main, scr)
		drawn += 1
	main._feedback_open = false
	main.pending_party.assign(ids)
	await _show(main, "party_assembly")
	check(drawn >= 19, "every camp tab and front-end screen draws (%d)" % drawn)
	main.screen = "rift_hall"
	main._open_settings()
	main._open_settings()   # the gear pressed again on Settings
	(main._header_back()[0] as Callable).call()
	check(main.screen == "rift_hall", "Back from Settings returns where it was opened, even after a second gear press")
	# Party slots: a bench hero takes an occupied slot (the one there goes
	# home), a party member dropped on another swaps, an empty slot appends,
	# and the cap holds.
	main.pending_party.assign([ids[0], ids[1]])
	main._place_hero(ids[2], 0)
	var ok_replace: bool = main.pending_party == [ids[2], ids[1]]
	main._place_hero(ids[1], 0)
	var ok_swap: bool = main.pending_party == [ids[1], ids[2]]
	main._place_hero(ids[0], 3)
	main._place_hero(ids[3], 3)
	var ok_fill: bool = main.pending_party == [ids[1], ids[2], ids[0], ids[3]]
	check(ok_replace and ok_swap and ok_fill, "party slots: replace, swap and fill")
	await _show(main, "party_assembly")
	main._slot_pick = 1
	await _show(main, "party_assembly")
	check(main._combat_hotkeys.has("Escape"), "a slot's hero picker opens (Esc closes it)")
	main._slot_pick = -1
	main.pending_party.clear()
	# A guild received from another device: pick a slot and it opens there.
	var sent := GameState.export_save_text()
	main._receive_open = true
	main._received = {"text": sent, "name": GameState.guild_name, "sealed": GameState.rifts_sealed}
	await _show(main, "load_game")
	var slot := GameState.SLOT_COUNT - 1   # a real slot (run_tests puts the player's slots back)
	main._place_received(slot)
	check(GameState.active_slot == slot and GameState.guild_name != "" and main._received.is_empty() and main.screen in ["camp", "rift_run"], "a received guild lands in the chosen slot and opens")
	GameState.active_slot = 9

	# The Rift Ladder says what a Rank A rift puts at stake (0.68).
	main._ladder_pick = "A"
	await _show(main, "rift_hall")
	check(main.find_children("*", "Label", true, false).any(func(l): return l.text.contains("Heavy blows wound")), "a Rank A rift card names its stakes")
	# A ranked fight: the command bar, More, the Guard picker, a gamepad button.
	GameState.start_ladder_rift("A", ids, null)
	GameState.pending_stories.clear()
	await _show(main, "rift_run")
	GameState.engage_node()
	await _frames(5)
	main._more_open = false
	main.render()
	await _frames()
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_START
	pad.pressed = true
	main._unhandled_input(pad)
	await _frames()
	check(main._more_open, "Start on a gamepad opens More in a fight")
	main._ally_pick = "guard"
	main.render()
	await _frames()
	main._ally_pick = ""
	# Fight stakes (0.68): a wounded hero's plate says so.
	var wh := GameState.find_hero(ids[0])
	wh.wound = 30
	main.render()
	await _frames()
	check(main.find_children("*", "Control", true, false).any(func(c): return c.tooltip_text.contains("Wound: -30")), "a wounded hero's plate shows the wound")
	wh.wound = 0
	# Win it and draw the victory screen.
	var st: Dictionary = GameState.run["node_state"].get("combat_state", {})
	for m in st.get("monsters", []):
		m["hp"] = 1.0
	for k in 60:
		if GameState.run["node_state"].has("result"):
			break
		GameState.resolve_turn_now()
	main._combat_animating = false
	main.render()
	await _frames()
	check(GameState.run["node_state"].has("result"), "the fight ends and its result screen draws")
	GameState.retreat_now()
	await _show(main, "camp", "camp")

	# A screen transition caught mid-fade clears even with Main switched off.
	main._play_transition(false)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(0.8).timeout
	check(not main._veil.visible, "a transition clears even while the camp UI is switched off")
	main.process_mode = Node.PROCESS_MODE_INHERIT

	# The opening cinematic: skipped early it leaves the prologue card to tell
	# the story; watched to the end it stands in for it.
	var prologue := str(GameData.PROLOGUE["title"])
	GameState.pending_stories = [GameData.PROLOGUE.duplicate()]
	main._play_cinematic(true)
	await _frames()
	var cin: Cinematic = null
	for c in main.get_children():
		if c is Cinematic:
			cin = c
	check(cin != null, "the opening cinematic plays")
	cin._finish(true)
	await _frames()
	check(GameState.pending_stories.any(func(st): return str(st["title"]) == prologue), "skipped early: the prologue card still tells it")
	main._play_cinematic(true)
	await _frames()
	for c in main.get_children():
		if c is Cinematic:
			cin = c
	cin._shot = Cinematic.SHOTS.size()
	cin._finish(false)
	await _frames()
	check(not GameState.pending_stories.any(func(st): return str(st["title"]) == prologue), "watched through: it stands in for the prologue card")
	for i in Cinematic.SHOTS.size():
		check(ResourceLoader.exists(str(Cinematic.SHOTS[i][0])), "shot %d has its picture" % (i + 1))
	main.queue_free()
	await _frames()
