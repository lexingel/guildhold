extends "res://tests/base_test.gd"
## Fight stakes (0.68): wounds from heavy blows, by rift rank.

func _guild() -> void:
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "W"
	GameState.rifts_sealed = 5
	GameState.heroes.clear()
	for i in 4:
		var h := Combat.gen_hero("B", 6)
		h.id = "w%d" % i
		h.hp = Combat.max_hp(h)
		GameState.heroes.append(h)


func _ids() -> Array[String]:
	var out: Array[String] = []
	for h in GameState.heroes:
		out.append(h.id)
	return out


func run() -> void:
	seed(5)
	_guild()
	var h: Hero = GameState.heroes[0]
	GameState.start_ladder_rift("B", _ids(), null)
	check(GameState.stakes_rank() == "B" and GameState.wounds_on() and not GameState.wounds_last_run(), "a Rank B rift: wounds per fight")
	check(GameState.fall_costs_on(), "fall costs once three rifts are sealed")
	var base := Combat.base_max_hp(h)
	var added := GameState.add_wound(h, 100)
	check(added == 50 and h.wound == 50 and Combat.max_hp(h) == base - 50, "half a wounding blow comes off max HP (%d)" % h.wound)
	check(h.hp <= Combat.max_hp(h), "HP follows the lower ceiling")
	GameState.add_wound(h, 100000)
	check(h.wound == int(base * GameData.WOUND_CAP), "wounds stop at the cap (%d of %d)" % [h.wound, base])
	var back := Hero.from_dict(h.to_dict())
	check(back.wound == h.wound, "a wound survives a save")
	GameState.retreat_now()
	check(h.wound == 0 and Combat.max_hp(h) == base, "wounds close when the run ends")

	GameState.start_ladder_rift("E", _ids(), null)
	check(GameState.stakes_rank() == "E" and not GameState.wounds_on(), "no wounds below Rank C")
	GameState.retreat_now()
	GameState.start_ladder_rift("S", _ids(), null)
	check(GameState.wounds_last_run(), "from Rank S wounds last the run")
	GameState.run["daily"] = 1
	check(GameState.stakes_rank() == "", "the Daily has no stakes")
	GameState.run.erase("daily")
	GameState.hardship = -1
	check(GameState.stakes_rank() == "", "Story has no stakes")
	GameState.hardship = 0
	GameState.rifts_sealed = 2
	check(GameState.wounds_on() and not GameState.fall_costs_on(), "no fall costs before three seals")
	GameState.retreat_now()

	# Blows: a landed wind-up wounds an undefended hero; Defend never does.
	GameState.rifts_sealed = 5
	GameState.start_ladder_rift("B", _ids(), null)
	var party: Array[Hero] = []
	party.assign(GameState.heroes)
	var t: Hero = GameState.heroes[1]
	var wounded := false
	var defended_clean := true
	for i in 30:
		var st := Combat.start_combat(party, "combat", GameState._diff(), 0)
		st["dodge"] = 0.0
		t.hp = Combat.max_hp(t)
		t.wound = 0
		st["monsters"][0]["_charged"] = true
		Combat._monster_strike(st, 0, t, 1.0, false)
		wounded = wounded or t.wound > 0
		t.wound = 0
		t.hp = Combat.max_hp(t)
		st["monsters"][0]["_charged"] = true
		st["_defending"][t.id] = true
		Combat._monster_strike(st, 0, t, 1.0, false)
		defended_clean = defended_clean and t.wound == 0
	check(wounded, "a landed wind-up wounds at Rank B")
	check(defended_clean, "a defended blow never wounds")
	t.wound = 40
	Combat._finish_combat(Combat.start_combat(party, "combat", GameState._diff(), 0), true, false)
	check(t.wound == 0, "up to Rank A a wound closes when the fight ends")
	var sure := 0
	for i in 20:
		var st := Combat.start_combat(party, "combat", GameState._diff(), 0)
		for r in 2:
			st["round_num"] = r + 1
			Combat._start_round(st)
		sure += 1 if st.get("_sure_windup", false) else 0
	check(sure == 20, "every ordinary fight from Rank C has a wind-up by round 2 (%d/20)" % sure)

	# Auto-fight steps in front of an ally a heavy blow is aimed at.
	var sa := Combat.start_combat(party, "combat", GameState._diff(), 0)
	sa["round_num"] = 1
	Combat._start_round(sa)
	for m in sa["monsters"]:
		m["_charged"] = false
		m["_winding"] = false
	sa["monsters"][0]["_charged"] = true
	sa["intents"] = {0: {"kind": "attack", "target": GameState.heroes[1].id}}
	var it0 := Combat.monster_intent(sa, 0)
	var a0 := Combat.auto_action(sa, GameState.heroes[0])
	check(it0.get("heavy_blow", false) and it0["target"] != GameState.heroes[0], "the setup: a heavy blow aimed at an ally (%s)" % it0)
	check(str(a0.get("action", "")) == "guard" and str(a0.get("ally", "")) == str((it0["target"] as Hero).id), "auto-fight guards the ally a heavy blow is aimed at (%s)" % a0)
	GameState.retreat_now()

	GameState.start_ladder_rift("D", _ids(), null)
	var st_d := Combat.start_combat(party, "combat", GameState._diff(), 0)
	st_d["dodge"] = 0.0
	t.hp = Combat.max_hp(t)
	st_d["monsters"][0]["_charged"] = true
	Combat._monster_strike(st_d, 0, t, 1.0, false)
	check(t.wound == 0, "no wounds at Rank D")
	GameState.retreat_now()

	# From Rank S a wound lasts the run; a campfire halves it, a shrine closes some.
	GameState.start_ladder_rift("S", _ids(), null)
	# On the road from Rank S ordinary fights hit harder and every hit leaves a trace (0.69).
	seed(21)
	var plain := Combat.gen_monster(GameState._diff(), 0, "combat")
	seed(21)
	GameData.WOUND_ROAD_DMG = 1.0
	var mild := Combat.gen_monster(GameState._diff(), 0, "combat")
	GameData.WOUND_ROAD_DMG = 1.5
	check(int(plain["dmg"]) > int(mild["dmg"]), "from Rank S ordinary foes hit harder (%d vs %d)" % [int(plain["dmg"]), int(mild["dmg"])])
	t.wound = 0
	t.hp = Combat.max_hp(t)
	var st_t := Combat.start_combat(party, "combat", GameState._diff(), 0)
	st_t["dodge"] = 0.0
	var hp0 := t.hp
	for k in 10:
		if t.wound == 0:
			Combat._monster_strike(st_t, 0, t, 1.0, false)
	check(t.wound > 0 and t.wound <= int(ceil((hp0 - t.hp) * GameData.WOUND_SHARE)) + 1, "an ordinary hit leaves a trace from Rank S (%d)" % t.wound)
	# Momentum decides who strikes first on the road, and carries between fights (0.69).
	GameState.run.erase("momentum_bonus")
	var cold := Combat.start_combat(party, "combat", GameState._diff(), 0)
	check(cold.get("_foes_first", false), "from Rank S the foes strike first at %d Momentum" % GameData.MOMENTUM_START)
	cold["round_num"] = 1
	var order: Array = Combat._compute_turn_order(cold)
	check(str(order[0]["type"]) == "monster", "and act before every hero in round 1")
	GameState.run["momentum_bonus"] = GameData.ROAD_INITIATIVE - GameData.MOMENTUM_START
	var warm := Combat.start_combat(party, "combat", GameState._diff(), 0)
	check(not warm.get("_foes_first", false), "with %d Momentum the party keeps the initiative" % GameData.ROAD_INITIATIVE)
	warm["momentum"] = 4
	Combat._finish_combat(warm, true, false)
	check(int(GameState.run.get("momentum_bonus", 0)) == 4, "Momentum left after a won fight carries to the next")
	GameState.run.erase("momentum_bonus")
	var boss_st := Combat.start_combat(party, "boss", GameState._diff(), 0)
	check(not boss_st.get("_foes_first", false), "the boss isn't affected")
	t.wound = 100
	Combat._finish_combat(Combat.start_combat(party, "combat", GameState._diff(), 0), true, false)
	check(t.wound == 100, "from Rank S a wound outlasts the fight")
	t.hp = 1
	GameState.run["node_state"] = {}
	GameState.campfire_choose("rest")
	check(t.wound == 50, "a campfire's Rest halves it (%d)" % t.wound)
	GameState.run["node_state"] = {"path": ""}
	GameState.pray_at_shrine()
	check(t.wound == maxi(0, 50 - int(Combat.base_max_hp(t) * GameData.WOUND_SHRINE_CLOSE)), "a shrine closes a quarter of max HP")
	GameState.retreat_now()
	GameState.delete_slot(9)
