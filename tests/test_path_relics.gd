extends "res://tests/base_test.gd"
## Path relics (0.65): two per Path, each bending its rule through Combat._pm;
## sealing a Rank D+ ladder rift offers 1 of 3 the guild doesn't own (two for
## the party's Paths), or Essence instead; an untaken offer pays the Essence.


func run() -> void:
	seed(65)
	GameState.active_slot = 9
	GameState.reset()
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
	var built := Combat.relic_from_unique(GameData.PATH_RELICS[0])
	check(built.rarity == "legendary" and built.unique_id == str(GameData.PATH_RELICS[0]["id"]), "they build as Legendary relics")

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

	# Who gets an offer.
	GameState.start_ladder_rift("E", ids, null)
	check(not GameState.path_relic_eligible(), "no offer below Rank D")
	GameState.run = {}
	GameState.start_ladder_rift("C", ids, null)
	check(GameState.path_relic_eligible(), "a Rank C ladder rift offers one")
	var party_paths := ["bloodrage", "weaponmaster", "evocation", "aegis"]
	var offer := GameState.roll_path_relic_offer()
	var mine := offer.filter(func(id): return party_paths.has(str(GameData.find_unique_relic(str(id))["path"])))
	check(offer.size() == 3 and mine.size() >= 2, "3 relics, at least two for the party's Paths (%s)" % str(offer))

	# Taking one; owned ones aren't offered again.
	GameState.run["sealed"] = {"path_relics": offer}
	GameState.pick_path_relic(0)
	var got := GameState.relics.filter(func(r): return r.unique_id == str(offer[0]))
	check(got.size() == 1 and got[0].equipped, "the pick joins the guild's relics (equipped while a slot is free)")
	GameState.pick_path_relic(1)
	check(GameState.relics.filter(func(r): return r.unique_id.begins_with("p_")).size() == 1, "only one pick per seal")
	var again_ok := true
	for t in 20:
		again_ok = again_ok and not GameState.roll_path_relic_offer().has(offer[0])
	check(again_ok, "an owned relic isn't offered again")
	var before := GameState.crystals
	GameState.run["sealed"] = {"path_relics": GameState.roll_path_relic_offer()}
	GameState.finish_run()
	check(GameState.crystals > before, "an untaken offer pays its Essence when the party goes home")

	# In a fight: Red Tooth Torc lifts Bloodrage's cap.
	for r in GameState.relics:
		r.equipped = false
	var party: Array[Hero] = []
	for id in ids:
		party.append(GameState.find_hero(id))
	var rager := party[0]
	rager.hp = int(Combat.max_hp(rager) * 0.05)
	GameState.start_ladder_rift("C", ids, null)
	var plain := Combat._pp_dmg_mult(Combat.start_combat(party, "combat", GameState._diff(), 1), rager, 0)
	var torc := Combat.relic_from_unique(GameData.find_unique_relic("p_red_tooth_torc"))
	torc.equipped = true
	GameState.relics.append(torc)
	var st := Combat.start_combat(party, "combat", GameState._diff(), 1)
	check(Combat._pm(st, "rage_cap") > 0.0 and Combat._pp_dmg_mult(st, rager, 0) > plain + 0.05, "Red Tooth Torc: a badly hurt Bloodrage hero hits harder (%.2f vs %.2f)" % [Combat._pp_dmg_mult(st, rager, 0), plain])
	# Kindling Box: Evocation starts warm.
	var box := Combat.relic_from_unique(GameData.find_unique_relic("p_kindling_box"))
	box.equipped = true
	GameState.relics.append(box)
	var st2 := Combat.start_combat(party, "combat", GameState._diff(), 1)
	check(int(Combat._pp(st2, party[2]).get("heat", 0)) == 2, "Kindling Box: Evocation heroes start with 2 Heat")
	GameState.run = {}
