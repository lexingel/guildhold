extends "res://tests/base_test.gd"
## Story cards' pictures (0.48): every act, big choice and ending finds its own.


func run() -> void:
	for n in range(1, 7):
		check(GameData.story_art({"act_intro": n}).ends_with("act_%d.png" % n) and GameData.story_art({"act_outro": n}) == GameData.story_art({"act_intro": n}), "Act %d's intro and outro share a picture" % n)
	for card in [GameData.PROLOGUE, GameData.ACCORD_PROLOGUE, GameData.CHARTER_TURN, GameData.SPIRE_CHOICE, GameData.VAELITH_CHOICE, GameData.ACCORD_CHOICE,
			GameData.BRANNOCH_CHOICE, GameData.SKY_CHOICE, GameData.EPILOGUE_CHOICE]:
		check(GameData.story_art(card) != "", "%s has a picture" % str(card["title"]))
	for id in ["ending_renew", "ending_break", "ending_rewrite", "sky_both", "sky_ours", "epilogue_read", "epilogue_burn", "sky_beneath"]:
		check(GameData.story_art({"art": id}) != "", "%s has a picture" % id)
	check(GameData.story_art({"title": "A plain card"}) == "", "a card without one shows none")

	# The cards the game builds carry their picture.
	GameState.active_slot = 9
	GameState.reset()
	GameState.hire_starters()
	GameState.campaign_act = 5
	GameState.pending_stories.clear()
	GameState.choose_accord_ending("break")
	check(GameState.pending_stories.any(func(c): return str(c.get("art", "")) == "ending_break"), "the Break ending's card")
	check(GameState.pending_stories.any(func(c): return str(c.get("art", "")) == "sky_beneath"), "and Book II's opening")
	check(GameState.pending_stories.any(func(c): return int(c.get("act_intro", 0)) == 5), "and Act V's intro")
	GameState.delete_slot(9)
