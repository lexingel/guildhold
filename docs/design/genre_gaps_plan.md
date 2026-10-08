# Closing the genre gaps (plan, 2026-10-08)

Follows the market comparison report ("Guildhold Genre Gaps", 0.63.0) and covers
gaps 1, 3, 4, 5 and 6. Gap 2 (Steam) is left out on purpose.
The revamp's rule still holds: **new texture, no new rules**. Each piece below
uses what the player already does (pick a route, rest at a campfire, pick
1 of 3, answer an event) and reuses code that already exists.

| Version | Piece | Gap | Size |
|---|---|---|---|
| 0.64 | Resolve, which wears the party down during a run | 1 | M |
| 0.65 | Path relics: 30 rule-bending relics, a pick of 3 when a rift is sealed | 3 | M |
| 0.66 | More events: 15 camp events and 20 hero requests; hero rename and titles | 4, 6a | M |
| 0.67 | Hardships 1-10 and a Story setting | 5 | S-M |
| 0.68 | Action preview on hover; key rebinding | 6b, 6c | S |
| 0.69 | Sound pass, from 24 to about 70 effects | 6f | M |
| 0.70 | Spanish, then Simplified Chinese | 6e | L |
| any time | Daily leaderboard on the relay | 6d | S |

Order: Resolve comes first because some relics, events and Hardships act on
it. Hardships come after relics, so the calibration includes relic power.
Each version ships with tests, a campaign_sim pass, Turkish, What's New and
knowledge-pack updates, the usual way.

---

## 0.64: Resolve (gap 1: nothing wears the party down)

**Problem.** Ordinary fights are won 99% of the time from 97% party HP, and
number sweeps can't fix that, because combat is burst (0.61 audit). Floors
before the boss are filler, so the lane map's route choice carries little
weight.

**Rule.** A party enters a rift with **10 Resolve**. It is shown as a lantern
with pips on the run bar, next to the haul.

| Drains | Amount |
|---|---|
| Each floor advanced (`advance_node`) | -1 |
| An elite won | -1 more |
| A hazard: push through / risk | -1 / -2 |
| Fleeing a fight | -2 |

| Restores | Amount |
|---|---|
| Campfire Rest (it still heals 25%) | +3 |
| Path shrine | +2 |
| Some rift events (new `resolve` effect key) | +1 to +3 |
| A few Path relics and camp events (0.65/0.66) | varies |

| Resolve | State | Effect in every fight |
|---|---|---|
| 4-10 | Steady | none |
| 1-3 | Wavering | foes act first in round 1 (put ahead of heroes in `_compute_turn_order`) |
| 0 | Broken | as Wavering, plus heroes start at 0 Momentum and deal -15% damage |

A careful route reaches the boss at about 5-6 Resolve and is fine. A greedy
route (elites, risked hazards, treasure behind an elite) reaches it Wavering
unless it detours through a shrine. That gives the lane map and the
Trapper/Stalker scouting a real payoff, without making ordinary fights hit
harder.

**Scope**
- Off in the Tower, the training rift and the 3-seal haul grace (the same gate
  as `haul_at_risk`), so new players meet it at about Rank E.
- Breach rifts: they start at 10 and are only 3 fights long, so in practice
  there is no effect.
- The Descent: -1 per depth; landings with a campfire restore it.

**Code**
- `run["resolve"]` is set in `start_run` (GameStateRuns.gd:28). It has to be
  added both to `_run_for_save` (GameStateCore.gd:642) and to the load mirror
  (GameState.gd:388), or a reload loses it.
- Knobs as `var`s in GameDataModes, so the sim can sweep them:
  `RESOLVE_START`, `RESOLVE_DRAIN` (dict), `RESOLVE_WAVER`, `RESOLVE_BROKEN_DMG`.
- Combat: `start_combat` reads the state. Round 1's turn order puts foes first
  (Rally already reorders turns, so that is the template).
- UI: the run bar (RiftRunView.gd:372, beside the haul), lane-map node
  tooltips ("-1 Resolve"), the campfire screen, and the room screen before a
  fight ("Wavering: foes strike first").
- campaign_sim:
  - Rest when Resolve is 3 or lower or HP is below 0.8.
  - Prefer the shrine and campfire when Wavering.
  - Log Resolve at each boss door.

**Targets (sim, 4 guilds × 2 profiles × 45 days)**
- 20-35% of boss doors reached Wavering or worse.
- Fights lost from above 90% HP drop by about a third.
- Seals at Recommended stay within 60-70%; recalibrate the readout if they
  move.
- Act timings stay within the economy targets.

**Tests:** test_resolve.gd. It checks drain and restore amounts, the
thresholds, round-1 order, the save round-trip and the grace gate.

---

## 0.65: Path relics (gap 3: too few items that change a run)

**Facts.** Relics belong to the guild: 3 slots, +2 from the vault, +1 from the
Reliquary. There are 14 unique relics, and sealing a rift drops no relic or
item today. Elites already offer a pick of 3 run boons.

**Rule.**
- When a rift is sealed at Rank D or higher, offer **1 of 3 Path relics**.
  Two of the three match a Path someone in the party has, and the third is
  random.
- Relics already owned are left out. When none are left, the pick pays
  Essence instead.
- Relic slots stay as they are, so choosing which to equip becomes the build
  decision.

**Code**
- `PATH_RELICS` in GameDataItems uses the `UNIQUE_RELICS` schema plus
  `path` and `pmod`. `find_unique_relic` and `relic_from_unique` already work
  for that shape.
- A helper `_pmod(state, key)` (like `party_has_unique_relic`) is read inside
  the existing `_pp_*` hooks in Combat.gd, so each relic is a one-line change
  to its hook.
- Pick UI: `BattleView._pick_overlay`, the same pop-up the boon pick uses. Each
  card names the Path heroes it helps.
- Icons: the type gem with the Path emblem until the 2026-11-06 PixelLab
  reset. After that, 30 pixflux icons, plus the missing `momentum_pct.png`.
  About 31 credits in total.
- Balance: the per-Path probe (60 SS runs per Path) with and without that
  Path's relics. No Path may go above about 75%, the Mercy lesson.

**Draft list (names and numbers get tuned in the sim)**

| Path | Relic | Change to the rule |
|---|---|---|
| Shieldwall | Bulwark Chain | Guardian takes 40% of back-row hits (from 25%); the Guardian takes +10% damage |
| Shieldwall | Oathplate Rivets | a shared hit gives the Guardian +1 Momentum, once a round |
| Bloodrage | Red Tooth Torc | cap +60% (from +40%); mending on this hero is halved |
| Bloodrage | Grudge Knot | below 30% HP, hits ignore 20% armour |
| Weaponmaster | Whetstone of Habit | Combo stacks to 6 |
| Weaponmaster | Duelist's Ribbon | at full Combo the next hit pierces shields |
| Marksman | Owl-Feather Fletching | Steady Aim survives one hit a fight |
| Marksman | Long Sightline | Steady Aim gives +55%, back row only |
| Trapper | Bramble Coil | snares two foes in round 1 |
| Trapper | Tripwire Bells | snared foes take +15% damage |
| Stalker | Hunter's Chalk | the Mark jumps to a new foe when the marked foe dies |
| Stalker | Blood Scent | a marked foe's first wind-up is cancelled |
| Evocation | Kindling Box | Abilities add Heat too |
| Evocation | Cinder Glass | detonates at 4 Heat |
| Warding | Loomed Sigil | Ward Weave covers the two most-hurt allies |
| Warding | Thrice-Knotted Thread | half the wards left at the end of a fight carry into the next |
| Augury | Second Sight | cancels the first two heavy blows |
| Augury | Omen Bones | a cancelled blow gives +2 Momentum |
| Mercy | Brimming Chalice | all overheal becomes a ward (from half); healing -10% |
| Mercy | Saint's Tally | the Miracle revive restores +15% HP |
| Aegis | Hallowed Mortar | Sanctuary 9% while the Aegis hero is in the front row |
| Aegis | Choir Bell | Sanctuary also cuts hazard damage 25% |
| Zeal | Burning Psalter | Fervor heals 35%; the Zeal hero takes +10% damage |
| Zeal | Judgment Nail | a Fervor heal on a kill gives +1 Momentum |
| Assassin | Widow's Thread | Execute threshold 45% (from 35%) |
| Assassin | Quiet Coin | the first execute each fight restores 1 Resolve |
| Skirmisher | Feather-Step Wraps | Evasion +25% dodge; max HP -10% |
| Skirmisher | Riposte Cord | the dodge jab hits twice |
| Scrapper | Brawler's Knuckle | Scrappy heals 25% of damage dealt |
| Scrapper | Pit-Fighter's Tape | the Scrappy round bonus also works in the back row |

---

## 0.66: More events, hero names and titles (gaps 4 and 6a)

**Camp events, from 15 to 30**
- **8 regional events**, two per later region, gated by a new `region`/`min_act`.
  Examples: Glass Coast smugglers, Marsh fever-reed sellers, Ashen salt
  caravans, Inverted City pilgrims.
- **4 that touch Resolve.** Example: a wandering chaplain means the next run
  starts at 12, through a new guild key `resolve_bonus`.
- **3 more dilemmas.**
- They use the same shape and handlers (`camp_day`, `answer_camp_event`).

**Hero requests, from 5 to 25**
- A new optional `need` field limits a request to the heroes it fits:
  `path`, `quirk_origin`, `bonded`, `injured`, `morale_below`, `rank`.
- Each answer leaves a lasting mark: a quirk, a bond, a title, XP.
- Examples: "Ilsa wants to test Flashpoint on the training dummies", "Two
  bonded heroes ask to share a tent", "A scarred veteran wants to visit the
  memorial".
- Twice a week (days 3 and 6, from once). The pick is weighted toward
  requests whose `need` matches.
- The sim checks that morale doesn't spiral.

**Fix while there:** `request_title` and `request_options` skip `tr()`, and the
yes/no lines are formatted into the const (GameDataModes.gd:137,
GameStateQuests.gd:370). So hero requests show in English for Turkish players
today. Fix: keep the `%d` in the data and call `tr()` first, then format.

**Rename and titles**
- Rename: the first name is edited from the hero page. The stored name stays
  "First the Class", because code splits on " the ". The new name is checked:
  14 characters at most, and no " the ".
- Titles: `Hero.titles` is earned from about 10 deeds. Examples:
  - Breach-Holder: held a breach rift
  - Kingslayer: landed the last hit on a boss
  - the Unbroken: 20 fights without a knockout
  - Twice-Risen: revived twice
  - Lanternbearer: a seal from Wavering
- The newest title shows under the name and in the memorial and legacy.

**Volume:** about 150 English strings and their Turkish.

---

## 0.67: Hardships and a Story setting (gap 5)

A setting in the founding panel. Story and Standard are always available.
Hardship 1 opens after a guild reaches any ending or Act IV; each later
Hardship opens by reaching an ending at the one before it. The steps stack
and almost all reuse existing knobs:

| Level | Adds |
|---|---|
| Story | foes ×0.8 HP and damage, haul never at risk, breaches 2 days slower, Laurels ×0.5 |
| 1 | foes +10% HP |
| 2 | breaches 2 days sooner |
| 3 | Resolve starts at 8 |
| 4 | wages ×1.25 |
| 5 | +1 elite chance per floor (`elite_chance_up`) |
| 6 | MEND_CAP 0.3 |
| 7 | falling loses 75% of the haul |
| 8 | bosses get a second mechanic (`boss_double_mechanic`) |
| 9 | campfires heal 15% |
| 10 | rival Renown ×1.2, foes +10% damage |

- Laurels: +5% per Hardship. Oaths stay as they are, an optional extra with
  their own cap.
- Recommended power is multiplied by each level's measured factor, so the
  readout stays honest. Calibrate at Story, H5 and H10.
- Badge: on the save slot, the standings, the legacy record and the memorial.
  `legacy.max_hardship` drives the unlocks.
- Code: `HARDSHIPS` in GameDataModes, plus `hard(key)` in GameStateCore that
  sums the active steps, read at about 10 knob sites. Save key: `hardship`.

---

## 0.68: Action preview and key rebinding (gaps 6b and 6c)

**Action preview**
- New `Combat.preview_action(state, hid, act, ti)` returns expected damage, a
  kill flag and the Momentum after the action.
- It is built only from functions with no side effects (`_hit_base`,
  `attack_would_kill`, `_pp_dmg_mult`). Skills use their multiplier; Abilities
  show text only.
- Display: in the command tooltip and as a ghost segment on the target's HP
  bar, with a skull on a kill.

**Key rebinding**
- Define InputMap actions in project.godot for the combat hotkeys, end day,
  Auto and Retreat. Today keys are read raw by keycode string
  (BattleView.gd:389).
- Settings > Controls lists every action with "press a key", saved in
  settings.json, with a "Reset to defaults" button.
- Controller mapping (`PAD_BATTLE`) stays as it is.

---

## 0.69: Sound pass (gap 6f)

- From 24 to about 70 effects:
  - one per Path rule moment (15)
  - a hit and a death per foe family (about 20)
  - camp: an event chime, a threat omen, the payday coin
  - lane map: node select
  - Resolve: a drop and a Wavering sting
  - UI: hover and tab
- `ui_error` exists but is never played; wire it to blocked actions.
- Everything goes through `AudioManager.cue`, so hearing-aid captions come
  for free.
- Source: CC0 packs (Kenney and freesound CC0). **Needs your OK to download.**
  A paid generator would be your call.
- Music batch 2 (boss, camp hall, finales) is still yours.

---

## 0.70: Spanish, then Simplified Chinese (gap 6e)

- About 5,600 strings each, using the same extract/merge tooling as Turkish.
  I translate; each language ships as "beta" with a call for native reviewers
  in the Discord.
- Spanish runs about 20% longer: run the screen captures at both sizes to
  catch overflow.
- Chinese needs a CJK font. No current font covers it (Lato, Cinzel and
  Alegreya do not).
  - Use a Noto Sans SC subset cut to only the glyphs used (about 1-2 MB),
    loaded only when Chinese is picked, so the web build stays the same size.
  - **Needs your OK** to download the font and the subsetting tool
    (fonttools).
- Voiced lines stay English with captions, as in Turkish.

---

## Any time: daily leaderboard (gap 6d)

- Score the daily: floors cleared + bosses + party HP left + Resolve left −
  turns.
- The transfer relay (tools/transfer-relay/worker.js, KV) gets
  `POST /daily/<day>` and `GET /daily/<day>`, returning the top 20 plus your
  rank by guild name.
- Cheating can only be limited, not stopped (a signed payload and a rate
  limit), which is fine for a daily.
- **Needs your go-ahead.** It is a public endpoint that stores guild names.

---

## Decisions (defaults used unless you say otherwise)
1. The name "Resolve" (Turkish: Azim) and the lantern pips.
2. Path relics drop when a rift is sealed (not from elites, which keep their
   boon pick).
3. Hero requests twice a week.
4. Story mode gives half Laurels.
5. Hardship unlocks: an ending or Act IV for H1, then an ending at the
   previous level.
6. Languages: Spanish first, then Chinese, both as beta.
7. Relic icons wait for the 2026-11-06 PixelLab reset.
8. Downloads (sounds, font, fonttools) and the public leaderboard wait for
   your OK.

---

## Built (0.64.0, 2026-10-08)

Everything above shipped together as 0.64.0. Differences from the plan:
- **Resolve** starts at 8 (cap 10), not 10. Tuned with campaign_sim: at 10 a
  careful party reached the boss with about 6 left, and only 3 of 271 boss
  doors were Wavering, so it never bit. At 8, about 7% of boss doors are
  Wavering (mostly greedy routes) and progress stays in the usual noise.
  Campfire Rest +3, its other choices +1, a shrine +2, six rift events +1/+2.
  Foes acting first in round 1 is a mild penalty, so Resolve shapes routes
  more than it walls players. Off in Story, the Tower, the training rift and
  the haul's grace. Knobs: `RESOLVE_*` in GameDataModes; sim args
  `rstart= waver= resolve=`.
- **Path relics**: 30, with values as drafted. Two renames: Choir Bell (it
  clashed with a Tower relic) became Sanctum Chime, and Kindling Box gives
  +2 starting Heat (Abilities already add Heat). They are cached per fight
  in `state["_pmods"]` and read by `Combat._pm` inside the `_pp_*` hooks.
  Icons are type gems until the PixelLab reset.
- **Events**: the 15 camp events and 20 hero requests are data
  (`opts` / `need`, `pair`, `yes_fx`), each handled by one generic function.
  The planned "Rift tremor" fight at camp was left out (the old tremor
  stays). A blessing's Resolve waits in `next_resolve` for the next party.
  The untranslated hero-request text is fixed (tr first, then format).
- **Hardships** go through `year_mult` / `year_add`, so most knobs needed
  no new code. Recommended power scales by sqrt(foe HP × foe damage). Not
  yet calibrated by sim at H5/H10.
- **Preview**: `Combat.preview_attack / preview_skill / preview_hit` (pure).
  Key rebinding is a table (`key_binds` in settings.json) that the battle's
  key handler reads through `unbind_key`. No InputMap was needed.
- **Sound**: 40 effects made from the existing CC0 set by
  tools/derive_sfx.py (no downloads). Not yet listened to by a person;
  Kenney packs could replace them with an OK to download.
- **Languages**: Spanish and Simplified Chinese, translated by agents from a
  shared glossary (docs: scratchpad brief, terms in the plan above), marked
  beta. Names are built per language (`NameTranslation.SHAPES`). Spanish
  keeps the English -s plural. Chinese shows on the web only once
  assets/fonts/NotoSansSC-Regular.otf exists (a download that needs the
  user's OK); desktops fall back to a system font.
- **Daily board**: worker routes `/daily/<day>`; posting is opt-in from the
  daily result. Live once the worker is redeployed.
