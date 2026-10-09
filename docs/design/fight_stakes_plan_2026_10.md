# Fight stakes (0.68) implementation plan

**Goal:** build docs/design/fight_stakes_2026_10.md, which adds wounds from heavy blows and the cost of falling by rift rank, and ship it sim-checked as 0.68.

**Approach:**
- **Wounds:** a saved `Hero.wound` (absolute HP) is subtracted inside `Combat.max_hp`, so every heal and readout respects it. `base_max_hp` keeps the old formula.
- **Which runs have stakes:** one GameState helper, `stakes_rank()`.
- **Where the code goes:**
  - wounding in `Combat._monster_strike`;
  - closing in `_finish_combat`, the campfire Rest, the shrine and the run end (`_clamp_hp_to_max`);
  - fall costs in `GameState.fall_costs(h)`, called from `_finish_combat` in place of today's flat 50% scar roll.

**Stack:** Godot 4.7 GDScript. Tests run through `tests/run_tests.tscn` with `extends "res://tests/base_test.gd"` and `check(cond, msg)`. Sims: `tests/sim/campaign_sim.tscn` and `balance_sim`.

## Global constraints

- **Ranks:** wounds and fall costs from Rank C, wounds lasting the run from S, death at SS and SSS only.
- **Never in:** training fights, the Daily, the Tower, the Descent, breach rifts, or Story difficulty (`hardship < 0`, the same rule as the haul).
- **No fall costs before 3 seals.**
- **Knobs:** every number is a `var` in GameDataModes, so the sim can sweep it.
- **Text:** all player text through `tr()`, with Turkish, Spanish and Chinese added before the ship.
- **Players:** never assume a hero's gender in text ("them").
- **Commands:**
  - tests: `bash $S/gate.sh`
  - one test: `godot --headless --path . res://tests/run_tests.tscn -- <fragment>`
  - ship: `bash $S/ship.sh 0.68.0 msg.txt`
- **Godot runs:** never two at once.

## Found while planning (deviations from the spec)

- **Today, any knock-out scars at 50%,** at every rank (`Combat._finish_combat`). Following the spec, F-D falls stop scarring and C+ uses 15-35%. Flag this to the user at ship time.
- **The existing injury severity is called "wounded"** (`INJURY_*`). The new UI says "Wound −X max HP" to keep them apart.
- **Finales have no `rift_rank`:** they follow `highest_open_rank()`.
- **Story difficulty is excluded,** like the haul.

---

### Task 1: knobs, `Hero.wound`, `max_hp`, stakes helpers

**Files:** GameDataModes.gd (vars), Hero.gd (field and save), CombatStats.gd (`max_hp`, `base_max_hp`), GameStateRuns.gd (helpers), GameStateHeroes.gd (`_clamp_hp_to_max`). Test: tests/test_wounds.gd (new).

**Produces:**
- `Combat.base_max_hp(h) -> int`; `Combat.max_hp(h) = base_max_hp(h) - h.wound`, never below 1.
- `GameState.stakes_rank() -> String` ("" = no stakes).
- `GameState.wounds_on() -> bool`, `wounds_last_run() -> bool`, `fall_costs_on() -> bool`.
- `GameState.add_wound(h, dealt) -> int`, which returns the wound added.

```gdscript
# GameDataModes.gd
var WOUND_FROM_RANK := "C"
var WOUND_PERSIST_RANK := "S"
var WOUND_SHARE := 0.5          # of a wounding blow's damage
var WOUND_CAP := 0.6            # of base max HP
var WOUND_HEAVY_PCT := 0.25     # a hit this share of base max HP wounds, wind-up or not
var WOUND_REST_CLOSE := 0.5     # a campfire's Rest closes this share
var WOUND_SHRINE_CLOSE := 0.25  # a shrine closes this share of base max HP
var FALL_SCAR_CHANCE := {"C": 0.15, "B": 0.2, "A": 0.25, "S": 0.3, "SS": 0.35, "SSS": 0.35}
var FALL_DEATH_FROM_RANK := "SS"
var FALL_DEATH_CHANCE := 0.5
var FALL_COST_SEALS := 3
```

```gdscript
# GameStateRuns.gd
func stakes_rank() -> String:
	if run.is_empty() or hardship < 0 or run.get("training", false) or run.has("daily") or run.has("tower") or run.has("descent") or run.has("breach"):
		return ""
	return highest_open_rank() if int(run.get("finale", 0)) > 0 else str(run.get("rift_rank", ""))

func _stakes_at(rank_id: String) -> bool:
	var r := stakes_rank()
	return r != "" and GameData.rift_rank_index(r) >= GameData.rift_rank_index(rank_id)

func wounds_on() -> bool: return _stakes_at(GameData.WOUND_FROM_RANK)
func wounds_last_run() -> bool: return _stakes_at(GameData.WOUND_PERSIST_RANK)
func fall_costs_on() -> bool: return wounds_on() and rifts_sealed >= GameData.FALL_COST_SEALS
```

- Test (test_wounds): a Rank B ladder run with `rifts_sealed = 5`.
  - `wounds_on` is true, `wounds_last_run` is false.
  - `add_wound(h, 100)` on a hero with base 300 HP sets `wound` 50 and `max_hp` 250.
  - Another `add_wound(h, 1000)` caps at 180.
  - `hp` is clamped to the new max.
  - Rank E has no stakes, and neither does `run["daily"]`.
  - After `finish_run`, wound is 0.
  - `Hero.to_dict` / `from_dict` keep `wound`.

### Task 2: wounding blows, a sure wind-up, and closing

**Files:** Combat.gd (`_monster_strike`, `_start_round`, `_finish_combat`), GameStateRuns.gd (campfire Rest about line 560, shrine about line 805).

- **In `_monster_strike`,** where `dealt_back` lands (the `else` branch), wound if all hold:
  - `GameState.wounds_on()`;
  - no `guard` stepped in;
  - the target isn't defending;
  - the blow was a heavy blow, or `dealt_back >= base_max_hp(target) * WOUND_HEAVY_PCT`.

  Then `GameState.add_wound(target, dealt_back)`, tally `wounds`, and log "%s is wounded: -%d max HP.". Make `heavy_hit` read `base_max_hp`.
- **Tallies of avoided wounds,** for the sim: "wound_guarded", "wound_defended", "wound_dodged".
- **In `_start_round`:** if `GameState.wounds_on()`, the fight is an ordinary one, it's round 1 or 2, and `_sure_windup` isn't set, then on round 2 for certain (or round 1 at 50%) set `_winding` on one living, non-hasted, uncharged foe and set `state["_sure_windup"] = true`. A natural wind-up in rounds 1-2 also sets the flag.
- **In `_finish_combat`:** `if not GameState.wounds_last_run(): h.wound = 0` for the party.
- **Campfire Rest:** `h.wound = int(h.wound * (1.0 - WOUND_REST_CLOSE))` before the heal.
- **Shrine:** `h.wound = maxi(0, h.wound - int(base_max_hp(h) * WOUND_SHRINE_CLOSE))`.
- Test:
  - A forced charged foe hits an undefended hero: the wound is half the damage.
  - Defending gives no wound, a guard redirect gives no wound, and a dodge gives no wound.
  - Rank D gives no wound.
  - At C-A, the fight end clears the wound. At S, it keeps it, a campfire halves it and a shrine closes 25%.
  - At Rank C, an ordinary fight has a wind-up by round 2 (seeded loop over 20 fights).

### Task 3: the cost of falling

**Files:** GameStateRuns.gd (`fall_costs`, the drop and its return, death), Combat.gd (`_finish_combat`: replace the 50% scar roll), GameStateRuns `finish_run` / `retreat_now` (resolve drops).

```gdscript
## A hero knocked out in a fight with stakes (0.68): maybe a scar, maybe
## (SS/SSS, two scars) death, and one worn gear piece left in the rift.
func fall_costs(h: Hero) -> Array[String]
func fall_scar_chance(h: Hero) -> float   # rank chance x cleric 0.5 x Warding/Aegis 0.75 each x Healers' Wing 0.5
func death_risk(h: Hero) -> bool          # for the Party screen: the rank is SS+ and the hero has SCARS_MAX scars
```

- **Order:**
  1. **Death:** if `death_risk` and `randf() < FALL_DEATH_CHANCE`, the hero dies. Add their id to `run["dead"]` and log it, but take them out of play only at run end. Unequip their gear to the inventory then, return their Path relic, and `_memorialize(h, "Fell in a Rank %s rift")`.
  2. **Scar:** `randf() < fall_scar_chance(h)` → `Combat.roll_scar`.
  3. **Drop:** once per hero per run. Pick a random equipped gear item: remove it from `items` and store its dict in `run["dropped"][h.id]`.
- **Resolving drops:**
  - `finish_run` with a seal: each dropped item goes back to `items`, re-equipped to its hero if they live and the slot is free. Log "recovered".
  - Otherwise (falls, retreats, leaving): the item is lost, with a news line.
  - `retreat_now`: always lost.
- **Dead heroes in the run:** excluded from `pending_injuries` and fetching.
- **Today's 50% scar roll** in `_finish_combat` is replaced by `log.append_array(GameState.fall_costs(h))`. The roll survives only where stakes are off and the context is the old one: none. Drop it.
- Test:
  - Seeded chances: a cleric halves the scar chance, and Rank B gives 0.2.
  - A drop removes one item and a seal returns it; a retreat loses it; a second fall drops nothing; relics are never touched.
  - Death only at SS with two scars: the hero leaves the roster at run end and gets a memorial entry.
  - No costs with `rifts_sealed = 2`, the Daily, training or Story.

### Task 4: auto-fight guards an ally from a heavy blow

**Files:** Combat.gd `auto_action`.

- After the self-defend check: if a foe's intent is `heavy_blow` aimed at an ally, the acting hero can't break it (no `shield_bash` / `frost_nova` ready), and `action_block(state, h, "guard") == ""`, return `{"action": "guard", "target": 0, "ally": target.id}`. Use the same shape the UI's Guard sends; check `_resolve_hero_action`.
- Test: a forced heavy-blow intent on h2, with h1 a warrior without a bash, makes `auto_action(h1)` guard h2.

### Task 5: screens

**Files:** UiKit.gd `_hp_bar`, BattleView.gd plates, RiftRunView.gd (map strip, intent text), Main/GuildViews rift cards and Party screen, GameDataArt `FEATURE_UNLOCKS` + `feature_unlocked`, the Library's Systems topics, `Combat.defeat_reasons`.

- **HP bars:** a dark wound segment at the right end, a ColorRect sized `wound / base_max_hp`, with tooltip "Wound -%d max HP (heavy blows; closes %s)".
- **Intent:** `describe_incoming` and the intent tag at C+ read "Heavy blow: wounds unless guarded or defended".
- **Run map at S+:** "Wounds: -%d max HP" and "Dropped: %s" beside Resolve and the haul.
- **Rift cards:**
  - C-A: "Heavy blows wound. A fall can scar and drop gear."
  - S+: "Wounds last until a campfire."
  - SS+: "...and a twice-scarred hero can die."
- **Party screen:** "%s has two scars: a fall here can kill them." for each `death_risk` hero.
- **Reveals:**
  - `"wounds"`: Wen, unlocked when `ladder_rank_lock("C") == ""` and C is open.
  - `"wounds_run"`: Wen, when `ladder_rank_lock("S") == ""`.
- **Library topic** "Wounds and falls".
- **Defeat line:** "%d wound%s from heavy blows taken unguarded".
- Test: `test_ui_smoke`'s existing fixture renders a C+ rift card and a battle with a wounded hero, with no errors and the wound line present.

### Task 6: sim, tuning, calibration

**Files:** tests/sim/campaign_sim.gd, tests/sim/balance_sim.gd (calibrate), GameDataModes (knobs).

- **Counters:**
  - wounds taken and avoided;
  - boss-door HP share (run party HP / base max at the boss node, S+);
  - falls per run;
  - fall scars, drops, recoveries and deaths;
  - ordinary-fight win rate at C-A.
- **Runs,** none at the same time:
  1. Baseline from the last runs.
  2. `days=45 seeds=8 advice` with the change.
  3. Tune `WOUND_SHARE` / `WOUND_HEAVY_PCT` / the sure wind-up until the spec's targets hold.
  4. `balance_sim -- calibrate` for the rank `rec` values and finales, if seals at Recommended move off about 65%.
- If a target can't be met by these knobs, stop and report to the user.

### Task 7: ship 0.68

- What's New (en, tr, es, zh).
- Translate the new strings with `i18n_extract --merge` and check them with check.py.
- `gate.sh`, then `ship.sh 0.68.0`.
- Update the spec's status, the 05 roadmap, memory and the knowledge pack.
