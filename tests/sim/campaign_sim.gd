extends Node
## Whole-campaign sim: plays new guilds day by day through the real GameState
## calls the UI makes (one rift or rest a day, Quick fight in every fight,
## matters answered, Riftbreaks defended) and reports pacing, the Gold
## economy and fight win rates. Never touches the player's saves (slot 9).
##   godot --headless --path . res://tests/sim/campaign_sim.tscn
##   ... -- investor | casual     only that profile
##   ... -- days=60 seeds=4       length and sample size
##   ... -- bold                  always enter the highest open rank (no
##                                stepping down when it reads Deadly)
##   ... -- hp=1.2 dmg=1.2        try a RANK_THREAT without editing the data
##   ... -- attr=agility          every attribute point into one attribute
##   ... -- hand                  fight like a careful player (see _hand_action)
##                                instead of Quick fight
##   ... -- advice               casual guilds follow the Act panel's power advice when stuck
##   ... -- chain                one player's guilds in a row: the legacy carries, endings
##                                cycle renew/break/rewrite (the story web's pacing)
##   ... -- charter=expose|quiet  the Charter War's turn (default: never
##                                answered, as before 0.32.0); echoes are
##                                given back or kept 50/50, the Accord renewed
## The Endless Rift: when the act still asks for a freed champion (Act IV),
## every other day goes to an Endless run with the guild's champions on
## autopilot, finished through GameState.finish_survivors like a player's.
## Profiles: "investor" spends like a player who reads the tooltips (quests,
## skills, upgrades, training, recruits, champion levels); "casual" takes
## quests, spends skill and attribute points, equips gear and hires up to 6,
## but never buys an upgrade, training or a champion level.

const TARGETS := """Targets: wages+upkeep 35-50%% of Gold income (weeks 2-6) · Act I done day 4-7 · Act II day 18-28 · investor clears 65-80%% of runs at its top rank"""

var days := 60
var seeds := 4
var seed0 := 7000   # the first seed (seed0=7100 for a second batch)
var profile := ""
var log_days := false
var chain := false         # chain: one player's guilds in a row, sharing a legacy (the story web)
var advice := false        # advice: the casual player takes the Act panel's advice when a finale is out of reach
var chain_guild := 0
var bold := false
var hand := false
var force_attr := ""
var charter := ""        # the sim's answer to Mother Ilse's page ("" = leave it)
var founding := "free"   # the founding charter (founding=mercenary, ...)
var oaths: Array = []    # oaths sworn (oaths=by_hand,lean_purse)
var ending := "renew"    # the Accord's ending (ending=break: the Open Hollow's tides)
var gifts: Array = []    # founding gifts (gifts=veteran,contacts), Laurels free
var endless_mode := "descent"   # how the sim frees champions: descent (turn-based) or survivors
var year := ""           # "The Vale this year": year=dry,restless or year=random
var spire := ""          # the Spire's fall: spire=archive or spire=hollin ("" = either, at random)
var hand_bonus := 0      # fights that paid the flawless-by-hand bonus
var train_count := 0     # subclass trainings started (0.62)
var mastery_ranks := 0   # Path Mastery ranks bought (0.65)
var curve := {}          # power/recommended bucket -> [sealed, lost], ladder runs only
# Per guild:
var gross_gold := {}     # week -> Gold earned (runs, quests, defenses)
var bill_paid := {}      # week -> wages + upkeep paid
var fights := {}         # rank -> [won, lost]
var left_with_haul := 0
var sustain := [0.0, 0.0, 0.0, 0, 0.0, 0.0, 0.0]   # mend/round sum, start hp sum, end hp sum, won fights
var hard_level := 0   # hard=N: found at Hardship N (-1 Story), 0.64
var take_path_relics := true   # relics=0: always take the Essence
var path_relics_taken := 0
var expeditions_on := false   # exped=1: bench heroes go on expeditions (2026-10-09)
var _exp_sent := {}           # str(hero ids) -> {gold, ess, bon, days, n, tier}
## Expedition and rift pay, per profile: [sent, success, partial, failure, gold, essence, hero-days,
## wounds, scars, rift run days, rift hero-days, rift gold, rift essence]
var exp_stats := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var _run_party := 0           # heroes in today's rift run (0: no run today)
var _run_ess := 0             # Essence the run brought in
var _exp_paid_today := [0, 0] # expedition Gold, Essence that came home today
var short_runs := [0, 0, 0]    # runs with under 4 heroes, of them with an expedition out, runs stepped down a rank
var resolve_doors := [0, 0, 0, 0, 0]   # boss doors with Resolve on: [doors, wavering, broken, won from wavering/broken, sum of Resolve]
var lost_high := [0, 0]   # lost fights / of them from above 90% party HP
var by_kind := {}        # fight kind -> [won, lost, start hp % sum of lost, of won] (all guilds)
## Fight stakes (0.68), per tier ("C-A" wounds per fight, "S+" per run): [ordinary won, ordinary lost,
## boss doors, boss-door HP share sum, wounds, wounds avoided, falls, fall scars, drops, deaths, fights]
var stakes := {}
var runs := {}           # rank -> [sealed, lost]
var rounds := {}         # rank -> [fights, total rounds, fights over in round 1]
var act_day := {}        # act finished -> day
var act_runs := {}       # act -> [sealed, lost, rest days, defense days]
var notes: Array[String] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("days="):
			days = int(a.substr(5))
		elif a.begins_with("seed0="):
			seed0 = int(a.substr(6))
		elif a.begins_with("seeds="):
			seeds = int(a.substr(6))
		elif a in ["investor", "casual"]:
			profile = a
		elif a.begins_with("hp="):
			GameData.RANK_THREAT_HP = float(a.substr(3))
		elif a.begins_with("dmg="):
			GameData.RANK_THREAT_DMG = float(a.substr(4))
		elif a.begins_with("threat="):   # threat=combat:1.3:1.5,boss:0.9:0.9
			for part in a.substr(7).split(","):
				var bits := part.split(":")
				GameData.FIGHT_THREAT[bits[0]] = [float(bits[1]), float(bits[2])]
		elif a.begins_with("haul="):   # haul=0 turns the haul loss off
			GameData.HAUL_LOSS = {"fell": float(a.substr(5)), "fled": float(a.substr(5)) * 0.5}
		elif a.begins_with("resolve="):   # resolve=0 turns the drain off; resolve=2 doubles it (0.64)
			for k in GameData.RESOLVE_DRAIN:
				GameData.RESOLVE_DRAIN[k] = int(round(float(GameData.RESOLVE_DRAIN[k]) * float(a.substr(8))))
		elif a.begins_with("hard="):
			hard_level = int(a.substr(5))
		elif a == "relics=0":
			take_path_relics = false
		elif a == "exped=1":
			expeditions_on = true
		elif a.begins_with("set="):   # set=NAME:VALUE, a GameData knob (0.68 sweeps)
			var kv := a.substr(4).split(":")
			GameData.set(kv[0], int(kv[1]) if not kv[1].contains(".") else float(kv[1]))
		elif a == "stakes=0":   # the rules before fight stakes (0.68), for a baseline
			GameData.STAKES_ON = false
		elif a.begins_with("rstart="):
			GameData.RESOLVE_START = int(a.substr(7))
		elif a.begins_with("waver="):
			GameData.RESOLVE_WAVER = int(a.substr(6))
		elif a.begins_with("camp="):   # camp event chance (0.63): camp=0 turns them off
			GameData.CAMP_EVENT_CHANCE = float(a.substr(5))
		elif a.begins_with("mendcap="):
			GameData.MEND_CAP = float(a.substr(8))
		elif a.begins_with("mend="):
			GameData.POST_FIGHT_MEND = float(a.substr(5))
		elif a.begins_with("attr="):
			force_attr = a.substr(5)
		elif a.begins_with("tide_growth="):
			GameData.TIDE_GROWTH = float(a.substr(12))
		elif a.begins_with("year="):
			year = a.substr(5)
		elif a.begins_with("endless="):
			endless_mode = a.substr(8)
		elif a.begins_with("gifts="):
			gifts = Array(a.substr(6).split(","))
		elif a.begins_with("ending="):
			ending = a.substr(7)
		elif a.begins_with("oaths="):
			oaths = Array(a.substr(6).split(","))
		elif a.begins_with("founding="):
			founding = a.substr(9)
		elif a.begins_with("spire="):
			spire = a.substr(6)
		elif a.begins_with("charter="):
			charter = a.substr(8)
		elif a == "hand":
			hand = true
		elif a == "bold":
			bold = true
		elif a == "log":
			log_days = true
		elif a == "chain":
			chain = true
		elif a == "advice":
			advice = true
		elif a.begins_with("feat_bonus="):
			GameData.FEAT_BONUS = float(a.get_slice("=", 1))
	# The legacy file is shared by every guild on this machine: keep the
	# player's, and give each simulated guild an empty one.
	# A copy waits on disk too, in case a run is stopped before the end.
	var bak := GameState.LEGACY_PATH + ".simbak"
	if FileAccess.file_exists(bak):   # the last run was stopped: put the player's back first
		var old := FileAccess.get_file_as_bytes(bak)
		if old.is_empty():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.LEGACY_PATH))
		else:
			FileAccess.open(GameState.LEGACY_PATH, FileAccess.WRITE).store_buffer(old)
	var keep_legacy := FileAccess.get_file_as_bytes(GameState.LEGACY_PATH) if FileAccess.file_exists(GameState.LEGACY_PATH) else PackedByteArray()
	FileAccess.open(bak, FileAccess.WRITE).store_buffer(keep_legacy)
	print(TARGETS % [])
	print("Rank threat: hp x%.2f, dmg x%.2f, mend %.2f, mend cap %.2f, fights %s, haul %s" % [GameData.RANK_THREAT_HP, GameData.RANK_THREAT_DMG, GameData.POST_FIGHT_MEND, GameData.MEND_CAP, str(GameData.FIGHT_THREAT), str(GameData.HAUL_LOSS)])
	for p in (["investor", "casual"] if profile == "" else [profile]):
		var all_fights := {}
		var all_runs := {}
		var all_rounds := {}
		var ratios: Array = []
		var acts := {2: [], 3: [], 4: [], 5: [], 6: [], 7: []}
		for s in seeds:
			_guild(p, seed0 + s)
			for r in fights:
				var t: Array = all_fights.get(r, [0, 0])
				all_fights[r] = [t[0] + fights[r][0], t[1] + fights[r][1]]
			for r in rounds:
				var t2: Array = all_rounds.get(r, [0, 0, 0])
				all_rounds[r] = [t2[0] + rounds[r][0], t2[1] + rounds[r][1], t2[2] + rounds[r][2]]
			for r in runs:
				var t: Array = all_runs.get(r, [0, 0])
				all_runs[r] = [t[0] + runs[r][0], t[1] + runs[r][1]]
			for w in range(2, 7):
				if float(gross_gold.get(w, 0)) > 0:
					ratios.append(float(bill_paid.get(w, 0)) / float(gross_gold[w]))
			for a in acts:
				acts[a].append(int(act_day.get(a, -1)))
		print("== %s%s%s%s%s%s, %d guilds x %d days" % [p, " (bold)" if bold else "", " (by hand)" if hand else " (Quick fight)", (" all points in " + force_attr) if force_attr != "" else "", (" charter=" + charter) if charter != "" else "", (" founding=" + founding) if founding != "free" else "", seeds, days])
		print("   Act I done on days %s · Act II %s · Act III %s · Act IV %s · Act V %s · Act VI %s   (-1 = not reached)" % [acts[2], acts[3], acts[4], acts[5], acts[6], acts[7]])
		ratios.sort()
		if not ratios.is_empty():
			print("   wages+upkeep / Gold income, weeks 2-6: median %d%% (min %d%%, max %d%%)" % [int(ratios[ratios.size() / 2] * 100), int(ratios[0] * 100), int(ratios[-1] * 100)])
		var ranks := all_fights.keys()
		ranks.sort_custom(func(a, b): return GameData.rift_rank_index(str(a)) < GameData.rift_rank_index(str(b)))
		print("   fights won: %s" % "  ".join(ranks.map(func(r): return "%s %d/%d" % [r, all_fights[r][0], all_fights[r][0] + all_fights[r][1]])))
		if hand:
			print("   flawless-by-hand bonus paid in %d fights" % hand_bonus)
		print("   fight length (avg rounds, %% over in round 1): %s" % "  ".join(ranks.filter(func(r): return all_rounds.has(r)).map(func(r): return "%s %.1f/%d%%" % [r, float(all_rounds[r][1]) / maxf(1.0, all_rounds[r][0]), int(100.0 * all_rounds[r][2] / maxf(1.0, all_rounds[r][0]))])))
		print("   by fight kind (won/all, party HP at the start: lost vs won): %s" % "  ".join(by_kind.keys().map(func(k): return "%s %d/%d (%d%% vs %d%%)" % [k, by_kind[k][0], by_kind[k][0] + by_kind[k][1], int(100.0 * by_kind[k][2] / maxf(1.0, by_kind[k][1])), int(100.0 * by_kind[k][3] / maxf(1.0, by_kind[k][0]))])))
		by_kind = {}
		for tier in stakes:
			var sk: Array = stakes[tier]
			print("   stakes %s: ordinary fights won %d/%d (%.1f%%) · boss door HP %d%% (%d doors) · %d wounds, %d avoided · %d falls in %d fights: %d scars, %d drops, %d deaths" % [tier, sk[0], sk[0] + sk[1], 100.0 * sk[0] / maxf(1, sk[0] + sk[1]), int(100.0 * sk[3] / maxf(1, sk[2])), sk[2], sk[4], sk[5], sk[6], sk[10], sk[7], sk[8], sk[9]])
		stakes = {}
		print("   Resolve at boss doors: %d doors, avg %.1f left, wavering %d, broken %d (won %d of those) · lost fights %d, %d from above 90%% HP" % [resolve_doors[0], float(resolve_doors[4]) / maxf(1, resolve_doors[0]), resolve_doors[1], resolve_doors[2], resolve_doors[3], lost_high[0], lost_high[1]])
		resolve_doors = [0, 0, 0, 0, 0]
		print("   Path relics taken: %d" % path_relics_taken)
		path_relics_taken = 0
		var es := exp_stats
		print("   expeditions: %d sent (%d success, %d partial, %d failed), %d Gold %d Essence over %d hero-days = %.0f Gold %.1f Essence a hero-day · about %d heroes hurt, %d parties came back with a scar" % [es[0], es[1], es[2], es[3], es[4], es[5], es[6], es[4] / maxf(1, es[6]), es[5] / maxf(1, es[6]), es[7], es[8]])
		print("   rifts: %d run days, %d hero-days = %.0f Gold %.1f Essence a hero-day (gross, before wages)" % [es[9], es[10], es[11] / maxf(1, es[10]), es[12] / maxf(1, es[10])])
		print("   short parties: %d runs with under 4 heroes (%d of them with an expedition out) · %d runs stepped below the top open rank" % short_runs)
		short_runs = [0, 0, 0]
		exp_stats = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
		lost_high = [0, 0]
		print("   left a run early to keep the haul: %d times" % left_with_haul)
		print("   won fights: party mend %.1f%%/round, dodge %d%%, wipe guard %d%%, %.1f rounds, party HP %d%% before, %d%% after" % [100.0 * sustain[0] / maxf(1, sustain[3]), int(100.0 * sustain[4] / maxf(1, sustain[3])), int(100.0 * sustain[5] / maxf(1, sustain[3])), sustain[6] / maxf(1, sustain[3]), int(100.0 * sustain[1] / maxf(1, sustain[3])), int(100.0 * sustain[2] / maxf(1, sustain[3]))])
		sustain = [0.0, 0.0, 0.0, 0, 0.0, 0.0, 0.0]
		left_with_haul = 0
		print("   runs sealed: %s" % "  ".join(ranks.filter(func(r): return all_runs.has(r)).map(func(r): return "%s %d/%d" % [r, all_runs[r][0], all_runs[r][0] + all_runs[r][1]])))
	var ks := curve.keys()
	ks.sort()
	print("Clear rate by party power / recommended (all profiles): %s" % "  ".join(ks.map(func(k): return "%.1f: %d/%d" % [k / 10.0, curve[k][0], curve[k][0] + curve[k][1]])))
	if keep_legacy.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.LEGACY_PATH))
	else:
		FileAccess.open(GameState.LEGACY_PATH, FileAccess.WRITE).store_buffer(keep_legacy)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bak))
	get_tree().quit()


func _guild(p: String, s: int) -> void:
	seed(s)
	gross_gold = {}
	bill_paid = {}
	fights = {}
	runs = {}
	rounds = {}
	act_day = {}
	act_runs = {}
	notes = []
	ambush = [0, 0]
	endless_runs = 0
	descent_deepest = 0
	gate_tries = [0, 0]
	freed_day = -1
	morrow_day = -1
	morrow_lost = 0
	ending_day = -1
	ending_laurels = 0
	hall_days = []
	tides = []
	GameState.active_slot = 9
	var carried: Dictionary = GameState.legacy.duplicate(true) if chain and chain_guild > 0 else {}
	GameState.reset()
	GameState.guild_name = "Sim %d" % s
	GameState.tips_off = true
	if chain:   # one player's guilds in a row: the legacy carries, the endings vary
		GameState.legacy = carried if not carried.is_empty() else {"laurels": 0, "guilds": [], "champions": {}, "charters": GameData.FOUNDINGS.keys()}
		GameData.LEGACY_CHAMPIONS = GameState.legacy["champions"]
		ending = ["renew", "break", "rewrite"][chain_guild % 3]
		if ending == "rewrite" and not GameState.rewrite_open():
			ending = "renew"
		charter = ["quiet", "expose"][chain_guild % 2]
		chain_guild += 1
	else:
		GameState.legacy = {"laurels": 0, "guilds": [], "champions": {}, "charters": GameData.FOUNDINGS.keys()}   # the sim may found under any charter
		GameData.LEGACY_CHAMPIONS = GameState.legacy["champions"]
	if ending == "rewrite":   # the third ending needs both others in the Hall and the whole line
		GameState.legacy["guilds"] = [{"name": "Kept", "ending": "renew"}, {"name": "Broke", "ending": "break"}]
		GameState.legacy["line"] = GameData.LINE_PIECES.size()
	GameState.apply_founding(founding)
	GameState.oaths = oaths.duplicate()
	GameState.hardship = hard_level
	if year == "random":
		GameState.vale_year = GameState.roll_vale_year()
	elif year != "":
		GameState.vale_year = {"mods": Array(year.split(",")).map(func(y): return {"id": y, "region": "marsh"})}
	if not GameState.vale_year.is_empty():
		notes.append("year: " + ", ".join(GameState.vale_year_lines(GameState.vale_year).map(func(l): return l[0])))
	GameState.hire_starters()
	GameState.refresh_recruit_pool()
	if not gifts.is_empty():
		GameState.legacy["laurels"] = 999
		GameState.apply_legacy_gifts(gifts)
		GameState.legacy["laurels"] = 0
	var act := GameState.campaign_act
	_exp_sent = {}
	while GameState.day < days:
		var pay0 := int(GameState.payday_report.get("day", -1))
		var c0 := GameState.coins
		var out0: Array = GameState.expeditions.map(func(x): return str(x["hero_ids"]))
		var news0: Array = GameState.guild_news.duplicate()
		_run_party = 0
		_run_ess = 0
		_day(p)
		_exp_returns(out0, news0)
		var spent := _spent
		_spent = 0
		var paid := 0
		if int(GameState.payday_report.get("day", -1)) != pay0:
			paid = int(GameState.payday_report["paid"]) + (int(GameState.payday_report["upkeep"]) if GameState.payday_report["upkeep_paid"] else 0)
			var pw := (int(GameState.payday_report["day"]) - 1) / GameData.PAYDAY_DAYS
			bill_paid[pw] = int(bill_paid.get(pw, 0)) + paid
		var w := (GameState.day - 1) / GameData.PAYDAY_DAYS   # days 1-7 are week 0, paid on day 7
		gross_gold[w] = int(gross_gold.get(w, 0)) + maxi(0, GameState.coins - c0 + spent + paid)
		if _run_party > 0:   # a rift day: its gross Gold and Essence, less any expedition that came home today
			exp_stats[9] += 1
			exp_stats[10] += _run_party
			exp_stats[11] += maxi(0, GameState.coins - c0 + spent + paid - _exp_paid_today[0])
			exp_stats[12] += maxi(0, _run_ess - _exp_paid_today[1])
		if GameState.campaign_act != act:
			act = GameState.campaign_act
			act_day[act] = GameState.day
	GameState.active_slot = 9
	var last := (GameState.day - 1) / GameData.PAYDAY_DAYS
	var top: Array = GameState.heroes.filter(func(h): return not h.is_champion)
	top.sort_custom(func(a, b): return GameData.rank_index(a.rank) * 10 + a.level > GameData.rank_index(b.rank) * 10 + b.level)
	print("   [%s seed %d] heroes: %s · subclass trainings %d · mastery ranks %d · rooms %d · wings %s" % [p, s, " ".join(top.slice(0, 6).map(func(h): return "%s%d/%d" % [h.rank, h.level, GameData.subclass_stage(h.pool_id)])), train_count, mastery_ranks + GameState.heroes.reduce(func(a, h): return a + (h.mastery if mastery_ranks == 0 else 0), 0), int(Combat.guild_tier_info()["total"]), GameState.hall_works])
	train_count = 0
	mastery_ranks = 0
	print("   [%s seed %d] training yard: %d hero-days, attribute points trained %d" % [p, s, GameState.heroes.reduce(func(t, h): return t + int(h.history.get("trained_days", 0)), 0), GameState.heroes.reduce(func(t, h): return t + h.attr_trained, 0)])
	print("   [%s seed %d] day %d act %d · %d Gold %d Essence · roster %d · week %d bill %d of income %d · Renown %d vs rival %d · charter %s/%s · echoes %d (%d back) · ambushes %d/%d won · Endless %d runs, %s · Morrow %s%s" % [p, s, GameState.day, GameState.campaign_act, GameState.coins, GameState.crystals, GameState.heroes.size(),
		last - 1, int(bill_paid.get(last - 1, 0)), int(gross_gold.get(last - 1, 0)), GameState.reputation, GameState.rival_renown,
		GameState.charter_choice if GameState.charter_choice != "" else "-", GameState.charter_result if GameState.charter_result != "" else "-",
		GameState.echoes_seen.size(), GameState.echoes_returned, ambush[0], ambush[0] + ambush[1],
		endless_runs, (("freed day %d" % freed_day) if freed_day >= 0 else "none freed") + ((", Descent depth %d" % descent_deepest) if descent_deepest > 0 else ""),
		("beaten day %d after %d loss%s" % [morrow_day, morrow_lost, "" if morrow_lost == 1 else "es"]) if GameState.morrow_defeated else ("lost %d" % morrow_lost if morrow_lost > 0 else "-"),
		("  · " + "; ".join(notes)) if not notes.is_empty() else ""])
	if gate_tries[0] + gate_tries[1] > 0:
		print("     the City's gate: %d held, %d lost" % gate_tries)
	print("     story web: %d fragments found here (%s) · %d of %d known in all · %d of %d truths · ending %s · epilogue %s" % [GameState.lore_found_here.size(), ", ".join(GameState.lore_found_here),
		(GameState.legacy.get("fragments", []) as Array).size(), GameData.FRAGMENTS.size(), (GameState.legacy.get("truths", []) as Array).size(), GameData.TRUTHS.size(),
		GameState.accord_ending, str(GameState.legacy.get("epilogue", "-"))])
	print("     endowments: %d" % GameState.endowments)
	print("     feats done by hand: %d of %d elite/boss wins · flawless wins: %d" % [GameState.feats_done, GameState.elites_won + GameState.bosses_won, GameState.flawless_wins])
	if not GameState.feat_tally.is_empty():
		print("     feats by kind: %s" % "  ".join(GameState.feat_tally.keys().map(func(k): return "%s %d/%d" % [k, GameState.feat_tally[k][0], GameState.feat_tally[k][1]])))
	var cur := GameState.current_act()
	if not cur.is_empty():
		var unmet: Array = (cur["objectives"] as Array).filter(func(o): return not GameState.campaign_objective_met(o)).map(func(o): return "%s (%d/%d)" % [str(o["label"]), GameState.campaign_objective_progress(o), int(o["target"])])
		print("     stuck in Act %d since day %d: %s%s" % [GameState.campaign_act, int(act_day.get(GameState.campaign_act, 0)), ", ".join(unmet) if not unmet.is_empty() else "objectives met, finale not won", (" · finale tries %d/%d won · posts freed %d · best party %d vs finale %d · seals: Glass %d, City %d, crossings %d · this act: %s sealed/lost/rest/defend" % [runs.get("finale", [0, 0])[0], runs.get("finale", [0, 0])[0] + runs.get("finale", [0, 0])[1], GameState.posts_freed(), Combat.party_power(_pick_party().map(func(id): return GameState.find_hero(id))), GameState.finale_recommended_power(), int(GameState.quest_tally.get("biome_seals:glass", 0)), int(GameState.quest_tally.get("biome_seals:city", 0)), GameState.crossings_answered, str(act_runs.get(GameState.campaign_act, []))])])
	if ending_day >= 0:
		var lost: Array = tides.filter(func(t): return not t[1])
		print("     postgame (%s from day %d): Laurels %d at the ending, +%d after · %s · end %d Gold %d Essence, %d champions of %d" % [GameState.accord_ending, ending_day, ending_laurels,
			int(GameState.legacy["laurels"]) - ending_laurels,
			("halls %d/%d on days %s" % [hall_days.size(), GameData.ACCORD_HALLS.size(), hall_days]) if GameState.accord_ending == "renew" else
			("tides held %d of %d, lost: %s, %d tidewalls" % [tides.size() - lost.size(), tides.size(), lost.map(func(t): return t[0]), GameState.tidewalls]),
			GameState.coins, GameState.crystals, GameState.champions.size(), GameState.champion_roll.size()])
		if GameState.accord_ending == "break":
			# How strong a tide this guild could hold now (the next tide's defenders).
			var probe: Array = []
			for m in [1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0]:
				var opts := GameState.defense_opts()
				opts["foe_mult"] = m / GameState.tidewall_factor()
				var r := DefenseRun.new("camp", GameData.rift_rank_index(GameData.TIDE_RANK), GameState.defense_candidates().slice(0, 2), null, 7, opts)
				probe.append("x%.1f %s" % [m, "held" if _run_defense(r) else "lost"])
			print("     tide probe at day %d: %s" % [GameState.day, ", ".join(probe)])


var ambush := [0, 0]     # Company Ambush fights [won, lost]
var endless_runs := 0
var freed_day := -1
var morrow_day := -1
var morrow_lost := 0
var _party_power := 0
var _spent := 0   # Gold spent at camp and in shops today (not a loss of income)
var ending_day := -1       # the day the Accord's ending was chosen
var ending_laurels := 0    # Laurels the legacy paid at the ending
var hall_days: Array = []  # the day each Accord hall was restored
var descent_deepest := 0   # the deepest Descent depth cleared
var gate_tries := [0, 0]   # the Inverted City's gate defenses [held, lost]
var tides: Array = []      # [tide, held] for each tide of the Open Hollow


func _day(p: String) -> void:
	GameState.check_feature_unlocks()
	GameState.check_subclass_unlocks()
	GameState.check_milestones()
	_answer_stories()
	GameState.pending_stories.clear()
	GameState.pending_toasts.clear()
	_answer_matters()
	if GameState.accord_ending != "" and not GameState.legacy_written:
		ending_day = GameState.day
		ending_laurels = GameState.write_legacy([])
	_quests()
	var g0 := GameState.coins
	if p == "investor":
		_invest()
	else:
		_idle_spend()
	_spent += maxi(0, g0 - GameState.coins)
	if expeditions_on:   # after training: a capped hero's Path course needs the bench to fill the party
		_send_expeditions()
	if GameState.breach_broken():
		var da: Array = act_runs.get(GameState.campaign_act, [0, 0, 0, 0])
		da[3] += 1
		act_runs[GameState.campaign_act] = da
		_defend()
		return
	if GameState.day % 2 == 0 and _endless_due():
		if endless_mode == "survivors":
			_endless()
		else:
			_descent()
		return
	var party := _pick_party()
	if party.is_empty():
		var ra: Array = act_runs.get(GameState.campaign_act, [0, 0, 0, 0])
		ra[2] += 1
		act_runs[GameState.campaign_act] = ra
		GameState.rest_guild()
		return
	# The number the Party screen shows: relics, synergies and bonds included.
	_party_power = Combat.party_power(party.map(func(id): return GameState.find_hero(id)))
	var rank := "finale"
	if GameState.finale_ready() and (bold or _party_power >= GameState.finale_recommended_power() * 0.8):
		GameState.start_finale(party, null)
	else:
		rank = GameState.highest_open_rank()
		# Step down until the party is close to the rank's recommended power
		# (one step only spiralled: a battered party kept losing at SS).
		while not bold and _party_power < Combat.recommended_power("", rank) * 0.8 and GameData.rift_rank_index(rank) > 0:
			rank = str(GameData.RIFT_RANKS[GameData.rift_rank_index(rank) - 1]["id"])
		if GameState.daily_available():
			GameState.start_daily(rank, party, null)
		else:
			GameState.start_ladder_rift(rank, party, null)
	if party.size() < 4:   # a short party, and was the bench away on an expedition?
		short_runs[0] += 1
		short_runs[1] += 1 if not GameState.expeditions.is_empty() else 0
	short_runs[2] += 1 if rank != GameState.highest_open_rank() and rank != "finale" else 0
	var e_run := GameState.crystals
	var res := _play_run(rank)
	_run_party = party.size()
	_run_ess = GameState.crystals - e_run
	if rank != "finale":
		var b := clampi(int(round(float(_party_power) / Combat.recommended_power("", rank) * 10.0)), 4, 16)
		var ct: Array = curve.get(b, [0, 0])
		ct[0 if res == "sealed" else 1] += 1
		curve[b] = ct
	var ar: Array = act_runs.get(GameState.campaign_act, [0, 0, 0, 0])
	ar[0 if res == "sealed" else 1] += 1
	act_runs[GameState.campaign_act] = ar
	var rt: Array = runs.get(rank, [0, 0])
	rt[0 if res == "sealed" else 1] += 1
	runs[rank] = rt
	if log_days:
		print("     day %d %s (party power %d, recommended %d): %s · %d Gold" % [GameState.day, rank, _party_power, Combat.recommended_power("", rank) if rank != "finale" else 0, res, GameState.coins])


## Story cards that ask something: the echo (back or keep, 50/50), the
## Charter War's turn (the `charter=` policy) and the Accord's ending (renew).
func _answer_stories() -> void:
	while not GameState.pending_stories.is_empty():
		var c: Dictionary = GameState.pending_stories[0]
		if not c.has("choices"):
			GameState.pending_stories.pop_front()
			continue
		match str(c.get("kind", "")):
			"echo":
				GameState.answer_echo("return" if randf() < 0.5 else "keep")
			"charter":
				if charter == "":
					return
				GameState.choose_charter(charter)
			"crossing":
				GameState.answer_crossing("through" if randf() < 0.5 else "back")
			"sky":
				GameState.choose_sky_ending("both")
			"vaelith":
				GameState.choose_vaelith("end")
			"spire":
				GameState.choose_spire(spire if spire != "" else ("archive" if randf() < 0.5 else "hollin"))
			"hearing":
				GameState.choose_hearing("accept")
			"key":
				GameState.choose_key("break")
			"ezra":
				GameState.choose_lantern("keep")
			"brannoch":
				GameState.choose_brannoch("free")
			"epilogue":
				GameState.choose_epilogue("read")
			_:
				GameState.choose_accord_ending(ending, GameState.heroes[0].id)
		if not GameState.pending_stories.is_empty() and GameState.pending_stories[0] == c:
			GameState.pending_stories.pop_front()   # an answer that didn't take


func _answer_matters() -> void:
	# Damaged buildings get repaired when the Gold is there (the status board asks).
	for key in GameState.damaged.keys():
		if GameState.coins > int(GameState.payday_forecast()["bill"]) + GameState.repair_cost(str(key)):
			GameState.repair_building(str(key))
	# Camp events (0.64): a threat sends a hero if one is free, else pays when
	# there's Gold to spare; anything else is taken when the guild is flush.
	if not GameState.camp_event.is_empty():
		var opts: Array = GameState.camp_event_options()
		var flush := GameState.coins > int(GameState.payday_forecast()["bill"]) * 1.5
		var threat := str(GameData.CAMP_EVENTS[str(GameState.camp_event["id"])]["kind"]) == "threat"
		var order: Array = [1, 0] if threat else range(opts.size() - 1)
		var took := false
		for k in order:
			if int(k) < opts.size() - 1 and str(opts[k][1]) == "" and (flush or (threat and int(k) == 1)):
				GameState.answer_camp_event(int(k))
				took = true
				break
		if not took and not GameState.camp_event.is_empty():
			GameState.answer_camp_event(opts.size() - 1)
	if not GameState.hero_request.is_empty() and randf() < 0.9:
		if GameState.answer_request(randf() < 0.6) != "":
			GameState.answer_request(false)
	if not GameState.rival_event.is_empty() and not GameState.rival_event.get("answered", false):
		var opts: Array = GameState.rival_event_options()
		if opts.is_empty():
			GameState.rival_event["seen"] = true
		elif GameState.answer_rival(str(opts[0][1]) == "" and randf() < 0.6) != "":
			GameState.answer_rival(false)


func _idle_spend() -> void:
	for h in GameState.heroes:
		_spend_attrs(h)
		_learn_all(h)
		GameState.equip_best(h.id)
	var bill := GameState.weekly_wages() + GameState.upkeep()
	_grow_heroes(bill + 100)
	if GameState.heroes.size() < mini(6, GameState.hero_slot_cap()) and not GameState.recruit_pool.is_empty():
		var offer: Hero = GameState.recruit_pool[0]
		if GameState.coins - int(GameData.find_rank(offer.rank)["cost"]) > bill + 60:
			GameState.recruit_hero(offer.id)
	if GameState.feast_ready() and GameState.heroes.any(func(h): return h.morale < 45) and GameState.coins > bill + GameState.feast_cost():
		GameState.hold_feast()
	if advice:   # a casual player who reads the Act panel's advice when it shows
		if GameState.advice_due(Combat.party_power(_pick_party().map(func(id): return GameState.find_hero(id)))) or GameState.spare_wealth():
			for i in 3:
				var tips: Array = GameState.power_advice()
				if tips.is_empty() or GameState.follow_advice(tips[0]) != "":
					break


func _quests() -> void:
	for q in GameState.guild_board.duplicate():
		if str(q["status"]) == "active" and GameState.quest_progress(q) >= int(q["target"]):
			GameState.claim_quest(str(q["id"]))
	if GameState.feature_unlocked("quests"):
		for q in GameState.guild_board:
			if str(q["status"]) == "posted":
				GameState.accept_quest(str(q["id"]))


## Spends like a player who reads the tooltips: quests, skill and attribute
## points, evolutions, training, the cheapest facility upgrade, recruits up
## to the cap (keeping next payday's bill in hand), a champion level.
func _invest() -> void:
	for h in GameState.heroes:
		_spend_attrs(h)
		_learn_all(h)
	var bill := GameState.weekly_wages() + GameState.upkeep()
	if not GameState.wing_offer.is_empty() and GameState.coins - GameState.hall_work_cost() > bill + 100:   # the wing on offer (0.65: the first of the two), before anything else
		GameState.build_hall_work(str(GameState.wing_offer[0]))
	_grow_heroes(bill + 200)
	var wing_keep := GameState.hall_work_cost() / 2 if not GameState.wing_offer.is_empty() else 0   # half the wing on offer kept in hand
	for round_i in 3:
		var best_key := ""
		var best_cost := 1 << 30
		for b in GameData.BRANCHES:
			for n in b["nodes"]:
				var key := "%s.%s" % [b["id"], n["id"]]
				var cur := int(GameState.upgrades.get(key, 0))
				if cur >= int(n["max"]):
					continue
				var cost := GameState.room_cost(key)   # 0.65: every room is built with Gold
				var ok: bool = GameState.coins - cost > bill + 150 + wing_keep and GameState.room_open(key)
				if ok and cost < best_cost:
					best_cost = cost
					best_key = key
		if best_key == "" or GameState.upgrade_node(best_key) != "":
			break
	while GameState.heroes.size() < GameState.hero_slot_cap() and not GameState.recruit_pool.is_empty():
		var offers: Array = GameState.recruit_pool.filter(func(o): return GameState.coins - int(GameData.find_rank(o.rank)["cost"]) > bill + 100)
		if offers.is_empty():
			break
		offers.sort_custom(func(a, b): return int(GameData.find_rank(a.rank)["cost"]) > int(GameData.find_rank(b.rank)["cost"]))
		if GameState.recruit_hero(offers[0].id) != "":
			break
		bill = GameState.weekly_wages() + GameState.upkeep()
	# The bench trains (0.58): heroes outside the best four, a 3-day course in their role's attribute.
	var lineup := _pick_party()
	for h in GameState.heroes:
		if GameState.training_free() > 0 and not lineup.has(h.id) and h.is_available() and not h.is_champion and GameState.crystals - GameState.train_fee(h, 3) > 40:
			var spread: Array = GameData.ROLE_ATTR_SPREAD.get(GameData.hero_role(h), ["might"])
			GameState.start_training(h.id, str(spread[0]), 3)
	if GameState.accord_ending == "renew":   # Keepers of the Vale
		for hall in GameData.ACCORD_HALLS:
			var keep_wages: bool = GameState.coins - int(GameState.hall_cost(str(hall["id"]))[0]) > bill + 300
			if keep_wages and GameState.hall_lock(str(hall["id"])) == "" and GameState.restore_hall(str(hall["id"])) == "":
				hall_days.append(GameState.day)
	while GameState.accord_ending == "break" and GameState.coins - int(GameState.tidewall_cost()[0]) > bill + 300 and GameState.raise_tidewall() == "":   # the Open Hollow
		pass
	if GameState.legacy_written and (GameState.halls_restored.size() >= GameData.ACCORD_HALLS.size() or GameState.accord_ending == "break"):
		while GameState.coins - GameState.endow_cost() > bill + 2000 and GameState.endow() == "":   # the endowment, once nothing else wants the Gold
			pass
	for id in GameState.champions:
		var c := GameState.champion_level_cost(str(id))
		if c > 0 and GameState.crystals > c + 200:
			GameState.level_champion(str(id))
	for i in 3:   # Path Mastery (0.65), the cheapest rank first, keeping some Essence back
		var mh := GameState.mastery_pick()
		if mh == null or GameState.crystals <= GameState.mastery_cost(mh) + 200 or GameState.train_mastery(mh.id) != "":
			break
		mastery_ranks += 1
	if GameState.feast_ready() and GameState.heroes.any(func(h): return h.morale < 45) and GameState.coins > bill + GameState.feast_cost():
		GameState.hold_feast()
	for h in GameState.heroes:
		GameState.equip_best(h.id)
	# Gold into power (0.61): temper the lineup's gear, cheapest first (the wing on offer comes before the rooms, above).
	var worn: Array = GameState.items.filter(func(it): return lineup.has(it.equipped_to))
	var keep_forge := GameState.hall_work_cost() / 2 if not GameState.wing_offer.is_empty() else 0
	for i in 12:
		worn.sort_custom(func(a, b): return GameState.forge_cost(a) < GameState.forge_cost(b))
		var nxt: Array = worn.filter(func(it): return GameState.forge_cost(it) > 0)
		if nxt.is_empty() or GameState.coins - GameState.forge_cost(nxt[0]) <= bill + 300 + keep_forge or GameState.forge_item(nxt[0].id) != "":
			break


## Evolve every hero at level 10 and send heroes to subclass training (0.62),
## keeping `reserve` Gold for payday and four heroes free for runs. The Path:
## the hero's own, else (stage 1) a random unlocked one.
func _grow_heroes(reserve: int) -> void:
	for h in GameState.heroes:
		var c := GameState.evolve_cost(h)
		if not c.is_empty() and GameState.evolve_lock(h) == "" and GameState.coins - int(c[0]) > reserve:
			GameState.evolve_hero(h.id)
	for h in GameState.heroes:
		if GameState.heroes.filter(func(x): return x.is_available() and not x.is_champion).size() <= 4 or GameState.training_free() <= 0:
			break
		var opts: Array = GameState.subclass_training_options(h).filter(func(o): return str(o["lock"]) == "" and not bool(o["change"]))
		if opts.is_empty() or GameState.coins - int(opts[0]["cost"]["gold"]) <= reserve:
			continue
		var pick: Dictionary = opts[0] if h.path != "" else opts[randi() % opts.size()]
		if GameState.start_subclass_training(h.id, str(pick["id"])) == "":
			train_count += 1


func _spend_attrs(h: Hero) -> void:
	if force_attr == "":
		Combat.auto_spend_attrs(h)
		return
	for i in h.attr_points:
		GameState.spend_attr_point(h.id, force_attr)


## Skill points: the hero's own tree first, in order.
func _learn_all(h: Hero) -> void:
	var kinds: Array = GameData.KIND_SKILL_PACKAGE.keys()
	kinds.erase(h.innate_kind)
	kinds.push_front(h.innate_kind)
	for pass_i in 3:
		for kind in kinds:
			for id in ["edge", "hide"] + (GameData.KIND_SKILL_PACKAGE[kind] as Array).map(func(n): return str(n["id"])):
				if h.skill_points > 0:
					GameState.learn_skill(h.id, str(kind), str(id))


## Bench heroes (outside the top four) take the best-paying posting they
## have at least a 50% chance on: the sim's expedition player.
func _send_expeditions() -> void:
	if not GameState.expeditions_open():
		return
	var lineup := _pick_party()
	for round_i in 2:
		if GameState.expeditions.size() >= GameState.expedition_cap() or GameState.expedition_board.is_empty():
			return
		var bench: Array = GameState.heroes.filter(func(h): return not h.is_champion and h.is_available() and not lineup.has(h.id) and h.training.is_empty())
		bench.sort_custom(func(a, b): return Combat.power_of(a) > Combat.power_of(b))
		var best := -1
		var best_ids: Array = []
		var best_ev := 0.0
		for i in GameState.expedition_board.size():
			var post: Dictionary = GameState.expedition_board[i]
			var e := GameState.expedition_def(str(post["id"]))
			var ids: Array = bench.slice(0, int(e["size"])).map(func(h): return h.id)
			if ids.is_empty():
				continue
			var c := GameState.expedition_chance(post, ids)
			var ev := (c + (1.0 - c) * 0.25) * (float(post["gold"]) + 3.0 * float(post["essence"])) / (float(ids.size()) * float(e["days"]))
			if c >= 0.5 and ev > best_ev:
				best = i
				best_ids = ids
				best_ev = ev
		if log_days:
			var bp := 0.0
			for i2 in GameState.expedition_board.size():
				var pp: Dictionary = GameState.expedition_board[i2]
				var ids2: Array = bench.slice(0, int(GameState.expedition_def(str(pp["id"]))["size"])).map(func(h): return h.id)
				if not ids2.is_empty():
					bp = maxf(bp, GameState.expedition_chance(pp, ids2))
			print("     exp day %d act %d sealed %s bench %d best chance %.2f" % [GameState.day, GameState.campaign_act, GameData.RIFT_RANKS[maxi(0, GameState.best_rift_rank_sealed)]["id"], bench.size(), bp])
		if best < 0:
			return
		var post2: Dictionary = GameState.expedition_board[best]
		var e2 := GameState.expedition_def(str(post2["id"]))
		var rec := {"gold": int(post2["gold"]), "ess": int(post2["essence"]), "bon": GameState.expedition_bonuses(best_ids), "days": int(e2["days"]), "n": best_ids.size(), "tier": int(e2["tier"])}
		if GameState.send_expedition(best, best_ids) == "":
			_exp_sent[str(best_ids)] = rec
			exp_stats[0] += 1


## Parties back today: their outcome (from the news line) and what they paid.
func _exp_returns(out0: Array, news0: Array) -> void:
	_exp_paid_today = [0, 0]
	var still: Array = GameState.expeditions.map(func(x): return str(x["hero_ids"]))
	var fresh: Array = GameState.guild_news.filter(func(l): return not news0.has(l) and str(l).contains("Expedition:"))
	for key in _exp_sent.keys():   # every party sent and no longer out (a 1-day job comes back the day it left)
		if still.has(key):
			continue
		var rec: Dictionary = _exp_sent[key]
		_exp_sent.erase(key)
		var line := str(fresh.pop_front()) if not fresh.is_empty() else ""
		var outcome := "success" if line.contains("a success") else ("partial" if line.contains("half done") else "failure")
		var share := {"success": 1.0, "partial": 0.5, "failure": 0.0}[outcome] as float
		var g := int(round(int(rec["gold"]) * share * (1.0 + float(rec["bon"]["gold"]))))
		var ess := int(round(int(rec["ess"]) * share * (1.0 + float(rec["bon"]["ess"]))))
		exp_stats[{"success": 1, "partial": 2, "failure": 3}[outcome]] += 1
		exp_stats[4] += g
		exp_stats[5] += ess
		exp_stats[6] += int(rec["n"]) * int(rec["days"])
		exp_stats[7] += 1 if outcome == "partial" else (int(rec["n"]) if outcome == "failure" else 0)
		_exp_paid_today[0] += g
		_exp_paid_today[1] += ess
	exp_stats[8] += GameState.pending_toasts.filter(func(t): return str(t.get("text", "")).contains("keeps a scar")).size()


func _pick_party() -> Array[String]:
	var ok: Array = GameState.heroes.filter(func(h): return not h.is_champion and not h.is_downed() and not h.is_away() and h.hp > Combat.max_hp(h) * 0.35)
	ok.sort_custom(func(a, b): return Combat.power_of(a) > Combat.power_of(b))
	var out: Array[String] = []
	for h in ok.slice(0, 4):
		out.append(h.id)
	return out


func _tally(rank: String, won: bool) -> void:
	var t: Array = fights.get(rank, [0, 0])
	t[0 if won else 1] += 1
	fights[rank] = t


func _play_run(rank: String, posts0: int = -1) -> String:
	for step in 200:
		if GameState.run.is_empty():
			return "?"
		# The Descent: decide at each landing (a new depth's campfire).
		var dpos := int(GameState.run.get("pos", 0))
		if GameState.run.has("descent") and dpos > 0 and dpos % GameData.DESCENT_FLOORS == 0 and (GameState.run.get("node_state", {}) as Dictionary).is_empty() 				and (GameState.posts_freed() > posts0 or _party_hp() < 0.5 or int(GameState.run["descent"]) > 5):
			var depth := int(GameState.run["descent"])
			GameState.retreat_now()
			return "climbed out at depth %d" % depth
		if GameState.run.get("sealed") is Dictionary and not (GameState.run["sealed"] as Dictionary).is_empty():
			var offer: Array = GameState.run["sealed"].get("path_relics", [])
			if not offer.is_empty() and take_path_relics:   # the Path relic most of the party can use (0.65)
				var best := 0
				var best_n := -1
				for i in offer.size():
					var pid := str(GameData.find_unique_relic(str(offer[i]))["path"])
					var n := GameState.current_party().filter(func(h): return GameData.hero_path_id(h) == pid).size()
					if n > best_n:
						best = i
						best_n = n
				GameState.pick_path_relic(best)
				path_relics_taken += 1
			GameState.finish_run()
			return "sealed"
		if not GameState.pending_injuries().is_empty():
			for inj in GameState.pending_injuries():
				var hid := str(inj.get("hero_id", inj.get("id", "")))
				if GameState.injury_heal(hid) != "":
					GameState.injury_carry(hid)
			continue
		var kind := GameState.current_node_kind()
		if kind == "" and GameState.haul_at_risk() and _party_hp() < 0.35:
			# Badly hurt with a haul to lose: take it home (0.56).
			GameState.retreat_now()
			left_with_haul += 1
			return "left with the haul"
		if kind == "":
			var opts := GameState.current_layer_options()
			var prefs := ["boss", "pillar", "combat", "echo", "event", "shop", "anvil", "elite", "treasure", "shrine", "campfire", "hazard"]
			if _party_hp() < 0.55 or (GameState.resolve_on() and GameState.resolve_now() <= GameData.RESOLVE_WAVER + 1):
				prefs = ["boss", "campfire", "echo", "anvil", "shrine", "event", "treasure", "shop", "combat", "hazard", "elite"]
			for pr in prefs:
				if opts.has(pr):
					kind = pr
					break
			if kind == "":
				kind = str(opts[0])
			GameState.choose_node_type(kind)
			continue
		var ns: Dictionary = GameState.run.get("node_state", {})
		match kind:
			"combat", "elite", "boss", "pillar":
				if not ns.has("result") and not GameState.current_party().any(func(h): return not h.is_downed() and h.hp > 0):
					GameState.retreat_now()   # everyone fell to a hazard: nobody can engage
					return "nobody left to fight"
				if not ns.has("result"):
					if hand:
						_hand_fight()
					else:
						GameState.quick_fight()
					continue
				var result: Dictionary = ns["result"]
				if not ns.get("tallied", false):
					ns["tallied"] = true
					_tally(rank, bool(result.get("won", false)))
					var bk: Array = by_kind.get(kind, [0, 0, 0.0, 0.0])
					var won_now := bool(result.get("won", false))
					bk[0 if won_now else 1] += 1
					if not won_now:
						lost_high[0] += 1
						if float(ns.get("combat_state", {}).get("_start_hp_pct", 1.0)) > 0.9:
							lost_high[1] += 1
					if kind == "boss" and GameState.resolve_on():
						var wv := int(ns.get("combat_state", {}).get("_waver", 0))
						resolve_doors[0] += 1
						resolve_doors[4] += GameState.resolve_now()
						if wv > 0:
							resolve_doors[wv] += 1
							if won_now:
								resolve_doors[3] += 1
					bk[3 if won_now else 2] += float(ns.get("combat_state", {}).get("_start_hp_pct", 1.0))
					by_kind[kind] = bk
					var tier := "S+" if GameState.wounds_last_run() else ("C-A" if GameState.wounds_on() else "")
					if tier != "":
						var sk: Array = stakes.get(tier, [0, 0, 0, 0.0, 0, 0, 0, 0, 0, 0, 0])
						var cs: Dictionary = ns.get("combat_state", {})
						var stt: Dictionary = cs.get("_stats", {})
						sk[10] += 1
						if kind == "combat":
							sk[0 if won_now else 1] += 1
						if kind == "boss":   # HP against base max HP, so wounds count
							sk[2] += 1
							sk[3] += float(cs.get("_start_hp_base", cs.get("_start_hp_pct", 1.0)))
						sk[4] += int(stt.get("wounds", 0.0))
						sk[5] += int(stt.get("wound_guarded", 0.0) + stt.get("wound_defended", 0.0) + stt.get("wound_dodged", 0.0))
						sk[6] += (cs.get("party", []) as Array).filter(func(x): return x.hp <= 0).size()
						var lg: Array = result.get("log", [])
						sk[7] += lg.filter(func(l): return str(l).contains("lasting scar")).size()
						sk[8] += lg.filter(func(l): return str(l).contains("in the rift.") and str(l).contains(" drops their ")).size()
						sk[9] += lg.filter(func(l): return str(l).contains("does not get up again")).size()
						stakes[tier] = sk
					if won_now:
						sustain[0] += float(ns.get("combat_state", {}).get("mend", 0.0))
						sustain[1] += float(ns.get("combat_state", {}).get("_start_hp_pct", 1.0))
						sustain[2] += _party_hp()
						sustain[3] += 1
						var cst: Dictionary = ns.get("combat_state", {})
						sustain[4] += float(cst.get("dodge", 0.0))
						sustain[5] += float(cst.get("wipe_guard", 0.0))
						sustain[6] += float(cst.get("round_num", 0))
					var ms: Array = ns.get("combat_state", {}).get("monsters", [])
					if ms.any(func(m): return str(m["name"]) == "Company Crossbowman"):
						ambush[0 if result.get("won", false) else 1] += 1
					if kind == "boss" and GameState.run.get("morrow", false):
						if result.get("won", false):
							morrow_day = GameState.day
						else:
							morrow_lost += 1
					var rt: Array = rounds.get(rank, [0, 0, 0])
					rounds[rank] = [rt[0] + 1, rt[1] + int(result.get("rounds", 0)), rt[2] + (1 if int(result.get("rounds", 0)) <= 1 else 0)]
				if not result.get("won", false):
					GameState.finish_run()
					return "lost at " + kind
				if not ns.get("reward_chosen", false) and not (result.get("reward_options", []) as Array).is_empty():
					GameState.pick_combat_reward(0)
				if GameState.boon_pending():
					GameState.pick_boon(0)
				if not GameState.pending_injuries().is_empty():
					continue
				if kind == "boss":
					GameState.seal_rift()
				else:
					GameState.advance_node()
			"event":
				GameState.ensure_event()
				var ev: Dictionary = GameState.run["node_state"]["event"]
				if not GameState.run["node_state"].get("resolved", false):
					var choices: Array = ev["choices"]
					var ci := randi() % choices.size()
					if not GameState.can_afford(choices[ci].get("cost", {})):
						ci = choices.size() - 1
					GameState.resolve_event(ci)
				GameState.advance_node()
			"campfire":
				GameState.campfire_choose("rest" if _party_hp() < 0.8 or (GameState.resolve_on() and GameState.resolve_now() <= GameData.RESOLVE_WAVER + 2) else "train")
				GameState.advance_node()
			"treasure":
				GameState.ensure_treasure()
				GameState.pick_treasure(0)
				GameState.advance_node()
			"anvil", "shrine", "echo":   # the lane map's nodes (0.65)
				GameState.ensure_lane_node()
				if kind == "anvil" and not GameState.anvil_items().is_empty():
					GameState.use_anvil(GameState.anvil_items()[0].id)
				elif kind == "shrine":
					GameState.pray_at_shrine()
				elif kind == "echo":
					var low: Array = GameState.current_party().filter(func(h): return h.hp > 0)
					low.sort_custom(func(a, b): return a.level < b.level)
					if not low.is_empty():
						GameState.train_with_echo(low[0].id)
				GameState.advance_node()
			"shop":
				GameState.ensure_shop_offers()
				var offers: Array = GameState.run["node_state"].get("offers", [])
				for i in offers.size():
					if GameState.coins - int(offers[i]["price"]) > GameState.weekly_wages() + GameState.upkeep() + 40:
						var c0 := GameState.coins
						GameState.buy_shop_offer(i)
						_spent += maxi(0, c0 - GameState.coins)
						break
				GameState.advance_node()
			"hazard":
				GameState.ensure_hazard()
				GameState.push_through_hazard()
				GameState.advance_node()
			_:
				GameState.advance_node()
	notes.append("day %d: run stuck" % GameState.day)
	GameState.retreat_now()
	return "stuck"


## A fight played turn by turn the way the battle screen's buttons would.
func _hand_fight() -> void:
	GameState.engage_node()
	var st: Dictionary = GameState.run.get("node_state", {}).get("combat_state", {})
	for i in 600:
		if st.is_empty() or GameState.run.get("node_state", {}).has("result"):
			break
		var nxt := Combat.peek_next_turn(st)
		if str(nxt["type"]) == "hero":
			var h := Combat._find_party_hero(st["party"], str(nxt["id"]))
			if h and h.hp > 0:
				st["pending_actions"][h.id] = _hand_action(st, h)
		GameState.resolve_turn_now()
	if float(GameState.run.get("node_state", {}).get("result", {}).get("hand_bonus_ess", 0)) > 0:
		hand_bonus += 1


## What a careful player does on top of Auto: Defend against any hit that
## would drop this hero (Auto only braces for wind-up blows), Guard a hurt ally
## from a hit that would drop them when this hero can take it, and focus the
## foe that hurts most per point of health left instead of the weakest.
func _hand_action(st: Dictionary, h: Hero) -> Dictionary:
	var monsters: Array = st["monsters"]
	var threat_on := Combat.incoming_hits(st)
	var mine := int(threat_on.get(h.id, 0))
	if mine > 0 and mine >= h.hp:
		return {"action": "defend", "target": 0}
	for x in st["party"]:
		var hit := int(threat_on.get(x.id, 0))
		if x != h and x.hp > 0 and hit >= x.hp and Combat.guard_of(st, x) == null and h.hp - mine > hit * Combat.GUARD_DAMAGE_MULT * 1.2:
			return {"action": "guard", "target": 0, "ally": x.id}
	var a := Combat.auto_action(st, h)
	if str(a["action"]) == "attack" or str(a["action"]) in ["skill:pierce", "skill:strike", "skill:backstab", "skill:volley"]:
		var best := -1
		var best_v := -1.0
		for mi in monsters.size():
			var m: Dictionary = monsters[mi]
			if float(m["hp"]) <= 0:
				continue
			var v := float(m["dmg"]) * (2.0 if m.get("_winding", false) or m.get("_charged", false) else 1.0) / maxf(1.0, float(m["hp"]))
			if v > best_v:
				best_v = v
				best = mi
		if best >= 0:
			a["target"] = best
	return a


## The act still needs a champion freed and there are champions to send.
func _endless_due() -> bool:
	var act := GameState.current_act()
	if act.is_empty() or not GameState.endless_unlocked() or GameState.champions.is_empty():
		return false
	return (act["objectives"] as Array).any(func(o): return str(o["type"]) == "posts_freed" and not GameState.campaign_objective_met(o))


## One Endless run: up to four champions, autopilot, the strongest pick each
## level-up, until it ends or 25 minutes in.
func _endless() -> void:
	var party: Array = []
	for id in GameState.champion_roll:
		if GameState.champion_unlocked(str(id)) and party.size() < 4:
			party.append(GameState.champion_hero(str(id)))
	var r := SurvivorsRun.new(party, GameState.pick_biome())
	r.lost = GameState.lost_champions().filter(func(e): return not GameState.champion_unlocked(str(e[0])))
	r.threat = GameState.endless_threat()
	while not r.over and r.time < 1500.0:
		r.step(0.2, r.autopilot_dir())
		r.events.clear()
		r.settle_picks(_best_pick)
	endless_runs += 1
	if not r.rescued.is_empty() and freed_day < 0:
		freed_day = GameState.day
	GameState.finish_survivors(r)


## One Descent with the strongest party: deeper while the party holds up,
## out at a landing once a champion is freed, the party is hurt, or depth 5.
func _descent() -> void:
	var party := _pick_party()
	if party.is_empty():
		GameState.rest_guild()
		return
	var posts := GameState.posts_freed()
	GameState.start_descent(party, null)
	endless_runs += 1
	var res := _play_run(GameState.descent_rank(), posts)
	descent_deepest = maxi(descent_deepest, GameState.descent_best)
	if GameState.posts_freed() > posts and freed_day < 0:
		freed_day = GameState.day
	if log_days:
		print("     day %d Descent: %s" % [GameState.day, res])


func _best_pick(o: Array) -> String:
	if o.is_empty():
		return ""
	for pref in ["evolve:", "fuse:", "ability:", "mod:", "might", "vigor", "skill:", "haste", "area"]:
		for id in o:
			if str(id).begins_with(pref) and not (pref == "skill:" and str(id).split(":")[2] in ["heal", "sanctuary", "taunt", "smoke_bomb"]):
				return str(id)
	return str(o[randi() % o.size()])


func _defend() -> void:
	if not GameData.DEFENSE_TD_ENABLED:   # 0.63: a breach rift, played like any run
		var tide0 := int(GameState.breach.get("tide", 0))
		var gate0 := bool(GameState.breach.get("gate", false))
		var party := _pick_party()
		if party.is_empty():
			GameState.rest_guild()
			return
		GameState.start_breach_rift(party)
		var held := _play_run(GameState.breach_rank_id()) == "sealed"
		if gate0:
			gate_tries[0 if held else 1] += 1
		if tide0 > 0:
			tides.append([tide0, held])
		return
	var posted: Array = GameState.defense_candidates().slice(0, 2)
	var r := DefenseRun.new(str(GameState.breach["region"]), int(GameState.breach["rank"]), posted, null, 7, GameState.defense_opts())
	_run_defense(r)
	var tide := int(GameState.breach.get("tide", 0))
	var gate := bool(GameState.breach.get("gate", false))
	var out := GameState.resolve_breach(r.result())
	if gate:
		gate_tries[0 if bool(out["held"]) else 1] += 1
	if tide > 0:
		tides.append([tide, bool(out["held"])])


## Plays a defense on autoplay to the end; true if it held.
func _run_defense(r: DefenseRun) -> bool:
	for k in 6000:
		if r.over:
			break
		if k % 25 == 0:
			r.autoplay()
			if r.build_t > 0.0 and r.wave > 0:
				r.call_early()
		r.step(0.1)
		r.events.clear()
	return bool(r.result().get("held", false))


func _party_hp() -> float:
	var cur := 0.0
	var mx := 0.0
	for h in GameState.current_party():
		cur += maxf(0, h.hp)
		mx += Combat.max_hp(h)
	return cur / maxf(1.0, mx)
