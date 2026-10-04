extends "res://tests/base_test.gd"
## Book II, the Sky Beneath: Acts V and VI after the Accord's ending, the
## regions, crossings, the City's gate and the both-worlds or ours ending.


func run() -> void:
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "Far Shore"
	GameState.hire_starters()
	GameState.roll_champions()
	GameState.legacy = {"laurels": 0, "guilds": [], "champions": {}}

	# Book II waits for the Accord's ending, then opens with Act V.
	GameState.campaign_act = 5
	check(GameState.current_act().is_empty() and GameState.book2_regions().is_empty(), "nothing of Book II before the ending")
	check(GameState.choose_accord_ending("break") == "" and int(GameState.current_act().get("act", 0)) == 5, "after the ending: Act V, the Glass Coast")
	check(GameState.pending_stories.any(func(c): return str(c.get("title", "")) == "The Sky Beneath"), "the reply on the ledger's last page")
	check(GameState.book2_regions().has("glass") and not GameState.book2_regions().has("city"), "the Glass Coast joins the rifts; the City waits")
	GameState.write_legacy([])
	GameState.pending_stories.clear()

	# Region objectives count seals there; crossings ask, and count.
	var obj: Dictionary = GameState.current_act()["objectives"][0]
	GameState.quest_tally["biome_seals:glass"] = 3
	check(GameState.campaign_objective_met(obj), "three seals on the Glass Coast")
	GameState.run = {"biome": "glass", "layers": []}
	for i in 30:
		GameState.maybe_crossing()
	GameState.run = {}
	var crossing: Array = GameState.pending_stories.filter(func(c): return str(c.get("kind", "")) == "crossing")
	check(crossing.size() == 1, "a crossing waits at the door, one at a time")
	var coins0 := GameState.coins
	GameState.answer_crossing("back")
	check(GameState.crossings_answered == 1 and GameState.coins == coins0 + GameData.CROSSING_BOUNTY, "turned back: the Crown's bounty")

	# Act VI: the City's gate is a defense whatever the ending (even a keeper's).
	GameState._complete_act(5)
	check(int(GameState.current_act().get("act", 0)) == 6 and GameState.book2_regions().has("city"), "Act VI, the Inverted City")
	GameState.accord_ending = "renew"
	GameState.breach = {}
	GameState._on_day_passed()
	check(GameState.breach.get("gate", false) and str(GameState.breach["region"]) == "city", "the City's gate swells, even with the rifts shut")
	GameState._on_rift_sealed(GameData.rift_rank_index("SSS"))
	check(GameState.breach.get("gate", false), "the gate can't be sealed away; it has to be held")
	GameState.breach["broken"] = true
	GameState.resolve_breach({"held": true, "integrity": 1.0, "fallen": []})
	check(GameState.gates_held == 1 and not GameState.gate_due(), "the gate held")

	# The ending: both worlds opens the doors to Hollow-born recruits, in later guilds too.
	GameState._complete_act(6)
	check(GameState.pending_stories.any(func(c): return str(c.get("kind", "")) == "sky"), "after Act VI: the doors")
	GameState.choose_sky_ending("both")
	check(GameState.sky_ending == "both" and GameState.hollowborn_open() and bool(GameState.legacy.get("hollowborn", false)), "both worlds: Hollow-born heroes, remembered by the Vale")
	var hb := 0
	for i in 200:
		if GameState.gen_recruit_offer().quirks.has("Hollow-born"):
			hb += 1
	check(hb > 10 and hb < 80, "some recruits come from the far side (%d of 200)" % hb)

	# Ours: Laurels, and the Hollow's foes leave the ladder.
	GameState.reset()
	GameState.guild_name = "Closed Doors"
	GameState.legacy = {"laurels": 0, "guilds": [], "champions": {}}
	GameState.campaign_act = 7
	GameState.accord_ending = "break"
	GameState.write_legacy([])
	var l0 := int(GameState.legacy["laurels"])
	GameState.choose_sky_ending("ours")
	check(int(GameState.legacy["laurels"]) == l0 + GameData.SKY_OURS_LAURELS and GameState.book2_regions().is_empty() and not GameState.hollowborn_open(), "ours: Laurels, and the far side's rifts close")
	GameState.legacy = {"laurels": 0, "guilds": [], "champions": {}}
	GameState.delete_slot(9)
