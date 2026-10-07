extends "res://scripts/autoload/game_state/GameStateQuests.gd"
## GameState, part 5: rift difficulty and the modes built on runs — campaign, the daily twist, Tower hooks, boons, records.


## Folds a ladder rank (GameData.RIFT_RANKS) into a copy of its base `diff`:
## foe multipliers, reward multiplier and extra rules. Shared by start_run()
## (the first build_layers() call) and _diff() (every later lookup).
func _apply_rift_rank_modifiers(diff: Dictionary, rift_rank: String) -> Dictionary:
	if rift_rank == "":
		return diff
	var mods: Dictionary = GameData.find_rift_rank(rift_rank)
	var out := diff.duplicate(true)
	var above_f := rift_rank != "F"
	out["monster_hp"] = float(out["monster_hp"]) * float(mods["hp"]) * (GameData.RANK_THREAT_HP if above_f else 1.0)
	out["monster_dmg"] = float(out["monster_dmg"]) * float(mods["dmg"]) * (GameData.RANK_THREAT_DMG if above_f else 1.0)
	var rw := float(mods["reward"])
	out["coin"] = [int(round(float(out["coin"][0]) * rw)), int(round(float(out["coin"][1]) * rw))]
	out["crystal"] = [int(round(float(out["crystal"][0]) * rw)), int(round(float(out["crystal"][1]) * rw))]
	out["seal_essence"] = int(round(float(out["seal_essence"]) * rw))
	out["rec_power"] = int(mods["rec"])
	out["hazard_severity_up"] = int(mods.get("hazard_severity_up", 0))
	out["elite_chance_up"] = bool(mods.get("elite_chance_up", false))
	out["shop_chance_down"] = bool(mods.get("shop_chance_down", false))
	out["boss_double_mechanic"] = bool(mods.get("boss_double_mechanic", false))
	return out


func _diff() -> Dictionary:
	if run.has("tower"):
		return _tower_diff(tower_floor_info(int(run["tower"])))
	var diff: Dictionary = GameData.DIFFICULTIES[0]
	for d in GameData.DIFFICULTIES:
		if d["id"] == run["diff_id"]:
			diff = d
	diff = _apply_rift_rank_modifiers(diff, str(run.get("rift_rank", "")))
	if not run.is_empty():
		diff = diff.duplicate()
		diff["biome"] = run_biome()
	if run.has("daily"):
		diff = _apply_daily(diff)
	if int(run.get("finale", 0)) > 0:
		return _apply_finale(diff)
	if run.get("morrow", false):   # the Charter War: Morrow is this rift's boss
		diff = diff.duplicate()
		diff["boss_name"] = GameData.MORROW_BOSS
	if year_mult("rift_gold") != 1.0 or (stirred_region() != "" and str(diff.get("biome", "")) == stirred_region()):   # the Vale this year
		var yg := year_mult("rift_gold")
		var stirred := stirred_region() != "" and str(diff.get("biome", "")) == stirred_region()
		diff = diff.duplicate()
		diff["coin"] = [int(round(float(diff["coin"][0]) * yg)), int(round(float(diff["coin"][1]) * yg))]
		if stirred:
			diff["monster_hp"] = float(diff["monster_hp"]) * float(GameData.VALE_STIRRED["hp"])
			diff["crystal"] = [int(round(float(diff["crystal"][0]) * float(GameData.VALE_STIRRED["essence"]))), int(round(float(diff["crystal"][1]) * float(GameData.VALE_STIRRED["essence"])))]
	if run.has("descent"):   # each depth harder, and better paid
		var g := float(int(run["descent"]) - 1)
		var pay := 1.0 + GameData.DESCENT_PAY_GROWTH * g
		diff = diff.duplicate()
		diff["monster_hp"] = float(diff["monster_hp"]) * (1.0 + GameData.DESCENT_GROWTH * g)
		diff["monster_dmg"] = float(diff["monster_dmg"]) * (1.0 + GameData.DESCENT_GROWTH * g)
		diff["coin"] = [int(round(float(diff["coin"][0]) * pay)), int(round(float(diff["coin"][1]) * pay))]
		diff["crystal"] = [int(round(float(diff["crystal"][0]) * pay)), int(round(float(diff["crystal"][1]) * pay))]
	return _apply_training(diff) if run.get("training", false) else diff


func _apply_training(diff: Dictionary) -> Dictionary:
	var out := diff.duplicate(true)
	var t: Dictionary = GameData.TRAINING_RIFT
	out["floors"] = int(t["floors"])
	out["monster_hp"] = int(round(float(out["monster_hp"]) * float(t["monster_hp_mult"])))
	out["monster_dmg"] = int(round(float(out["monster_dmg"]) * float(t["monster_dmg_mult"])))
	return out


# ---------------- Campaign ----------------

func campaign_done() -> bool:
	return campaign_act > GameData.CAMPAIGN.size()


func current_act() -> Dictionary:
	if campaign_done() or (campaign_act >= 5 and accord_ending == ""):   # Book II waits for the Accord's ending
		return {}
	return GameData.CAMPAIGN[campaign_act - 1]


func campaign_objective_progress(o: Dictionary) -> int:
	var t := str(o["type"])
	if t.begins_with("boss:"):
		return int(quest_tally.get(t, 0))
	if t.begins_with("region_seals:"):
		return int(quest_tally.get("biome_seals:" + t.trim_prefix("region_seals:"), 0))
	match t:
		"rifts_sealed": return rifts_sealed
		"heroes": return heroes.size()
		"greater_seals": return int(quest_tally.get("greater_seals", 0))
		"reputation": return reputation
		"map_rank": return best_rift_rank_sealed + 1 if best_rift_rank_sealed >= int(o["target"]) else 0
		"quests_done": return int(quest_tally.get("quests_done", 0))
		"ledger_pages": return accord_pages
		"posts_freed": return posts_freed()
		"crossings": return crossings_answered
		"gate_held": return gates_held
	return 0


## The act's named wardens not yet beaten (Act III's Korrath and Drevok): a
## rift's boss is one of them when its region has them. Drevok guards only
## the Ashen Crown, as one of two bosses; in the sim 2 of 16 casual guilds
## sealed 15+ rifts in Act III without meeting him and sat there 60 days.
func wanted_wardens() -> Array:
	var out: Array = []
	for o in current_act().get("objectives", []):
		var t := str(o["type"])
		if t.begins_with("boss:") and campaign_objective_progress(o) < int(o["target"]):
			out.append(t.trim_prefix("boss:"))
	return out


## Lost champions freed in the Endless Rift: the posts the guild has emptied.
func posts_freed() -> int:
	return lost_champions().filter(func(e): return champion_unlocked(str(e[0]))).size()


func campaign_objective_met(o: Dictionary) -> bool:
	if str(o["type"]) == "map_rank":
		return best_rift_rank_sealed >= int(o["target"])
	return campaign_objective_progress(o) >= int(o["target"])


func finale_ready() -> bool:
	var act := current_act()
	return not act.is_empty() and (act["objectives"] as Array).all(func(o): return campaign_objective_met(o))


func finale_recommended_power() -> int:
	var act := current_act()
	if act.is_empty():
		return 0
	var grow := (1.0 + (GameData.TERMS_PER_POST * posts_freed() if int(act["act"]) == 4 else 0.0)) * _terms_cut(int(act["act"]))   # as _apply_finale
	return int(round(int(GameData.FINALE_REC[int(act["act"]) - 1]) * grow))


## A biome for a new rift: the Vale in Act I, the Vale or the Marshes in Act
## II, any of the three after that.
func pick_biome(for_run: bool = false) -> String:
	var open := open_regions()
	if for_run and key_region_open() and open.has(chosen_region):   # Pip's Key
		return chosen_region
	return str(open[randi() % open.size()])


## The regions a rift can open in now (weighted: a region listed twice is
## twice as likely).
func open_regions() -> Array:
	var open := ["vale"] if campaign_act <= 1 else (["vale", "marsh", "marsh"] if campaign_act == 2 else ["vale", "marsh", "ashen"])
	open.append_array(book2_regions())
	return open


## The Sky Beneath's regions this guild has reached (none after closing the doors).
func book2_regions() -> Array:
	if accord_ending == "" or campaign_act < 5 or sky_ending == "ours":
		return []
	return ["glass", "glass", "glass"] if campaign_act == 5 else ["glass", "city", "city", "city"] if campaign_act == 6 else ["glass", "city"]


## The run's biome.
func run_biome() -> String:
	return str(run.get("biome", "vale"))


## A finale is its act's gate rank (the one you seal to open it) and then
## some: it was the bare tier x1.15-1.45, weaker than the rank before it, and
## a quarter of finale fights ended in round 1 (campaign_sim).
func _apply_finale(diff: Dictionary) -> Dictionary:
	var act: Dictionary = GameData.CAMPAIGN[int(run["finale"]) - 1]
	var out := _apply_rift_rank_modifiers(diff, str(act.get("rank", ""))).duplicate(true)
	out["monster_hp"] = int(round(float(out["monster_hp"]) * float(act["mult"])))
	out["monster_dmg"] = int(round(float(out["monster_dmg"]) * float(act["mult"])))
	if int(act["act"]) == 4:   # the Terms grow with every empty post
		var grow := (1.0 + GameData.TERMS_PER_POST * posts_freed()) * _terms_cut(4)
		out["monster_hp"] = int(round(float(out["monster_hp"]) * grow))
		out["monster_dmg"] = int(round(float(out["monster_dmg"]) * grow))
	out["boss_name"] = str(act["boss"])
	out["boss_double_mechanic"] = int(act["act"]) >= 3
	out["rec_power"] = finale_recommended_power()   # the readout, for defeat reasons
	return out


## Sealing a finale: the act's reward, a Legendary relic, the next act.
func _complete_act(act_num: int) -> void:
	note_milestone("Act %d done" % act_num)
	var act: Dictionary = GameData.CAMPAIGN[act_num - 1]
	var reward: Dictionary = act["reward"]
	var first_card := pending_stories.size()
	crystals += int(reward.get("crystals", 0))
	var relic := Combat.gen_unique_relic()
	relics.append(relic)
	campaign_act = act_num + 1
	act_since = day
	var subtitle := tr("Act %s complete — +%d Essence, %s") % [tr(str(_roman(act_num))), int(reward.get("crystals", 0)), tr(str(relic.name))]
	if str(act["opens"]) != "":
		subtitle += tr(" · %s unlocked") % tr(str(act["opens"]))
	var spared_sub := tr("Act %s complete — +%d Essence") % [tr(str(_roman(act_num))), int(reward.get("crystals", 0)) - GameData.VAELITH_SPARE_ESSENCE]
	if str(act["opens"]) != "":
		spared_sub += tr(" · %s unlocked") % tr(str(act["opens"]))
	pending_stories.append({"title": tr(str(act["finale"])) + tr(" — sealed"), "subtitle": subtitle, "text": str(act["outro"]), "act_outro": act_num, "subtitle_spared": spared_sub})
	lore_event("finale", str(act_num))
	var freed := story_champion(act_num)
	if freed != "" and not champions.has(freed):
		unlock_champion(freed)
		var d := GameData.champion_def(freed)
		pending_stories.append({"title": tr("A champion is freed"), "subtitle": GameData.champion_full_name(freed),
			"text": tr("Deep in %s, held in a pillar of light, your guild finds %s. %s\n\n%s\n\nChampions oversee your rift runs (their Boon, and their Call) and fight in the Endless Rift. See Roster > Champions.") % [tr(str(act["finale"])), GameData.champion_full_name(freed), tr(str(d.get("lore", ""))), champion_memory_line(freed)]})
	if act_num == 3 and feature_unlocked("rival"):
		pending_stories.append(_charter_hearing())
	if act_num == 2 and feature_unlocked("rival") and charter_choice == "":
		var turn_card: Dictionary = GameData.CHARTER_TURN.duplicate(true)
		if sworn("never_sell"):
			turn_card["choices"] = ["expose"]   # the oath: the page goes to the Crown
		var page := lore_event("charter", "turn")
		if page != "":
			turn_card["text"] = tr(str(turn_card["text"])) + "\n\n" + page
		pending_stories.append(turn_card)   # after Act III's intro (below)
	if act_num == 3:
		_find_line_piece()
	if act_num >= 5:
		_add_postgame_laurels(GameData.BOOK2_ACT_LAURELS)
	if act_num == 6:
		pending_stories.append(GameData.SKY_CHOICE.duplicate(true))   # both worlds, or ours
	elif act_num == 4:
		var choice: Dictionary = GameData.ACCORD_CHOICE.duplicate(true)
		if rewrite_open():   # the third ending: Hesper's forty-second line
			choice["text"] = tr(str(choice["text"])) + "\n\n" + tr(hesper_alt("rewrite_hint", GameData.REWRITE_HINT))
			(choice["choices"] as Array).append("rewrite")
		pending_stories.append(choice)   # the ending, then The End
	elif campaign_done():
		pending_stories.append(_the_end_card())
	else:
		pending_stories.append(_act_intro_card(campaign_act))
		if campaign_act == 2 and founding == "mercenary":
			var offer: Dictionary = GameData.MERCENARY_OFFER.duplicate()
			var wm := lore_event("mercenary", "offer")
			if wm != "":
				offer["text"] = tr(str(offer["text"])) + "\n\n" + wm
			pending_stories.append(offer)
		# The Charter War's turn waits until after Act III's intro.
		var turn := pending_stories.filter(func(c): return str(c.get("kind", "")) == "charter")
		for c in turn:
			pending_stories.erase(c)
			pending_stories.append(c)
	if act_num == 5 and truth_known("t_brannoch") and str(branches.get("brannoch", "")) == "" and not champion_unlocked("brannoch"):   # B7
		pending_stories.append(GameData.BRANNOCH_CHOICE.duplicate(true))
	if act_num == 2 and str(branches.get("spire", "")) == "":   # B10: before the outro
		pending_stories.insert(mini(first_card, pending_stories.size()), GameData.SPIRE_CHOICE.duplicate(true))
	if act_num == 1 and not _in_veteran and vaelith_open():   # B1: before the outro
		var vc: Dictionary = GameData.VAELITH_CHOICE.duplicate(true)
		vc["relic"] = relic.id
		pending_stories.insert(mini(first_card, pending_stories.size()), vc)


## Branch B1 (the Unwritten Accord): a guild that knows why Vaelith left may
## let her go at Act I's finale.
func vaelith_open() -> bool:
	return truth_known("t_why_left") and str(branches.get("vaelith", "")) == ""


## Answers B1 on top of the story queue: "end" (as ever) or "spare": no
## finale relic and half its Essence, Vaelith joins as a champion, Act IV's
## finale is a little weaker, and an Iron Chorus rival makes something of it.
func choose_vaelith(choice: String) -> void:
	if pending_stories.is_empty() or str(pending_stories[0].get("kind", "")) != "vaelith":
		return
	var card: Dictionary = pending_stories.pop_front()
	if choice == "spare":
		branches["vaelith"] = "spared"
		for i in relics.size():
			if relics[i].id == str(card.get("relic", "")):
				relics.remove_at(i)
				break
		crystals = maxi(0, crystals - branch_cost(GameData.VAELITH_SPARE_ESSENCE))
		unlock_champion("vaelith")
		if rival_name == "The Iron Chorus":
			rival_renown += GameData.VAELITH_CHORUS_RENOWN
			_news(tr("The Iron Chorus calls it harbouring a deserter (+%d Renown to them).") % GameData.VAELITH_CHORUS_RENOWN)
		for c in pending_stories:
			if int(c.get("act_outro", 0)) == 1:
				c["text"] = GameData.VAELITH_SPARED_OUTRO
				c["subtitle"] = str(c.get("subtitle_spared", c["subtitle"]))
		pending_stories.push_front(GameData.VAELITH_SPARED.duplicate())
		_news(tr("Vaelith was let go at the Breach, and joined the guild."))
	save()
	state_changed.emit()


## Act IV's finale, a little weaker if Vaelith was let go (B1) and again if
## the archive was carried out of the Spire (B10).
func _terms_cut(act_num: int) -> float:
	if act_num != 4:
		return 1.0
	return 1.0 - (GameData.VAELITH_FINALE_CUT if str(branches.get("vaelith", "")) == "spared" else 0.0) \
		- (GameData.SPIRE_TERMS_CUT if str(branches.get("spire", "")) == "archive" else 0.0)


## B10 (needs no truth): at Act II's finale, carry out the Accord's archive
## or save Hollin.
func choose_spire(choice: String) -> void:
	if pending_stories.is_empty() or str(pending_stories[0].get("kind", "")) != "spire":
		return
	pending_stories.pop_front()
	var archive := choice == "archive"
	branches["spire"] = "archive" if archive else "hollin"
	if archive:
		reputation = maxi(0, reputation - GameData.SPIRE_ARCHIVE_RENOWN)
		for c in pending_stories:
			if int(c.get("act_outro", 0)) == 2:
				c["text"] = GameData.SPIRE_ARCHIVE_OUTRO
	else:
		add_reputation(GameData.SPIRE_HOLLIN_RENOWN)
	var r: Dictionary = (GameData.SPIRE_ARCHIVE if archive else GameData.SPIRE_HOLLIN).duplicate()
	var frag := lore_event("spire", str(branches["spire"]))
	if frag != "":
		r["text"] = tr(str(r["text"])) + "\n\n" + frag
	pending_stories.push_front(r)
	_news(tr("The archive was carried out of the Spire, and Hollin flooded.") if archive else tr("Hollin was saved from the flood, and the Spire's archive drowned."))
	save()
	state_changed.emit()


## Crossings (Book II): letting one through costs no Renown if Hollin was
## saved (B10); turning one back pays double while this guild holds the
## Royal Charter.
func crossing_renown() -> int:
	return 0 if str(branches.get("spire", "")) == "hollin" else GameData.CROSSING_RENOWN


func crossing_bounty() -> int:
	return GameData.CROSSING_BOUNTY * (GameData.CHARTER_BOUNTY_MULT if charter_result == "won" and not moot() else 1)


## `text` with `lines` added before its closing "(...)" note, if it has one.
static func _with_lines(text: String, lines: Array) -> String:
	if lines.is_empty():
		return text
	var add := "\n\n".join(lines)
	var at := text.rfind("\n\n(")
	return text + "\n\n" + add if at < 0 else text.substr(0, at) + "\n\n" + add + text.substr(at)


## "<Name> remembers: ..." (the Broken Accord), or "" for a champion without one.
func champion_memory_line(id: String) -> String:
	var m := str(GameData.CHAMPION_MEMORY.get(id, GameData.champion_def(id).get("memory", "")))
	return "" if m == "" else tr("%s remembers: %s") % [tr(str(GameData.champion_def(id)["name"])), tr(m)]


## A sealed rift may turn up the next page of the Grandmaster's ledger (a
## finale always does), once the campaign has reached that page's act.
func maybe_find_ledger_page(finale: bool) -> void:
	if accord_pages >= GameData.LEDGER_PAGES.size():
		return
	var page: Dictionary = GameData.LEDGER_PAGES[accord_pages]
	if campaign_act < int(page["act"]):
		return
	if not finale and ledger_dry < GameData.LEDGER_PITY and randf() >= GameData.LEDGER_PAGE_CHANCE * float(founding_rule("ledger", 1.0)) * spire_finds():
		ledger_dry += 1
		return
	ledger_dry = 0
	accord_pages += 1
	hear_ledger_claims()
	pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("A page of the Grandmaster's ledger"),
		"text": tr("Page %d of %d, found in the rift. Read it in Library > Codex > Chronicle.") % [accord_pages, GameData.LEDGER_PAGES.size()]})


## What the Rifts Take: from Act II a sealed rift sometimes leaves an echo
## (GameData.ECHOES, each once), a choice card: give it back or keep it.
func maybe_echo() -> void:
	if campaign_act < 2 or pending_stories.any(func(c): return str(c.get("kind", "")) == "echo") or randf() >= GameData.ECHO_CHANCE * year_mult("echo_chance") * float(founding_rule("echo_chance", 1.0)):
		return
	var left: Array = GameData.ECHOES.filter(func(e): return not echoes_seen.has(str(e["id"])))
	if left.is_empty():
		return
	var e: Dictionary = left[randi() % left.size()]
	echoes_seen.append(str(e["id"]))
	pending_stories.append({"kind": "echo", "echo": str(e["id"]), "title": str(e["title"]), "subtitle": tr("An echo, from the last rift"),
		"text": str(e["text"]), "choices": ["return", "keep"], "essence": echo_essence()})


func echo_essence() -> int:
	return 25 + 15 * mini(campaign_act, 4)


## Answers the echo on top of the story queue: "return" (Renown, and a scene)
## or "keep" (its Essence).
func answer_echo(choice: String) -> void:
	if pending_stories.is_empty() or str(pending_stories[0].get("kind", "")) != "echo":
		return
	var card: Dictionary = pending_stories.pop_front()
	var e: Array = GameData.ECHOES.filter(func(x): return str(x["id"]) == str(card["echo"]))
	if choice == "return":
		var renown := int(round(GameData.ECHO_RENOWN * float(founding_rule("echo_renown", 1.0))))
		add_reputation(renown)
		echoes_returned += 1
		if str(card["echo"]) == "song":   # the story web: the Choir learned it from us
			legacy["song_given"] = true
			save_legacy()
		if not e.is_empty():
			var back := tr(hesper_alt("echo_oath", str(e[0]["returned"])) if str(card["echo"]) == "oath" else str(e[0]["returned"]))
			var frag := lore_event("echo", str(card["echo"]))
			pending_stories.push_front({"title": tr(str(e[0]["title"])), "subtitle": tr("Given back · +%d Renown") % renown, "text": back + ("\n\n" + tr(frag) if frag != "" else "")})
		_news(tr("An echo was given back to the village: %s.") % tr(str(card["title"])))
	else:
		crystals += int(round(int(card.get("essence", echo_essence())) * float(founding_rule("echo_essence", 1.0)) * year_mult("echo_essence")))
		_news(tr("An echo was kept: %s (+%d Essence).") % [tr(str(card["title"])), int(card.get("essence", 0))])
		_echo_touch(str(card["echo"]))
		lore_event("echo_kept", str(card["echo"]))
	if echoes_seen.size() == 3:   # the third echo brings Ezra
		var ez: Dictionary = GameData.EZRA_VISIT["gave" if echoes_returned * 2 >= echoes_seen.size() else "kept"]
		var ez_card := {"title": tr(str(ez["title"])), "subtitle": tr(str(ez["subtitle"])), "text": tr(str(ez["text"]))}
		var lamp := lore_event("ezra", "visit")
		if lamp != "":
			ez_card["text"] = str(ez_card["text"]) + "\n\n" + lamp
		if truth_known("t_lantern") and str(branches.get("lantern", "")) == "":   # B6
			ez_card["kind"] = "ezra"
			ez_card["choices"] = ["keep", "pour"]
			ez_card["text"] = str(ez_card["text"]) + tr(GameData.EZRA_CHOICE_TEXT)
		pending_stories.append(ez_card)
	save()
	state_changed.emit()


## A kept echo may touch a hero who recognises what's in it (Echo-Touched).
func _echo_touch(echo_id: String) -> void:
	var pool: Array = heroes.filter(func(h): return not h.is_champion and not h.quirks.has("Echo-Touched"))
	if pool.is_empty() or randf() >= float(founding_rule("echo_touch", GameData.ECHO_TOUCH_CHANCE)):
		return
	var h: Hero = pool[randi() % pool.size()]
	h.history["echoes"] = 1
	check_earned_quirks(h)
	var n := tr(str(h.name.split(" the ")[0]))
	var t: Dictionary = GameData.ECHO_TOUCH
	pending_stories.append({"title": tr(str(t["title"])) % n, "subtitle": tr(str(t["subtitle"])),
		"text": tr(str(t["text"])) % [n, tr(str(GameData.ECHO_HOLDS.get(echo_id, "something"))), n, n]})


## "gave" or "kept": what the Vale remembers of the echoes (a poured lantern, B6, is giving).
func vale_verdict() -> String:
	return "gave" if echoes_returned * 2 >= echoes_seen.size() or str(branches.get("lantern", "")) == "poured" else "kept"


## What the Vale remembers (the campaign's end, after three echoes or more).
func _vale_remembers() -> Dictionary:
	var v: Dictionary = GameData.VALE_REMEMBERS[vale_verdict()]
	return {"title": tr(str(v["title"])), "subtitle": tr(str(v["subtitle"])), "text": tr(str(v["text"]))}


## The Charter War's turn: "expose" the Hollow Crown Company or keep "quiet"
## (the choice card that opens Act III).
func choose_charter(choice: String) -> void:
	if choice == "turn":
		turn_morrow()
		return
	if charter_choice != "" or not GameData.CHARTER_RESULT.has(choice) or (choice == "quiet" and sworn("never_sell")):
		return
	charter_choice = choice
	if choice == "expose":
		add_reputation(GameData.CHARTER_EXPOSE_RENOWN)
		if rival_name == "The Hollow Crown Company":
			rival_renown = maxi(0, rival_renown - GameData.CHARTER_EXPOSE_RENOWN)   # the Crown fines them
		if campaign_act >= GameData.BREACH_UNLOCK_ACT and breach.is_empty():
			breach_next_day = day + 2   # the Company opens one on your road
	var r: Dictionary = GameData.CHARTER_RESULT[choice]
	if not pending_stories.is_empty() and str(pending_stories[0].get("kind", "")) == "charter":
		pending_stories.pop_front()
	var small := lore_event("charter", "quiet") if choice == "quiet" else ""
	pending_stories.push_front({"title": tr(str(r["title"])), "subtitle": tr(str(r["subtitle"])), "text": tr(hesper_alt("charter_quiet", str(r["text"])) if choice == "quiet" else str(r["text"])) + ("\n\n" + small if small != "" else "")})
	_news(tr(str(r["title"])) + ".")
	save()
	state_changed.emit()


## The Crown's hearing (Act III's end): the Royal Charter to the Renown leader.
func _charter_hearing(accepted: bool = false) -> Dictionary:
	if charter_choice == "turn" and not accepted and not branches.has("turn_hearing"):   # B2: the Crown remembers Morrow
		branches["turn_hearing"] = "done"
		rival_renown += GameData.MORROW_TURN_HEARING
	if not accepted and reputation < rival_renown and truth_known("t_warden") and not moot():   # B3: the Charter has a price
		return GameData.HEARING_CHOICE.duplicate(true)
	charter_result = "won" if reputation >= rival_renown else "lost"
	var h: Dictionary = (GameData.MOOT_HEARING if moot() else GameData.CHARTER_HEARING)[charter_result]
	var rn := tr(str(rival_name))
	var card := {"title": tr(str(h["title"])), "subtitle": tr(str(h["subtitle"])), "text": tr(str(h["text"]))}
	if charter_result == "lost":
		card["subtitle"] = card["subtitle"] % rn
		card["text"] = card["text"] % rn
	else:
		var left := lore_event("hearing", "won")
		if left != "":
			card["text"] = str(card["text"]) + "\n\n" + left
	_news(card["subtitle"] + ".")
	return card


## B2: a guild that knows who pays the Company can buy Morrow instead.
func morrow_turn_open() -> bool:
	return truth_known("t_paymaster") and charter_choice == ""


## Turns Morrow (B2): the bribe, Morrow on the roster on double wages, the
## Company's hunt called off, and the key on the table (B4). Returns "" or why not.
func turn_morrow() -> String:
	if not morrow_turn_open():
		return tr("Morrow can't be bought by this guild.")
	var cost := branch_cost(GameData.MORROW_TURN_COST)
	if coins < cost:
		return tr("Turning Morrow takes %d Gold.") % cost
	coins -= cost
	charter_choice = "turn"
	branches["morrow"] = "turned"
	var m: Hero = null
	for i in 40:
		m = Combat.gen_hero("S", GameData.MORROW_HERO_LEVEL)
		if m.cls_id == "rogue":
			break
	m.name = "Morrow the %s" % m.name.split(" the ")[1]
	m.history["morrow"] = 1
	heroes.append(m)
	wage_raise[m.id] = 1.0   # double wages
	if not pending_stories.is_empty() and str(pending_stories[0].get("kind", "")) == "charter":
		pending_stories.pop_front()
	_offer_key()
	pending_stories.push_front(GameData.MORROW_TURNED.duplicate())
	_news(tr("Captain Morrow was bought, and joined the guild."))
	save()
	state_changed.emit()
	return ""


## B4: the key, kept or broken (once Morrow is beaten or turned, and the
## guild knows what it opens).
func _offer_key() -> void:
	if truth_known("t_key") and str(branches.get("key", "")) == "":
		pending_stories.append(GameData.KEY_CHOICE.duplicate(true))


func choose_key(choice: String) -> void:
	if pending_stories.is_empty() or str(pending_stories[0].get("kind", "")) != "key":
		return
	pending_stories.pop_front()
	branches["key"] = "kept" if choice == "keep" else "broken"
	if choice != "keep":
		add_reputation(GameData.KEY_BREAK_RENOWN)
		chosen_region = ""
	pending_stories.push_front((GameData.KEY_KEPT if choice == "keep" else GameData.KEY_BROKEN).duplicate())
	save()
	state_changed.emit()


## B3: the Crown's hearing, bought (or the verdict accepted).
func choose_hearing(choice: String) -> String:
	if pending_stories.is_empty() or str(pending_stories[0].get("kind", "")) != "hearing":
		return ""
	var cost := branch_cost(GameData.HEARING_BUY_COST)
	if choice == "buy" and coins < cost:
		return tr("Buying the Charter takes %d Gold.") % cost
	pending_stories.pop_front()
	if choice == "buy":
		coins -= cost
		charter_result = "won"
		branches["hearing"] = "bought"
		pending_stories.push_front(GameData.HEARING_BOUGHT.duplicate())
		_news(tr("The Royal Charter was bought."))
	else:
		pending_stories.push_front(_charter_hearing(true))
	save()
	state_changed.emit()
	return ""


## B6: Ezra's lantern, filled with the vault's kept echoes (or not).
func choose_lantern(choice: String) -> void:
	if pending_stories.is_empty() or str(pending_stories[0].get("kind", "")) != "ezra":
		return
	pending_stories.pop_front()
	if choice == "pour":
		branches["lantern"] = "poured"
		crystals = maxi(0, crystals - branch_cost(GameData.LANTERN_PER_ECHO) * (echoes_seen.size() - echoes_returned))
		for h in heroes:
			h.quirks.erase("Echo-Touched")
		pending_stories.push_front(GameData.LANTERN_POURED.duplicate())
		_news(tr("The kept echoes were poured into Ezra's lantern."))
	save()
	state_changed.emit()


## B7: Brannoch's door, at Act VI's start.
func choose_brannoch(choice: String) -> void:
	if pending_stories.is_empty() or str(pending_stories[0].get("kind", "")) != "brannoch":
		return
	pending_stories.pop_front()
	if choice == "leave":
		branches["brannoch"] = "left"
		gates_held = maxi(gates_held, 1)   # the City's gate holds
		if breach.has("gate"):
			breach = {}
		pending_stories.push_front(GameData.BRANNOCH_LEFT.duplicate())
	else:
		branches["brannoch"] = "freed"
		unlock_champion("brannoch")
		champions["brannoch"] = maxi(int(champions.get("brannoch", 1)), GameData.BRANNOCH_LEVEL)
		pending_stories.push_front(GameData.BRANNOCH_FREED.duplicate())
	save()
	state_changed.emit()


## The epilogue opens after Book II's ending, once per player, when the
## guild knows the five truths behind the first signature.
func epilogue_open() -> bool:
	return epilogue() == "" and GameData.EPILOGUE_TRUTHS.all(func(t): return truth_known(t))


func choose_epilogue(choice: String) -> void:
	if pending_stories.is_empty() or str(pending_stories[0].get("kind", "")) != "epilogue" or epilogue() != "":
		return
	pending_stories.pop_front()
	legacy["epilogue"] = choice
	branches["epilogue"] = choice
	_add_postgame_laurels(GameData.EPILOGUE_LAURELS, {"epilogue": choice})   # saves the legacy too
	save_legacy()
	var e: Dictionary = GameData.EPILOGUE_ENDING[choice]
	pending_stories.push_front({"title": tr(str(e["title"])), "subtitle": tr(str(e["subtitle"])), "text": tr(str(e["text"])), "art": "epilogue_" + choice})
	_news(tr(str(e["title"])) + ".")
	save()
	state_changed.emit()


## Wen's line for the Memorial (by voice, a steady pick per name).
func memorial_line(h: Hero) -> String:
	var lines: Array = GameData.MEMORIAL_LINES.get(GameData.hero_voice(h), GameData.MEMORIAL_LINES["stoic"])
	var first := str(h.name.split(" the ")[0])
	return tr(str(lines[abs(first.hash()) % lines.size()])) % tr(first)


func _the_end_card() -> Dictionary:
	return {"title": tr("The End"), "subtitle": tr("The campaign is complete"), "text": tr("Thank you for playing. Your guild endures: push the Endless Rift, climb the rift ladder, and take on quests for as long as rifts keep opening.")}


## The mystery across guilds: this guild's piece of the forty-second line
## (once per guild, at the end of Act III; the count lives in the legacy).
func _find_line_piece() -> void:
	if line_piece_seen:
		return
	if legacy.is_empty():
		load_legacy()
	var n := int(legacy.get("line", 0))
	if n >= GameData.LINE_PIECES.size():
		return
	line_piece_seen = true
	legacy["line"] = n + 1
	save_legacy()
	var p: Dictionary = GameData.LINE_PIECES[n]
	var text := tr(hesper_alt("line_%d" % (n + 1), str(p["text"])))
	var hall: Array = legacy.get("guilds", [])
	if n == 1:
		text = text % (str(hall[-1]["name"]) if not hall.is_empty() else tr("the guild before you"))
		hear_claim("hesper_spared")
	elif n == 2:
		var kept := hall.filter(func(g): return str(g.get("ending", "")) == "renew")
		var broke := hall.filter(func(g): return str(g.get("ending", "")) == "break")
		text = text % [str(kept[-1]["name"]), str(broke[-1]["name"])] if not kept.is_empty() and not broke.is_empty() else tr(hesper_alt("line_3_wait", str(p["text_wait"])))
	var sub := tr("A letter from the forty-first post") if hesper_posted() and n > 0 else tr(str(p["subtitle"]))
	pending_stories.append({"title": tr(str(p["title"])), "subtitle": sub, "text": text})
	lore_event("line", str(n + 1))


## Whether this guild may rewrite the Terms: the Hall of Guilds holds a guild
## that renewed the Accord and one that broke it, and the line is found.
func rewrite_open() -> bool:
	var hall: Array = legacy.get("guilds", [])
	return int(legacy.get("line", 0)) >= GameData.LINE_PIECES.size() \
		and hall.any(func(g): return str(g.get("ending", "")) == "renew") and hall.any(func(g): return str(g.get("ending", "")) == "break")


## The Broken Accord's ending (the choice card after Act IV). "renew" needs
## the hero who takes the forty-first post; "break" frees every champion of
## this guild. Returns "" or why not.
func choose_accord_ending(choice: String, hero_id: String = "") -> String:
	if accord_ending != "" or not GameData.ACCORD_ENDING.has(choice):
		return ""
	var end: Dictionary = GameData.ACCORD_ENDING[choice]
	var card := {"title": tr(str(end["title"])), "subtitle": tr(str(end["subtitle"])), "text": tr(str(end["text"])), "art": "ending_" + choice}
	if choice == "rewrite" and not rewrite_open():
		return tr("The forty-second line isn't open to this guild.")
	if choice == "renew" and hero_id == "hesper":   # B5: the clerk signs the line herself
		if not hesper_can_sign():
			return tr("Hesper won't sign for this guild.")
		card["subtitle"] = card["subtitle"] % "Hesper"
		card["text"] = card["text"] % "Hesper"
		accord_hero = "Hesper"
		branches["hesper"] = "signed"
		legacy["hesper_posted"] = true
		save_legacy()
		breach = {}
		breach_next_day = -1
	elif choice == "renew":
		var h := find_hero(hero_id)
		if h == null or h.is_champion:
			return tr("Choose a hero to take the post.")
		if heroes.size() <= 1:
			return tr("The guild needs at least one hero.")
		var first := tr(str(h.name.split(" the ")[0]))
		card["subtitle"] = card["subtitle"] % first
		card["text"] = card["text"] % first
		accord_hero = first
		_memorialize(h, tr("Took the forty-first post"))
		_release(h)
		breach = {}
		breach_next_day = -1
	else:
		for id in champion_roll:
			unlock_champion(str(id))
		if choice == "rewrite":   # the posts held in turns: everyone home, and the rifts shut
			breach = {}
			breach_next_day = -1
			if hesper_posted():   # and Hesper comes home
				card["text"] = tr(hesper_alt("rewrite", str(end["text"])))
				legacy["hesper_posted"] = false
				(legacy["champions"] as Dictionary).erase("legacy_hesper")
				save_legacy()
			else:
				var frag := lore_event("ending", "rewrite")
				if frag != "":
					card["text"] = str(card["text"]) + "\n\n" + tr(frag)
	accord_ending = choice
	if not pending_stories.is_empty() and pending_stories[0].has("choices"):
		pending_stories.pop_front()
	pending_stories.push_front(_act_intro_card(5))   # Book II opens
	var sky := _sky_beneath_card()
	var reply := lore_event("book2", "start")   # the story web: whose Terms
	if reply != "":
		sky["text"] = str(sky["text"]) + "\n\n" + reply
	pending_stories.push_front(sky)
	book2_started = true
	if echoes_seen.size() >= 3:
		pending_stories.push_front(_vale_remembers())
	pending_stories.push_front(card)
	_news(card["title"] + ".")
	save()
	state_changed.emit()
	return ""


func _act_intro_card(act_num: int) -> Dictionary:
	var act: Dictionary = GameData.CAMPAIGN[act_num - 1]
	var lines: Array = []   # payoffs of choices this guild made
	if act_num == 4 and str(branches.get("spire", "")) == "archive":
		lines.append(tr(GameData.SPIRE_ARCHIVE_ACT4))
	if act_num == 5 and not moot() and charter_result == "won":
		lines.append(tr(GameData.PAYOFF_CHARTER_WON))
	elif act_num == 5 and not moot() and charter_result == "lost":
		lines.append(tr(GameData.PAYOFF_CHARTER_LOST) % tr(str(rival_name)))
	var text := str(act["intro"]) if lines.is_empty() else tr(str(act["intro"])) + "\n\n" + "\n\n".join(lines)
	return {"title": tr("Act %s — %s") % [tr(str(_roman(act_num))), tr(str(act["name"]))], "subtitle": tr("Foe: %s") % tr(str(act["foe"])), "text": text, "act_intro": act_num}


static func _roman(n: int) -> String:
	return ["I", String(TranslationServer.translate("II")), String(TranslationServer.translate("III")), "IV", "V", "VI"][clampi(n - 1, 0, 5)]


## Book II's first card: the reply on the ledger's last page, and a line for
## how this guild ended the Accord.
func _sky_beneath_card() -> Dictionary:
	var c: Dictionary = GameData.SKY_BENEATH
	var line := tr(str(GameData.SKY_BENEATH_BY_ENDING.get(accord_ending, "")))
	if accord_ending == "renew":
		line = line % accord_hero
	if charter_choice == "quiet":   # a payoff: Morrow's money pays for the climb down
		line += "\n\n" + tr(hesper_alt("payoff_quiet", GameData.PAYOFF_QUIET))
	return {"title": tr(str(c["title"])), "subtitle": tr(str(c["subtitle"])), "text": tr(hesper_alt("sky_beneath", str(c["text"]))) + "\n\n" + line, "art": "sky_beneath"}


## A crossing (Book II): a sealed rift in the Sky Beneath sometimes ends at a
## door with people behind it. One card at a time.
func maybe_crossing() -> void:
	if book2_regions().is_empty() or not (run_biome() in ["glass", "city"]) or pending_stories.any(func(c): return str(c.get("kind", "")) == "crossing") \
			or randf() >= GameData.CROSSING_CHANCE:
		return
	var c: Dictionary = GameData.SIGNATORY if signatory_open() else GameData.CROSSINGS[crossings_answered % GameData.CROSSINGS.size()]
	var frag := lore_event("crossing", str(c["id"]))
	var lines: Array = []   # payoffs of choices this guild made
	if crossings_answered == 0 and str(branches.get("spire", "")) == "hollin":
		lines.append(tr(GameData.SPIRE_HOLLIN_CROSSING))
	if str(c["id"]) == "family" and str(branches.get("vaelith", "")) == "spared" and champion_unlocked("vaelith"):
		lines.append(tr(GameData.PAYOFF_VAELITH_FAMILY))
	if str(c["id"]) == "choir" and str(branches.get("lantern", "")) == "poured":
		lines.append(tr(GameData.PAYOFF_LANTERN_CHOIR))
	if frag != "":
		lines.append(tr(frag))
	var choices := ["through", "back"]
	if str(c["id"]) == "choir" and truth_known("t_knock"):   # B8
		choices.append("sing")
	pending_stories.append({"kind": "crossing", "id": str(c["id"]), "title": tr(str(c["title"])), "subtitle": tr("A crossing, %s") % tr(str(GameData.BIOMES[run_biome()]["name"])),
		"text": "\n\n".join([tr(str(c["text"]))] + lines), "choices": choices})


## B9: the First Signatory comes once the Hall holds a guild that kept both
## worlds open and the guild knows whose Terms they were.
func signatory_open() -> bool:
	return crossings_answered >= 1 and _hall_has("both") and truth_known("t_terms_hers") and str(branches.get("signatory", "")) == ""


## Answers the crossing on top of the story queue: let them through (Renown
## falls a little) or turn them back (the Crown's bounty).
func answer_crossing(choice: String) -> void:
	if pending_stories.is_empty() or str(pending_stories[0].get("kind", "")) != "crossing":
		return
	var card: Dictionary = pending_stories.pop_front()
	crossings_answered += 1
	var signatory := str(card.get("id", "")) == "signatory"
	if signatory:
		branches["signatory"] = choice
	if choice == "sing":   # B8: the Choir sings the oath in the square
		crossings_through += 1
		add_reputation(GameData.CHOIR_SING_RENOWN)
		for h in heroes:
			change_morale(h, GameData.CHOIR_SING_MORALE)
		if not keepers() and breach.is_empty() and campaign_act >= GameData.BREACH_UNLOCK_ACT:
			breach_next_day = day + 2   # the song carries down
		pending_stories.push_front(GameData.CHOIR_SANG.duplicate())
		_news(tr("%s: they sang the oath in the square.") % str(card["title"]))
	elif choice == "through":
		crossings_through += 1
		var lost := crossing_renown()
		reputation = maxi(0, reputation - lost)
		if lost > 0:
			_news(tr("%s: let through. The villages are frightened (-%d Renown).") % [str(card["title"]), lost])
		else:
			_news(tr("%s: let through. Hollin takes them in.") % str(card["title"]))
		lore_event("through", "through")
		if signatory:   # B9: she joins, and opens her satchel
			var s: Hero = null
			for i in 40:
				s = Combat.gen_hero("A", 5)
				if s.cls_id == "cleric":
					break
			s.quirks = s.quirks.filter(func(q): return GameData.QUIRKS.get(q, {}).get("origin", "") != "born")
			s.quirks.append("Hollow-born")
			s.history["signatory"] = 1   # her own portrait (GameData.hero_portrait)
			heroes.append(s)
			var page := lore_event("signatory", "through")
			pending_stories.push_front({"title": tr("The First Signatory"), "subtitle": tr("She joins the guild"), "text": page if page != "" else tr(str(GameData.FRAGMENTS["f_first_page"]["text"]))})
	else:
		var bounty: int = GameData.SIGNATORY_BOUNTY if signatory else crossing_bounty()
		coins += bounty
		_news(tr("%s: turned back. The Crown pays its bounty (+%d Gold).") % [str(card["title"]), bounty])
	save()
	state_changed.emit()


## Book II's ending, by what this guild did on the way: the crossings it let
## through, and Brannoch's door (B7).
func _sky_payoffs(choice: String) -> Array:
	var p: Dictionary = GameData.PAYOFF_SKY
	var lines: Array = []
	if choice == "both":
		lines.append(tr(str(p["both_some" if crossings_through > 0 else "both_none"])))
	elif crossings_through > 0:
		lines.append(tr(str(p["ours_some"])))
	match str(branches.get("brannoch", "")):
		"left":
			lines.append(tr(str(p["brannoch_left_" + choice])))
		"freed":
			lines.append(tr(str(p["brannoch_freed"])))
	return lines


## Book II's ending, after Act VI: both worlds (Hollow-born recruits from now
## on, in later guilds too) or ours (Laurels; the Hollow's foes leave the ladder).
func choose_sky_ending(choice: String) -> void:
	if sky_ending != "" or not GameData.SKY_ENDING.has(choice):
		return
	sky_ending = choice
	if not pending_stories.is_empty() and str(pending_stories[0].get("kind", "")) == "sky":
		pending_stories.pop_front()
	if legacy.is_empty():
		load_legacy()
	for g in legacy.get("guilds", []):   # the Hall of Guilds remembers how Book II ended
		if str(g.get("name", "")) == guild_name and not g.get("retired", false):
			g["sky"] = choice
	if choice == "both":
		legacy["hollowborn"] = true
		save_legacy()
	else:
		_add_postgame_laurels(GameData.SKY_OURS_LAURELS)   # saves the legacy too
	var e: Dictionary = GameData.SKY_ENDING[choice]
	pending_stories.push_front(_the_end_card())
	if epilogue_open():   # the first signature
		var ep: Dictionary = GameData.EPILOGUE_CHOICE.duplicate(true)
		var seen: Array = []   # payoffs: who is in the square
		if charter_choice == "expose":
			seen.append(tr(GameData.PAYOFF_EXPOSED))
		if heroes.any(func(h): return h.history.has("morrow")):
			seen.append(tr(GameData.PAYOFF_MORROW))
		if not seen.is_empty():
			ep["text"] = tr(str(ep["text"])) + "\n\n" + "\n\n".join(seen)
		pending_stories.push_front(ep)
	pending_stories.push_front({"title": tr(str(e["title"])), "subtitle": tr(str(e["subtitle"])), "text": _with_lines(tr(str(e["text"])), _sky_payoffs(choice)), "art": "sky_" + choice})
	_news(tr(str(e["title"])) + ".")
	save()
	state_changed.emit()



# ---------------- The daily twist on the ladder ----------------

static func daily_id() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


## Today's twist: rule, starting boon, region and seed.
func daily_info(day: int = -1) -> Dictionary:
	if day < 0:
		day = daily_id()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["daily", day])
	var rules: Array = GameData.TOWER_RULES.filter(func(r): return not r.has("party_cap"))
	var rule: Dictionary = rules[rng.randi() % rules.size()]
	var boon: Dictionary = GameData.BOONS[rng.randi() % GameData.BOONS.size()]
	var biomes := ["vale", "marsh", "ashen"]
	return {"day": day, "rule": rule, "boon": str(boon["id"]),
		"biome": biomes[rng.randi() % biomes.size()], "seed": rng.randi()}


func daily_available() -> bool:
	return feature_unlocked("daily") and daily_attempt_day != daily_id()


func _apply_daily(diff: Dictionary) -> Dictionary:
	var rule: Dictionary = daily_info(int(run["daily"]))["rule"]
	var d := diff.duplicate(true)
	d.merge(rule.get("diff", {}), true)
	var hp := float(d["monster_hp"]) * float(d.get("hp_mult", 1.0)) * (2.0 if d.get("tower_single", false) else 1.0)
	d["monster_hp"] = int(round(hp))
	d["monster_dmg"] = int(round(float(d["monster_dmg"]) * float(d.get("dmg_mult", 1.0))))
	return d


## Sealing a rift with today's twist: the bonus, and the streak.
func _complete_daily() -> Dictionary:
	var day := int(run["daily"])
	daily_clears += 1
	daily_streak = daily_streak + 1 if daily_last_clear == day - 1 else 1
	daily_last_clear = day
	var cr := GameData.DAILY_CLEAR_CRYSTALS + GameData.DAILY_CLEAR_CRYSTALS_PER_ACT * mini(campaign_act, 3)
	crystals += cr
	return {"crystals": cr, "streak": daily_streak}


# ---------------- Records: run history, memorial ----------------

func _run_label() -> String:
	if run.has("descent"):
		return tr("The Descent · depth %d") % int(run["descent"])
	if str(run.get("rift_rank", "")) != "":
		return tr("Rank %s rift") % tr(str(run["rift_rank"])) + (tr(" · daily twist") if run.has("daily") else "")
	if int(run.get("finale", 0)) > 0:
		return tr("Act %s finale") % tr(str(_roman(int(run["finale"]))))
	return str(_diff().get("name", tr("Rift")))


## Appends the run that's ending to run_history (newest first).
func _record_run(outcome: String) -> void:
	if run.is_empty() or run.has("tower"):
		return
	var names: Array = []
	for h in current_party():
		names.append(h.name.split(" the ")[0])
	var entry := {"day": day, "kind": _run_label(), "result": outcome,
		"floor": "%d/%d" % [mini(int(run.get("pos", 0)) + 1, (run.get("layers", []) as Array).size()), (run.get("layers", []) as Array).size()],
		"heroes": names, "boons": run.get("boons", []),
		"coins": coins - int(run.get("start_coins", coins)), "crystals": crystals - int(run.get("start_crystals", crystals))}
	run_history.push_front(entry)
	if run_history.size() > GameData.RUN_HISTORY_MAX:
		run_history.resize(GameData.RUN_HISTORY_MAX)
	runs_finished += 1


## A key (English): compared, and kept in run history; shown translated.
func _run_outcome() -> String:
	if run.get("sealed") != null:
		return "Sealed"
	var res: Dictionary = run.get("node_state", {}).get("result", {})
	if bool(res.get("retreated", false)):
		return "Retreated"
	if not res.is_empty() and not bool(res.get("won", true)):
		return "Defeated"
	return "Left"


## Remembers a hero lost for good (left behind in a rift).
func _memorialize(h: Hero, cause: String) -> void:
	fallen.push_front({"name": h.name, "cls_id": h.cls_id, "pool_id": h.pool_id, "rank": h.rank, "level": h.level,
		"day": day, "cause": cause, "rifts": int(h.history.get("rifts_cleared", 0)), "kills": int(h.history.get("kills", 0)),
		"line": memorial_line(h)})
	heroes_lost_total += 1
	note_milestone("first hero lost")


# ---------------- Run boons ----------------

func boon_family_counts() -> Dictionary:
	var counts := {}
	for id in run.get("boons", []):
		var fam := str(GameData.find_boon(str(id)).get("family", ""))
		if fam != "":
			counts[fam] = int(counts.get(fam, 0)) + 1
	return counts


## Three boons not yet owned; when you already lean into a family, one slot
## favours it so a build can come together.
func roll_boon_offer(size: int = GameData.BOON_OFFER_SIZE) -> Array:
	var owned: Array = run.get("boons", [])
	var pool: Array = GameData.BOONS.filter(func(b): return not owned.has(b["id"])).map(func(b): return str(b["id"]))
	pool.shuffle()
	var offer: Array = []
	var counts := boon_family_counts()
	if not counts.is_empty():
		var fams := counts.keys()
		var fav := str(fams[randi() % fams.size()])
		for id in pool:
			if GameData.find_boon(id)["family"] == fav:
				offer.append(id)
				break
	for id in pool:
		if offer.size() >= size:
			break
		if not offer.has(id):
			offer.append(id)
	return offer


## Takes offered boon `idx` (or -1 to skip) from the current fight's result.
func pick_boon(idx: int) -> void:
	var ns: Dictionary = run.get("node_state", {})
	var res: Dictionary = ns.get("result", {})
	var offer: Array = res.get("boon_offer", [])
	if ns.get("boon_chosen", false) or offer.is_empty():
		return
	if idx >= 0 and idx < offer.size():
		var boons: Array = run.get("boons", [])
		boons.append(str(offer[idx]))
		run["boons"] = boons
		if boon_family_counts().values().any(func(n): return int(n) >= 4):
			boon_set4_reached = true
	ns["boon_chosen"] = true
	run["node_state"] = ns
	save()
	state_changed.emit()


func boon_pending() -> bool:
	var ns: Dictionary = run.get("node_state", {})
	return not (ns.get("result", {}).get("boon_offer", []) as Array).is_empty() and not ns.get("boon_chosen", false)


# ---------------- Tower of Trials ----------------

static func tower_week_id() -> int:
	return int(Time.get_unix_time_from_system() / 604800.0)


func _tower_roll_week() -> void:
	if tower_week != tower_week_id():
		tower_week = tower_week_id()
		tower_week_cleared = 0


## The floor a new attempt fights: the next uncleared one, or, once floor 90
## is cleared, this week's next ladder floor (91-100). 0 = nothing left this week.
func tower_next_floor() -> int:
	_tower_roll_week()
	var from := GameData.TOWER_WEEKLY_FROM
	if tower_best < from - 1:
		return tower_best + 1
	var f := from + tower_week_cleared
	return f if f <= GameData.TOWER_FLOORS else 0


## Everything fixed about a floor: its fight kind, region, guardian, rules
## (seeded by the floor; floors 91+ also by the week) and first-clear reward.
func tower_floor_info(f: int) -> Dictionary:
	var boss: Dictionary = GameData.TOWER_BOSSES.get(f, {})
	var weekly := f >= GameData.TOWER_WEEKLY_FROM
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["tower", f, tower_week_id() if weekly else 0])
	var rules: Array = []
	if boss.is_empty() and f > 5:
		var pool: Array = GameData.TOWER_RULES.duplicate()
		for i in (2 if weekly else 1):
			rules.append(pool.pop_at(rng.randi() % pool.size()))
	var cap := 4
	for r in rules:
		cap = mini(cap, int(r.get("party_cap", 4)))
	return {"floor": f, "kind": "boss" if not boss.is_empty() else ("elite" if f % 5 == 0 else "combat"),
		"biome": str(boss.get("biome", ["vale", "marsh", "ashen"][((f - 1) / 10) % 3])),
		"boss": boss, "rules": rules, "weekly": weekly, "party_cap": cap, "seed": rng.randi(), "reward": tower_reward(f)}


## First-clear reward for a floor (every 5th floor pays extra Crystals). A
## weekly re-clear pays half the Coins and Crystals and nothing else.
func tower_reward(f: int) -> Dictionary:
	return {"coins": 20 + 4 * f, "crystals": 8 + int(1.5 * f) + ((2 + f / 10) if f % 5 == 0 else 0),
		"relic": GameData.TOWER_RELICS.get(f, {})}


## Fit to the balance sim: a party of this power clears about half its tries.
## Party power whose climb typically ends around floor f (balance_sim
## -- calibrate), interpolated between measured points.
const TOWER_REC := [[1, 60], [5, 140], [10, 250], [20, 650], [45, 1000], [70, 1500], [85, 2200], [100, 2600]]


func tower_recommended_power(f: int) -> int:
	for i in range(1, TOWER_REC.size()):
		if f <= int(TOWER_REC[i][0]):
			var a: Array = TOWER_REC[i - 1]
			var b: Array = TOWER_REC[i]
			return int(round(lerpf(float(a[1]), float(b[1]), clampf(float(f - int(a[0])) / float(int(b[0]) - int(a[0])), 0.0, 1.0))))
	return int(TOWER_REC[-1][1])


func _tower_diff(info: Dictionary) -> Dictionary:
	var f := int(info["floor"])
	var d := {"id": "tower", "name": "Tower of Trials", "floors": 1, "power": "Trial",
		"coin": [0, 0], "crystal": [0, 0], "seal_essence": 0, "cache_chance": 0.0,
		"rec_power": tower_recommended_power(f), "biome": info["biome"]}
	for r in info["rules"]:
		d.merge(r.get("diff", {}), true)
	var hp := float(GameData.TOWER_BASE["monster_hp"]) * pow(1.0 + GameData.TOWER_HP_GROWTH, f - 1) * float(d.get("hp_mult", 1.0))
	if d.get("tower_single", false):
		hp *= 2.0
	d["monster_hp"] = int(round(hp))
	d["monster_dmg"] = int(round(float(GameData.TOWER_BASE["monster_dmg"]) * pow(1.0 + GameData.TOWER_DMG_GROWTH, f - 1) * float(d.get("dmg_mult", 1.0))))
	var boss: Dictionary = info["boss"]
	if not boss.is_empty():
		d["boss_name"] = str(boss["name"])
		d["boss_mechanics"] = boss["mechanics"]
	return d


func tower_title() -> String:
	var t := ""
	for e in GameData.TOWER_TITLES:
		if tower_best >= int(e[0]):
			t = str(e[1])
	return t


## Pays a cleared floor (from _apply_combat_outcome, once) and returns what
## it paid for the result screen.
func _complete_tower_floor(f: int) -> Dictionary:
	var first := f > tower_best
	var rw := tower_reward(f)
	var got := {"floor": f, "first": first, "coins": int(rw["coins"]), "crystals": int(rw["crystals"]), "relic": "", "title": ""}
	if first:
		var rdef: Dictionary = rw["relic"]
		if not rdef.is_empty():
			var r := Combat.relic_from_unique(rdef)
			r.equipped = Combat.equipped_relics().size() < relic_slot_cap()
			relics.append(r)
			got["relic"] = r.name
		var old_title := tower_title()
		tower_best = f
		if tower_title() != old_title:
			got["title"] = tower_title()
	else:
		got["coins"] = int(got["coins"]) / 2
		got["crystals"] = int(got["crystals"]) / 2
	if f >= GameData.TOWER_WEEKLY_FROM:
		_tower_roll_week()
		tower_week_cleared = maxi(tower_week_cleared, f - GameData.TOWER_WEEKLY_FROM + 1)
	coins += int(got["coins"])
	crystals += int(got["crystals"])
	return got


func _end_tower() -> void:
	var snap: Dictionary = run.get("tower_snap", {})
	for h in current_party():
		if snap.has(h.id):
			var s: Array = snap[h.id]
			h.hp = int(s[0])
			h.down_runs = int(s[1])
			h.bedded = bool(s[2])
	run = {}
	_clamp_hp_to_max()
	save()
	state_changed.emit()


# ---------------- Legacy ----------------
## The Laurels this guild leaves the next ones (GameData.LAURELS).
func laurels_earned() -> int:
	var L: Dictionary = GameData.LAURELS
	var n := clampi(campaign_act - 1, 0, GameData.CAMPAIGN.size()) * int(L["act"])
	n += int(L["ending"]) if accord_ending != "" else 0
	n += GameData.REWRITE_LAURELS if accord_ending == "rewrite" else 0
	n += posts_freed() * int(L["freed"])
	n += int(L["charter"]) if charter_result == "won" and str(branches.get("hearing", "")) != "bought" else 0
	n += int(L["morrow"]) if morrow_defeated else 0
	n += echoes_returned * int(L["echo"])
	n += GameData.GRUDGE_LAURELS if grudge != "" and charter_result == "won" and str(branches.get("hearing", "")) != "bought" else 0   # an old score settled
	return int(round(n * (1.0 + oath_bonus()) * (GameData.EPILOGUE_READ_LAURELS if moot() else 1.0)))


## The Laurels bonus for the oaths sworn (GameData.OATHS, capped).
func oath_bonus() -> float:
	var b := 0.0
	for o in oaths:
		b += float(GameData.OATHS.get(o, {}).get("laurels", 0.0))
	return minf(b, GameData.OATH_LAURELS_CAP)


## Heroes the Vale can remember: Rank C or higher, or 25 rifts sealed.
func legacy_candidates() -> Array:
	return heroes.filter(func(h): return not h.is_champion and (GameData.rank_index(h.rank) >= GameData.rank_index(GameData.LEGACY_MIN_RANK)
		or int(h.history.get("rifts_cleared", 0)) >= GameData.LEGACY_MIN_RIFTS))


## The Accord's ending is chosen and the guild's legacy isn't written yet.
func legacy_due() -> bool:
	return guild_name != "" and accord_ending != "" and not legacy_written


## A guild can retire once Act II is done (and not after its legacy is written).
func can_retire() -> bool:
	return guild_name != "" and campaign_act >= 3 and not legacy_written


## Writes this guild into the Vale's history: its record in the Hall of
## Guilds, up to LEGACY_HEROES remembered heroes as champions for later
## guilds (plus whoever took the forty-first post), and its Laurels.
## Returns the Laurels earned.
func write_legacy(hero_ids: Array, retired: bool = false) -> int:
	if legacy_written or guild_name == "":
		return 0
	if legacy.is_empty():
		load_legacy()
	var names: Array = []
	var ok := legacy_candidates()
	for hid in hero_ids.slice(0, GameData.LEGACY_HEROES):
		var h := find_hero(str(hid))
		if h and ok.has(h):
			_legacy_champion({"name": h.name, "cls_id": h.cls_id, "pool_id": h.pool_id, "rank": h.rank,
				"rifts": int(h.history.get("rifts_cleared", 0)), "kills": int(h.history.get("kills", 0))}, false)
			names.append(h.name.split(" the ")[0])
	if accord_ending == "renew" and str(branches.get("hesper", "")) == "signed":
		_legacy_champion({"name": "Hesper", "cls_id": "mage"}, true, "legacy_hesper",
			tr(GameData.HESPER_POST_LORE) % guild_name, tr(GameData.HESPER_POST_MEMORY) % guild_name)
		names.append("Hesper")
	elif accord_ending == "renew":
		for f in fallen:
			if str(f.get("name", "")).split(" the ")[0] == accord_hero:
				_legacy_champion(f, true)
				names.append(accord_hero)
				break
	# Only the most recent remembered heroes stay in the pool.
	var keys: Array = (legacy["champions"] as Dictionary).keys()
	keys.sort_custom(func(a, b): return int(legacy["champions"][a].get("at", 0)) > int(legacy["champions"][b].get("at", 0)))
	keys.erase("legacy_hesper")   # she waits at her post for as long as it takes
	for k in keys.slice(GameData.LEGACY_POOL):
		(legacy["champions"] as Dictionary).erase(k)
	var earned := laurels_earned()
	legacy["laurels"] = int(legacy["laurels"]) + earned
	(legacy["guilds"] as Array).append({"id": "g%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 100000],
		"name": guild_name, "crest": guild_crest, "ending": accord_ending, "retired": retired, "day": day, "act": campaign_act,
		"rifts": rifts_sealed, "laurels": earned, "remembered": names, "fallen": fallen.size(), "charter": charter_result,
		"quiet": charter_choice == "quiet", "founding": founding, "oaths": oaths.duplicate(), "year": vale_year.duplicate(true),
		"branches": branches.duplicate(), "fragments": lore_found_here.size(), "vale": vale_verdict() if echoes_seen.size() >= 3 else "",
		"rival": rival_name, "beat_rival": charter_result == "won", "colour": banner_colour})
	for key in [["bestiary", monsters_seen], ["beaten", bosses_defeated]]:   # one Bestiary across every guild
		var have: Array = legacy.get(key[0], [])
		for m in key[1]:
			if not have.has(m):
				have.append(m)
		legacy[key[0]] = have
	legacy_written = true
	save_legacy()
	save()
	state_changed.emit()
	return earned


## A remembered hero as a champion: their name, class and portrait, a Boon,
## Call and mods borrowed from a champion of the same role, and a lore and
## memory line from their history.
func _legacy_champion(src: Dictionary, post: bool, fixed_id: String = "", lore: String = "", memory_line: String = "") -> String:
	var role := str(src.get("cls_id", "warrior"))
	var same: Array = GameData.CHAMPIONS.keys().filter(func(k): return str(GameData.CHAMPIONS[k]["role"]) == role)
	if same.is_empty():
		same = GameData.CHAMPIONS.keys()
	same.sort()
	var first := str(src.get("name", "")).split(" the ")[0]
	var tpl: Dictionary = GameData.CHAMPIONS[same[absi(hash(first + guild_name)) % same.size()]]
	var rifts := int(src.get("rifts", 0))
	var id := fixed_id if fixed_id != "" else "legacy_%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 100000]
	var memory := tr(GameData.LEGACY_POST_MEMORY) % guild_name if post else ""
	if not post:
		var m := str(GameData.LEGACY_MEMORY[absi(hash(first)) % GameData.LEGACY_MEMORY.size()])
		memory = tr(m) % ([guild_name, rifts] if m.find("%s") < m.find("%d") else [rifts, guild_name])
	if memory_line != "":
		memory = memory_line
	legacy["champions"][id] = {"name": first, "guild": guild_name, "role": role, "post": post, "at": int(Time.get_unix_time_from_system()),
		"boon": (tpl["boon"] as Dictionary).duplicate(), "call": (tpl["call"] as Dictionary).duplicate(), "mods": (tpl["mods"] as Array).duplicate(),
		"portrait": GameData.portrait_for_hero(role, str(src.get("pool_id", ""))),
		"lore": lore if lore != "" else tr(GameData.LEGACY_POST_LORE) % guild_name if post else tr(GameData.LEGACY_LORE) % [tr(str(src.get("rank", "F"))), guild_name, rifts, int(src.get("kills", 0))],
		"memory": memory}
	return id


## Spends Laurels on founding gifts for this new guild (GameData.LEGACY_GIFTS
## ids); a gift it can't afford is skipped. Returns the ones applied.
func apply_legacy_gifts(ids: Array) -> Array:
	var applied: Array = []
	for g in GameData.LEGACY_GIFTS:
		if not ids.has(g["id"]) or int(legacy.get("laurels", 0)) < int(g["cost"]) or not gift_open(g):
			continue
		legacy["laurels"] = int(legacy["laurels"]) - int(g["cost"])
		match str(g["id"]):
			"gold":
				coins += 300
			"hero":
				heroes.append(Combat.gen_recruit("D"))
			"relic":
				var r := Combat.gen_relic("rare")
				r.id = "rl" + str(next_id)
				next_id += 1
				r.equipped = true
				relics.append(r)
			"barracks":
				upgrades["ops.barracks"] = maxi(1, int(upgrades.get("ops.barracks", 0)))
			"contacts":
				for i in 2:
					var c := Combat.gen_recruit("C")
					_post_offer(c, int(GameData.RECRUIT_STAY[1]), 0)
			"veteran":
				_veteran_start()
			"clerks_copy":
				accord_pages = maxi(accord_pages, 2)
				hear_ledger_claims()
			"pips_key":
				branches["key_gift"] = "yes"
		applied.append(g["id"])
	if not applied.is_empty():
		save_legacy()
		save()
	return applied


## A founding gift is open: some need a truth (the Unwritten Accord).
func gift_open(g: Dictionary) -> bool:
	return lore_option_open(g)


## B5: Hesper can sign the forty-first line in this guild's Renew ending.
func hesper_can_sign() -> bool:
	return truth_known("t_blank_line") and not hesper_posted()


## The veteran start (a Laurels gift): Act I done, the way a quick guild
## finishes it. Act I's own completion runs (its reward, relic and cards).
func _veteran_start() -> void:
	if campaign_act >= 2:
		return
	_in_veteran = true
	for h in heroes:
		while h.level < GameData.VETERAN_LEVEL:
			Combat.gain_xp(h, Combat.xp_to_next(h.level, h.rank))
	for r in GameData.VETERAN_RECRUITS:
		heroes.append(Combat.gen_recruit(str(r)))
	for i in GameData.VETERAN_GEAR:
		var it := Combat.gen_item("rare")
		it.id = "i%d" % next_id
		next_id += 1
		items.append(it)
	for i in 2:
		var rl := Combat.gen_relic("rare")
		rl.id = "rl" + str(next_id)
		next_id += 1
		relics.append(rl)
	for h in heroes:
		equip_best(h.id)
	runs_started = maxi(runs_started, 4)
	rifts_sealed = maxi(rifts_sealed, 3)
	best_rift_rank_sealed = maxi(best_rift_rank_sealed, GameData.rift_rank_index("E"))
	coins += GameData.VETERAN_GOLD
	crystals += GameData.VETERAN_ESSENCE
	var intro := str(_act_intro_card(1)["title"])
	pending_stories = pending_stories.filter(func(c): return str(c.get("title", "")) != intro)
	_complete_act(1)   # feature unlocks follow on the next render (Main)
	_in_veteran = false


## The playtest shortcut on the founding screen: Act I done, the way the
## veteran start does it, so testers can reach the middle game quickly.
func skip_act_one() -> void:
	if campaign_act >= 2:
		return
	_veteran_start()
	skipped_act1 = true
	save()


## ---- Founding charters ----
## Whether `id` can be picked: Free Company always; others once bought with
## Laurels, or by a deed a guild in the Hall of Guilds did.
func founding_unlocked(id: String) -> bool:
	var f: Dictionary = GameData.FOUNDINGS.get(id, {})
	if f.is_empty() or (id == "accord" and hesper_posted()) or not lore_option_open(f):   # Hesper's own guild, and she's at the post; a truth's charter
		return false
	if not f.has("laurels") and not f.has("deed"):
		return true
	if (legacy.get("charters", []) as Array).has(id):
		return true
	match str(f.get("deed", "")):
		"quiet":
			return (legacy.get("guilds", []) as Array).any(func(g): return g.get("quiet", false))
		"ending":
			return (legacy.get("guilds", []) as Array).any(func(g): return str(g.get("ending", "")) != "")
	return false


## Buys `id` with Laurels for good. Returns "" or why not.
func unlock_founding(id: String) -> String:
	var f: Dictionary = GameData.FOUNDINGS.get(id, {})
	if f.is_empty() or founding_unlocked(id):
		return ""
	if not f.has("laurels"):
		return tr("This charter is earned by a deed, not bought.")
	if not lore_option_open(f):
		return tr("This charter needs a truth first.")
	if int(legacy.get("laurels", 0)) < int(f["laurels"]):
		return tr("Not enough Laurels.")
	legacy["laurels"] = int(legacy["laurels"]) - int(f["laurels"])
	if not legacy.has("charters"):
		legacy["charters"] = []
	(legacy["charters"] as Array).append(id)
	save_legacy()
	return ""


## Founds this guild under charter `id` (before hiring the starters, whose
## first week's wages follow the charter): its Gold, its rival, its prologue.
func apply_founding(id: String) -> void:
	if not founding_unlocked(id):
		id = "free"
	founding = id
	coins += int(founding_rule("gold", 0))
	if epilogue() == "burn" and str(founding_rule("no_rival", "")) != "The Iron Chorus":   # royal patronage: the Crown's own company
		rival_name = "The Iron Chorus"
	var shunned := "The Last Lantern" if id == "smugglers" else str(founding_rule("no_rival", ""))
	if shunned != "" and rival_name == shunned:
		var others: Array = GameData.RIVAL_NAMES.filter(func(n): return n != shunned)
		rival_name = str(others[randi() % others.size()])
	if int(founding_rule("start_lab", 0)) > 0:
		upgrades["res.lab"] = maxi(int(founding_rule("start_lab", 0)), int(upgrades.get("res.lab", 0)))
	grudge = ""
	for g in legacy.get("guilds", []):   # a rival a past guild beat comes back with a grudge
		if str(g.get("rival", "")) == rival_name and bool(g.get("beat_rival", false)):
			grudge = str(g.get("name", ""))
	if id == "accord":
		for i in pending_stories.size():
			if str(pending_stories[i].get("title", "")) == str(GameData.PROLOGUE["title"]):
				pending_stories[i] = GameData.ACCORD_PROLOGUE.duplicate()


## ---- Keepers of the Vale (the Accord renewed) ----
## [Gold, Essence] to restore hall `id` next.
func hall_cost(id: String) -> Array:
	if id == "grandmaster":
		var forced := GameData.KEY_HALL_FORCED if str(branches.get("key", "")) == "broken" else 1.0   # B4: no key to open it
		return [int(round(int(GameData.GRANDMASTER_HALL_COST[0]) * forced)), int(round(int(GameData.GRANDMASTER_HALL_COST[1]) * forced))]
	var n := halls_restored.filter(func(h): return h != "grandmaster").size()
	return [int(GameData.HALL_COST[0]) + int(GameData.HALL_COST_STEP[0]) * n, int(GameData.HALL_COST[1]) + int(GameData.HALL_COST_STEP[1]) * n]


## "" if hall `id` can be restored now, else why not.
func hall_lock(id: String) -> String:
	if not keepers():
		return tr("Only Keepers of the Vale restore the old halls")
	if halls_restored.has(id):
		return tr("Restored")
	if id == "grandmaster" and halls_restored.size() < GameData.ACCORD_HALLS.size() - 1:
		return tr("Restore the other six halls first")
	var c := hall_cost(id)
	if coins < int(c[0]) or crystals < int(c[1]):
		return tr("Needs %d Gold and %d Essence") % [int(c[0]), int(c[1])]
	return ""


func restore_hall(id: String) -> String:
	var lock := hall_lock(id)
	if lock != "":
		return lock
	var c := hall_cost(id)
	coins -= int(c[0])
	crystals -= int(c[1])
	halls_restored.append(id)
	var hall: Dictionary = GameData.ACCORD_HALLS.filter(func(h): return h["id"] == id)[0]
	var htext := tr(hesper_alt("iron_oath", str(hall["text"])) if id == "iron_oath" else (GameData.KEY_HALL_TEXT if id == "grandmaster" and str(branches.get("key", "")) == "broken" else str(hall["text"])))
	var frag := lore_event("hall", id)
	pending_stories.append({"title": tr(str(hall["name"])), "subtitle": tr("Keepers of the Vale"), "text": htext + ("\n\n" + tr(frag) if frag != "" else "")})
	_news(tr("%s is restored.") % tr(str(hall["name"])))
	if id == "grandmaster":
		_add_postgame_laurels(GameData.GRANDMASTER_LAURELS, {"title": "Keepers of the Vale"})
	save()
	state_changed.emit()
	return ""


## What would raise the guild's power right now, with what it costs: the
## Whether the Act panel gives power advice for a best party of `best`: under
## 80% of the finale, once the finale is open or once the guild has spent
## ADVICE_STUCK_DAYS in the act (a guild too weak to meet the objectives: the
## 0.46 sim's Act V stalls were guilds losing half their runs, short of a
## Rank S seal or the crossings, that never saw the advice).
func advice_due(best: int) -> bool:
	if current_act().is_empty():
		return false
	return best < finale_recommended_power() * 0.8 and (finale_ready() or day - act_since >= GameData.ADVICE_STUCK_DAYS)


## Gold or Essence sitting idle: over three weeks' bill in Gold, or 300+
## Essence. The Grow goal then names something to spend it on even when the
## guild isn't stuck (0.61.1 sim: casual guilds sat on 10-26k Gold and
## 4-9k Essence because advice only showed when behind).
func spare_wealth() -> bool:
	return coins > 3 * (weekly_wages() + upkeep()) or crystals >= 300


## Act panel's advice when a finale is out of reach (casual guilds in the sim
## sat at 70-85% of a finale with 10-34k Gold and 5-15k Essence unspent).
## [{"kind", "text", "id", "choice"}], most useful first, at most three.
func power_advice() -> Array:
	var out: Array = []
	var bill := weekly_wages() + upkeep()
	for h in heroes:   # evolutions (0.62: a rank up at level 10, Gold and Essence)
		if h.is_champion or h.level < 10:
			continue
		var c := evolve_cost(h)
		if not c.is_empty() and evolve_lock(h) == "" and coins - int(c[0]) > bill:
			out.append({"kind": "evolve", "id": h.id, "choice": "",
				"text": tr("Evolve %s to Rank %s: %d Gold, %d Essence.") % [tr(str(h.name.split(" the ")[0])), tr(next_rank_of(h)), int(c[0]), int(c[1])]})
			break
	for h in heroes:   # a subclass training (0.62), the hero's own Path first
		if h.is_champion or not h.training.is_empty():
			continue
		var opts: Array = subclass_training_options(h).filter(func(o): return str(o["lock"]) == "" and not bool(o["change"]))
		if not opts.is_empty() and coins - int(opts[0]["cost"]["gold"]) > bill:
			var cls := GameData.find_class(str(opts[0]["id"]))
			out.append({"kind": "train", "id": h.id, "choice": str(opts[0]["id"]),
				"text": tr("Train %s as a %s at the Training Yard (stage %d): %d Gold, %d Essence.") % [tr(str(h.name.split(" the ")[0])), tr(str(cls.get("name", ""))), int(opts[0]["stage"]), int(opts[0]["cost"]["gold"]), int(opts[0]["cost"]["essence"])]})
			break
	var weakest := 99
	for h in heroes:
		if not h.is_champion:
			weakest = mini(weakest, GameData.rank_index(h.rank))
	var best_offer: Hero = null
	for o in recruit_pool:
		if GameData.rank_index(o.rank) > weakest and coins - int(GameData.find_rank(o.rank)["cost"]) > bill and (best_offer == null or GameData.rank_index(o.rank) > GameData.rank_index(best_offer.rank)):
			best_offer = o
	if best_offer:
		out.append({"kind": "recruit", "id": best_offer.id,
			"text": tr("Hire %s from the recruit board: Rank %s, %d Gold. Your weakest hero is Rank %s.") % [tr(str(best_offer.name.split(" the ")[0])), tr(best_offer.rank), int(GameData.find_rank(best_offer.rank)["cost"]), tr(str(GameData.RANKS[weakest]["id"])) if weakest < GameData.RANKS.size() else "?"]})
	var drill := GameData.find_branch_node("ops.drill")
	if feature_unlocked("management") and not drill.is_empty() and int(upgrades.get("ops.drill", 0)) < int(drill["max"]):
		var dcost := int(drill["cost_base"]) + int(drill["cost_step"]) * int(upgrades.get("ops.drill", 0))
		if crystals >= dcost:
			out.append({"kind": "drill", "id": "ops.drill",
				"text": tr("Build the Drill Yard to level %d: +4%% damage and health for every hero, %d Essence.") % [int(upgrades.get("ops.drill", 0)) + 1, dcost]})
	# Essence into power (0.61.3): the cheapest equipped relic level, then the
	# cheapest level of a Management node that strengthens the party (the
	# Drill Yard is above). Not slots or income: the sim's guilds took the
	# cheapest of any node, swelled to 16 heroes and hoarded more Gold.
	var relic: Relic = null
	for r in relics:
		if r.equipped and r.level < RELIC_MAX_LEVEL and relic_levels_up(r) and relic_upgrade_cost(r) <= crystals and (relic == null or relic_upgrade_cost(r) < relic_upgrade_cost(relic)):
			relic = r
	if relic:
		out.append({"kind": "relic", "id": relic.id,
			"text": tr("Upgrade %s on the Relic Altar to level %d: %d Essence.") % [tr(str(relic.name)), relic.level + 1, relic_upgrade_cost(relic)]})
	if feature_unlocked("management"):
		var best_key := ""
		var best_cost := 1 << 30
		for b in GameData.BRANCHES:
			for n in b["nodes"]:
				var key := "%s.%s" % [b["id"], n["id"]]
				var cur := int(upgrades.get(key, 0))
				var c := int(n["cost_base"]) + int(n["cost_step"]) * cur
				if key in ["res.lab", "res.vault", "infra.wardstones"] and cur < int(n["max"]) and c <= crystals and c < best_cost:
					best_key = key
					best_cost = c
		if best_key != "":
			var node := GameData.find_branch_node(best_key)
			out.append({"kind": "management", "id": best_key,
				"text": tr("Build %s to level %d (Guild Management): %s, %d Essence.") % [tr(str(node["name"])), int(upgrades.get(best_key, 0)) + 1, tr(str(node["every"])), best_cost]})
	# Gold into power (0.61): a hall wing, then the Forge, keeping payday's bill in hand.
	if hall_work_lock("war_room") == "" and coins - hall_work_cost() > bill:
		out.append({"kind": "hall_work", "id": "war_room",
			"text": tr("Rebuild the War Room (Guild Hall > Hall Works): +5%% damage and health for every hero, %d Gold.") % hall_work_cost()})
	var temper: Item = null
	for it in items:
		var h: Hero = find_hero(it.equipped_to) if it.equipped_to != "" else null
		var fc := forge_cost(it)
		if h and not h.is_champion and fc > 0 and coins - fc > bill and (temper == null or fc < forge_cost(temper)):
			temper = it
	if temper:
		out.append({"kind": "forge", "id": temper.id,
			"text": tr("Temper %s's %s at the Forge (their gear slot on the Roster): +%d%% to its stats, %d Gold.") % [tr(str(find_hero(temper.equipped_to).name.split(" the ")[0])), tr(str(temper.name)), int(GameData.FORGE_STEP * 100), forge_cost(temper)]})
	if overseer != "" and champion_level_cost(overseer) > 0 and crystals >= champion_level_cost(overseer):
		out.append({"kind": "champion", "id": overseer,
			"text": tr("Level %s to %d: a stronger Boon, %d Essence.") % [GameData.champion_full_name(overseer), champion_level(overseer) + 1, champion_level_cost(overseer)]})
	return out.slice(0, 3)


## Takes one piece of power_advice (the sims; the panel's own buttons are
## the screens it names). Returns "" or why not.
func follow_advice(a: Dictionary) -> String:
	match str(a.get("kind", "")):
		"evolve":
			return evolve_hero(str(a["id"]), str(a["choice"]))
		"recruit":
			if heroes.size() >= hero_slot_cap():   # make room: the weakest hero goes
				var weakest: Hero = null
				for h in heroes:
					if not h.is_champion and (weakest == null or GameData.rank_index(h.rank) < GameData.rank_index(weakest.rank)):
						weakest = h
				if weakest:
					dismiss_hero(weakest.id)
			return recruit_hero(str(a["id"]))
		"drill":
			return upgrade_node("ops.drill")
		"train":
			return start_subclass_training(str(a["id"]), str(a["choice"]))
		"hall_work":
			return build_hall_work(str(a["id"]))
		"relic":
			return upgrade_relic(str(a["id"]))
		"management":
			return upgrade_node(str(a["id"]))
		"forge":
			return forge_item(str(a["id"]))
		"champion":
			return level_champion(str(a["id"]))
	return ""


## The endowment: Gold for the next guild, a Laurel at a time.
func endow_cost() -> int:
	return GameData.ENDOW_COST + GameData.ENDOW_STEP * endowments


## Returns "" or why not.
func endow() -> String:
	if not legacy_written:
		return tr("Endowments open once the guild's legacy is written.")
	if coins < endow_cost():
		return tr("Not enough Gold.")
	coins -= endow_cost()
	endowments += 1
	_add_postgame_laurels(1, {"endowed": endowments})
	_news(tr("Gold set aside for the next guild: +1 Laurel."))
	save()
	state_changed.emit()
	return ""


## Laurels earned after the legacy was written go straight to the legacy,
## and the guild's Hall of Guilds record notes them (and `note`).
func _add_postgame_laurels(n: int, note: Dictionary = {}) -> void:
	if legacy.is_empty() or n <= 0:
		return
	legacy["laurels"] = int(legacy["laurels"]) + n
	for g in legacy.get("guilds", []):
		if str(g.get("name", "")) == guild_name and not g.get("retired", false):
			g["laurels"] = int(g.get("laurels", 0)) + n
			g.merge(note, true)
	save_legacy()


## ---- The completion board (both endings) ----
func board_done(id: String) -> bool:
	match id:
		"champions": return champions.size() >= champion_roll.size()
		"ledger": return accord_pages >= GameData.LEDGER_PAGES.size()
		"echoes": return echoes_seen.size() >= GameData.ECHOES.size()
		"morrow": return morrow_defeated
		"charter": return charter_result == "won"
		"halls": return halls_restored.size() >= GameData.ACCORD_HALLS.size()
		"tides": return tides_held >= 5
	return false


## Lines for this guild's ending, in board order.
func board_lines() -> Array:
	var as_ending := "renew" if accord_ending == "rewrite" else accord_ending   # rewritten: the halls are the Keepers' work
	return GameData.COMPLETION_BOARD.filter(func(l): return str(l.get("ending", as_ending)) == as_ending)


## Pays BOARD_LAURELS for each line finished since the legacy was written.
func check_completion_board() -> void:
	if not legacy_written:
		return
	for l in board_lines():
		var id := str(l["id"])
		if board_done(id) and not board_claimed.has(id):
			board_claimed.append(id)
			_add_postgame_laurels(GameData.BOARD_LAURELS)
			pending_toasts.append({"cls_id": "", "pool_id": "", "title": tr("The Chronicle grows"),
				"text": tr("%s: +%d Laurels.") % [tr(str(l["label"])), GameData.BOARD_LAURELS]})


# ---------------- Paths: subclass unlocks and training (0.62) ----------------
## Whether `pool_id`'s unlock (GameData.SUBCLASS_UNLOCK) is met by this guild.
func subclass_gate_met(pool_id: String) -> bool:
	var g: Dictionary = GameData.SUBCLASS_UNLOCK.get(pool_id, {})
	var role := str(GameData.find_class(pool_id).get("role", ""))
	for k in g:
		var v = g[k]
		match str(k):
			"act":
				if campaign_act <= int(v):
					return false
			"tower":
				if tower_best < int(v):
					return false
			"role_seals":
				if int(role_seals.get(role, 0)) < int(v):
					return false
			"flawless_boss":
				if flawless_bosses < int(v):
					return false
			"freed":
				if posts_freed() < int(v):
					return false
			"seal_rank":
				if best_rift_rank_sealed < GameData.rift_rank_index(str(v)):
					return false
			"riftbreak_rank":
				if riftbreak_best < GameData.rift_rank_index(str(v)):
					return false
	return true


func subclass_unlocked(pool_id: String) -> bool:
	return subclass_known.has(pool_id) or subclass_carried.has(pool_id) or subclass_gate_met(pool_id)


## What unlocks `pool_id`, in words ("" when it's open from the start).
func subclass_unlock_text(pool_id: String) -> String:
	var g: Dictionary = GameData.SUBCLASS_UNLOCK.get(pool_id, {})
	var role := str(GameData.find_class(pool_id).get("role", ""))
	var parts: Array[String] = []
	for k in g:
		var v = g[k]
		match str(k):
			"act": parts.append(tr("Act %s done") % tr(str(_roman(int(v)))))
			"tower": parts.append(tr("Tower of Trials floor %d") % int(v))
			"role_seals": parts.append(tr("seal %d rifts with a %s in the party (%d/%d)") % [int(v), tr(role.capitalize()), mini(int(role_seals.get(role, 0)), int(v)), int(v)])
			"flawless_boss": parts.append(tr("beat a rift boss by hand with no one down"))
			"freed": parts.append(tr("free a lost champion"))
			"seal_rank": parts.append(tr("seal a Rank %s rift") % tr(str(v)))
			"riftbreak_rank": parts.append(tr("hold a Rank %s Riftbreak") % tr(str(v)))
	return tr(" and ").join(parts)


## Notes every subclass training newly unlocked (a toast each, quiet for a
## new guild's starting set) and remembers it in the legacy for later guilds.
## Returns the newly unlocked ids.
func check_subclass_unlocks() -> Array:
	if guild_name == "":
		return []
	var fresh: Array = []
	var quiet := subclass_known.is_empty()
	var all_ids: Array = GameData.SUBCLASS_UNLOCK.keys()
	for pid in all_ids:
		if subclass_known.has(pid) or not (subclass_carried.has(pid) or subclass_gate_met(pid)):
			continue
		subclass_known.append(pid)
		fresh.append(pid)
		var remembered: Array = legacy.get("subclasses", [])
		if not remembered.has(pid):
			remembered.append(pid)
			legacy["subclasses"] = remembered
	if fresh.is_empty():
		return fresh
	save_legacy()
	if not quiet:
		for pid in fresh:
			var cls := GameData.find_class(pid)
			var path := GameData.path_of(pid)
			pending_toasts.append({"cls_id": str(cls.get("role", "")), "pool_id": pid, "title": tr("New training: %s") % tr(str(cls.get("name", pid))),
				"text": (tr("A Legend for every %s Path, trained at Rank S.") % tr(str(cls.get("role", "")).capitalize())) if path == "" else tr("%s, stage %d, at the Training Yard.") % [tr(str(GameData.PATHS[path]["name"])), GameData.subclass_stage(pid)]})
	return fresh


## The stage a hero would train next (1 for a base class), or 0 when done.
func next_training_stage(h: Hero) -> int:
	var st := GameData.subclass_stage(h.pool_id) + 1
	return st if st <= 3 else 0


## Every subclass `h` could train next: [{id, stage, change, cost, lock}],
## the hero's own Path first. Stage 1 offers every Path of the role.
func subclass_training_options(h: Hero) -> Array:
	var out: Array = []
	if h.is_champion:
		return out
	var st := next_training_stage(h)
	if st == 0:
		return out
	var role := GameData.hero_role(h)
	var own := h.path if h.path != "" else GameData.path_of(h.pool_id)
	var paths: Array = GameData.role_paths(role)
	if own != "":
		paths.erase(own)
		paths.push_front(own)
	for pid in paths:
		for sid in GameData.stage_options(str(pid), st):
			if GameData.is_legend(str(sid)) and str(pid) != own and own != "":
				continue   # a Legend keeps the hero's Path: listed once, under it
			var change: bool = st > 1 and str(pid) != own
			out.append({"id": str(sid), "path": str(pid), "stage": st, "change": change,
				"cost": GameData.training_cost(str(sid), change), "lock": subclass_training_lock(h, str(sid), change)})
	return out


## "" if `h` can start training `pool_id` now, else why not.
func subclass_training_lock(h: Hero, pool_id: String, change: bool = false) -> String:
	var st := GameData.subclass_stage(pool_id)
	if st != next_training_stage(h):
		return tr("Not the next stage")
	if GameData.rank_index(h.rank) < GameData.rank_index(str(GameData.STAGE_RANK[st])):
		return tr("Opens at Rank %s") % tr(str(GameData.STAGE_RANK[st]))
	if not subclass_unlocked(pool_id):
		return tr("Locked: %s") % subclass_unlock_text(pool_id)
	if not h.training.is_empty():
		return tr("Already training")
	if not h.is_available() or (run.get("hero_ids", []) as Array).has(h.id):
		return tr("Not here to train")
	if training_free() <= 0:
		return tr("Every station is taken")
	var c := GameData.training_cost(pool_id, change)
	if coins < int(c["gold"]) or crystals < int(c["essence"]):
		return tr("Needs %d Gold and %d Essence") % [int(c["gold"]), int(c["essence"])]
	return ""


## Sends `h` to the Training Yard to become `pool_id`: Gold and Essence up
## front, back in its days with the new subclass (_train_day finishes it).
func start_subclass_training(hero_id: String, pool_id: String) -> String:
	var h := find_hero(hero_id)
	if not h:
		return tr("No such hero")
	var opts: Array = subclass_training_options(h).filter(func(o): return str(o["id"]) == pool_id)
	if opts.is_empty():
		return tr("Not a training this hero can take")
	var o: Dictionary = opts[0]
	var lock := str(o["lock"])
	if lock != "":
		return lock
	var c: Dictionary = o["cost"]
	coins -= int(c["gold"])
	crystals -= int(c["essence"])
	var days := int(c["days"])
	h.training = {"program": "subclass:" + pool_id, "path": str(o["path"]), "left": days, "total": days,
		"fee": int(c["gold"]) / days, "essence": int(c["essence"]) / days}
	save()
	state_changed.emit()
	return ""


## Remembered unlocks a new guild can carry (legacy, not open from the start).
func carriable_subclasses() -> Array:
	return (legacy.get("subclasses", []) as Array).filter(func(sid): return GameData.carry_laurels(str(sid)) > 0)


## Founding: carries remembered subclass unlocks into this guild for Laurels
## (one it can't afford is skipped). Returns the ones carried.
func carry_subclasses(ids: Array) -> Array:
	var done: Array = []
	for sid in ids:
		var cost := GameData.carry_laurels(str(sid))
		if cost <= 0 or not carriable_subclasses().has(sid) or int(legacy.get("laurels", 0)) < cost:
			continue
		legacy["laurels"] = int(legacy["laurels"]) - cost
		subclass_carried.append(str(sid))
		done.append(sid)
	if not done.is_empty():
		save_legacy()
	return done
