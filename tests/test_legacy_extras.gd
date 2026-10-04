extends "res://tests/base_test.gd"
## The Vale remembers, 5d (heirs, ending hero types, one Bestiary, banner
## colours, grudges, the Hall's records) and the balance pass with it (the
## endowment, lighter tide losses, the Act panel's power advice).


func _guild(name: String) -> void:
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = name
	GameState.hire_starters()
	GameState.pending_stories.clear()


func _legacy(guilds: Array) -> void:
	GameState.legacy = {"laurels": 0, "guilds": guilds.duplicate(true), "champions": {}}
	GameData.LEGACY_CHAMPIONS = GameState.legacy["champions"]


func _offers(n: int) -> Array:
	var out: Array = []
	for i in n:
		GameState.recruit_pool.clear()
		var h := GameState.gen_recruit_offer()
		out.append(h)
	return out


func run() -> void:
	# The endowment: spare Gold for the next guild, a Laurel at a time.
	_legacy([])
	_guild("Endowers")
	GameState.coins = 10000
	check(GameState.endow() != "", "no endowment before the legacy is written")
	GameState.legacy_written = true
	GameState.legacy["guilds"] = [{"name": "Endowers", "laurels": 0}]
	check(GameState.endow() == "" and GameState.coins == 10000 - GameData.ENDOW_COST and int(GameState.legacy["laurels"]) == 1, "one Laurel for %d Gold" % GameData.ENDOW_COST)
	check(GameState.endow_cost() == GameData.ENDOW_COST + GameData.ENDOW_STEP, "the next costs more")

	# A lost tide costs half what a lost Riftbreak does.
	_guild("Tide Losers")
	GameState.accord_ending = "break"
	GameState.coins = 10000
	GameState.crystals = 1000
	GameState.breach = {"rank": 5, "region": "camp", "started": 0, "breaks_on": 0, "broken": true, "tide": 1, "held_before": 0}
	GameState.day = 1
	var out := GameState.resolve_breach({"held": false, "integrity": 0.0, "fallen": []})
	check(absi(int(out["lost_crystals"]) - int(1000 * GameData.TIDE_LOSS_SHARE)) <= 5, "a lost tide takes %d%% of the Essence (%d)" % [int(GameData.TIDE_LOSS_SHARE * 100), int(out["lost_crystals"])])

	# Ending hero types: a past Renew guild sends Accord-Sworn recruits, a Break guild Tide-Hardened ones.
	_legacy([{"name": "Old Keepers", "ending": "renew", "remembered": []}])
	_guild("New Blood")
	var sworn := _offers(80).filter(func(h): return h.quirks.has("Accord-Sworn")).size()
	check(sworn > 3, "a past Renew guild: Accord-Sworn recruits (%d of 80)" % sworn)
	_legacy([{"name": "Old Breakers", "ending": "break", "remembered": []}])
	_guild("Tide Blood")
	var hard := _offers(80).filter(func(h): return h.quirks.has("Tide-Hardened")).size()
	check(hard > 3 and _offers(40).all(func(h): return not h.quirks.has("Accord-Sworn")), "a past Break guild: Tide-Hardened ones (%d of 80)" % hard)
	_legacy([{"name": "New Blood", "ending": "renew", "remembered": []}])
	_guild("New Blood")
	check(_offers(80).all(func(h): return not h.quirks.has("Accord-Sworn")), "a guild's own ending doesn't count for itself")

	# Heirs.
	_legacy([{"name": "Pocket Crows", "ending": "renew", "remembered": ["Oren"]}])
	_guild("Heirs")
	var heirs := 0
	for i in 200:
		GameState.recruit_pool.clear()
		var h := GameState.gen_recruit_offer()
		if h.history.has("heir_of"):
			heirs += 1
			check(str(h.history["heir_of"]) == "Oren of Pocket Crows" and h.quirks.has("Heir"), "an heir knows their parent: %s" % str(h.history["heir_of"]))
			break
	check(heirs == 1, "remembered heroes have children who come to the recruit board")
	GameState.recruit_pool.clear()
	var first_heir := GameState.gen_recruit_offer()
	first_heir.history["heir_of"] = "Oren of Pocket Crows"
	GameState.recruit_pool.append(first_heir)
	var more := 0
	for i in 100:
		more += 1 if GameState.gen_recruit_offer().history.has("heir_of") else 0
	check(more == 0, "one heir on the board at a time")

	# One Bestiary across every guild.
	_legacy([])
	_guild("Hunters")
	GameState.monsters_seen = ["Hedge Warden"]
	GameState.bosses_defeated = ["Vaelith"]
	GameState.campaign_act = 5
	GameState.accord_ending = "renew"
	GameState.write_legacy([])
	_guild("Hunters II")
	check(GameState.bestiary_seen("Hedge Warden") and not GameState.monsters_seen.has("Hedge Warden"), "a later guild's Bestiary knows what a past one met")
	check((GameState.legacy.get("beaten", []) as Array).has("Vaelith"), "and which wardens fell")

	# Banner colours, earned in the Hall.
	_legacy([])
	check(GameState.banner_colour_open("crest") and not GameState.banner_colour_open("keeper"), "only the crest's own colour at first")
	_legacy([{"name": "Gold Guild", "ending": "renew", "oaths": ["a", "b", "c"]}])
	check(GameState.banner_colour_open("keeper") and GameState.banner_colour_open("oath") and not GameState.banner_colour_open("hollow"), "Renew and three oaths open their colours")
	check(GameState.banner_cloth("keeper", 1) == Color(str(GameData.BANNER_COLOURS["keeper"]["color"])), "and the banner wears it")

	# A rival with a grudge.
	_legacy([{"name": "Charter Winners", "rival": "The Gilded Lance", "beat_rival": true}])
	_guild("Grudge Match")
	GameState.rival_name = "The Gilded Lance"
	GameState.apply_founding("free")
	check(GameState.grudge == "Charter Winners", "the Lance remembers who beat it")
	GameState.campaign_act = 5
	GameState.accord_ending = "break"
	GameState.charter_result = "won"
	var L: Dictionary = GameData.LAURELS
	check(GameState.laurels_earned() == 4 * int(L["act"]) + int(L["ending"]) + int(L["charter"]) + GameData.GRUDGE_LAURELS, "beating it again is worth %d Laurels more" % GameData.GRUDGE_LAURELS)
	_guild("No Grudge")
	GameState.rival_name = "The Iron Chorus"
	GameState.apply_founding("free")
	check(GameState.grudge == "", "a rival no guild beat holds none")

	# The Act panel's advice: concrete, costed, and it works.
	_legacy([])
	_guild("Advised")
	var h0: Hero = GameState.heroes[0]
	while h0.level < 10:
		Combat.gain_xp(h0, Combat.xp_to_next(h0.level))
	GameState.crystals = 5000
	var tips: Array = GameState.power_advice()
	check(not tips.is_empty() and str(tips[0]["kind"]) == "evolve" and str(tips[0]["text"]).contains("Essence"), "a level-10 hero and spare Essence: evolve (%s)" % (str(tips[0]["text"]) if not tips.is_empty() else "none"))
	var r0 := h0.rank
	check(GameState.follow_advice(tips[0]) == "" and h0.rank != r0, "and following it evolves them")
	GameState.delete_slot(9)
