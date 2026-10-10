extends "res://scripts/autoload/combat/CombatGen.gd"
## Combat, part 3b: the Paths' rules in a fight (the _pp_* hooks Combat.gd
## calls), and the small fight helpers they share with it (Momentum, action
## costs, a hero's hit, stuns, burns, foe intents). Split out of Combat.gd in
## 0.69.2; like every part of the chain it only calls down.


## True if `h` has an Ability at all (a trained subclass, 0.62) — used to
## gate both the combat action-button row and the Ability's cooldown ticking.
static func qualifies_for_ability(h: Hero) -> bool:
	return GameData.SUBCLASS_ABILITIES.has(h.pool_id)   # 0.62: comes with the subclass (base classes have none)


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


func _find_party_hero(party: Array[Hero], hero_id: String) -> Hero:
	for h in party:
		if h.id == hero_id:
			return h
	return null


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


## A foe burns for `per_round` damage at each round's end for `rounds` rounds
## (the stronger burn wins).
func _burn_foe(state: Dictionary, i: int, per_round: float, rounds: int) -> void:
	var burns: Dictionary = state.get_or_add("_m_burn", {})
	var old: Dictionary = burns.get(i, {})
	if old.is_empty() or float(old["dmg"]) * int(old["rounds"]) < per_round * rounds:
		burns[i] = {"dmg": per_round, "rounds": rounds}


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
