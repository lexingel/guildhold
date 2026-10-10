extends "res://scripts/autoload/game_state/GameStateBreach.gd"
## GameState, part 7 (the autoload): starting special runs, Guild Orders, and loading/resetting a guild.
## The chain, bottom up: game_state/GameStateCore.gd (state, formulas, saving) -> Lore (the story web)
## -> Heroes -> Items -> Quests -> Modes -> Runs -> this file. Each part only calls
## down the chain; every var/const/signal lives in Core.


func reset() -> void:
	guild_name = ""
	guild_crest = 1
	next_id = 1
	coins = 100
	crystals = 15
	heroes = []
	relics = []
	items = []
	tonics = {}
	recruit_pool = []
	recruit_until = {}
	recruit_rerolls = 0
	party_presets = [[], [], []]
	upgrades = {}
	caps = {}
	champions = {}
	overseer = ""
	roll_champions()
	daily_attempt_day = -1
	daily_clears = 0
	daily_streak = 0
	daily_last_clear = -1
	run_history = []
	runs_finished = 0
	fallen = []
	heroes_lost_total = 0
	week_start_coins = -1
	hero_request = {}
	camp_event = {}
	camp_omen = {}
	camp_event_last = {}
	expedition_board = []
	expeditions = []
	founding_picks = 0
	founding_rerolls = 0
	next_resolve = 0
	hardship = 0
	breach = {}
	breach_next_day = -1
	damaged = {}
	wage_raise = {}
	pay_rate = {}
	contest_start = {}
	rival_event = {}
	session = {}
	boon_set4_reached = false
	tower_best = 0
	role_seals = {}
	flawless_bosses = 0
	riftbreak_best = -1
	subclass_known = []
	subclass_carried = []
	tower_week = 0
	tower_week_cleared = 0
	rifts_sealed = 0
	best_rift_rank_sealed = -1
	rival_name = str(GameData.RIVAL_NAMES[randi() % GameData.RIVAL_NAMES.size()])
	rival_renown = 0
	rival_ahead = 0
	feast_week = -1
	payday_report = {}
	guild_news = []
	triage_used_this_cycle = false
	pending_shop_boost = false
	guide_hidden = false
	last_party = []
	relics_found = []
	accord_pages = 0
	accord_ending = ""
	line_piece_seen = false
	skipped_act1 = false
	ledger_dry = 0
	act_since = 0
	crossings_answered = 0
	crossings_through = 0
	gates_held = 0
	sky_ending = ""
	book2_started = false
	branches = {}
	lore_dry = 0
	lore_found_here = []
	chosen_region = ""
	accord_hero = ""
	echoes_seen = []
	charter_choice = ""
	charter_result = ""
	morrow_defeated = false
	legacy_written = false
	founding = "free"
	oaths = []
	halls_restored = []
	hall_works = []
	wing_offer = []
	path_relic_chest = []
	tide_count = 0
	tides_held = 0
	tidewalls = 0
	descent_best = 0
	vale_year = {}
	board_claimed = []
	echoes_returned = 0
	run = {}
	monsters_seen = []
	bosses_defeated = []
	hazards_seen = []
	reputation = 0
	monster_kill_counts = {}
	crafts_performed = 0
	flawless_wins = 0
	feats_done = 0
	endowments = 0
	banner_colour = "crest"
	grudge = ""
	feat_tally = {}
	elites_won = 0
	bosses_won = 0
	guild_board = []
	day = 0
	runs_started = 0
	campaign_act = 1
	pending_stories = [GameData.PROLOGUE.duplicate(), _act_intro_card(1)]
	features_seen = []
	hints_seen = []
	last_export_day = -1
	tips_off = false
	tips_key_only = false
	tips_asked = false
	board_refresh_day = 0
	quest_tally = {}
	milestones_claimed = []
	bonds = {}


## Relics are rules only (0.66): a rolled relic becomes Essence (twice its
## salvage), the Essence spent on relic levels comes back, and a Path relic
## goes to the strongest hero of its Path (or the chest). Heroes load first.
func _convert_relics_066() -> void:
	var essence := 0
	var rolled := 0
	var keep: Array[Relic] = []
	for r in relics:
		for l in range(1, r.level):   # what its levels cost (15 x rarity mult x level, the old price)
			essence += int(round(15.0 * float(GameData.find_rarity(r.rarity)["mult"]) * l))
		if r.unique_id == "":
			essence += int(round(GameData.SALVAGE_CRYSTALS * float(GameData.find_rarity(r.rarity)["mult"]) * GameData.OLD_RELIC_ESSENCE_MULT))
			rolled += 1
		elif r.unique_id.begins_with("p_"):
			give_path_relic(r.unique_id)
		else:
			r.level = 1
			keep.append(r)
	relics.assign(keep)
	crystals += essence
	if rolled > 0 or essence > 0:
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("Relics have changed"),
			"text": tr("Relics bend rules now; stats live on gear. %d rolled relics and every relic level became %d Essence, and Path relics went to heroes of their Path.") % [rolled, essence]})


## Brings a save dict up to SAVE_VERSION, one step at a time. Version 1 is
## every save written before versioning existed; its missing fields are all
## handled by per-model defaults, so 1 -> 2 only stamps the version.
func _migrate_save(data: Dictionary) -> Dictionary:
	var v := int(data.get("save_version", 1))
	if v > SAVE_VERSION:
		push_warning("Save is from a newer version (%d > %d)" % [v, SAVE_VERSION])
	if v < 3:
		# Guild Management was rebuilt (9 nodes, perks instead of capstones):
		# refund every Crystal spent on the old tree.
		var refund := old_mgmt_refund(data.get("upgrades", {}), data.get("caps", {}))
		data["upgrades"] = {}
		data["caps"] = {}
		data["crystals"] = int(data.get("crystals", 0)) + refund
		if refund > 0:
			data["_mgmt_refund"] = refund
		v = 3
	if v < 4:
		# Paths (0.62): levels 1-10 per rank, points per rank, Path trees.
		# Heroes are converted after they load (migrate_hero_to_paths).
		data["_paths_migrate"] = true
		v = 4
	if v < 5:
		# The reveal schedule (0.65): what was open before stays open (after load).
		data["_reveal_migrate"] = true
		v = 5
	if v < 6:
		# Gear (0.66): rolled relics retired, relic levels gone, Path relics on heroes (after load).
		data["_relics66"] = true
		v = 6
	# if v < 7: ...next migration goes here, then v = 7
	data["save_version"] = max(v, SAVE_VERSION)
	return data


func load_save() -> bool:
	var parsed := _read_slot(active_slot)
	if parsed.is_empty():
		return false
	if restored_from_backup:
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("Save restored"),
			"text": tr("Your last save was damaged, so the one just before it was loaded.")})
	var data: Dictionary = _migrate_save(parsed)
	# A save file can exist on disk for a slot that was never actually
	# founded (e.g. a stray write while "Name Your Guild" was still open) —
	# slot_summary() already treats a blank guild_name as "empty" for slot
	# selection, so this has to agree: otherwise _switch_slot()'s "if not
	# load_save(): reset()" skips reset() for a slot that looks reusable,
	# and every field reset() seeds is left at its bare class default.
	if String(data.get("guild_name", "")) == "":
		return false
	guild_name = data.get("guild_name", "")
	guild_crest = data.get("guild_crest", 1)
	next_id = data.get("next_id", 1)
	coins = data.get("coins", 60)
	crystals = data.get("crystals", 15)
	Hero.attrs_migrated = 0
	heroes.assign(data.get("heroes", []).map(func(d): return Hero.from_dict(d)))
	if Hero.attrs_migrated > 0:
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("Heroes have attributes now"),
			"text": tr("Might, Agility and Focus — each hero has points from their past levels to spend (Roster > Hero).")})
	recruit_pool.assign(data.get("recruit_pool", []).map(func(d): return Hero.from_dict(d)))
	for h in heroes:
		migrate_hero_skill_keys(h)
	for h in recruit_pool:
		migrate_hero_skill_keys(h)
	if data.get("_paths_migrate", false):
		for h in heroes:
			migrate_hero_to_paths(h)
		recruit_pool.clear()   # the board refills with base-class recruits below
		data.erase("recruit_until")
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("Heroes have Paths now"),
			"text": tr("Every rank is levels 1-10 now; evolve at 10. Subclasses are trained at the Training Yard at Ranks D, B and S, and your heroes keep the ones they have. Skill points were refunded to spend again.")})
	recruit_until = (data.get("recruit_until", {}) as Dictionary).duplicate()
	recruit_rerolls = int(data.get("recruit_rerolls", 0))
	for h in recruit_pool:   # from before offers had a stay: spread their leaving
		if not recruit_until.has(h.id):
			recruit_until[h.id] = day + randi_range(int(GameData.RECRUIT_STAY[0]), int(GameData.RECRUIT_STAY[1]))
	party_presets = (data.get("party_presets", [[], [], []]) as Array).duplicate(true)
	while party_presets.size() < 3:
		party_presets.append([])
	if recruit_pool.is_empty() and guild_name != "" and not data.has("recruit_until"):
		# Saves from before recruit_pool was persisted (or an old save with no
		# key at all) would otherwise show an empty Hero Recruits screen until
		# the next rift seal — refresh_recruit_pool() always produces exactly
		# 4 offers, so a genuinely empty pool only ever means "missing data,"
		# never "no offers today."
		refresh_recruit_pool()
	path_relic_chest = (data.get("path_relic_chest", []) as Array).duplicate()   # before the relics: the 0.66 conversion adds to it
	relics.assign(data.get("relics", []).map(func(d): return Relic.from_dict(d)))
	if data.has("_relics66"):
		_convert_relics_066()
	items.assign(data.get("items", []).map(func(d): return Item.from_dict(d)))
	var tn = data.get("tonics", {})
	tonics = tn if tn is Dictionary else ({"healing": int(tn)} if int(tn) > 0 else {})
	monsters_seen.assign(data.get("monsters_seen", []))
	bosses_defeated.assign(data.get("bosses_defeated", []))
	hazards_seen.assign(data.get("hazards_seen", []))
	reputation = data.get("reputation", 0)
	monster_kill_counts = data.get("monster_kill_counts", {})
	crafts_performed = data.get("crafts_performed", 0)
	flawless_wins = data.get("flawless_wins", 0)
	feats_done = int(data.get("feats_done", 0))
	endowments = int(data.get("endowments", 0))
	banner_colour = str(data.get("banner_colour", "crest"))
	grudge = str(data.get("grudge", ""))
	elites_won = data.get("elites_won", 0)
	bosses_won = data.get("bosses_won", 0)
	guild_board.assign(data.get("guild_board", []))
	day = int(data.get("day", 0))
	board_refresh_day = int(data.get("board_refresh_day", 0))
	quest_tally = data.get("quest_tally", {})
	milestones_claimed.assign(data.get("milestones_claimed", []))
	bonds = data.get("bonds", {})
	upgrades = data.get("upgrades", {})
	caps = data.get("caps", {})
	if int(data.get("_mgmt_refund", 0)) > 0:
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("Guild Management rebuilt"),
			"text": tr("Upgrades are fewer and much stronger now. %d Essence spent on the old tree were refunded.") % int(data["_mgmt_refund"])})
	champions = data.get("champions", {})
	overseer = str(data.get("overseer", ""))
	crystals += int(data.get("echoes", 0))   # Echoes (older saves) are Essence now
	if data.has("champion_roll"):
		champion_roll.assign(data["champion_roll"])
	else:
		roll_champions()
	tower_best = int(data.get("tower_best", 0))
	role_seals = (data.get("role_seals", {}) as Dictionary).duplicate()
	flawless_bosses = int(data.get("flawless_bosses", 0))
	riftbreak_best = int(data.get("riftbreak_best", -1))
	subclass_known = (data.get("subclass_known", []) as Array).duplicate()
	subclass_carried = (data.get("subclass_carried", []) as Array).duplicate()
	daily_attempt_day = int(data.get("daily_attempt_day", -1))
	daily_clears = int(data.get("daily_clears", 0))
	daily_streak = int(data.get("daily_streak", 0))
	daily_last_clear = int(data.get("daily_last_clear", -1))
	run_history = data.get("run_history", [])
	runs_finished = int(data.get("runs_finished", 0))
	fallen = data.get("fallen", [])
	heroes_lost_total = int(data.get("heroes_lost_total", 0))
	week_start_coins = int(data.get("week_start_coins", -1))
	hero_request = (data.get("hero_request", {}) as Dictionary).duplicate(true)
	camp_event = (data.get("camp_event", {}) as Dictionary).duplicate(true)
	camp_omen = (data.get("camp_omen", {}) as Dictionary).duplicate(true)
	camp_event_last = (data.get("camp_event_last", {}) as Dictionary).duplicate(true)
	expedition_board = (data.get("expedition_board", []) as Array).duplicate(true)
	founding_picks = int(data.get("founding_picks", 0))
	founding_rerolls = int(data.get("founding_rerolls", 0))
	expeditions = (data.get("expeditions", []) as Array).duplicate(true)
	next_resolve = int(data.get("next_resolve", 0))
	hardship = int(data.get("hardship", 0))
	breach = (data.get("breach", {}) as Dictionary).duplicate(true)
	breach_next_day = int(data.get("breach_next_day", -1))
	damaged = (data.get("damaged", {}) as Dictionary).duplicate()
	wage_raise = (data.get("wage_raise", {}) as Dictionary).duplicate()
	pay_rate = (data.get("pay_rate", {}) as Dictionary).duplicate()
	contest_start = (data.get("contest_start", {}) as Dictionary).duplicate()
	rival_event = (data.get("rival_event", {}) as Dictionary).duplicate(true)
	session = (data.get("session", {}) as Dictionary).duplicate()
	session["n"] = int(session.get("n", 0)) + 1   # times this guild was opened (0.65, for the feedback report)
	boon_set4_reached = bool(data.get("boon_set4_reached", false))
	tower_week = int(data.get("tower_week", 0))
	tower_week_cleared = int(data.get("tower_week_cleared", 0))
	rifts_sealed = data.get("rifts_sealed", 0)
	best_rift_rank_sealed = int(data.get("best_rift_rank_sealed", -1))
	rival_name = str(data.get("rival_name", GameData.RIVAL_NAMES[0]))
	rival_renown = int(data.get("rival_renown", 0))
	rival_ahead = int(data.get("rival_ahead", 0))
	feast_week = int(data.get("feast_week", -1))
	payday_report = data.get("payday_report", {})
	guild_news = data.get("guild_news", [])
	runs_started = int(data.get("runs_started", 0 if rifts_sealed == 0 and monsters_seen.is_empty() else 1))
	pending_stories = (data.get("pending_stories", []) as Array).duplicate(true)   # cards still to read (0.65: they were lost on a reload)
	if data.has("campaign_act"):
		campaign_act = int(data["campaign_act"])
	else:
		# A guild from before the campaign keeps what it had unlocked.
		campaign_act = 3 if int(data.get("best_endless_cycle", 0)) > 0 else (2 if rifts_sealed >= 3 else 1)
	# Champions: the acts already behind this guild have freed theirs.
	for act in range(1, mini(campaign_act, GameData.CHAMPION_STORY_ACTS + 1)):
		unlock_champion(story_champion(act))
	if not data.has("champion_roll"):
		# Champions used to be hired for Gold: the ones hired stay on as heroes.
		var kept := 0
		for h in heroes:
			if h.is_champion:
				h.is_champion = false
				kept += 1
		if not champions.is_empty() or kept > 0:
			pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("Champions have changed"),
				"text": tr("Champions are no longer hired: they're freed by the story and rescued in the Endless Rift, and oversee your rift runs. Champions you hired stay on as heroes.")})
	hints_seen = data.get("hints_seen", [])
	last_export_day = int(data.get("last_export_day", -1))
	tips_off = bool(data.get("tips_off", false))
	tips_key_only = bool(data.get("tips_key_only", false))
	tips_asked = bool(data.get("tips_asked", true))   # saves from before the question don't ask it
	if data.has("features_seen"):
		features_seen = data["features_seen"]
	else:
		# A guild from before staged unlocks: everything it already has is old news.
		features_seen = GameData.FEATURE_UNLOCKS.keys().filter(func(f): return feature_unlocked(f))
	if data.has("_reveal_migrate"):
		# 0.65 hid things that were open from day 1, and opened the hall's rooms in stages.
		var had: Array = ["forge", "training", "requests", "relics"]
		if features_seen.has("management"):
			had.append_array(["hall_rooms", "hall_research", "wardcraft"])
		if rifts_sealed >= 3:
			had.append("resolve")
		for f in had:
			if not features_seen.has(f):
				features_seen.append(f)
	triage_used_this_cycle = data.get("triage_used_this_cycle", false)
	pending_shop_boost = data.get("pending_shop_boost", false)
	guide_hidden = data.get("guide_hidden", false)
	last_party.assign(data.get("last_party", []))
	relics_found = data.get("relics_found", [])
	accord_pages = int(data.get("accord_pages", 0))
	accord_ending = str(data.get("accord_ending", ""))
	line_piece_seen = bool(data.get("line_piece_seen", false))
	skipped_act1 = bool(data.get("skipped_act1", false))
	ledger_dry = int(data.get("ledger_dry", 0))
	act_since = int(data.get("act_since", 0))
	crossings_answered = int(data.get("crossings_answered", 0))
	crossings_through = int(data.get("crossings_through", 0))
	gates_held = int(data.get("gates_held", 0))
	sky_ending = str(data.get("sky_ending", ""))
	book2_started = bool(data.get("book2_started", false))
	branches = data.get("branches", {})
	lore_dry = int(data.get("lore_dry", 0))
	lore_found_here = data.get("lore_found_here", [])
	chosen_region = str(data.get("chosen_region", ""))
	if accord_ending != "" and not book2_started:   # a guild that ended the Accord before Book II existed
		book2_started = true
		pending_stories.append(_sky_beneath_card())
		pending_stories.append(_act_intro_card(5))
	accord_hero = str(data.get("accord_hero", ""))
	echoes_seen = data.get("echoes_seen", [])
	charter_choice = str(data.get("charter_choice", ""))
	charter_result = str(data.get("charter_result", ""))
	morrow_defeated = bool(data.get("morrow_defeated", false))
	legacy_written = bool(data.get("legacy_written", false))
	founding = str(data.get("founding", "free"))
	oaths = (data.get("oaths", []) as Array).duplicate()
	halls_restored = (data.get("halls_restored", []) as Array).duplicate()
	hall_works = (data.get("hall_works", []) as Array).duplicate()
	wing_offer = (data.get("wing_offer", []) as Array).duplicate()
	tide_count = int(data.get("tide_count", 0))
	tides_held = int(data.get("tides_held", 0))
	tidewalls = int(data.get("tidewalls", 0))
	descent_best = int(data.get("descent_best", 0))
	vale_year = (data.get("vale_year", {}) as Dictionary).duplicate(true)
	board_claimed = (data.get("board_claimed", []) as Array).duplicate()
	echoes_returned = int(data.get("echoes_returned", 0))
	check_wing_offer()   # a guild past the end of Act I, III or V with a wing due
	# Guilds that finished the campaign before Act IV existed start it now.
	if campaign_act == 4 and not hints_seen.has("act4_intro"):
		hints_seen.append("act4_intro")
		pending_stories.append(_act_intro_card(4))

	var run_data: Dictionary = data.get("run", {})
	if run_data.get("endless", false):
		# A run of the old, floor-by-floor Endless Rift: it's a survival mode
		# now, so the run ends here (heroes keep their HP and loot).
		run_data = {}
		pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("The Endless Rift has changed"),
			"text": tr("Your Endless run was closed: it's a real-time survival run now (Rift Hall).")})
	if run_data.is_empty():
		run = {}
	else:
		# JSON round-trips Dictionary keys as strings, but `chosen` is keyed
		# by int rift position everywhere it's read (current_node_kind() etc).
		var chosen_raw: Dictionary = run_data.get("chosen", {})
		var chosen_fixed: Dictionary = {}
		for k in chosen_raw:
			chosen_fixed[int(k)] = chosen_raw[k]
		run = {
			"diff_id": run_data.get("diff_id", ""),
			"layers": run_data.get("layers", []), "pos": run_data.get("pos", 0),
			"chosen": chosen_fixed, "hero_ids": run_data.get("hero_ids", []),
			"shield": run_data.get("shield", 0), "boss_rounds": run_data.get("boss_rounds", 0),
			"node_kind": run_data.get("node_kind", ""), "node_state": _unpack(run_data.get("node_state", {})), "seed": int(run_data.get("seed", randi())),
			"sealed": run_data.get("sealed"), "anchor_used": run_data.get("anchor_used", false),
			"start_coins": run_data.get("start_coins", coins), "start_crystals": run_data.get("start_crystals", crystals),
			"heroes_lost": run_data.get("heroes_lost", 0), "start_snap": run_data.get("start_snap", {}),
			"rift_rank": run_data.get("rift_rank", ""), "champion_call_used": bool(run_data.get("champion_call_used", false)),
			"injured": run_data.get("injured", []), "left_behind": run_data.get("left_behind", []), "heal_used": bool(run_data.get("heal_used", false)),
			"any_ko": bool(run_data.get("any_ko", false)),
			"champion_calls": int(run_data.get("champion_calls", 1 if run_data.get("champion_call_used", false) else 0)), "overseer": str(run_data.get("overseer", "")), "phoenix_used": bool(run_data.get("phoenix_used", false)),
			"finale": int(run_data.get("finale", 0)), "momentum_bonus": int(run_data.get("momentum_bonus", 0)), "training": bool(run_data.get("training", false)), "biome": str(run_data.get("biome", "vale")),
			"orders_used": int(run_data.get("orders_used", 0)), "boons": run_data.get("boons", []), "events_seen": run_data.get("events_seen", []),
		}
		if run_data.get("haul_lost") is Array:   # the haul already dropped once (0.56)
			run["haul_lost"] = run_data["haul_lost"]
		if int(run_data.get("daily", -1)) >= 0:
			run["daily"] = int(run_data["daily"])
		if run_data.has("tower"):
			run["tower"] = int(run_data["tower"])
			run["tower_snap"] = run_data.get("tower_snap", {})
		if run_data.has("descent"):
			run["descent"] = int(run_data["descent"])
		if run_data.has("resolve"):
			run["resolve"] = int(run_data["resolve"])
		if run_data.get("free_rally_used", false):
			run["free_rally_used"] = true
		var pre: Dictionary = (run["node_state"] as Dictionary).get("pre_hp", {})
		if not pre.is_empty() and not (run["node_state"] as Dictionary).has("result"):
			# Reloaded mid-fight: the fight starts over from where the party stood.
			for id in pre:
				var ph := find_hero(str(id))
				if ph:
					ph.hp = int(pre[id][0])
					ph.down_runs = int(pre[id][1])
		for key in ["morrow", "breach"]:
			if run_data.has(key):
				run[key] = bool(run_data[key])
		var at_fixed := {}
		for k in (run_data.get("at", {}) as Dictionary):   # JSON keys come back as strings
			at_fixed[int(k)] = int(run_data["at"][k])
		run["at"] = at_fixed
	return true


## Starts the current act's finale rift: its tier's rift, tougher by the act's
## mult, ending in the act's named foe.
func start_finale(hero_ids: Array[String], starting_relic: Relic) -> void:
	if not finale_ready():
		return
	var act := current_act()
	start_run(str(act["tier"]), hero_ids, starting_relic)
	run["finale"] = int(act["act"])
	run["training"] = false
	run["biome"] = str(GameData.ACT_BIOME[int(act["act"])])
	run["layers"] = Combat.build_layers(_diff())
	save()


## A ladder rift with today's twist: the day's rule and starting boon, and
## the same layout for every guild at that rank today.
func start_daily(rank_id: String, hero_ids: Array[String], starting_relic: Relic) -> void:
	if not daily_available():
		start_ladder_rift(rank_id, hero_ids, starting_relic)
		return
	var info := daily_info()
	start_ladder_rift(rank_id, hero_ids, starting_relic)
	run["daily"] = int(info["day"])
	run["training"] = false
	run["seed"] = hash([int(info["seed"]), rank_id])
	run["biome"] = str(info["biome"])
	run["boons"] = [info["boon"]]
	seed(int(run["seed"]))
	run["layers"] = Combat.build_layers(_diff())
	randomize()
	run["pos"] = 0
	run["chosen"] = {}
	auto_resolve_single_option()
	daily_attempt_day = int(info["day"])
	save()
	state_changed.emit()


# ---------------- Guild Orders ----------------

## Orders whose node is at GameData.ORDER_UNLOCK_LEVEL or above.
func orders_unlocked() -> Array:
	return GameData.GUILD_ORDERS.keys().filter(func(id): return lvl(str(GameData.GUILD_ORDERS[id]["node"])) >= GameData.ORDER_UNLOCK_LEVEL)


## Orders per rift: 1 once any is unlocked, +1 at Renowned and Legendary tier.
func orders_per_rift() -> int:
	if orders_unlocked().is_empty():
		return 0
	var total := int(Combat.guild_tier_info()["total"])
	return 1 + (1 if total >= 25 else 0) + (1 if total >= 40 else 0)


func orders_left() -> int:
	return maxi(0, orders_per_rift() - int(run.get("orders_used", 0)))


## Whether the run has any Guild Order to show (one unlocked, or the War Room's Rally).
func has_orders() -> bool:
	return orders_per_rift() > 0 or free_rally()


## The War Room's free Rally, once a rift (it needs no Drill Yard and no order).
func free_rally() -> bool:
	return has_wing("war_room") and not run.is_empty() and not run.get("free_rally_used", false) and not run.has("tower")


## "" if `id` can be used right now, else why not.
func order_blocker(id: String) -> String:
	if run.is_empty():
		return tr("Only inside a rift")
	if run.has("tower"):
		return tr("The Tower is a trial: no orders")
	var free := id == "rally" and free_rally()
	if not orders_unlocked().has(id) and not free:
		return tr("Not unlocked")
	if orders_left() <= 0 and not free:
		return tr("No orders left this rift")
	var ns: Dictionary = run.get("node_state", {})
	var in_fight: bool = ns.has("combat_state") and not ns.has("result")
	match id:
		"supply":
			if in_fight:
				return tr("Not during a fight")
			if not current_party().any(func(h): return h.hp > 0 and h.hp < Combat.max_hp(h)):
				return tr("Everyone is at full HP")
		"rally":
			if not in_fight:
				return tr("Only during a fight")
		"requisition":
			var res: Dictionary = ns.get("result", {})
			if not bool(res.get("won", false)) or (res.get("reward_options", []) as Array).is_empty() or ns.get("reward_chosen", false):
				return tr("Only when choosing a fight's loot")
		"scout":
			if current_node_kind() != "" or current_layer_options().size() < 2:
				return tr("Only when choosing a path")
	return ""


func use_order(id: String) -> String:
	var why := order_blocker(id)
	if why != "":
		return why
	var ns: Dictionary = run.get("node_state", {})
	match id:
		"supply":
			for h in current_party():
				if h.hp > 0:
					h.hp = mini(Combat.max_hp(h), h.hp + int(ceil(Combat.max_hp(h) * 0.35)))
		"rally":
			Combat.apply_rally(ns["combat_state"])
		"requisition":
			var res: Dictionary = ns["result"]
			var opts: Array = []
			for i in (res["reward_options"] as Array).size():
				opts.append(Combat.gen_loot(Combat.weighted_rarity()))
			res["reward_options"] = opts
		"scout":
			var layer: Dictionary = run["layers"][int(run["pos"])]
			var old: Array = layer["options"]
			var pool: Array = Combat.FORK_POOL.filter(func(k): return not old.has(k))
			pool.shuffle()
			var a: String = pool[0]
			var rest: Array = pool.filter(func(k): return k != a)
			layer["options"] = [a, rest[0]]
	if id == "rally" and free_rally():
		run["free_rally_used"] = true
	else:
		run["orders_used"] = int(run.get("orders_used", 0)) + 1
	save()
	state_changed.emit()
	return ""


## One fight on the next floor. Heroes fight at full HP with abilities ready;
## _end_tower puts them back exactly as they were (no downing, no time passing).
func start_tower(hero_ids: Array[String]) -> void:
	var f := tower_next_floor()
	if f <= 0 or not feature_unlocked("tower"):
		return
	var info := tower_floor_info(f)
	var ids: Array[String] = []
	ids.assign(hero_ids.slice(0, int(info["party_cap"])))
	last_party = ids.duplicate()
	var shield := 0
	run = {
		"diff_id": "tower",
		"layers": [{"options": [info["kind"]]}], "pos": 0, "chosen": {},
		"hero_ids": ids, "shield": shield, "boss_rounds": 0,
		"node_kind": "", "node_state": {}, "sealed": null, "anchor_used": false,
		"start_coins": coins, "start_crystals": crystals, "heroes_lost": 0,
		"rift_rank": "", "seed": int(info["seed"]), "biome": str(info["biome"]), "tower": f,
	}
	var snap := {}
	for h in current_party():
		snap[h.id] = [h.hp, h.down_runs, h.bedded]
	run["tower_snap"] = snap
	auto_resolve_single_option()
	save()
	state_changed.emit()


## Time in the game for the Feedback report (session["secs"]): counted while
## a guild is being played (Main.render sets session_live; not on the title
## or naming screens), and never across a pause longer than a second.
var session_live := false


func _process(delta: float) -> void:
	if session_live and guild_name != "" and delta < 1.0:
		session["secs"] = float(session.get("secs", 0.0)) + delta


## Retires this guild: its legacy is written and its save slot freed (the
## Hall of Guilds keeps its record). Returns the Laurels earned.
func retire_guild(hero_ids: Array) -> int:
	if not can_retire():
		return 0
	var earned := write_legacy(hero_ids, true)
	delete_slot(active_slot)
	reset()
	return earned
