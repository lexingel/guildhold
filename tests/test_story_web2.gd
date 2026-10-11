extends "res://tests/base_test.gd"
## The Unwritten Accord, Phase 2: the Key and the Lantern. Branches B2 (turn
## Morrow), B3 (buy the hearing), B4 (Pip's Key), B6 (pour out the lantern),
## and the founding options truths open.


func _guild(name: String) -> void:
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = name
	GameState.hire_starters()
	GameState.pending_stories.clear()
	GameState.pending_toasts.clear()


func _fresh_legacy(truths: Array = []) -> void:
	GameState.legacy = {"laurels": 0, "guilds": [], "champions": {}, "truths": truths.duplicate()}
	GameData.LEGACY_CHAMPIONS = GameState.legacy["champions"]


func run() -> void:
	# B2: turning Morrow.
	_fresh_legacy()
	_guild("Treasury Watch")
	GameState.campaign_act = 3
	check(not GameState.morrow_turn_open(), "Morrow can't be bought without knowing who pays him")
	(GameState.legacy["truths"] as Array).append_array(["t_paymaster", "t_key"])
	check(GameState.morrow_turn_open(), "he can once the Treasury's part is known")
	GameState.coins = 100
	check(GameState.turn_morrow() != "", "the bribe has to be paid")
	GameState.coins = 1000
	var n := GameState.heroes.size()
	check(GameState.turn_morrow() == "" and GameState.coins == 1000 - GameData.MORROW_TURN_COST, "Morrow is bought for %d Gold" % GameData.MORROW_TURN_COST)
	var morrow: Hero = GameState.heroes[-1]
	check(GameState.heroes.size() == n + 1 and morrow.name.begins_with("Morrow") and morrow.rank == "S" and morrow.level == GameData.MORROW_HERO_LEVEL, "and joins as a Rank S hero")
	check(float(GameState.wage_raise.get(morrow.id, 0.0)) == 1.0 and GameState.wage_of(morrow) >= 2 * int(GameData.WAGE_BY_RANK["S"]), "on double wages (%d)" % GameState.wage_of(morrow))
	check(not GameState.company_hunting() and GameState.charter_choice == "turn", "the Company stops hunting")
	check(str(GameState.pending_stories[0]["title"]) == "Morrow, turned" and GameState.pending_stories.any(func(c): return str(c.get("kind", "")) == "key"), "a card, and the key on the table")
	var r0 := GameState.rival_renown
	GameState.reputation = 999
	GameState._charter_hearing()
	check(GameState.rival_renown == r0 + GameData.MORROW_TURN_HEARING, "the Crown remembers at its hearing")
	# Miss his pay once and he's gone.
	GameState.coins = 0
	for h in GameState.heroes:
		h.unpaid_weeks = 0
	GameState.run_payday()
	check(not GameState.heroes.has(morrow), "unpaid once, Morrow walks")

	# B4: the key, kept.
	GameState.pending_stories = [GameData.KEY_CHOICE.duplicate(true)]
	GameState.choose_key("keep")
	check(GameState.key_region_open(), "a kept key lets the guild pick the region")
	GameState.chosen_region = "marsh"
	check(GameState.pick_biome(true) == "marsh", "rifts open where it's pointed")
	var breaches_ok := true
	GameState.best_rift_rank_sealed = 2
	for i in 10:
		GameState.breach = {}
		GameState._swell_breach()
		breaches_ok = breaches_ok and int(GameState.breach["rank"]) >= 3
	check(breaches_ok, "and every Riftbreak comes a rank higher")
	GameState.breach = {}
	# ... or broken.
	GameState.branches.erase("key")
	var warn0 := GameState.breach_warn_days()
	var gm0: Array = GameState.hall_cost("grandmaster")
	var rep0 := GameState.reputation
	GameState.pending_stories = [GameData.KEY_CHOICE.duplicate(true)]
	GameState.choose_key("break")
	check(GameState.reputation == rep0 + GameData.KEY_BREAK_RENOWN and GameState.breach_warn_days() == warn0 + 1, "a broken key: Renown, and a day more warning")
	check(int(GameState.hall_cost("grandmaster")[0]) == int(round(int(gm0[0]) * GameData.KEY_HALL_FORCED)) and not GameState.key_region_open(), "the Grandmaster's Hall must be forced, and no regions to pick")

	# B3: the hearing, bought.
	_guild("Bought Charter")
	(GameState.legacy["truths"] as Array).append("t_warden")
	GameState.reputation = 10
	GameState.rival_renown = 50
	var card := GameState._charter_hearing()
	check(str(card.get("kind", "")) == "hearing" and GameState.charter_result == "", "a guild that's losing can bargain")
	GameState.pending_stories = [card]
	GameState.coins = 100
	check(GameState.choose_hearing("buy") != "" and GameState.charter_result == "", "not without the Gold")
	GameState.coins = 2000
	check(GameState.choose_hearing("buy") == "" and GameState.charter_result == "won" and GameState.coins == 2000 - GameData.HEARING_BUY_COST, "the Charter is bought")
	check(absf(GameState.charter_pay(true) - GameData.HEARING_BUY_PAY) < 0.001, "it pays less than an earned one")
	GameState.campaign_act = 5
	GameState.accord_ending = "break"
	var L: Dictionary = GameData.LAURELS
	check(GameState.laurels_earned() == 4 * int(L["act"]) + int(L["ending"]), "and earns no Laurels")
	GameState.campaign_act = 4
	GameState.coins = 1000
	GameState._maybe_audit()
	check(GameState.coins == 800, "the Crown's auditors take a fifth in Act IV")
	GameState._maybe_audit()
	check(GameState.coins == 800, "once")
	_guild("Fair Hearing")
	GameState.reputation = 10
	GameState.rival_renown = 50
	GameState.pending_stories = [GameState._charter_hearing()]
	GameState.choose_hearing("accept")
	check(GameState.charter_result == "lost" and str(GameState.pending_stories[0]["subtitle"]).contains(GameState.rival_name), "accepting the verdict loses the Charter")

	# B6: Ezra's lantern.
	_fresh_legacy(["t_lantern"])
	_guild("Lamp Keepers")
	GameState.campaign_act = 3
	GameState.echoes_seen = ["name", "street"]
	GameState.heroes[0].quirks.append("Echo-Touched")
	GameState.pending_stories = [{"kind": "echo", "echo": "song", "title": "A Song", "text": "", "choices": ["return", "keep"], "essence": 70}]
	GameState.echoes_seen.append("song")
	GameState.answer_echo("keep")
	var ez: Array = GameState.pending_stories.filter(func(c): return str(c.get("kind", "")) == "ezra")
	check(not ez.is_empty(), "Ezra's visit asks, once the lantern's truth is known")
	check(GameState.fragment_known("f_my_lamp") and str(ez[0]["text"]).contains("last apprentice"), "and he says whose lantern it is")
	GameState.pending_stories = ez
	var ess0 := GameState.crystals
	GameState.choose_lantern("pour")
	check(GameState.crystals == maxi(0, ess0 - GameData.LANTERN_PER_ECHO * 3), "pouring costs Essence for every kept echo")
	check(not GameState.heroes[0].quirks.has("Echo-Touched") and GameState.vale_verdict() == "gave", "the touched heroes let go, and the Vale remembers it as giving")
	check(absf(GameState.charter_pay(true) - (1.0 + GameData.LANTERN_ESSENCE)) < 0.001, "contracts pay more Essence")

	# Fragments: one event can carry two.
	_fresh_legacy(["t_lantern"])
	_guild("Ninth Lamp Restorers")
	var both := GameState.lore_event("hall", "ninth_lamp")
	check(GameState.fragment_known("f_lamps_light") and GameState.fragment_known("f_last_finding") and both.contains("\n\n"), "a restored hall can hold two fragments")
	# The Gilded Lance's letters: claims in order, the cousin on its fragment.
	GameState.rival_name = "The Gilded Lance"
	if not GameState.features_seen.has("rival"):   # rival letters come once the rivals have arrived (0.70)
		GameState.features_seen.append("rival")
	GameState.lore_letter_ps()
	GameState.lore_letter_ps()
	GameState.lore_letter_ps()
	check(GameState.claim_heard("aldric_sold") and GameState.fragment_known("f_aldric_cousin") and GameState.claim_heard("aldric_myth"), "Ser Aldric's letters tell his version, cousin and all")
	var status := GameState.claim_status((GameData.WITNESSES.filter(func(w): return w["id"] == "aldric")[0]["claims"] as Array)[1])
	check(status == "open", "his cousin's story stays open until the Warden's truth")
	# Morrow's defeat carries the key's fragment, and offers the key.
	_fresh_legacy(["t_key"])
	_guild("Morrow Hunters")
	GameState.charter_choice = "expose"
	GameState.campaign_act = 3
	check(GameState.lore_event("morrow", "down").contains("turns the wrong way"), "Morrow's key turns the wrong way")

	# The founding options truths open.
	_fresh_legacy()
	GameState.legacy["laurels"] = 100
	check(not GameState.founding_unlocked("rangers") and GameState.unlock_founding("rangers") != "", "Vaelith's Rangers need their truth")
	(GameState.legacy["truths"] as Array).append_array(["t_held_open", "t_sky", "t_key"])
	check(GameState.unlock_founding("rangers") == "" and GameState.founding_unlocked("rangers"), "then they can be bought")
	_guild("Deserters")
	GameState.rival_name = "The Iron Chorus"
	if not GameState.features_seen.has("rival"):   # rival letters come once the rivals have arrived (0.70)
		GameState.features_seen.append("rival")
	var c0 := GameState.coins
	GameState.apply_founding("rangers")
	check(GameState.coins == c0 - 100 and GameState.rival_name != "The Iron Chorus", "the Rangers start leaner, and the Iron Chorus won't race them")
	GameState.refresh_recruit_pool()
	check(GameState.recruit_pool.any(func(h): return h.cls_id == "ranger"), "every board holds a ranger")
	var rh: Hero = GameState.heroes.filter(func(h): return h.cls_id == "ranger")[0] if GameState.heroes.any(func(h): return h.cls_id == "ranger") else Combat.gen_hero("F", 1)
	if rh.cls_id == "ranger":
		check(absf(GameState.charter_role_dmg(rh) - 0.10) < 0.001, "and rangers hit harder")
	check(GameState.breach_warn_days() == GameData.BREACH_WARN + 1, "Riftbreaks warn a day earlier")
	check(GameState.unlock_founding("ninth_lamp") == "", "the Ninth Lamp opens with its truth")
	_guild("Lamplight")
	var y0 := GameState.crystal_yield_bonus()
	GameState.apply_founding("ninth_lamp")
	check(GameState.lvl("res.lab") >= 1 and absf(GameState.crystal_yield_bonus() - y0 * 0.8) < 0.001, "the Lamp starts with the Arcane Lab, and harvests gently")
	var oath: Dictionary = GameData.OATHS["ledger"]
	check(not GameState.lore_option_open(oath), "Sworn to the Ledger needs five truths")
	(GameState.legacy["truths"] as Array).append_array(["t_squad", "t_clerk"])
	check(GameState.lore_option_open(oath), "five open it")
	GameState.oaths = ["ledger"]
	check(GameState.branch_cost(GameData.MORROW_TURN_COST) == int(GameData.MORROW_TURN_COST * GameData.LEDGER_OATH_COST), "and story branches cost half again")
	GameState.oaths = []
	var gift: Dictionary = GameData.LEGACY_GIFTS.filter(func(g): return str(g["id"]) == "pips_key")[0]
	check(GameState.gift_open(gift) and GameState.apply_legacy_gifts(["pips_key"]) == ["pips_key"], "Pip's Key, a founding gift")
	GameState.campaign_act = 2
	check(GameState.key_region_open(), "picks regions in the early acts")
	GameState.campaign_act = GameData.PIPS_KEY_UNTIL_ACT + 1
	check(not GameState.key_region_open(), "until Act III is done")

	_fresh_legacy()
	GameState.save_legacy()
	GameState.delete_slot(9)
