extends "res://scripts/autoload/combat/CombatGen.gd"
## Combat, part 4 (the autoload): a fight â€” setup, turn order, hero and monster turns, round effects, defeat analysis, outcome.
## The chain, bottom up: combat/CombatStats.gd -> Effects -> Gen -> this file; each part only calls down.


## Turn-based combat, per-hero and per-monster: a fight starts with
## start_combat() (one-time setup: monster roll via gen_monsters(), all
## party-wide bonus totals) and then advances one round per resolve_round()
## call. Each living hero has their own pending action (state["pending_actions"],
## hero_id -> {"action": "attack"/"ability"/"skill:<id>"/"defend"/..., "target":
## monster index}, mutated between renders by GameState.set_hero_action
## without resolving anything). Skills and Abilities spend the party's shared
## Momentum (state["momentum"]), built by attacks, kills and taking hits
## while Defending or Guarding. Foes telegraph each round's move in
## state["intents"] (see _roll_intent / monster_intent). HP lives directly on each Hero throughout (no pooling), so win/
## retreat/loss need no redistribution step. Monsters live in state["monsters"]
## (Array of {name, hp, max_hp, dmg, mechanic, is_main} — mechanic is only ever
## non-empty on the "is_main" unit, and only for a "boss" encounter). Every
## living monster retaliates independently each round against a random living
## hero; a hero knocked out (hp reaches 0) sits out the rest of the fight but
## the party keeps fighting — a loss only happens once every hero is down, a
## win only once every monster is down. State is persisted by the caller
## (GameState.engage_node/resolve_round_now) across renders in
## run["node_state"]["combat_state"], the same per-node-cache pattern already
## used for shop/hazard nodes. `kind` is "combat"/"elite"/"boss".
func start_combat(party: Array[Hero], kind: String, diff: Dictionary, floor_idx: int) -> Dictionary:
	var is_boss := kind == "boss"
	var is_elite := kind == "elite"
	var monsters := gen_monsters(diff, floor_idx, kind)

	var raw_sum := 0.0
	for h in party:
		raw_sum += dmg_of(h)
	var team_dmg_base: float = (raw_sum * GameState.tactical_bonus()) * (1.0 + synergy_value_for("dmg_pct") + bond_bonus_for(party, "dmg_pct"))

	var first_round_bonus: float = (0.25 if GameState.vanguard() else 0.0) + party_skill_total(party, "first_round_pct") + relic_special_total("first_round_pct") + relic_drawback_total("first_round_pct") + synergy_value_for("first_round_pct") + bond_bonus_for(party, "first_round_pct")
	var escalate: float = party_skill_total(party, "escalate_pct") + relic_special_total("escalate_pct") + relic_drawback_total("escalate_pct") + synergy_value_for("escalate_pct")
	var mend: float = 0.0 if party_has_unique_relic("bloodpact") else min(GameData.MEND_CAP + GameState.year_add("mend_cap"), party_skill_total(party, "mend_pct") + relic_special_total("mend_pct") + relic_drawback_total("mend_pct") + synergy_value_for("mend_pct") + bond_bonus_for(party, "mend_pct"))
	var dodge: float = min(GameData.DODGE_CAP, party_skill_total(party, "dodge_pct") + relic_special_total("dodge_pct") + relic_drawback_total("dodge_pct") + synergy_value_for("dodge_pct") + bond_bonus_for(party, "dodge_pct"))
	var wipe_guard: float = min(0.9, party_skill_total(party, "wipe_guard") + relic_special_total("wipe_guard") + relic_drawback_total("wipe_guard") + bond_bonus_for(party, "wipe_guard"))
	var counter: float = min(0.6, relic_special_total("counter_pct"))
	var momentum_proc: float = min(0.75, relic_special_total("momentum_pct"))
	var kill_shield: float = min(0.6, relic_special_total("kill_shield_pct"))
	var alpha_strikes: float = (party_skill_total(party, "boss_alpha_strike") + relic_special_total("boss_alpha_strike")) if is_boss else 0.0

	var log: Array[String] = []
	var enc: Dictionary = monsters[0].get("encounter", {})
	if not enc.is_empty():
		log.append("%s! %s" % [tr(str(enc["name"])), tr(str(enc["hint"]))])
	if monsters.size() == 1:
		log.append(tr("A %s blocks the way (%d HP).") % [tr(str(monsters[0]["name"])), monsters[0]["hp"]])
	else:
		var names: Array[String] = []
		for m in monsters:
			names.append(tr(str(m["name"])))
		log.append(tr("%d foes block the way: %s.") % [monsters.size(), ", ".join(names)])
	for m in monsters:
		if not m["mechanic"].is_empty():
			log.append("%s: %s" % [tr(str(m["mechanic"]["name"])), tr(str(m["mechanic"]["desc"]))])
		var mechanic2: Dictionary = m.get("mechanic2", {})
		if not mechanic2.is_empty():
			log.append("%s: %s" % [tr(str(mechanic2["name"])), tr(str(mechanic2["desc"]))])
		if m.has("phase"):
			var ph: Dictionary = GameData.BOSS_PHASES[m["phase"]]
			log.append("%s: %s" % [tr(str(ph["name"])), tr(str(ph["desc"]))])
		for a in m.get("affixes", []):
			log.append("%s: %s" % [tr(str(GameData.ELITE_AFFIXES[a]["name"])), tr(str(GameData.ELITE_AFFIXES[a]["desc"]))])
	if alpha_strikes > 0:
		var alpha: float = team_dmg_base * alpha_strikes
		monsters[0]["hp"] = float(monsters[0]["hp"]) - round(alpha)
		log.append(tr("An opening volley lands for %d!") % round(alpha))

	# A "shielded"-ability monster starts the fight with a one-time absorb
	# shield on incoming hero damage — pre-filled here (once, not re-rolled
	# each round) mirroring how alpha_strikes above is also a one-time
	# fight-start effect rather than a per-round one.
	var monster_shields: Dictionary = {}
	for i in monsters.size():
		var ability: Dictionary = monsters[i].get("ability", {})
		if ability.get("kind") == "shielded":
			monster_shields[i] = float(monsters[i]["max_hp"]) * float(ability["value"])
			log.append(tr("%s: %s (shielded)") % [tr(str(monsters[i]["name"])), tr(str(ability["name"]))])

	var pending_actions: Dictionary = {}
	for h in party:
		pending_actions[h.id] = {"action": "attack", "target": 0}
	# Drill Yard Lv5 and a campfire's Sharpen (run "momentum_bonus") add to
	# the Momentum a fight starts with.
	var momentum: int = GameData.MOMENTUM_START + (3 if GameState.abilities_ready_each_fight() else 0) + int(GameState.run.get("momentum_bonus", 0))
	GameState.run.erase("momentum_bonus")
	# Resolve (0.64): a worn-down party is caught off guard.
	var waver: int = 0 if GameState.run.has("tower") else GameState.resolve_tier()
	if waver >= 2:
		momentum = 0
		log.append(tr("The party's Resolve is broken: foes strike first, and the heroes fight without Momentum."))
	elif waver == 1:
		log.append(tr("The party is wavering: foes strike first."))
	# From Rank S, Momentum decides who strikes first on the road (0.69).
	var road_first := false
	if waver == 0 and kind == "combat" and GameState.wounds_last_run():
		road_first = momentum < GameData.ROAD_INITIATIVE
		log.append(tr("The foes strike first: the party has %d Momentum, %d keeps the initiative.") % [momentum, GameData.ROAD_INITIATIVE] if road_first
			else tr("The party has the initiative (%d Momentum).") % momentum)

	# An escort NPC quest, folded onto an ordinary "combat" node rather than a
	# whole new node kind — a chance for a fragile ally to tag along who
	# monster retaliation can occasionally hit instead of a hero (see
	# resolve_round's retaliation loop). {} = no escort this fight, the same
	# "empty dict = not present" contract mechanic/mechanic2 already use.
	var escort: Dictionary = {}
	if kind == "combat" and not GameState.run.has("tower") and randf() < 0.25:
		var avg_hp := 0.0
		for h in party:
			avg_hp += max_hp(h)
		avg_hp /= float(max(1, party.size()))
		var ehp: int = max(15, int(round(avg_hp * 0.4)))
		var ename: String = GameData.ESCORT_NAMES[randi() % GameData.ESCORT_NAMES.size()]
		escort = {"name": ename, "hp": ehp, "max_hp": ehp}
		log.append(tr("A %s tags along, hoping to survive the crossing.") % tr(str(ename)))

	var hp_now := 0.0
	var hp_max := 0.0
	var hp_base := 0.0
	for h in party:
		hp_now += max(0, h.hp)
		hp_max += max_hp(h)
		hp_base += base_max_hp(h)
	var state := {
		"_start_hp_pct": hp_now / maxf(1.0, hp_max),
		"_start_hp_base": hp_now / maxf(1.0, hp_base),   # against max HP before wounds (0.68)
		"party": party, "kind": kind, "diff": diff, "floor_idx": floor_idx,
		"is_boss": is_boss, "is_elite": is_elite,
		"monsters": monsters, "background_idx": _biome_background(diff),
		"team_dmg_base": team_dmg_base, "raw_sum": raw_sum,
		"first_round_bonus": first_round_bonus, "escalate": escalate,
		"mend": mend, "dodge": dodge, "wipe_guard": wipe_guard, "wipe_guard_used": false, "counter": counter,
		"momentum_proc": momentum_proc, "momentum": mini(momentum, GameData.MOMENTUM_MAX), "kill_shield": kill_shield, "hero_shields": {},
		"monster_shields": monster_shields, "hero_poison": {}, "escort": escort,
		"round_num": 0, "log": log,
		"pending_actions": pending_actions, "_waver": waver, "_foes_first": road_first,
	}
	_pp_start(state)   # Paths (0.62): per-hero counters, Resonance
	# Seed round 1's turn order immediately so the combat screen's very first
	# render already knows whose turn it is, instead of needing a resolve_turn
	# call just to find out.
	_start_round(state)
	return state


## True if `h` has an Ability at all (a trained subclass, 0.62) — used to
## gate both the combat action-button row and the Ability's cooldown ticking.
static func qualifies_for_ability(h: Hero) -> bool:
	return GameData.SUBCLASS_ABILITIES.has(h.pool_id)   # 0.62: comes with the subclass (base classes have none)


## "tonic:<id>" -> id ("tonic" alone is a Healing Tonic).
static func _tonic_id(action: String) -> String:
	return action.substr(6) if action.begins_with("tonic:") else "healing"


func gain_momentum(state: Dictionary, n: int) -> void:
	state["momentum"] = clampi(int(state.get("momentum", 0)) + n, 0, GameData.MOMENTUM_MAX)


## What `action` ("ability" or "skill:<id>") costs in Momentum and which row
## it needs: [cost, row].
func action_cost(action: String) -> Array:
	if action == "ability":
		return [GameData.ABILITY_MOMENTUM_COST, "any"]
	if action.begins_with("skill:"):
		var sk := GameData.find_skill_def(action.substr(6))
		return [int(sk.get("cost", 0)), str(sk.get("row", "any"))]
	return [0, "any"]


## "" if `h` can use `action` right now, else why not (for the command bar
## and the auto-player).
func action_block(state: Dictionary, h: Hero, action: String) -> String:
	if action == "ability" and not qualifies_for_ability(h):
		return tr("Comes with a subclass")
	if action.begins_with("skill:") and not GameData.hero_skills(h).any(func(sk): return "skill:" + str(sk["id"]) == action):
		return tr("Not learned yet")
	var c := action_cost(action)
	if str(c[1]) != "any" and (str(c[1]) == "back") != (h.formation == "back"):
		return tr("%s row only") % tr(str(c[1])).capitalize()
	var need := int(c[0]) - (1 if action == "ability" and state.get("_res_arcane", false) else 0)   # Resonance: Arcane x3
	if int(state.get("momentum", 0)) < need:
		return tr("Needs %d Momentum") % need
	return ""


## One-line hint about the round about to happen, meant to sit above the
## action rows as a warning rather than only showing up in the log after the
## fact. Boss-mechanic messages (read from the main monster unit) take
## priority; every fight (not just bosses) falls back to a general heavy-hit/
## stacking-damage heuristic so the signal isn't boss-only.
func describe_incoming(state: Dictionary) -> String:
	var monsters: Array = state["monsters"]
	var main_mechanic: Dictionary = {}
	var main_mechanic2: Dictionary = {}
	for m in monsters:
		if bool(m.get("is_main", false)):
			main_mechanic = m["mechanic"]
			main_mechanic2 = m.get("mechanic2", {})
			break
	# round_num is prepared (incremented + turn order rolled) by _start_round
	# before this round's first turn ever runs — see resolve_turn — so it
	# already names the round currently in progress, not the last completed
	# one; no +1 needed here anymore.
	var next_round: int = int(state.get("round_num", 0))
	# A double-mechanic boss (SS-rank+ mapped rift) checks both rolled
	# mechanics here, same message per id as the single-mechanic case —
	# whichever one matches first wins, same as only ever having had one.
	for mech in [main_mechanic, main_mechanic2]:
		if mech.is_empty():
			continue
		match mech.get("id"):
			"warded":
				if next_round <= 2:
					return tr("Warded — dodge won't help this round.")
			"enrage":
				if next_round > GameData.BOSS_ENRAGE_ROUND:
					return tr("Enraged — retaliation is empowered this round.")
			"regen":
				return tr("Regenerating — it will heal after this exchange.")
			"frenzied":
				return tr("Frenzied — its blows already hit harder.")
	for m in monsters:
		if not m.has("phase") or float(m["hp"]) <= 0.0:
			continue
		var points := GameData.boss_phase_points(m)
		var done := int(m.get("_phases_done", 0))
		if done < points.size() and float(m["hp"]) <= float(m["max_hp"]) * (float(points[done]) + 0.2):
			return tr("%s is close to %d%% health: %s.") % [tr(str(str(m["name"]).split(",")[0])), int(round(float(points[done]) * 100.0)), tr(str(GameData.BOSS_PHASES[m["phase"]]["desc"]).trim_prefix(tr("At half health, ")).trim_prefix(tr("At half health ")))]

	var party: Array[Hero] = state["party"]
	var living: Array[Hero] = []
	living.assign(party.filter(func(h): return h.hp > 0))
	if living.is_empty():
		return ""
	var worst_back := 0.0
	for m in monsters:
		if float(m["hp"]) <= 0:
			continue
		var back: float = float(m["dmg"])
		var is_enraging: bool = main_mechanic.get("id") == "enrage" or main_mechanic2.get("id") == "enrage"
		if bool(m.get("is_main", false)) and is_enraging and next_round > GameData.BOSS_ENRAGE_ROUND:
			back = back * (1.0 + 0.15 * (next_round - GameData.BOSS_ENRAGE_ROUND))
		worst_back = max(worst_back, back)
	var avg_max := 0.0
	for h in living:
		avg_max += max_hp(h)
	avg_max /= living.size()
	if avg_max > 0.0 and worst_back / avg_max > 0.35:
		return tr("A heavy blow is coming: Defend or Guard, or it wounds.") if GameState.wounds_on() else tr("A heavy blow is coming — consider Defending.")
	if float(state["escalate"]) > 0.0 and next_round >= 3:
		return tr("Damage is stacking — every attack counts more now.")
	return ""


## A monster's raw hit this round before defend/dodge/shields — enrage and
## frenzy included. Shared by the real attack and the intent preview.
func _monster_hit(m: Dictionary, round_num: int) -> float:
	var back: float = float(m["dmg"])
	var mech: Dictionary = m.get("mechanic", {})
	var mech2: Dictionary = m.get("mechanic2", {})
	var ability: Dictionary = m.get("ability", {})
	if (mech.get("id") == "enrage" or mech2.get("id") == "enrage") and round_num > GameData.BOSS_ENRAGE_ROUND:
		back = round(back * (1.0 + 0.15 * (round_num - GameData.BOSS_ENRAGE_ROUND)))
	if ability.get("kind") == "frenzy" and float(m["hp"]) / float(m["max_hp"]) <= 0.3:
		back = round(back * (1.0 + float(ability["value"])))
	return back


## What monster `i` is about to do this round, for the combat screen:
## {"target": Hero, "dmg": int, "heavy": bool} or {} if it's down / no target.
## Heavy = a quarter of the target's max HP or more (same bar as the log's
## heavy-hit reactions). Intercepts/escort hits can still change the outcome.
## What an auto-played hero does this turn (Auto toggle, Quick fight, the
## balance sim): Defend against a heavy blow aimed at them, heal a badly hurt
## ally, break a wind-up, the Champion's Call on a boss, the Ability or a
## damage skill when Momentum allows, otherwise attack the weakest foe.
func auto_action(state: Dictionary, h: Hero) -> Dictionary:
	var monsters: Array = state["monsters"]
	var tgt: int = max(0, _lowest_hp_living_monster_idx(monsters))
	for mi in monsters.size():
		var it := monster_intent(state, mi)
		if it.get("heavy_blow", false) and it["target"] == h:
			return {"action": "defend", "target": 0}
	var ok := func(a: String) -> bool: return action_block(state, h, a) == ""
	var party: Array = state["party"]
	# From Rank C a heavy blow wounds (0.68): step in front of an ally it's aimed at.
	if GameState.wounds_on() and ok.call("guard"):
		for mi in monsters.size():
			var it := monster_intent(state, mi)
			var tg = it.get("target")
			if it.get("heavy_blow", false) and tg is Hero and tg != h and tg.hp > 0 and guard_of(state, tg) == null and not state["_defending"].has(tg.id):
				return {"action": "guard", "target": 0, "ally": tg.id}
	var hurt: Array = party.filter(func(x): return x.hp > 0 and x.hp < max_hp(x) * 0.45)
	if not hurt.is_empty() and ok.call("skill:heal"):
		return {"action": "skill:heal", "target": 0}
	for mi in monsters.size():
		if float(monsters[mi]["hp"]) > 0 and monsters[mi].get("_winding", false):
			if ok.call("skill:shield_bash"):
				return {"action": "skill:shield_bash", "target": mi}
			if ok.call("skill:frost_nova"):
				return {"action": "skill:frost_nova", "target": 0}
	if bool(state.get("is_boss", false)) and GameState.champion_call_ready(h):
		return {"action": "call", "target": 0}
	if ok.call("ability"):
		var at := _ability_target(state, h)
		if at >= 0:
			return {"action": "ability", "target": at}
	var tech_act := _pp_auto(state, h)   # a Path's Technique when it fits the moment
	if not tech_act.is_empty():
		return tech_act
	# A Healing Tonic for a badly hurt ally when no heal skill is ready.
	if GameState.tonic_count("healing") > 0:
		var worst: Hero = null
		for x in party:
			if x.hp > 0 and x.hp < max_hp(x) * 0.3 and (worst == null or x.hp < worst.hp):
				worst = x
		if worst:
			return {"action": "tonic:healing", "target": 0, "ally": worst.id}
	# Spend on a damage skill only with enough left over for someone's Ability.
	if int(state.get("momentum", 0)) >= GameData.ABILITY_MOMENTUM_COST + 2:
		for sk in GameData.hero_skills(h):
			if str(sk["effect"]) in ["pierce", "strike", "backstab", "volley"] and ok.call("skill:" + str(sk["id"])):
				return {"action": "skill:" + str(sk["id"]), "target": tgt}
	return {"action": "attack", "target": tgt}


## Whether `h`'s Ability is worth firing now, and at which foe: the index,
## or -1 to hold it. Heals wait for someone hurt, Revive for someone down,
## defensive ones for a big hit coming; stuns go to a foe winding up, marks
## to the toughest foe, executes to the weakest. Full Momentum always fires.
func _ability_target(state: Dictionary, h: Hero) -> int:
	var monsters: Array = state["monsters"]
	var party: Array = state["party"]
	var weakest: int = max(0, _lowest_hp_living_monster_idx(monsters))
	var toughest := weakest
	for i in monsters.size():
		if float(monsters[i]["hp"]) > float(monsters[toughest]["hp"]):
			toughest = i
	var full := int(state.get("momentum", 0)) >= GameData.MOMENTUM_MAX - 1
	var eff := str(GameData.SUBCLASS_ABILITIES.get(h.pool_id, {}).get("effect", ""))
	var hurt: bool = party.any(func(x): return x.hp > 0 and x.hp < max_hp(x) * 0.6)
	var danger := false
	for mi in monsters.size():
		var it := monster_intent(state, mi)
		if it.get("kind") in ["sweep", "heavy", "windup", "harvest", "drown", "immolate", "sunder"] or (it.get("target") != null and int(it.get("dmg", 0)) >= max_hp(it["target"]) * 0.25):
			danger = true
	match eff:
		"revive":
			return 0 if party.any(func(x): return x.hp <= 0) or party.any(func(x): return x.hp > 0 and x.hp < max_hp(x) * 0.4) or full else -1
		"mend_burst", "cleanse_heal", "mend_shield_hybrid", "shield_lowest", "team_shield_burst", "shield_wall_front":
			var ailing: bool = not (state.get("hero_burn", {}) as Dictionary).is_empty() or not (state.get("hero_poison", {}) as Dictionary).is_empty() or not (state.get("_weakened", {}) as Dictionary).is_empty()
			return 0 if hurt or (eff == "cleanse_heal" and ailing) or full else -1
		"trap", "riposte", "taunt_ward", "undying", "evasion_round", "dodge_surge", "wipe_guard_surge":
			return 0 if danger or full else -1
		"stun_strike", "freeze_target":
			for mi in monsters.size():
				if float(monsters[mi]["hp"]) > 0 and (monsters[mi].get("_winding", false) or monsters[mi].get("_charged", false)):
					return mi
			return toughest
		"mark_target", "armor_break":
			return toughest
		"execute_threshold":
			return weakest if float(monsters[weakest]["hp"]) <= float(monsters[weakest]["max_hp"]) * 0.35 or full else -1
	return weakest


## What monster `i` is about to do this round, for the combat screen and the
## auto-player: {"kind", "target" (Hero or null), "dmg", "heavy", ...} or {}
## if it's down or has already acted. Kinds: attack, windup (charging),
## heavy (the blow), sweep ("targets": every hero), snipe, curse, ward, mend,
## roar, stunned. Heavy = a quarter of the target's max HP or more.
func monster_intent(state: Dictionary, i: int) -> Dictionary:
	var m: Dictionary = state["monsters"][i]
	if float(m["hp"]) <= 0:
		return {}
	# A monster that has already acted this round has nothing left to show
	# (and Guard can't change a hit that already landed), except a wound-up
	# blow: it keeps its warning until it lands next round (the target is
	# only picked then).
	var order: Array = state.get("turn_order", [])
	for k in min(int(state.get("turn_idx", 0)), order.size()):
		if str(order[k]["type"]) == "monster" and int(order[k]["id"]) == i:
			return {"kind": "windup", "target": null, "dmg": 0, "heavy": false, "guarded": false, "charging": true} if m.get("_charged", false) else {}
	if state.get("_m_stunned", {}).has(i):
		return {"kind": "stunned", "target": null, "dmg": 0, "heavy": false}
	var it: Dictionary = _intent_of(state, i)
	var kind := str(it.get("kind", "attack"))
	var round_num := int(state.get("round_num", 0))
	if kind in ["ward", "mend", "roar"]:
		return {"kind": kind, "target": null, "dmg": 0, "heavy": false}
	if kind in ["sweep", "harvest", "drown", "immolate", "sunder"]:
		var living: Array = (state["party"] as Array).filter(func(h): return h.hp > 0)
		if kind == "sunder":
			living = living.filter(func(h): return h.formation != "back")
		var mult: float = {"sweep": GameData.SWEEP_MULT, "harvest": GameData.HARVEST_MULT, "drown": GameData.DROWN_MULT, "immolate": GameData.IMMOLATE_MULT, "sunder": GameData.SUNDER_MULT}[kind]
		return {"kind": kind, "target": null, "targets": living, "dmg": int(_monster_hit(m, round_num) * mult), "heavy": kind == "sunder"}
	var t := _find_party_hero(state["party"], str(it.get("target", "")))
	if t == null or t.hp <= 0:
		return {}
	if kind in ["curse", "brand"]:
		return {"kind": kind, "target": t, "dmg": 0, "heavy": false}
	if m.get("_winding", false):
		return {"kind": "windup", "target": t, "dmg": 0, "heavy": false, "guarded": false, "charging": true}
	var taunter := _find_party_hero(state["party"], str(state.get("_taunt", "")))
	if taunter and taunter.hp > 0:
		t = taunter
	var dmg := _monster_hit(m, round_num)
	var blow: bool = m.get("_charged", false)
	if blow:
		dmg *= GameData.HEAVY_BLOW_MULT
	if kind == "snipe":
		dmg *= GameData.SNIPE_MULT
	if t == taunter:
		dmg *= 1.0 - float(state.get("_taunt_cut", 0.0))
	# A guarded target shows the hit landing on its guard.
	var guard := guard_of(state, t)
	if guard:
		t = guard
		dmg *= GUARD_DAMAGE_MULT
	return {"kind": "heavy" if blow else kind, "target": t, "dmg": int(dmg), "heavy": blow or dmg >= float(max_hp(t)) * 0.25, "guarded": guard != null, "heavy_blow": blow}


## A monster's rolled intent for this round: {"kind", "target": hero id}.
func _intent_of(state: Dictionary, i: int) -> Dictionary:
	var it = state.get("intents", {}).get(i, {})
	return it if it is Dictionary else {"kind": "attack", "target": str(it)}


const GUARD_DAMAGE_MULT := 0.75


## Stuns monster `i` for its next `actions` actions, unless a stun already
## cost it an action this round or last: a foe can't be stun-locked round
## after round (a front row of warriors used to keep a boss's adds frozen).
## Returns whether the stun took; logs the shake-off when it didn't.
func stun_monster(state: Dictionary, i: int, actions: int) -> bool:
	var rn := int(state.get("round_num", 0))
	var last: Dictionary = state.get_or_add("_m_stun_round", {})
	if int(last.get(i, -99)) >= rn - 1:
		(state["log"] as Array).append(tr("%s shakes off the stun.") % tr(str(state["monsters"][i]["name"])))
		return false
	state.get_or_add("_m_stunned", {})[i] = actions
	last[i] = rn + actions - 1
	return true


## The biggest hit still coming at each living hero this round, by hero id
## (from the monsters' intents; sweeps count on everyone they reach).
func incoming_hits(state: Dictionary) -> Dictionary:
	var out := {}
	for mi in (state["monsters"] as Array).size():
		var it := monster_intent(state, mi)
		if it.is_empty():
			continue
		var targets: Array = it.get("targets", [it["target"]] if it.get("target") != null else [])
		for t in targets:
			out[t.id] = maxi(int(out.get(t.id, 0)), int(it.get("dmg", 0)))
	return out


## The living hero a hit this round would knock out, or null (Auto stops for it).
func hero_about_to_fall(state: Dictionary) -> Hero:
	var hits := incoming_hits(state)
	for h in state["party"]:
		if h.hp > 0 and int(hits.get(h.id, 0)) >= h.hp:
			return h
	return null


## The living hero guarding `target` this round, or null.
func guard_of(state: Dictionary, target: Hero) -> Hero:
	var gid: String = str(state.get("_guarding", {}).get(target.id, ""))
	if gid == "":
		return null
	var g := _find_party_hero(state["party"], gid)
	return g if g and g.hp > 0 and g != target else null


func _find_party_hero(party: Array[Hero], hero_id: String) -> Hero:
	for h in party:
		if h.id == hero_id:
			return h
	return null


## Living heroes + living monsters, sorted by Combat.spd_of()/monster "spd"
## descending (a small random jitter breaks exact ties so they don't always
## resolve in the same order) — this round's turn sequence.
func _compute_turn_order(state: Dictionary) -> Array:
	var entries: Array = []
	var chilled: Dictionary = state.get("_chilled", {})
	for h in state["party"]:
		if h.hp > 0:
			entries.append({"type": "hero", "id": h.id, "_spd": (0.0 if _tw(h, "bulwark") and _pa(h) == "shieldwall" else spd_of(h)) * (0.5 if chilled.has(h.id) else 1.0) + randf() * 0.01})
	var monsters: Array = state["monsters"]
	for i in monsters.size():
		if float(monsters[i]["hp"]) > 0:
			var mspd := float(monsters[i].get("spd", 10)) * (1.0 - float(state.get("_res_frost", 0.0))) * (0.5 if int(monsters[i].get("_slow", 0)) > 0 else 1.0)
			if int(monsters[i].get("_snared", 0)) > 0:
				mspd = 0.0   # snared (Trapper): acts last
			entries.append({"type": "monster", "id": i, "_spd": mspd + randf() * 0.01})
			if (monsters[i].get("affixes", []) as Array).has("hasted"):
				entries.append({"type": "monster", "id": i, "_spd": float(monsters[i].get("spd", 10)) * 0.4 + randf() * 0.01})
	entries.sort_custom(func(a, b): return float(a["_spd"]) > float(b["_spd"]))
	if (int(state.get("_waver", 0)) > 0 or state.get("_foes_first", false)) and int(state.get("round_num", 0)) == 1:
		# Low Resolve (0.64), or too little Momentum on the road from Rank S (0.69): every foe acts before every hero in round 1.
		var foes_first := entries.filter(func(e): return e["type"] == "monster")
		foes_first.append_array(entries.filter(func(e): return e["type"] == "hero"))
		return foes_first
	return entries


## Everything that happens once at the start of a round, before any actor's
## turn: round_num/attack_mult/escalate_mult (cached on state for the whole
## round — an ability that raises state["escalate"] mid-round only takes
## effect starting next round, same timing the old batched resolve_round
## had), the Legendary relic round-wide rolls, ability cooldown ticks, a
## fresh turn order, and defaulting any dead-target pending actions to a
## living monster.
func _start_round(state: Dictionary) -> void:
	var log: Array[String] = state["log"]
	var party: Array[Hero] = state["party"]
	var monsters: Array = state["monsters"]
	var living: Array[Hero] = []
	living.assign(party.filter(func(h): return h.hp > 0))

	state["round_num"] = int(state["round_num"]) + 1
	var round_num: int = state["round_num"]
	var attack_mult: float = (1.0 + float(state["first_round_bonus"]) if round_num == 1 else 1.0) * (1.0 + float(state["escalate"]) * (round_num - 1))
	var escalate_mult: float = 1.0 + float(state["escalate"]) * (round_num - 1)

	if party_has_unique_relic("gamblers_coin"):
		if randf() < 0.5:
			attack_mult *= 2.0
			log.append(tr("The Gambler's Gold shines bright — damage is doubled this round!"))
		else:
			attack_mult *= 0.5
			log.append(tr("The Gambler's Gold shows its dark face — damage is halved this round."))
	if party_has_unique_relic("ashes_of_the_fallen"):
		var desperation_cap := 0.30
		if party_has_unique_relic("twin_embers"):
			desperation_cap *= 2.0
		var total_max := 0.0
		var total_missing := 0.0
		for h3 in living:
			total_max += max_hp(h3)
			total_missing += max_hp(h3) - h3.hp
		if total_max > 0.0:
			attack_mult *= 1.0 + desperation_cap * (total_missing / total_max)
	if party_has_unique_relic("bloodpact"):
		attack_mult *= 1.35
	if party_has_unique_relic("prism_heart"):
		var elems := {}
		for h3 in living:
			if h3.type != "":
				elems[h3.type] = true
		attack_mult *= 1.0 + 0.05 * elems.size()
	if party_has_unique_relic("sable_standard"):
		var roles_seen := {}
		for h3 in living:
			roles_seen[h3.cls_id] = true
		if roles_seen.size() == 1:
			attack_mult *= 1.25

	if int(state.get("_waver", 0)) >= 2:
		attack_mult *= 1.0 - GameData.RESOLVE_BROKEN_DMG
	state["_attack_mult"] = attack_mult
	state["_escalate_mult"] = escalate_mult
	state["_defending"] = {}
	state["_guarding"] = {}   # guarded hero id -> guard's id (see "guard" below)
	state["_extra_turned"] = {}
	state["_taunt"] = ""
	state["_smoke"] = 0.0
	state["_undying"] = {}
	var branded: Dictionary = state.get("_branded", {})
	for bid in branded.keys().duplicate():
		branded[bid] = int(branded[bid]) - 1
		if int(branded[bid]) <= 0:
			branded.erase(bid)
	state["_branded"] = branded
	var weakened: Dictionary = state.get("_weakened", {})
	for wid in weakened.keys().duplicate():
		weakened[wid] = int(weakened[wid]) - 1
		if int(weakened[wid]) <= 0:
			weakened.erase(wid)
	state["_weakened"] = weakened

	var pending: Dictionary = state["pending_actions"]
	for h in living:
		var prev: Dictionary = pending.get(h.id, {})
		var target_idx: int = int(prev.get("target", 0))
		if target_idx < 0 or target_idx >= monsters.size() or float(monsters[target_idx]["hp"]) <= 0:
			target_idx = max(0, _first_living_monster_idx(monsters))
		pending[h.id] = {"action": str(prev.get("action", "attack")), "target": target_idx}

	state["turn_order"] = _compute_turn_order(state)
	var chilled: Dictionary = state.get("_chilled", {})
	for hid in chilled.keys().duplicate():
		chilled[hid] = int(chilled[hid]) - 1
		if int(chilled[hid]) <= 0:
			chilled.erase(hid)
	state["_chilled"] = chilled
	for mw in monsters:
		if float(mw["hp"]) <= 0 or mw.get("_charged", false):
			continue
		if int(mw.get("_windup_cd", 0)) > 0:
			mw["_windup_cd"] = int(mw["_windup_cd"]) - 1
			continue
		if (mw.get("affixes", []) as Array).has("hasted"):
			continue
		# The guided first fight teaches attacks and skills before its one wind-up (round 2).
		if GameState.run.get("training", false) and int(state["round_num"]) < 2 and not GameState.hints_seen.has("tut_windup"):
			continue
		var wtier := str(mw.get("tier", "combat"))
		if wtier == "combat" and GameData.WINDUP_BRUTES.has(str(mw["name"])):
			wtier = "brute"
		if randf() < float(GameData.WINDUP_CHANCE.get(wtier, 0.0)) + float(state.get("diff", {}).get("windup_bonus", 0.0)) + float(mw.get("windup_bonus", 0.0)):
			mw["_winding"] = true
	# Fight stakes (0.68): from Rank C every ordinary fight has a wind-up to answer by round 2.
	if GameState.wounds_on() and str(state.get("kind", "")) == "combat" and int(state["round_num"]) <= GameData.WOUND_SURE_ROUND and not state.get("_sure_windup", false):
		if monsters.any(func(x): return x.get("_winding", false) or x.get("_charged", false)):
			state["_sure_windup"] = true
		elif int(state["round_num"]) == GameData.WOUND_SURE_ROUND or randf() < 0.5:
			for mw in monsters:
				if float(mw["hp"]) > 0 and not mw.get("_charged", false) and not (mw.get("affixes", []) as Array).has("hasted"):
					mw["_winding"] = true
					state["_sure_windup"] = true
					break
	# The guided first fight (training rift) shows one wind-up in round 2.
	if GameState.run.get("training", false) and int(state["round_num"]) == 2 and not GameState.hints_seen.has("tut_windup"):
		for mw in monsters:
			if float(mw["hp"]) > 0 and not mw.get("_charged", false):
				mw["_winding"] = true
				break
	if str(state.get("feat", {}).get("id", "")) == "break" and int(state["round_num"]) == 2:   # the Feat's wind-up
		for mw in monsters:
			if float(mw["hp"]) > 0 and not mw.get("_charged", false) and not (mw.get("affixes", []) as Array).has("hasted"):
				mw["_winding"] = true
				break
	if int(state["round_num"]) % 3 == 0 and not living.is_empty():
		_fire("round_third", state, living[0])
	var intents := {}
	if not living.is_empty():
		for mi in monsters.size():
			if float(monsters[mi]["hp"]) > 0:
				intents[mi] = _roll_intent(state, mi, living)
	state["intents"] = intents
	state["turn_idx"] = 0
	_pp_round_start(state)


## What monster `mi` will do this round: attack (or wind up / land a heavy
## blow, rolled above), or now and then a move from its kit, never two
## rounds running. {"kind", "target": hero id or ""}.
func _roll_intent(state: Dictionary, mi: int, living: Array[Hero]) -> Dictionary:
	var m: Dictionary = state["monsters"][mi]
	if not m.has("kit"):
		m["kit"] = monster_kit(m)
	var round_num := int(state["round_num"])
	var kind := "attack"
	if not m.get("_winding", false) and not m.get("_charged", false) and int(m.get("_special_round", -9)) < round_num - 1 and not GameState.run.get("training", false):
		var kit: Array = m["kit"]
		if not kit.is_empty():
			var pick := str(kit[randi() % kit.size()])
			var chance := GameData.BOSS_SPECIAL_CHANCE if str(m.get("tier", "")) == "boss" else GameData.INTENT_SPECIAL_CHANCE
			var monsters: Array = state["monsters"]
			match pick:
				"mend":
					chance = 0.6 if monsters.any(func(o): return float(o["hp"]) > 0 and float(o["hp"]) < float(o["max_hp"]) * 0.7) else 0.0
				"roar":
					chance = chance if int(m.get("_roars", 0)) < 2 else 0.0
			if randf() < chance:
				kind = pick
				m["_special_round"] = round_num
	var target := ""
	match kind:
		"attack", "curse", "brand":
			target = weighted_formation_target(living).id
		"snipe":
			var back: Array = living.filter(func(h): return h.formation == "back")
			var pool: Array = back if not back.is_empty() else living
			var best: Hero = pool[0]
			for h in pool:
				if float(h.hp) / max_hp(h) < float(best.hp) / max_hp(best):
					best = h
			target = best.id
	return {"kind": kind, "target": target}


## One hero hit on monster `ti` at `mult` of their share of the party's
## damage (the basic attack is mult 1). Armor and wards soak it and reflect
## bites back unless `pierce`. Returns the damage dealt.
## A hero's hit on foe `ti` before any on-hit effects, armor or wards.
func _hit_base(state: Dictionary, h: Hero, ti: int, mult: float) -> float:
	var monsters: Array = state["monsters"]
	var formation_mult := 1.0 if bool(monsters[ti].get("is_main", true)) else 0.75
	var weaken := 1.0 - GameData.CURSE_WEAKEN if state.get("_weakened", {}).has(h.id) else 1.0
	var marked := 1.0 + float(monsters[ti].get("_marked", 0.0))
	match str(state.get("_twist", "")):
		"executioner":
			if float(monsters[ti]["hp"]) < float(monsters[ti]["max_hp"]) * GameData.TWIST_EXECUTE_BELOW:
				mult *= 1.0 + GameData.TWIST_EXECUTE
		"opener":
			if not state.get("_opened", {}).has(h.id):
				mult *= 1.0 + GameData.TWIST_OPENER
	return dmg_of(h) / float(state["raw_sum"]) * float(state["team_dmg_base"]) * float(state.get("_attack_mult", 1.0)) * formation_mult * mult * weaken * marked * (1.0 + hero_cond_stat(h, "dmg_pct", state, {"target": monsters[ti]})) * _pp_dmg_mult(state, h, ti)


## Whether a plain Attack from `h` would bring foe `ti` down, before chance
## (crits and other on-hit effects can only add to it). For the Momentum
## preview: a kill earns +1 on top of the attack's own.
func attack_would_kill(state: Dictionary, h: Hero, ti: int) -> bool:
	var monsters: Array = state["monsters"]
	if ti < 0 or ti >= monsters.size() or float(monsters[ti]["hp"]) <= 0.0:
		return false
	return preview_attack(state, h, ti) >= int(round(float(monsters[ti]["hp"])))


## The damage a plain Attack from `h` would deal foe `ti` after armor and
## wards, before chance (0.68: the hover preview). Pure.
func preview_attack(state: Dictionary, h: Hero, ti: int) -> int:
	var reach := GameData.BACK_ROW_MELEE_MULT if h.formation == "back" and GameData.MELEE_ROLES.has(h.cls_id) else 1.0
	return preview_hit(state, h, ti, reach, false)


## A hit at `mult` from `h` on foe `ti`, after armor and wards unless `pierce`. Pure.
func preview_hit(state: Dictionary, h: Hero, ti: int, mult: float, pierce: bool) -> int:
	var monsters: Array = state["monsters"]
	if ti < 0 or ti >= monsters.size() or float(monsters[ti]["hp"]) <= 0.0:
		return 0
	var dealt := _hit_base(state, h, ti, mult)
	if not pierce and not _pp_pierce(state, h, ti):
		dealt -= dealt * float(monsters[ti].get("armor", 0.0))
		dealt -= float(state["monster_shields"].get(ti, 0.0))
	return maxi(0, int(round(dealt)))


## The damage a foe-targeted role skill would deal `ti` (0 for skills that
## don't strike one foe for their value). Pure; Techniques aren't previewed.
func preview_skill(state: Dictionary, h: Hero, act_id: String, ti: int) -> int:
	if not act_id.begins_with("skill:"):
		return 0
	var sk := GameData.find_skill_def(act_id.substr(6))
	var eff := str(sk.get("effect", ""))
	if not eff in ["bash", "pierce", "strike", "backstab"] or ti < 0 or ti >= (state["monsters"] as Array).size():
		return 0
	var val := float(sk.get("value", 1.0))
	if eff == "backstab":
		var m: Dictionary = state["monsters"][ti]
		if m.get("_winding", false) or m.get("_charged", false) or float(m["hp"]) < float(m["max_hp"]) * 0.5:
			val += 1.0
	return preview_hit(state, h, ti, val, eff == "pierce")


func _hero_hit(state: Dictionary, h: Hero, ti: int, mult: float, pierce: bool = false) -> float:
	var log: Array[String] = state["log"]
	var monsters: Array = state["monsters"]
	var was_alive := float(monsters[ti]["hp"]) > 0.0
	pierce = pierce or _pp_pierce(state, h, ti)
	if state.get("_res_frost_first", false) and not state.get("_res_frost_used", false):
		state["_res_frost_used"] = true
		monsters[ti]["_slow"] = 2   # Resonance: Frost x3 chills the fight's first foe hit
	var hit := {"target": monsters[ti]}
	hit["dealt"] = _hit_base(state, h, ti, mult)
	_fire("before_hit", state, h, hit)
	var dealt: float = hit["dealt"]
	var armor := float(monsters[ti].get("armor", 0.0))
	if armor > 0.0 and dealt > 0.0 and not pierce:
		var blocked: float = dealt * armor
		dealt -= blocked
		monsters[ti]["armor"] = maxf(0.0, armor - GameData.ARMOR_SUNDER)
		log.append(tr("%s's armor turns aside %d.") % [tr(str(monsters[ti]["name"])), int(round(blocked))])
	var m_shields: Dictionary = state["monster_shields"]
	if dealt > 0.0 and float(m_shields.get(ti, 0.0)) > 0.0 and not pierce:
		var m_have: float = float(m_shields[ti])
		var m_absorbed: float = min(m_have, dealt)
		m_shields[ti] = m_have - m_absorbed
		dealt -= m_absorbed
		log.append(tr("%s's ward absorbs %d damage.") % [tr(str(monsters[ti]["name"])), int(round(m_absorbed))])
	monsters[ti]["hp"] = float(monsters[ti]["hp"]) - round(dealt)
	log.append(tr("%s strikes %s for %d.") % [tr(str(h.name)), tr(str(monsters[ti]["name"])), round(dealt)])
	var target_ability: Dictionary = monsters[ti].get("ability", {})
	if target_ability.get("kind") == "reflect" and dealt > 0.0 and not pierce:
		var reflected: int = max(1, int(round(dealt * float(target_ability["value"]))))
		h.hp = max(0, h.hp - reflected)
		log.append(tr("%s's surface reflects %d damage back at %s.") % [tr(str(monsters[ti]["name"])), reflected, tr(str(h.name))])
	hit["dealt"] = dealt
	var steal := float(state.get("_lifesteal", 0.0))
	if steal > 0.0 and dealt > 0.0 and h.hp > 0:
		h.hp = mini(max_hp(h), h.hp + int(round(dealt * steal)))
	_fire("after_hit", state, h, hit)
	_pp_after_hit(state, h, ti, dealt, was_alive)
	return dealt


## A role skill (GameData.ROLE_SKILLS) — Momentum already paid.
func _use_role_skill(state: Dictionary, h: Hero, sk: Dictionary, target_idx: int) -> void:
	var log: Array[String] = state["log"]
	var party: Array[Hero] = state["party"]
	var monsters: Array = state["monsters"]
	var val := float(sk["value"])
	if not sk.get("technique", false):   # a Technique logs its own line
		log.append(tr("%s uses %s!") % [tr(str(h.name)), tr(str(sk["name"]))])
	_tally(state, "skills")
	if target_idx < 0 or target_idx >= monsters.size() or float(monsters[target_idx]["hp"]) <= 0:
		target_idx = _first_living_monster_idx(monsters)
	var living: Array[Hero] = []
	living.assign(party.filter(func(x): return x.hp > 0))
	var arch := hero_main_arch(h)
	state["_twist"] = arch
	_role_skill_effect(state, h, sk, target_idx, val, living)
	state["_twist"] = ""
	match arch:
		"guardian":
			if not living.is_empty():
				var low: Hero = living[0]
				for x in living:
					if float(x.hp) / max_hp(x) < float(low.hp) / max_hp(low):
						low = x
				var shields: Dictionary = state["hero_shields"]
				shields[low.id] = float(shields.get(low.id, 0.0)) + max_hp(low) * GameData.TWIST_WARD
		"sustain":
			h.hp = mini(max_hp(h), h.hp + int(round(max_hp(h) * GameData.TWIST_HEAL)))
		"evasion":
			state.get_or_add("_evade_next", {})[h.id] = true
		"attrition":
			if target_idx >= 0 and target_idx < monsters.size() and float(monsters[target_idx]["hp"]) > 0 and str(sk["target"]) == "foe":
				_burn_foe(state, target_idx, dmg_of(h) / float(state["raw_sum"]) * float(state["team_dmg_base"]) * GameData.TWIST_BURN, 2)
		"opener":
			state.get_or_add("_opened", {})[h.id] = true


## A foe burns for `per_round` damage at each round's end for `rounds` rounds
## (the stronger burn wins).
func _burn_foe(state: Dictionary, i: int, per_round: float, rounds: int) -> void:
	var burns: Dictionary = state.get_or_add("_m_burn", {})
	var old: Dictionary = burns.get(i, {})
	if old.is_empty() or float(old["dmg"]) * int(old["rounds"]) < per_round * rounds:
		burns[i] = {"dmg": per_round, "rounds": rounds}


func _role_skill_effect(state: Dictionary, h: Hero, sk: Dictionary, target_idx: int, val: float, living: Array[Hero]) -> void:
	var log: Array[String] = state["log"]
	var monsters: Array = state["monsters"]
	if str(sk["effect"]).begins_with("tech:"):   # a Path's Technique (0.62)
		_pp_technique(state, h, str(sk["effect"]).substr(5), target_idx)
		return
	match str(sk["effect"]):
		"bash":
			if target_idx >= 0:
				_hero_hit(state, h, target_idx, val)
				var m: Dictionary = monsters[target_idx]
				if float(m["hp"]) > 0:
					var broke: bool = m.get("_winding", false) or m.get("_charged", false)
					if broke:
						_tally(state, "broke_windup")
					m["_winding"] = false
					m["_charged"] = false
					if str(m.get("tier", "")) != "boss":
						if stun_monster(state, target_idx, 1):
							log.append(tr("%s is stunned!") % tr(str(m["name"])))
					elif broke:
						log.append(tr("%s's wind-up is broken!") % tr(str(m["name"])))
					else:
						log.append(tr("%s shrugs off the stun: a boss only loses a wind-up.") % tr(str(m["name"])))
		"taunt":
			state["_taunt"] = h.id
			state["_taunt_cut"] = val
			log.append(tr("Every foe turns on %s.") % tr(str(h.name)))
		"pierce", "strike":
			if target_idx >= 0:
				_hero_hit(state, h, target_idx, val, str(sk["effect"]) == "pierce")
		"backstab":
			if target_idx >= 0:
				var m2: Dictionary = monsters[target_idx]
				var exposed: bool = m2.get("_winding", false) or m2.get("_charged", false) or float(m2["hp"]) < float(m2["max_hp"]) * 0.5
				_hero_hit(state, h, target_idx, val + (1.0 if exposed else 0.0))
		"volley", "nova":
			for i in monsters.size():
				if float(monsters[i]["hp"]) > 0:
					_hero_hit(state, h, i, val)
					if str(sk["effect"]) == "nova" and (monsters[i].get("_winding", false) or monsters[i].get("_charged", false)):
						_tally(state, "broke_windup")
						monsters[i]["_winding"] = false
						monsters[i]["_charged"] = false
						log.append(tr("%s's wind-up is broken!") % tr(str(monsters[i]["name"])))
		"heal":
			if not living.is_empty():
				var low: Hero = living[0]
				for x in living:
					if float(x.hp) / max_hp(x) < float(low.hp) / max_hp(low):
						low = x
				var healed: int = _pp_heal(state, low, int(round(max_hp(low) * val)))
				log.append(tr("%s is healed for %d.") % [tr(str(low.name)), healed])
		"sanctuary":
			var shields: Dictionary = state["hero_shields"]
			for x in living:
				shields[x.id] = float(shields.get(x.id, 0.0)) + max_hp(x) * val
				for key in ["hero_poison", "hero_burn", "_chilled", "_stunned", "_weakened", "_branded"]:
					state.get(key, {}).erase(x.id)
			log.append(tr("A sanctuary shelters the party."))
		"smoke":
			state["_smoke"] = float(state.get("_smoke", 0.0)) + val
			log.append(tr("Smoke fills the field — the party is hard to hit."))


## One hero's pending action (attack/defend/ability) from state["pending_actions"]
## — the per-hero body of the old batched hero phase, unchanged math, just
## scoped to a single hero's turn instead of looping the whole living party.
func _resolve_hero_action(state: Dictionary, h: Hero) -> void:
	var log: Array[String] = state["log"]
	var party: Array[Hero] = state["party"]
	var monsters: Array = state["monsters"]
	var pending: Dictionary = state["pending_actions"]
	var attack_mult: float = float(state["_attack_mult"])
	var escalate_mult: float = float(state["_escalate_mult"])
	var raw_sum: float = state["raw_sum"]

	var monsters_hp_before: Array[float] = []
	for m in monsters:
		monsters_hp_before.append(float(m["hp"]))

	var act: Dictionary = pending.get(h.id, {"action": "attack", "target": 0})
	var action: String = str(act.get("action", "attack"))
	# A skill the hero can't pay for (or from the wrong row) falls back to an attack.
	if (action == "ability" or action.begins_with("skill:")) and action_block(state, h, action) != "":
		action = "attack"
	if action == "attack":
		var target_idx: int = int(act.get("target", 0))
		if target_idx < 0 or target_idx >= monsters.size() or float(monsters[target_idx]["hp"]) <= 0:
			target_idx = _first_living_monster_idx(monsters)
		if target_idx >= 0:
			var reach := GameData.BACK_ROW_MELEE_MULT if h.formation == "back" and GameData.MELEE_ROLES.has(h.cls_id) else 1.0
			_hero_hit(state, h, target_idx, reach)
			var pp := _pp(state, h)
			if int(pp.get("sw_double", 0)) > 0:   # Second Wind (Scrapper): attacks hit twice
				pp["sw_double"] = int(pp["sw_double"]) - 1
				if float(monsters[target_idx]["hp"]) > 0:
					_hero_hit(state, h, target_idx, reach)
			gain_momentum(state, 1)
	elif action.begins_with("skill:"):
		gain_momentum(state, -int(action_cost(action)[0]))
		_use_role_skill(state, h, GameData.find_skill_def(action.substr(6)), int(act.get("target", 0)))
	elif action == "defend":
		state["_defending"][h.id] = true
	elif action == "swap":
		h.formation = "back" if h.formation != "back" else "front"
		log.append(tr("%s moves to the %s row.") % [tr(str(h.name)), tr(str(h.formation))])
	elif action.begins_with("tonic") and GameState.tonic_count(_tonic_id(action)) > 0:
		var tid := _tonic_id(action)
		var patient := _find_party_hero(party, str(act.get("ally", "")))
		if patient == null or patient.hp <= 0:
			patient = h
		GameState.tonics[tid] = GameState.tonic_count(tid) - 1
		match tid:
			"healing":
				for key in ["hero_poison", "hero_burn", "_chilled", "_stunned", "_weakened", "_branded"]:
					state.get(key, {}).erase(patient.id)
				var healed: int = min(max_hp(patient) - patient.hp, int(round(max_hp(patient) * GameData.TONIC_HEAL_PCT)))
				patient.hp += healed
				log.append(tr("%s gives %s a Healing Tonic: +%d HP.") % [tr(str(h.name)), tr(str(patient.name)), healed])
			"iron":
				var ward := max_hp(patient) * GameData.TONIC_WARD_PCT
				var shields: Dictionary = state["hero_shields"]
				shields[patient.id] = float(shields.get(patient.id, 0.0)) + ward
				log.append(tr("%s gives %s an Iron Tonic: a %d ward.") % [tr(str(h.name)), tr(str(patient.name)), int(round(ward))])
			"focus":
				gain_momentum(state, GameData.TONIC_FOCUS)
				log.append(tr("%s drinks a Focus Tonic: +%d Momentum.") % [tr(str(h.name)), GameData.TONIC_FOCUS])
	elif action == "guard":
		# Until the round ends, attacks aimed at the ally hit this hero
		# instead, 25% weaker (see _resolve_monster_action).
		var ally := _find_party_hero(party, str(act.get("ally", "")))
		if ally and ally != h and ally.hp > 0:
			var guards: Dictionary = state.get("_guarding", {})
			guards[ally.id] = h.id
			state["_guarding"] = guards
			log.append(tr("%s moves to guard %s.") % [tr(str(h.name)), tr(str(ally.name))])
	elif action == "ability" or (action == "call" and GameState.champion_call_ready(h)):
		_tally(state, "abilities")
		var team_dmg_base: float = float(state["team_dmg_base"])
		var ab: Dictionary
		if action == "call":
			ab = GameState.champion_call(h)
			GameState.run["champion_calls"] = int(GameState.run.get("champion_calls", 0)) + 1
			GameState.run["champion_call_used"] = true
		else:
			gain_momentum(state, -(GameData.ABILITY_MOMENTUM_COST - (1 if state.get("_res_arcane", false) else 0)))
			ab = GameData.SUBCLASS_ABILITIES[h.pool_id]
		var eff: String = ab["effect"]
		var val: float = float(ab["value"])
		# Focus: ability power strengthens the effect — a damage-cutting
		# debuff cuts deeper, a damage multiplier grows, the rest scale up.
		var ap := hero_skill_total(h, "ability_power")
		if ap != 0.0:
			match eff:
				"monster_dmg_mult", "debuff_lowest":
					val = maxf(0.2, 1.0 - (1.0 - val) * (1.0 + ap))
				"team_dmg_mult":
					val = 1.0 + (val - 1.0) * (1.0 + ap)
				_:
					val *= 1.0 + ap
		if action == "call":
			log.append(tr("%s calls on %s: %s!") % [tr(str(h.name)), GameData.champion_full_name(GameState.run_overseer()), tr(str(ab["name"]))])
		else:
			log.append(tr("%s uses %s%s!") % [tr(str(h.name)), tr(str(ab["name"])), tr(str(" (Awakened)" if h.ability_awakened else ""))])
		var living: Array[Hero] = []
		living.assign(party.filter(func(hh): return hh.hp > 0))
		match eff:
			"mend_burst":
				for h2 in party:
					if h2.hp > 0:
						_pp_heal(state, h2, int(round(max_hp(h2) * val)))
				log.append(tr("The party mends."))
			"monster_dmg_mult":
				for m in monsters:
					m["dmg"] = float(m["dmg"]) * val
				log.append(tr("The enemies' strength is sapped."))
			"team_dmg_mult":
				state["team_dmg_base"] = team_dmg_base * val
			"burst_lowest":
				var idx := _lowest_hp_living_monster_idx(monsters)
				if idx >= 0:
					var burst: float = team_dmg_base * escalate_mult * val
					monsters[idx]["hp"] = float(monsters[idx]["hp"]) - round(burst)
					log.append(tr("A burst lands on %s for %d!") % [tr(str(monsters[idx]["name"])), round(burst)])
			"cleave_burst":
				for m in monsters:
					if float(m["hp"]) > 0:
						var dealt2: float = team_dmg_base * escalate_mult * val
						m["hp"] = float(m["hp"]) - round(dealt2)
				log.append(tr("A wave of damage sweeps every foe."))
			"execute_burst":
				var idx2 := _lowest_hp_living_monster_idx(monsters)
				if idx2 >= 0:
					var missing_frac: float = 1.0 - float(monsters[idx2]["hp"]) / float(monsters[idx2]["max_hp"])
					var dealt3: float = team_dmg_base * val * (1.0 + missing_frac)
					monsters[idx2]["hp"] = float(monsters[idx2]["hp"]) - round(dealt3)
					log.append(tr("A finishing blow strikes %s for %d!") % [tr(str(monsters[idx2]["name"])), round(dealt3)])
			"shield_lowest":
				var shielded := _shield_lowest(state, val)
				if not shielded.is_empty():
					log.append(tr("%s is shielded for %d.") % [tr(str(shielded[0].name)), int(round(shielded[1]))])
			"reset_cooldowns":
				gain_momentum(state, 7)
				log.append(tr("+7 Momentum."))
			"dodge_surge":
				state["dodge"] = min(GameData.DODGE_CAP, float(state["dodge"]) + val)
				log.append(tr("The party moves lighter on its feet."))
			"escalate_surge":
				state["escalate"] = float(state["escalate"]) + val
				log.append(tr("Every attack counts for more now."))
			"counter_surge":
				state["counter"] = min(0.6, float(state["counter"]) + val)
				log.append(tr("The party stands ready to strike back."))
			"wipe_guard_surge":
				state["wipe_guard"] = min(0.9, float(state["wipe_guard"]) + val)
				log.append(tr("The party braces against disaster."))
			"self_sac_burst":
				var idx3 := _lowest_hp_living_monster_idx(monsters)
				if idx3 >= 0:
					var self_cost: int = max(1, int(round(max_hp(h) * 0.15)))
					h.hp = max(1, h.hp - self_cost)
					var burst2: float = team_dmg_base * escalate_mult * val
					monsters[idx3]["hp"] = float(monsters[idx3]["hp"]) - round(burst2)
					log.append(tr("%s sacrifices %d HP for a burst on %s for %d!") % [tr(str(h.name)), self_cost, tr(str(monsters[idx3]["name"])), round(burst2)])
			"debuff_lowest":
				var idx4 := _lowest_hp_living_monster_idx(monsters)
				if idx4 >= 0:
					monsters[idx4]["dmg"] = float(monsters[idx4]["dmg"]) * val
					log.append(tr("%s is crippled, dealing far less damage.") % tr(str(monsters[idx4]["name"])))
			"team_shield_burst":
				var shields2: Dictionary = state["hero_shields"]
				for hh3 in living:
					shields2[hh3.id] = float(shields2.get(hh3.id, 0.0)) + max_hp(hh3) * val
				log.append(tr("The whole party is shielded."))
			"execute_all_low":
				for m2 in monsters:
					if float(m2["hp"]) > 0:
						var missing_frac2: float = 1.0 - float(m2["hp"]) / float(m2["max_hp"])
						if missing_frac2 >= 0.5:
							var dealt4: float = team_dmg_base * val * (1.0 + missing_frac2)
							m2["hp"] = float(m2["hp"]) - round(dealt4)
				log.append(tr("Every wounded foe is finished off."))
			"stun_strike", "execute_threshold", "armor_break", "double_strike", "mark_target", "freeze_target":
				var ti := int(act.get("target", 0))
				if ti < 0 or ti >= monsters.size() or float(monsters[ti]["hp"]) <= 0:
					ti = _first_living_monster_idx(monsters)
				if ti >= 0:
					var tm: Dictionary = monsters[ti]
					var boss: bool = str(tm.get("tier", "")) == "boss"
					match eff:
						"stun_strike":
							tm["hp"] = float(tm["hp"]) - round(team_dmg_base * escalate_mult * val)
							if tm.get("_winding", false) or tm.get("_charged", false):
								_tally(state, "broke_windup")
							tm["_winding"] = false
							tm["_charged"] = false
							if boss:
								log.append(tr("%s is staggered — its wind-up breaks!") % tr(str(tm["name"])))
							elif stun_monster(state, ti, 1):
								log.append(tr("%s is stunned!") % tr(str(tm["name"])))
						"freeze_target":
							if tm.get("_winding", false) or tm.get("_charged", false):
								_tally(state, "broke_windup")
							tm["_winding"] = false
							tm["_charged"] = false
							if stun_monster(state, ti, 1 if boss else 2):
								log.append(tr("%s is frozen solid!") % tr(str(tm["name"])))
						"execute_threshold":
							if not boss and float(tm["hp"]) <= float(tm["max_hp"]) * 0.35:
								tm["hp"] = 0.0
								log.append(tr("%s is finished off!") % tr(str(tm["name"])))
							else:
								tm["hp"] = float(tm["hp"]) - round(team_dmg_base * escalate_mult * val)
						"armor_break":
							tm["armor"] = 0.0
							state["monster_shields"].erase(ti)
							tm["_marked"] = float(tm.get("_marked", 0.0)) + 0.15
							tm["hp"] = float(tm["hp"]) - round(team_dmg_base * escalate_mult * val * 0.5)
							log.append(tr("%s's defences shatter.") % tr(str(tm["name"])))
						"mark_target":
							tm["_marked"] = float(tm.get("_marked", 0.0)) + val
							log.append(tr("%s is marked.") % tr(str(tm["name"])))
						"double_strike":
							_hero_hit(state, h, ti, val)
							if float(tm["hp"]) > 0:
								_hero_hit(state, h, ti, val)
			"burn_all":
				for bi in monsters.size():
					if float(monsters[bi]["hp"]) > 0:
						_burn_foe(state, bi, team_dmg_base * val * 0.5, GameData.MONSTER_BURN_ROUNDS)
				log.append(tr("Every foe is set ablaze."))
			"chain_lightning":
				for k in 3:
					var alive_idx: Array = []
					for ci in monsters.size():
						if float(monsters[ci]["hp"]) > 0:
							alive_idx.append(ci)
					if alive_idx.is_empty():
						break
					var ci2: int = alive_idx[randi() % alive_idx.size()]
					monsters[ci2]["hp"] = float(monsters[ci2]["hp"]) - round(team_dmg_base * escalate_mult * val)
				log.append(tr("Lightning leaps between the foes."))
			"ward_break":
				for wi in monsters.size():
					if float(monsters[wi]["hp"]) > 0:
						monsters[wi]["armor"] = 0.0
						monsters[wi]["hp"] = float(monsters[wi]["hp"]) - round(team_dmg_base * escalate_mult * val * 0.5)
				state["monster_shields"] = {}
				log.append(tr("Every ward and plate is torn away."))
			"riposte":
				state.get_or_add("_riposte", {})[h.id] = {"left": 3, "dmg": team_dmg_base * val}
				log.append(tr("%s stands ready to answer every blow.") % tr(str(h.name)))
			"taunt_ward":
				state["_taunt"] = h.id
				state["_taunt_cut"] = 0.3
				var tsh: Dictionary = state["hero_shields"]
				tsh[h.id] = float(tsh.get(h.id, 0.0)) + max_hp(h) * val
				log.append(tr("%s plants their feet — every foe turns on them.") % tr(str(h.name)))
			"undying":
				state.get_or_add("_undying", {})[h.id] = true
				log.append(tr("%s will not fall this round.") % tr(str(h.name)))
			"revive":
				var fallen: Array = party.filter(func(x): return x.hp <= 0)
				var raised: Dictionary = state.get_or_add("_raised", {})   # 0.62.1: one raise a fight, then it heals
				if not fallen.is_empty() and not raised.has(h.id):
					raised[h.id] = true
					var rv: Hero = fallen[0]
					rv.hp = maxi(1, int(round(max_hp(rv) * val)))
					log.append(tr("%s is raised back to their feet!") % tr(str(rv.name)))
				elif not living.is_empty():
					var low2: Hero = living[0]
					for x in living:
						if float(x.hp) / max_hp(x) < float(low2.hp) / max_hp(low2):
							low2 = x
					low2.hp = mini(max_hp(low2), low2.hp + int(round(max_hp(low2) * val)))
					log.append(tr("%s is mended.") % tr(str(low2.name)))
			"cleanse_heal":
				for x in living:
					x.hp = mini(max_hp(x), x.hp + int(round(max_hp(x) * val)))
					for key in ["hero_poison", "hero_burn", "_chilled", "_stunned", "_weakened", "_branded"]:
						state.get(key, {}).erase(x.id)
				log.append(tr("A cleansing light washes over the party."))
			"shield_wall_front":
				var wsh: Dictionary = state["hero_shields"]
				for x in living:
					if x.formation != "back":
						wsh[x.id] = float(wsh.get(x.id, 0.0)) + max_hp(x) * val
				log.append(tr("The front row locks shields."))
			"evasion_round":
				state["_smoke"] = float(state.get("_smoke", 0.0)) + val
				log.append(tr("The party slips out of reach."))
			"trap":
				state["_trap"] = float(state.get("_trap", 0.0)) + team_dmg_base * val
				log.append(tr("A snare is set."))
			"lifesteal_surge":
				state["_lifesteal"] = float(state.get("_lifesteal", 0.0)) + val
				log.append(tr("Every wound the party deals now feeds it."))
			"blood_price":
				h.hp = maxi(1, h.hp - int(round(max_hp(h) * 0.2)))
				gain_momentum(state, 3)
				state["team_dmg_base"] = float(state["team_dmg_base"]) * (1.0 + val)
				log.append(tr("%s pays in blood: +3 Momentum, and the party hits harder.") % tr(str(h.name)))
			"hp_drain_burst":
				var idx5 := _lowest_hp_living_monster_idx(monsters)
				if idx5 >= 0:
					var burst3: float = team_dmg_base * escalate_mult * val
					monsters[idx5]["hp"] = float(monsters[idx5]["hp"]) - round(burst3)
					var drained: int = max(1, int(round(burst3 * 0.4)))
					h.hp = min(max_hp(h), h.hp + drained)
					log.append(tr("%s drains %d from %s, healing %d!") % [tr(str(h.name)), round(burst3), tr(str(monsters[idx5]["name"])), drained])
			"mend_shield_hybrid":
				if not living.is_empty():
					var lowest2: Hero = living[0]
					for hh4 in living:
						if hh4.hp < lowest2.hp:
							lowest2 = hh4
					lowest2.hp = min(max_hp(lowest2), lowest2.hp + int(round(max_hp(lowest2) * val)))
					var shields3: Dictionary = state["hero_shields"]
					var amt2: float = max_hp(lowest2) * val * 0.6
					shields3[lowest2.id] = float(shields3.get(lowest2.id, 0.0)) + amt2
					log.append(tr("%s is mended and shielded.") % tr(str(lowest2.name)))

		# Awakening (GameState.awaken_ability) grants a bucketed rider on top
		# of the primary effect above, keyed by GameData's ABILITY_AWAKENING_BUCKET
		# — see its doc comment for why buckets instead of one flat number or
		# 18 fully bespoke riders.
		if h.ability_awakened:
			var bucket: String = GameData.ABILITY_AWAKENING_BUCKET.get(eff, "buff")
			match bucket:
				"buff":
					gain_momentum(state, GameData.ABILITY_AWAKENING_MOMENTUM)
				"single_dmg":
					for m3 in monsters:
						m3["dmg"] = float(m3["dmg"]) * 0.97
				"aoe_dmg":
					state["dodge"] = min(GameData.DODGE_CAP, float(state["dodge"]) + 0.08)
				"support":
					var shields4: Dictionary = state["hero_shields"]
					shields4[h.id] = float(shields4.get(h.id, 0.0)) + max_hp(h) * 0.15
				"utility":
					state["escalate"] = float(state["escalate"]) + 0.02

	# Checked against just this hero's own action, so on_kill effects (the
	# Lantern's shield included) trigger on any hero's kill regardless of turn
	# order. Fires once per action, however many foes that action dropped.
	var kills := 0
	for i in monsters.size():
		if monsters_hp_before[i] > 0.0 and float(monsters[i]["hp"]) <= 0.0:
			kills += 1
	if kills > 0:
		h.history["kills"] = int(h.history.get("kills", 0)) + kills
		gain_momentum(state, 1)
		_fire("on_kill", state, h)
	# Per-fight tallies for the victory screen (damage dealt, kills).
	var dealt_now := 0.0
	for i in monsters.size():
		dealt_now += maxf(0.0, monsters_hp_before[i] - maxf(0.0, float(monsters[i]["hp"])))
	var dealt_map: Dictionary = state.get("_dealt", {})
	dealt_map[h.id] = float(dealt_map.get(h.id, 0.0)) + dealt_now
	state["_dealt"] = dealt_map
	var kill_map: Dictionary = state.get("_kills", {})
	kill_map[h.id] = int(kill_map.get(h.id, 0)) + kills
	state["_kills"] = kill_map
	_pp_after_action(state, h, action)


## One living monster's retaliation — the per-monster body of the old batched
## monster phase, unchanged math, scoped to a single monster's turn. `round_num`
## still gates warded/enrage exactly as it did in the batched version (a
## round-scoped effect, not a per-turn one).
func _resolve_monster_action(state: Dictionary, i: int) -> void:
	var log: Array[String] = state["log"]
	var party: Array[Hero] = state["party"]
	var monsters: Array = state["monsters"]
	var round_num: int = int(state["round_num"])
	var m: Dictionary = monsters[i]

	if round_num == 1 and party_has_unique_relic("stopped_clock"):
		log.append(tr("%s is frozen in time by the Stopped Clock.") % tr(str(m["name"])))
		return
	var escort: Dictionary = state.get("escort", {})
	if not escort.is_empty() and float(escort["hp"]) > 0.0 and randf() < 0.2:
		var escort_dmg: int = max(1, int(round(float(m["dmg"]) * 0.6)))
		escort["hp"] = max(0.0, float(escort["hp"]) - escort_dmg)
		log.append(tr("The %s strikes %s for %d!") % [tr(str(m["name"])), tr(str(escort["name"])), escort_dmg])
		if float(escort["hp"]) <= 0.0:
			log.append(tr("%s doesn't survive the fight.") % tr(str(escort["name"])))
		return

	var stunned: Dictionary = state.get("_m_stunned", {})
	if stunned.has(i):
		var left := int(stunned[i]) - 1
		if left <= 0:
			stunned.erase(i)
		else:
			stunned[i] = left
		log.append(tr("%s is stunned and loses its action.") % tr(str(m["name"])))
		return
	if m.get("_winding", false):
		m["_winding"] = false
		m["_charged"] = true
		log.append(tr("%s gathers its strength — a heavy blow is coming!") % tr(str(m["name"])))
		return
	var alive_now: Array[Hero] = []
	alive_now.assign(party.filter(func(h): return h.hp > 0))
	if alive_now.is_empty():
		return
	var it := _intent_of(state, i)
	var kind := str(it.get("kind", "attack"))
	if m.get("_charged", false):
		kind = "attack"   # a charged blow always lands as an attack
	match kind:
		"ward", "mend":
			var low := -1
			for j in monsters.size():
				if float(monsters[j]["hp"]) > 0 and (low < 0 or float(monsters[j]["hp"]) / float(monsters[j]["max_hp"]) < float(monsters[low]["hp"]) / float(monsters[low]["max_hp"])):
					low = j
			if low >= 0:
				if kind == "ward":
					var amt: float = round(float(monsters[low]["max_hp"]) * GameData.WARD_PCT)
					var ws: Dictionary = state["monster_shields"]
					ws[low] = float(ws.get(low, 0.0)) + amt
					log.append(tr("%s wards %s for %d.") % [tr(str(m["name"])), tr(str(monsters[low]["name"])), amt])
				else:
					var pct := float(m.get("ability", {}).get("value", GameData.MEND_PCT)) if m.get("ability", {}).get("kind") == "healer" else GameData.MEND_PCT
					var heal: float = round(float(monsters[low]["max_hp"]) * pct)
					monsters[low]["hp"] = minf(float(monsters[low]["max_hp"]), float(monsters[low]["hp"]) + heal)
					log.append(tr("%s mends %s for %d.") % [tr(str(m["name"])), tr(str(monsters[low]["name"])), heal])
					_tally(state, "enemy_heal", heal)
			return
		"roar":
			for o in monsters:
				if float(o["hp"]) > 0:
					o["dmg"] = float(o["dmg"]) * GameData.ROAR_MULT
			m["_roars"] = int(m.get("_roars", 0)) + 1
			log.append(tr("%s roars — every foe hits harder!") % tr(str(m["name"])))
			return
		"curse":
			var ct: Hero = _find_party_hero(party, str(it.get("target", "")))
			if ct == null or ct.hp <= 0:
				ct = alive_now[randi() % alive_now.size()]
			state.get_or_add("_weakened", {})[ct.id] = GameData.CURSE_ROUNDS
			log.append(tr("%s curses %s: %d%% less damage for %d rounds.") % [tr(str(m["name"])), tr(str(ct.name)), int(GameData.CURSE_WEAKEN * 100), GameData.CURSE_ROUNDS])
			return
		"sweep":
			log.append(tr("%s sweeps the whole party!") % tr(str(m["name"])))
			for h in alive_now:
				if h.hp > 0:
					_monster_strike(state, i, h, GameData.SWEEP_MULT, false)
			return
		"harvest":
			log.append(tr("%s reaps the whole party!") % tr(str(m["name"])))
			var before := 0
			for h in alive_now:
				before += h.hp
			for h in alive_now:
				if h.hp > 0:
					_monster_strike(state, i, h, GameData.HARVEST_MULT, false)
			var taken := before
			for h in alive_now:
				taken -= h.hp
			if taken > 0:
				m["hp"] = minf(float(m["max_hp"]), float(m["hp"]) + taken * 0.5)
				log.append(tr("%s drinks in the harvest (+%d).") % [tr(str(m["name"])), int(taken * 0.5)])
				_tally(state, "enemy_heal", taken * 0.5)
			return
		"drown":
			log.append(tr("%s calls the Drowning Tide!") % tr(str(m["name"])))
			for h in alive_now:
				if h.hp > 0:
					_monster_strike(state, i, h, GameData.DROWN_MULT, false)
					if h.hp > 0:
						state.get_or_add("_chilled", {})[h.id] = 2
						state.get_or_add("_weakened", {})[h.id] = maxi(int(state.get("_weakened", {}).get(h.id, 0)), 2)
			return
		"immolate":
			log.append(tr("%s sets the party ablaze!") % tr(str(m["name"])))
			for h in alive_now:
				if h.hp > 0:
					_monster_strike(state, i, h, GameData.IMMOLATE_MULT, false)
					if h.hp > 0:
						state.get_or_add("hero_burn", {})[h.id] = {"rounds": 3, "value": float(GameData.STATUS_INFO["burn"]["value"])}
			return
		"sunder":
			var front: Array = alive_now.filter(func(h): return h.formation != "back")
			if front.is_empty():
				front = alive_now
			log.append(tr("%s sunders the front line!") % tr(str(m["name"])))
			for h in front:
				if h.hp > 0:
					(state["hero_shields"] as Dictionary).erase(h.id)
					_monster_strike(state, i, h, GameData.SUNDER_MULT, false)
			return
		"brand":
			var bt: Hero = _find_party_hero(party, str(it.get("target", "")))
			if bt == null or bt.hp <= 0:
				bt = alive_now[randi() % alive_now.size()]
			state.get_or_add("_branded", {})[bt.id] = GameData.BRAND_ROUNDS
			log.append(tr("%s brands %s: they take %d%% more damage for %d rounds.") % [tr(str(m["name"])), tr(str(bt.name)), int(GameData.BRAND_TAKEN * 100), GameData.BRAND_ROUNDS])
			return
	# The target was rolled at round start (state["intents"]) so the combat
	# screen can show it; re-roll only if that hero has since dropped.
	var target: Hero = _find_party_hero(party, str(it.get("target", "")))
	if target == null or target.hp <= 0:
		target = weighted_formation_target(alive_now)
	_monster_strike(state, i, target, GameData.SNIPE_MULT if kind == "snipe" else 1.0, true)


## Monster `i` hits `target` for `mult` of its hit. `aimed` hits can be
## redirected (Taunt, intercept effects, Guard); a sweep's can't.
func _monster_strike(state: Dictionary, i: int, target: Hero, mult: float, aimed: bool) -> void:
	var log: Array[String] = state["log"]
	var party: Array[Hero] = state["party"]
	var m: Dictionary = state["monsters"][i]
	var round_num: int = int(state["round_num"])
	var alive_now: Array[Hero] = []
	alive_now.assign(party.filter(func(h): return h.hp > 0))
	var guard: Hero = null
	var taunted := false
	if aimed and float(state.get("_trap", 0.0)) > 0.0:
		var trap_dmg := float(state["_trap"])
		state["_trap"] = 0.0
		m["hp"] = float(m["hp"]) - round(trap_dmg)
		log.append(tr("%s springs the snare: %d damage, and its attack is lost!") % [tr(str(m["name"])), int(round(trap_dmg))])
		return
	if aimed:
		var taunter := _find_party_hero(party, str(state.get("_taunt", "")))
		if taunter and taunter.hp > 0:
			target = taunter
			taunted = true
		else:
			var aim := {"target": target, "attacker": m}
			# The sturdiest ally gets the first chance to step in (a relic's
			# intercept says "your healthiest hero").
			var in_line := alive_now.duplicate()
			in_line.sort_custom(func(a, b): return a.hp > b.hp)
			for ally in in_line:
				if ally != target:
					_fire("ally_targeted", state, ally, aim)
					if aim["target"] != target:
						break
			target = aim["target"]
			guard = guard_of(state, target)
			if guard:
				log.append(tr("%s takes the blow meant for %s!") % [tr(str(guard.name)), tr(str(target.name))])
				_proc(state, guard, "Guard!")
				target = guard
			else:
				target = _pp_retarget(state, m, target)   # Paths: Feint, Vanish, Untouchable
	var mech: Dictionary = m.get("mechanic", {})
	var mech2: Dictionary = m.get("mechanic2", {})
	var ability: Dictionary = m.get("ability", {})
	var back: float = _monster_hit(m, round_num) * mult
	var heavy_blow: bool = m.get("_charged", false)
	if heavy_blow and not m.get("_prophesied", false) and _pp_cancel_heavy(state, m):   # Augury's Foresight
		m["_charged"] = false
		m["_windup_cd"] = 1
		return
	if heavy_blow:
		m["_charged"] = false
		m["_windup_cd"] = 1
		back *= GameData.HEAVY_BLOW_MULT
	if guard:
		back *= GUARD_DAMAGE_MULT
		gain_momentum(state, 2 if heavy_blow else 1)
	if taunted:
		back *= 1.0 - float(state.get("_taunt_cut", 0.0))
	if state.get("_branded", {}).has(target.id):
		back *= 1.0 + GameData.BRAND_TAKEN
	var undying: bool = state.get("_undying", {}).has(target.id) or (int(_pp(state, target).get("mist", 0)) > 0 and _tw(target, "ashen-templar"))
	if undying:
		back *= 0.5
	back *= _pp_taken_mult(state, m, target)
	var warded: bool = (mech.get("id") == "warded" or mech2.get("id") == "warded") and round_num <= 2
	if state["_defending"].has(target.id):
		back *= 0.5
		gain_momentum(state, 2 if heavy_blow else 1)
	var effective_dodge: float = float(state["dodge"]) + float(state.get("_smoke", 0.0)) + hero_cond_stat(target, "dodge_pct", state, {"attacker": m}) + _pp_dodge(state, target, m)
	var evaded := false
	if state.get("_evade_next", {}).has(target.id):
		state["_evade_next"].erase(target.id)
		log.append(tr("%s saw it coming and slips the blow!") % tr(str(target.name)))
		evaded = true
	elif not warded and effective_dodge > 0.0 and randf() < effective_dodge:
		log.append(tr("%s evades %s's retaliation!") % [tr(str(target.name)), tr(str(m["name"]))])
		evaded = true
	var heavy_hit: bool = back >= float(base_max_hp(target)) * 0.25
	if GameState.wounds_on() and (heavy_blow or heavy_hit):   # 0.68: what Guard, Defend or a dodge kept from wounding
		if evaded:
			_tally(state, "wound_dodged")
		elif guard:
			_tally(state, "wound_guarded")
		elif state["_defending"].has(target.id):
			_tally(state, "wound_defended")
	if evaded:
		back = 0.0
	if evaded or heavy_hit:
		_fire("evade_or_heavy", state, target, {"attacker": m})
	if back > 0.0 and aimed:
		back = _pp_guardian_share(state, m, target, back)   # Shieldwall's Guardian takes a share
	if back > 0.0:
		var lw := _pp_last_wall(state, target, int(round(back - float(state["hero_shields"].get(target.id, 0.0)))))
		if lw != target:
			target = lw   # Last Wall: the guardian takes the blow that would have felled an ally
	var shields: Dictionary = state["hero_shields"]
	if back > 0.0 and float(shields.get(target.id, 0.0)) > 0.0:
		var have: float = float(shields[target.id])
		var absorbed: float = min(have, back)
		shields[target.id] = have - absorbed
		back -= absorbed
		log.append(tr("%s's shield absorbs %d damage.") % [tr(str(target.name)), int(round(absorbed))])
		_pp_ward_struck(state, i, absorbed, have - absorbed <= 0.0)
	var landed := 0
	if back > 0.0:
		var dealt_back: int = int(round(back))
		landed = dealt_back
		var is_last_hero := alive_now.size() == 1
		if dealt_back >= target.hp and is_last_hero and not state["wipe_guard_used"] and float(state["wipe_guard"]) > 0.0:
			state["wipe_guard_used"] = true
			target.hp = max(1, int(round(float(max_hp(target)) * float(state["wipe_guard"]))))
			log.append(tr("Last Stand! %s clings to life with %d HP.") % [tr(str(target.name)), target.hp])
		else:
			target.hp = max(1 if undying else 0, target.hp - dealt_back)
			log.append(tr("The %s hits %s for %d.") % [tr(str(m["name"])), tr(str(target.name)), dealt_back])
			_tally(state, "taken", dealt_back)
			if heavy_blow and not state["_defending"].has(target.id):
				_tally(state, "undefended_heavy")
				_tally(state, "heavy_dmg", dealt_back)
			if heavy_blow and target.hp > 0 and not state["_defending"].has(target.id):
				state.get_or_add("_stunned", {})[target.id] = true
				log.append(tr("%s is stunned by the blow!") % tr(str(target.name)))
			# Fight stakes (0.68): a landed wind-up or a big hit, taken unguarded and
			# undefended, wounds; any other such hit leaves a trace.
			if GameState.wounds_on() and not guard and not state["_defending"].has(target.id):
				var big: bool = heavy_blow or dealt_back >= base_max_hp(target) * GameData.WOUND_HEAVY_PCT
				var trace: float = GameData.WOUND_TRACE if GameState.wounds_last_run() and str(state.get("kind", "")) == "combat" else 0.0   # traces wear the road down from Rank S (0.69)
				var w := GameState.add_wound(target, dealt_back, GameData.WOUND_SHARE if big else trace)
				if w > 0:
					_tally(state, "wound_hp", w)
					if big:
						_tally(state, "wounds")
						log.append(tr("%s is wounded: -%d max HP.") % [tr(str(target.name)), w])
			var status := str(m.get("status", ""))
			if status != "" and target.hp > 0 and randf() < float(GameData.STATUS_INFO[status]["chance"]):
				var info: Dictionary = GameData.STATUS_INFO[status]
				if status == "burn":
					state.get_or_add("hero_burn", {})[target.id] = {"rounds": int(info["rounds"]), "value": float(info["value"])}
					log.append(tr("%s is set ablaze!") % tr(str(target.name)))
				elif status == "chill":
					state.get_or_add("_chilled", {})[target.id] = int(info["rounds"]) + 1
					log.append(tr("%s is chilled — they'll act late next round.") % tr(str(target.name)))
			if ability.get("kind") == "poison" and target.hp > 0:
				state["hero_poison"][target.id] = {"rounds": 2, "value": float(ability["value"])}
				log.append(tr("%s is poisoned!") % tr(str(target.name)))
			if ability.get("kind") == "drain" and dealt_back > 0:
				var drained: int = max(1, int(round(dealt_back * float(ability["value"]))))
				m["hp"] = min(float(m["max_hp"]), float(m["hp"]) + drained)
				log.append(tr("%s drains %d HP from the blow.") % [tr(str(m["name"])), drained])
			if target.hp <= 0:
				log.append(tr("%s is knocked out!") % tr(str(target.name)))
				_fire("ally_down", state, target)
	_pp_after_struck(state, i, target, landed, evaded)
	var rip: Dictionary = state.get("_riposte", {}).get(target.id, {})
	if not rip.is_empty() and target.hp > 0 and float(m["hp"]) > 0:
		m["hp"] = float(m["hp"]) - round(float(rip["dmg"]))
		log.append(tr("%s ripostes, striking %s for %d!") % [tr(str(target.name)), tr(str(m["name"])), int(round(float(rip["dmg"])))])
		rip["left"] = int(rip["left"]) - 1
		if int(rip["left"]) <= 0:
			state["_riposte"].erase(target.id)


# ---------------- Defeat analysis ----------------

## Fight tallies for the "why you lost" card (state["_stats"]).
## A Feat for this fight (GameData.FEATS): one that suits it, picked from the
## fight's own seed. `kind` is "elite", "boss" or "pillar".
func roll_feat(state: Dictionary, kind: String, want: String = "") -> Dictionary:
	var monsters: Array = state["monsters"]
	var ids: Array = ["break", "swift", "unbloodied", "momentum"]
	var adds: Array = range(monsters.size()).filter(func(i): return not monsters[i].get("is_main", false))
	if not adds.is_empty():
		ids.append("first")
	if monsters.size() >= 2:
		ids.append("double")
	var id := want if ids.has(want) else str(ids[randi() % ids.size()])   # the one shown before Engage, if it fits
	var feat := {"id": id}
	var start := {}
	for h in state["party"]:
		start[h.id] = h.hp
	state["_feat_start_hp"] = start
	match id:
		"swift":
			feat["rounds"] = int(GameData.FEAT_ROUNDS.get("elite" if kind == "elite" else "boss", 6))
		"first":   # the toughest of the main foe's company
			var pick: int = adds[0]
			for i in adds:
				if float(monsters[i]["max_hp"]) > float(monsters[pick]["max_hp"]):
					pick = i
			feat["foe"] = str(monsters[pick]["name"]).split(",")[0]
		"momentum":
			feat["momentum"] = GameData.FEAT_MOMENTUM
	return feat


## The Feat shown before Engage (the foes aren't known yet): its name and
## what it asks, with "first" naming no one until the fight starts.
func feat_preview_text(id: String, kind: String) -> Array:
	match id:
		"first":
			return [tr("Down one of its company first"), tr("The fight names which one when it starts.")]
		"double":
			return [tr(str(GameData.FEATS["double"]["name"])), tr(str(GameData.FEATS["double"]["desc"])) + " " + tr("If it fights alone, another Feat takes its place.")]
	return feat_text({"id": id, "rounds": int(GameData.FEAT_ROUNDS.get("elite" if kind == "elite" else "boss", 6)), "momentum": GameData.FEAT_MOMENTUM})


## The Feat's name and what it asks, for the battle screen.
func feat_text(feat: Dictionary) -> Array:
	var d: Dictionary = GameData.FEATS.get(str(feat.get("id", "")), {})
	if d.is_empty():
		return ["", ""]
	var arg: Variant = feat.get("rounds", feat.get("foe", feat.get("momentum", null)))
	var nm := tr(str(d["name"]))
	var ds := tr(str(d["desc"]))
	if arg != null:
		var a2: Variant = tr(str(arg)) if arg is String else arg
		nm = nm % a2 if nm.contains("%") else nm
		ds = ds % a2 if ds.contains("%") else ds
	return [nm, ds]


## Watches the fight for the Feat (after every turn): the first foe down,
## two down in one round, a hero who lost half their health.
func _feat_watch(state: Dictionary) -> void:
	if not state.has("feat"):
		return
	var downed: Dictionary = state.get_or_add("_feat_downed", {})
	var round_num := int(state["round_num"])
	for i in (state["monsters"] as Array).size():
		var m: Dictionary = state["monsters"][i]
		if float(m["hp"]) <= 0 and not downed.has(i):
			downed[i] = round_num
			if not state.has("_feat_first"):
				state["_feat_first"] = str(m["name"]).split(",")[0]
	state["_feat_max_mom"] = maxi(int(state.get("_feat_max_mom", 0)), int(state.get("momentum", 0)))
	var start: Dictionary = state.get("_feat_start_hp", {})
	for h in state["party"]:
		if h.hp < int(start.get(h.id, max_hp(h))) - max_hp(h) * 0.5:
			state["_feat_hurt"] = true


## "done", "failed" or "open": how the Feat stands (`ended`: the fight is over).
func feat_status(state: Dictionary, ended: bool = false) -> String:
	var feat: Dictionary = state.get("feat", {})
	if feat.is_empty():
		return ""
	var stats: Dictionary = state.get("_stats", {})
	match str(feat["id"]):
		"break":
			if float(stats.get("broke_windup", 0.0)) > 0:
				return "done"
			return "failed" if ended else "open"
		"swift":
			if int(state["round_num"]) > int(feat["rounds"]):
				return "failed"
		"unbloodied":
			if state.get("_feat_hurt", false):
				return "failed"
		"first":
			if state.has("_feat_first"):
				return "done" if str(state["_feat_first"]) == str(feat["foe"]) else "failed"
		"double":
			var per_round := {}
			for i in state.get("_feat_downed", {}):
				var r := int(state["_feat_downed"][i])
				per_round[r] = int(per_round.get(r, 0)) + 1
			if per_round.values().any(func(n): return n >= 2):
				return "done"
			return "failed" if ended else "open"
		"momentum":
			if int(state.get("_feat_max_mom", 0)) >= int(feat["momentum"]):
				return "done"
			return "failed" if ended else "open"
	return "done" if ended else "open"


func _tally(state: Dictionary, key: String, amount: float = 1.0) -> void:
	var st: Dictionary = state.get_or_add("_stats", {})
	st[key] = float(st.get(key, 0.0)) + amount


## The top reasons a fight was lost, each [title, tip], most important first.
func defeat_reasons(state: Dictionary) -> Array:
	var st: Dictionary = state.get("_stats", {})
	var party: Array = state["party"]
	var out: Array = []   # [weight, title, tip]
	var power := party_power(party)
	var rec := int(state.get("diff", {}).get("rec_power", 0))
	if state.get("is_boss", false):
		rec = int(round(rec * 1.1))
	if rec > 0 and power < rec * 0.9:
		out.append([3.0 + float(rec - power) / rec * 5.0, tr("Underpowered: party power %d vs %d recommended") % [power, rec],
			"Level heroes, train attributes and upgrade gear at camp, or pick an easier rift for now."])
	var heavy := int(st.get("undefended_heavy", 0))
	if heavy > 0:
		out.append([2.5 + heavy, tr("%d heavy blow%s landed undefended (%d damage)") % [heavy, GameData.pl(heavy), int(st.get("heavy_dmg", 0.0))],
			"When a foe is \"Winding up\", its target should Defend (5): half damage and no stun. Guard (6) moves the hit onto a sturdier ally; Shield Bash or Frost Nova break the wind-up."])
	var wounds := int(st.get("wounds", 0))
	if wounds > 0:   # fight stakes (0.68)
		out.append([2.2 + wounds, tr("%d wound%s from heavy blows taken unguarded (-%d max HP)") % [wounds, GameData.pl(wounds), int(st.get("wound_hp", 0.0))],
			"From Rank C a heavy blow wounds unless its target Defends, is Guarded or dodges. Answer every wind-up: Defend (5), Guard (6), or break it with Shield Bash or Frost Nova."])
	var taken := float(st.get("taken", 0.0))
	var dot := float(st.get("dot", 0.0))
	if taken > 0.0 and dot / taken >= 0.2:
		out.append([2.0 + dot / taken * 4.0, tr("Burn and poison did %d damage (%d%% of the total)") % [int(dot), int(dot / taken * 100.0)],
			"A Healing Tonic cleanses burn, poison, chill and stun. Kill the fire and poison foes first."])
	var healed := float(st.get("enemy_heal", 0.0))
	var foe_hp := 0.0
	for m in state["monsters"]:
		foe_hp += float(m["max_hp"])
	if foe_hp > 0.0 and healed / foe_hp >= 0.15:
		out.append([2.0 + healed / foe_hp * 4.0, tr("Your foes healed %d HP") % int(healed),
			"Focus the healer first, and save Abilities to burst a regenerating foe from low HP."])
	var start_pct := float(state.get("_start_hp_pct", 1.0))
	if start_pct < 0.6:
		out.append([2.0 + (0.6 - start_pct) * 5.0, tr("The party started the fight at %d%% HP") % int(start_pct * 100.0),
			"Rest at a campfire, use a Supply Drop order, or retreat and come back healed."])
	if int(state.get("round_num", 0)) >= 3 and int(st.get("abilities", 0)) == 0:
		out.append([1.8, tr("No Abilities were used"),
			"Abilities (2) hit much harder than attacks. Use them whenever they're ready."])
	var squishy_front := party.filter(func(h): return h.formation == "front" and GameData.hero_role(h) in ["mage", "cleric", "ranger"] and h.hp <= 0)
	if not squishy_front.is_empty():
		out.append([1.5, tr("%s fell in the front row") % tr(str(", ".join(squishy_front.map(func(h): return h.name.split(" the ")[0])))),
			"The front row takes most of the hits. Put Mages, Clerics and Rangers in the back row."])
	if not party.any(func(h): return GameData.hero_role(h) == "cleric") and int(state.get("round_num", 0)) >= 6:
		out.append([1.2, tr("No healer in a long fight"),
			"A Cleric (or healing relics and skills) keeps the party standing through long fights."])
	out.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	return out.slice(0, 3).map(func(x): return [x[1], x[2]])


## Passive round-cadence effects (monster regen, hero poison tick,
## party mend) — fired once, after every actor in the round's turn order has
## acted, rather than at the old "after heroes, before monsters" phase
## boundary, which no longer exists once heroes and monsters are genuinely
## interleaved. Same total effect per round as before, just anchored to
## round-end instead of a mid-round phase split.
func _end_round_effects(state: Dictionary) -> void:
	var log: Array[String] = state["log"]
	var party: Array[Hero] = state["party"]
	var monsters: Array = state["monsters"]

	for m in monsters:
		var is_regen: bool = m.get("mechanic", {}).get("id") == "regen" or m.get("mechanic2", {}).get("id") == "regen"
		if float(m["hp"]) > 0 and is_regen:
			var regen_heal: float = round(float(m["max_hp"]) * 0.08)
			m["hp"] = min(float(m["max_hp"]), float(m["hp"]) + regen_heal)
			log.append(tr("%s regenerates %d HP.") % [tr(str(m["name"])), regen_heal])
			_tally(state, "enemy_heal", regen_heal)

	var mburn: Dictionary = state.get("_m_burn", {})
	for mi in mburn.keys().duplicate():
		var mb: Dictionary = mburn[mi]
		if int(mi) >= monsters.size() or float(monsters[int(mi)]["hp"]) <= 0:
			mburn.erase(mi)
			continue
		monsters[int(mi)]["hp"] = float(monsters[int(mi)]["hp"]) - round(float(mb["dmg"]))
		log.append(tr("%s burns for %d.") % [tr(str(monsters[int(mi)]["name"])), int(round(float(mb["dmg"])))])
		mb["rounds"] = int(mb["rounds"]) - 1
		if int(mb["rounds"]) <= 0:
			mburn.erase(mi)
	var burn: Dictionary = state.get("hero_burn", {})
	for bid in burn.keys().duplicate():
		var hb: Hero = _find_party_hero(party, str(bid))
		if hb == null or hb.hp <= 0:
			burn.erase(bid)
			continue
		var btick: int = max(1, int(round(max_hp(hb) * float(burn[bid]["value"]))))
		hb.hp = max(0, hb.hp - btick)
		log.append(tr("%s burns for %d.") % [tr(str(hb.name)), btick])
		_tally(state, "dot", btick)
		_tally(state, "taken", btick)
		if hb.hp <= 0:
			log.append(tr("%s is knocked out!") % tr(str(hb.name)))
		burn[bid]["rounds"] = int(burn[bid]["rounds"]) - 1
		if int(burn[bid]["rounds"]) <= 0 or hb.hp <= 0:
			burn.erase(bid)
	var poison: Dictionary = state["hero_poison"]
	for hero_id in poison.keys().duplicate():
		var h5: Hero = null
		for hp_candidate in party:
			if hp_candidate.id == str(hero_id):
				h5 = hp_candidate
				break
		if h5 == null or h5.hp <= 0:
			poison.erase(hero_id)
			continue
		var entry: Dictionary = poison[hero_id]
		var tick: int = max(1, int(round(max_hp(h5) * float(entry["value"]))))
		h5.hp = max(0, h5.hp - tick)
		log.append(tr("%s suffers %d poison damage.") % [tr(str(h5.name)), tick])
		_tally(state, "dot", tick)
		_tally(state, "taken", tick)
		if h5.hp <= 0:
			log.append(tr("%s is knocked out!") % tr(str(h5.name)))
		entry["rounds"] = int(entry["rounds"]) - 1
		if entry["rounds"] <= 0 or h5.hp <= 0:
			poison.erase(hero_id)
		else:
			poison[hero_id] = entry

	var living: Array[Hero] = []
	living.assign(party.filter(func(h): return h.hp > 0))
	if float(state["mend"]) > 0.0:
		var mended := false
		for h in living:
			if h.hp > 0 and h.hp < max_hp(h):
				var heal: int = max(1, int(round(max_hp(h) * float(state["mend"]))))
				_pp_heal(state, h, heal, false)   # the party mend: no Overflow ward
				mended = true
		if mended:
			log.append(tr("The party mends its wounds."))
			for h4 in living:
				_fire("party_mend", state, h4)
	_pp_round_end(state)


## {} if the fight isn't over; otherwise the {"done":true,...} outcome from
## _finish_combat.
func _check_monsters_defeated(state: Dictionary) -> Dictionary:
	var monsters: Array = state["monsters"]
	for m in monsters:
		if float(m["hp"]) > 0:
			return {}
	state["log"].append((tr("The %s falls!") % tr(str(monsters[0]["name"]))) if monsters.size() == 1 else tr("All foes defeated!"))
	return _finish_combat(state, true, false)


func _check_party_defeated(state: Dictionary) -> Dictionary:
	for h in state["party"]:
		if h.hp > 0:
			return {}
	if party_has_unique_relic("phoenix_feather") and not GameState.run.is_empty() and not bool(GameState.run.get("phoenix_used", false)):
		GameState.run["phoenix_used"] = true
		for h in state["party"]:
			h.hp = max(1, int(round(max_hp(h) * 0.30)))
		(state["log"] as Array).append(tr("The Phoenix Feather flares — the party rises from the ashes!"))
		return {}
	return _finish_combat(state, false, false)


## Ensures state["turn_order"]/state["turn_idx"] point at a valid upcoming
## turn — rolling a fresh round via _start_round if the previous one is
## exhausted — and returns that turn descriptor without resolving it. Lets a
## caller (Main.gd's _run_combat_turns) find out what's coming next, and
## whether it needs player input, before committing to resolve_turn. Has the
## same round-rollover side effects _start_round always has, so — like
## resolve_turn — only call this from an actual game action, never from a
## read-only render() pass (see Main.gd's own comment on this).
## Guild Order "Rally": the rest of this round, every hero acts before any
## foe and the party hits 30% harder.
func apply_rally(state: Dictionary) -> void:
	peek_next_turn(state)   # make sure a round is under way
	state["_attack_mult"] = float(state.get("_attack_mult", 1.0)) * 1.3
	var idx := int(state.get("turn_idx", 0))
	var order: Array = state["turn_order"]
	var rest: Array = order.slice(idx)
	var sorted: Array = rest.filter(func(t): return t["type"] == "hero") + rest.filter(func(t): return t["type"] != "hero")
	for k in sorted.size():
		order[idx + k] = sorted[k]
	(state["log"] as Array).append(tr("Rally! The guild's order rings out: the party moves first and hits 30% harder this round."))


func peek_next_turn(state: Dictionary) -> Dictionary:
	if state.get("turn_order", []).is_empty() or int(state.get("turn_idx", 0)) >= state["turn_order"].size():
		_start_round(state)
	return state["turn_order"][int(state["turn_idx"])]


## One actor's turn within an in-progress fight — a living hero's chosen
## pending action, or a living monster's retaliation, whichever
## state["turn_order"] says comes next (see _compute_turn_order — heroes and
## monsters are genuinely interleaved by speed, not resolved in two batch
## phases). Advances state["turn_idx"]; once a round's turn order is fully
## spent, rolls the passive round-end effects and a fresh order for the next
## round. Mutates `state` in place and returns {"done": bool, "result":
## Dictionary} — result is only populated once the fight ends. Call once per
## turn (see Main.gd's _run_combat_turns, which drives this automatically for
## monster turns and on the player's action-bar click for a hero's turn).
func resolve_turn(state: Dictionary) -> Dictionary:
	state["_procs"] = []   # effects that fired this turn — the combat screen floats their names
	state["_barks"] = []   # what a hero said this turn (speech bubbles)
	var turn: Dictionary = peek_next_turn(state)
	var turn_idx: int = int(state["turn_idx"])
	state["turn_idx"] = turn_idx + 1

	if turn["type"] == "hero":
		var h := _find_party_hero(state["party"], str(turn["id"]))
		var stunned: Dictionary = state.get("_stunned", {})
		if h and h.hp > 0 and stunned.has(h.id) and _pp_stun_immune(state, h):
			stunned.erase(h.id)   # Red Mist / a Scrapper Legend shrugs it off
		if h and h.hp > 0 and stunned.has(h.id):
			stunned.erase(h.id)
			(state["log"] as Array).append(tr("%s is stunned and loses the turn.") % tr(str(h.name)))
		elif h and h.hp > 0:
			var alive_before: Array = (state["monsters"] as Array).filter(func(m): return float(m["hp"]) > 0)
			_resolve_hero_action(state, h)
			var felled: Array = alive_before.filter(func(m): return float(m["hp"]) <= 0)
			if not felled.is_empty() and h.hp > 0:
				_bark(state, h, "kill", 1.0 if felled.any(func(m): return m["is_main"] and m["tier"] != "combat") else 0.3)
	else:
		var i: int = int(turn["id"])
		var monsters: Array = state["monsters"]
		if i < monsters.size() and float(monsters[i]["hp"]) > 0:
			var hp_before := {}
			for ph in state["party"]:
				hp_before[ph.id] = ph.hp
			_resolve_monster_action(state, i)
			var living: Array = (state["party"] as Array).filter(func(x): return x.hp > 0)
			for ph in state["party"]:
				if ph.hp >= int(hp_before[ph.id]):
					continue
				if ph.hp <= 0 and not living.is_empty():
					_bark(state, living[randi() % living.size()], "ally_down", 0.6)
				elif ph.hp > 0 and ph.hp < max_hp(ph) * 0.25:
					_bark(state, ph, "low_hp", 0.7)
	_check_phases(state)
	_feat_watch(state)

	var outcome := _check_monsters_defeated(state)
	if not outcome.is_empty():
		return outcome
	outcome = _check_party_defeated(state)
	if not outcome.is_empty():
		return outcome

	if int(state["turn_idx"]) >= state["turn_order"].size():
		_end_round_effects(state)
		_feat_watch(state)
		outcome = _check_monsters_defeated(state)
		if not outcome.is_empty():
			return outcome
		outcome = _check_party_defeated(state)
		if not outcome.is_empty():
			return outcome
		if int(state["round_num"]) >= 30:
			return _finish_combat(state, false, false)

	return {"done": false, "result": {}}


## Ends the fight immediately by player choice — no round processing, no
## penalty beyond forfeiting rewards; every hero keeps their current live HP.
func retreat_combat(state: Dictionary) -> Dictionary:
	var log: Array[String] = state["log"]
	log.append(tr("The party withdraws from the fight."))
	return _finish_combat(state, false, true)


func _finish_combat(state: Dictionary, won: bool, retreated: bool) -> Dictionary:
	var party: Array[Hero] = state["party"]
	var log: Array[String] = state["log"]
	var full_loss := not won and not retreated
	if full_loss:
		log.append(tr("Your party is overwhelmed..."))
	if not GameState.wounds_last_run():   # up to Rank A wounds close when the fight ends (0.68)
		for h in party:
			h.wound = 0
	elif won and not bool(state.get("is_boss", false)):   # from Rank S Momentum left over carries to the next fight (0.69)
		var left := int(state.get("momentum", 0))
		if left > 0:
			GameState.run["momentum_bonus"] = mini(GameData.MOMENTUM_MAX - GameData.MOMENTUM_START, int(GameState.run.get("momentum_bonus", 0)) + left)
	# Any hero knocked out mid-fight (hp hit 0 while the party kept
	# fighting and ultimately won, or before a retreat) still needs a
	# recovery timer — not just the whole-party-wiped case above, or
	# they'd sit at 0 HP forever, invisible to needs_recovery()/Medical Bay.
	for h in party:
		if h.hp <= 0 and h.down_runs <= 0:
			GameState.knock_out(h)
			h.history["knockouts"] = int(h.history.get("knockouts", 0)) + 1
			# The cost of falling (0.68): from Rank C a scar chance, a dropped
			# gear piece and, at SS+, death for a twice-scarred hero.
			var scars0 := h.quirks.size()
			log.append_array(GameState.fall_costs(h))
			if h.quirks.size() > scars0:
				log.append(GameData.narrative_line("scar_gained"))

	var result := {
		"won": won, "retreated": retreated, "log": log, "rounds": int(state["round_num"]), "monster_name": state["monsters"][0]["name"],
		"coin": 0, "crystal": 0, "bonus_crystal": 0, "reward_options": [],
	}
	if won and state.has("feat"):   # the Feat, settled
		_feat_watch(state)
		result["feat_done"] = feat_status(state, true) == "done"
	if won:
		var is_boss: bool = state["is_boss"]
		var is_elite: bool = state["is_elite"]
		var diff: Dictionary = state["diff"]
		var floor_idx: int = state["floor_idx"]
		var reward_mult: float = (1.4 * (1.5 if GameState.has_wing("war_room") else 1.0)) if is_elite else 1.0
		var depth_mult: float = 1.0 + floor_idx * 0.05
		result["coin"] = round(randf_range(diff["coin"][0], diff["coin"][1]) * reward_mult * depth_mult)
		var base_crystal: float = round(randf_range(diff["crystal"][0], diff["crystal"][1]) * reward_mult * depth_mult)
		result["crystal"] = round(base_crystal * GameState.crystal_yield_bonus())
		result["guild_crystal"] = int(result["crystal"] - base_crystal)   # Crystal Amplifiers' share, shown on the result
		if is_boss and GameState.crystal_resonance():
			var cache := int(round(float(diff["crystal"][1]) * 2.0))
			result["bonus_crystal"] = int(result.get("bonus_crystal", 0)) + cache
			result["crystal_cache"] = cache
		if is_elite:
			var bonus_crystal := 0
			for h in party:
				if randf() < GameState.energy_extract_chance():
					bonus_crystal += randi() % 4 + 2
			result["bonus_crystal"] = bonus_crystal
		var xp_gain: int = int(round((30 if is_boss else (20 if is_elite else 12)) * float(GameData.RIFT_XP_MULT[clampi(GameData.rift_rank_index(GameState.loot_rank()), 0, GameData.RIFT_XP_MULT.size() - 1)])))
		var summary: Array = []
		for h in party:
			var lv0 := h.level
			var xp0 := h.xp
			gain_xp(h, xp_gain)
			summary.append({"id": h.id, "name": h.name, "cls_id": h.cls_id, "pool_id": h.pool_id, "alive": h.hp > 0,
				"lv0": lv0, "xp0": xp0, "next0": xp_to_next(lv0, h.rank), "lv1": h.level, "xp1": h.xp, "next1": xp_to_next(h.level, h.rank),
				"dealt": int(round(float(state.get("_dealt", {}).get(h.id, 0.0)))), "kills": int(state.get("_kills", {}).get(h.id, 0))})
		result["heroes"] = summary
		result["xp_gain"] = xp_gain
		# One hero sums it up: whoever levelled, else the top damage dealer.
		var speaker: Hero = null
		var moment := "victory"
		for k in summary.size():
			if summary[k]["alive"] and int(summary[k]["lv1"]) > int(summary[k]["lv0"]):
				speaker = party[k]
				moment = "level_up"
				break
		if speaker == null:
			for k in summary.size():
				if summary[k]["alive"] and (speaker == null or int(summary[k]["dealt"]) > int(state.get("_dealt", {}).get(speaker.id, 0.0))):
					speaker = party[k]
		if speaker:
			result["bark"] = {"id": speaker.id, "name": speaker.name.split(" the ")[0], "text": bark_line(speaker, moment)}
		if not is_boss:
			var options := [gen_loot(weighted_rarity()), gen_loot(weighted_rarity())]
			if randf() < min(0.5, drop_rate_bonus() * 2.0):
				options.append(gen_loot(weighted_rarity()))
			if is_elite and randf() < GameData.ELITE_UNIQUE_CHANCE:   # 0.66: an elite may hold a unique relic
				var u := GameState.unique_or_epic()
				if str(u["loot_type"]) == "relic":
					options[0] = u
			result["reward_options"] = options
	return {"done": true, "result": result}


# ======================================================================
## Paths (0.62). Each trained hero brings their Path's rule
## (stage 1), Technique (stage 2, a skill: see GameData.hero_skills) and
## Signature moment (stage 3), bent by their subclass's Twist; a Legend lifts
## the rule's limit. The fight engine (Combat.gd) calls the _pp_* hooks below;
## per-hero counters live in state["_pp"][hero id], per-foe ones on the foe.
## Text for every rule: GameData.PATHS / SUBCLASS_TWIST.

const BLOODRAGE_CAP := 0.4
const COMBO_STEP := 0.12
const STEADY_BONUS := 0.35
const MARK_BONUS := 0.15
const HEAT_STEP := 0.08
const EXECUTE_BELOW := 0.35
const EXECUTE_BONUS := 0.5
const SANCTUARY := 0.06
const FERVOR := 0.25
const SCRAPPY := 0.15
const EVASION := 0.15


# ---------------- Who has what ----------------
func _pa(h: Hero) -> String:
	return "" if h == null or h.is_champion else GameData.hero_path_id(h)


func _st(h: Hero) -> int:
	return 0 if h == null or h.is_champion else GameData.subclass_stage(h.pool_id)


func _tw(h: Hero, pool_id: String) -> bool:
	return h != null and h.pool_id == pool_id


func _legend(h: Hero) -> bool:
	return h != null and GameData.is_legend(h.pool_id)


func _pp(state: Dictionary, h: Hero) -> Dictionary:
	var all: Dictionary = state.get_or_add("_pp", {})
	return all.get_or_add(h.id, {})


## Living party heroes on Path `pid` at stage >= `stage`.
func _on_path(state: Dictionary, pid: String, stage: int = 1) -> Array:
	return (state["party"] as Array).filter(func(x): return x.hp > 0 and _pa(x) == pid and _st(x) >= stage)


## Path Mastery (0.65): each rank makes the hero's Path rule numbers
## GameData.MASTERY_STEP stronger (1.0 for an unmastered hero or a champion).
func _mx(h: Hero) -> float:
	return 1.0 if h == null or h.is_champion else 1.0 + GameData.MASTERY_STEP * h.mastery


## A Path relic's bend on a rule (0.65), by its "pmod"; 0 when none is equipped.
func _pm(state: Dictionary, key: String) -> float:
	return float(state.get("_pmods", {}).get(key, 0.0))


func _pp_log(state: Dictionary, line: String) -> void:
	(state["log"] as Array).append(line)


# ---------------- Fight start ----------------
func _pp_start(state: Dictionary) -> void:
	state["_pp"] = {}
	var pmods := {}
	for carrier in state["party"]:   # 0.66: a Path relic works while its carrier fights
		if carrier.path_relic != "" and not carrier.is_champion:
			var pd := GameData.find_unique_relic(carrier.path_relic)
			if pd.has("pmod"):
				pmods[str(pd["pmod"])] = float(pd["value"])
			if pd.has("pmod2"):   # its drawback (0.64.1)
				pmods[str(pd["pmod2"])] = float(pd["value2"])
	state["_pmods"] = pmods
	for h in state["party"]:
		var p := _pp(state, h)
		p["mark"] = -1
		p["combo_t"] = -1
		p["combo"] = 1 if _tw(h, "trailblazer") and _pa(h) == "weaponmaster" else 0
		p["heat"] = (2 if _tw(h, "cinder-adept") else 0) + (int(_pm(state, "heat_start")) if _pa(h) == "evocation" else 0)
		p["quiet"] = 1   # Steady Aim: the opening shot counts as unhurried
		p["hit_round"] = -9
	state["_pf"] = {"cancels": (2 if _on_path(state, "augury").any(func(x): return _legend(x)) else 1) if not _on_path(state, "augury").is_empty() else 0,
		"miracles": (2 if _on_path(state, "mercy", 3).any(func(x): return _legend(x)) else 1) if not _on_path(state, "mercy", 3).is_empty() else 0,
		"conjures": 1 if (state["party"] as Array).any(func(x): return _tw(x, "grim-conjurer")) else 0}
	if int(state["_pf"]["cancels"]) > 0:
		state["_pf"]["cancels"] = int(state["_pf"]["cancels"]) + int(_pm(state, "cancels"))
	_resonance_start(state)


# ---------------- Round start (after the turn order is rolled) ----------------
func _pp_round_start(state: Dictionary) -> void:
	var monsters: Array = state["monsters"]
	var living: Array = (state["party"] as Array).filter(func(x): return x.hp > 0)
	var rn := int(state["round_num"])
	for h in living:
		var p := _pp(state, h)
		# Steady Aim: count quiet rounds (not hit last round).
		var hits_last := int(p.get("hits_last", 0))
		if hits_last > 0 and _pa(h) == "marksman" and _pm(state, "steady_keep") > 0 and not p.get("owl", false):
			p["owl"] = true   # Owl-Feather Fletching: the first hit doesn't break Steady Aim
			hits_last -= 1
		p["quiet"] = int(p.get("quiet", 0)) + 1 if hits_last <= (1 if _tw(h, "slinger") else 0) or (_legend(h) and _pa(h) == "marksman") else 0
		p["hits_last"] = 0
		for k in ["mist", "untouch", "vanish", "lastwall", "perfect"]:
			if int(p.get(k, 0)) > 0:
				p[k] = int(p[k]) - 1
	# Warding: Ward Weave on the most-hurt ally (Fledgling Seer: the one a foe is aiming at).
	for w in _on_path(state, "warding"):
		var pick: Hero = null
		if _tw(w, "fledgling-seer"):
			for mi in state.get("intents", {}):
				var aim := _find_party_hero(state["party"], str(state["intents"][mi].get("target", "")))
				if aim and aim.hp > 0:
					pick = aim
					break
		var pool: Array = living.filter(func(x): return x.formation != "back") if _tw(w, "stoneward-mystic") else living
		if pool.is_empty():
			pool = living
		var targets: Array = pool if _legend(w) else []
		if targets.is_empty():
			if pick == null:
				for x in pool:
					if pick == null or float(x.hp) / max_hp(x) < float(pick.hp) / max_hp(pick):
						pick = x
			targets = [pick] if pick else []
			if pick and _pm(state, "ward_two") > 0:   # Loomed Sigil: the next most-hurt too
				var second: Hero = null
				for x in pool:
					if x != pick and (second == null or float(x.hp) / max_hp(x) < float(second.hp) / max_hp(second)):
						second = x
				if second:
					targets.append(second)
		var frac := ((0.12 if _tw(w, "stoneward-mystic") else 0.08) + _pm(state, "ward_frac")) * _mx(w)
		var sh: Dictionary = state["hero_shields"]
		for t in targets:
			sh[t.id] = float(sh.get(t.id, 0.0)) + max_hp(t) * frac
		if not targets.is_empty():
			_proc(state, w, tr("Ward Weave"))
	# Trapper: the first foe to act steps in a snare.
	for t in _on_path(state, "trapper"):
		for e in state["turn_order"]:
			if e["type"] == "monster" and float(monsters[int(e["id"])]["hp"]) > 0 and int(monsters[int(e["id"])].get("_snared", 0)) <= 0:
				_snare(state, t, int(e["id"]))
				break
	if rn == 1 and _pm(state, "snare_two") > 0 and not _on_path(state, "trapper").is_empty():   # Bramble Coil
		for e in state["turn_order"]:
			if e["type"] == "monster" and float(monsters[int(e["id"])]["hp"]) > 0 and int(monsters[int(e["id"])].get("_snared", 0)) <= 0:
				_snare(state, _on_path(state, "trapper")[0], int(e["id"]))
				break
	# Augury Prophecy (stage 3): the first wind-up of the fight is dodged by everyone.
	for a in _on_path(state, "augury", 3):
		var pa := _pp(state, a)
		if pa.get("prophecy_used", false):
			break
		for mi in monsters.size():
			var mw: Dictionary = monsters[mi]
			if float(mw["hp"]) > 0 and mw.get("_winding", false):
				pa["prophecy_used"] = true
				mw["_prophesied"] = true
				gain_momentum(state, 2)
				_pp_log(state, tr("Prophecy: %s saw %s's blow before it began.") % [tr(str(a.name)), tr(str(mw["name"]))])
				_proc(state, a, tr("Prophecy"))
				if _tw(a, "archon-of-storms"):
					var bolt := dmg_of(a) / float(state["raw_sum"]) * float(state["team_dmg_base"]) * 1.2
					mw["hp"] = float(mw["hp"]) - round(bolt)
					_pp_log(state, tr("Lightning strikes %s for %d.") % [tr(str(mw["name"])), int(round(bolt))])
				break
	# Shieldwall: Last Wall's taunt holds for its rounds.
	for g in _on_path(state, "shieldwall", 3):
		if int(_pp(state, g).get("lastwall", 0)) > 0:
			state["_taunt"] = g.id
			state["_taunt_cut"] = 0.0
	# Marksman Held Breath: the held shot fires at the first foe to act.
	for mk in _on_path(state, "marksman", 3):
		var p2 := _pp(state, mk)
		if p2.get("overwatch", false):
			p2["overwatch"] = false
			for e in state["turn_order"]:
				if e["type"] == "monster" and float(monsters[int(e["id"])]["hp"]) > 0:
					p2["ow_shot"] = true
					_pp_log(state, tr("%s lets the held shot fly!") % tr(str(mk.name)))
					_hero_hit(state, mk, int(e["id"]), 1.0, _tw(mk, "rift-piercer"))
					p2["ow_shot"] = false
					break
	# Scrapper: front-row heroes patch themselves up.
	for s in _on_path(state, "scrapper"):
		if (s.formation != "back" or _pm(state, "scrap_back") > 0) and rn > 1:
			_pp_heal(state, s, int(round(max_hp(s) * 0.05 * _mx(s))))


func _snare(state: Dictionary, trapper: Hero, i: int) -> void:
	var m: Dictionary = state["monsters"][i]
	var base := dmg_of(trapper) / float(state["raw_sum"]) * float(state["team_dmg_base"])
	var dmg := base * (1.0 if _tw(trapper, "deadfall-hunter") else 0.5) * (2.0 if _tw(trapper, "trapper") else 1.0) * _mx(trapper)
	m["hp"] = float(m["hp"]) - round(dmg)
	m["_snared"] = 2   # through this round's end, so it acts last next round
	m["_snared_ever"] = true
	var pf: Dictionary = state["_pf"]
	pf["snared"] = int(pf.get("snared", 0)) + 1
	_pp_log(state, tr("%s steps in %s's snare (%d) and will act last.") % [tr(str(m["name"])), tr(str(trapper.name)), int(round(dmg))])
	if _tw(trapper, "wintertide-archer"):
		stun_monster(state, i, 1)
	if _legend(trapper) or _tw(trapper, "wintertide-archer"):
		m["_winding"] = false
		m["_charged"] = false
	if _tw(trapper, "sapling-keeper"):
		var low := _most_hurt(state)
		if low:
			_pp_heal(state, low, int(round(max_hp(low) * 0.04)))
	if _st(trapper) >= 3 and int(pf.get("snared", 0)) >= 3 and not pf.get("kg_used", false):
		pf["kg_used"] = true
		pf["kg"] = 2
		_pp_log(state, tr("Killing Ground! Every snared foe takes 30% more damage."))
		_proc(state, trapper, tr("Killing Ground"))


func _most_hurt(state: Dictionary) -> Hero:
	var low: Hero = null
	for x in state["party"]:
		if x.hp > 0 and (low == null or float(x.hp) / max_hp(x) < float(low.hp) / max_hp(low)):
			low = x
	return low


# ---------------- A hero's hit ----------------
## The Path multiplier on `h`'s hit on foe `ti` (pure: also used by previews).
func _pp_dmg_mult(state: Dictionary, h: Hero, ti: int) -> float:
	var pid := _pa(h)
	var all: Dictionary = state.get("_pp", {})
	var mult := 1.0
	var m: Dictionary = state["monsters"][ti]
	if int(state.get("_pf", {}).get("kg", 0)) > 0 and m.get("_snared_ever", false):
		mult *= 1.3
	if int(m.get("_snared", 0)) > 0:
		mult *= 1.0 + _pm(state, "snare_dmg")
	for other in state["party"]:   # the party's shared Marks (Stalker)
		var op: Dictionary = all.get(other.id, {})
		if other.hp > 0 and _pa(other) == "stalker" and (int(op.get("mark", -1)) == ti or int(op.get("mark2", -1)) == ti):
			mult *= 1.0 + (MARK_BONUS + _pm(state, "mark_bonus")) * _mx(other)
			break
	if pid == "" or not all.has(h.id):
		return mult
	var p: Dictionary = all[h.id]
	match pid:
		"bloodrage":
			var missing := 1.0 - float(h.hp) / maxf(1.0, max_hp(h))
			mult *= 1.0 + minf(BLOODRAGE_CAP + _pm(state, "rage_cap"), missing * 0.5) * _mx(h)
			if p.get("bp", false):
				mult *= 1.5
			if _tw(h, "squire"):
				mult *= 1.1
		"weaponmaster":
			if int(p.get("combo_t", -1)) == ti or (_legend(h) and int(p.get("combo", 0)) > 0):
				mult *= 1.0 + COMBO_STEP * int(p.get("combo", 0)) * _mx(h)
		"marksman":
			var need := 2 if _tw(h, "longshot") else 1
			if int(p.get("quiet", 0)) >= need:
				mult *= 1.0 + (STEADY_BONUS + (_pm(state, "steady_back") if h.formation == "back" else 0.0)) * (2.0 if _tw(h, "longshot") else 1.0) * (2.0 if p.get("ow_shot", false) else 1.0) * _mx(h)
		"stalker":
			if p.get("hunt", false) and int(p.get("mark", -1)) == ti:
				mult *= 1.6
			if p.get("vanish_shot", false) and int(p.get("mark", -1)) == ti:
				mult *= 3.0
		"evocation":
			mult *= 1.0 + HEAT_STEP * int(p.get("heat", 0)) * _mx(h)
		"assassin":
			var below := (0.5 if _legend(h) else EXECUTE_BELOW) + _pm(state, "execute_at")
			if float(m["hp"]) < float(m["max_hp"]) * below:
				mult *= 1.0 + EXECUTE_BONUS * _mx(h)
		"zeal":
			if _tw(h, "vanguard-chaplain") and not p.get("first_done", false):
				mult *= 1.5
	if int(p.get("blessed", -1)) == int(state.get("round_num", 0)):
		mult *= 1.05
	return mult


## Whether `h`'s hit on `ti` ignores armor and wards (a Path's reach).
func _pp_pierce(state: Dictionary, h: Hero, ti: int) -> bool:
	var p: Dictionary = state.get("_pp", {}).get(h.id, {})
	match _pa(h):
		"weaponmaster":
			return (_tw(h, "rift-breaker") or _pm(state, "combo_pierce") > 0) and int(p.get("combo", 0)) >= 4 and int(p.get("combo_t", -1)) == ti
		"bloodrage":
			return _pm(state, "rage_pierce") > 0 and float(h.hp) < max_hp(h) * _pm(state, "rage_pierce")
		"marksman":
			return (_tw(h, "fieldscout") and int(p.get("quiet", 0)) >= 1) or (_tw(h, "rift-piercer") and p.get("ow_shot", false))
	return false


## After `h`'s hit on foe `ti` landed for `dealt` (`was_alive`: it stood before).
func _pp_after_hit(state: Dictionary, h: Hero, ti: int, dealt: float, was_alive: bool) -> void:
	var pid := _pa(h)
	var monsters: Array = state["monsters"]
	var m: Dictionary = monsters[ti]
	var p := _pp(state, h)
	var killed: bool = was_alive and float(m["hp"]) <= 0.0
	if _tw(h, "arcane-pilferer"):
		(state["monster_shields"] as Dictionary).erase(ti)
	match pid:
		"bloodrage":
			if p.get("bp", false):
				p["bp"] = false
				if _tw(h, "berserker"):
					for j in monsters.size():
						if j != ti and float(monsters[j]["hp"]) > 0:
							monsters[j]["hp"] = float(monsters[j]["hp"]) - round(dealt * 0.5)
					_pp_log(state, tr("%s's blow cleaves through every foe!") % tr(str(h.name)))
			if _tw(h, "bloodletter") and dealt > 0:
				var missing := 1.0 - float(h.hp) / maxf(1.0, max_hp(h))
				_pp_heal(state, h, int(round(dealt * 0.01 * floorf(missing * 100.0 / 4.0))))
			if int(p.get("mist", 0)) > 0 and not p.get("cleaving", false):
				p["cleaving"] = true
				for j in monsters.size():
					if j != ti and float(monsters[j]["hp"]) > 0:
						monsters[j]["hp"] = float(monsters[j]["hp"]) - round(dealt * 0.6)
				p["cleaving"] = false
		"weaponmaster":
			var cap := (6 if _tw(h, "warbrand") else 4) + int(_pm(state, "combo_cap"))
			if int(p.get("combo_t", -1)) == ti or _legend(h):
				p["combo"] = mini(cap, int(p.get("combo", 0)) + 1)
			else:
				p["combo"] = 1
			p["combo_t"] = ti
			if _st(h) >= 3 and int(p["combo"]) >= 4 and not p.get("perfect_used", false):
				p["perfect_used"] = true
				p["perfect"] = 2
				_pp_log(state, tr("%s finds Perfect Form: they act twice next round!") % tr(str(h.name)))
				_proc(state, h, tr("Perfect Form"))
		"marksman":
			if int(p.get("called", -1)) == ti and int(p.get("quiet", 0)) >= 1:
				m["_winding"] = false
				m["_charged"] = false
				p["called"] = -1
				_pp_log(state, tr("%s's called shot breaks %s's wind-up!") % [tr(str(h.name)), tr(str(m["name"]))])
				if _tw(h, "blade-dancer"):
					for j in monsters.size():
						if j != ti and float(monsters[j]["hp"]) > 0 and float(monsters[j]["hp"]) < float(monsters[j]["max_hp"]) * 0.4:
							monsters[j]["hp"] = float(monsters[j]["hp"]) - round(dealt * 0.5)
			if not p.get("ow_shot", false):
				p["quiet"] = 0   # the steady shot is spent
		"stalker":
			p["hunt"] = false
			p["vanish_shot"] = false
			if int(p.get("mark", -1)) < 0 or float(monsters[int(p["mark"])]["hp"]) <= 0:
				p["mark"] = ti if not killed else _next_living(monsters, ti)
				if _legend(h):
					p["mark2"] = _next_living(monsters, int(p["mark"]))
			if _tw(h, "stormtracker") and int(p.get("mark", -1)) == ti and dealt > 0:
				var other := _next_living(monsters, ti)
				if other >= 0 and other != ti:
					monsters[other]["hp"] = float(monsters[other]["hp"]) - round(dealt * 0.3)
		"zeal":
			p["first_done"] = true
			if dealt > 0:
				var heal_frac := (FERVOR + _pm(state, "fervor")) * (2.0 if p.get("smiting", false) else 1.0) * _mx(h)
				if _legend(h):
					for x in state["party"]:
						if x.hp > 0:
							_pp_heal(state, x, int(round(dealt * 0.1)))
				else:
					var low := _most_hurt(state)
					if low:
						_pp_heal(state, low, int(round(dealt * heal_frac)))
						if _tw(h, "emberblessed-acolyte"):
							_pp(state, low)["blessed"] = int(state["round_num"]) + 1
			if _tw(h, "lay-brother") and (m.get("_winding", false) or m.get("_charged", false)) and float(m["hp"]) > 0:
				m["_winding"] = false
				m["_charged"] = false
				_pp_log(state, tr("%s breaks %s's wind-up!") % [tr(str(h.name)), tr(str(m["name"]))])
		"scrapper":
			if dealt > 0:
				var steal := (SCRAPPY + _pm(state, "scrappy")) * (2.0 if _legend(h) else 1.0) * _mx(h)
				var got := int(round(dealt * steal))
				_pp_heal(state, h, got)
				if _tw(h, "herbrunner"):
					var low2 := _most_hurt(state)
					if low2 and low2 != h:
						_pp_heal(state, low2, int(round(got * 0.5)))
	# Kills: Assassin's refund and Deathmark, Zeal's Judgment, Ashbound fire, the Cutpurse's purse.
	if killed:
		_pp_on_kill(state, h, ti)


func _next_living(monsters: Array, from: int) -> int:
	for k in monsters.size():
		var j := (from + 1 + k) % monsters.size()
		if float(monsters[j]["hp"]) > 0:
			return j
	return -1


func _pp_on_kill(state: Dictionary, h: Hero, ti: int) -> void:
	var monsters: Array = state["monsters"]
	var pid := _pa(h)
	var p := _pp(state, h)
	if _pm(state, "mark_jump") > 0:   # Hunter's Chalk
		for s in state["party"]:
			if s.hp > 0 and _pa(s) == "stalker" and int(_pp(state, s).get("mark", -1)) == ti:
				_pp(state, s)["mark"] = _next_living(monsters, ti)
	if pid == "zeal" and _pm(state, "zeal_momentum") > 0:   # Judgment Nail
		gain_momentum(state, int(_pm(state, "zeal_momentum")))
	if pid == "assassin" and _pm(state, "execute_resolve") > 0 and not state["_pf"].get("quiet_coin", false):
		state["_pf"]["quiet_coin"] = true
		if GameState.change_resolve(int(_pm(state, "execute_resolve"))) > 0:
			_pp_log(state, tr("The Quiet Coin: +%d Resolve.") % int(_pm(state, "execute_resolve")))
	if pid == "assassin":
		gain_momentum(state, 2)
		if _tw(h, "cutpurse") and not GameState.run.is_empty():
			GameState.coins += 10
		if _st(h) >= 3:
			var chain := int(p.get("deathmarks", 0))
			if chain < (3 if _tw(h, "the-unseen-hand") else 1):
				p["deathmarks"] = chain + 1
				state["turn_order"].insert(int(state["turn_idx"]), {"type": "hero", "id": h.id, "_spd": 0.0})
				_pp_log(state, tr("Deathmark! %s strikes again.") % tr(str(h.name)))
				_proc(state, h, tr("Deathmark"))
	if monsters[ti].has("_burn_mark") or (state.get("_m_burn", {}) as Dictionary).has(ti):
		for ash in state["party"]:
			if ash.hp > 0 and _tw(ash, "ashbound-theorist"):
				for j in monsters.size():
					if float(monsters[j]["hp"]) > 0:
						_burn_foe(state, j, float(state["team_dmg_base"]) * 0.08, 2)
				_pp_log(state, tr("The fire spreads from the fallen foe."))
				break
	if state.get("_res_ember", false):   # Resonance: Ember x3 sets the fallen's neighbours alight
		for j in monsters.size():
			if float(monsters[j]["hp"]) > 0:
				_burn_foe(state, j, float(state["team_dmg_base"]) * 0.05, 2)
	var pf: Dictionary = state["_pf"]
	if not pf.get("judged", false):
		for z in _on_path(state, "zeal", 3):
			if z == h or _tw(z, "radiant-vanguard"):
				pf["judged"] = true
				var j_dmg := dmg_of(z) / float(state["raw_sum"]) * float(state["team_dmg_base"]) * 0.5
				for j in monsters.size():
					if float(monsters[j]["hp"]) > 0:
						monsters[j]["hp"] = float(monsters[j]["hp"]) - round(j_dmg)
						if _tw(z, "sainted-ember"):
							_burn_foe(state, j, j_dmg * 0.3, 2)
				for x in state["party"]:
					if x.hp > 0:
						_pp_heal(state, x, int(round(max_hp(x) * 0.1)))
				_pp_log(state, tr("Judgment! Holy light strikes every foe and mends the party."))
				_proc(state, z, tr("Judgment"))
				break


# ---------------- After a hero's action ----------------
func _pp_after_action(state: Dictionary, h: Hero, action: String) -> void:
	var p := _pp(state, h)
	if _pa(h) == "evocation" and (action == "attack" or action == "ability" or action.begins_with("skill:")):
		var cap := 7 if _tw(h, "apprentice") else 5
		var at := (4 if _tw(h, "pyromancer") else cap) - int(_pm(state, "heat_at"))
		var is_skill: bool = action == "ability" or action.begins_with("skill:")
		if is_skill and int(p.get("heat", 0)) >= at:
			_detonate(state, h)
		else:
			p["heat"] = mini(cap, int(p.get("heat", 0)) + 1)
	if _tw(h, "cinderling") and action == "attack":
		var t := int(state["pending_actions"].get(h.id, {}).get("target", 0))
		if t >= 0 and t < (state["monsters"] as Array).size() and float(state["monsters"][t]["hp"]) > 0:
			_burn_foe(state, t, dmg_of(h) / float(state["raw_sum"]) * float(state["team_dmg_base"]) * 0.1, 2)
	if int(p.get("perfect", 0)) == 1 and not p.get("perfect_extra", false):
		p["perfect_extra"] = true
		state["turn_order"].insert(int(state["turn_idx"]), {"type": "hero", "id": h.id, "_spd": 0.0})
		if _tw(h, "runeblade"):
			state["_attack_mult"] = float(state.get("_attack_mult", 1.0)) * 1.15


func _detonate(state: Dictionary, h: Hero) -> void:
	var p := _pp(state, h)
	var monsters: Array = state["monsters"]
	var heat := int(p.get("heat", 0))
	var base := dmg_of(h) / float(state["raw_sum"]) * float(state["team_dmg_base"]) * (0.25 + 0.1 * heat)
	if _tw(h, "apprentice"):
		var t := _lowest_hp_living_monster_idx(monsters)
		if t >= 0:
			monsters[t]["hp"] = float(monsters[t]["hp"]) - round(base * 2.0)
	else:
		for j in monsters.size():
			if float(monsters[j]["hp"]) > 0:
				monsters[j]["hp"] = float(monsters[j]["hp"]) - round(base)
				if _st(h) >= 3 and not p.get("inferno", false):
					_burn_foe(state, j, base * 0.3, 3)
	if _st(h) >= 3 and not p.get("inferno", false):
		p["inferno"] = true
		_pp_log(state, tr("Inferno! Every foe is left burning."))
		_proc(state, h, tr("Inferno"))
	p["heat"] = 3 if _legend(h) else 0
	_pp_log(state, tr("%s's heat detonates!") % tr(str(h.name)))
	_proc(state, h, tr("Detonate!"))


# ---------------- Techniques ----------------
func _pp_technique(state: Dictionary, h: Hero, pid: String, target_idx: int) -> void:
	var monsters: Array = state["monsters"]
	var party: Array = state["party"]
	var p := _pp(state, h)
	var sh: Dictionary = state["hero_shields"]
	var name := tr(str(GameData.PATHS[pid]["technique"]["name"]))
	_pp_log(state, tr("%s uses %s!") % [tr(str(h.name)), name])
	var tgt := target_idx if target_idx >= 0 and target_idx < monsters.size() and float(monsters[target_idx]["hp"]) > 0 else _first_living_monster_idx(monsters)
	match pid:
		"shieldwall":
			p["hold"] = int(state["round_num"])
			if _tw(h, "iron-guard"):
				for x in party:
					if x.hp > 0 and x.formation == "back":
						sh[x.id] = float(sh.get(x.id, 0.0)) + max_hp(x) * 0.1
		"bloodrage":
			var cost := int(round(max_hp(h) * (0.10 if _tw(h, "berserker") else 0.15)))
			h.hp = maxi(1, h.hp - cost)
			gain_momentum(state, 2)
			p["bp"] = true
			_pp_after_damage(state, h)
		"weaponmaster":
			if tgt >= 0:
				for k in 3:
					if float(monsters[tgt]["hp"]) > 0:
						_hero_hit(state, h, tgt, 0.5)
		"marksman":
			p["called"] = tgt
			p["quiet"] = maxi(1, int(p.get("quiet", 0)))
			if tgt >= 0:
				_hero_hit(state, h, tgt, 1.6, _tw(h, "fieldscout"))
			if _st(h) >= 3 and not p.get("ow_used", false):
				p["ow_used"] = true
				p["overwatch"] = true
				_pp_log(state, tr("%s holds their breath.") % tr(str(h.name)))
		"trapper":
			state["_trap"] = dmg_of(h) / float(state["raw_sum"]) * float(state["team_dmg_base"]) * 0.6
			state["_trap_by"] = h.id
			if _tw(h, "warden"):
				for x in party:
					if x.hp > 0:
						sh[x.id] = float(sh.get(x.id, 0.0)) + max_hp(x) * 0.08
		"stalker":
			if tgt >= 0:
				p["mark"] = tgt
				p["hunt"] = true
				_hero_hit(state, h, tgt, 1.0)
		"evocation":
			p["heat"] = mini(7 if _tw(h, "apprentice") else 5, int(p.get("heat", 0)) + 3)
		"warding":
			for x in party:
				if x.hp > 0:
					sh[x.id] = float(sh.get(x.id, 0.0)) + max_hp(x) * 0.12
		"augury":
			if tgt >= 0:
				monsters[tgt]["_winding"] = false
				monsters[tgt]["_charged"] = false
				var living: Array[Hero] = []
				living.assign(party.filter(func(x): return x.hp > 0))
				if not living.is_empty():
					state["intents"][tgt] = _roll_intent(state, tgt, living)
				_pp_log(state, tr("%s twists %s's fate.") % [tr(str(h.name)), tr(str(monsters[tgt]["name"]))])
			if _tw(h, "verdant-oracle"):
				for x in party:
					if x.hp > 0:
						_pp_heal(state, x, int(round(max_hp(x) * 0.06)))
			if _tw(h, "duskglass-seer"):
				gain_momentum(state, 2)
		"mercy":
			for x in party:
				if x.hp > 0:
					_pp_heal(state, x, int(round(max_hp(x) * 0.10)))
					if _tw(h, "frost-anchorite"):
						for key in ["hero_poison", "hero_burn", "_chilled", "_stunned", "_weakened", "_branded"]:
							state.get(key, {}).erase(x.id)
		"aegis":
			var low := _most_hurt(state)
			if low:
				state.get_or_add("_consecrated", {})[low.id] = int(state["round_num"])
				if _tw(h, "battle-chaplain"):
					_pp(state, low)["dodge_round"] = int(state["round_num"]) + 1
				_pp_log(state, tr("%s is consecrated: no harm this round.") % tr(str(low.name)))
		"zeal":
			if _tw(h, "zealot"):
				h.hp = maxi(1, h.hp - int(round(max_hp(h) * 0.1)))
			if tgt >= 0:
				p["smiting"] = true
				_hero_hit(state, h, tgt, 1.5)
				p["smiting"] = false
				if _tw(h, "ember-confessor") and float(monsters[tgt]["hp"]) > 0 and float(monsters[tgt]["hp"]) < float(monsters[tgt]["max_hp"]) * 0.2:
					monsters[tgt]["hp"] = 0.0
					_pp_log(state, tr("%s's smite finishes %s.") % [tr(str(h.name)), tr(str(monsters[tgt]["name"]))])
					_pp_on_kill(state, h, tgt)
		"assassin":
			if tgt >= 0:
				_hero_hit(state, h, tgt, 1.3)
			if _tw(h, "wraithstep"):
				p["vanish"] = 1
		"skirmisher":
			p["feint"] = int(state["round_num"])
			if _tw(h, "rift-slipper") and not state.get("wipe_guard_used", false):
				state["wipe_guard"] = maxf(float(state["wipe_guard"]), 0.25)
		"scrapper":
			if tgt >= 0:
				for k in (2 if _tw(h, "fleetblade") else 1):
					if float(monsters[tgt]["hp"]) > 0:
						_hero_hit(state, h, tgt, 1.0)
				if float(monsters[tgt]["hp"]) > 0 and str(monsters[tgt].get("tier", "")) != "boss":
					stun_monster(state, tgt, 1)
				gain_momentum(state, 2)


# ---------------- Incoming blows ----------------
## Who a foe's aimed blow really lands on: a Vanished hero can't be picked,
## a Skirmisher's Feint draws half of them.
func _pp_retarget(state: Dictionary, m: Dictionary, target: Hero) -> Hero:
	var living: Array = (state["party"] as Array).filter(func(x): return x.hp > 0)
	var rn := int(state["round_num"])
	for s in living:
		if s != target and _pa(s) == "skirmisher" and int(_pp(state, s).get("feint", -1)) == rn and randf() < 0.5:
			return s
	if int(_pp(state, target).get("vanish", 0)) > 0 or int(_pp(state, target).get("untouch", 0)) > 0:
		var others: Array = living.filter(func(x): return x != target and int(_pp(state, x).get("vanish", 0)) <= 0)
		if not others.is_empty():
			return others[randi() % others.size()]
	return target


## Multiplier on a blow `back` aimed at `target` from foe `m`.
func _pp_taken_mult(state: Dictionary, m: Dictionary, target: Hero) -> float:
	var mult := 1.0
	var rn := int(state["round_num"])
	if int(state.get("_consecrated", {}).get(target.id, -9)) == rn:
		return 0.0
	if int(_pp(state, target).get("untouch", 0)) > 0 or int(_pp(state, target).get("vanish", 0)) > 0:
		return 0.0
	match _pa(target):   # Path relic drawbacks (0.64.1)
		"shieldwall":
			mult *= 1.0 + _pm(state, "guard_taken")
		"zeal":
			mult *= 1.0 + _pm(state, "zeal_taken")
		"skirmisher":
			mult *= 1.0 + _pm(state, "skirm_taken")
	for a in _on_path(state, "aegis"):
		var cut := (SANCTUARY * (2.0 if _legend(a) else 1.0) + _pm(state, "sanctuary")) * _mx(a)
		if _tw(a, "frostward-sister") and target.formation != "back":
			cut += 0.04
		mult *= 1.0 - cut
		break
	if int(state.get("_pf", {}).get("hallowed", 0)) > 0:
		mult *= 0.5
	if _tw(target, "squire"):
		mult *= 1.1
	if _tw(target, "ironhide-footpad") and target.formation != "back":
		mult *= 0.9
	if m.get("_snared", 0) and (state["party"] as Array).any(func(x): return x.hp > 0 and _tw(x, "pathfinder")):
		mult *= 0.9
	for s in (state["party"] as Array):
		if s.hp > 0 and _tw(s, "shadowtracker") and (state["monsters"] as Array).find(m) == int(_pp(state, s).get("mark", -2)):
			mult *= 0.9
			break
	return mult


## Extra dodge `target` has against foe `m` from Paths.
func _pp_dodge(state: Dictionary, target: Hero, m: Dictionary) -> float:
	var d := 0.0
	var p := _pp(state, target)
	match _pa(target):
		"skirmisher":
			d += (EVASION + _pm(state, "evasion")) * _mx(target)
			if int(p.get("feint", -1)) == int(state["round_num"]):
				d += 0.25
		"weaponmaster":
			if _tw(target, "featherguard"):
				d += 0.03 * int(p.get("combo", 0))
		"stalker":
			if _tw(target, "duskstalker") and int(p.get("mark", -1)) >= 0:
				d += 0.15
	if int(p.get("dodge_round", -9)) == int(state["round_num"]):
		d += 0.2
	for s in (state["party"] as Array):
		if s.hp > 0 and _tw(s, "nightwarden") and (state["monsters"] as Array).find(m) == int(_pp(state, s).get("mark", -2)):
			d += 0.15
			break
	if m.get("_charged", false) and m.get("_prophesied", false):
		d += 1.0   # Prophecy: everyone saw this one coming
	return d


## A foe's heavy blow about to land: Augury's Foresight cancels the first one.
func _pp_cancel_heavy(state: Dictionary, m: Dictionary) -> bool:
	var pf: Dictionary = state.get("_pf", {})
	if int(pf.get("cancels", 0)) <= 0:
		return false
	var seers := _on_path(state, "augury")
	if seers.is_empty() or randf() >= _mx(seers[0]) - 1.0:   # Mastery: a chance the cancel isn't spent
		pf["cancels"] = int(pf["cancels"]) - 1
	if _pm(state, "cancel_momentum") > 0:   # Omen Bones
		gain_momentum(state, int(_pm(state, "cancel_momentum")))
	_pp_log(state, tr("Foresight: the party saw %s's blow coming and it comes to nothing.") % tr(str(m["name"])))
	for a in _on_path(state, "augury"):
		_proc(state, a, tr("Foresight"))
		if _tw(a, "shade-adept"):
			m["_marked"] = float(m.get("_marked", 0.0)) + 0.15
		break
	return true


## A blow aimed at a back-row hero: Shieldwall's Guardian takes a share.
## Returns the part left for `target`; the rest lands on the guardian.
func _pp_guardian_share(state: Dictionary, m: Dictionary, target: Hero, back: float) -> float:
	if back <= 0.0:
		return back
	for g in _on_path(state, "shieldwall"):
		if g == target or g.formation == "back":
			continue
		if target.formation != "back" and not _legend(g):
			continue
		var hold: bool = int(_pp(state, g).get("hold", -9)) == int(state["round_num"]) and target.formation == "back"
		var share := 1.0 if hold else minf(0.9, ((0.4 if _tw(g, "bulwark") else 0.25) + _pm(state, "guard_share")) * _mx(g))
		var taken := back * share * (0.7 if hold else 1.0)
		var sh: Dictionary = state["hero_shields"]
		var absorbed: float = minf(float(sh.get(g.id, 0.0)), taken)
		sh[g.id] = float(sh.get(g.id, 0.0)) - absorbed
		g.hp = maxi(0, g.hp - int(round(taken - absorbed)))
		_pp_log(state, tr("%s takes %d of the blow meant for %s.") % [tr(str(g.name)), int(round(taken)), tr(str(target.name))])
		if _pm(state, "guard_momentum") > 0 and int(_pp(state, g).get("rivet", -9)) != int(state["round_num"]):   # Oathplate Rivets
			_pp(state, g)["rivet"] = int(state["round_num"])
			gain_momentum(state, int(_pm(state, "guard_momentum")))
		if _tw(g, "footman") and not m.get("_shoved", false):
			m["_shoved"] = true
			m["dmg"] = float(m["dmg"]) * 0.9
		if _tw(g, "fieldmender"):
			_pp_heal(state, target, int(round(max_hp(target) * 0.05)))
		if _tw(g, "frostguard"):
			m["_slow"] = 2
		_pp_after_damage(state, g)
		return back * (1.0 - share)
	return back


## A blow that would fell `target`: Last Wall (Shieldwall stage 3) takes it.
func _pp_last_wall(state: Dictionary, target: Hero, dmg: int) -> Hero:
	if dmg < target.hp:
		return target
	for g in _on_path(state, "shieldwall", 3):
		var p := _pp(state, g)
		if g != target and not p.get("lastwall_used", false):
			p["lastwall_used"] = true
			p["lastwall"] = 2
			state["hero_shields"][g.id] = float(state["hero_shields"].get(g.id, 0.0)) + max_hp(g) * 0.3
			state["_taunt"] = g.id
			_pp_log(state, tr("Last Wall! %s throws themself in front of %s.") % [tr(str(g.name)), tr(str(target.name))])
			_proc(state, g, tr("Last Wall"))
			return g
	return target


## After foe `i`'s blow on `target` (dealt > 0) or a dodge (`evaded`).
func _pp_after_struck(state: Dictionary, i: int, target: Hero, dealt: int, evaded: bool) -> void:
	var m: Dictionary = state["monsters"][i]
	var p := _pp(state, target)
	p["hits_last"] = int(p.get("hits_last", 0)) + (0 if evaded else 1)
	if evaded and _pa(target) == "skirmisher":
		gain_momentum(state, 1)
		var jab := float(state["team_dmg_base"]) * (1.0 if _legend(target) else (0.6 if _tw(target, "skirmisher") else 0.3)) * dmg_of(target) / maxf(1.0, float(state["raw_sum"])) * 2.0 * (1.0 + _pm(state, "jab"))
		m["hp"] = float(m["hp"]) - round(jab)
		if _tw(target, "glyphhand"):
			(state["monster_shields"] as Dictionary).erase(i)
		_pp_log(state, tr("%s dodges and jabs back for %d.") % [tr(str(target.name)), int(round(jab))])
		if _tw(target, "runaway"):
			var low := _most_hurt(state)
			if low:
				state["hero_shields"][low.id] = float(state["hero_shields"].get(low.id, 0.0)) + max_hp(low) * 0.05
		if _tw(target, "footpad") and not p.get("first_dodge", false):
			gain_momentum(state, 3)
		p["first_dodge"] = true
		p["dodges"] = int(p.get("dodges", 0)) + 1
		if _st(target) >= 3 and int(p["dodges"]) >= (2 if _tw(target, "wraithblade-adept") else 3) and not p.get("untouch_used", false):
			p["untouch_used"] = true
			p["untouch"] = 3
			_pp_log(state, tr("%s is untouchable!") % tr(str(target.name)))
			_proc(state, target, tr("Untouchable"))
	if evaded:
		return
	if _tw(target, "stormcaller") and _pa(target) == "evocation":
		p["heat"] = mini(5, int(p.get("heat", 0)) + 1)
	if _tw(target, "stormguard") and int(p.get("lastwall", 0)) > 0 and float(m["hp"]) > 0:
		stun_monster(state, i, 1)
	if _tw(target, "bramblefoot") and dealt > 0:
		m["hp"] = float(m["hp"]) - round(dealt * 0.1)
	if _tw(target, "duelist") and int(p.get("combo_t", -1)) == i and target.hp > 0:
		var counter := dmg_of(target) / maxf(1.0, float(state["raw_sum"])) * float(state["team_dmg_base"]) * 0.35
		m["hp"] = float(m["hp"]) - round(counter)
		_pp_log(state, tr("%s counters %s for %d.") % [tr(str(target.name)), tr(str(m["name"])), int(round(counter))])
	if target.hp > 0 and (state["party"] as Array).any(func(x): return x.hp > 0 and _tw(x, "thornweaver")) and not p.get("thorn_round", -1) == int(state["round_num"]):
		p["thorn_round"] = int(state["round_num"])
		_pp_heal(state, target, int(round(max_hp(target) * 0.04)))
	if _st(target) >= 3 and _pa(target) == "stalker" and not p.get("vanish_used", false) and target.hp > 0:
		p["vanish_used"] = true
		p["vanish"] = 3 if _tw(target, "voidwalker") else 2
		p["vanish_shot"] = true
		_pp_log(state, tr("%s vanishes!") % tr(str(target.name)))
		_proc(state, target, tr("Vanish"))
	_pp_after_damage(state, target)


## HP thresholds after damage: Red Mist, Second Wind, Hallowed Ground; a fall
## caught by Miracle or the Grim Conjurer.
func _pp_after_damage(state: Dictionary, h: Hero) -> void:
	var p := _pp(state, h)
	var frac := float(h.hp) / maxf(1.0, max_hp(h))
	if h.hp > 0 and _pa(h) == "bloodrage" and _st(h) >= 3 and not p.get("mist_used", false) and frac < (0.5 if _legend(h) else 0.3):
		p["mist_used"] = true
		p["mist"] = 4
		_pp_log(state, tr("Red Mist! %s's attacks hit every foe.") % tr(str(h.name)))
		_proc(state, h, tr("Red Mist"))
	if h.hp > 0 and _pa(h) == "scrapper" and _st(h) >= 3 and not p.get("sw_used", false) and frac < (0.4 if _tw(h, "duskrunner") else 0.25):
		p["sw_used"] = true
		p["sw_double"] = 2
		_pp_heal(state, h, int(round(max_hp(h) * 0.5)))
		_pp_log(state, tr("Second Wind! %s gets back up swinging.") % tr(str(h.name)))
		_proc(state, h, tr("Second Wind"))
	var pf: Dictionary = state.get("_pf", {})
	if not pf.get("hallowed_used", false):
		for a in _on_path(state, "aegis", 3):
			var cur := 0.0
			var mx := 0.0
			for x in state["party"]:
				cur += maxf(0, x.hp)
				mx += max_hp(x)
			if mx > 0.0 and cur / mx < (0.7 if _tw(a, "sanctified-shield") else 0.5):
				pf["hallowed_used"] = true
				pf["hallowed"] = 2
				_pp_log(state, tr("Hallowed Ground! Damage to the party is halved."))
				_proc(state, a, tr("Hallowed Ground"))
			break
	if h.hp <= 0:
		if int(pf.get("miracles", 0)) > 0 and not _on_path(state, "mercy", 3).is_empty():
			pf["miracles"] = int(pf["miracles"]) - 1
			var healer: Hero = _on_path(state, "mercy", 3)[0]
			h.hp = maxi(1, int(round(max_hp(h) * ((0.5 if _tw(healer, "alchemist") else 0.3) + _pm(state, "miracle_hp")))))
			_pp_log(state, tr("Miracle! %s rises again.") % tr(str(h.name)))
			_proc(state, healer, tr("Miracle"))
			if _tw(healer, "dawnkeeper"):
				for x in state["party"]:
					if x.hp > 0:
						state["hero_shields"][x.id] = float(state["hero_shields"].get(x.id, 0.0)) + max_hp(x) * 0.15
		elif int(pf.get("conjures", 0)) > 0:
			pf["conjures"] = int(pf["conjures"]) - 1
			h.hp = maxi(1, int(round(max_hp(h) * 0.15)))
			_pp_log(state, tr("The Grim Conjurer pulls %s back from the dark.") % tr(str(h.name)))


## True when `h`'s next turn is lost to a stun (resolve_turn skips it), so the
## screen plays it as a skipped turn instead of offering the action bar.
func hero_loses_turn(state: Dictionary, h: Hero) -> bool:
	return state.get("_stunned", {}).has(h.id) and not _pp_stun_immune(state, h)


## A stun on `h` that a Path shrugs off (Red Mist, a Scrapper Legend).
func _pp_stun_immune(state: Dictionary, h: Hero) -> bool:
	return int(_pp(state, h).get("mist", 0)) > 0 or (_legend(h) and _pa(h) == "scrapper")


# ---------------- Healing ----------------
## Heals `h` by `amount`: Mercy's Overflow turns the excess into a ward (not the party mend's),
## Red Mist refuses it. Returns the HP restored.
func _pp_heal(state: Dictionary, h: Hero, amount: int, overflow := true) -> int:
	if amount <= 0 or h.hp <= 0 or int(_pp(state, h).get("mist", 0)) > 0:
		return 0
	# Path relic drawbacks (0.64.1): Brimming Chalice, Red Tooth Torc.
	amount = int(round(amount * (1.0 - _pm(state, "heal_cut")) * (1.0 - (_pm(state, "rage_heal_cut") if _pa(h) == "bloodrage" else 0.0))))
	if amount <= 0:
		return 0
	var room := max_hp(h) - h.hp
	var healed := mini(room, amount)
	h.hp += healed
	var over := amount - healed
	if over > 0 and overflow:
		for c in _on_path(state, "mercy"):
			var ward := float(over) * (0.5 + _pm(state, "overflow")) * (1.5 if _tw(c, "peddler") else 1.0) * _mx(c)
			var sh: Dictionary = state["hero_shields"]
			sh[h.id] = minf(float(sh.get(h.id, 0.0)) + ward, max_hp(h) * 0.2)
			break
	if healed > 0 and (state["party"] as Array).any(func(x): return x.hp > 0 and _tw(x, "acolyte")):
		for key in ["hero_poison", "hero_burn", "_weakened"]:
			if state.get(key, {}).has(h.id):
				state[key].erase(h.id)
				break
	if healed > 0 and (state["party"] as Array).any(func(x): return x.hp > 0 and _tw(x, "herbalist")):
		_pp(state, h)["regen"] = 2
	return healed


# ---------------- Round end ----------------
func _pp_round_end(state: Dictionary) -> void:
	var pf: Dictionary = state.get("_pf", {})
	for k in ["hallowed", "kg", "mirror"]:
		if int(pf.get(k, 0)) > 0:
			pf[k] = int(pf[k]) - 1
	for m in state["monsters"]:
		for k in ["_snared", "_slow"]:
			if int(m.get(k, 0)) > 0:
				m[k] = int(m[k]) - 1
	for h in state["party"]:
		if h.hp <= 0:
			continue
		var p := _pp(state, h)
		if int(p.get("regen", 0)) > 0:
			p["regen"] = int(p["regen"]) - 1
			h.hp = mini(max_hp(h), h.hp + int(round(max_hp(h) * 0.03)))
		if _tw(h, "hearth-warden"):
			for x in state["party"]:
				if x.hp > 0:
					_pp_heal(state, x, int(round(max_hp(x) * 0.02)))


# ---------------- Auto (Quick fight, Auto, the sims) ----------------
## A Technique worth using now, or {} (Momentum and row already checked by the caller).
func _pp_auto(state: Dictionary, h: Hero) -> Dictionary:
	var tech := GameData.hero_technique(h)
	if tech.is_empty() or action_block(state, h, "skill:" + str(tech["id"])) != "":
		return {}
	var act := "skill:" + str(tech["id"])
	var monsters: Array = state["monsters"]
	var tgt: int = maxi(0, _lowest_hp_living_monster_idx(monsters))
	var hurt: Array = (state["party"] as Array).filter(func(x): return x.hp > 0 and x.hp < max_hp(x) * 0.5)
	var winding := -1
	for mi in monsters.size():
		if float(monsters[mi]["hp"]) > 0 and (monsters[mi].get("_winding", false) or monsters[mi].get("_charged", false)):
			winding = mi
	match _pa(h):
		"bloodrage":
			if h.hp > max_hp(h) * 0.5:
				return {"action": act, "target": tgt}
		"mercy":
			if hurt.size() >= 2:
				return {"action": act, "target": 0}
		"aegis":
			if not hurt.is_empty() or winding >= 0:
				return {"action": act, "target": 0}
		"shieldwall", "skirmisher":
			if winding >= 0:
				return {"action": act, "target": 0}
		"augury", "marksman":
			if winding >= 0:
				return {"action": act, "target": winding}
		"warding", "trapper":
			if int(state.get("momentum", 0)) >= 6:
				return {"action": act, "target": 0}
		"evocation":
			if int(_pp(state, h).get("heat", 0)) <= 2:
				return {"action": act, "target": 0}
		_:
			if int(state.get("momentum", 0)) >= int(tech["cost"]) + 2:
				return {"action": act, "target": tgt}
	return {}


# ---------------- Resonance (shared elements) ----------------
## Two or more living heroes of one element in the party light up a bonus
## (GameData.RESONANCE): applied once at the fight's start.
func _resonance_start(state: Dictionary) -> void:
	var counts := resonance_counts(state["party"])
	var log: Array = state["log"]
	for el in counts:
		var n := int(counts[el])
		if n < 2:
			continue
		var big := n >= 3
		match str(el):
			"Ember":
				state["team_dmg_base"] = float(state["team_dmg_base"]) * (1.12 if big else 1.06)
				state["_res_ember"] = big
			"Frost":
				state["_res_frost"] = 0.10 if big else 0.05
				state["_res_frost_first"] = big
			"Verdant":
				state["mend"] = float(state["mend"]) + (0.06 if big else 0.03)
			"Umbral":
				state["dodge"] = minf(GameData.DODGE_CAP, float(state["dodge"]) + (0.10 if big else 0.05))
			"Arcane":
				gain_momentum(state, 2 if big else 1)
				state["_res_arcane"] = big
		log.append(tr("Resonance: %s ×%d") % [tr(str(el)), n])


## Living heroes per element.
func resonance_counts(party: Array) -> Dictionary:
	var out := {}
	for h in party:
		if h.hp > 0 and h.type != "":
			out[h.type] = int(out.get(h.type, 0)) + 1
	return out


## A hero's ward soaked part of foe `i`'s blow (`broke`: it's gone now):
## Warding's Mirror Ward (stage 3) and the Frost Scholar's chill.
func _pp_ward_struck(state: Dictionary, i: int, absorbed: float, broke: bool) -> void:
	var m: Dictionary = state["monsters"][i]
	var pf: Dictionary = state.get("_pf", {})
	var wards: Array = _on_path(state, "warding")
	if wards.is_empty():
		return
	if int(pf.get("mirror", 0)) > 0 and absorbed > 0.0:
		m["hp"] = float(m["hp"]) - round(absorbed)
		_pp_log(state, tr("The ward reflects %d back at %s.") % [int(round(absorbed)), tr(str(m["name"]))])
	if not broke:
		return
	for w in wards:
		if _tw(w, "frost-scholar"):
			m["_slow"] = 2
		if _st(w) >= 3 and not pf.get("mirror_used", false):
			pf["mirror_used"] = true
			pf["mirror"] = 2
			_pp_log(state, tr("Mirror Ward! Every ward reflects damage for 2 rounds."))
			_proc(state, w, tr("Mirror Ward"))
			if _tw(w, "rift-warden-magus"):
				for mm in state["monsters"]:
					if mm.get("_winding", false) or mm.get("_charged", false):
						mm["_winding"] = false
						mm["_charged"] = false
						_pp_log(state, tr("%s's wind-up shatters on the ward.") % tr(str(mm["name"])))
						break
