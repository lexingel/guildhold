extends "res://tests/base_test.gd"
## The Training Yard (0.58), reset unequipping, new-guild recovery.

func run() -> void:
	seed(5)
	GameState.active_slot = 9
	GameState.reset()
	var h := Combat.gen_hero("D", 6)
	h.id = "h1"
	GameState.active_slot = 9
	GameState.guild_name = "T"
	GameState.heroes.clear()
	GameState.heroes.append(h)
	GameState.upgrades = {}
	var b := Combat.gen_hero("D", 6)
	b.id = "h2"
	var c2 := Combat.gen_hero("D", 6)
	c2.id = "h3"
	GameState.heroes.append(b)
	GameState.heroes.append(c2)
	check(GameState.training_slots() == GameData.TRAIN_SLOTS_BY_TIER[0], "%d stations to start" % GameData.TRAIN_SLOTS_BY_TIER[0])
	GameState.upgrades = {"ops.drill": 5}
	check(GameState.training_slots() == GameData.TRAIN_SLOTS_BY_TIER[2], "%d at the yard's top tier" % GameData.TRAIN_SLOTS_BY_TIER[2])
	GameState.upgrades = {}
	var fee := GameState.train_fee(h, 3)
	GameState.coins = fee - 1
	check(GameState.start_training("h1", "might", 3) == "Not enough Gold", "the fee is paid up front")
	GameState.coins = 10000
	var m0 := int(h.attrs["might"])
	check(GameState.start_training("h1", "might", 3) == "" and GameState.coins == 10000 - fee and not h.is_available(), "a 3-day Might course: paid, and the hero sits out runs")
	check(GameState.start_training("h2", "focus", 1) == "" and GameState.start_training("h3", "agility", 1) == "Every station is taken", "two stations, both in use")
	b.level = 9
	var lv0 := h.level
	GameState.pass_time()
	check(int(h.attrs["might"]) == m0 + 1 and h.attr_trained == 1 and (h.level > lv0 or h.xp > 0), "a day: +1 Might and some XP")
	check(b.training.is_empty() and b.attr_trained == 1, "a 1-day course ends after a day")
	var back0 := Hero.from_dict(JSON.parse_string(JSON.stringify(h.to_dict())))
	check(int(back0.training.get("left", 0)) == 2, "a course in progress is saved")
	var c0 := GameState.coins
	var refund := GameState.recall_training("h1")
	check(refund == fee / 3 and GameState.coins == c0 + refund and h.training.is_empty() and h.is_available(), "recalled with 2 days left: the day under way is lost, the last one refunded (%d)" % refund)
	# End day (0.59): the preview says who finishes tomorrow and what payday asks; resting passes a day.
	GameState.start_training("h2", "focus", 1)
	GameState.day = GameData.PAYDAY_DAYS - 1
	GameState.coins = 0
	var pv := GameState.day_preview()
	check(pv.any(func(l): return l.contains(b.name.split(" the ")[0])) and pv.any(func(l): return l.contains("short")), "End day's preview: %s" % str(pv))
	GameState.rest_guild()
	check(GameState.day == GameData.PAYDAY_DAYS and b.training.is_empty(), "resting ends the day")
	GameState.coins = 10000
	# The cap: past ATTR_TRAIN_CAP trained points a course gives XP only.
	h.attr_trained = GameData.ATTR_TRAIN_CAP
	var m1 := int(h.attrs["might"])
	GameState.start_training("h1", "might", 2)
	GameState.pass_time()
	check(int(h.attrs["might"]) == m1, "capped at %d trained points" % GameData.ATTR_TRAIN_CAP)
	# XP never takes a hero past the guild's best.
	GameState.recall_training("h1")
	b.level = h.level
	var xp0 := h.xp
	GameState.start_training("h1", "might", 2)
	GameState.pass_time()
	check(h.xp == xp0, "no XP once level with the best hero")
	GameState.recall_training("h1")
	var back := Hero.from_dict(JSON.parse_string(JSON.stringify(h.to_dict())))
	check(back.attr_trained == h.attr_trained, "attr_trained saved")
	# Reset unequips gear that no longer qualifies.
	GameState.auto_assign_attrs("h1")
	var it := Combat.gen_item("epic", "weapon")
	it.id = "i1"
	GameState.items.append(it)
	h.attrs[it.attr] = 20
	GameState.equip_item("h1", "weapon", 0, "i1")
	check(it.equipped_to == "h1", "epic equipped at 20 %s" % it.attr)
	GameState.crystals = 200
	GameState.respec_attrs("h1")
	check(it.equipped_to == "", "reset takes off gear the hero no longer qualifies for")
	check(GameState.recovery_runs() == 1, "new guild recovers in 1 run")
	GameState.rifts_sealed = 3
	check(GameState.recovery_runs() == GameData.DOWNED_RECOVERY_RUNS, "after 3 seals: normal recovery")
	GameState.coins = 300
