extends "res://scripts/autoload/game_state/GameStateItems.gd"
## GameState, part 4: the Guild Board, reputation and milestones.


# ---------------- Quests: Guild Board (Contracts + Dailies) & Milestones ----------------
## Every Reputation gain routes through here so crossing a 20-point tier can
## auto-arm a Shop Boost (an Epic at the next rift shop) —
## Reputation losses (none exist yet, but kept symmetrical) skip the roll.
func add_reputation(amount: int) -> void:
	if amount <= 0:
		reputation = maxi(0, reputation + amount)
		return
	amount = maxi(1, int(round(amount * float(founding_rule("renown", 1.0)) * year_mult("renown"))))
	var before := reputation / 20
	reputation += amount
	if reputation / 20 > before:
		pending_shop_boost = true


## ---------------- Guild Board ----------------
## QUEST_POSTED quests are posted at a time; accept up to QUEST_ACTIVE_MAX.
## Every QUEST_REFRESH_DAYS days (a day = one rift run or rest) the unaccepted
## postings are replaced; accepted ones stay until claimed or abandoned.
## Progress is read off quest_tally / the all-time counters minus a baseline
## taken when the quest is accepted, so only work done after accepting counts.

func _quest_reward(diff: int) -> Dictionary:
	match diff:
		3:
			return {"coins": 110 + randi() % 50, "crystals": 30 + randi() % 12, "reputation": 5}
		2:
			return {"coins": 70 + randi() % 40, "crystals": 14 + randi() % 9, "reputation": 2}
	return {"coins": 40 + randi() % 30, "crystals": 5 + randi() % 6, "reputation": 1}


func _tally(key: String) -> int:
	return int(quest_tally.get(key, 0))


func _bump(key: String, n: int = 1) -> void:
	quest_tally[key] = _tally(key) + n


## Rolls one posting of a random type the guild can actually attempt now.
func roll_quest() -> Dictionary:
	var types := ["hunt", "hunt", "elite", "bounty", "seal_rank", "trial_small", "trial_flawless", "flawless_win"]
	if feature_unlocked("crafting"):
		types.append("craft")
	if greater_rift_unlocked():
		types.append("seal_greater")
	var type: String = types[randi() % types.size()]
	var q := {"id": "quest%d" % next_id, "type": type, "param": "", "target": 1, "diff": 1, "status": "posted", "baseline": 0}
	next_id += 1
	match type:
		"hunt":
			var pool: Array = monsters_seen.filter(func(n): return GameData.MONSTER_NAMES.has(n))
			if pool.size() < 3:
				pool = GameData.MONSTER_NAMES
			q["param"] = str(pool[randi() % pool.size()])
			q["target"] = 4 + randi() % 4
		"elite":
			q["target"] = 1 + randi() % 2
			q["diff"] = q["target"]
		"bounty":
			q["param"] = str(GameData.BOSS_NAMES[randi() % GameData.BOSS_NAMES.size()])
			q["diff"] = 2
		"seal_rank":
			var r: int = clampi(max(best_rift_rank_sealed, 0) + randi() % 2, 1, 5)
			q["param"] = str(GameData.RIFT_RANKS[r]["id"])
			q["diff"] = 2 if r <= 3 else 3
		"seal_greater":
			q["diff"] = 3
		"trial_small":
			q["diff"] = 2
		"trial_flawless":
			q["diff"] = 3
		"craft":
			q["target"] = 1 + randi() % 2
		"flawless_win":
			q["target"] = 1 + randi() % 2
	q["reward"] = _quest_reward(int(q["diff"]))
	return q


## The all-time count a quest's progress is measured against.
func _quest_current(q: Dictionary) -> int:
	match str(q["type"]):
		"hunt": return int(monster_kill_counts.get(str(q["param"]), 0))
		"elite": return elites_won
		"bounty": return _tally("boss:" + str(q["param"]))
		"seal_rank":
			var n := 0
			for i in range(GameData.rift_rank_index(str(q["param"])), GameData.RIFT_RANKS.size()):
				n += _tally("rank_seals:%d" % i)
			return n
		"seal_greater": return _tally("greater_seals")
		"trial_small": return _tally("small_seals")
		"trial_flawless": return _tally("flawless_rifts")
		"craft": return crafts_performed
		"flawless_win": return flawless_wins
	return 0


func quest_progress(q: Dictionary) -> int:
	if str(q.get("status", "")) != "active":
		return 0
	return min(int(q["target"]), max(0, _quest_current(q) - int(q.get("baseline", 0))))


## Seeds a fresh board (new guild, or a save from the old contract/daily
## board) and refreshes postings when their days are up.
func resolve_guild_board() -> void:
	var changed := false
	if guild_board.is_empty() or guild_board.any(func(q): return not q.has("status")):
		guild_board = []
		board_refresh_day = day
		changed = true
	if day >= board_refresh_day:
		# The rival was after a posting that's coming down: it takes it.
		var grab := _rival_quest()
		if str(rival_event.get("type", "")) == "snatch" and (grab.is_empty() or str(grab["status"]) == "posted"):
			if not grab.is_empty():
				_news(tr("%s took the contract: %s.") % [tr(str(rival_name)), tr(str(quest_desc(grab)))])
			rival_event = {}
		guild_board.assign(guild_board.filter(func(q): return str(q["status"]) == "active"))
		while guild_board.filter(func(q): return str(q["status"]) == "posted").size() < GameData.QUEST_POSTED:
			guild_board.append(roll_quest())
		board_refresh_day = day + GameData.QUEST_REFRESH_DAYS
		changed = true
	# Contracts past their due day fail: Renown and everyone's morale drop.
	for q in guild_board:
		if str(q["status"]) == "active" and day > int(q.get("due", 1 << 30)) and quest_progress(q) < int(q["target"]):
			q["status"] = "failed"
			add_reputation(-2 * int(q.get("diff", 1)))
			for h in heroes:
				h.morale = clampi(h.morale + GameData.MORALE_QUEST_FAILED, 0, 100)
			_news(tr("Contract failed: %s (-%d Renown).") % [tr(str(quest_desc(q))), 2 * int(q.get("diff", 1))])
			pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("Contract failed"), "text": tr("%s ran out of time. -%d Renown, and the guild's morale dips.") % [tr(str(quest_desc(q))), 2 * int(q.get("diff", 1))]})
			changed = true
	if changed:
		save()


func active_quests() -> Array:
	return guild_board.filter(func(q): return str(q["status"]) == "active")


func accept_quest(quest_id: String) -> String:
	if active_quests().size() >= GameData.QUEST_ACTIVE_MAX:
		return tr("You can only take %d at a time") % GameData.QUEST_ACTIVE_MAX
	for q in guild_board:
		if str(q["id"]) == quest_id and str(q["status"]) == "posted":
			q["status"] = "active"
			q["baseline"] = _quest_current(q)
			q["due"] = day + int(GameData.QUEST_DUE_DAYS.get(int(q.get("diff", 1)), 6))
			if str(rival_event.get("type", "")) == "snatch" and str(rival_event.get("quest", "")) == quest_id:
				_news(tr("You took the contract before %s could: %s.") % [tr(str(rival_name)), tr(str(quest_desc(q)))])
				rival_event = {}
			save()
			state_changed.emit()
			return ""
	return ""


func abandon_quest(quest_id: String) -> void:
	guild_board.assign(guild_board.filter(func(q): return str(q["id"]) != quest_id))
	save()
	state_changed.emit()


func quest_desc(q: Dictionary) -> String:
	var t := int(q["target"])
	var s := GameData.pl(t)
	match str(q["type"]):
		"hunt": return tr("Hunt: defeat %s ×%d") % [tr(str(q["param"])), t]
		"elite": return tr("Hunt: win %d Elite fight%s") % [t, tr(str(s))]
		"bounty": return tr("Bounty: defeat %s") % tr(str(q["param"]))
		"seal_rank": return tr("Seal: seal a Rank %s+ rift") % tr(str(q["param"]))
		"seal_greater": return tr("Seal: seal a Rank C+ rift")
		"trial_small": return tr("Trial: seal a rift with 2 heroes or fewer")
		"trial_flawless": return tr("Trial: seal a rift without any hero going down")
		"craft": return tr("Supply: craft %d item%s or relic%s") % [t, tr(str(s)), tr(str(s))]
		"flawless_win": return tr("Trial: win %d fight%s without a hero going down") % [t, tr(str(s))]
	return "?"


func quest_reward_desc(reward: Dictionary) -> String:
	var parts: Array[String] = []
	if int(reward.get("coins", 0)) > 0:
		parts.append(tr("%d Gold") % int(reward["coins"]))
	if int(reward.get("crystals", 0)) > 0:
		parts.append(tr("%d Essence") % int(reward["crystals"]))
	if int(reward.get("reputation", 0)) > 0:
		parts.append(tr("%d Renown") % int(reward["reputation"]))
	return ", ".join(parts)


func claim_quest(quest_id: String) -> void:
	for q in guild_board:
		if str(q["id"]) != quest_id or quest_progress(q) < int(q["target"]):
			continue
		var reward: Dictionary = q["reward"]
		var ledger := 1.5 if Combat.party_has_unique_relic("quartermasters_ledger") else 1.0
		coins += int(round(int(reward.get("coins", 0)) * ledger * charter_pay(false)))
		crystals += int(round(int(reward.get("crystals", 0)) * ledger * charter_pay(true)))
		add_reputation(int(reward.get("reputation", 0)))
		guild_board.erase(q)
		_bump("quests_done")
		save()
		state_changed.emit()
		return


func milestone_progress(m: Dictionary) -> int:
	match str(m["type"]):
		"rifts_sealed": return rifts_sealed
		"total_kills":
			var s := 0
			for v in monster_kill_counts.values():
				s += int(v)
			return s
		"elites_won": return elites_won
		"bosses_won": return bosses_won
		"crafts_performed": return crafts_performed
		"full_roster": return 1 if heroes.size() >= hero_slot_cap() else 0
		"guild_tier_renowned":
			var tname := str(Combat.guild_tier_info()["name"])
			return 1 if tname == "Renowned Guild" or tname == "Legendary Guild" else 0
		"greater_unlocked": return 1 if greater_rift_unlocked() else 0
		"campaign_act": return campaign_act
		"flawless_rifts": return int(quest_tally.get("flawless_rifts", 0))
		"tower_best": return tower_best
		"endless_time": return best_endless_time
		"daily_clears": return daily_clears
		"daily_streak": return daily_streak
		"boon_set4": return 1 if boon_set4_reached else 0
		"guild_tier_legendary": return 1 if str(Combat.guild_tier_info()["name"]) == "Legendary Guild" else 0
		"standings_top": return 1 if day > 0 and str(guild_standings()[0]["name"]) == guild_name else 0
		"max_level": return 1 if heroes.any(func(h): return h.level >= 10) else 0
		"roster_size": return heroes.size()
		_: return 0


## Called once per render() — cheap (8-item loop) — grants any not-yet-claimed
## milestone the instant its condition becomes true. Returns the ids newly
## granted this call (usually 0 or 1) so the caller can show a flavor toast.
func check_milestones() -> Array[String]:
	var newly: Array[String] = []
	for m in GameData.milestones():
		var mid := str(m["id"])
		if milestones_claimed.has(mid):
			continue
		if milestone_progress(m) >= int(m["target"]):
			milestones_claimed.append(mid)
			var reward: Dictionary = m["reward"]
			coins += int(reward.get("coins", 0))
			crystals += int(reward.get("crystals", 0))
			add_reputation(int(reward.get("reputation", 0)))
			newly.append(mid)
	if not newly.is_empty():
		save()
		state_changed.emit()
	return newly


# ---------------- Running the guild: wages, morale, the rival ----------------

## A hero's weekly wage at their pay rate.
func wage_of(h: Hero) -> int:
	return wage_at(h, pay_rate_of(h))


func wage_at(h: Hero, rate: String) -> int:
	return int(round(float(GameData.WAGE_BY_RANK.get(h.rank, 15)) * (1.0 + GameData.WAGE_PER_LEVEL * (h.level - 1)) * (1.0 + float(wage_raise.get(h.id, 0.0))) * float(GameData.PAY_RATES[rate][0]) * float(founding_rule("wages", 1.0)) * year_mult("wages") * (1.5 if sworn("lean_purse") else 1.0) * (1.0 - hall_bonus("wages"))
		* (GameData.EPILOGUE_MOOT_WAGES if moot() and charter_result == "won" else 1.0)))


func pay_rate_of(h: Hero) -> String:
	return str(pay_rate.get(h.id, "full"))


func set_pay_rate(hero_id: String, rate: String) -> void:
	if not GameData.PAY_RATES.has(rate) or find_hero(hero_id) == null:
		return
	if rate == "full":
		pay_rate.erase(hero_id)
	else:
		pay_rate[hero_id] = rate
	save()
	state_changed.emit()


## Who payday would leave unpaid if it came now: wages go out in roster
## order while the Gold lasts (run_payday).
func unpaid_if_payday_now() -> Array:
	var left := coins
	var out: Array = []
	for h in heroes:
		var w := wage_of(h)
		if left >= w:
			left -= w
		else:
			out.append(h.id)
	return out


func weekly_wages() -> int:
	var total := 0
	for h in heroes:
		total += wage_of(h)
	return total


func days_to_payday() -> int:
	return GameData.PAYDAY_DAYS - (day % GameData.PAYDAY_DAYS)


## The coming payday at a glance: {days, wages, upkeep, bill, have, short,
## since (Gold gained since the last payday), per_run (average pay of the
## last few rifts, 0 if none), runs (rifts at that pay to cover the gap)}.
func payday_forecast() -> Dictionary:
	var w := weekly_wages()
	var up := upkeep()
	var bill := w + up
	var pays: Array = run_history.slice(0, 5).map(func(e): return int(e.get("coins", 0))).filter(func(c): return c > 0)
	var per_run := 0
	if not pays.is_empty():
		per_run = int(pays.reduce(func(a, b): return a + b, 0) / pays.size())
	var short := maxi(0, bill - coins)
	return {"days": days_to_payday(), "wages": w, "upkeep": up, "bill": bill, "have": coins, "short": short,
		"since": coins - (week_start_coins if week_start_coins >= 0 else coins), "per_run": per_run,
		"runs": (int(ceil(float(short) / per_run)) if per_run > 0 else -1) if short > 0 else 0}


# ---------------- Hero requests ----------------

## Mid-week, maybe a hero asks for something (see HERO_REQUESTS).
func maybe_hero_request() -> void:
	if not hero_request.is_empty() or not GameData.REQUEST_DAYS.has(day % GameData.PAYDAY_DAYS) or not feature_unlocked("requests"):
		return
	var in_rift: Array = run.get("hero_ids", []) if not run.is_empty() else []
	var pool: Array = heroes.filter(func(h): return not h.is_champion and not in_rift.has(h.id) and not h.is_downed() and h.busy_runs <= 0)
	if pool.is_empty():
		return
	pool.shuffle()
	# Every request someone could make, weighted: a request about who a hero is
	# (their Path, a scar, a bond) comes up twice as often as a generic one.
	var cands: Array = []   # [type, ids, weight]
	var total := 0.0
	for t in GameData.HERO_REQUESTS:
		var ids := _request_heroes(str(t), pool)
		if ids.is_empty():
			continue
		var def: Dictionary = GameData.HERO_REQUESTS[t]
		var w := 2.0 if not (def.get("need", {}) as Dictionary).is_empty() else 1.0
		cands.append([t, ids, w])
		total += w
	if cands.is_empty():
		return
	var roll := randf() * total
	var pick: Array = cands[0]
	for c in cands:
		roll -= float(c[2])
		if roll <= 0.0:
			pick = c
			break
	hero_request = {"type": pick[0], "ids": pick[1], "day": day}
	_news(request_title() + ".")   # it pops up at camp (Main._matter_overlay)


## Who would make request `t` (ids, the asker first), or [] if nobody fits.
func _request_heroes(t: String, pool: Array) -> Array:
	var def: Dictionary = GameData.HERO_REQUESTS[t]
	match t:
		"week_off", "raise", "gear":
			return [pool[0].id]
		"train":
			return [pool[0].id] if training_free() > 0 else []
		"feud":
			return [pool[0].id, pool[1].id] if pool.size() >= 2 else []
	for h in pool:
		if not _request_need_ok(h, def.get("need", {})):
			continue
		if not def.has("pair"):
			return [h.id]
		var mate := _request_mate(h, str(def["pair"]), pool)
		if mate:
			return [h.id, mate.id]
	return []


func _request_need_ok(h: Hero, need: Dictionary) -> bool:
	for k in need:
		var v = need[k]
		var ok := true
		match k:
			"role": ok = GameData.hero_role(h) == str(v)
			"path": ok = GameData.hero_path_id(h) != "" if str(v) == "any" else GameData.hero_path_id(h) == str(v)
			"quirk_origin": ok = h.quirks.any(func(q): return str(GameData.quirk(q).get("origin", "")) == str(v))
			"morale_below": ok = h.morale < int(v)
			"morale_above": ok = h.morale > int(v)
			"rank_min": ok = GameData.rank_index(h.rank) >= GameData.rank_index(str(v))
			"level_max": ok = h.level <= int(v) and h.seasoned == 0
			"knockouts_min": ok = int(h.history.get("knockouts", 0)) >= int(v)
			"rival": ok = rival_name != ""
			"act_min": ok = campaign_act >= int(v)
			"worn_forgeable": ok = _request_forge_item(h) != null
		if not ok:
			return false
	return true


## The second hero of a two-hero request.
func _request_mate(h: Hero, kind: String, pool: Array) -> Hero:
	var best: Hero = null
	for x in pool:
		if x == h:
			continue
		match kind:
			"bonded":
				if bond_rifts(h.id, x.id) >= GameData.BOND_LEVEL_RIFTS[0] and (best == null or bond_rifts(h.id, x.id) > bond_rifts(h.id, best.id)):
					best = x
			"junior":
				if x.level <= h.level - 3 and x.seasoned <= h.seasoned and (best == null or x.level < best.level):
					best = x
			"same_role":
				if GameData.hero_role(x) == GameData.hero_role(h):
					return x
	return best


## The worn piece a hero would temper themself (most forging left).
func _request_forge_item(h: Hero) -> Item:
	var best: Item = null
	for it in items:
		if it.equipped_to == h.id and forge_cost(it) > 0 and (best == null or it.forge_level < best.forge_level):
			best = it
	return best


func _request_names() -> Array:
	var out: Array = []
	for id in hero_request.get("ids", []):
		var h := find_hero(str(id))
		out.append(h.name.split(" the ")[0] if h else "someone")
	return out


func request_title() -> String:
	if hero_request.is_empty():
		return ""
	var def: Dictionary = GameData.HERO_REQUESTS[hero_request["type"]]
	return _request_fmt(tr(str(def["title"])))


## The request's story line, names filled in.
func request_text() -> String:
	if hero_request.is_empty():
		return ""
	return _request_fmt(tr(str(GameData.HERO_REQUESTS[hero_request["type"]]["text"])))


## Fills a translated line's %s with the heroes' names (one or two).
func _request_fmt(s: String) -> String:
	var n := _request_names().map(func(x): return tr(str(x)))
	match s.count("%s"):
		0:
			return s
		1:
			return s % n[0]
	return s % [n[0], n[1] if n.size() > 1 else n[0]]


## The two answers' button texts (translated, then filled in).
func request_options() -> Array:
	var def: Dictionary = GameData.HERO_REQUESTS[hero_request["type"]]
	var n := _request_names().map(func(x): return tr(str(x)))
	if hero_request["type"] == "feud":
		return [tr(str(def["yes"])) % n[0], tr(str(def["no"])) % n[1]]
	var yes := tr(str(def["yes"]))
	if yes.contains("%d"):
		yes = yes % int(def.get("yes_n", def.get("yes_gold", def.get("yes_ess", 0))))
	return [yes, tr(str(def["no"]))]


## Why "yes" can't be chosen right now, or "".
func request_blocked() -> String:
	if hero_request.is_empty():
		return ""
	var def: Dictionary = GameData.HERO_REQUESTS[hero_request["type"]]
	var gold := int(def.get("yes_gold", GameData.REQUEST_GEAR_COST if hero_request["type"] == "gear" else 0))
	if coins < gold:
		return tr("Not enough Gold.")
	if crystals < int(def.get("yes_ess", 0)):
		return tr("Not enough Essence.")
	return ""


## Answers this week's request. For a feud, "yes" sides with the first hero,
## "no" with the second. Returns "" or why it can't be done.
func answer_request(yes: bool) -> String:
	if hero_request.is_empty():
		return tr("No request is waiting.")
	var t := str(hero_request["type"])
	var def: Dictionary = GameData.HERO_REQUESTS[t]
	var hs: Array = (hero_request["ids"] as Array).map(func(id): return find_hero(str(id))).filter(func(h): return h != null)
	if hs.is_empty():
		hero_request = {}
		return ""
	var h: Hero = hs[0]
	if def.has("yes_fx"):   # a 0.66 request: data-driven
		var fx: Dictionary = def["yes_fx"] if yes else def.get("no_fx", {})
		if yes:
			var why := request_blocked()
			if why != "":
				return why
			coins -= int(def.get("yes_gold", 0))
			crystals -= int(def.get("yes_ess", 0))
			if def.has("yes_chance") and randf() >= float(def["yes_chance"]):
				fx = def.get("yes_fail", {})
		_request_fx(fx, hs)
	elif t == "feud":
		if hs.size() >= 2:
			var winner: Hero = hs[0] if yes else hs[1]
			var loser: Hero = hs[1] if yes else hs[0]
			change_morale(winner, int(def["yes_morale"]))
			change_morale(loser, int(def["no_morale"]))
	elif yes:
		match t:
			"week_off":
				h.busy_runs = maxi(h.busy_runs, GameData.REQUEST_LEAVE_DAYS)
			"raise":
				wage_raise[h.id] = float(wage_raise.get(h.id, 0.0)) + GameData.REQUEST_RAISE
			"gear":
				if coins < GameData.REQUEST_GEAR_COST:
					return tr("Not enough Gold.")
				coins -= GameData.REQUEST_GEAR_COST
			"train":
				# A free day at the yard, in the hero's strongest attribute.
				var best: String = GameData.ATTRIBUTES.reduce(func(a, b): return a if int(h.attrs.get(a, 0)) >= int(h.attrs.get(b, 0)) else b)
				var why := start_training(h.id, best, 1, true)
				if why != "":
					return why
		change_morale(h, int(def["yes_morale"]))
	else:
		change_morale(h, int(def["no_morale"]))
	hero_request = {}
	save()
	state_changed.emit()
	return ""


## A 0.66 request's effects on its heroes (`hs`: the asker first).
func _request_fx(fx: Dictionary, hs: Array) -> void:
	var h: Hero = hs[0]
	var h2: Hero = hs[1] if hs.size() > 1 else null
	for k in fx:
		var v = fx[k]
		match k:
			"morale":
				change_morale(h, int(v))
			"morale_pair":
				for x in hs:
					change_morale(x, int(v))
			"morale_all":
				for x in heroes:
					if not x.is_champion:
						change_morale(x, int(v))
			"xp":
				_xp_share(h, float(v))
			"xp_pair":
				for x in hs:
					_xp_share(x, float(v))
			"xp2":
				if h2:
					_xp_share(h2, float(v))
			"quirk":
				give_quirk(h, str(v))
			"title":
				give_title(h, str(v))
			"bond":
				if h2:
					var key := _bond_key(h.id, h2.id)
					bonds[key] = int(bonds.get(key, 0)) + int(v)
			"renown":
				add_reputation(int(v))
			"resolve":
				if resolve_counts():
					next_resolve = clampi(next_resolve + int(v), -GameData.RESOLVE_MAX, GameData.RESOLVE_MAX)
			"busy":
				h.busy_runs = maxi(h.busy_runs, int(v))
			"busy_pair":
				for x in hs:
					x.busy_runs = maxi(x.busy_runs, int(v))
			"hurt":
				h.hp = maxi(1, h.hp - int(Combat.max_hp(h) * float(v)))
			"forge":
				var it := _request_forge_item(h)
				if it:
					coins += forge_cost(it)   # forge_item takes the price; this one is free
					forge_item(it.id)
			"gold_pct":
				coins -= mini(150, int(coins * float(v)))   # ponytail: a flat cap; scale with the act if it bites late


## `share` of a level's XP (nothing at level 10).
func _xp_share(h: Hero, share: float) -> void:
	if h.level < 10:
		Combat.gain_xp(h, int(round(Combat.xp_to_next(h.level, h.rank) * share)))


func change_morale(h: Hero, delta: int) -> void:
	h.morale = clampi(h.morale + delta, 0, 100)


## Every PAYDAY_DAYS days: wages go out (as many heroes as Gold covers, in
## roster order), the unpaid lose morale, idle heroes grow restless, and a
## hero unpaid twice running or at rock-bottom morale walks out (never one
## on a rift right now). Then the guild is compared with its rival.
func run_payday() -> void:
	note_milestone("first payday")
	_maybe_audit()   # B3's price, once in Act IV
	if not hero_request.is_empty():
		_news(tr("%s — no answer by payday, taken as a no.") % tr(str(request_title())))
		answer_request(false)
	_close_rival_event()
	var in_rift: Array = run.get("hero_ids", []) if not run.is_empty() else []
	var paid := 0
	var unpaid: Array[String] = []
	for h in heroes:
		var w := wage_of(h)
		if coins >= w:
			coins -= w
			paid += w
			h.unpaid_weeks = 0
			change_morale(h, int(GameData.PAY_RATES[pay_rate_of(h)][1]))
		else:
			h.unpaid_weeks += 1
			change_morale(h, GameData.MORALE_UNPAID)
			unpaid.append(h.name.split(" the ")[0])
		if day - h.last_rift_day >= GameData.PAYDAY_DAYS and not in_rift.has(h.id):
			change_morale(h, GameData.MORALE_IDLE_WEEK)
	# Then the facilities: unpaid upkeep costs Renown.
	var up := upkeep()
	var upkeep_paid := up <= coins
	if upkeep_paid:
		coins -= up
	elif up > 0:
		add_reputation(-GameData.UPKEEP_UNPAID_RENOWN)
	var left: Array[String] = []
	for h in heroes.duplicate():
		if in_rift.has(h.id) or heroes.size() <= 1:
			continue
		if h.unpaid_weeks >= GameData.UNPAID_WEEKS_TO_LEAVE or h.morale <= GameData.MORALE_WALKOUT or (h.unpaid_weeks >= 1 and h.history.has("morrow")):   # Morrow walks at once
			left.append(h.name.split(" the ")[0])
			_release(h)
	var volunteers: Array[String] = []
	while heroes.size() < GameData.VOLUNTEER_FLOOR and coins < int(GameData.find_rank("F")["cost"]):
		var vh := Combat.gen_recruit("F")
		heroes.append(vh)
		volunteers.append(vh.name.split(" the ")[0])
	if not volunteers.is_empty():
		_news(tr("Volunteers joined the guild: %s.") % ", ".join(volunteers))
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("Volunteers"), "text": tr("%s joined for free. A guild short on heroes and Gold draws volunteers; Rank F rifts pay enough to rebuild.") % ", ".join(volunteers)})
	var was_ahead := int(payday_report.get("ahead", 0))
	rival_ahead = 1 if reputation > rival_renown else (-1 if reputation < rival_renown else 0)
	var past := _past_pick()
	var scene := _payday_scene(payday_report, left, unpaid, was_ahead, past)
	payday_report = {"day": day, "due": paid + unpaid.size(), "paid": paid, "unpaid": unpaid, "left": left, "ahead": rival_ahead, "upkeep": up, "upkeep_paid": upkeep_paid,
		"scene": scene, "lost_total": heroes_lost_total}
	if scene.begins_with("past"):
		payday_report["past"] = past["guild"]
		payday_report["past_hero"] = past["hero"]
	var line := tr("Payday: %d Gold in wages, %s.") % [paid, tr(str((tr("%d in upkeep") % up) if upkeep_paid else tr("upkeep unpaid (-%d Renown)") % GameData.UPKEEP_UNPAID_RENOWN))]
	if not unpaid.is_empty():
		line += tr(" Unpaid: %s.") % tr(str(", ".join(unpaid)))
	if not left.is_empty():
		line += tr(" Walked out: %s.") % tr(str(", ".join(left)))
	_news(line)
	_news(tr("%s the %s (Renown %d vs %d).") % [tr(str(tr("Your guild leads") if rival_ahead > 0 else (tr("The guild trails") if rival_ahead < 0 else tr("Your guild is level with")))), tr(str(rival_name)), reputation, rival_renown] + (tr(" Recruits favor you this week: +1 offer.") if rival_ahead > 0 else (tr(" Recruits favor them this week: -1 offer.") if rival_ahead < 0 else "")))
	recruit_top_up()
	var text := tr("%d Gold in wages, %s") % [paid, tr(str((tr("%d upkeep") % up) if upkeep_paid else tr("upkeep unpaid (-%d Renown)") % GameData.UPKEEP_UNPAID_RENOWN))]
	if not unpaid.is_empty():
		text += tr(" · couldn't pay %s") % tr(str(", ".join(unpaid)))
	if not left.is_empty():
		text += tr(" · %s walked out") % tr(str(", ".join(left)))
	pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("Payday"), "text": text + "."})
	week_start_coins = coins


## Which pay-table scene (GameData.PAYDAY_SCENES) this payday gets: the
## week's biggest news first, else a quiet one that isn't last week's.
func _payday_scene(prev: Dictionary, left: Array, unpaid: Array, was_ahead: int, past: Dictionary = {}) -> String:
	if prev.is_empty():
		if not hesper_posted():
			hear_claim("hesper_fever")
		return "first"
	if not left.is_empty():
		return "walkout"
	if heroes_lost_total > int(prev.get("lost_total", heroes_lost_total)):
		return "lost"
	if not unpaid.is_empty():
		return "unpaid"
	var last := str(prev.get("scene", ""))
	if feast_week >= 0 and feast_week == maxi(0, day - 1) / GameData.PAYDAY_DAYS and last != "feast":   # a feast in the week just ending
		return "feast"
	if feature_unlocked("rival") and rival_ahead != was_ahead and rival_ahead != 0:
		return "we_lead" if rival_ahead > 0 else "they_lead"
	if coins > 3 * maxi(1, weekly_wages() + upkeep()) and last != "rich":
		return "rich"
	var spire := "spire_" + str(branches.get("spire", ""))   # B10, once: what came of the Spire
	if spire != "spire_" and not branches.has("spire_scene") and _scene_ok(spire):
		branches["spire_scene"] = "told"
		return spire
	var lore := lore_payday_scene(last)   # the story web
	if lore != "":
		return lore
	var fits: Array = (past.get("scenes", []) as Array).filter(func(s): return _scene_ok(str(s)))
	if not fits.is_empty() and not last.begins_with("past") and randf() < GameData.PAST_SCENE_CHANCE:
		return str(fits[randi() % fits.size()])
	if accord_pages > 0 and last != "accord" and _scene_ok("accord") and randf() < 0.3:
		return "accord"
	var quiet: Array = ["quiet1", "quiet2", "quiet3", "quiet4", "quiet5", "quiet6"].filter(func(q): return q != last and _scene_ok(q))
	return str(quiet[randi() % quiet.size()])


## A scene that can play: while Hesper holds the post, none she leads.
func _scene_ok(id: String) -> bool:
	return not hesper_posted() or not (GameData.PAYDAY_SCENES.get(id, []) as Array).any(func(l): return str(l[0]) == "Hesper")


## A past guild from the Hall of Guilds for a pay-table scene: its name, a
## hero it remembered, and the scenes that fit how it ended.
func _past_pick() -> Dictionary:
	var hall: Array = legacy.get("guilds", [])
	if hall.is_empty():
		return {}
	var g: Dictionary = hall[randi() % hall.size()]
	var names: Array = g.get("remembered", [])
	var fits: Array = ["past_paytable", "past_banner", "past_books"]
	if not names.is_empty():
		fits.append("past_hero")
	fits.append({"renew": "past_renew", "break": "past_break", "rewrite": "past_rewrite"}.get(str(g.get("ending", "")), "past_retired"))
	var b: Dictionary = g.get("branches", {})   # what it chose on the way
	if b.has("spire"):
		fits.append("past_" + str(b["spire"]))
	if bool(g.get("quiet", false)):
		fits.append("past_quiet")
	if str(b.get("vaelith", "")) == "spared":
		fits.append("past_vaelith")
	return {"guild": str(g.get("name", "")), "hero": str(names[randi() % names.size()]) if not names.is_empty() else "", "scenes": fits}


## A hero leaves the guild (dismissed or walked out): their gear returns to
## the stockpile.
func _release(h: Hero) -> void:
	for it in items:
		if it.equipped_to == h.id:
			it.equipped_to = ""
			it.equipped_idx = -1
	pay_rate.erase(h.id)
	set_down_path_relic(h)
	for p in party_presets:
		for entry in (p as Array).duplicate():
			if str(entry[0]) == h.id:
				p.erase(entry)
	heroes.erase(h)


## Let a hero go. Not while they're on a rift, and never the last one.
func dismiss_hero(hero_id: String) -> String:
	var h := find_hero(hero_id)
	if h == null:
		return ""
	if not run.is_empty() and (run.get("hero_ids", []) as Array).has(hero_id):
		return tr("They're on a rift right now")
	if heroes.size() <= 1:
		return tr("The guild needs at least one hero")
	_release(h)
	_news(tr("%s left the guild.") % tr(str(h.name.split(" the ")[0])))
	save()
	state_changed.emit()
	return ""


func feast_cost() -> int:
	return GameData.FEAST_COST_PER_HERO * mini(heroes.size(), feast_seats())


func feast_ready() -> bool:
	return feast_week != day / GameData.PAYDAY_DAYS


## Once a week: Gold for +FEAST_MORALE morale for every hero.
func hold_feast() -> String:
	if not feast_ready():
		return tr("Already feasted this week")
	if coins < feast_cost():
		return tr("Not enough Gold")
	coins -= feast_cost()
	feast_week = day / GameData.PAYDAY_DAYS
	var guests: Array = heroes.duplicate()
	guests.sort_custom(func(a, b): return a.morale < b.morale)
	guests = guests.slice(0, feast_seats())
	for h in guests:
		change_morale(h, int(round(GameData.FEAST_MORALE * year_mult("feast"))))
	_news(tr("A feast in the hall: +%d morale for %d hero%s%s.") % [int(round(GameData.FEAST_MORALE * year_mult("feast"))), guests.size(), GameData.pl(guests.size(), "es"), tr(str("" if guests.size() == heroes.size() else tr(" (no seats for %d)") % (heroes.size() - guests.size())))])
	save()
	state_changed.emit()
	return ""


## The rival's day: it gains Renown (more each act), and once a week it may
## make a move you have to answer (maybe_rival_move).
func rival_day() -> void:
	var span: Array = GameData.RIVAL_DAILY_RENOWN[mini(3, campaign_act)]
	rival_renown += int(round((int(span[0]) + randi() % (int(span[1]) - int(span[0]) + 1)) * year_mult("rival_renown") * (GameData.GRUDGE_RENOWN if grudge != "" else 1.0))) + (1 if reputation - rival_renown >= GameData.RIVAL_CATCH_UP else 0)
	maybe_rival_move()
	if randf() < GameData.RIVAL_TAUNT_CHANCE:
		var taunts: Array = GameData.RIVAL_VOICE.get(rival_name, {}).get("taunts", GameData.RIVAL_TAUNTS)
		var taunt := tr(str(taunts[randi() % taunts.size()]))
		var held := guild_name
		if grudge != "" and randf() < GameData.GRUDGE_TAUNT_CHANCE:   # an old score
			taunt = tr(str(GameData.GRUDGE_TAUNTS[randi() % GameData.GRUDGE_TAUNTS.size()]))
			held = grudge
		_news(tr("%s of %s: \"%s\"") % [tr(str(rival_leader()["leader"])), tr(str(rival_name)), taunt % held if taunt.contains("%s") else taunt])
	# This month's contest.
	if contest_start.is_empty():
		contest_start = {"ours": reputation, "theirs": rival_renown}
	if day % GameData.CONTEST_DAYS == 0:
		_end_contest()


# ---------------- The rival's moves ----------------

## On RIVAL_MOVE_DAY the rival may make a move (one at a time): court your
## strongest hero, dare you to seal a rift by payday, or go for a posted
## contract. Each waits in rival_event for an answer.
func maybe_rival_move() -> void:
	if not feature_unlocked("rival") or not rival_event.is_empty() or day % GameData.PAYDAY_DAYS != GameData.RIVAL_MOVE_DAY or randf() >= GameData.RIVAL_MOVE_CHANCE * year_mult("rival_moves"):
		return
	var moves: Array = []
	var target := _poach_target()
	if target:
		moves.append({"type": "poach", "hero": target.id})
	if rifts_sealed >= 1:
		moves.append({"type": "challenge", "rank": str(GameData.RIFT_RANKS[clampi(best_rift_rank_sealed, 0, GameData.RIFT_RANKS.size() - 1)]["id"])})
	var posted: Array = guild_board.filter(func(q): return str(q["status"]) == "posted")
	if not posted.is_empty():
		moves.append({"type": "snatch", "quest": str(posted[randi() % posted.size()]["id"])})
	if moves.is_empty():
		return
	rival_event = moves[randi() % moves.size()]
	# This year's temperament: its favourite move, when it can make it.
	var fav := str(GameData.RIVAL_TEMPERS.get(str(vale_year.get("temper", "")), {}).get("move", ""))
	var favs := moves.filter(func(m): return str(m["type"]) == fav)
	if not favs.is_empty() and randf() < GameData.RIVAL_TEMPER_PULL:
		rival_event = favs[0]
	rival_event["day"] = day
	rival_event["ps"] = lore_letter_ps()   # the story web: a postscript
	_news(rival_event_title() + ".")


## The hero the rival courts: your strongest who isn't on a rift, and only
## once the guild is big enough to lose one.
func _poach_target() -> Hero:
	var in_rift: Array = run.get("hero_ids", []) if not run.is_empty() else []
	var pool: Array = heroes.filter(func(h): return not h.is_champion and not in_rift.has(h.id))
	if heroes.size() < GameData.POACH_MIN_ROSTER or pool.is_empty():
		return null
	pool.sort_custom(func(a, b): return Combat.power_of(a) > Combat.power_of(b))
	return pool[0]


func _rival_quest() -> Dictionary:
	for q in guild_board:
		if str(q["id"]) == str(rival_event.get("quest", "")):
			return q
	return {}


## What a counter-offer to keep a courted hero costs.
func poach_counter_cost(h: Hero) -> int:
	return wage_of(h) * GameData.POACH_COUNTER_WEEKS


func rival_event_title() -> String:
	var rn := tr(str(rival_name))
	match str(rival_event.get("type", "")):
		"poach":
			var h := find_hero(str(rival_event["hero"]))
			return tr("%s is courting %s") % [rn, tr(str(h.name.split(" the ")[0])) if h else tr("a hero")]
		"challenge":
			return tr("%s dares you to seal a Rank %s rift by payday") % [rn, tr(str(rival_event["rank"]))]
		"snatch":
			return tr("%s is after one of your posted contracts") % rn
	return ""


func rival_event_text() -> String:
	var who := tr("%s of %s") % [tr(str(rival_leader()["leader"])), tr(str(rival_name))]
	match str(rival_event.get("type", "")):
		"poach":
			var h := find_hero(str(rival_event["hero"]))
			var n := tr(str(h.name.split(" the ")[0])) if h else tr("a hero")
			return tr("%s has offered %s a place, and better pay. Match it, or let %s choose: a hero stays at morale %d or above (now %d).") % [who, n, n, GameData.POACH_STAY_MORALE, h.morale if h else 0]
		"challenge":
			if rival_event.get("accepted", false):
				return tr("You took the dare. Seal a Rank %s rift (or higher) before payday: +%d Renown and they lose %d. Miss it and they gain %d.") % [tr(str(rival_event["rank"])), GameData.CHALLENGE_WIN_RENOWN, GameData.CHALLENGE_WIN_TAKE, GameData.CHALLENGE_FAIL_RENOWN]
			return tr("%s says your guild can't seal a Rank %s rift before payday, and says it in every tavern.") % [who, tr(str(rival_event["rank"]))]
		"snatch":
			var q := _rival_quest()
			return tr("%s means to take the contract \"%s\" off the board. Take it on now, or let it go.") % [who, tr(str(quest_desc(q))) if not q.is_empty() else "?"]
	return ""


## The rival leader's own note with this move (GameData.RIVAL_VOICE), or "".
func rival_letter() -> String:
	var voice: Dictionary = GameData.RIVAL_VOICE.get(rival_name, {})
	var t := str(rival_event.get("type", ""))
	if not voice.has(t) or rival_event.get("accepted", false):
		return ""
	var note := tr(str(voice[t]))
	match t:
		"poach":
			var h := find_hero(str(rival_event["hero"]))
			note = note % tr(str(h.name.split(" the ")[0])) if h else ""
		"challenge":
			note = note % tr(str(rival_event["rank"]))
	var ps := str(rival_event.get("ps", ""))
	return note + ("\n\n" + tr(ps) if ps != "" and note != "" else "")


## The two answers: [[yes text, why it can't be done or ""], [no text, ""]],
## or [] once there's nothing left to choose (an accepted dare).
func rival_event_options() -> Array:
	match str(rival_event.get("type", "")):
		"poach":
			var h := find_hero(str(rival_event["hero"]))
			if h == null:
				return []
			var cost := poach_counter_cost(h)
			var stays := h.morale >= GameData.POACH_STAY_MORALE
			return [[tr("Counter-offer: %d Gold, +%d morale") % [cost, GameData.POACH_COUNTER_MORALE], tr("Not enough Gold.") if coins < cost else ""],
				[tr("Let them choose (they'd %s)") % (tr("stay") if stays else tr("leave")), ""]]
		"challenge":
			if rival_event.get("accepted", false):
				return []
			return [[tr("Accept: +%d Renown if you do it, they gain %d if not") % [GameData.CHALLENGE_WIN_RENOWN, GameData.CHALLENGE_FAIL_RENOWN], ""],
				[tr("Decline: they gain %d Renown") % GameData.CHALLENGE_DECLINE_RENOWN, ""]]
		"snatch":
			var q := _rival_quest()
			var full := active_quests().size() >= GameData.QUEST_ACTIVE_MAX
			return [[tr("Take it on now (due in %d days)") % int(GameData.QUEST_DUE_DAYS.get(int(q.get("diff", 1)), 6)), (tr("You already have %d contracts.") % GameData.QUEST_ACTIVE_MAX) if full else ""],
				[tr("Let them have it"), ""]]
	return []


## Answers the rival's move. Returns "" or why it can't be done.
func answer_rival(yes: bool) -> String:
	if rival_event.is_empty():
		return tr("Nothing to answer.")
	var rn := tr(str(rival_name))
	match str(rival_event["type"]):
		"poach":
			var h := find_hero(str(rival_event["hero"]))
			if h:
				if yes:
					var cost := poach_counter_cost(h)
					if coins < cost:
						return tr("Not enough Gold.")
					coins -= cost
					change_morale(h, GameData.POACH_COUNTER_MORALE)
					_news(tr("You matched %s's offer; %s stays.") % [rn, tr(str(h.name.split(" the ")[0]))])
				else:
					var in_rift: Array = run.get("hero_ids", []) if not run.is_empty() else []
					if h.morale >= GameData.POACH_STAY_MORALE or in_rift.has(h.id) or heroes.size() <= 1:
						_news(tr("%s turned down %s and stays with the guild.") % [tr(str(h.name.split(" the ")[0])), rn])
					else:
						_release(h)
						_news(tr("%s left to join %s.") % [tr(str(h.name.split(" the ")[0])), rn])
						pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("A hero left"), "text": tr("%s joined %s.") % [tr(str(h.name.split(" the ")[0])), rn]})
		"challenge":
			if yes:
				rival_event["accepted"] = true
				rival_event["seen"] = true
				_news(tr("You took %s's dare: a Rank %s rift by payday.") % [rn, tr(str(rival_event["rank"]))])
				save()
				state_changed.emit()
				return ""
			rival_renown += GameData.CHALLENGE_DECLINE_RENOWN
			_news(tr("You turned down %s's dare; they crow about it (+%d Renown to them).") % [rn, GameData.CHALLENGE_DECLINE_RENOWN])
		"snatch":
			var q := _rival_quest()
			if not q.is_empty():
				if yes:
					var err := accept_quest(str(q["id"]))
					if err != "":
						return err
				else:
					guild_board.erase(q)
					_news(tr("%s took the contract: %s.") % [rn, tr(str(quest_desc(q)))])
	rival_event = {}
	save()
	state_changed.emit()
	return ""


## A rift sealed at `rank_idx`: an accepted dare at that rank or below is won.
func _check_challenge(rank_idx: int) -> void:
	if str(rival_event.get("type", "")) != "challenge" or not rival_event.get("accepted", false) or rank_idx < GameData.rift_rank_index(str(rival_event["rank"])):
		return
	add_reputation(GameData.CHALLENGE_WIN_RENOWN)
	rival_renown = maxi(0, rival_renown - GameData.CHALLENGE_WIN_TAKE)
	_news(tr("Dare won: a Rank %s rift sealed. +%d Renown, and %s loses %d.") % [tr(str(rival_event["rank"])), GameData.CHALLENGE_WIN_RENOWN, tr(str(rival_name)), GameData.CHALLENGE_WIN_TAKE])
	pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("Dare won"), "text": tr("+%d Renown; %s loses %d.") % [GameData.CHALLENGE_WIN_RENOWN, tr(str(rival_name)), GameData.CHALLENGE_WIN_TAKE]})
	rival_event = {}


## Payday closes the rival's move: an unanswered one goes the "no" way, and
## an accepted dare not yet won is lost.
func _close_rival_event() -> void:
	if rival_event.is_empty():
		return
	if str(rival_event["type"]) == "challenge" and rival_event.get("accepted", false):
		rival_renown += GameData.CHALLENGE_FAIL_RENOWN
		_news(tr("Dare lost: no Rank %s rift by payday. %s gains %d Renown.") % [tr(str(rival_event["rank"])), tr(str(rival_name)), GameData.CHALLENGE_FAIL_RENOWN])
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("Dare lost"), "text": tr("%s gains %d Renown.") % [tr(str(rival_name)), GameData.CHALLENGE_FAIL_RENOWN]})
		rival_event = {}
		return
	_news(tr("%s — no answer by payday.") % rival_event_title())
	if answer_rival(false) != "":
		rival_event = {}


## The rival's leader: {leader, portrait (path), crest (path)}.
func rival_leader() -> Dictionary:
	var d: Dictionary = GameData.RIVAL_LEADERS.get(rival_name, {"leader": "Their captain", "portrait": "footman", "crest": 1})
	var art := str(GameData.RIVAL_ART.get(rival_name, ""))
	var portrait := art if art != "" and ResourceLoader.exists(art) else GameData.portrait_for_hero("", str(d["portrait"]))
	return {"leader": d["leader"], "portrait": portrait, "crest": GameData.CREST_PATH[int(d["crest"]) % GameData.CREST_PATH.size()]}


## This month's contest, Renown gained since it began: {ours, theirs, days_left}.
func contest_status() -> Dictionary:
	var ours := reputation - int(contest_start.get("ours", reputation))
	var theirs := rival_renown - int(contest_start.get("theirs", rival_renown))
	return {"ours": ours, "theirs": theirs, "days_left": GameData.CONTEST_DAYS - (day % GameData.CONTEST_DAYS)}


## The month is up: whoever gained more Renown takes the prize (a tie, nobody).
func _end_contest() -> void:
	var c := contest_status()
	var ours: int = c["ours"]
	var theirs: int = c["theirs"]
	var prize_c := int(round(int(GameData.CONTEST_PRIZE["coins"]) * year_mult("contest")))
	var prize_r := int(round(int(GameData.CONTEST_PRIZE["reputation"]) * year_mult("contest")))
	if ours > theirs:
		coins += prize_c
		add_reputation(prize_r)
		_news(tr("You won the month's contest, %d Renown to %d: +%d Gold, +%d Renown.") % [ours, theirs, prize_c, prize_r])
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("Contest won"), "text": tr("%d Renown gained to %s's %d. +%d Gold, +%d Renown.") % [ours, tr(str(rival_name)), theirs, prize_c, prize_r]})
	elif theirs > ours:
		rival_renown += prize_r
		_news(tr("%s won the month's contest, %d Renown to your %d.") % [tr(str(rival_name)), theirs, ours])
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("Contest lost"), "text": tr("%s gained %d Renown to your %d and takes the prize.") % [tr(str(rival_name)), theirs, ours]})
	else:
		_news(tr("The month's contest ends level at %d Renown each.") % ours)
	if ours > theirs:
		lore_event("contest", "won")   # the story web: Orla Venn's marching order
	_epilogue_month()
	contest_start = {"ours": reputation, "theirs": rival_renown}


## The Guild Standings, best Renown first: your guild, the rival, and three
## more guilds whose Renown, Tower floor and Endless time grow each day
## (deterministic, so they don't jump around between looks).
## [{name, renown, tower, endless, you}].
func guild_standings() -> Array:
	var rows: Array = [{"name": guild_name, "renown": reputation, "tower": tower_best, "endless": best_endless_time, "you": true},
		{"name": rival_name, "renown": rival_renown, "tower": mini(100, int(day * 0.55)), "endless": mini(1500, day * 11), "you": false}]
	var others: Array = GameData.RIVAL_NAMES.filter(func(n): return n != rival_name).slice(0, GameData.STANDING_STRENGTH.size())
	for k in others.size():
		var st: float = GameData.STANDING_STRENGTH[k]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["standings", others[k]])
		var pace := st * (0.8 + 0.4 * rng.randf())
		rows.append({"name": others[k], "renown": int(day * 0.9 * pace), "tower": mini(100, int(day * 0.5 * pace)), "endless": mini(1500, int(day * 10.0 * pace)), "you": false})
	rows.sort_custom(func(a, b): return int(a["renown"]) > int(b["renown"]) or (int(a["renown"]) == int(b["renown"]) and a["you"]))
	return rows

