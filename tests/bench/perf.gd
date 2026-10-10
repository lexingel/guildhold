extends Node
## Times the hot paths on a mid-game guild (save slot 8, deleted after):
##   Godot --headless --path . tests/bench/perf.tscn
## Prints ms per call for save(), a full render() of busy screens, and the
## stat lookups the roster and fights lean on.


func _ms(c: Callable, n: int) -> float:
	var t := Time.get_ticks_usec()
	for i in n:
		c.call()
	return (Time.get_ticks_usec() - t) / 1000.0 / n


func _ready() -> void:
	var keep := FileAccess.get_file_as_bytes(GameState.LEGACY_PATH) if FileAccess.file_exists(GameState.LEGACY_PATH) else PackedByteArray()
	seed(4242)
	GameState.active_slot = 8
	GameState.reset()
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	GameState.active_slot = 8
	GameState.reset()
	GameState.guild_name = "Bench"
	GameState.tips_off = true
	GameState.campaign_act = 4
	GameState.rifts_sealed = 14
	GameState.best_rift_rank_sealed = 4
	GameState.day = 26
	GameState.coins = 2400
	for i in 10:
		var h := Combat.gen_hero("B", 12)
		h.id = "h%d" % GameState.next_id
		GameState.next_id += 1
		GameState.heroes.append(h)
	for i in 30:
		var it := Combat.gen_item(["common", "rare", "epic", "legendary"][i % 4])
		it.id = "i%d" % GameState.next_id
		GameState.next_id += 1
		GameState.items.append(it)
	GameState.pending_stories.clear()
	var h0: Hero = GameState.heroes[0]
	main.selected_hero_id = h0.id
	print("save()            %.2f ms" % _ms(GameState.save, 20))
	print("max_hp(hero)      %.4f ms" % _ms(func(): Combat.max_hp(h0), 2000))
	print("power_of(hero)    %.4f ms" % _ms(func(): Combat.power_of(h0), 500))
	for t in [["camp", "camp"], ["camp", "roster"], ["camp", "inventory"], ["rift_hall", ""]]:
		main.screen = t[0]
		if t[1] != "":
			main.term_tab = t[1]
		main.render()
		await get_tree().process_frame
		print("render %-16s %.2f ms" % [t[0] + "/" + t[1], _ms(main.render, 10)])
		await get_tree().process_frame
	main.screen = "camp"
	main.term_tab = "roster"
	print("  _sorted_heroes   %.2f ms" % _ms(main._sorted_heroes, 10))
	print("  _roster_row x10  %.2f ms" % _ms(func(): for hh in GameState.heroes: main._roster_row(hh).free(), 5))
	print("  _hero_card       %.2f ms" % _ms(func(): main._hero_card(h0).free(), 5))
	var fit: Array[Item] = []
	fit.assign(GameState.items.filter(func(it): return it.equipped_to == "" and GameState.item_fits_hero(it, h0)))
	var probes := {
		"evolve_lock": func(): GameState.evolve_lock(h0),
		"subclass_training_options": func(): GameState.subclass_training_options(h0),
		"fitting items": func(): GameState.items.filter(func(it): return it.equipped_to == "" and GameState.item_fits_hero(it, h0)),
		"hero_sheet": func(): var c := VBoxContainer.new(); main._render_hero_sheet(c, h0, fit); c.free(),
		"attr_panel": func(): main._attr_panel(h0).free(),
		"stat_panel": func(): main._stat_panel(h0).free(),
		"quirk_row": func(): main._quirk_row(h0).free(),
		"hero_title": func(): GameState.hero_title(h0),
		"equip_best_changes": func(): GameState.equip_best_changes(h0),
		"item_tile x fitting": func(): for it in fit: main._item_tile(it, 48, h0).free(),
		"equip_slot_frame": func(): main._equip_slot_frame(h0, "gear", 0, 58.0).free(),
		"hero_icon": func(): main._hero_icon(h0, 190).free(),
		"draggable icon": func(): main._draggable_item_icon(fit[0], 32, h0).free(),
	}
	print("    fitting items: %d" % fit.size())
	for k in probes:
		print("    %-26s %.2f ms" % [k, _ms(probes[k], 5)])
	var renders := [0]
	GameState.state_changed.connect(func(): renders[0] += 1)
	main.screen = "camp"
	main.term_tab = "roster"
	main.render()
	await get_tree().process_frame
	GameState.delete_slot(8)
	if keep.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.LEGACY_PATH))
	else:
		FileAccess.open(GameState.LEGACY_PATH, FileAccess.WRITE).store_buffer(keep)
	get_tree().quit()
