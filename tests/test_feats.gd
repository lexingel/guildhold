extends "res://tests/base_test.gd"
## Feats: elites, bosses, pillars and finales set an optional objective; done
## by hand in a won fight, it pays FEAT_BONUS and an elite offers one more boon.


func _engage(kind: String) -> Dictionary:
	for h in GameState.heroes:
		h.hp = Combat.max_hp(h)
	GameState.run["node_state"] = {}
	GameState.choose_node_type(kind)
	GameState.engage_node()
	return GameState.run["node_state"]["combat_state"]


func _finish(state: Dictionary, auto: bool = false) -> Dictionary:
	if auto:
		state["auto_used"] = true
	for step in 300:
		if GameState.run["node_state"].has("result"):
			break
		GameState.resolve_turn_now()
	return GameState.run["node_state"].get("result", {})


func run() -> void:
	seed(777)
	GameState.active_slot = 9
	GameState.reset()
	GameState.guild_name = "Feats"
	var ids: Array[String] = []
	for r in ["A", "A", "A"]:
		var h := Combat.gen_hero(r, 30)
		h.id = "h%d" % GameState.next_id
		GameState.next_id += 1
		GameState.heroes.append(h)
		ids.append(h.id)
	GameState.runs_started = 3
	GameState.start_ladder_rift("F", ids, null)

	# Which fights set one.
	var st := _engage("elite")
	check(st.has("feat") and GameData.FEATS.has(str(st["feat"]["id"])), "an elite sets a Feat (%s)" % str(st.get("feat", {})))
	var txt: Array = Combat.feat_text(st["feat"])
	check(str(txt[0]) != "" and not str(txt[0]).contains("%"), "with a name that reads: %s" % str(txt[0]))
	var plain := _engage("combat")
	check(not plain.has("feat"), "a regular fight doesn't")
	# The Feat is chosen before Engage, and the fight keeps it.
	GameState.run["node_state"] = {}
	GameState.choose_node_type("elite")
	var pre := GameState.coming_feat()
	check(GameData.FEATS.has(pre) and str(Combat.feat_preview_text(pre, "elite")[0]) != "", "the encounter screen shows the coming Feat (%s)" % pre)
	GameState.engage_node()
	var fid := str(GameState.run["node_state"]["combat_state"]["feat"]["id"])
	check(fid == pre or pre in ["first", "double"], "and the fight sets that Feat (%s)" % fid)

	# Each kind of Feat settles from the fight's own record.
	var s := {"feat": {"id": "break"}, "round_num": 3, "_stats": {}, "monsters": [], "party": GameState.heroes}
	check(Combat.feat_status(s) == "open" and Combat.feat_status(s, true) == "failed", "break: no wind-up broken yet")
	s["_stats"] = {"broke_windup": 1.0}
	check(Combat.feat_status(s) == "done", "one broken wind-up: done")
	s = {"feat": {"id": "swift", "rounds": 4}, "round_num": 5}
	check(Combat.feat_status(s) == "failed", "swift: round 5 is too late for a 4-round Feat")
	s = {"feat": {"id": "first", "foe": "Hedge Warden"}, "round_num": 2, "_feat_first": "Rift Wisp"}
	check(Combat.feat_status(s) == "failed", "first: the wrong foe fell first")
	s["_feat_first"] = "Hedge Warden"
	check(Combat.feat_status(s) == "done", "the right one: done")
	s = {"feat": {"id": "double"}, "round_num": 3, "_feat_downed": {0: 2, 1: 3}}
	check(Combat.feat_status(s, true) == "failed", "double: one per round isn't two at once")
	s["_feat_downed"] = {0: 3, 1: 3}
	check(Combat.feat_status(s) == "done", "two in round 3: done")
	s = {"feat": {"id": "momentum", "momentum": 8}, "round_num": 4, "momentum": 5, "_feat_max_mom": 7}
	check(Combat.feat_status(s) == "open" and Combat.feat_status(s, true) == "failed", "momentum: 7 banked isn't 8")
	s["_feat_max_mom"] = 8
	check(Combat.feat_status(s) == "done", "8 at any point: done")
	# Losing half one's health in the fight (not starting below half) fails "unbloodied".
	var h0: Hero = GameState.heroes[0]
	h0.hp = int(Combat.max_hp(h0) * 0.4)
	s = {"feat": {"id": "unbloodied"}, "round_num": 1, "monsters": [], "party": GameState.heroes, "_feat_start_hp": {h0.id: h0.hp}}
	Combat._feat_watch(s)
	check(Combat.feat_status(s) == "open", "a hero who started the fight hurt doesn't fail it")
	s["_feat_start_hp"] = {h0.id: Combat.max_hp(h0)}
	Combat._feat_watch(s)
	check(Combat.feat_status(s) == "failed", "one who lost more than half does")

	# The payout: by hand only.
	var paid := 0
	var autos_paid := 0
	var four := false
	for i in 12:
		var es := _engage("elite")
		es["feat"] = {"id": "swift", "rounds": 6}   # easy for this party
		var res := _finish(es)
		if res.get("won", false) and res.get("feat_done", false):
			paid += 1 if int(res.get("feat_gold", 0)) > 0 and int(res.get("feat_ess", 0)) > 0 else 0
			four = four or (res.get("boon_offer", []) as Array).size() == GameData.BOON_OFFER_SIZE + 1
	check(paid > 0, "a Feat done by hand pays Gold and Essence (%d of 12)" % paid)
	check(four, "and an elite offers one more boon")
	check(GameState.feats_done == paid, "Records count them (%d)" % GameState.feats_done)
	for i in 6:
		var es2 := _engage("elite")
		es2["feat"] = {"id": "swift", "rounds": 6}
		var res2 := _finish(es2, true)
		autos_paid += int(int(res2.get("feat_gold", 0)) > 0)
	check(autos_paid == 0, "Auto never earns a Feat")
	GameState.delete_slot(9)
