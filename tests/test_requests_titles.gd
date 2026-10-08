extends "res://tests/base_test.gd"
## 0.66: 30 camp events (15 written as data), 25 hero requests (20 as data,
## each for the heroes it fits), titles for deeds, renaming a hero, and the
## Resolve a blessing at camp gives the next party.


func _hero(role: String, path: String) -> Hero:
	var h := Combat.gen_hero("C", 6)
	h.cls_id = role
	h.pool_id = role
	h.path = path
	h.id = "h%d" % GameState.next_id
	GameState.next_id += 1
	Combat.refresh_stats(h)
	h.hp = Combat.max_hp(h)
	GameState.heroes.append(h)
	return h


func run() -> void:
	seed(66)
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "T"
	GameState.rival_name = "The Ashen Hand"
	var mage := _hero("mage", "evocation")
	var war := _hero("warrior", "shieldwall")
	var war2 := _hero("warrior", "")
	var cler := _hero("cleric", "aegis")
	GameState.campaign_act = 6
	GameState.coins = 5000
	GameState.crystals = 500

	check(GameData.CAMP_EVENTS.size() >= 30 and GameData.HERO_REQUESTS.size() >= 25, "30 camp events, 25 hero requests (%d, %d)" % [GameData.CAMP_EVENTS.size(), GameData.HERO_REQUESTS.size()])

	# Every request reads cleanly (two names where it has two).
	var clean := true
	for t in GameData.HERO_REQUESTS:
		GameState.hero_request = {"type": t, "ids": [mage.id, war.id], "day": GameState.day}
		var o: Array = GameState.request_options()
		clean = clean and GameState.request_title() != "" and GameState.request_text() != "" and o.size() == 2 and not str(o[0]).contains("%s") and not str(o[0]).contains("%d") and not GameState.request_title().contains("%s")
	check(clean, "every request's title, text and answers fill in")
	GameState.hero_request = {}

	# Who can ask.
	var pool: Array = [mage, war, war2, cler]
	check(GameState._request_heroes("flashpoint", pool) == [mage.id], "only an Evocation hero wants to test a spell")
	check(GameState._request_heroes("relics_study", [war, cler]).is_empty(), "no mage, no relic study")
	check((GameState._request_heroes("sparring", pool) as Array).size() == 2, "sparring pairs two heroes of a role")

	# Answers.
	var c0 := GameState.coins
	var m0 := mage.morale
	GameState.hero_request = {"type": "flashpoint", "ids": [mage.id], "day": GameState.day}
	check(GameState.answer_request(true) == "" and GameState.coins == c0 - 40 and mage.morale > m0, "a granted request costs its Gold and lifts morale")
	war.quirks.append("Haunted")
	GameState.hero_request = {"type": "memorial", "ids": [war.id], "day": GameState.day}
	GameState.answer_request(true)
	check(war.quirks.has("Steady Nerves") and war.busy_runs >= 1, "the memorial visit leaves a quirk")
	GameState.hero_request = {"type": "song", "ids": [cler.id], "day": GameState.day}
	GameState.answer_request(true)
	check(cler.titles.has("the Songmaker") and GameState.hero_title(cler) != "", "the song gives a title")
	GameState.coins = 0
	GameState.hero_request = {"type": "homesick", "ids": [war2.id], "day": GameState.day}
	check(GameState.request_blocked() != "" and GameState.answer_request(true) != "", "no Gold, no money sent home")
	GameState.coins = 5000

	# Camp events written as data.
	var ok := true
	for id in GameData.CAMP_EVENTS:
		var ev: Dictionary = GameData.CAMP_EVENTS[id]
		if not ev.has("opts"):
			continue
		GameState.camp_event = {"id": id, "day": GameState.day, "data": {}}
		ok = ok and GameState.camp_event_options().size() == (ev["opts"] as Array).size() and GameState.camp_event_text() != ""
	check(ok, "every data event lists its options")
	GameState.next_resolve = 0
	GameState.camp_event = {"id": "chaplain", "day": GameState.day, "data": {}}
	check(GameState.answer_camp_event(0) == "" and GameState.next_resolve == 3 and GameState.camp_event.is_empty(), "the chaplain's blessing waits for the next party")
	GameState.camp_event = {"id": "lost_child", "day": GameState.day, "data": {}}
	var r0 := GameState.reputation
	GameState.answer_camp_event(0)
	check(GameState.reputation > r0 and GameState.heroes.any(func(h): return h.busy_runs > 0), "sending a hero after the child: they're busy, Renown rises")

	# The blessing reaches the next party.
	GameState.runs_started = 5
	GameState.rifts_sealed = 5
	for h in GameState.heroes:
		h.busy_runs = 0
	var ids: Array[String] = [mage.id, war.id, war2.id, cler.id]
	GameState.start_ladder_rift("C", ids, null)
	check(GameState.resolve_now() == mini(GameData.RESOLVE_START + 3, GameData.RESOLVE_MAX) and GameState.next_resolve == 0, "the next party sets out with the extra Resolve (%d, %d left, run %s)" % [GameState.resolve_now(), GameState.next_resolve, str(not GameState.run.is_empty())])
	GameState.run = {}

	# Titles for deeds; renaming.
	mage.history["boss_kills"] = 5
	var lines := GameState.check_titles(mage)
	check(mage.titles.has("Kingslayer") and lines.size() >= 1, "five bosses make a Kingslayer")
	check(GameState.rename_hero(mage.id, "Ysra") == "" and mage.name.begins_with("Ysra the "), "a hero can be renamed (the class part stays)")
	check(GameState.rename_hero(mage.id, "X") != "" and GameState.rename_hero(mage.id, "Bob the Great") != "", "too short or with ' the ' is refused")
	GameState.save()
	GameState.load_save()
	var back := GameState.find_hero(mage.id)
	check(back.titles.has("Kingslayer") and back.name.begins_with("Ysra"), "titles and the new name survive a save")
