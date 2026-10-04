extends "res://tests/base_test.gd"
## The Spire, falling (B10: the archive or Hollin, at Act II's finale) and the
## payoffs (0.46): choices a guild made coming back later in the story.


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


func _crossing() -> Dictionary:
	for i in 60:
		GameState.pending_stories.clear()
		GameState.maybe_crossing()
		if not GameState.pending_stories.is_empty():
			return GameState.pending_stories[0]
	return {}


func _card(title: String) -> Dictionary:
	var c: Array = GameState.pending_stories.filter(func(x): return str(x.get("title", "")) == title)
	return c[0] if not c.is_empty() else {}


func run() -> void:
	# A first guild meets it: Act II's finale asks before its outro.
	_fresh_legacy()
	_guild("Archivists")
	GameState.campaign_act = 2
	GameState._complete_act(2)
	check(str(GameState.pending_stories[0].get("kind", "")) == "spire", "Act II's finale opens on the Spire, with no truth known")
	check(int(GameState.pending_stories[1].get("act_outro", 0)) == 2, "before the act's outro")
	GameState.reputation = 20
	GameState.choose_spire("archive")
	check(GameState.reputation == 20 - GameData.SPIRE_ARCHIVE_RENOWN and str(GameState.branches["spire"]) == "archive", "the archive: Hollin floods (-%d Renown)" % GameData.SPIRE_ARCHIVE_RENOWN)
	check(str(GameState.pending_stories[0]["title"]) == "The archive, carried out" and str(GameState.pending_stories[0]["text"]).contains("pen went through"), "a card says so, with the copyists' index")
	check(GameState.fragment_known("f_copyists"), "the fragment is kept")
	var outro: Array = GameState.pending_stories.filter(func(c): return int(c.get("act_outro", 0)) == 2)
	check(not outro.is_empty() and str(outro[0]["text"]) == GameData.SPIRE_ARCHIVE_OUTRO, "the outro tells it the archive's way")
	check(is_equal_approx(GameState.spire_finds(), GameData.SPIRE_ARCHIVE_FINDS), "pages and fragments turn up half again as often")
	var intro4 := GameState._act_intro_card(4)
	check(str(intro4["text"]).contains("clause by clause"), "Act IV's intro remembers the archive")
	GameState.campaign_act = 4
	var cut_power := GameState.finale_recommended_power()
	GameState.branches["vaelith"] = "spared"
	var both_power := GameState.finale_recommended_power()
	GameState.branches.erase("spire")
	GameState.branches.erase("vaelith")
	var full_power := GameState.finale_recommended_power()
	check(absf(float(cut_power) / full_power - (1.0 - GameData.SPIRE_TERMS_CUT)) < 0.01, "Act IV's finale is %d%% weaker (%d vs %d)" % [int(GameData.SPIRE_TERMS_CUT * 100), cut_power, full_power])
	check(absf(float(both_power) / full_power - (1.0 - GameData.SPIRE_TERMS_CUT - GameData.VAELITH_FINALE_CUT)) < 0.01, "and stacks with Vaelith's cut")
	check(not str(GameState._act_intro_card(4)["text"]).contains("clause by clause"), "a guild without the archive gets the plain intro")
	GameState.branches["spire"] = "archive"
	GameState.campaign_act = 2
	GameState.pending_stories.clear()
	GameState._complete_act(2)
	check(not GameState.pending_stories.any(func(c): return str(c.get("kind", "")) == "spire"), "a guild answers once")

	# The pay table, once.
	GameState.branches.erase("spire_scene")
	GameState.coins = 0   # not a "rich" week
	var s1 := GameState._payday_scene({"scene": "quiet1"}, [], [], GameState.rival_ahead)
	var s2 := GameState._payday_scene({"scene": s1}, [], [], GameState.rival_ahead)
	check(s1 == "spire_archive" and s2 != "spire_archive", "the next payday tells of the archive, once (%s, %s)" % [s1, s2])

	# Hollin: Renown now, and Book II's crossings cost none.
	_fresh_legacy()
	_guild("Millers")
	GameState.campaign_act = 2
	GameState._complete_act(2)
	GameState.reputation = 20
	GameState.choose_spire("hollin")
	check(GameState.reputation == 20 + GameData.SPIRE_HOLLIN_RENOWN, "Hollin: +%d Renown" % GameData.SPIRE_HOLLIN_RENOWN)
	check(GameState.fragment_known("f_mill_wheel") and str(GameState.pending_stories[0]["text"]).contains("mill wheel"), "and the miller remembers the Night")
	var outro2: Array = GameState.pending_stories.filter(func(c): return int(c.get("act_outro", 0)) == 2)
	check(str(outro2[0]["text"]) == str(GameData.CAMPAIGN[1]["outro"]), "the outro is the usual one")
	check(is_equal_approx(GameState.spire_finds(), 1.0) and GameState.crossing_renown() == 0, "no faster finds; crossings cost no Renown")
	GameState.campaign_act = 5
	GameState.accord_ending = "break"
	GameState.run = {"biome": "glass"}
	var first := _crossing()
	check(str(first.get("text", "")).contains("Hollin will take them in"), "the first crossing says so")
	var rep0 := GameState.reputation
	GameState.answer_crossing("through")
	check(GameState.reputation == rep0, "and letting them through costs nothing")
	GameState.pending_stories.clear()
	check(not str(_crossing().get("text", "")).contains("Hollin will take"), "only the first card says it")

	# The Royal Charter in Book II: double the bounty, and a line in Act V.
	_fresh_legacy()
	_guild("Charter Holders")
	GameState.charter_result = "won"
	check(GameState.crossing_bounty() == GameData.CROSSING_BOUNTY * GameData.CHARTER_BOUNTY_MULT, "holding the Charter: the bounty is doubled")
	check(str(GameState._act_intro_card(5)["text"]).contains("Crown's seal follows you down"), "Act V's intro says so")
	GameState.charter_result = "lost"
	GameState.rival_name = "The Gilded Lance"
	check(GameState.crossing_bounty() == GameData.CROSSING_BOUNTY and str(GameState._act_intro_card(5)["text"]).contains("The Gilded Lance holds the Charter"), "the rival holding it: the usual bounty, and they're sent down too")
	GameState.legacy["epilogue"] = "read"
	check(not str(GameState._act_intro_card(5)["text"]).contains("holds the Charter"), "after the Moot there is no Crown's Charter to speak of")
	GameState.legacy.erase("epilogue")

	# Keeping quiet: Morrow's money pays for the climb down.
	GameState.charter_choice = "quiet"
	GameState.accord_ending = "break"
	check(str(GameState._sky_beneath_card()["text"]).contains("Hesper does"), "the Sky Beneath remembers the quiet arrangement")
	GameState.legacy["hesper_posted"] = true
	check(str(GameState._sky_beneath_card()["text"]).contains("Wen writes it down anyway"), "with Hesper at the post, Wen tells it")
	GameState.legacy["hesper_posted"] = false

	# Vaelith at the family's door; the poured lantern at the Choir's.
	_guild("Door Openers")
	GameState.campaign_act = 5
	GameState.accord_ending = "break"
	GameState.run = {"biome": "glass"}
	GameState.branches = {"vaelith": "spared", "lantern": "poured"}
	GameState.unlock_champion("vaelith")
	GameState.crossings_answered = 0
	check(str(_crossing().get("text", "")).contains("runs to her"), "Vaelith comes to the family's door")
	GameState.crossings_answered = 2
	check(str(_crossing().get("text", "")).contains("some of theirs are home"), "the Choir hears where their voices went")

	# Book II's ending: the crossings let through, and Brannoch.
	_guild("Sky Keepers")
	GameState.campaign_act = 7
	GameState.crossings_through = 0
	GameState.branches = {"brannoch": "left"}
	GameState.choose_sky_ending("both")
	var both := _card("Both worlds")
	check(str(both.get("text", "")).contains("empty shore") and str(both["text"]).contains("sets down a door"), "both worlds, none let through, Brannoch left: both lines")
	check(str(both["text"]).ends_with(")"), "and the lines come before the closing note")
	_guild("Door Closers")
	GameState.campaign_act = 7
	GameState.crossings_through = 2
	GameState.branches = {"brannoch": "freed"}
	GameState.choose_sky_ending("ours")
	var ours := _card("Ours")
	check(str(ours.get("text", "")).contains("watch from the cliff") and str(ours["text"]).contains("top of the cords"), "ours, two let through, Brannoch freed")

	# The epilogue: who is in the square.
	_fresh_legacy(GameData.EPILOGUE_TRUTHS)
	_guild("Readers")
	GameState.campaign_act = 7
	GameState.charter_choice = "expose"
	var m := GameState.heroes[0]
	m.history["morrow"] = 1
	GameState.choose_sky_ending("both")
	var ep: Array = GameState.pending_stories.filter(func(c): return str(c.get("kind", "")) == "epilogue")
	check(not ep.is_empty() and str(ep[0]["text"]).contains("Mother Ilse") and str(ep[0]["text"]).contains("Someone always pays"), "Ilse and Morrow are in the square")

	# Later guilds: the Hall remembers what a past guild chose.
	_fresh_legacy([], [{"name": "Old Millers", "ending": "renew", "quiet": true, "branches": {"spire": "hollin", "vaelith": "spared"}}])
	_guild("Heirs of the Mill")
	var fits: Array = GameState._past_pick()["scenes"]
	check(fits.has("past_hollin") and fits.has("past_quiet") and fits.has("past_vaelith") and not fits.has("past_archive"), "the pay table can turn to what Old Millers chose")
	GameState.legacy["hesper_posted"] = true
	check(not GameState._scene_ok("past_quiet") and GameState._scene_ok("past_hollin"), "the ones with Hesper in them wait while she holds the post")
	GameState.legacy["hesper_posted"] = false
	GameState.delete_slot(9)
