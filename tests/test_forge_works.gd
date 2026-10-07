extends "res://tests/base_test.gd"
## Gold into power (0.61): the Forge tempers an item's rolled stats, Hall
## Works rebuild the guild hall's wings for guild-wide bonuses. Both persist.


func run() -> void:
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "T"
	var h := Combat.gen_hero("F", 1)
	h.id = "h%d" % GameState.next_id
	GameState.next_id += 1
	GameState.heroes.append(h)
	var it := Combat.gen_item("rare")
	GameState.items.append(it)
	GameState.equip_item(h.id, it.slot_type(), 0, it.id)
	var v0 := it.value

	# The Forge
	GameState.coins = 0
	var c1 := GameState.forge_cost(it)
	check(c1 > 0 and GameState.forge_item(it.id) != "", "no Gold, no temper")
	GameState.coins = 100000
	check(GameState.forge_item(it.id) == "" and it.forge_level == 1 and GameState.coins == 100000 - c1, "a temper costs %d Gold" % c1)
	check(absf(it.value - v0 * (1.0 + GameData.FORGE_STEP)) < 0.002, "the rolled stat grows %d%%" % int(GameData.FORGE_STEP * 100))
	check(GameState.forge_cost(it) > c1, "the next temper costs more")
	for i in 10:
		GameState.forge_item(it.id)
	check(it.forge_level == GameData.FORGE_MAX and GameState.forge_cost(it) == 0 and GameState.forge_item(it.id) != "", "tempering stops at %d" % GameData.FORGE_MAX)

	# Hall Works
	GameState.campaign_act = 1
	check(GameState.hall_work_lock("war_room") != "", "wings open after Act I")
	GameState.campaign_act = 2
	var tb := GameState.tactical_bonus()
	var w0 := GameState.hall_work_cost()
	check(GameState.build_hall_work("war_room") == "" and GameState.coins == 100000 - _spent_forge(it) - w0, "the War Room costs %d Gold" % w0)
	check(absf(GameState.tactical_bonus() - tb - 0.05) < 0.0001, "the War Room adds 5% damage and HP")
	check(GameState.build_hall_work("war_room") != "", "a wing is built once")
	check(GameState.hall_work_cost() == w0 + GameData.HALL_WORK_COST_STEP, "each wing costs more")
	var slots := GameState.relic_slot_cap()
	GameState.build_hall_work("reliquary")
	check(GameState.relic_slot_cap() == slots + 1, "the Reliquary adds a relic slot")
	var hall := {"id": "hall", "tier": "guild"}
	check(GameState.hamlet_tier(hall) >= 2, "two wings raise the hall's art")
	GameState.build_hall_work("smithy")
	var it2 := Combat.gen_item("rare")
	GameState.items.append(it2)
	check(GameState.forge_cost(it2) < c1, "the Smithy makes tempering cheaper")

	# Persistence
	GameState.save()
	GameState.load_save()
	var back: Array = GameState.items.filter(func(x): return x.id == it.id)
	check(not back.is_empty() and back[0].forge_level == GameData.FORGE_MAX, "tempering survives a save")
	check(GameState.hall_works.has("war_room") and GameState.hall_works.has("reliquary"), "wings survive a save")

	# Advice: a guild with spare Gold is told about the War Room and the Forge
	GameState.reset()
	GameState.guild_name = "T"
	GameState.campaign_act = 2
	GameState.coins = 50000
	var h2 := Combat.gen_hero("F", 1)
	h2.id = "h%d" % GameState.next_id
	GameState.next_id += 1
	GameState.heroes.append(h2)
	var it3 := Combat.gen_item("common")
	GameState.items.append(it3)
	GameState.equip_item(h2.id, it3.slot_type(), 0, it3.id)
	var kinds: Array = GameState.power_advice().map(func(a): return str(a["kind"]))
	check(kinds.has("hall_work") and kinds.has("forge"), "power advice names a hall wing and the Forge (%s)" % str(kinds))
	check(GameState.spare_wealth(), "idle Gold counts as spare wealth, so the Grow goal names the advice")
	GameState.crystals = 5000
	var rl := Combat.gen_relic("rare")
	rl.equipped = true
	GameState.relics.append(rl)
	GameState.features_seen.append("management")
	var ek: Array = GameState.power_advice().map(func(a): return str(a["kind"]))
	check(ek.has("relic") and ek.has("management"), "spare Essence: the advice names a relic level and a Management level (%s)" % str(ek))
	var lv0 := rl.level
	check(GameState.follow_advice(GameState.power_advice().filter(func(a): return str(a["kind"]) == "relic")[0]) == "" and rl.level == lv0 + 1, "following it upgrades the relic")
	GameState.coins = 0
	GameState.crystals = 0
	check(not GameState.spare_wealth(), "an empty treasury isn't spare wealth")
	GameState.reset()


func _spent_forge(it: Item) -> int:
	# What the five tempers cost before the Smithy (levels 1..5).
	var total := 0
	var lvl := it.forge_level
	for l in GameData.FORGE_MAX:
		it.forge_level = l
		total += GameState.forge_cost(it)
	it.forge_level = lvl
	return total
