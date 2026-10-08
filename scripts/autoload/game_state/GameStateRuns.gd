extends "res://scripts/autoload/game_state/GameStateModes.gd"
## GameState, part 6: rift runs — nodes, fights, events, shops, hazards, sealing, recovery, the Endless Rift payout.


## `rift_rank` is a ladder rank (start_ladder_rift) or "" for unranked runs
## (daily, finale). relic_rarity_floor_down is read by Party Assembly's
## starting-relic roll, which happens before the run exists.
func start_run(diff_id: String, hero_ids: Array[String], starting_relic: Relic, rift_rank: String = "") -> void:
	last_party = hero_ids.duplicate()
	var shield := 0
	for r in Combat.equipped_relics():
		shield += r.hp
	if starting_relic:
		shield += starting_relic.hp
		starting_relic.id = "rl" + str(next_id)
		next_id += 1
		starting_relic.equipped = false
		relics.append(starting_relic)
	var diff: Dictionary = GameData.DIFFICULTIES[0]
	for d in GameData.DIFFICULTIES:
		if d["id"] == diff_id:
			diff = d
	diff = _apply_rift_rank_modifiers(diff, rift_rank)
	var training := runs_started == 0 and rift_rank in ["", "F"]
	if training:
		diff = _apply_training(diff)
	runs_started += 1
	run = {
		"diff_id": diff_id,
		"layers": Combat.build_layers(diff), "pos": 0, "chosen": {},
		"hero_ids": hero_ids, "shield": shield, "boss_rounds": 0,
		"node_kind": "", "node_state": {}, "sealed": null, "anchor_used": false,
		"start_coins": coins, "start_crystals": crystals, "heroes_lost": 0, "start_snap": run_snapshot(hero_ids),
		"rift_rank": rift_rank, "seed": randi(), "training": training, "biome": pick_biome(true),
		"overseer": overseer if champions.has(overseer) else "",
		"resolve": GameData.RESOLVE_START + int(year_add("resolve_start")),
	}
	if next_resolve != 0 and resolve_on():   # a blessing (or a bad night) at camp
		run["resolve"] = clampi(int(run["resolve"]) + next_resolve, 0, GameData.RESOLVE_MAX)
		next_resolve = 0
	if training:
		# No elites in the training rift — a campfire takes their place.
		for layer in run["layers"]:
			layer["options"] = (layer["options"] as Array).map(func(o): return "campfire" if o == "elite" else o)
	auto_resolve_single_option()
	save()
	state_changed.emit()


## The rift rank newly generated items drop at (GameData.ITEM_RANK_MULT): a
## ladder rift's own rank; an unranked Greater run reads as C; Lesser and
## anything outside a run (shop restock etc.) is F.
func loot_rank() -> String:
	if run.is_empty():
		return "F"
	var mapped: String = str(run.get("rift_rank", ""))
	if mapped != "":
		return mapped
	if run.get("diff_id", "") == "greater":
		return "C"
	return "F"


## Announces each feature the first time it unlocks (once per render, like
## check_milestones). Returns the ids newly announced.
## The Broken Accord: a champion freed from the Endless Rift leaves their post
## empty, and the next Riftbreak comes sooner (told once).
func _empty_post() -> void:
	if breach_next_day > day + 1:
		breach_next_day = maxi(day + 1, breach_next_day - GameData.EMPTY_POST_DAYS)
	if not hints_seen.has("empty_post"):
		hints_seen.append("empty_post")
		pending_stories.append(GameData.EMPTY_POST.duplicate())


func check_feature_unlocks() -> Array:
	var fresh: Array = []
	for f in GameData.FEATURE_UNLOCKS:
		if not features_seen.has(f) and feature_unlocked(f):
			features_seen.append(f)
			fresh.append(f)
	if fresh.has("rival"):   # the Charter War begins
		var card: Dictionary = (GameData.MOOT_NOTICE if moot() else GameData.ROYAL_CHARTER).duplicate()   # the epilogue's Vale
		card["text"] = tr(str(card["text"])) % [tr(str(rival_name)), tr(str(rival_leader()["leader"]))]
		if grudge != "":   # the Vale remembers: an old score
			card["text"] = str(card["text"]) + "\n\n" + tr(GameData.GRUDGE_NOTICE) % [tr(str(rival_name)), grudge, GameData.GRUDGE_LAURELS]
		pending_stories.append(card)
	# A person brings the bigger news in (a story card); the rest are toasts.
	# A returning player gets toasts only.
	var told: Array = fresh.filter(func(f): return GameData.FEATURE_UNLOCKS[f].has("who") and not veteran_reveal())
	for f in told:
		var def: Dictionary = GameData.FEATURE_UNLOCKS[f]
		pending_stories.append({"title": tr("New: %s") % tr(str(def["name"])), "subtitle": tr(str(def["who"])), "text": tr(str(def["news"]))})
	var rest: Array = fresh.filter(func(f): return not told.has(f))
	if rest.size() == 1:
		var def: Dictionary = GameData.FEATURE_UNLOCKS[rest[0]]
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("New: %s") % tr(str(def["name"])), "text": str(def["news"])})
	elif rest.size() > 1:
		# Several at once: one toast, not a stack.
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("New at camp"), "text": ", ".join(rest.map(func(f): return tr(str(GameData.FEATURE_UNLOCKS[f]["name"])))) + tr(" — check the tabs above.")})
	if not fresh.is_empty():
		save()
	return fresh


func hint_pending(id: String) -> bool:
	return not tips_off and not hints_seen.has(id)


func _see_hint(id: String) -> void:
	if not hints_seen.has(id):
		hints_seen.append(id)


func dismiss_hint(id: String) -> void:
	if not hints_seen.has(id):
		hints_seen.append(id)
	save()


## The kinds the party can take on this floor: on a lane map, only the
## nodes linked from where they stand (each kind once).
func current_layer_options() -> Array:
	var layers: Array = run["layers"]
	var opts: Array = layers[int(run["pos"])]["options"]
	var reach := reachable_options()
	if reach.size() == opts.size():
		return opts
	var out: Array = []
	for i in reach:
		if not out.has(opts[i]):
			out.append(opts[i])
	return out


## The node indices on this floor the party can step to (0.65 lane map):
## the ones linked from their node on the floor before; every node otherwise.
func reachable_options() -> Array:
	var layers: Array = run["layers"]
	var pos := int(run["pos"])
	var all: Array = range((layers[pos]["options"] as Array).size())
	var at: Dictionary = run.get("at", {})
	if pos == 0 or not (layers[pos - 1] as Dictionary).has("next") or not at.has(pos - 1):
		return all
	var links: Array = layers[pos - 1]["next"]
	var from := int(at[pos - 1])
	if from < 0 or from >= links.size():
		return all
	var out: Array = []
	for i in links[from]:
		if int(i) < all.size() and not out.has(int(i)):
			out.append(int(i))
	return out if not out.is_empty() else all


## A Trapper or a Stalker in the party scouts the whole rift (0.65).
func party_scouts() -> bool:
	return current_party().any(func(h): return (h.path if h.path != "" else GameData.path_of(h.pool_id)) in ["trapper", "stalker"])


## Steps onto node `idx` of this floor (the lane map's click).
func choose_node(idx: int) -> void:
	if not reachable_options().has(idx):
		return
	var at: Dictionary = run.get("at", {})
	at[int(run["pos"])] = idx
	run["at"] = at
	choose_node_type(str(run["layers"][int(run["pos"])]["options"][idx]))


func auto_resolve_single_option() -> void:
	var reach := reachable_options()
	var chosen: Dictionary = run["chosen"]
	if reach.size() == 1 and not chosen.has(int(run["pos"])):
		choose_node(int(reach[0]))


func choose_node_type(kind: String) -> void:
	var pos := int(run["pos"])
	var at: Dictionary = run.get("at", {})
	if not at.has(pos):   # by kind (the sims, tests, Auto): the first linked node of it
		for i in reachable_options():
			if str(run["layers"][pos]["options"][i]) == kind:
				at[pos] = i
				break
		run["at"] = at
	var chosen: Dictionary = run["chosen"]
	chosen[int(run["pos"])] = kind
	run["chosen"] = chosen
	run["node_kind"] = kind
	run["node_state"] = {}
	save()
	state_changed.emit()


func current_node_kind() -> String:
	var chosen: Dictionary = run.get("chosen", {})
	return chosen.get(int(run.get("pos", 0)), "")


## Rolls the battle backdrop the moment a fresh combat node is stood on
## (called from the pre-engage screen), rather than leaving it to
## Combat.start_combat() at Engage time — so the "encounter awaits" screen
## and the arena you fight in are the same room instead of a jarring swap.
func ensure_combat_bg() -> void:
	var ns: Dictionary = run.get("node_state", {})
	if ns.has("bg_idx") or ns.has("combat_state"):
		return
	var bgs: Array = GameData.BIOMES.get(run_biome(), {}).get("backgrounds", [])
	ns["bg_idx"] = int(bgs[randi() % bgs.size()]) if not bgs.is_empty() else randi() % GameData.BATTLE_BACKGROUNDS.size()
	run["node_state"] = ns


## The foes engage_node() will roll on this floor (same seed, same diff),
## for the room screen before Engage. gen_monsters() only reads state.
func preview_foes() -> Array:
	if run.is_empty() or not run.has("pos"):
		return []
	var kind := current_node_kind()
	if not kind in ["combat", "elite", "boss", "pillar"]:
		return []
	var diff := _diff()
	if kind == "pillar":
		diff = diff.duplicate()
		diff.erase("boss_name")
	seed(hash([int(run.get("seed", 0)), int(run["pos"])]))
	var floor_i := int(run["pos"]) % GameData.DESCENT_FLOORS if run.has("descent") else int(run["pos"])
	var foes: Array = Combat.gen_monsters(diff, floor_i, "boss" if kind == "pillar" else kind)
	randomize()
	return foes


func engage_node() -> void:
	var diff := _diff()
	var party: Array[Hero] = []
	party.assign(current_party().filter(func(h): return not h.is_downed() and h.hp > 0))
	if party.is_empty():
		return
	# The party as it stood before the fight: a reload mid-fight (which can't
	# keep the fight itself) puts it back, so the fight starts over fairly.
	var pre_hp := {}
	for h in current_party():
		pre_hp[h.id] = [h.hp, h.down_runs]
	var kind := current_node_kind()
	if run.has("tower"):
		for h in party:
			h.hp = Combat.max_hp(h)
	if kind == "pillar":   # a lost champion's pillar: its keeper fights as a rift warden
		diff = diff.duplicate()
		diff.erase("boss_name")
	seed(hash([int(run.get("seed", 0)), int(run["pos"])]))
	var floor_i := int(run["pos"]) % GameData.DESCENT_FLOORS if run.has("descent") else int(run["pos"])
	var state := Combat.start_combat(party, "boss" if kind == "pillar" else kind, diff, floor_i)
	var feat_pre := coming_feat()
	if feat_pre != "":
		state["feat"] = Combat.roll_feat(state, kind, feat_pre)   # an optional objective, by hand
	randomize()
	var prior_bg_idx := int(run["node_state"].get("bg_idx", -1))
	if prior_bg_idx >= 0:
		state["background_idx"] = prior_bg_idx
	for m in state["monsters"]:
		# Boss names are generated as "Vaelith, Lesser Warden" — split off the
		# difficulty suffix so the same boss counts as seen regardless of tier.
		var mname := str(m["name"]).split(",")[0]
		if not monsters_seen.has(mname):
			monsters_seen.append(mname)
	# bg_idx stays alongside so a reload mid-fight (which drops combat_state)
	# brings back the same arena.
	run["node_state"] = {"type": "combat", "combat_state": state, "reward_chosen": false, "bg_idx": int(state.get("background_idx", prior_bg_idx)), "feat_pre": feat_pre, "pre_hp": pre_hp}
	save()
	state_changed.emit()


## The Feat this node's fight will set, chosen when the party reaches it (so
## the encounter screen can show it before Engage), or "" for none.
func coming_feat() -> String:
	var kind := current_node_kind()
	if not (kind in ["elite", "boss", "pillar"] or int(run.get("finale", 0)) > 0) or run.has("tower") or run.get("training", false):
		return ""
	var ns: Dictionary = run.get("node_state", {})
	if not ns.has("feat_pre"):
		var ids: Array = GameData.FEATS.keys()
		ids.sort()
		ns["feat_pre"] = str(ids[absi(hash([int(run.get("seed", 0)), int(run.get("pos", 0)), "feat"])) % ids.size()])
		run["node_state"] = ns
	return str(ns["feat_pre"])


## A Feat done by hand (no Auto) in a won fight pays out.
func feat_earned(state: Dictionary, result: Dictionary) -> bool:
	return bool(result.get("feat_done", false)) and not state.get("auto_used", false)


## Whether a flawless fight played by hand pays HAND_BONUS here: elites,
## bosses, and every fight on a rank not sealed yet (a finale, the training
## rift). Paid everywhere it was ~+30% income for anyone playing by hand
## (campaign_sim -- hand: 1,423 of ~1,500 fights); it now rewards the
## fights where hand play matters. Never in the Tower.
func hand_bonus_here(kind: String) -> bool:
	return not run.has("tower") and (kind in ["elite", "boss", "pillar"] or quick_fight_lock() != "")


## What the end-of-run summary compares against: the party's levels and the
## items and relics the guild held when the run began.
func run_snapshot(hero_ids: Array) -> Dictionary:
	var lv := {}
	for id in hero_ids:
		var h := find_hero(str(id))
		if h:
			lv[h.id] = h.level
	return {"levels": lv, "items": items.map(func(it): return it.id), "relics": relics.map(func(r): return r.id)}


## "" when the battle screen offers Quick fight for this run, else why not.
## It's earned per rank: a rank you've sealed is routine, a new one (and a
## finale) is fought where you can see it. Playing by hand seals ~17 points
## more runs than the auto policy at the same power (campaign_sim -- hand),
## so the frontier is where that matters. Only regular fights offer it at all
## (BattleView); this function itself doesn't refuse, so the sims can use it.
func quick_fight_lock() -> String:
	if sworn("by_hand"):
		return tr("Sworn to fight By Hand: no Quick fight")
	if int(run.get("finale", 0)) > 0:
		return tr("A finale is fought in full")
	var rank := str(run.get("rift_rank", ""))
	# A party far above the rank (Favored on the Party screen) may Quick fight it too.
	if rank != "" and GameData.rift_rank_index(rank) > best_rift_rank_sealed and Combat.party_power(current_party()) < Combat.recommended_power("", rank) * GameData.QUICK_FIGHT_FAVORED:
		return tr("Quick fight opens once you seal a Rank %s rift, or with a party at %d%% of Recommended power") % [tr(rank), int(GameData.QUICK_FIGHT_FAVORED * 100)]
	return ""


## Quick fight: engages the node and plays it out instantly with the auto
## policy (Combat.auto_action), landing straight on the result screen.
func quick_fight() -> void:
	engage_node()
	var st: Dictionary = run.get("node_state", {}).get("combat_state", {})
	if not st.is_empty():
		st["auto_used"] = true   # played by the auto policy: no hand-played bonus
	for i in 600:
		if st.is_empty() or run.get("node_state", {}).has("result"):
			break
		var nxt := Combat.peek_next_turn(st)
		if str(nxt["type"]) == "hero":
			var h := Combat._find_party_hero(st["party"], str(nxt["id"]))
			if h and h.hp > 0:
				st["pending_actions"][h.id] = Combat.auto_action(st, h)
		resolve_turn_now()


## Sets one hero's pending action for the round about to resolve — a pure
## "what will they do" toggle, no combat math, mirrors how e.g.
## choose_node_type() just records a choice.
## `target` is a monster index into state["monsters"], meaningful only for
## "attack" — ignored (but still stored, harmlessly) for "ability"/"defend".
## Party Assembly's Front/Back toggle — checks the roster first, then the
## Champion (find_hero only searches `heroes`, and the Champion needs this
## toggle too since their row has no other picker interaction).
func set_hero_formation(hero_id: String, formation: String) -> void:
	var h := find_hero(hero_id)
	if not h:
		return
	h.formation = formation
	save()
	state_changed.emit()


## `ally_id` is the hero a "guard" action protects.
func set_hero_action(hero_id: String, action: String, target: int = 0, ally_id: String = "") -> void:
	var ns: Dictionary = run.get("node_state", {})
	var state: Dictionary = ns.get("combat_state", {})
	if state.is_empty():
		return
	var pending: Dictionary = state["pending_actions"]
	pending[hero_id] = {"action": action, "target": target, "ally": ally_id}
	if run.get("training", false):
		if action == "attack":
			_see_hint("tut_attack")
		elif (action == "ability" or action.begins_with("skill:")) and Combat.action_block(state, find_hero(hero_id), action) == "":
			_see_hint("tut_skill")
		elif action in ["defend", "guard"] and (state["monsters"] as Array).any(func(m): return m.get("_winding", false) or m.get("_charged", false)):
			_see_hint("tut_windup")
	save()
	state_changed.emit()


func _apply_combat_outcome(outcome: Dictionary) -> void:
	var ns: Dictionary = run.get("node_state", {})
	var state: Dictionary = ns.get("combat_state", {})
	if outcome["done"]:
		var result: Dictionary = outcome["result"]
		var tally := ("auto" if state.get("auto_used", false) else "hand") + ("_w" if result["won"] else "_l")
		session[tally] = int(session.get(tally, 0)) + 1
		if not result["won"] and not bool(result.get("retreated", false)):
			result["defeat_reasons"] = Combat.defeat_reasons(state)
		if not result["won"]:
			_drop_haul("fled" if bool(result.get("retreated", false)) else "fell")
			if bool(result.get("retreated", false)):
				change_resolve(-int(GameData.RESOLVE_DRAIN["fled"]))
		if run.has("tower"):
			# The Tower pays per floor (first clear), not per fight.
			result["reward_options"] = []
			result["bonus_crystal"] = 0
			if result["won"]:
				result["tower"] = _complete_tower_floor(int(run["tower"]))
		var kind := current_node_kind()
		if result["won"]:
			coins += int(result["coin"])
			crystals += int(result["crystal"]) + int(result["bonus_crystal"])
			if kind == "elite":
				change_resolve(-int(GameData.RESOLVE_DRAIN["elite"]))
			_attune_gear(state.get("party", []))
			var breath := GameData.POST_FIGHT_MEND + work_bonus("mend")   # the Chapel
			if breath > 0.0 and not run.has("tower"):   # a breath between fights
				for h in state.get("party", []):
					if h.hp > 0:
						h.hp = mini(Combat.max_hp(h), h.hp + int(ceil(Combat.max_hp(h) * breath)))
			if kind == "boss":
				run["boss_rounds"] = int(result["rounds"])
				var bname := str(result["monster_name"]).split(",")[0]
				if not bosses_defeated.has(bname):
					bosses_defeated.append(bname)
				bosses_won += 1
				_bump("boss:" + bname)
				if bname == "Captain Morrow" and run.get("morrow", false) and not morrow_defeated:
					morrow_defeated = true
					coins += int(GameData.MORROW_REWARD["coins"])
					add_reputation(int(GameData.MORROW_REWARD["reputation"]))
					var down := lore_event("morrow", "down")   # the story web: the key, a confession
					pending_stories.append({"title": tr(str(GameData.MORROW_DOWN["title"])), "subtitle": tr(str(GameData.MORROW_DOWN["subtitle"])), "text": tr(str(GameData.MORROW_DOWN["text"])) + ("\n\n" + down if down != "" else "")})
					_offer_key()
					_news(tr("Captain Morrow is beaten; the Hollow Crown Company is finished."))
			elif kind == "elite":
				elites_won += 1
				if not run.has("tower"):
					result["boon_offer"] = roll_boon_offer(GameData.BOON_OFFER_SIZE + (1 if feat_earned(state, result) else 0))
			elif kind == "pillar":
				result["freed"] = free_lost_champion(next_lost_champion())
			# Quest tallies — every monster in a won fight is by definition dead,
			# so state["monsters"] (still the pre-cleanup fight roster) is a
			# reliable "what did we just kill" list.
			for m in state.get("monsters", []):
				var mname := str(m.get("name", ""))
				if mname != "":
					monster_kill_counts[mname] = int(monster_kill_counts.get(mname, 0)) + 1
					if mname == "Company Crossbowman":   # the story web: a Bestiary note
						lore_event("bestiary", mname)
			if state.has("feat") and not state.get("auto_used", false):
				var ft: Array = feat_tally.get(str(state["feat"]["id"]), [0, 0])
				feat_tally[str(state["feat"]["id"])] = [int(ft[0]) + (1 if result.get("feat_done", false) else 0), int(ft[1]) + 1]
			if feat_earned(state, result):   # a Feat, done by hand
				feats_done += 1
				result["feat_gold"] = maxi(1, int(round(int(result["coin"]) * GameData.FEAT_BONUS)))
				result["feat_ess"] = maxi(1, int(round(int(result["crystal"]) * GameData.FEAT_BONUS)))
				coins += int(result["feat_gold"])
				crystals += int(result["feat_ess"])
			var flawless := true
			for h in state.get("party", []):
				if h.hp <= 0:
					flawless = false
					break
			if flawless:
				flawless_wins += 1
				if kind == "boss" and not state.get("auto_used", false):
					flawless_bosses += 1
				# Played by hand (no Auto) with no one down: a bonus on top.
				if not state.get("auto_used", false) and hand_bonus_here(kind):
					result["hand_bonus"] = maxi(1, int(round(int(result["coin"]) * GameData.HAND_BONUS)))
					coins += int(result["hand_bonus"])
					# Essence too: it's the currency a guild runs short of.
					result["hand_bonus_ess"] = maxi(1, int(round(int(result["crystal"]) * GameData.HAND_BONUS)))
					crystals += int(result["hand_bonus_ess"])
			# An escort NPC (start_combat's ~25% chance on a "combat" node) pays
			# out a small bonus only if it survived the whole fight — dying
			# mid-fight is a softer failure than a party wipe, so it never
			# affects the fight's own win/loss.
			if kind != "boss" and not run.has("tower"):
				_note_injuries("critical" if kind == "elite" else "wounded")
			var escort: Dictionary = state.get("escort", {})
			if not escort.is_empty() and float(escort.get("hp", 0.0)) > 0.0:
				add_reputation(2)
				crystals += 1
				result["escort_saved"] = str(escort["name"])
		# Hero history (kills/knockouts are tallied inside Combat as they
		# happen; boss/elite wins are only known here) and any traits it earns.
		if result["won"] and kind in ["boss", "elite", "pillar"]:
			for h in state.get("party", []):
				h.history[kind + "_kills"] = int(h.history.get(kind + "_kills", 0)) + 1
		var earned: Array[String] = []
		for h in state.get("party", []):
			earned.append_array(check_earned_quirks(h))
		if not earned.is_empty():
			result["flavor"] = (str(result.get("flavor", "")) + " " + " ".join(earned)).strip_edges()
		ns["result"] = result
	run["node_state"] = ns
	save()
	state_changed.emit()


## Resolves whichever actor's turn is next (see Combat.resolve_turn — a
## living hero's pending action, or a living monster's retaliation). Once it
## reports the fight done, applies the same roster-level bookkeeping
## engage_node used to do in one shot (coin/crystal gain, boss_rounds
## tracking).
func resolve_turn_now() -> void:
	var ns: Dictionary = run.get("node_state", {})
	var state: Dictionary = ns.get("combat_state", {})
	if state.is_empty():
		return
	_apply_combat_outcome(Combat.resolve_turn(state))


## Ends the current fight by player choice, forfeiting rewards — heroes keep
## whatever HP they currently have, no one is downed or removed.
func combat_retreat() -> void:
	var ns: Dictionary = run.get("node_state", {})
	var state: Dictionary = ns.get("combat_state", {})
	if state.is_empty():
		return
	_apply_combat_outcome(Combat.retreat_combat(state))


func pick_combat_reward(idx: int) -> void:
	var ns: Dictionary = run.get("node_state", {})
	var result: Dictionary = ns.get("result", {})
	var options: Array = result.get("reward_options", [])
	if ns.get("reward_chosen", false) or idx < 0 or idx >= options.size():
		return
	var opt: Dictionary = options[idx]
	if opt["loot_type"] == "item":
		var it: Item = opt["obj"]
		it.id = "it" + str(next_id)
		next_id += 1
		items.append(it)
	else:
		var r: Relic = opt["obj"]
		r.id = "rl" + str(next_id)
		next_id += 1
		r.equipped = Combat.equipped_relics().size() < relic_slot_cap()
		relics.append(r)
	ns["reward_chosen"] = true
	save()
	state_changed.emit()


# ---------------- Campfire / event / treasure nodes ----------------

## Campfire: one of Rest (heal), Train (XP) or Sharpen (abilities ready).
func campfire_choose(choice: String) -> void:
	var ns: Dictionary = run.get("node_state", {})
	if ns.get("resolved", false):
		return
	var party := current_party().filter(func(h): return h.hp > 0)
	var log: Array[String] = []
	match choice:
		"rest":
			for h in party:
				h.hp = min(Combat.max_hp(h), h.hp + int(ceil(Combat.max_hp(h) * campfire_heal_pct())))
			log.append(tr("The party rests by the fire and recovers %d%% HP.") % int(round(campfire_heal_pct() * 100)))
		"train":
			for h in party:
				Combat.gain_xp(h, GameData.CAMPFIRE_TRAIN_XP)
			log.append(tr("The party drills together: +%d XP each.") % GameData.CAMPFIRE_TRAIN_XP)
		"sharpen":
			run["momentum_bonus"] = int(run.get("momentum_bonus", 0)) + 4
			log.append(tr("Weapons sharpened, focus restored — the next fight starts with +4 Momentum."))
	var gain := change_resolve(int(GameData.RESOLVE_GAIN["rest" if choice == "rest" else "campfire"]) + (1 if has_wing("chapel") else 0))
	if gain != 0:
		log.append(tr("%+d Resolve.") % gain)
	ns["type"] = "campfire"
	ns["resolved"] = true
	ns["log"] = log
	run["node_state"] = ns
	save()
	state_changed.emit()


func ensure_event() -> void:
	var ns: Dictionary = run.get("node_state", {})
	if ns.has("event"):
		return
	ns["type"] = "event"
	var seen: Array = run.get("events_seen", [])
	# Region events ("biome") only happen in their region.
	var here: Array = GameData.RIFT_EVENTS.filter(func(e): return str(e.get("biome", run_biome())) == run_biome() and campaign_act >= int(e.get("min_act", 1)))
	var fresh: Array = here.filter(func(e): return not seen.has(e["id"]))
	if fresh.is_empty():
		fresh = here
	ns["event"] = fresh[randi() % fresh.size()]
	seen.append(str(ns["event"]["id"]))
	run["events_seen"] = seen
	ns["resolved"] = false
	run["node_state"] = ns


func can_afford(cost: Dictionary) -> bool:
	return coins >= int(cost.get("coins", 0)) and crystals >= int(cost.get("crystals", 0))


func resolve_event(choice_idx: int) -> void:
	var ns: Dictionary = run.get("node_state", {})
	if ns.get("resolved", false) or not ns.has("event"):
		return
	var choices: Array = ns["event"]["choices"]
	if choice_idx < 0 or choice_idx >= choices.size():
		return
	var c: Dictionary = choices[choice_idx]
	var cost: Dictionary = c.get("cost", {})
	if not can_afford(cost):
		return
	coins -= int(cost.get("coins", 0))
	crystals -= int(cost.get("crystals", 0))
	var log: Array[String] = []
	if c.has("check"):
		var chk: Dictionary = c["check"]
		var info := event_check(chk)
		var passed := randf() < float(info["chance"])
		log.append(tr("%s check (%s, %d vs %d): %s.") % [tr(str(GameData.ATTR_LABEL[chk["attr"]])), tr(str(info["hero"])), int(info["value"]), int(info["target"]), tr(str("passed" if passed else "failed"))])
		log.append_array(_apply_event_effect(chk["win"] if passed else chk["lose"]))
	elif c.has("gamble"):
		var g: Dictionary = c["gamble"]
		var won := randf() < float(g["chance"])
		log.append(tr("Luck is with you.") if won else tr("Luck is not with you."))
		log.append_array(_apply_event_effect(g["win"] if won else g["lose"]))
	else:
		log.append_array(_apply_event_effect(c.get("effect", {})))
	if log.is_empty():
		log.append(tr("You move on."))
	ns["resolved"] = true
	ns["log"] = log
	run["node_state"] = ns
	save()
	state_changed.emit()


## An event attribute check: the party member with the best score, that
## score, the target, and the chance to pass.
func event_check(chk: Dictionary) -> Dictionary:
	var attr := str(chk["attr"])
	var party := current_party().filter(func(h): return h.hp > 0)
	var avg_lv := 1.0
	if not party.is_empty():
		avg_lv = party.reduce(func(acc, h): return acc + h.level, 0) / float(party.size())
	# Attributes grow ~3 points a level, so the bar rises with the party.
	var target := int(chk["target"]) + int(round(GameData.EVENT_CHECK_PER_LEVEL * avg_lv)) + (0 if str(run.get("diff_id", "lesser")) == "lesser" and str(run.get("rift_rank", "")) == "" else 3)
	var best: Hero = null
	for h in current_party():
		if h.hp > 0 and (best == null or Combat.hero_attr(h, attr) > Combat.hero_attr(best, attr)):
			best = h
	var value := Combat.hero_attr(best, attr) if best else GameData.ATTR_BASELINE
	var chance := clampf(GameData.EVENT_CHECK_BASE + GameData.EVENT_CHECK_PER_POINT * (value - target), 0.1, 0.95)
	return {"hero": best.name.split(" the ")[0] if best else "nobody", "value": value, "target": target, "chance": chance}


func _event_amount(v) -> int:
	return randi_range(int(v[0]), int(v[1])) if v is Array else int(v)


func _apply_event_effect(e: Dictionary) -> Array[String]:
	var log: Array[String] = []
	var party := current_party().filter(func(h): return h.hp > 0)
	if e.has("coins"):
		var n := _event_amount(e["coins"])
		coins += n
		log.append(tr("+%d Gold.") % n)
	if e.has("crystals"):
		var n2 := _event_amount(e["crystals"])
		crystals += n2
		log.append(tr("+%d Essence.") % n2)
	if e.has("reputation"):
		var r := int(e["reputation"])
		add_reputation(r)
		log.append(tr("%+d Renown.") % r)
	if e.has("xp_all"):
		for h in party:
			Combat.gain_xp(h, int(e["xp_all"]))
		log.append(tr("Every hero gains %d XP.") % int(e["xp_all"]))
	if e.has("heal_pct"):
		for h in party:
			h.hp = min(Combat.max_hp(h), h.hp + int(ceil(Combat.max_hp(h) * float(e["heal_pct"]))))
		log.append(tr("The party heals %d%% HP.") % int(float(e["heal_pct"]) * 100))
	if e.has("hurt_pct"):
		for h in party:
			h.hp = max(1, h.hp - int(ceil(Combat.max_hp(h) * float(e["hurt_pct"]))))
		log.append(tr("Everyone loses %d%% HP.") % int(float(e["hurt_pct"]) * 100))
	if e.get("ready", false):
		run["momentum_bonus"] = int(run.get("momentum_bonus", 0)) + 3
		log.append(tr("The next fight starts with +3 Momentum."))
	if e.has("resolve"):
		var rg := change_resolve(int(e["resolve"]))
		if rg != 0:
			log.append(tr("%+d Resolve.") % rg)
	if e.has("tonic"):
		var add := add_tonic("healing", int(e["tonic"]))
		log.append(tr("+%d Healing Tonic.") % add if add > 0 else tr("You can't carry another tonic."))
	if e.has("shield"):
		run["shield"] = int(run.get("shield", 0)) + int(e["shield"])
		log.append(tr("A %d-point shield against hazards.") % int(e["shield"]))
	for kind in ["item", "relic"]:
		if e.has(kind):
			var rr := Combat.weighted_rarity()
			if _rarity_order(rr) < _rarity_order(str(e[kind])):
				rr = str(e[kind])
			var lt: Dictionary = {"loot_type": "item", "obj": Combat.gen_item(rr)} if kind == "item" or not feature_unlocked("relics") else {"loot_type": "relic", "obj": Combat.gen_relic(rr)}
			_grant_loot(lt)
			log.append(tr("You receive: %s (%s).") % [tr(str(lt["obj"].name)), tr(str(rr.capitalize()))])
	if e.has("loot"):
		var rarity := Combat.weighted_rarity()
		if _rarity_order(rarity) < _rarity_order(str(e["loot"])):
			rarity = str(e["loot"])
		var loot: Dictionary = Combat.gen_loot(rarity)
		_grant_loot(loot)
		log.append(tr("You receive: %s (%s).") % [tr(str(loot["obj"].name)), tr(str(rarity.capitalize()))])
	return log


func _rarity_order(r: String) -> int:
	return ["common", "rare", "epic", "legendary"].find(r)


## Adds a rolled loot entry ({loot_type, obj}) to the guild's stash.
func _grant_loot(loot: Dictionary) -> void:
	if loot["loot_type"] == "item":
		var it: Item = loot["obj"]
		it.id = "it" + str(next_id)
		next_id += 1
		items.append(it)
	else:
		var r: Relic = loot["obj"]
		r.id = "rl" + str(next_id)
		next_id += 1
		r.equipped = Combat.equipped_relics().size() < relic_slot_cap()
		relics.append(r)


## Treasure: pick one of two loot drops, no fight.
func ensure_treasure() -> void:
	var ns: Dictionary = run.get("node_state", {})
	if ns.has("options"):
		return
	ns["type"] = "treasure"
	ns["options"] = [Combat.gen_loot(Combat.weighted_rarity()), Combat.gen_loot(Combat.weighted_rarity())]
	ns["picked"] = false
	run["node_state"] = ns


func pick_treasure(idx: int) -> void:
	var ns: Dictionary = run.get("node_state", {})
	var options: Array = ns.get("options", [])
	if ns.get("picked", false) or idx < 0 or idx >= options.size():
		return
	_grant_loot(options[idx])
	ns["picked"] = true
	save()
	state_changed.emit()


## The lane map's own nodes (0.65): an anvil (one free Forge level on a
## piece the party wears), a Path's shrine (XP for the party, more for its
## Path's heroes) and a trainer's echo (one hero gains a level).
func ensure_lane_node() -> void:
	var ns: Dictionary = run.get("node_state", {})
	if ns.has("lane"):
		return
	ns["lane"] = current_node_kind()
	ns["done"] = false
	if ns["lane"] == "shrine":   # usually a Path someone in the party walks
		var walked: Array = []
		for h in current_party():
			var p := h.path if h.path != "" else GameData.path_of(h.pool_id)
			if p != "" and not walked.has(p):
				walked.append(p)
		var keys: Array = GameData.PATHS.keys()
		ns["path"] = walked[randi() % walked.size()] if not walked.is_empty() and randf() < 0.7 else keys[randi() % keys.size()]
	run["node_state"] = ns


## The party's worn pieces an anvil can temper (most forging left first).
func anvil_items() -> Array:
	var ids: Array = run.get("hero_ids", [])
	var out: Array = items.filter(func(it): return ids.has(it.equipped_to) and forge_cost(it) > 0)
	out.sort_custom(func(a, b): return a.forge_level < b.forge_level)
	return out.slice(0, 6)


func use_anvil(item_id: String) -> void:
	var ns: Dictionary = run.get("node_state", {})
	var it := find_item(item_id)
	if ns.get("done", false) or it == null or forge_cost(it) <= 0:
		return
	coins += forge_cost(it)   # the anvil is free: forge_item takes its price back
	forge_item(item_id)
	ns["done"] = true
	ns["note"] = tr("%s is tempered on the old anvil.") % tr(it.name)
	save()
	state_changed.emit()


## XP share of a level a shrine gives: its Path's heroes / everyone else.
const SHRINE_XP := [0.5, 0.15]


func pray_at_shrine() -> void:
	var ns: Dictionary = run.get("node_state", {})
	if ns.get("done", false):
		return
	var names: Array = []
	for h in current_party():
		if h.hp <= 0 or h.level >= 10:
			continue
		var own := (h.path if h.path != "" else GameData.path_of(h.pool_id)) == str(ns.get("path", ""))
		Combat.gain_xp(h, int(round(Combat.xp_to_next(h.level, h.rank) * float(SHRINE_XP[0 if own else 1]) * (2.0 if has_wing("library") else 1.0))))
		if own:
			names.append(h.name.split(" the ")[0])
	ns["done"] = true
	change_resolve(int(GameData.RESOLVE_GAIN["shrine"]))
	ns["note"] = tr("The shrine answers: %s learn the most.") % ", ".join(names) if not names.is_empty() else tr("The shrine answers, faintly: a little XP for everyone.")
	save()
	state_changed.emit()


func train_with_echo(hero_id: String) -> void:
	var ns: Dictionary = run.get("node_state", {})
	var h := find_hero(hero_id)
	if ns.get("done", false) or h == null:
		return
	var times := 2 if has_wing("library") else 1   # the Library: twice the lesson
	if h.level < 10:
		for i in times:
			if h.level < 10:
				Combat.gain_xp(h, Combat.xp_to_next(h.level, h.rank) - h.xp)
		ns["note"] = tr("%s trains with the echo: level %d.") % [h.name.split(" the ")[0], h.level]
	else:
		h.attr_points += GameData.ATTR_PER_STEP * times
		ns["note"] = tr("%s trains with the echo: +%d attribute points.") % [h.name.split(" the ")[0], GameData.ATTR_PER_STEP * times]
	ns["done"] = true
	save()
	state_changed.emit()


func skip_lane_node() -> void:
	var ns: Dictionary = run.get("node_state", {})
	ns["done"] = true
	ns["note"] = tr("You move on.")
	save()
	state_changed.emit()


func ensure_hazard() -> void:
	var ns: Dictionary = run.get("node_state", {})
	if ns.has("hazard"):
		return
	# A mapped rift's "hazard_severity_up" modifier (0-2) biases the roll
	# toward worse hazards by filtering out the mildest ones first, rather
	# than reordering HAZARD_TYPES itself — falls back to the full list if
	# filtering would leave nothing (never happens at today's 3 severity
	# steps against 5 hazard types spanning dmg_mult 0.8-1.3, but kept safe).
	var severity_up := int(_diff().get("hazard_severity_up", 0))
	var min_mult: float = [0.0, 1.0, 1.2][clampi(severity_up, 0, 2)]
	var eligible: Array = GameData.HAZARD_TYPES.filter(func(h): return float(h["dmg_mult"]) >= min_mult)
	if eligible.is_empty():
		eligible = GameData.HAZARD_TYPES
	var hz: Dictionary = eligible[randi() % eligible.size()]
	ns["hazard"] = hz
	ns["resolved"] = false
	run["node_state"] = ns
	var hz_id := str(hz["id"])
	if not hazards_seen.has(hz_id):
		hazards_seen.append(hz_id)


## Shared core for all 3 hazard choices — `dmg_scale` multiplies the normal
## damage roll (1.0 = unchanged), `bonus_chance_override` replaces the
## hazard's own bonus_chance when >= 0.0 (a negative value means "use the
## hazard's own chance unmodified").
## What a hazard choice would do, without doing it: the hazard's damage is
## fixed (no roll), so this is exact. `dmg_scale` is 1.0 to push through, 2.0
## to risk it. {anchor, total, absorbed, per_hero, downs: [hero names]}.
## _apply_hazard uses the same numbers, so the preview can't drift from it.
func hazard_preview(dmg_scale: float) -> Dictionary:
	ensure_hazard()
	var party: Array[Hero] = []
	party.assign(current_party().filter(func(h): return not h.is_downed() and h.hp > 0))
	if not run.get("anchor_used", false) and anchor_artifact():
		return {"anchor": true, "total": 0, "absorbed": 0, "per_hero": 0, "downs": [], "party": party}
	var hz: Dictionary = run["node_state"]["hazard"]
	# Scaled like the rift's foes: a flat 16-26 points was nothing past Rank D
	# ("hazard severity seems pretty wasted").
	var rank_scale: float = float(_diff()["monster_dmg"]) / float(GameData.DIFFICULTIES[0]["monster_dmg"])
	var dmg: float = (6.0 + int(_diff()["floors"]) * 2.0) * float(hz["dmg_mult"]) * dmg_scale * rank_scale
	var guard: float = min(0.9, hazard_severity_reduction() + Combat.party_skill_total(party, "hazard_guard_pct") + Combat.relic_special_total("hazard_guard_pct") + Combat.relic_drawback_total("hazard_guard_pct") + Combat.synergy_value_for("hazard_guard_pct") + Combat.bond_bonus_for(party, "hazard_guard_pct"))
	if party.any(func(h): return GameData.hero_path_id(h) == "aegis"):   # Sanctum Chime (0.65)
		dmg *= 1.0 - path_relic_value("aegis_hazard")
	dmg = round(dmg * (1.0 - guard))
	var absorbed: int = min(int(run.get("shield", 0)), int(dmg))
	dmg -= absorbed
	if party.any(func(x): return x.pool_id == "pathfinder"):   # Twist (0.62): hazards 20% weaker
		dmg = round(dmg * 0.8)
	# One reckoning for the card and the outcome (0.65: they had drifted apart).
	var per: float = dmg / party.size() if party.size() > 0 else 0.0
	var hits := {}
	var downs: Array[String] = []
	for h in party:
		if h.pool_id == "scavenger" or dmg <= 0:   # Twist (0.62): hazards never hurt them
			continue
		hits[h.id] = int(round(per))
		if h.hp - int(round(per)) <= 0 and not hazards_nonlethal():
			downs.append(h.name.split(" the ")[0])
	return {"anchor": false, "total": int(dmg), "absorbed": absorbed, "per_hero": int(round(per)), "hits": hits, "downs": downs, "party": party}


func _apply_hazard(dmg_scale: float, bonus_chance_override: float) -> void:
	var pv := hazard_preview(dmg_scale)
	var party: Array[Hero] = pv["party"]
	var ns: Dictionary = run["node_state"]
	var hz: Dictionary = ns["hazard"]
	var log: Array[String] = []
	var rl := change_resolve(-int(GameData.RESOLVE_DRAIN["risk" if dmg_scale > 1.0 else "hazard"]))
	if rl != 0:
		log.append(tr("%+d Resolve.") % rl)
	if pv["anchor"]:
		run["anchor_used"] = true
		log.append(tr("The Anchor Artifact snuffs the hazard before it strikes."))
	else:
		var absorbed: int = pv["absorbed"]
		run["shield"] = int(run.get("shield", 0)) - absorbed
		if absorbed > 0:
			log.append(tr("Relic wards absorb %d of the hazard.") % absorbed)
		var hits: Dictionary = pv["hits"]
		if not hits.is_empty():
			for h in party:
				if hits.has(h.id):
					h.hp = max(1 if hazards_nonlethal() else 0, h.hp - int(hits[h.id]))
					if h.hp <= 0:
						knock_out(h)
			log.append(tr("The hazard deals %d damage across the party.") % hits.values().reduce(func(a, b): return a + b, 0))
			_note_injuries("wounded")
	# Getting through always pays about what a fight here pays; the hazard's
	# bonus chance (or Risk it) doubles it. It was a 15-50% chance of 2-6.
	var bonus_chance: float = float(hz["bonus_chance"]) if bonus_chance_override < 0.0 else bonus_chance_override
	var rng := hazard_reward_range()
	var c := randi_range(int(rng[0]), int(rng[1])) * (2 if randf() < bonus_chance else 1)
	if hz["bonus_type"] == "coins":
		coins += c
		log.append(tr("You scavenge %d Gold on the way through.") % c)
	else:
		crystals += c
		log.append(tr("Essence found in the rubble: +%d.") % c)
	ns["resolved"] = true
	ns["log"] = log
	run["node_state"] = ns
	save()
	state_changed.emit()


## What getting through a hazard pays (before a double): the rift's own
## per-fight Gold or Essence range, by the hazard's kind.
func hazard_reward_range() -> Array:
	ensure_hazard()
	var key := "coin" if str(run["node_state"]["hazard"]["bonus_type"]) == "coins" else "crystal"
	var r: Array = _diff()[key]
	return [int(r[0]), int(r[1])]


## The safe default: full damage roll, the hazard's own normal bonus chance.
func push_through_hazard() -> void:
	_apply_hazard(1.0, -1.0)


## The gambler's choice: double damage exposure, guaranteed bonus reward.
func risk_hazard() -> void:
	_apply_hazard(2.0, 1.0)


func can_afford_hazard_bypass() -> bool:
	return crystals >= HAZARD_BYPASS_COST


## Pay Crystals to skip the hazard entirely — no damage, no reward, no
## resistance/anchor math (there's nothing to resist or block).
func bypass_hazard() -> void:
	if not can_afford_hazard_bypass():
		return
	ensure_hazard()
	var ns: Dictionary = run["node_state"]
	crystals -= HAZARD_BYPASS_COST
	ns["resolved"] = true
	ns["log"] = [tr("You pay %d Essence and bypass the hazard entirely.") % HAZARD_BYPASS_COST]
	run["node_state"] = ns
	save()
	state_changed.emit()


func ensure_shop_offers() -> void:
	var ns: Dictionary = run.get("node_state", {})
	if ns.get("type") == "shop":
		return
	var boosted := pending_shop_boost
	var offers: Array = []
	for i in 3:
		offers.append(_gen_shop_offer((boosted or shop_guaranteed_epic()) and i == 0))
	if boosted:
		pending_shop_boost = false
	run["node_state"] = {"type": "shop", "offers": offers, "rerolls": 0}


func _gen_shop_offer(force_epic: bool = false) -> Dictionary:
	var rarity := "epic" if force_epic else Combat.weighted_rarity()
	var loot: Dictionary = {"loot_type": "relic", "obj": Combat.gen_relic(rarity)} if force_epic else Combat.gen_loot(rarity)
	var rar := GameData.find_rarity(rarity)
	loot["price"] = max(4, int(round((10.0 + 15.0 * float(rar["mult"])) * (1.0 - merchant_price_reduction()))))
	loot["bought"] = false
	return loot


## Rerolling a shop costs more each time in the same shop.
func shop_reroll_cost() -> int:
	return 8 + 6 * int(run.get("node_state", {}).get("rerolls", 0))


## Replaces every offer not yet bought with a fresh one.
func reroll_shop() -> void:
	var ns: Dictionary = run.get("node_state", {})
	var cost := shop_reroll_cost()
	if ns.get("type") != "shop" or coins < cost:
		return
	coins -= cost
	var offers: Array = ns["offers"]
	for i in offers.size():
		if not offers[i].get("bought", false):
			offers[i] = _gen_shop_offer()
	ns["rerolls"] = int(ns.get("rerolls", 0)) + 1
	save()
	state_changed.emit()


func buy_shop_offer(idx: int) -> void:
	var ns: Dictionary = run.get("node_state", {})
	var offers: Array = ns.get("offers", [])
	if idx < 0 or idx >= offers.size():
		return
	var off: Dictionary = offers[idx]
	if off.get("bought", false):
		return
	if coins < int(off["price"]):
		return
	coins -= int(off["price"])
	off["bought"] = true
	if off["loot_type"] == "item":
		var it: Item = off["obj"]
		it.id = "it" + str(next_id)
		next_id += 1
		items.append(it)
	else:
		var r: Relic = off["obj"]
		r.id = "rl" + str(next_id)
		next_id += 1
		r.equipped = Combat.equipped_relics().size() < relic_slot_cap()
		relics.append(r)
	save()
	state_changed.emit()


func advance_node() -> void:
	if not pending_injuries().is_empty():
		return   # decide what happens to the downed first (see _note_injuries)
	if run.has("descent") and int(run["pos"]) + 1 >= (run["layers"] as Array).size():   # a depth cleared: the next opens below
		descent_best = maxi(descent_best, int(run["descent"]))
		run["descent"] = int(run["descent"]) + 1
		(run["layers"] as Array).append_array(_descent_layers(int(run["descent"])))
		if int(run["descent"]) >= 6:   # the story web: a deep pillar's height marks
			lore_event("descent", "6")
	change_resolve(-int(GameData.RESOLVE_DRAIN["floor"]))
	run["pos"] = int(run["pos"]) + 1
	run["node_state"] = {}
	auto_resolve_single_option()
	save()
	state_changed.emit()


func seal_rift() -> void:
	note_milestone("first seal")
	var roles_here := {}
	for h in current_party():
		roles_here[GameData.hero_role(h)] = true
	for r in roles_here:
		role_seals[r] = int(role_seals.get(r, 0)) + 1
	_rescue_left_behind()
	maybe_find_ledger_page(int(run.get("finale", 0)) > 0)
	if not run.has("tower"):   # the story web: a fragment in the rift
		var rr := str(run.get("rift_rank", ""))
		lore_on_seal(run_biome(), GameData.rift_rank_index(rr) if rr != "" else -1)
	if int(run.get("finale", 0)) == 0 and not run.has("tower"):
		maybe_echo()
	if int(run.get("finale", 0)) > 0 and int(run["finale"]) == campaign_act:
		_complete_act(campaign_act)
	var diff := _diff()
	var fast_clear: bool = int(run.get("boss_rounds", 99)) <= 6
	var seal_mult: float = seal_bonus_mult()
	var earned := int(round(float(diff["seal_essence"]) * seal_mult))
	crystals += earned
	var cache := 0
	if randf() < float(diff["cache_chance"]) + cache_chance_bonus():
		cache = int(round(float(GameData.RIFT_CACHE_GOLD.get(str(diff["id"]), 70)) * (1.3 if black_market_unlocked() else 1.0)))
		coins += cache
	var mapped_rank: String = str(run.get("rift_rank", ""))
	if mapped_rank != "":
		best_rift_rank_sealed = max(best_rift_rank_sealed, GameData.rift_rank_index(mapped_rank))
		_on_rift_sealed(GameData.rift_rank_index(mapped_rank))
		_check_challenge(GameData.rift_rank_index(mapped_rank))
	var just_unlocked_greater := int(run.get("finale", 0)) == 1   # Greater Rifts open with Act I's finale
	rifts_sealed += 1
	add_reputation(GameData.SEAL_RENOWN_BASE + (GameData.rift_rank_index(mapped_rank) / 3 if mapped_rank != "" else 0) + int(founding_rule("seal_renown", 0)))
	# Guild Board tallies (see _quest_current).
	if mapped_rank != "":
		_bump("rank_seals:%d" % GameData.rift_rank_index(mapped_rank))
	if not run.has("tower"):
		_bump("biome_seals:" + run_biome())   # Book II's region objectives
		maybe_crossing()
	if str(diff.get("id", "")) == "greater":
		_bump("greater_seals")
	if not bool(run.get("any_ko", false)):
		_bump("flawless_rifts")
	if (run.get("hero_ids", []) as Array).size() <= 2:
		_bump("small_seals")
	var flavor := GameData.narrative_line("fast_clear" if fast_clear else "rift_sealed")
	if just_unlocked_greater:
		flavor += " " + GameData.narrative_line("greater_rift_unlocked")
	# Rift history + bonds: every roster hero who saw this rift through counts
	# it, and every pair of them grows their bond (see GameData.BOND_LEVEL_RIFTS).
	var sealers: Array[Hero] = []
	sealers.assign(current_party())
	var deepened: Array[String] = []   # "A & B (Lv2)": one line for every bond, not a sentence each
	for i in sealers.size():
		sealers[i].history["rifts_cleared"] = int(sealers[i].history.get("rifts_cleared", 0)) + 1
		if int(sealers[i].history["rifts_cleared"]) == 50 and not sealers[i].is_champion:   # the Chronicle
			var fn := tr(str(sealers[i].name.split(" the ")[0]))
			var fifty: Array = GameData.FIFTY_RIFTS.filter(func(t): return not hesper_posted() or not str(t).contains("Hesper"))
			pending_stories.append({"title": tr("Fifty rifts"), "subtitle": tr(str(sealers[i].name)),
				"text": tr(str(fifty[randi() % fifty.size()])) % [fn, fn]})
		for j in range(i + 1, sealers.size()):
			var key := _bond_key(sealers[i].id, sealers[j].id)
			var before := GameData.bond_level(int(bonds.get(key, 0)))
			bonds[key] = int(bonds.get(key, 0)) + 1
			if GameData.bond_level(int(bonds[key])) > before:
				if before + 1 == GameData.BOND_LEVEL_RIFTS.size():   # the last level: a scene (the Chronicle)
					var pair := [tr(str(sealers[i].name.split(" the ")[0])), tr(str(sealers[j].name.split(" the ")[0]))]
					var bond_pool: Array = GameData.BOND_SCENES.filter(func(t): return not hesper_posted() or not str(t).contains("Hesper"))
					var scene := tr(str(bond_pool[randi() % bond_pool.size()]))
					var args := [pair[0], pair[1], pair[1]] if scene.count("%s") == 3 else pair
					pending_stories.append({"title": tr("%s & %s") % pair, "subtitle": tr("A bond, written down"), "text": scene % args})
				deepened.append(tr("%s & %s (Lv%d)") % [tr(str(sealers[i].name.split(" the ")[0])), tr(str(sealers[j].name.split(" the ")[0])), before + 1])
				push_toast(sealers[i], tr("Bond deepened — Lv%d") % (before + 1), tr("%s & %s: +%d%% party damage while both stand") % [tr(str(sealers[i].name.split(" the ")[0])), tr(str(sealers[j].name.split(" the ")[0])), int(round(GameData.BOND_DMG_PER_LEVEL * (before + 1) * 100))])
	if not deepened.is_empty():
		flavor += " " + tr("Bonds deepen: %s.") % ", ".join(deepened)
	var wavering := resolve_on() and resolve_tier() > 0
	for h in sealers:
		change_morale(h, GameData.MORALE_SEAL)
		if run.has("breach"):
			h.history["breaches_held"] = int(h.history.get("breaches_held", 0)) + 1
		if wavering:
			h.history["sealed_wavering"] = int(h.history.get("sealed_wavering", 0)) + 1
		for line in check_earned_quirks(h) + check_titles(h):
			flavor += " " + line
	triage_used_this_cycle = false
	run["sealed"] = {"essence": earned, "fast_clear": fast_clear, "cache": cache, "flavor": flavor}
	if path_relic_eligible():
		var offer := roll_path_relic_offer()
		if not offer.is_empty():
			run["sealed"]["path_relics"] = offer
	if run.has("daily"):
		run["sealed"]["daily"] = _complete_daily()
	save()
	state_changed.emit()


## Pays out a finished Endless Rift (survivors) run: a little gold, Essence
## (which also levels the champions), loot for elites and wardens, and every lost
## champion freed on the way. The guild spends a day on it (wages, healing).
## Returns what was earned for the result screen.
func finish_survivors(r: SurvivorsRun) -> Dictionary:
	var pay := r.rewards()
	coins += int(pay["coins"])
	crystals += int(pay["crystals"])
	var freed: Array = []
	for id in r.rescued:
		var fname := free_lost_champion(str(id))
		if fname != "":
			freed.append(fname)
	var names: Array = []
	for h in r.heroes:
		names.append(h["hero"].name.split(" the ")[0])
	var loot_names: Array = []
	for i in int(pay["loot"]):
		var loot := Combat.gen_loot(Combat.weighted_rarity())
		_grant_loot(loot)
		loot_names.append(loot["obj"].name)
	for name in r.kill_counts:
		monster_kill_counts[name] = int(monster_kill_counts.get(name, 0)) + int(r.kill_counts[name])
	var t := int(r.time)
	var best := t > int(endless_best.get(r.biome, 0))
	best_endless_time = maxi(best_endless_time, t)
	endless_best[r.biome] = maxi(int(endless_best.get(r.biome, 0)), t)
	endless_runs += 1
	# First-time milestones: gold, Essence, an Endless relic, a guild title.
	var got: Array = []
	for m in GameData.ENDLESS_MILESTONES:
		if endless_milestones.has(int(m["at"])) or t < int(m["at"]) or (m.get("sealed", false) and not r.won):
			continue
		endless_milestones.append(int(m["at"]))
		coins += int(m["coins"])
		crystals += int(m["crystals"])
		var line := tr("%s: %s+%d essence") % [tr(str(m["name"])), tr("+%d gold, ") % int(m["coins"]) if int(m["coins"]) > 0 else "", int(m["crystals"])]
		if m.has("relic"):
			var rl := Combat.relic_from_unique(GameData.ENDLESS_RELICS[m["relic"]])
			rl.equipped = Combat.equipped_relics().size() < relic_slot_cap()
			relics.append(rl)
			line += tr(", the relic %s") % tr(str(rl.name))
		if m.has("title"):
			line += tr(", the title \"%s\"") % tr(str(m["title"]))
		got.append(line)
	runs_finished += 1
	pass_time()
	run_history.push_front({"day": day, "kind": "Endless Rift", "result": "Sealed" if r.won else "Survived", "floor": "", "time": t, "kills": r.kills,
		"heroes": names, "boons": [], "coins": int(pay["coins"]), "crystals": int(pay["crystals"])})
	if run_history.size() > GameData.RUN_HISTORY_MAX:
		run_history.resize(GameData.RUN_HISTORY_MAX)
	save()
	state_changed.emit()
	return {"coins": int(pay["coins"]), "crystals": int(pay["crystals"]), "freed": freed, "loot": loot_names, "best": best, "milestones": got}


## Frees a lost champion (from a pillar in the Descent or a ladder rift, or
## the Endless Rift's light): the post they held empties, and a story card.
## Returns their full name, or "" if there was no one to free.
func free_lost_champion(id: String) -> String:
	if id == "" or champions.has(id):
		return ""
	unlock_champion(id)
	_empty_post()
	var mem := champion_memory_line(id)
	if mem != "":
		pending_stories.append({"title": tr("A champion is freed"), "subtitle": GameData.champion_full_name(id),
			"text": tr("The pillar of light gives way, and %s steps out of it. %s\n\n%s") % [GameData.champion_full_name(id), tr(str(GameData.champion_def(id).get("lore", ""))), mem]})
	return GameData.champion_full_name(id)


## The next lost champion still held in a pillar (in roll order), or "".
func next_lost_champion() -> String:
	for e in lost_champions():
		if not champion_unlocked(str(e[0])):
			return str(e[0])
	return ""


# ---------------- The Descent ----------------
## The rank the Descent is fought at: the guild's best sealed rank.
func descent_rank() -> String:
	return str(GameData.RIFT_RANKS[clampi(best_rift_rank_sealed, 0, GameData.RIFT_RANKS.size() - 1)]["id"])


func start_descent(hero_ids: Array[String], starting_relic: Relic) -> void:
	var rank := descent_rank()
	start_run(str(GameData.find_rift_rank(rank)["base"]), hero_ids, starting_relic, rank)
	if run.is_empty():
		return
	run["descent"] = 1
	run["layers"] = _descent_layers(1)
	run["chosen"] = {}
	run["node_kind"] = ""
	run["node_state"] = {}
	auto_resolve_single_option()
	save()
	state_changed.emit()


## One depth of the Descent: a fight (a campfire from depth 2), two forks,
## and its guardian, or a lost champion's pillar every few depths.
func _descent_layers(depth: int) -> Array:
	var d := _diff().duplicate()
	d["floors"] = GameData.DESCENT_FLOORS
	d["lanes"] = 0   # the Descent keeps its two-way forks
	var layers: Array = Combat.build_layers(d)
	if depth > 1:
		layers[0] = {"options": ["campfire"]}
	var pillar := depth % GameData.DESCENT_PILLAR_EVERY == 0 and next_lost_champion() != ""
	layers[layers.size() - 1] = {"options": ["pillar" if pillar else "elite"]}
	return layers


## A Descent that ends in defeat loses part of what it earned.
## The Gold and Essence this run has earned so far (never below zero).
func haul() -> Vector2i:
	return Vector2i(maxi(0, coins - int(run.get("start_coins", coins))), maxi(0, crystals - int(run.get("start_crystals", crystals))))


## Whether a lost or fled fight costs part of the haul (GameData.HAUL_LOSS).
func haul_at_risk() -> bool:
	return not run.is_empty() and not run.has("tower") and not run.get("training", false) and hardship >= 0 \
		and (run.has("descent") or feature_unlocked("resolve"))


## A campfire's Rest (Hardship 9 lowers it).
func campfire_heal_pct() -> float:
	return maxf(0.05, GameData.CAMPFIRE_HEAL_PCT + year_add("campfire_heal"))


## Path relics (0.65): sealing a Rank D+ ladder rift (not a breach, the
## Descent, the Tower or a finale) offers 1 of 3 GameData.PATH_RELICS.
func path_relic_eligible() -> bool:
	var rr := str(run.get("rift_rank", ""))
	return rr != "" and GameData.rift_rank_index(rr) >= GameData.rift_rank_index("D") and int(run.get("finale", 0)) == 0 \
		and not run.has("tower") and not run.has("breach") and not run.has("descent") and not run.get("training", false)


## Up to 3 Path relic ids the guild doesn't own: two for Paths in the party
## when it can, the rest from anywhere.
func roll_path_relic_offer() -> Array:
	var owned := {}
	for r in relics:
		owned[r.unique_id] = true
	var paths := {}
	for h in current_party():
		paths[GameData.hero_path_id(h)] = true
	var pool: Array = GameData.PATH_RELICS.filter(func(d): return not owned.has(str(d["id"])))
	pool.shuffle()
	var offer: Array = []
	for d in pool:
		if offer.size() < 2 and paths.has(str(d["path"])):
			offer.append(str(d["id"]))
	for d in pool:
		if offer.size() < (4 if has_wing("reliquary") else 3) and not offer.has(str(d["id"])):
			offer.append(str(d["id"]))
	return offer


## The Essence a sealed rift pays instead of its Path relic.
func path_relic_essence() -> int:
	return maxi(10, int(round(float(_diff()["seal_essence"]) * 0.5)))


## Takes offered Path relic `idx`, or Essence instead (idx < 0).
func pick_path_relic(idx: int) -> void:
	var s = run.get("sealed")
	if not s is Dictionary or (s.get("path_relics", []) as Array).is_empty() or s.has("relic_taken"):
		return
	var offer: Array = s["path_relics"]
	if idx >= 0 and idx < offer.size():
		var r := Combat.relic_from_unique(GameData.find_unique_relic(str(offer[idx])))
		_grant_loot({"loot_type": "relic", "obj": r})
		s["relic_taken"] = r.name
	else:
		var e := path_relic_essence()
		crystals += e
		s["relic_taken"] = ""
		s["relic_essence"] = e
	save()
	state_changed.emit()


## The value of an equipped Path relic's "pmod" outside a fight (0 if none).
func path_relic_value(key: String) -> float:
	for r in Combat.equipped_relics():
		if r.unique_id.begins_with("p_"):
			var d := GameData.find_unique_relic(r.unique_id)
			if str(d.get("pmod", "")) == key:
				return float(d["value"])
	return 0.0


## Resolve (0.64) counts once the haul does (after the first seals), and only
## in runs that started with it (an older saved run has none).
func resolve_on() -> bool:
	return haul_at_risk() and run.has("resolve")


func resolve_now() -> int:
	return int(run.get("resolve", GameData.RESOLVE_START))


## 0 Steady, 1 Wavering (foes act first in round 1), 2 Broken (also no
## starting Momentum and less damage).
func resolve_tier() -> int:
	if not resolve_on():
		return 0
	var r := resolve_now()
	return 2 if r <= 0 else (1 if r <= GameData.RESOLVE_WAVER else 0)


## Moves Resolve by `n` (clamped); returns the real change (0 when it's off).
func change_resolve(n: int) -> int:
	if not resolve_on() or n == 0:
		return 0
	var before := resolve_now()
	run["resolve"] = clampi(before + n, 0, GameData.RESOLVE_MAX)
	return int(run["resolve"]) - before


## A choice card's "+3 Resolve" line, or "" while Resolve is off.
func resolve_hint(n: int) -> String:
	return tr("%+d Resolve") % n if resolve_on() and n != 0 else ""


## A lost ("fell") or fled fight drops its share of the haul, once per run.
func _drop_haul(why: String) -> void:
	note_milestone("first fall" if why == "fell" else "first flee")
	if not haul_at_risk() or run.has("haul_lost"):
		return
	var h := haul()
	var share := minf(1.0, float(GameData.HAUL_LOSS[why]) + (year_add("haul_fell") if why == "fell" else 0.0))
	var lost := Vector2i(int(h.x * share), int(h.y * share))
	coins -= lost.x
	crystals -= lost.y
	run["haul_lost"] = [lost.x, lost.y]
	if lost == Vector2i.ZERO:
		return
	if run.has("descent"):
		_news(tr("The party fell at depth %d of the Descent and lost %d Gold and %d Essence on the way out.") % [int(run["descent"]), lost.x, lost.y])
	else:
		_news((tr("The party fell and lost %d Gold and %d Essence on the way out.") if why == "fell" else tr("The party fled and dropped %d Gold and %d Essence on the way out.")) % [lost.x, lost.y])


## Whether a ladder rift of `rank_id` may hold a lost champion's pillar.
func ladder_pillar_open(rank_id: String) -> bool:
	return endless_unlocked() and GameData.rift_rank_index(rank_id) >= GameData.rift_rank_index(GameData.PILLAR_MIN_RANK) and next_lost_champion() != ""


## Puts a pillar on one of the run's forks.
func _add_pillar() -> void:
	var layers: Array = run["layers"]
	if layers.size() < 3:
		return
	var opts: Array = layers[1 + randi() % (layers.size() - 2)]["options"]
	opts[randi() % opts.size()] = "pillar"


## The guild's Endless Rift title (the last milestone title earned), or "".
func endless_title() -> String:
	var t := ""
	if not GameData.ENDLESS_ENABLED:
		return t
	for m in GameData.ENDLESS_MILESTONES:
		if m.has("title") and endless_milestones.has(int(m["at"])):
			t = str(m["title"])
	return t


# ---------------- Downed mid-rift ----------------

## Adds every roster hero in the party who's down and not yet decided on to
## run["injured"] — the rift can't continue until each is dealt with.
func _note_injuries(severity: String) -> void:
	var injured: Array = run.get("injured", [])
	for hid in run.get("hero_ids", []):
		var h := find_hero(str(hid))
		if h and h.hp <= 0 and not injured.any(func(e): return str(e["id"]) == h.id):
			injured.append({"id": h.id, "severity": severity})
	run["injured"] = injured


func pending_injuries() -> Array:
	return run.get("injured", [])


func _injury(hero_id: String) -> Dictionary:
	for e in run.get("injured", []):
		if str(e["id"]) == hero_id:
			return e
	return {}


func _resolve_injury(hero_id: String, leave_party: bool) -> void:
	run["injured"] = (run.get("injured", []) as Array).filter(func(e): return str(e["id"]) != hero_id)
	if leave_party:
		run["hero_ids"] = (run.get("hero_ids", []) as Array).filter(func(x): return str(x) != hero_id)


## Idle roster heroes who could go fetch someone: not in the rift, not
## recovering, not already away — the lowest level first.
func idle_heroes() -> Array[Hero]:
	var out: Array[Hero] = []
	var in_rift: Array = run.get("hero_ids", [])
	for h in heroes:
		if not in_rift.has(h.id) and h.is_available():
			out.append(h)
	out.sort_custom(func(a, b): return a.level < b.level)
	return out


## Who in the party can patch a downed hero up mid-rift ("" if nobody).
func field_healer() -> String:
	if bool(run.get("heal_used", false)):
		return ""
	var min_rank := GameData.rank_index(GameData.FIELD_HEALER_MIN_RANK)
	for hid in run.get("hero_ids", []):
		var h := find_hero(str(hid))
		if h and h.hp > 0 and GameData.hero_role(h) == "cleric" and GameData.rank_index(h.rank) >= min_rank:
			return h.name.split(" the ")[0]
	if field_triage_available():
		return tr("Field Triage")
	return ""


## Carry them out: a day passes and they head home.
func injury_carry(hero_id: String) -> String:
	if _injury(hero_id).is_empty():
		return ""
	_resolve_injury(hero_id, true)
	if not Combat.party_has_unique_relic("lantern_of_the_lost"):
		pass_time()
	save()
	state_changed.emit()
	return ""


func injury_reinforce(hero_id: String) -> String:
	var e := _injury(hero_id)
	if e.is_empty():
		return ""
	var sev := str(e["severity"])
	var need := int(GameData.INJURY_REINFORCEMENTS[sev])
	var idle := idle_heroes()
	if idle.size() < need:
		return tr("Needs %d idle hero%s at camp") % [need, GameData.pl(need, "es")]
	for i in need:
		idle[i].busy_runs = int(GameData.INJURY_BUSY_RUNS[sev])
	_resolve_injury(hero_id, true)
	save()
	state_changed.emit()
	return ""


func injury_heal(hero_id: String) -> String:
	if _injury(hero_id).is_empty():
		return ""
	if field_healer() == "":
		return tr("No healer can do it")
	var h := find_hero(hero_id)
	h.down_runs = 0
	h.battered = true
	h.hp = max(1, int(round(Combat.max_hp(h) * GameData.FIELD_HEAL_HP_PCT)))
	run["heal_used"] = true
	_resolve_injury(hero_id, false)
	save()
	state_changed.emit()
	return ""


func injury_leave(hero_id: String) -> String:
	if _injury(hero_id).is_empty():
		return ""
	if rifts_sealed < 3:
		return tr("A new guild can't leave anyone behind")
	var lb: Array = run.get("left_behind", [])
	lb.append(hero_id)
	run["left_behind"] = lb
	_resolve_injury(hero_id, true)
	save()
	state_changed.emit()
	return ""


## Sealing the rift finds everyone left behind alive; they come home to recover.
func _rescue_left_behind() -> void:
	for hid in run.get("left_behind", []):
		var h := find_hero(str(hid))
		if h:
			push_toast(h, tr("Found alive"), tr("%s is carried home from the sealed rift") % tr(str(h.name.split(" the ")[0])))
	run["left_behind"] = []


## The run ended without a seal: anyone left in the rift is lost. Their gear
## is recovered and returns to the Inventory.
func _lose_left_behind() -> void:
	for hid in run.get("left_behind", []):
		var h := find_hero(str(hid))
		if not h:
			continue
		for it in items:
			if it.equipped_to == h.id:
				it.equipped_to = ""
				it.equipped_idx = -1
		push_toast(h, tr("Lost in the rift"), tr("%s was left behind and never came back") % tr(str(h.name.split(" the ")[0])))
		_memorialize(h, tr("Left behind in a %s") % tr(str(_run_label())))
		heroes.erase(h)
		run["heroes_lost"] = int(run.get("heroes_lost", 0)) + 1
	run["left_behind"] = []


## True for any hero worth a bed — actually downed, or merely wounded (hp
## below max but still able to fight). Beds are a shared resource across
## both, matching the original design intent ("heroes without a bed still
## recover, just at the normal slower passive rate").
func needs_recovery(h: Hero) -> bool:
	return h.is_downed() or (h.hp > 0 and h.hp < Combat.max_hp(h))


func assign_to_bed(hero_id: String) -> void:
	var h := find_hero(hero_id)
	if not h or h.bedded or not needs_recovery(h):
		return
	if occupied_beds() >= medical_bed_cap():
		return
	# A bed takes one run off a downed hero's recovery (never below one), and
	# heals a wounded one fully the next time time passes (see pass_time).
	if h.is_downed() and not sworn("no_rest"):
		h.down_runs = max(1, h.down_runs - 1)
	h.bedded = true
	save()
	state_changed.emit()


func occupied_beds() -> int:
	var n := 0
	for h in heroes:
		if h.bedded and needs_recovery(h):
			n += 1
	return n


## Safety net, run once per render(): a hero at 0 HP who somehow isn't
## counting down (older saves) starts recovering, and a bed held by someone
## who no longer needs it is freed.
func resolve_recovery() -> void:
	var changed := false
	for h in heroes:
		if h.hp <= 0 and h.down_runs <= 0:
			knock_out(h)
			changed = true
		elif h.bedded and not needs_recovery(h):
			h.bedded = false
			changed = true
	if changed:
		save()


## Guild time moves one step whenever a rift run ends (or the guild rests
## instead): downed heroes count down their recovery and wounded ones heal.
func pass_time() -> void:
	day += 1
	var in_rift: Array = run.get("hero_ids", []) if not run.is_empty() else []
	for hid in in_rift:
		var hr := find_hero(str(hid))
		if hr:
			hr.last_rift_day = day
	rival_day()
	recruit_day()
	if day % GameData.PAYDAY_DAYS == 0:
		run_payday()
	maybe_hero_request()
	_train_day()
	for h in heroes:
		if h.busy_runs > 0:
			h.busy_runs -= 1
		if in_rift.has(h.id):
			continue   # a day passing mid-rift (carrying someone out) doesn't rest the party
		var mx := Combat.max_hp(h)
		if h.down_runs > 0:
			h.down_runs = maxi(0, h.down_runs - 1 - int(founding_rule("recover", 0)))   # a Temple Order mends faster
			if h.down_runs == 0:
				h.hp = mx
				h.bedded = false
		elif h.hp > 0 and h.hp < mx:
			h.hp = mx if (h.bedded and not sworn("no_rest")) or full_heal_between_runs() else min(mx, h.hp + int(ceil(mx * GameData.WOUND_HEAL_PER_RUN)))
			if h.hp >= mx:
				h.bedded = false
	camp_day()
	resolve_guild_board()
	_on_day_passed()


## Rest instead of running a rift: time passes (see pass_time) without a
## fight — heroes recover.
func rest_guild() -> void:
	if not run.is_empty():
		return
	pass_time()
	save()
	state_changed.emit()


## "" when a ladder rank can be entered, else why not: each rank opens once
## the one below it is sealed, and C and up need the Greater Rift (Act II).
func ladder_rank_lock(rank_id: String) -> String:
	var idx := GameData.rift_rank_index(rank_id)
	if str(GameData.RIFT_RANKS[idx]["base"]) == "greater" and not greater_rift_unlocked():
		return tr("Opens when you complete Act I")
	if idx > best_rift_rank_sealed + 1:
		return tr("Seal a Rank %s rift first") % tr(str(GameData.RIFT_RANKS[idx - 1]["id"]))
	return ""


## The highest rank the guild can enter right now.
func highest_open_rank() -> String:
	var out := "F"
	for r in GameData.RIFT_RANKS:
		if ladder_rank_lock(str(r["id"])) == "":
			out = str(r["id"])
	return out


func start_ladder_rift(rank_id: String, hero_ids: Array[String], starting_relic: Relic) -> void:
	start_run(str(GameData.find_rift_rank(rank_id)["base"]), hero_ids, starting_relic, rank_id)
	if not run.is_empty() and ladder_pillar_open(rank_id) and randf() < GameData.PILLAR_CHANCE:
		_add_pillar()
		save()
	# The Charter War: Morrow waits at the bottom of the next Rank C+ rift.
	if company_hunting() and GameData.rift_rank_index(rank_id) >= GameData.rift_rank_index("C") and not run.is_empty():
		run["morrow"] = true
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr(str(GameData.MORROW_WAITS["title"])), "text": tr(str(GameData.MORROW_WAITS["text"]))})
		save()


func retreat_now() -> void:
	if run.has("tower"):
		_end_tower()
		return
	if run.has("descent"):
		_news(tr("The party climbed out of the Descent at depth %d.") % int(run["descent"]))
	if run.has("breach"):   # leaving a breach rift gives the breach up
		_breach_outcome(false)
	var ns: Dictionary = run.get("node_state", {})
	if ns.has("pre_hp") and not ns.has("result"):   # a fight begun (and reloaded) and then run from: fleeing
		_drop_haul("fled")
	_record_run("Retreated")
	_lose_left_behind()
	run = {}
	_clamp_hp_to_max()
	pass_time()
	save()
	state_changed.emit()


func finish_run() -> void:
	if run.get("sealed") != null:
		pick_path_relic(-1)   # an offer left untaken pays its Essence
	if run.has("tower"):
		_end_tower()
		return
	var outcome := _run_outcome()
	if outcome == "Defeated":
		for h in current_party():
			change_morale(h, GameData.MORALE_DEFEAT)
		_drop_haul("fell")   # usually already dropped when the fight ended
	elif outcome == "Retreated":
		_drop_haul("fled")
	if run.has("breach"):
		_breach_outcome(outcome == "Sealed")
	_record_run(outcome)
	_lose_left_behind()
	for h in current_party():   # an evolution's XP boost lasts XP_BOOST_RUNS rift runs
		h.xp_boost_runs = maxi(0, h.xp_boost_runs - 1)
	run = {}
	_clamp_hp_to_max()
	pass_time()
	save()
	state_changed.emit()


## A new guild's first three: a warrior, a cleric and a ranger or mage
## (Rank F), so a player's first step is a rift, not the recruit board.
func hire_starters() -> void:
	for roles in [["warrior"], ["cleric"], ["ranger", "mage"]]:
		heroes.append(Combat.gen_recruit("F", str(roles[randi() % roles.size()])))
	coins += weekly_wages()   # the founders pay their first week, so a new guild doesn't open in the red
