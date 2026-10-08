extends "res://tests/base_test.gd"
## Gold into power (0.61): the Forge tempers an item's rolled stats, Hall
## Works rebuild the guild hall's wings for guild-wide bonuses. Both persist.


func run() -> void:
	GameState.active_slot = 9
	GameState.reset()
	reveal_all()
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

	# Hall Works (0.65): wings by choice, two offered at the end of Acts I, III and V
	GameState.campaign_act = 1
	GameState.check_wing_offer()
	check(GameState.wing_offer.is_empty() and GameState.hall_work_lock("war_room") != "", "no wing before Act I is done")
	GameState.campaign_act = 2
	GameState.check_wing_offer()
	check(GameState.wing_offer.size() == 2, "the end of Act I offers two wings")
	GameState.wing_offer = ["war_room", "reliquary"]
	check(GameState.hall_work_lock("smithy") != "", "a wing not on offer can't be built")
	var w0 := GameState.hall_work_cost()
	check(GameState.build_hall_work("war_room") == "" and GameState.coins == 100000 - _spent_forge(it) - w0, "the War Room costs %d Gold" % w0)
	check(GameState.wing_offer.is_empty() and GameState.hall_work_lock("reliquary") != "", "building one leaves the other a ruin")
	check(GameState.build_hall_work("war_room") != "", "a wing is built once")
	check(GameState.hall_work_cost() == w0 + GameData.HALL_WORK_COST_STEP, "each wing costs more")
	GameState.campaign_act = 4
	GameState.check_wing_offer()
	check(GameState.wing_offer.size() == 2 and not GameState.wing_offer.has("war_room"), "the end of Act III offers two unbuilt wings")
	GameState.wing_offer = ["reliquary", "smithy"]
	var slots := GameState.relic_slot_cap()
	GameState.build_hall_work("reliquary")
	check(GameState.relic_slot_cap() == slots + 1, "the Reliquary adds a relic slot")
	GameState.campaign_act = 6
	GameState.check_wing_offer()
	GameState.wing_offer = ["smithy", "library"]
	GameState.build_hall_work("smithy")
	var it2 := Combat.gen_item("rare")
	GameState.items.append(it2)
	check(GameState.forge_cost(it2) < c1, "the Smithy makes tempering cheaper")
	GameState.check_wing_offer()
	check(GameState.hall_works.size() == GameData.WINGS_MAX and GameState.wing_offer.is_empty(), "three wings, and no more are offered")
	var hall := {"id": "hall", "tier": "guild"}
	check(GameState.hamlet_tier(hall) == 1, "the hall's art follows the rooms, not the wings")
	GameState.upgrades["ops.barracks"] = 5
	GameState.upgrades["ops.infirmary"] = 5
	check(GameState.hamlet_tier(hall) == 2, "ten room levels raise it")
	GameState.upgrades.clear()
	# Their effects: the War Room's free Rally and elite pay; the Healers' Wing.
	check(GameState.has_wing("war_room") and not GameState.has_wing("healers"), "has_wing")
	GameState.hall_works.append("healers")
	GameState.rifts_sealed = 9
	check(GameState.recovery_runs() == 1, "the Healers' Wing: back after a day")
	GameState.hall_works.erase("healers")

	# Persistence
	GameState.save()
	GameState.load_save()
	var back: Array = GameState.items.filter(func(x): return x.id == it.id)
	check(not back.is_empty() and back[0].forge_level == GameData.FORGE_MAX, "tempering survives a save")
	check(GameState.hall_works.has("war_room") and GameState.hall_works.has("reliquary"), "wings survive a save")
	GameState.hall_works = ["chapel"]
	GameState.wing_offer = ["smithy", "library"]
	GameState.save()
	GameState.load_save()
	check(GameState.wing_offer == ["smithy", "library"], "the wing on offer survives a save")

	# Advice: a guild with spare Gold is told about the War Room and the Forge
	GameState.reset()
	reveal_all()
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
	GameState.check_wing_offer()
	var kinds: Array = GameState.power_advice().map(func(a): return str(a["kind"]))
	check(kinds.has("hall_work"), "power advice names the wing on offer (%s)" % str(kinds))
	GameState.coins = 50000
	GameState.wing_offer = []
	GameState.hall_works = ["war_room", "chapel", "library"]
	GameState.upgrades = {"ops.drill": 5, "infra.wardstones": 5, "res.vault": 5, "res.lab": 5}
	kinds = GameState.power_advice().map(func(a): return str(a["kind"]))
	check(kinds.has("forge"), "and, with the rooms built, the Forge (%s)" % str(kinds))
	GameState.upgrades = {}
	check(GameState.spare_wealth(), "idle Gold counts as spare wealth, so the Grow goal names the advice")
	GameState.crystals = 5000
	var rl := Combat.gen_relic("rare")
	rl.equipped = true
	GameState.relics.append(rl)
	GameState.hall_works = ["war_room", "chapel", "library"]   # no wing left to offer
	GameState.wing_offer = []
	var ek: Array = GameState.power_advice().map(func(a): return str(a["kind"]))
	check(ek.has("relic") and (ek.has("management") or ek.has("drill")), "spare Essence names a relic level, spare Gold a hall room (%s)" % str(ek))
	GameState.wing_offer = ["smithy", "reliquary"]
	ek = GameState.power_advice().map(func(a): return str(a["kind"]))
	check(not ek.is_empty() and ek[0] == "hall_work", "a wing on offer comes first (%s)" % str(ek))
	GameState.coins = GameState.weekly_wages() + GameState.upkeep() + 100
	ek = GameState.power_advice().map(func(a): return str(a["kind"]))
	check(not ek.has("drill") and not ek.has("management"), "and the rooms keep half its price in hand (%s)" % str(ek))
	GameState.coins = 50000
	GameState.wing_offer = []
	var lv0 := rl.level
	check(GameState.follow_advice(GameState.power_advice().filter(func(a): return str(a["kind"]) == "relic")[0]) == "" and rl.level == lv0 + 1, "following it upgrades the relic")
	GameState.coins = 0
	GameState.crystals = 0
	check(not GameState.spare_wealth(), "an empty treasury isn't spare wealth")
	GameState.reset()
	reveal_all()


func _spent_forge(it: Item) -> int:
	# What the five tempers cost before the Smithy (levels 1..5).
	var total := 0
	var lvl := it.forge_level
	for l in GameData.FORGE_MAX:
		it.forge_level = l
		total += GameState.forge_cost(it)
	it.forge_level = lvl
	return total
