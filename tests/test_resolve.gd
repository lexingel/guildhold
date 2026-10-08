extends "res://tests/base_test.gd"
## Resolve (0.64): a rift run's grit. It starts at RESOLVE_START, drains per
## floor (and for elites, hazards, fleeing), comes back at campfires, shrines
## and some events; at RESOLVE_WAVER or less foes act first in round 1, at 0
## the party also loses its starting Momentum and some damage. It is off
## during the haul's grace (the first seals) and survives a save.


func run() -> void:
	seed(64)
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "T"
	var ids: Array[String] = []
	for r in ["warrior", "ranger", "mage", "cleric"]:
		var h := Combat.gen_hero("C", 6)
		h.cls_id = r
		h.pool_id = r
		h.path = ""
		h.id = "h%d" % GameState.next_id
		GameState.next_id += 1
		Combat.refresh_stats(h)
		h.hp = Combat.max_hp(h)
		GameState.heroes.append(h)
		ids.append(h.id)
	GameState.runs_started = 5
	GameState.coins = 5000

	# Off during the grace: no change, no tier.
	GameState.rifts_sealed = 0
	GameState.start_ladder_rift("C", ids, null)
	check(not GameState.resolve_on() and GameState.change_resolve(-3) == 0 and GameState.resolve_tier() == 0, "Resolve is off before the first seals")
	GameState.run = {}

	GameState.rifts_sealed = 5
	GameState.start_ladder_rift("C", ids, null)
	check(GameState.resolve_on() and GameState.resolve_now() == GameData.RESOLVE_START, "a run starts at %d Resolve" % GameData.RESOLVE_START)
	GameState.advance_node()
	check(GameState.resolve_now() == GameData.RESOLVE_START - int(GameData.RESOLVE_DRAIN["floor"]), "each floor costs %d" % int(GameData.RESOLVE_DRAIN["floor"]))

	# Restores, clamped to the cap.
	GameState.run["resolve"] = 4
	GameState.run["node_state"] = {}
	GameState.campfire_choose("rest")
	check(GameState.resolve_now() == 4 + int(GameData.RESOLVE_GAIN["rest"]), "a campfire's Rest gives %d" % int(GameData.RESOLVE_GAIN["rest"]))
	GameState.run["node_state"] = {}
	GameState.campfire_choose("train")
	check(GameState.resolve_now() == 4 + int(GameData.RESOLVE_GAIN["rest"]) + int(GameData.RESOLVE_GAIN["campfire"]), "its other choices give %d" % int(GameData.RESOLVE_GAIN["campfire"]))
	GameState.run["node_state"] = {}
	GameState.pray_at_shrine()
	GameState._apply_event_effect({"resolve": 2})
	check(GameState.resolve_now() == GameData.RESOLVE_MAX, "a shrine and an event add more, up to %d" % GameData.RESOLVE_MAX)

	# Tiers.
	var tiers := []
	for r in [GameData.RESOLVE_WAVER + 1, GameData.RESOLVE_WAVER, 1, 0]:
		GameState.run["resolve"] = r
		tiers.append(GameState.resolve_tier())
	check(tiers == [0, 1, 1, 2], "Steady above %d, Wavering at %d-1, Broken at 0 (%s)" % [GameData.RESOLVE_WAVER, GameData.RESOLVE_WAVER, str(tiers)])

	# In a fight.
	var party: Array[Hero] = []
	party.assign(GameState.current_party())
	GameState.run["resolve"] = 10
	var calm := Combat.start_combat(party, "combat", GameState._diff(), 1)
	GameState.run["resolve"] = GameData.RESOLVE_WAVER
	var waver := Combat.start_combat(party, "combat", GameState._diff(), 1)
	var order: Array = waver["turn_order"]
	var first_hero := order.find(order.filter(func(e): return e["type"] == "hero")[0])
	check(int(waver["_waver"]) == 1 and first_hero > 0 and order.slice(first_hero).all(func(e): return e["type"] == "hero"), "Wavering: every foe acts before the first hero in round 1")
	GameState.run["resolve"] = 0
	var broken := Combat.start_combat(party, "combat", GameState._diff(), 1)
	check(int(broken["momentum"]) == 0 and is_equal_approx(float(broken["_attack_mult"]), float(calm["_attack_mult"]) * (1.0 - GameData.RESOLVE_BROKEN_DMG)), "Broken: no starting Momentum, %d%% less damage" % int(GameData.RESOLVE_BROKEN_DMG * 100))
	check(int(calm["_waver"]) == 0 and int(calm["momentum"]) > 0, "a steady party fights as before")

	# Save and reload.
	GameState.run["resolve"] = 4
	GameState.save()
	GameState.load_save()
	check(GameState.resolve_now() == 4 and GameState.resolve_on(), "Resolve survives a save")
	# A run saved before 0.64 has none and stays off.
	GameState.run.erase("resolve")
	check(not GameState.resolve_on() and GameState.resolve_tier() == 0, "an older run has no Resolve")
	GameState.run = {}
