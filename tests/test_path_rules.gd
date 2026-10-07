extends "res://tests/base_test.gd"
## Path rules in fights (0.62): each Path's stage-1 rule does what it says,
## plus a few Techniques, Signature moments and Resonance.


func _hero(pool_id: String, rank: String = "B", row: String = "") -> Hero:
	var h := Combat.gen_hero(rank, 6)
	var cls := GameData.find_class(pool_id)
	h.cls_id = str(cls["role"])
	h.pool_id = pool_id
	h.path = GameData.path_of(pool_id) if GameData.path_of(pool_id) != "" else str(GameData.role_paths(h.cls_id)[0])
	h.type = ""
	h.id = "h%d" % GameState.next_id
	GameState.next_id += 1
	h.formation = row if row != "" else str(GameData.ROLE_POSITION.get(h.cls_id, {}).get("row", "front"))
	Combat.refresh_stats(h)
	h.hp = Combat.max_hp(h)
	GameState.heroes.append(h)
	return h


func _base(role: String, row: String) -> Hero:
	var h := _hero(str(GameData.PATHS[GameData.role_paths(role)[0]]["stages"][0][0]), "B", row)
	h.pool_id = role
	h.path = ""
	return h


## A fight against `n` plain foes, no specials, turn order cleared.
func _fight(party: Array[Hero], n: int = 1) -> Dictionary:
	var st := Combat.start_combat(party, "combat", GameData.DIFFICULTIES[0], 1)
	var ms: Array = []
	for i in n:
		var m: Dictionary = st["monsters"][0].duplicate(true)
		m["hp"] = 400.0
		m["max_hp"] = 400.0
		m["armor"] = 0.0
		m["kit"] = []
		m["_winding"] = false
		m["_charged"] = false
		m["ability"] = {}
		m["status"] = ""
		m["mechanic"] = {}
		m["mechanic2"] = {}
		ms.append(m)
	st["monsters"] = ms
	st["monster_shields"] = {}
	st["intents"] = {}
	for i in n:
		st["intents"][i] = {"kind": "attack", "target": party[0].id}
	st["turn_order"] = []
	st["turn_idx"] = 0
	st["dodge"] = 0.0
	st["escort"] = {}
	return st


func run() -> void:
	seed(620)
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "T"

	# Shieldwall: Guardian takes a share of a blow aimed at the back row.
	var fm := _hero("footman", "B", "front")
	var cl := _base("cleric", "back")
	var st := _fight([fm, cl] as Array[Hero])
	st["intents"][0] = {"kind": "attack", "target": cl.id}
	st["monsters"][0]["dmg"] = 40.0
	var f0 := fm.hp
	var c0 := cl.hp
	Combat._resolve_monster_action(st, 0)
	check(fm.hp < f0 and cl.hp < c0, "Guardian: the Footman takes part of the back-row blow (%d->%d, %d->%d)" % [f0, fm.hp, c0, cl.hp])

	# Bloodrage: hits harder when hurt.
	var sq := _hero("squire", "B", "front")
	st = _fight([sq] as Array[Hero])
	var full := Combat._pp_dmg_mult(st, sq, 0)
	sq.hp = int(Combat.max_hp(sq) * 0.4)
	check(Combat._pp_dmg_mult(st, sq, 0) > full + 0.25, "Bloodrage: +damage at 40%% HP (%.2f vs %.2f)" % [Combat._pp_dmg_mult(st, sq, 0), full])

	# Weaponmaster: Combo builds on the same foe, resets on another.
	var tb := _hero("duelist", "B", "front")
	st = _fight([tb] as Array[Hero], 2)
	Combat._hero_hit(st, tb, 0, 1.0)
	Combat._hero_hit(st, tb, 0, 1.0)
	check(int(Combat._pp(st, tb)["combo"]) == 2 and Combat._pp_dmg_mult(st, tb, 0) > Combat._pp_dmg_mult(st, tb, 1), "Combo: 2 stacks on the same foe, none on another")
	Combat._hero_hit(st, tb, 1, 1.0)
	check(int(Combat._pp(st, tb)["combo"]) == 1, "Combo: switching targets resets it")

	# Marksman: Steady Aim when not attacked; spent after the shot.
	var fs := _hero("slinger", "B", "back")
	st = _fight([fs] as Array[Hero])
	check(Combat._pp_dmg_mult(st, fs, 0) >= 1.34, "Steady Aim: the opening shot is steady")
	Combat._hero_hit(st, fs, 0, 1.0)
	check(Combat._pp_dmg_mult(st, fs, 0) < 1.01, "Steady Aim: spent by the shot")

	# Trapper: the first foe to act steps in a snare.
	var tr_h := _hero("trapper", "B", "back")
	st = _fight([tr_h] as Array[Hero], 2)
	Combat._start_round(st)
	var snared: Array = (st["monsters"] as Array).filter(func(m): return int(m.get("_snared", 0)) > 0)
	check(snared.size() == 1 and float(snared[0]["hp"]) < 400.0, "Snares: one foe snared and hurt")

	# Stalker: a Mark the whole party hits harder.
	var stk := _hero("shadowtracker", "B", "back")
	var buddy := _base("warrior", "front")
	st = _fight([stk, buddy] as Array[Hero], 2)
	Combat._hero_hit(st, stk, 1, 1.0)
	check(int(Combat._pp(st, stk)["mark"]) == 1 and Combat._pp_dmg_mult(st, buddy, 1) > Combat._pp_dmg_mult(st, buddy, 0), "Mark: the party hits the marked foe harder")

	# Evocation: Heat builds per spell and detonates on a skill.
	var ev := _hero("cinderling", "B", "back")
	st = _fight([ev] as Array[Hero], 2)
	for k in 5:
		Combat._pp_after_action(st, ev, "attack")
	check(int(Combat._pp(st, ev)["heat"]) == 5, "Kindling: 5 Heat after 5 spells")
	var hp_other := float(st["monsters"][1]["hp"])
	Combat._pp_after_action(st, ev, "ability")
	check(int(Combat._pp(st, ev)["heat"]) == 0 and float(st["monsters"][1]["hp"]) < hp_other, "Kindling: a skill at 5 Heat detonates on every foe")

	# Warding: Ward Weave on the most-hurt ally each round.
	var wd := _hero("frost-scholar", "B", "back")
	var hurt := _base("warrior", "front")
	hurt.hp = int(Combat.max_hp(hurt) * 0.3)
	st = _fight([wd, hurt] as Array[Hero])
	Combat._start_round(st)
	check(float(st["hero_shields"].get(hurt.id, 0.0)) > 0.0, "Ward Weave: the most-hurt ally is warded")

	# Augury: Foresight cancels the first heavy blow.
	var au := _hero("shade-adept", "B", "back")
	var tank := _base("warrior", "front")
	st = _fight([tank, au] as Array[Hero])
	st["monsters"][0]["_charged"] = true
	var t0 := tank.hp
	Combat._resolve_monster_action(st, 0)
	check(tank.hp == t0 and not st["monsters"][0].get("_charged", false), "Foresight: the heavy blow comes to nothing")

	# Mercy: Overflow turns overhealing into a ward.
	var mc := _hero("acolyte", "B", "back")
	st = _fight([mc] as Array[Hero])
	Combat._pp_heal(st, mc, 50)
	check(float(st["hero_shields"].get(mc.id, 0.0)) > 0.0, "Overflow: healing past full becomes a ward")

	# Aegis: Sanctuary cuts damage to the party.
	var ae := _hero("frostward-sister", "B", "back")
	var fr := _base("warrior", "front")
	st = _fight([fr, ae] as Array[Hero])
	check(Combat._pp_taken_mult(st, st["monsters"][0], fr) < 0.95, "Sanctuary: the party takes less")

	# Zeal: Fervor heals the most-hurt ally by hitting.
	var zl := _hero("lay-brother", "B", "front")
	var wounded := _base("ranger", "back")
	wounded.hp = int(Combat.max_hp(wounded) * 0.3)
	st = _fight([zl, wounded] as Array[Hero])
	var w0 := wounded.hp
	Combat._hero_hit(st, zl, 0, 1.0)
	check(wounded.hp > w0, "Fervor: the hit heals the most-hurt ally")

	# Assassin: Execute on low foes, a kill refunds Momentum.
	var asn := _hero("cutpurse", "B", "front")
	st = _fight([asn] as Array[Hero], 2)
	st["monsters"][0]["hp"] = 50.0
	check(Combat._pp_dmg_mult(st, asn, 0) > Combat._pp_dmg_mult(st, asn, 1) + 0.4, "Execute: +50% on a foe under 35%")
	st["monsters"][0]["hp"] = 1.0
	st["momentum"] = 0
	Combat._hero_hit(st, asn, 0, 1.0)
	check(int(st["momentum"]) >= 2, "Execute: the kill refunds 2 Momentum")

	# Skirmisher: Evasion's dodge, and a jab on a dodge.
	var sk := _hero("runaway", "B", "front")
	st = _fight([sk] as Array[Hero])
	check(Combat._pp_dodge(st, sk, st["monsters"][0]) >= 0.15, "Evasion: +15% dodge")
	var m_hp := float(st["monsters"][0]["hp"])
	st["momentum"] = 0
	Combat._pp_after_struck(st, 0, sk, 0, true)
	check(int(st["momentum"]) == 1 and float(st["monsters"][0]["hp"]) < m_hp, "Evasion: a dodge gives Momentum and a jab")

	# Scrapper: Scrappy heals by hitting.
	var sc := _hero("herbrunner", "B", "front")
	sc.hp = int(Combat.max_hp(sc) * 0.5)
	st = _fight([sc] as Array[Hero])
	var s0 := sc.hp
	Combat._hero_hit(st, sc, 0, 1.0)
	check(sc.hp > s0, "Scrappy: hits heal")

	# Techniques replace the role's second skill from stage 2.
	var bk := _hero("berserker", "B", "front")
	var skills := GameData.hero_skills(bk)
	check(skills.size() == 2 and str(skills[1]["id"]).begins_with("tech_bloodrage"), "stage 2: the Technique takes the second skill slot")
	check(GameData.hero_skills(sq).all(func(x): return not str(x["id"]).begins_with("tech_")), "stage 1: no Technique yet")
	st = _fight([bk] as Array[Hero])
	st["momentum"] = 0
	var b0 := bk.hp
	st["pending_actions"][bk.id] = {"action": "skill:" + str(skills[1]["id"]), "target": 0}
	Combat._resolve_hero_action(st, bk)
	check(bk.hp < b0 and int(st["momentum"]) >= 2 and Combat._pp(st, bk).get("bp", false), "Blood Price: HP for Momentum and an empowered hit")

	# Signature moments: Red Mist (Bloodrage), Miracle (Mercy).
	var at := _hero("ashen-templar", "S", "front")
	st = _fight([at] as Array[Hero])
	at.hp = int(Combat.max_hp(at) * 0.2)
	Combat._pp_after_damage(st, at)
	check(int(Combat._pp(st, at).get("mist", 0)) > 0, "Red Mist: triggers under 30% HP")
	var dk := _hero("dawnkeeper", "S", "back")
	var fallen := _base("warrior", "front")
	st = _fight([fallen, dk] as Array[Hero])
	fallen.hp = 0
	Combat._pp_after_damage(st, fallen)
	check(fallen.hp > 0, "Miracle: a fallen ally rises")

	# Resonance: two Ember heroes hit harder together.
	var e1 := _base("warrior", "front")
	var e2 := _base("rogue", "front")
	e1.type = "Ember"
	e2.type = "Ember"
	var plain := Combat.start_combat([e1] as Array[Hero], "combat", GameData.DIFFICULTIES[0], 1)
	var both := Combat.start_combat([e1, e2] as Array[Hero], "combat", GameData.DIFFICULTIES[0], 1)
	check(Combat.resonance_counts([e1, e2]).get("Ember", 0) == 2, "Resonance counts shared elements")
	check(float(both["team_dmg_base"]) > (float(plain["team_dmg_base"]) + Combat.dmg_of(e2) * GameState.tactical_bonus()) * 1.05, "Resonance: Ember x2 adds damage")
	GameState.reset()
