extends "res://tests/base_test.gd"
## The Unwritten Accord, Phase 3: the Far Side and the Witnesses. Branches B7
## (Brannoch's door), B8 (the Choir sings), B9 (the First Signatory), the
## year of witnesses, and the epilogue's world flags.


func _guild(name: String) -> void:
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = name
	GameState.hire_starters()
	GameState.pending_stories.clear()
	GameState.pending_toasts.clear()


func _fresh_legacy(truths: Array = [], guilds: Array = []) -> void:
	GameState.legacy = {"laurels": 0, "guilds": guilds.duplicate(true), "champions": {}, "truths": truths.duplicate()}
	GameData.LEGACY_CHAMPIONS = GameState.legacy["champions"]


## A crossing card from maybe_crossing (it fires 60% of the time).
func _crossing() -> Dictionary:
	for i in 60:
		GameState.pending_stories.clear()
		GameState.maybe_crossing()
		if not GameState.pending_stories.is_empty():
			return GameState.pending_stories[0]
	return {}


func run() -> void:
	# Book II's opening: whose Terms, and (after a rewrite) the list on the wall.
	_fresh_legacy([], [{"name": "Turn Takers", "ending": "rewrite"}])
	_guild("Far Siders")
	GameState.campaign_act = 5
	GameState.choose_accord_ending("break")
	var sky: Array = GameState.pending_stories.filter(func(c): return str(c.get("title", "")) == "The Sky Beneath")
	check(not sky.is_empty() and str(sky[0]["text"]).contains("Yours. Not theirs") and str(sky[0]["text"]).contains("in turns"), "Book II's reply carries both its fragments")

	# B8: the Choir, once the knock is known.
	(GameState.legacy["truths"] as Array).append("t_knock")
	GameState.run = {"biome": "glass"}
	GameState.crossings_answered = 2   # the Choir's turn
	var choir := _crossing()
	check(str(choir.get("id", "")) == "choir" and (choir["choices"] as Array).has("sing"), "the Choir can be asked to sing")
	GameState.breach = {}
	var rep0 := GameState.reputation
	var m0 := GameState.heroes[0].morale
	GameState.answer_crossing("sing")
	check(GameState.reputation == rep0 + GameData.CHOIR_SING_RENOWN and GameState.heroes[0].morale == mini(100, m0 + GameData.CHOIR_SING_MORALE), "the song: Renown and morale")
	check(GameState.breach_next_day == GameState.day + 2 and GameState.crossings_answered == 3, "and a Riftbreak two days out; it counts as a crossing")

	# B9: the First Signatory, with a both-worlds guild in the Hall.
	_fresh_legacy(["t_terms_hers"], [{"name": "Open Doors", "ending": "renew", "sky": "both"}])
	_guild("Signatories")
	GameState.campaign_act = 5
	GameState.accord_ending = "break"
	GameState.run = {"biome": "glass"}
	GameState.crossings_answered = 1
	var sig := _crossing()
	check(str(sig.get("id", "")) == "signatory", "the hidden sixth crossing comes to the door")
	var n := GameState.heroes.size()
	GameState.answer_crossing("through")
	var newest: Hero = GameState.heroes[-1]
	check(GameState.heroes.size() == n + 1 and newest.rank == "A" and newest.quirks.has("Hollow-born"), "let through, she joins: Hollow-born, Rank A")
	check(GameState.fragment_known("f_first_page") and str(GameState.pending_stories[0]["text"]).contains("crowned door"), "and opens her satchel: the first page")
	check(GameState.fragment_known("f_wrote_first") and GameState.claim_heard("hollow_answered"), "any crossing let through tells who wrote first")
	GameState.pending_stories.clear()
	check(_crossing().get("id", "") != "signatory", "she comes once")

	# B7: Brannoch's door.
	_fresh_legacy(["t_brannoch"])
	_guild("Door Keepers")
	GameState.campaign_act = 5
	GameState._complete_act(5)
	check(GameState.pending_stories.any(func(c): return str(c.get("kind", "")) == "brannoch"), "Act VI opens on Brannoch's door")
	check(not GameState.gate_due(), "the gate waits for the answer")
	GameState.pending_stories = GameState.pending_stories.filter(func(c): return str(c.get("kind", "")) == "brannoch")
	GameState.choose_brannoch("leave")
	check(GameState.gates_held == 1 and not GameState.gate_due() and not GameState.champion_unlocked("brannoch"), "left holding: the gate holds, and he stays")
	_guild("Reliefs")
	GameState.campaign_act = 6
	GameState.pending_stories = [GameData.BRANNOCH_CHOICE.duplicate(true)]
	GameState.choose_brannoch("free")
	check(GameState.champion_unlocked("brannoch") and GameState.champion_level("brannoch") == GameData.BRANNOCH_LEVEL, "freed: he joins at level %d" % GameData.BRANNOCH_LEVEL)
	GameState._swell_gate()
	check(int(GameState.breach["rank"]) == GameData.rift_rank_index("SS"), "and the gate comes at Rank SS")

	# Event fragments: a deep pillar, the gate's knock.
	check(GameState.lore_event("descent", "6").contains("height") and GameState.lore_event("gate", "held").contains("relief"), "a deep Descent and a held gate carry fragments")
	check(GameState.claim_heard("hollow_promised"), "the knock is the Hollow's people's third claim")
	check(GameState.truth_known("t_brannoch"), "")

	# A truth that needs three.
	_fresh_legacy()
	_guild("Seal Hunters")
	GameState.find_fragment("f_first_page")
	GameState.find_fragment("f_stipend")
	check(not GameState.truth_known("t_first_seal"), "the Crown's seal needs three of its fragments")
	GameState.find_fragment("f_recalled")
	check(GameState.truth_known("t_first_seal"), "three make it known")

	# The year of witnesses comes only after a rival's truth.
	var seen := false
	for i in 120:
		seen = seen or (GameState.roll_vale_year()["mods"] as Array).any(func(y): return str(y["id"]) == "witnesses")
	check(not seen, "no year of witnesses before the Chorus's or the Wolves' truth")
	(GameState.legacy["truths"] as Array).append("t_wolves")
	for i in 200:
		seen = seen or (GameState.roll_vale_year()["mods"] as Array).any(func(y): return str(y["id"]) == "witnesses")
	check(seen, "then it can come round")
	GameState.vale_year = {"mods": [{"id": "witnesses", "region": ""}]}
	check(GameData.RIVAL_MOVE_CHANCE * GameState.year_mult("rival_moves") >= 1.0, "and the rival writes every week")

	# The epilogue: read aloud.
	_fresh_legacy(GameData.EPILOGUE_TRUTHS)
	_guild("First Readers")
	GameState.campaign_act = 7
	GameState.accord_ending = "renew"
	GameState.write_legacy([])
	var laurels0 := int(GameState.legacy["laurels"])
	GameState.choose_sky_ending("both")
	check(GameState.pending_stories.any(func(c): return str(c.get("kind", "")) == "epilogue"), "after Book II's ending, the first signature")
	GameState.pending_stories = GameState.pending_stories.filter(func(c): return str(c.get("kind", "")) == "epilogue")
	var gold0 := GameState.charter_pay(false)
	GameState.choose_epilogue("read")
	check(GameState.epilogue() == "read" and int(GameState.legacy["laurels"]) == laurels0 + GameData.EPILOGUE_LAURELS, "read aloud: +%d Laurels" % GameData.EPILOGUE_LAURELS)
	check(absf(GameState.charter_pay(false) - gold0 * GameData.EPILOGUE_READ_GOLD) < 0.001, "contracts pay less without the Treasury")
	check(str((GameState.legacy["guilds"] as Array)[-1].get("epilogue", "")) == "read", "the Hall remembers it")
	_guild("Moot Guild")
	check(GameState.hollowborn_open() and GameState.moot(), "later guilds: Hollow-born from the start, and a moot")
	GameState.reputation = 50
	GameState.rival_renown = 10
	var hearing := GameState._charter_hearing()
	check(str(hearing["title"]) == "The Vale's Moot" and GameState.charter_result == "won", "the Crown's hearing is the Vale's Moot")
	check(absf(GameState.charter_pay(false) - GameData.EPILOGUE_READ_GOLD) < 0.001, "which pays no Crown bonus")
	var h0: Hero = GameState.heroes[0]
	var w_moot := GameState.wage_of(h0)
	GameState.charter_result = ""
	check(w_moot < GameState.wage_of(h0), "but heroes ask less of the Vale's guild")
	GameState.campaign_act = 5
	GameState.accord_ending = "break"
	var L: Dictionary = GameData.LAURELS
	check(GameState.laurels_earned() == int(round((4 * int(L["act"]) + int(L["ending"])) * GameData.EPILOGUE_READ_LAURELS)), "and guilds earn more Laurels")
	GameState.campaign_act = 7
	GameState.pending_stories.clear()
	GameState.choose_sky_ending("ours")
	check(not GameState.pending_stories.any(func(c): return str(c.get("kind", "")) == "epilogue"), "the epilogue comes once per player")

	# ... or burned.
	_fresh_legacy(GameData.EPILOGUE_TRUTHS)
	GameState.legacy["epilogue"] = "burn"
	_guild("Royal Patrons")
	GameState.rival_name = "The Ashen Wolves"
	GameState.apply_founding("free")
	check(GameState.rival_name == "The Iron Chorus", "royal patronage: the Iron Chorus is always the rival")
	GameState.coins = 1000
	GameState._epilogue_month()
	check(GameState.coins == 900, "the Crown's tithe takes a tenth every month")
	GameState.branches["epilogue"] = "burn"
	GameState._epilogue_month()
	check(GameState.coins == 900 + GameData.EPILOGUE_PENSION, "the guild that burned it draws a pension instead")
	GameState.hear_claim("orla_deserter")
	(GameState.legacy["truths"] as Array).append("t_why_left")
	check(GameState.claim_status((GameData.WITNESSES[2]["claims"] as Array)[1]) == "open", "and the Crown's version is never struck through")

	_fresh_legacy()
	GameState.save_legacy()
	GameState.delete_slot(9)
