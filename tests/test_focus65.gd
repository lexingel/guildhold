extends "res://tests/base_test.gd"
## 0.65 (docs/design/focus_2026_10.md): Path Mastery, the wings' rewritten
## effects, a returning player's early reveals, and old saves keeping what
## they had.


func _hero(rank: String) -> Hero:
	var h := Combat.gen_hero(rank, 1)
	h.id = "h%d" % GameState.next_id
	GameState.next_id += 1
	GameState.heroes.append(h)
	return h


func run() -> void:
	GameState.active_slot = 9
	GameState.reset()
	reveal_all()
	GameState.guild_name = "T"

	# Path Mastery: a finished Path trains ranks at the yard for Essence.
	var h := _hero("S")
	check(GameState.mastery_lock(h) != "", "no Mastery without a Path")
	h.pool_id = "stormguard"
	h.path = "shieldwall"
	GameState.crystals = 50
	check(GameState.train_mastery(h.id) != "", "it costs Essence (%d)" % GameState.mastery_cost(h))
	GameState.crystals = 10000
	check(GameState.mastery_cost(h) == GameData.MASTERY_ESSENCE, "rank 1 costs %d Essence" % GameData.MASTERY_ESSENCE)
	check(GameState.train_mastery(h.id) == "" and GameState.crystals == 10000 - GameData.MASTERY_ESSENCE and str(h.training["program"]) == "mastery", "a day at the yard")
	GameState._train_day()
	check(h.mastery == 1 and h.training.is_empty(), "the day done: Mastery 1")
	check(absf(Combat._mx(h) - (1.0 + GameData.MASTERY_STEP)) < 0.0001, "the Path rule is %d%% stronger" % int(GameData.MASTERY_STEP * 100))
	check(GameState.mastery_cost(h) == 2 * GameData.MASTERY_ESSENCE, "each rank costs more")
	var guard := _hero("C")
	guard.formation = "front"
	guard.pool_id = "footman"
	guard.path = "shieldwall"
	var back := _hero("C")
	back.formation = "back"
	var party: Array[Hero] = [guard, back]
	var st := Combat.start_combat(party, "combat", GameData.DIFFICULTIES[0], 1)
	var hp0 := back.hp
	var left0 := Combat._pp_guardian_share(st, st["monsters"][0], back, 100.0)
	guard.mastery = 10
	guard.hp = Combat.max_hp(guard)
	var left10 := Combat._pp_guardian_share(st, st["monsters"][0], back, 100.0)
	check(left10 < left0, "Mastery 10: the Guardian takes a bigger share (%d -> %d left)" % [int(left0), int(left10)])
	back.hp = hp0
	h.mastery = GameData.MASTERY_MAX
	check(GameState.mastery_lock(h) != "", "Mastery stops at %d" % GameData.MASTERY_MAX)
	h.pool_id = "footman"   # stage 1
	h.mastery = 3
	check(GameState.mastery_cap(h) == 3 and GameState.mastery_lock(h) != "", "stage 1 opens 3 ranks")
	h.pool_id = "stormguard"
	h.mastery = 3
	GameState.save()
	GameState.load_save()
	check(GameState.find_hero(h.id).mastery == 3, "Mastery survives a save")
	h = GameState.find_hero(h.id)
	GameState.heroes = [h]
	check(GameState.mastery_pick() == h, "the advice names the hero to master")

	# The wings' effects (0.65): none repeats a hall room.
	GameState.hall_works = []
	for pair in [["bloodrage", "squire"], ["evocation", "apprentice"], ["aegis", "hearth-warden"]]:   # Paths to offer relics for (0.66)
		var walker := _hero("C")
		walker.path = pair[0]
		walker.pool_id = pair[1]
	var offer3 := GameState.roll_path_relic_offer().size()
	GameState.hall_works = ["reliquary"]
	check(GameState.roll_path_relic_offer().size() == offer3 + 1, "the Reliquary: Path relic offers show 4")
	GameState.hall_works = ["war_room"]
	GameState.run = {"hero_ids": [h.id], "node_state": {}}
	check(GameState.free_rally() and GameState.has_orders() and GameState.order_blocker("rally") != "Not unlocked", "the War Room: a free Rally in every rift")
	GameState.run = {"hero_ids": [h.id], "node_state": {"path": "shieldwall"}}
	h.level = 1
	h.xp = 0
	GameState.hall_works = []
	GameState.pray_at_shrine()
	var plain := h.xp + (100000 if h.level > 1 else 0)
	h.level = 1
	h.xp = 0
	GameState.run["node_state"] = {"path": "shieldwall"}
	GameState.hall_works = ["library"]
	GameState.pray_at_shrine()
	var doubled := h.xp + (100000 if h.level > 1 else 0)
	check(doubled > plain, "the Library: shrines teach more (%d -> %d)" % [plain, doubled])
	GameState.run = {}
	GameState.hall_works = ["smithy"]
	var cat: String = GameData.ITEM_CATEGORIES[0]
	GameState.items.clear()
	var fed: Array = []
	for i in 3:
		var it := Combat.gen_item("common", cat, "E")
		GameState.items.append(it)
		fed.append(it)
	var best: Item = fed[0]
	for it in fed:
		if GameState.item_roll(it) > GameState.item_roll(best):
			best = it
	var best_kind: String = best.kind
	var best_roll := GameState.item_roll(best)
	var before := GameState.items.size()
	GameState.craft_items(cat, "common")
	var made: Item = GameState.items[-1]
	check(GameState.items.size() == before - 2 and made.rarity == "rare", "three commons make a rare")
	check(made.kind == best_kind and absf(GameState.item_roll(made) - minf(best_roll, GameData.ITEM_ROLL_RANGE[1])) < 0.01, "the Smithy wing keeps the best stat line (%s)" % best_kind)

	# A returning player: Act II and before open from day 1, with toasts.
	GameState.reset()
	GameState.guild_name = "Back Again"
	GameState.legacy = {"guilds": [{"name": "Old", "act": 3}], "laurels": 0}
	check(GameState.veteran_reveal(), "a past guild got past Act I")
	check(GameState.feature_unlocked("forge") and GameState.feature_unlocked("rival") and GameState.feature_unlocked("management"), "Act II and before are open from day 1")
	check(not GameState.feature_unlocked("crafting") and not GameState.feature_unlocked("tower"), "Act III and later still wait")
	GameState.pending_stories.clear()
	GameState.check_feature_unlocks()
	check(not GameState.pending_stories.any(func(c): return str(c.get("title", "")).begins_with("New:")) and not GameState.pending_toasts.is_empty(), "announced by toasts, not story cards")
	GameState.legacy = {}

	# An old save (before 0.65) keeps what it had open.
	GameState.reset()
	GameState.guild_name = "Old Hands"
	GameState.rifts_sealed = 4
	GameState.campaign_act = 2
	GameState.hall_works = ["war_room"]
	GameState.features_seen = ["quests", "management", "rival"]
	GameState.save()
	var d: Dictionary = JSON.parse_string(GameState.export_save_text())
	d["save_version"] = 4
	d.erase("wing_offer")
	GameState.import_save_text(JSON.stringify(d), 9)
	GameState.load_save()
	for f in ["forge", "training", "requests", "relics", "hall_rooms", "hall_research", "wardcraft", "resolve"]:
		check(GameState.features_seen.has(f), "an old guild keeps %s open" % f)
	check(not GameState.features_seen.has("tower"), "but the Tower still waits for Act IV")
	check(GameState.wing_offer.is_empty(), "a guild with its Act I wing built isn't offered another")
	GameState.reset()
	GameState.delete_slot(9)
