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

Group the 93 subclasses into **15 Paths**, 3 per role. A Path is a playstyle with one always-on **rule** that visibly changes how the hero fights (a Bloodrager hits harder the more hurt she is; a Marksman who isn't attacked lines up a heavier shot). Each **stage** of the Path adds a new move: a Technique at stage II, a once-a-fight Signature moment at stage III, the rule's limit lifted at S. Every subclass adds a **Twist** that bends the Path its own way, so a Berserker and a Bloodletter play the same Path differently. The Path and its skill tree stay with the hero for their whole career; staying on a Path builds **Mastery** (fed by XP after level 10), which strengthens the rule's numbers; switching Paths is allowed but starts Mastery over. Party building gets **Resonance**: heroes sharing an element light up a small party bonus. No new subclass art is needed.

## 3. How a Path grows: stages and Twists

Each stage adds a **new move**, not a bigger number:

| Stage | Ranks | What it adds |
|---|---|---|
| **I** | F–E | **The rule**: the Path's identity, always on. |
| **II** | D–C | **A Technique**: an active skill only this Path has, built on the rule. It replaces the role's level-6 skill, so the action bar visibly changes. Costs 3 Momentum unless a Twist says otherwise. |
| **III** | B–A | **A Signature moment**: once a fight, triggered by something that happens in the fight, with an aura on the hero's sprite. The fight's big beat. |
| **Legend** | S | **The limit comes off**: the rule's cap or condition goes away. Each role's one S subclass is open to all three of its Paths and applies the Legend change of the Path the hero arrived on. |

Every subclass adds a **Twist**: one line that bends the rule, the Technique or the Signature moment, so two heroes at the same stage of the same Path still play differently. Subclass Abilities stay as they are for now; Phase 5 re-themes any that clash with their Path.

Numbers below are first guesses; the sims set them (section 9).

## 3a. The 15 Paths in full

### Warrior

**Shieldwall** — the one who stands in front.
- **Rule, Guardian:** from the front row, takes 25% of every hit aimed at a back-row ally.
- **Technique, Hold the Line:** until the round ends, takes every hit aimed at the back row, at 30% less.
- **Signature, Last Wall:** the first time an ally would fall, she takes the blow instead, gains a ward of 30% max HP, and every foe must attack her for 2 rounds.
- **Legend (Rift Sovereign):** Guardian covers front-row allies too.

| Stage | Subclass | Twist |
|---|---|---|
| I | Footman | Foes whose hits she takes deal 10% less for the rest of the fight. |
| I | Fieldmender | Each hit she takes heals the ally it was aimed at for 5% of their max HP. |
| I | Bulwark | Takes 40% instead of 25%, but always acts last. |
| I | Frostguard | Foes whose hits she takes are chilled and act later next round. |
| II | Iron-Guard | Hold the Line also wards the back row for 10% of their max HP. |
| II | Aegis-Bearer | Hold the Line costs 2 Momentum. |
| III | Stormguard | During Last Wall, every foe that hits her is stunned. |

**Bloodrage** — gets stronger as she bleeds.
- **Rule, Bloodrage:** +1% damage for every 2% of HP missing.
- **Technique, Blood Price:** pay 15% HP (no Momentum): +2 Momentum and the next hit does +50%.
- **Signature, Red Mist:** the first time she drops below 30% HP, for 3 rounds her attacks hit every foe, she can't be stunned, and she can't be healed.
- **Legend (Rift Sovereign):** Red Mist triggers at 50% HP.

| Stage | Subclass | Twist |
|---|---|---|
| I | Squire | Reckless: +10% damage dealt and taken. |
| II | Berserker | Blood Price costs 10% HP and the empowered hit cleaves. |
| II | Bloodletter | Heals 1% of damage dealt for every 4% of HP missing. |
| III | Ashen Templar | Can't fall below 1 HP during Red Mist. |

**Weaponmaster** — builds a rhythm on one foe.
- **Rule, Combo:** each hit in a row on the same foe adds +12% (up to 4); switching targets resets it.
- **Technique, Flurry:** three quick strikes at the target, each adding a Combo stack.
- **Signature, Perfect Form:** the first time Combo reaches 4, she acts twice next round.
- **Legend (Rift Sovereign):** switching targets no longer resets Combo.

| Stage | Subclass | Twist |
|---|---|---|
| I | Trailblazer | Starts every fight at 1 Combo. |
| I | Duelist | When her Combo target attacks her, she counters and keeps the stack. |
| I | Featherguard | Each Combo stack also gives +3% dodge. |
| II | Warbrand | Combo goes up to 6. |
| III | Runeblade | During Perfect Form the whole party hits 15% harder. |
| III | Rift-Breaker | At 4 Combo her hits ignore armor and wards. |

### Ranger

**Marksman** — waits for the clean shot.
- **Rule, Steady Aim:** not attacked last round → the next shot does +35%.
- **Technique, Called Shot:** pick a foe; the next Steady shot at it also cancels its wind-up.
- **Signature, Overwatch:** the first time she uses Called Shot, she holds her turn and fires at the first foe to act next round, with double the Steady bonus.
- **Legend (Rift-Eclipsed Warden):** Steady Aim holds even when she's attacked.

| Stage | Subclass | Twist |
|---|---|---|
| I | Fieldscout | Steady shots break armor. |
| I | Slinger | Steady Aim still holds after one hit. |
| I | Longshot | Needs two quiet rounds, but gives +70%. |
| II | Blade-Dancer | Called Shot also hits every foe under 40% HP. |
| II | Gale Marksman | Can use Called Shot from the front row. |
| III | Rift-Piercer | Overwatch shots ignore wards. |

**Trapper** — controls the ground.
- **Rule, Snares:** each round the first foe to act steps in a snare: light damage, and it acts last next round.
- **Technique, Bait:** a lure takes the next foe attack this round (no damage) and snares that foe.
- **Signature, Killing Ground:** the first time three foes have been snared in a fight, every snared foe takes +30% damage for 2 rounds.
- **Legend (Rift-Eclipsed Warden):** snares also cancel wind-ups.

| Stage | Subclass | Twist |
|---|---|---|
| I | Trapper | Snares do double damage. |
| I | Pathfinder | Snared foes' hits are 10% weaker; rift hazards are 20% weaker. |
| I | Sapling-Keeper | Each snare heals the most-hurt ally for 4% of max HP. |
| II | Warden | Bait also wards the party for 8% of max HP. |
| II | Deadfall Hunter | Snares hit as hard as her basic attack. |
| III | Wintertide Archer | Snared foes lose their next action. |

**Stalker** — picks the prey for the whole party.
- **Rule, Mark:** her first hit marks a foe; the party does +15% to it; the mark jumps to another foe when it dies.
- **Technique, Hunt:** move the Mark to any foe; her next hit on it does +60%.
- **Signature, Vanish:** the first time she's hit, she can't be targeted for a round and her next hit on the Mark does triple.
- **Legend (Rift-Eclipsed Warden):** two Marks at once.

| Stage | Subclass | Twist |
|---|---|---|
| I | Shadowtracker | The marked foe deals 10% less damage. |
| I | Nightwarden | The Mark shows the foe's next two moves. |
| II | Duskstalker | +15% dodge while her Mark lives. |
| II | Rift-Ranger | When the Mark jumps, +2 Momentum. |
| II | Stormtracker | Her hits on the Mark chain to another foe for 30%. |
| III | Voidwalker | Vanish lasts 2 rounds. |

### Mage

**Evocation** — builds heat until it explodes.
- **Rule, Kindling:** each spell adds 1 Heat (+8% damage, up to 5); at 5 the next skill hits every foe and Heat resets.
- **Technique, Flashpoint:** +3 Heat at once.
- **Signature, Inferno:** the first detonation in a fight leaves every foe burning for 3 rounds.
- **Legend (The Unbound):** detonating drops Heat to 3, not 0.

| Stage | Subclass | Twist |
|---|---|---|
| I | Apprentice | Heat goes up to 7, but the detonation hits only the target. |
| I | Cinderling | Every spell burns its target lightly. |
| I | Cinder-Adept | Starts every fight at 2 Heat. |
| II | Stormcaller | Gains Heat when foes attack him too. |
| III | Ashbound Theorist | When a burning foe dies, its fire spreads to the rest. |
| III | Pyromancer | Detonates at 4 Heat. |

**Warding** — keeps the party behind glass.
- **Rule, Ward Weave:** at the start of every round, the most-hurt ally gets a ward of 8% of max HP.
- **Technique, Sigil:** wards every ally for 12% of their max HP.
- **Signature, Mirror Ward:** the first time a ward breaks, every ward reflects damage for 2 rounds.
- **Legend (The Unbound):** Ward Weave wards every ally each round.

| Stage | Subclass | Twist |
|---|---|---|
| I | Fledgling Seer | Wards go on the ally a foe is about to hit, not the most-hurt one. |
| I | Frost Scholar | A broken ward chills the attacker. |
| I | Stoneward Mystic | Wards are 12%, front row only. |
| II | Wardweaver | Sigil costs 2 Momentum. |
| III | Rift-Warden Magus | Mirror Ward also stops one hazard and one wind-up. |

**Augury** — sees what's coming and bends it.
- **Rule, Foresight:** the party sees foes' moves a round further ahead; once a fight, cancel one heavy blow.
- **Technique, Twist Fate:** reroll a foe's next move.
- **Signature, Prophecy:** the first time a foe winds up, the whole party dodges the blow and gains 2 Momentum.
- **Legend (The Unbound):** two cancels a fight.

| Stage | Subclass | Twist |
|---|---|---|
| I | Shade-Adept | The foe whose blow is cancelled takes +15% damage after. |
| I | Thornweaver | Allies who were warned of a hit heal 4% after it lands. |
| I | Grim Conjurer | Once a fight, a fallen ally rises at 15%. |
| II | Verdant Oracle | Twist Fate also heals the party 6%. |
| II | Duskglass Seer | Twist Fate also gives an ally 2 Momentum. |
| III | Archon of Storms | Prophecy also strikes the winding-up foe with lightning. |

### Cleric

**Mercy** — healing that keeps on giving.
- **Rule, Overflow:** healing past full HP becomes a ward.
- **Technique, Benediction:** heals every ally for 15% of max HP.
- **Signature, Miracle:** the first time an ally falls, they rise at 30% HP.
- **Legend (Last-Light Martyr):** Miracle works twice a fight.

| Stage | Subclass | Twist |
|---|---|---|
| I | Acolyte | Her heals cleanse one ailment. |
| I | Peddler | Overflow wards are half again as big. |
| I | Herbalist | Healed allies mend 3% more on each of the next 2 rounds. |
| II | Rift-Medic | Benediction costs 2 Momentum. |
| II | Frost Anchorite | Benediction cleanses everyone. |
| III | Dawnkeeper | Miracle also wards the party for 15%. |
| III | Alchemist | Miracle brings the ally back at 50%. |

**Aegis** — the party is safer while she stands.
- **Rule, Sanctuary:** while she stands, the party takes 6% less damage.
- **Technique, Consecrate:** one ally takes no damage this round.
- **Signature, Hallowed Ground:** the first time the party falls below half its total HP, damage taken is halved for 2 rounds.
- **Legend (Last-Light Martyr):** Sanctuary is doubled.

| Stage | Subclass | Twist |
|---|---|---|
| I | Frostward Sister | Front-row allies take a further 4% less. |
| I | Hearth-Warden | Sanctuary also mends the party 2% each round. |
| II | Battle Chaplain | Consecrate also gives its target +20% dodge next round. |
| III | Sanctified Shield | Hallowed Ground triggers at 70% instead of 50%. |

**Zeal** — heals by hitting.
- **Rule, Fervor:** her attacks heal the most-hurt ally for 25% of the damage.
- **Technique, Smite:** a 150% holy strike; Fervor heals double for it.
- **Signature, Judgment:** her first kill in a fight hits every foe for half her attack and heals the party 10%.
- **Legend (Last-Light Martyr):** Fervor heals the whole party.

| Stage | Subclass | Twist |
|---|---|---|
| I | Emberblessed Acolyte | The ally Fervor heals hits 5% harder on their next turn. |
| I | Lay Brother | Her hits break a foe's wind-up. |
| I | Vanguard Chaplain | Her first attack each fight does +50%. |
| II | Ember Confessor | Smite finishes foes under 20% HP. |
| II | Zealot | Smite costs 10% HP instead of Momentum. |
| III | Radiant Vanguard | Judgment triggers on any party kill. |
| III | Sainted Ember | Judgment also sets every foe burning. |

### Rogue

**Assassin** — finishes what others start.
- **Rule, Execute:** +50% damage to foes under 35% HP; a kill refunds 2 Momentum.
- **Technique, Shadowstep:** strikes any foe for 130%, past escorts and guards.
- **Signature, Deathmark:** her first kill in a fight gives her another action at once.
- **Legend (The Final Cut):** Execute works under 50% HP.

| Stage | Subclass | Twist |
|---|---|---|
| I | Cutpurse | Her kills add 10 Gold to the haul. |
| I | Arcane Pilferer | Her hits break wards. |
| II | Wraithstep | After Shadowstep, she can't be targeted until her next turn. |
| II | Nightblade | Execute damage heals her for 20% of it. |
| III | The Unseen Hand | Deathmark can chain: up to 3 extra actions. |

**Skirmisher** — can't be pinned down.
- **Rule, Evasion:** +15% dodge; each dodge gives 1 Momentum and a counter jab.
- **Technique, Feint:** until her next turn, half the attacks aimed at others go to her instead, and she has +25% dodge.
- **Signature, Untouchable:** after her third dodge in a fight, she can't be hit for 2 rounds.
- **Legend (The Final Cut):** counter jabs hit at full strength.

| Stage | Subclass | Twist |
|---|---|---|
| I | Runaway | Each dodge wards the most-hurt ally for 5%. |
| I | Scavenger | Rift hazards never hurt her. |
| I | Skirmisher | Counter jabs hit for 60% instead of 30%. |
| I | Glyphhand | Counter jabs break wards. |
| I | Footpad | Dodging the first hit of a fight gives 3 Momentum. |
| II | Shadowfoot | Feint costs 2 Momentum. |
| II | Rift-Slipper | Feint also saves the party from one wipe. |
| III | Wraithblade Adept | Untouchable after the second dodge. |

**Scrapper** — hard to put down.
- **Rule, Scrappy:** heals 15% of the damage she deals; +5% HP each round in the front row.
- **Technique, Dirty Trick:** a hit that stuns the foe and gives 2 Momentum.
- **Signature, Second Wind:** the first time she drops below 25% HP, she heals 50% and her next 2 attacks hit twice.
- **Legend (The Final Cut):** can't be stunned, and Scrappy heals 30%.

| Stage | Subclass | Twist |
|---|---|---|
| I | Herbrunner | Scrappy also heals the most-hurt ally for half as much. |
| I | Ironhide Footpad | Takes 10% less in the front row. |
| II | Bramblefoot | Attackers take 10% of their hit back. |
| II | Fleetblade | Dirty Trick hits twice. |
| III | Duskrunner | Second Wind triggers at 40%. |

**Count:** 15 rules, 15 Techniques, 15 Signature moments, 15 Legend changes, 88 Twists (every non-S subclass), all 93 subclasses placed.

## 4. Ranks, stages and evolving

- **Rank stays what it is** (F–S, stat multiplier, wages, recruit odds). A Path's **stage** follows rank (I = F–E, …).
- **Evolving** (level 10, Essence, B/A/S rift gates as now) offers:
  - **Stay on the Path:** the Path's subclasses at the next rank's stage (its next stage's variants, or the same subclass ranked up when the stage doesn't change). Mastery is kept.
  - **Change Path:** any other Path of the role at that stage. Mastery restarts at 0; skill points in the old Path tree are refunded in full.
- The picker shows the choice that way: "Stay a Bloodrager (Mastery 2 kept)" vs "Become a Weaponmaster (Mastery resets)".

## 5. Mastery (and a use for XP after level 10)

- Mastery 0–3 per hero, for their current Path. XP past level 10 fills it (a meter on the hero page): Mastery 1 at 300 XP, 2 at +600, 3 at +900 (to tune).
- Mastery strengthens the **numbers** of the rule, Technique and Signature moment (+20% of their effect per level). New **moves** come only from stages, so a switcher keeps their stage's moves but loses the Mastery bonus.
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
| **2a. Rules and Twists (stage I)** | 15 rules and the stage-I Twists in combat, state indicators on plates, Auto/Quick fight support, power factors, a test per rule, sims + readout recalibration. | 2 sessions |
| **2b. Techniques and Signature moments** | 15 Techniques (replacing the role's level-6 skill from stage II), 15 Signature moments with sprite auras, the stage II/III Twists and Legend changes, tests, sims. | 2 sessions |
| **3. Mastery** | XP past 10 → Mastery, +20% per level to the Path's numbers, hero-page meter, barks. | 1 session |
| **4. Resonance** | Element bonuses, Party screen chips, readout. | half a session |
| **5. Tune and explain** | Per-Path sim report, numbers pass, Codex page "Paths", What's New, tester brief questions. | half a session |

Turkish: ~400 new lines across phases (names, rules, UI), translated as each phase ships.

## 13. Questions for you

1. The 15 Paths: rules, Techniques, Signature moments, Legend changes and Twists (section 3a): keep, swap, rename?
2. Switching Paths: allowed with a Mastery reset (as above), or locked once chosen?
3. Mastery from XP after level 10: good, or tie it to something else (rifts sealed on the Path, Essence)?
4. Resonance: in, or leave party building to the Path combos alone?
5. Legends at S: shared per role (no new art), or later give each Path its own S (10 new subclasses, ~150 PixelLab generations)?
