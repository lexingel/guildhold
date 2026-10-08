extends "res://tests/base_test.gd"
## Relics bend rules (0.66): where they come from, the legendaries' rules,
## the Relic Vault, and an old save's rolled relics turning into Essence.

func _uniq(id: String) -> Relic:
	return Combat.relic_from_unique(GameData.find_unique_relic(id))


func _equip_only(rs: Array) -> void:
	GameState.relics.clear()
	for r in rs:
		r.equipped = true
		GameState.relics.append(r)


func _fight_party(ids: Array[String]) -> Dictionary:
	GameState.start_run("lesser", ids, null)
	GameState.run["node_state"] = {}
	GameState.choose_node_type("combat")
	GameState.engage_node()
	return GameState.run["node_state"]["combat_state"]


func run() -> void:
	seed(8)
	GameState.active_slot = 9
	GameState.reset()
	reveal_all()
	GameState.guild_name = "T"
	GameState.crystals = 5000
	var ids: Array[String] = []
	for r in ["D", "C", "D"]:
		var h := Combat.gen_hero(r, 6)
		h.id = "h%d" % GameState.next_id
		GameState.next_id += 1
		GameState.heroes.append(h)
		ids.append(h.id)

	# Where relics come from: fights drop gear; a relic reward is a unique the
	# guild doesn't hold, else an epic item.
	var only_items := true
	for i in 200:
		only_items = only_items and str(Combat.gen_loot("rare")["loot_type"]) == "item"
	check(only_items, "fights drop gear, not relics")
	var got := GameState.unique_or_epic()
	check(str(got["loot_type"]) == "relic" and (got["obj"] as Relic).rarity == "legendary", "a relic reward is a unique relic")
	for u in GameData.UNIQUE_RELICS:
		GameState.relics.append(_uniq(str(u["id"])))
	var none_left := GameState.unique_or_epic()
	check(str(none_left["loot_type"]) == "item" and (none_left["obj"] as Item).rarity == "epic", "with every unique held: an epic item")
	GameState.relics.clear()
	GameState.features_seen.erase("relics")
	check(str(GameState.unique_or_epic()["loot_type"]) == "item", "before relics are revealed: an item")
	reveal_all()

	# The Relic Vault: a slot at Lv1, Lv3 and Lv5 (and the Reliquary wing).
	check(GameState.relic_slot_cap() == 3, "3 slots to start")
	GameState.upgrades["res.vault"] = 1
	check(GameState.relic_slot_cap() == 4, "Vault Lv1: +1")
	GameState.upgrades["res.vault"] = 5
	check(GameState.relic_slot_cap() == 6, "Vault Lv5: 6 slots")
	GameState.upgrades.clear()

	# Legendaries.
	var ph := _uniq("phoenix_feather")
	_equip_only([ph])
	var st := _fight_party(ids)
	for h in st["party"]:
		h.hp = 0
	var out := Combat._check_party_defeated(st)
	check(out.is_empty() and (st["party"] as Array).all(func(h): return h.hp > 0), "Phoenix revives the party once")
	for h in st["party"]:
		h.hp = 0
	check(not Combat._check_party_defeated(st).is_empty(), "…but only once per rift")
	GameState.run = {}
	for h in GameState.heroes:
		h.hp = Combat.max_hp(h); h.down_runs = 0

	var bp := _uniq("bloodpact")
	_equip_only([bp])
	st = _fight_party(ids)
	check(float(st["mend"]) == 0.0, "Bloodpact: no mending")
	GameState.run = {}

	var sc := _uniq("stopped_clock")
	_equip_only([sc])
	st = _fight_party(ids)
	for m3 in st["monsters"]:
		m3["hp"] = 99999.0
		m3["max_hp"] = 99999.0
	for i in 30:
		if int(st["round_num"]) > 1 or GameState.run["node_state"].has("result"):
			break
		GameState.resolve_turn_now()
	check((st["log"] as Array).any(func(l): return str(l).contains("frozen in time")), "Stopped Clock freezes foes in round 1")
	GameState.run = {}

	var crown := _uniq("crown_of_oaths")
	_equip_only([crown])
	var champ_id := GameState.champion_roll[0]
	GameState.unlock_champion(champ_id)
	GameState.set_overseer(champ_id)
	GameState.start_run("lesser", ids, null)
	GameState.run["champion_calls"] = 1
	check(GameState.champion_call_ready(), "Crown: a second Call")
	GameState.run["champion_calls"] = 2
	check(not GameState.champion_call_ready(), "…not a third")
	GameState.run = {}

	var ws := _uniq("wardens_seal")
	_equip_only([ws])
	check(is_equal_approx(Combat.relic_special_total("hazard_guard_pct"), 0.2), "Warden's Seal guards against hazards")
	var mirror := _uniq("mirror_shard")
	_equip_only([mirror, ws])
	check(is_equal_approx(Combat.relic_special_total("hazard_guard_pct"), 0.4), "Mirror doubles the best other relic's specials")

	# An old save: rolled relics become Essence, levels are refunded, Path
	# relics go to a hero of their Path.
	GameState.reset()
	GameState.guild_name = "Old Relics"
	var mage := Combat.gen_hero("C", 6)
	mage.cls_id = "mage"
	mage.pool_id = "apprentice"
	mage.path = "evocation"
	mage.id = "h%d" % GameState.next_id
	GameState.next_id += 1
	GameState.heroes.append(mage)
	GameState.crystals = 100
	GameState.save()
	var d: Dictionary = JSON.parse_string(GameState.export_save_text())
	d["save_version"] = 5
	d["relics"] = [
		{"id": "rl1", "name": "Ember Sigil of Fury", "type": "Ember", "rarity": "rare", "dmg": 3, "hp": 8, "level": 3, "equipped": true, "unique_id": "",
			"specials": [{"kind": "dmg_pct", "value": 0.05, "label": "+5% damage"}]},
		{"id": "rl2", "name": "Kindling Box", "type": "Ember", "rarity": "legendary", "level": 1, "equipped": true, "unique_id": "p_kindling_box"},
		{"id": "rl3", "name": "Phoenix Feather", "type": "Ember", "rarity": "legendary", "level": 1, "equipped": true, "unique_id": "phoenix_feather"},
	]
	GameState.import_save_text(JSON.stringify(d), 9)
	GameState.load_save()
	var mult := float(GameData.find_rarity("rare")["mult"])
	var want := int(round(15.0 * mult * 1)) + int(round(15.0 * mult * 2)) + int(round(GameData.SALVAGE_CRYSTALS * mult * GameData.OLD_RELIC_ESSENCE_MULT))
	check(GameState.crystals == 100 + want, "a rolled relic and its levels became %d Essence (got %d)" % [want, GameState.crystals - 100])
	check(GameState.relics.size() == 1 and GameState.relics[0].unique_id == "phoenix_feather", "the unique stays on the altar")
	check(GameState.find_hero(mage.id).path_relic == "p_kindling_box", "the Path relic went to the Evocation hero")
	check(GameState.pending_toasts.any(func(t): return str(t.get("title", "")) == "Relics have changed"), "one toast says so")
	GameState.reset()
	GameState.delete_slot(9)
