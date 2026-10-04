extends "res://tests/base_test.gd"
## The Unwritten Accord (the story web across guilds): fragments, truths,
## witnesses' claims, and Phase 1's branches (B1 let Vaelith go, B5 Hesper
## signs) with their prices.


func _guild(name: String) -> void:
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = name
	GameState.hire_starters()
	GameState.pending_stories.clear()
	GameState.pending_toasts.clear()


func _fresh_legacy() -> void:
	GameState.legacy = {"laurels": 0, "guilds": [], "champions": {}}
	GameData.LEGACY_CHAMPIONS = GameState.legacy["champions"]


func run() -> void:
	_fresh_legacy()
	_guild("Thornwood Lamps")

	# The data: every fragment short, every truth reachable more than one way.
	var long: Array = []
	for id in GameData.FRAGMENTS:
		if GameState.fragment_text(id).split(" ", false).size() > GameData.FRAGMENT_MAX_WORDS:
			long.append(id)
	check(long.is_empty(), "no fragment is over %d words %s" % [GameData.FRAGMENT_MAX_WORDS, long])
	var thin: Array = GameData.TRUTHS.keys().filter(func(t): return GameData.FRAGMENTS.values().filter(func(f): return str(f["truth"]) == t).size() < GameData.TRUTH_NEEDS + 1)
	check(thin.is_empty(), "every truth has more fragments than it needs %s" % [thin])
	check(GameData.FRAGMENTS.values().all(func(f): return GameData.TRUTHS.has(str(f["truth"]))), "every fragment belongs to a truth")

	# Gates: region and rank.
	check(GameState.lore_gate(GameData.FRAGMENTS["f_corin"], {"region": "vale", "rank": 0}) and not GameState.lore_gate(GameData.FRAGMENTS["f_corin"], {"region": "marsh", "rank": 0}),
		"a ranger's tag turns up only in the Vale")
	check(not GameState.lore_gate(GameData.FRAGMENTS["f_mags"], {"region": "vale", "rank": 0}) and GameState.lore_gate(GameData.FRAGMENTS["f_mags"], {"region": "vale", "rank": GameData.rift_rank_index("D")}),
		"the second only from Rank D")

	# A seal turns one up (the pity rule makes it certain), riding on a relic.
	var relics_before := GameState.relics.size()
	GameState.lore_dry = GameData.LORE_PITY
	var got := GameState.lore_on_seal("vale", 0)
	check(got == "f_corin" and GameState.fragment_known("f_corin"), "a Vale seal turns up Corin's tag")
	check(GameState.relics.size() == relics_before + 1 and GameState.relics[-1].lore == "f_corin" and GameState.relics[-1].name == "Corin's Tag", "on a relic that carries it")
	check(GameState.pending_toasts.any(func(t): return str(t["title"]).contains("Corin")), "with a toast")
	check(not GameState.truth_known("t_squad"), "one fragment isn't a truth yet")
	GameState.lore_dry = 0
	check(GameState.lore_on_seal("marsh", 0) == "", "nothing in the Marshes for this guild yet")
	check(GameState.lore_dry == 0, "and a seal with nothing to find doesn't count toward the pity")

	# The echo carries the second, and the truth assembles.
	GameState.pending_stories.append({"kind": "echo", "echo": "face", "title": "A Face", "text": "", "choices": ["return", "keep"], "essence": 50})
	GameState.answer_echo("return")
	check(GameState.fragment_known("f_face") and GameState.truth_known("t_squad"), "giving back the face finds its squad mark, and the first truth")
	check(str(GameState.pending_stories[0]["text"]).contains("four notches"), "on the echo's own card")

	# Pay-table fragments wait for their truth, then turn up.
	var scene := ""
	for i in 40:
		scene = GameState.lore_payday_scene("quiet1")
		if scene != "":
			break
	check(scene == "lore:f_two_sides" and GameState.fragment_known("f_two_sides"), "a payday tells what Vaelith asked Hesper")
	check(GameState.payday_scene_lines(scene).size() == 3, "as a scene at the pay table")
	check(GameState.lore_payday_scene(scene) == "", "never two story paydays in a row")

	# The rival's letters: Orla Venn's claims, one per letter, and her fragment.
	GameState.rival_name = "The Iron Chorus"
	var ps1 := GameState.lore_letter_ps()
	check(GameState.claim_heard("orla_attack") and ps1.contains("came for the Vale"), "the Chorus's first letter says the Hollow attacked")
	var ps2 := GameState.lore_letter_ps()
	check(GameState.fragment_known("f_orla_deserter") and GameState.claim_heard("orla_deserter") and ps2.contains("deserter"), "the second calls Vaelith a deserter")
	check(GameState.truth_known("t_why_left"), "and that makes the second truth: she heard children")
	var deserter: Dictionary = (GameData.WITNESSES[2]["claims"] as Array)[1]
	check(GameState.claim_status(deserter) == "struck", "which strikes Orla's claim through")
	check(GameState.claim_status((GameData.WITNESSES[2]["claims"] as Array)[0]) == "open", "while 'the Hollow attacked' stays open")

	# B1: Act I's finale asks, before its outro.
	check(GameState.vaelith_open(), "a guild that knows why Vaelith left can let her go")
	GameState.pending_stories.clear()
	GameState.campaign_act = 1
	var ess0 := GameState.crystals
	var rel0 := GameState.relics.size()
	GameState._complete_act(1)
	check(str(GameState.pending_stories[0].get("kind", "")) == "vaelith", "the finale opens on the choice")
	check(int(GameState.pending_stories[1].get("act_outro", 0)) == 1, "before the act's outro")
	var renown0 := GameState.rival_renown
	GameState.choose_vaelith("spare")
	check(GameState.relics.size() == rel0 and GameState.crystals == ess0 + 80 - GameData.VAELITH_SPARE_ESSENCE, "letting her go: no finale relic, half its Essence")
	check(GameState.champion_unlocked("vaelith") and str(GameData.champion_def("vaelith")["role"]) == "ranger", "she joins as a champion")
	check(ResourceLoader.exists(GameData.champion_portrait("vaelith")), "with her own portrait")
	check(GameState.rival_renown == renown0 + GameData.VAELITH_CHORUS_RENOWN, "the Iron Chorus calls it harbouring a deserter")
	check(str(GameState.pending_stories[0]["title"]) == "Let go", "a card says what happened")
	var outro: Array = GameState.pending_stories.filter(func(c): return int(c.get("act_outro", 0)) == 1)
	check(not outro.is_empty() and str(outro[0]["text"]) == GameData.VAELITH_SPARED_OUTRO, "and the outro tells it her way")
	check(not GameState.vaelith_open(), "a guild lets her go once")
	GameState.campaign_act = 4
	var spared_power := GameState.finale_recommended_power()
	GameState.branches.erase("vaelith")
	var full_power := GameState.finale_recommended_power()
	check(spared_power < full_power and absf(float(spared_power) / full_power - (1.0 - GameData.VAELITH_FINALE_CUT)) < 0.01, "Act IV's finale is %d%% weaker (%d vs %d)" % [int(GameData.VAELITH_FINALE_CUT * 100), spared_power, full_power])
	GameState.branches["vaelith"] = "spared"

	# The veteran start never asks.
	_guild("Quick Start")
	GameState._veteran_start()
	check(not GameState.pending_stories.any(func(c): return str(c.get("kind", "")) == "vaelith"), "the veteran start finishes Act I without the choice")

	# The record: the branch and the fragments go into the Hall of Guilds.
	_guild("Thornwood Lamps II")
	GameState.branches["vaelith"] = "spared"
	GameState.lore_found_here = ["f_corin", "f_face"]
	GameState.campaign_act = 5
	GameState.accord_ending = "break"
	GameState.write_legacy([])
	var rec: Dictionary = (GameState.legacy["guilds"] as Array)[-1]
	check(str((rec.get("branches", {}) as Dictionary).get("vaelith", "")) == "spared" and int(rec.get("fragments", 0)) == 2, "the Hall remembers she was let go")
	check(GameState._hall_has("spared_vaelith") and GameState.lore_gate(GameData.FRAGMENTS["f_footprints"], {"region": "vale"}), "which opens the footprints for later guilds")

	# B5: Hesper signs.
	_guild("Green Ink")
	check(not GameState.hesper_can_sign(), "Hesper can't sign before the truth about the blank line")
	(GameState.legacy["truths"] as Array).append("t_blank_line")
	check(GameState.hesper_can_sign(), "she can once it's known")
	GameState.campaign_act = 5
	var n_heroes := GameState.heroes.size()
	check(GameState.choose_accord_ending("renew", "hesper") == "", "the Accord renewed, in Hesper's hand")
	check(GameState.heroes.size() == n_heroes and GameState.accord_hero == "Hesper" and GameState.hesper_posted(), "every hero stays; Hesper holds the post")
	check(GameState.breach.is_empty() and GameState.breach_next_day == -1, "Riftbreaks end as with any renewal")
	GameState.write_legacy([])
	check(GameState.legacy["champions"].has("legacy_hesper") and bool(GameState.legacy["champions"]["legacy_hesper"]["post"]), "she waits in later guilds as the forty-first post's champion")
	check(GameState.payday_scene_lines("first").all(func(l): return str(l[0]) != "Hesper") and not GameState._scene_ok("quiet1"), "and is gone from the pay table")
	check(not GameState.founding_unlocked("accord"), "her own charter waits for her")
	check(not GameState.hesper_can_sign(), "she can only sign once")
	check(GameState._sky_beneath_card()["text"].contains("Wen reads it twice"), "Book II opens without her")

	_guild("After Hesper")
	check(GameState.champion_roll.has("legacy_hesper"), "a later guild finds her among its lost champions")
	GameState.legacy["line"] = 1
	GameState._find_line_piece()
	check(str(GameState.pending_stories[-1]["subtitle"]) == "A letter from the forty-first post" and str(GameState.pending_stories[-1]["text"]).contains("green ink"), "her part of the forty-second line comes as a letter")
	# A rewrite brings her home.
	GameState.legacy["line"] = 3
	GameState.legacy["guilds"] = [{"name": "Kept", "ending": "renew"}, {"name": "Burned", "ending": "break"}]
	GameState.campaign_act = 5
	check(GameState.choose_accord_ending("rewrite") == "", "the Terms rewritten")
	check(not GameState.hesper_posted() and not GameState.legacy["champions"].has("legacy_hesper"), "and Hesper climbs out with you")
	check(str(GameState.pending_stories.filter(func(c): return str(c.get("title", "")) == "The Terms rewritten")[0]["text"]).contains("climbs out"), "as the ending says")

	# The Clerk's Copy: a founding gift a truth opens.
	_fresh_legacy()
	_guild("Clerks")
	GameState.legacy["laurels"] = 20
	var copy: Dictionary = GameData.LEGACY_GIFTS.filter(func(g): return str(g["id"]) == "clerks_copy")[0]
	check(not GameState.gift_open(copy) and GameState.apply_legacy_gifts(["clerks_copy"]).is_empty(), "the Clerk's Copy needs its truth")
	(GameState.legacy["truths"] as Array).append("t_blank_line")
	check(GameState.apply_legacy_gifts(["clerks_copy"]) == ["clerks_copy"] and GameState.accord_pages == 2, "then starts the guild with two ledger pages")
	check(GameState.claim_heard("ledger_voice"), "and the ledger's first claim")

	# Found things travel with a save transfer, and a guild's branches save.
	GameState.merge_legacy({"guilds": [], "fragments": ["f_mags"], "truths": ["t_clerk"], "claims": ["orla_crown"]})
	check(GameState.fragment_known("f_mags") and GameState.truth_known("t_clerk") and GameState.claim_heard("orla_crown"), "another device's fragments, truths and claims merge in")
	GameState.branches = {"vaelith": "spared"}
	GameState.lore_found_here = ["f_mags"]
	GameState.lore_dry = 3
	GameState.save()
	check(GameState.load_save() and str(GameState.branches.get("vaelith", "")) == "spared" and GameState.lore_found_here == ["f_mags"] and GameState.lore_dry == 3, "branches and found fragments save")

	_fresh_legacy()
	GameState.save_legacy()
	GameState.delete_slot(9)
