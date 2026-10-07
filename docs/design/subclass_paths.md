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

Heroes are hired as **base classes** that differ only in rank, and climb ranks by levelling: each rank is levels 1–10, evolving resets to level 1. At Ranks D, B and S they can **train a subclass** at the Training Yard, unlocked for the guild by acts, Tower of Trials floors and deeds. The 93 subclasses form **15 Paths**, 3 per role. A Path is a playstyle with one always-on **rule** that visibly changes how the hero fights; stage 2 adds a **Technique**, stage 3 a once-a-fight **Signature moment** (or the role's Legend, which lifts the rule's limit). Every subclass adds a **Twist** that bends the Path its own way. Raised heroes end up slightly stronger; hired high-rank heroes arrive with more skill points. Party building gets **Resonance** from shared elements. No new subclass art is needed.

## 3. How a Path grows: stages and Twists

Heroes start as base classes and gain their Path at the Training Yard (section 5). Each stage adds a **new move**, not a bigger number:

| Stage | When | What it adds |
|---|---|---|
| **1** | trained at D | **The rule**: the Path's identity, always on. |
| **2** | trained at B | **A Technique**: an active skill only this Path has, built on the rule. It replaces the role's second skill, so the action bar visibly changes. Costs 3 Momentum unless a Twist says otherwise. |
| **3** | trained at S | **A Signature moment**: once a fight, triggered by something that happens in the fight, with an aura on the hero's sprite. The fight's big beat. |
| **Legend** | trained at S | **The limit comes off**: a stage-3 choice. Each role's Legend subclass is open to all three of its Paths; instead of the Signature moment's variant Twist it lifts the rule's limit (each Path's "Legend" line). |

Every subclass adds a **Twist**: one line that bends the rule, the Technique or the Signature moment, so two heroes at the same stage of the same Path still play differently. Subclass Abilities stay as they are for now; Phase 5 re-themes any that clash with their Path.

Numbers below are first guesses; the sims set them (section 9).

## 3a. The 15 Paths in full

In the tables, stage I/II/III = stage 1/2/3 (trained at D/B/S).

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

## 4. Recruiting, ranks and levels

**Heroes are hired as base classes.** Every recruit is a plain Warrior, Ranger, Mage, Cleric or Rogue (the five base portraits already exist); only their rank differs. Rank odds and prices stay as they are.

**Ranks and levels:**
- Each rank has levels 1–10. At level 10 the hero can **evolve** to the next rank (Essence cost and the B/A/S rift gates as now).
- Evolving **resets the level to 1** and gives **+20% XP for the next 2 rift runs**.
- Power comes from rank: levels 1–10 climb from this rank's power toward the next rank's, and evolving starts the next climb. Power stays where foes and Recommended expect it.
- XP now matters all career long (the Library wing, Barracks Lv5, training XP).

**Raised vs hired:**
- **Raised (Seasoned):** every rank a hero reaches by levelling and evolving adds **+2% permanent stats**. A hero raised from F to S has +12% over the same hero hired at S.
- **Hired (Trained elsewhere):** a recruit above F arrives with the skill and attribute points of every rank below theirs, unspent, plus **1 extra skill point per rank above F**. A hired S hero has 6 more skill points than a raised one: flexibility now vs stats over time.

**Skills and Abilities by rank, not level** (levels now reset): the role's first skill from Rank F, its second from Rank E; a subclass's Ability comes with its stage-1 training (today: level 3).

**Points per rank:** each rank gives **2 skill points** (at levels 5 and 10) and **2 attribute points** (at levels 3 and 8). A full F→S career totals 14 skill points (about 9 today) and 14 attribute points. Exact numbers are set in the sims.

**XP curve:** one rank (levels 1→10) should take about 3–5 rift runs at that rank's rifts early on, and longer at the top. A fresh F hero should reach Rank D (their first subclass) around the end of Act I or early Act II. The current per-level XP table is replaced by one scaled per rank; the campaign sim sets it.

## 5. Subclass training (the Training Yard)

A new kind of program at the Training Yard, beside the attribute programs:

| Stage | Opens at rank | What the hero gains | Training time |
|---|---|---|---|
| **Stage 1** | **D** | Chooses a Path and a stage-1 subclass of it: the rule, the subclass's Twist, name, portrait, Ability and main stat. | 3 days |
| **Stage 2** | **B** | A stage-2 subclass of the same Path: adds the Technique and that subclass's Twist. | 4 days |
| **Stage 3** | **S** | A stage-3 subclass of the same Path, or the role's Legend: adds the Signature moment (the Legend lifts the rule's limit instead). | 5 days |

- Only subclasses the guild has **unlocked** appear (section 6). The hero is away for the training days, like attribute training; the fee is Gold and grows with the stage.
- A hero who reaches D, B or S without training simply keeps what they have; they can train any time later. Evolving and training are separate: evolving is the rank, training is the subclass.
- **Changing Path:** at a stage-2 or stage-3 training the hero may switch to another Path's subclass of that stage. It takes twice as long, and the old Path's tree is refunded in full. The hero then has the new Path's moves up to their stage.
- The 5 Rank-S subclasses (Rift Sovereign, Rift-Eclipsed Warden, The Unbound, Last-Light Martyr, The Final Cut) become **Legends**: a stage-3 choice open to every Path of their role, keeping the Path's rule, Technique and Twists and lifting the rule's limit (the "Legend" line of each Path in section 3a).

## 6. Unlocking subclasses

Subclass trainings are unlocked for the whole guild by acts, Tower of Trials floors and deeds. The first subclass of every Path at each stage opens with the stage itself; the rest come from goals:

| Path | Stage 1 (Rank D) | Stage 2 (Rank B) | Stage 3 (Rank S) |
|---|---|---|---|
| **Shieldwall** | Footman (open from the start); Fieldmender (Act I done); Bulwark (Tower of Trials floor 10); Frostguard (seal 10 rifts with heroes of this role) | Iron-Guard (Act II done); Aegis-Bearer (Tower of Trials floor 30) | Stormguard (Act III done); Rift Sovereign (Legend: Tower of Trials floor 100) |
| **Bloodrage** | Squire (open from the start) | Berserker (Act II done); Bloodletter (Act III done) | Ashen Templar (Act III done); Rift Sovereign (Legend: Tower of Trials floor 100) |
| **Weaponmaster** | Trailblazer (open from the start); Duelist (seal 10 rifts with heroes of this role); Featherguard (Tower of Trials floor 20) | Warbrand (Act II done) | Runeblade (Act III done); Rift-Breaker (hold a Riftbreak at Rank S); Rift Sovereign (Legend: Tower of Trials floor 100) |
| **Marksman** | Fieldscout (open from the start); Slinger (Tower of Trials floor 20); Longshot (beat a rift boss by hand without anyone down) | Blade-Dancer (Act II done); Gale Marksman (Tower of Trials floor 45) | Rift-Piercer (Act III done); Rift-Eclipsed Warden (Legend: Act VI done) |
| **Trapper** | Trapper (open from the start); Pathfinder (beat a rift boss by hand without anyone down); Sapling-Keeper (Act I done) | Warden (Act II done); Deadfall Hunter (seal a Rank A rift) | Wintertide Archer (Act III done); Rift-Eclipsed Warden (Legend: Act VI done) |
| **Stalker** | Shadowtracker (open from the start); Nightwarden (Act I done) | Duskstalker (Act II done); Rift-Ranger (Tower of Trials floor 30); Stormtracker (Act III done) | Voidwalker (Act III done); Rift-Eclipsed Warden (Legend: Act VI done) |
| **Evocation** | Apprentice (open from the start); Cinderling (Tower of Trials floor 10); Cinder-Adept (seal 10 rifts with heroes of this role) | Stormcaller (Act II done) | Ashbound Theorist (Act III done); Pyromancer (Tower of Trials floor 70); The Unbound (Legend: Tower of Trials floor 90 and Act IV done) |
| **Warding** | Fledgling Seer (open from the start); Frost Scholar (seal 10 rifts with heroes of this role); Stoneward Mystic (Tower of Trials floor 20) | Wardweaver (Act II done) | Rift-Warden Magus (Act III done); The Unbound (Legend: Tower of Trials floor 90 and Act IV done) |
| **Augury** | Shade-Adept (open from the start); Thornweaver (Tower of Trials floor 20); Grim Conjurer (beat a rift boss by hand without anyone down) | Verdant Oracle (Act II done); Duskglass Seer (Tower of Trials floor 45) | Archon of Storms (Act III done); The Unbound (Legend: Tower of Trials floor 90 and Act IV done) |
| **Mercy** | Acolyte (open from the start); Peddler (beat a rift boss by hand without anyone down); Herbalist (Act I done) | Rift-Medic (Act II done); Frost Anchorite (seal a Rank A rift) | Dawnkeeper (Act III done); Alchemist (Tower of Trials floor 70); Last-Light Martyr (Legend: Act VI done) |
| **Aegis** | Frostward Sister (open from the start); Hearth-Warden (Act I done) | Battle Chaplain (Act II done) | Sanctified Shield (Act III done); Last-Light Martyr (Legend: Act VI done) |
| **Zeal** | Emberblessed Acolyte (open from the start); Lay Brother (Tower of Trials floor 10); Vanguard Chaplain (seal 10 rifts with heroes of this role) | Ember Confessor (Act II done); Zealot (Act III done) | Radiant Vanguard (Act III done); Sainted Ember (hold a Riftbreak at Rank S); Last-Light Martyr (Legend: Act VI done) |
| **Assassin** | Cutpurse (open from the start); Arcane Pilferer (seal 10 rifts with heroes of this role) | Wraithstep (Act II done); Nightblade (free a lost champion) | The Unseen Hand (Act III done); The Final Cut (Legend: Tower of Trials floor 100) |
| **Skirmisher** | Runaway (open from the start); Scavenger (Tower of Trials floor 20); Skirmisher (beat a rift boss by hand without anyone down); Glyphhand (Act I done); Footpad (Tower of Trials floor 10) | Shadowfoot (Act II done); Rift-Slipper (Tower of Trials floor 45) | Wraithblade Adept (Act III done); The Final Cut (Legend: Tower of Trials floor 100) |
| **Scrapper** | Herbrunner (open from the start); Ironhide Footpad (beat a rift boss by hand without anyone down) | Bramblefoot (Act II done); Fleetblade (seal a Rank A rift) | Duskrunner (Act III done); The Final Cut (Legend: Tower of Trials floor 100) |

- **Stage gates:** stage 1's first subclasses are open from the start (trainable once a hero reaches D); stage 2's open with Act II; stage 3's with Act III.
- **The rest** rotate through Act completions, Tower of Trials floors (10–100), sealing rifts with heroes of the role, a boss beaten by hand with no one down, freeing a lost champion, a Rank A seal and holding a Rank S Riftbreak, so every Path has goals across the game's modes.
- The Codex gets a **Subclasses** page: every subclass, locked or not, with what unlocks it.
- **Carrying unlocks to the next guild (Laurels):** a guild's unlocks are remembered in the legacy. On the founding screen, beside the founding gifts, each remembered unlock can be bought for the new guild with Laurels: **stage 1: 3, stage 2: 5, stage 3: 8, a Legend: 12**. Unbought ones must be earned again. The stage gates (the first subclass of each Path per stage) are free as always. This is the lasting Laurel sink the economy list was missing.

## 6b. Skill trees and points

- A **base class** uses the role tree: the role's two starting nodes and a small role package.
- Training stage 1 adds the **Path tree** (the kind package that fits the Path, e.g. Bloodrage → damage, Shieldwall → HP). Each later stage opens the Path tree's next tier.
- Points learned in the role tree stay; changing Path refunds the old Path tree in full. This retires `Hero.prior_pool_id` and fixes the bug where a second evolution silently deleted skill points.

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

- Base classes show the role ("Elowen the Warrior"); a trained hero takes the subclass name ("Elowen the Squire"), and its portrait. Every subclass gets its own name (from the ids; ~75 Turkish names to translate).
- A Path line under the name everywhere a hero appears: emblem + "Bloodrage · stage 1", or "Base class · trains at Rank D".
- Recruit cards show rank, points they bring, and which stages they can train right away (a B recruit can train stage 1 and 2).
- In fights, the rule's state is visible on the hero's plate: Heat 3/5, Combo ×2, a mark over the marked foe, Steady Aim glow.
- Barks: a line when a hero finishes a subclass training and when they evolve (reuses the bark system); the B calling scene moves to the stage-2 training.

## 9. Balance and the readout

- The party power formula (`CombatEffects`) gets a factor per stage so "Recommended" stays honest; re-run the 0.61.1 calibration probe after each phase.
- Auto and Quick fight must play the rules (target-switch rules for Combo and Mark; the rest are passive).
- Campaign sim before/after: pacing within ±2 days per act, finale seal rates at Recommended ~65%, no Path more than ~10% above or below its role's average clear rate (a per-Path sim report is part of the work).

## 10. Save migration

- Existing heroes keep their rank and level (level stays 1–10 in its rank).
- Heroes with a subclass keep it as **trained**: they get its Path and the stage that matches their rank (F–C → stage 1, B–A → stage 2, S → stage 3), even below Rank D, so nobody loses an identity they already had. - Every hero gets a free full skill reset (old kind-keyed trees → role + Path trees) and the points of their rank budget. Seasoned bonus: +2% per rank above F for existing heroes (we can't tell raised from hired in old saves).
- Subclasses existing heroes already have count as unlocked for the guild.
- A one-time notice explains the change. Champions are untouched.

## 11. Art and budget

- No new subclass portraits or animations: all 93 already have them. The 5 base-class portraits exist but predate the crisp pass; redraw them to match (~30 generations, Pro Flash).
- New: 15 Path emblems (32 px, pixflux ~1 generation each ≈ 15) and in-fight state icons (reuse skill icons). About 55 PixelLab generations in all.

## 12. Phases (each ships on its own)

| Phase | What ships | Size |
|---|---|---|
| **1. Ranks and recruits** | Base-class recruits with per-rank points; level 1–10 per rank, evolve resets to 1 with the XP boost; rank-based power curve with the Seasoned bonus; points per rank; per-rank XP table; save migration (grandfathering subclasses); sims for pacing and the readout. No Paths yet. | 2 sessions |
| **2. Paths and training** | Path data; subclass training at the Training Yard (stages at D/B/S, days, fees, switching); unlocks and the Codex Subclasses page; names, Path line, base portraits; role + Path trees; fixes the lost-skill-points bug. | 1–2 sessions |
| **3a. Rules and Twists (stage 1)** | 15 rules and the stage-1 Twists in combat, state indicators on plates, Auto/Quick fight support, power factors, a test per rule, sims + readout recalibration. | 2 sessions |
| **3b. Techniques and Signature moments** | 15 Techniques, 15 Signature moments with sprite auras, Legends, the stage 2/3 Twists, tests, sims. | 2 sessions |
| **4. Resonance** | Element bonuses, Party screen chips, readout. | half a session |
| **5. Tune and explain** | Per-Path sim report, numbers pass, Ability re-themes, What's New, tester brief questions. | half a session |

Turkish: ~450 new lines across phases (names, rules, training, UI), translated as each phase ships.

## 13. Questions for you

1. ~~The 15 Paths~~ — approved.
2. ~~The unlock table~~ — approved.
3. ~~Raised vs hired~~ — approved.
4. Resonance: in, or leave party building to the Path combos alone?
5. ~~Unlocks across guilds~~ — decided: carried with Laurels (section 6).
