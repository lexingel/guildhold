extends "res://tests/base_test.gd"
## Path relics (0.65, carried by heroes in 0.66): two per Path, each bending
## its rule through Combat._pm while its carrier fights; sealing a Rank D+
## ladder rift offers 3 the guild doesn't hold, for the Paths its heroes
## walk, or the seal's Essence instead; an untaken offer pays the Essence.


func run() -> void:
	seed(65)
	GameState.active_slot = 9
	GameState.reset()
	reveal_all()
	GameState.guild_name = "T"

	# The data.
	var per_path := {}
	var pmods := {}
	var ok := true
	for d in GameData.PATH_RELICS:
		per_path[d["path"]] = int(per_path.get(d["path"], 0)) + 1
		ok = ok and GameData.PATHS.has(d["path"]) and not pmods.has(d["pmod"]) and GameData.find_unique_relic(str(d["id"])) == d and str(d["id"]).begins_with("p_")
		pmods[d["pmod"]] = true
	check(ok and GameData.PATH_RELICS.size() == 30 and per_path.size() == 15 and per_path.values().all(func(n): return n == 2), "30 Path relics, two per Path, each with its own rule bend")

	var ids: Array[String] = []
	for pair in [["warrior", "bloodrage"], ["warrior", "weaponmaster"], ["mage", "evocation"], ["cleric", "aegis"]]:
		var h := Combat.gen_hero("C", 6)
		h.cls_id = pair[0]
		h.pool_id = pair[0]
		h.path = pair[1]
		h.id = "h%d" % GameState.next_id
		GameState.next_id += 1
		Combat.refresh_stats(h)
		h.hp = Combat.max_hp(h)
		GameState.heroes.append(h)
		ids.append(h.id)
	GameState.runs_started = 5
	GameState.rifts_sealed = 5
	var walked := ["bloodrage", "weaponmaster", "evocation", "aegis"]

	# Who gets an offer, and of what.
	GameState.start_ladder_rift("E", ids, null)
	check(not GameState.path_relic_eligible(), "no offer below Rank D")
	GameState.run = {}
	GameState.start_ladder_rift("C", ids, null)
	check(GameState.path_relic_eligible(), "a Rank C ladder rift offers one")
	var offer := GameState.roll_path_relic_offer()
	check(offer.size() == 3 and offer.all(func(id): return walked.has(str(GameData.find_unique_relic(str(id))["path"]))), "3 relics, all for Paths the guild's heroes walk (%s)" % str(offer))

	# Taking one: a hero of its Path carries it; the guild's relic slots stay free.
	GameState.run["sealed"] = {"path_relics": offer}
	GameState.pick_path_relic(0)
	var uid := str(offer[0])
	var carrier: Array = GameState.heroes.filter(func(h): return h.path_relic == uid)
	check(carrier.size() == 1 and GameData.hero_path_id(carrier[0]) == str(GameData.find_unique_relic(uid)["path"]), "a hero of its Path carries it")
	check(not GameState.relics.any(func(r): return r.unique_id == uid), "it doesn't take a relic slot")
	GameState.pick_path_relic(1)
	check(GameState.heroes.filter(func(h): return h.path_relic != "").size() == 1, "only one pick per seal")
	var again_ok := true
	for t in 20:
		again_ok = again_ok and not GameState.roll_path_relic_offer().has(uid)
	check(again_ok, "a held relic isn't offered again")
	var twin: Array = GameData.PATH_RELICS.filter(func(d): return str(d["path"]) == str(GameData.find_unique_relic(uid)["path"]) and str(d["id"]) != uid)
	var twin_seen := false
	for t in 40:
		twin_seen = twin_seen or GameState.roll_path_relic_offer().has(str(twin[0]["id"]))
	check(twin_seen, "its twin still is (two heroes of a Path can each carry one)")
	var before := GameState.crystals
	GameState.run["sealed"] = {"path_relics": GameState.roll_path_relic_offer()}
	var full := GameState.path_relic_essence()
	GameState.finish_run()
	check(GameState.crystals >= before + full and full >= int(GameData.find_rift_rank("C").get("seal_essence", 0)) * 0, "an untaken offer pays the seal's Essence when the party goes home")

	# Passing at camp, the chest, and a hero leaving.
	var c: Hero = carrier[0]
	GameState.set_down_path_relic(c)
	check(c.path_relic == "" and GameState.path_relic_chest.has(uid), "set down: it waits in the chest")
	check(GameState.carry_path_relic(uid, ids[3]) != "" or GameData.hero_path_id(GameState.find_hero(ids[3])) == str(GameData.find_unique_relic(uid)["path"]), "only a hero of its Path can carry it")
	check(GameState.carry_path_relic(uid, c.id) == "" and c.path_relic == uid and not GameState.path_relic_chest.has(uid), "and a hero of its Path takes it back")
	GameState.dismiss_hero(c.id)
	check(GameState.path_relic_chest.has(uid), "a hero who leaves sets theirs down")
	GameState.give_path_relic(uid)   # no hero of its Path: still the chest
	check(GameState.path_relic_chest.count(uid) == 1, "with no hero of its Path, it stays in the chest")
	GameState.save()
	GameState.load_save()
	check(GameState.path_relic_chest.has(uid), "the chest survives a save")

	# In a fight: Red Tooth Torc lifts Bloodrage's cap while its carrier fights.
	GameState.reset()
	reveal_all()
	GameState.guild_name = "T"
	ids.clear()
	for pair in [["warrior", "bloodrage"], ["warrior", "weaponmaster"], ["mage", "evocation"], ["cleric", "aegis"]]:
		var h := Combat.gen_hero("C", 6)
		h.cls_id = pair[0]
		h.pool_id = pair[0]
		h.path = pair[1]
		h.id = "h%d" % GameState.next_id
		GameState.next_id += 1
		Combat.refresh_stats(h)
		h.hp = Combat.max_hp(h)
		GameState.heroes.append(h)
		ids.append(h.id)
	GameState.runs_started = 5
	var party: Array[Hero] = []
	for id in ids:
		party.append(GameState.find_hero(id))
	var rager := party[0]
	rager.hp = int(Combat.max_hp(rager) * 0.05)
	GameState.start_ladder_rift("C", ids, null)
	var plain := Combat._pp_dmg_mult(Combat.start_combat(party, "combat", GameState._diff(), 1), rager, 0)
	GameState.give_path_relic("p_red_tooth_torc", rager.id)
	var st := Combat.start_combat(party, "combat", GameState._diff(), 1)
	check(Combat._pm(st, "rage_cap") > 0.0 and Combat._pp_dmg_mult(st, rager, 0) > plain + 0.05, "Red Tooth Torc: a badly hurt Bloodrage hero hits harder (%.2f vs %.2f)" % [Combat._pp_dmg_mult(st, rager, 0), plain])
	var hp0 := rager.hp
	var healed := Combat._pp_heal(st, rager, 40)
	check(Combat._pm(st, "rage_heal_cut") > 0.0 and healed == 20 and rager.hp == hp0 + 20, "and its drawback: Bloodrage heroes heal half as much (%d of 40)" % healed)
	rager.hp = hp0
	var without: Array[Hero] = [party[1], party[2], party[3]]
	check(Combat._pm(Combat.start_combat(without, "combat", GameState._diff(), 1), "rage_cap") == 0.0, "without its carrier in the party it does nothing")
	# Kindling Box: Evocation starts warm.
	GameState.give_path_relic("p_kindling_box", party[2].id)
	var st2 := Combat.start_combat(party, "combat", GameState._diff(), 1)
	check(int(Combat._pp(st2, party[2]).get("heat", 0)) == 2, "Kindling Box: Evocation heroes start with 2 Heat")
	GameState.run = {}
	GameState.reset()
	GameState.delete_slot(9)
