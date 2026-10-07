# Paths: making subclasses matter

Status: **plan for review** (2026-10-07). Nothing is built yet.

## 1. Why subclasses don't land today

From reading the code (0.61.4):

| Area | What happens now | Why it feels flat |
|---|---|---|
| Identity | Subclasses F–C all display the role's name ("Elowen the Warrior"); only B, A, S have their own names. | 75 of 93 subclasses are invisible as identities. |
| Fights | A subclass changes one Ability (4 Momentum, usually once a fight), a passive from a template for its main-stat kind, and its stat ratios. Turn to turn, every hero of a role uses the same attack and two role skills. | Two warriors of different subclasses play the same. |
| Skill trees | A tree comes from the subclass's main-stat **kind** (9 kinds), not the subclass: many subclasses share a tree. | Picking a subclass doesn't pick a playstyle. |
| Evolving | At level 10, pay Essence, pick any next-rank subclass of the role. Level never resets, so a level-10 hero can chain F→C in one sitting; XP has no use after level 10. A second evolution drops the oldest tree **and its skill points** (bug). The S step has one option per role. | The choice is "the higher number"; staying or switching means nothing. |
| Party building | Each subclass has an element (Ember, Frost, Verdant, Umbral, Arcane) used only for hit effects. No synergies between heroes. | Who you combine doesn't matter. |

## 2. The idea in one paragraph

Group the 93 subclasses into **15 Paths**, 3 per role. A Path is a playstyle with one **signature rule** that is always on and visibly changes how the hero fights (a Bloodrager hits harder the more hurt she is; a Marksman who isn't attacked lines up a heavier shot). Subclasses become the **stages** of a Path: the hero's look, name, Ability and main stat change as they climb, but the Path, its rule and its skill tree stay. Staying on a Path builds **Mastery** (fed by XP after level 10), which deepens the rule; switching Paths is allowed but starts Mastery over. Party building gets **Resonance**: heroes sharing an element light up a small party bonus. No new subclass art is needed.

## 3. The 15 Paths

Stages group ranks: **I = F–E, II = D–C, III = B–A, Legend = S**. Every Path has at least one subclass at stages I–III with today's roster; at S, each role's single Legend subclass is open to all three of its Paths (it keeps your Path's rule at full depth and adds its own capstone).

### Warrior
| Path | Signature rule (tier I) | Deepens to (II / III) | Stage I | Stage II | Stage III |
|---|---|---|---|---|---|
| **Shieldwall** | *Guardian*: from the front row, takes 25% of every hit aimed at a back-row ally. | II: intercepted hits are 30% weaker · III: each intercepted hit stores Retaliation, released on the next attack | Footman, Fieldmender, Bulwark, Frostguard | Iron-Guard, Aegis-Bearer | Stormguard |
| **Bloodrage** | *Bloodrage*: +1% damage for every 2% HP missing (max +40%). | II: once a fight, can't fall below 1 HP · III: below 30% HP, attacks hit every foe for half | Squire | Berserker, Bloodletter | Ashen Templar |
| **Weaponmaster** | *Combo*: each hit in a row on the same foe adds +12% (max 4); switching targets resets. | II: at 4 the hit ignores armor and wards · III: the 4th hit strikes twice | Trailblazer, Duelist, Featherguard | Warbrand | Runeblade, Rift-Breaker |

### Ranger
| Path | Signature rule | Deepens to | I | II | III |
|---|---|---|---|---|---|
| **Marksman** | *Steady Aim*: not attacked last round → next shot +35%. | II: Steady shots ignore armor · III: Steady builds over two rounds (+70%) | Fieldscout, Slinger, Longshot | Blade-Dancer, Gale Marksman | Rift-Piercer |
| **Trapper** | *Snares*: each round, the first foe to act steps in a snare (light damage, acts last next round). | II: snared foes lose their wind-up · III: two snares a round | Trapper, Pathfinder, Sapling-Keeper | Warden, Deadfall Hunter | Wintertide Archer |
| **Stalker** | *Mark*: the first hit marks a foe; the whole party deals +15% to it; the mark jumps when it dies. | II: +25% and marked foes miss more · III: two marks | Shadowtracker, Nightwarden | Duskstalker, Rift-Ranger, Stormtracker | Voidwalker |

### Mage
| Path | Signature rule | Deepens to | I | II | III |
|---|---|---|---|---|---|
| **Evocation** | *Kindling*: each spell adds Heat (+8%, max 5); at 5 the next skill detonates on every foe and resets. | II: detonation burns · III: Heat starts at 2 | Apprentice, Cinderling, Cinder-Adept | Stormcaller | Ashbound Theorist, Pyromancer |
| **Warding** | *Ward Weave*: at each round's start, the most-hurt ally gets a ward of 8% max HP. | II: wards hit back when broken · III: every ally is warded | Fledgling Seer, Frost Scholar, Stoneward Mystic | Wardweaver | Rift-Warden Magus |
| **Augury** | *Foresight*: the party sees foes' intents a round further ahead; once a fight, cancel one heavy blow. | II: party +10% dodge against foreseen hits · III: cancel twice | Shade-Adept, Thornweaver, Grim Conjurer | Verdant Oracle, Duskglass Seer | Archon of Storms |

### Cleric
| Path | Signature rule | Deepens to | I | II | III |
|---|---|---|---|---|---|
| **Mercy** | *Overflow*: healing past full HP becomes a ward. | II: heals cleanse · III: once a fight, a fallen ally rises at 30% | Acolyte, Peddler, Herbalist | Rift-Medic, Frost Anchorite | Dawnkeeper, Alchemist |
| **Aegis** | *Sanctuary*: while she stands, the party takes 6% less damage. | II: 10%, and Defend covers her row · III: 15% | Frostward Sister, Hearth-Warden | Battle Chaplain | Sanctified Shield |
| **Zeal** | *Fervor*: her attacks heal the most-hurt ally for 25% of the damage. | II: her crits stun · III: 40% | Emberblessed Acolyte, Lay Brother, Vanguard Chaplain | Ember Confessor, Zealot | Radiant Vanguard, Sainted Ember |

### Rogue
| Path | Signature rule | Deepens to | I | II | III |
|---|---|---|---|---|---|
| **Assassin** | *Execute*: +50% damage to foes under 35% HP; a kill refunds 2 Momentum. | II: under 45% · III: a kill grants another action | Cutpurse, Arcane Pilferer | Wraithstep, Nightblade | The Unseen Hand |
| **Skirmisher** | *Evasion*: +15% dodge; each dodge gives 1 Momentum and a counter jab. | II: +25% · III: dodges also shield the lowest ally | Runaway, Scavenger, Skirmisher, Glyphhand, Footpad | Shadowfoot, Rift-Slipper | Wraithblade Adept |
| **Scrapper** | *Scrappy*: steals 15% of damage dealt as HP; +5% HP a round in the front row. | II: 25% · III: can't be stunned | Herbrunner, Ironhide Footpad | Bramblefoot, Fleetblade | Duskrunner |

**Legends (S):** Rift Sovereign, Rift-Eclipsed Warden, The Unbound, Last-Light Martyr, The Final Cut. Each keeps the Path you arrived on (rule at tier III) plus its own capstone Ability.

Numbers are first guesses; the sims set them (section 9).

## 4. Ranks, stages and evolving

- **Rank stays what it is** (F–S, stat multiplier, wages, recruit odds). A Path's **stage** follows rank (I = F–E, …).
- **Evolving** (level 10, Essence, B/A/S rift gates as now) offers:
  - **Stay on the Path:** the Path's subclasses at the next rank's stage (its next stage's variants, or the same subclass ranked up when the stage doesn't change). Mastery is kept.
  - **Change Path:** any other Path of the role at that stage. Mastery restarts at 0; skill points in the old Path tree are refunded in full.
- The picker shows the choice that way: "Stay a Bloodrager (Mastery 2 kept)" vs "Become a Weaponmaster (Mastery resets)".

## 5. Mastery (and a use for XP after level 10)

- Mastery 0–3 per hero, for their current Path. XP past level 10 fills it (a meter on the hero page): Mastery 1 at 300 XP, 2 at +600, 3 at +900 (to tune).
- The rule's tier = **min(Mastery + 1, stage)**: a stage-III hero needs Mastery 2 for tier III; a fresh switcher plays tier I until it re-earns depth.
- So XP keeps mattering (the Library wing, Barracks Lv5, training XP all count again), and staying on a Path is a real reward.

## 6. Skill trees

- Each Path owns one tree: the role's two starting nodes plus the kind package that fits the Path (e.g. Bloodrage → damage package, Shieldwall → HP package; 15 Paths over the 9 packages, a few shared).
- Evolving on the same Path keeps the tree and every learned node. Changing Path refunds all its points.
- This retires `Hero.prior_pool_id` / the "one prior tree" rule and fixes the bug where a second evolution silently deleted skill points.

## 7. Resonance (party building)

Heroes already carry an element. In a party:

| Element | 2 heroes | 3+ heroes |
|---|---|---|
| Ember | +6% damage | +12%, and kills burn nearby foes |
| Frost | foes hit by the party act 5% slower | 10%, and the first hit each fight chills |
| Verdant | +3% mend per round | +6% |
| Umbral | +5% dodge | +10% |
| Arcane | +1 starting Momentum | +2, and Abilities cost 1 less |

Shown on the Party screen as chips ("Ember ×2: +6% damage"), and in the power readout. Path rules also combo on purpose: Stalker's Mark + Assassin's Execute, Trapper's Snares + Marksman's Steady Aim, Aegis + Shieldwall.

## 8. Identity

- Every subclass shows its own name from Rank F: "Elowen the Squire", "Gara the Acolyte" (names from the ids; Turkish names to translate, ~75).
- A Path line under the name everywhere a hero appears: emblem + "Bloodrage · Mastery 1".
- Recruit cards lead with the Path and its rule in one line, so hiring is choosing a playstyle.
- In fights, the rule's state is visible on the hero's plate: Heat 3/5, Combo ×2, a mark over the marked foe, Steady Aim glow.
- Barks: a line when a hero first joins a Path, and when Mastery rises (reuses the bark system).

## 9. Balance and the readout

- The party power formula (`CombatEffects`) gets a factor per rule tier so "Recommended" stays honest; re-run the 0.61.1 calibration probe after each phase.
- Auto and Quick fight must play the rules (target-switch rules for Combo and Mark; the rest are passive).
- Campaign sim before/after: pacing within ±2 days per act, finale seal rates at Recommended ~65%, no Path more than ~10% above or below its role's average clear rate (a per-Path sim report is part of the work).

## 10. Save migration

- Every existing hero gets the Path of their subclass (the table above), Mastery from their rank (stage − 1, capped 2) so veterans don't feel demoted, and a free full skill reset (old kind-keyed trees → Path trees). A one-time notice explains it.
- Champions are untouched (they aren't subclass heroes in rifts).

## 11. Art and budget

- No new subclass portraits or animations: all 93 already have them.
- New: 15 Path emblems (32 px, pixflux ~1 generation each ≈ 15) and in-fight state icons (reuse skill icons). Under 25 PixelLab generations.

## 12. Phases (each ships on its own)

| Phase | What ships | Size |
|---|---|---|
| **1. Paths and identity** | Path data and mapping; subclass names from F; Path line on hero/recruit/party cards; evolution picker "Stay / Change"; Path trees with refund; save migration; fixes the lost-skill-points bug. No combat change yet. | 1 session |
| **2. Signature rules (tier I)** | 15 rules in combat, plate indicators, Auto/Quick fight support, power factors, a test per rule, sims + readout recalibration. | 2 sessions (the big one) |
| **3. Mastery** | XP past 10 → Mastery, tiers II/III, hero-page meter, barks. | 1 session |
| **4. Resonance** | Element bonuses, Party screen chips, readout. | half a session |
| **5. Tune and explain** | Per-Path sim report, numbers pass, Codex page "Paths", What's New, tester brief questions. | half a session |

Turkish: ~250 new lines across phases (names, rules, UI), translated as each phase ships.

## 13. Questions for you

1. The 15 Paths and their rules: keep, swap, rename? (Tables in section 3.)
2. Switching Paths: allowed with a Mastery reset (as above), or locked once chosen?
3. Mastery from XP after level 10: good, or tie it to something else (rifts sealed on the Path, Essence)?
4. Resonance: in, or leave party building to the Path combos alone?
5. Legends at S: shared per role (no new art), or later give each Path its own S (10 new subclasses, ~150 PixelLab generations)?
