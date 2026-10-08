# Economy

A baseline for tuning prices. Income comes from `tests/sim/balance_sim.tscn`
(120 full runs per profile; it prints an "income per run" line for each), so
re-run it after changing rewards or costs and update the tables.

## Income per run (sim, Sep 2026)

| Profile | Clear rate | Coins | Crystals | Seal Tokens | Loot (sale value) |
|---|---|---|---|---|---|
| Lesser — new player (2 F heroes, Lv1) | ~28% | 132 | 41 | 3 | 63 |
| Lesser — invested (3 heroes, Lv4) | 100% | 170 | 53 | 10 | 68 |
| Greater — underleveled | ~23% | 337 | 97 | 4 | 77 |
| Greater — invested (4 heroes, Lv7) | 100% | 418 | 118 | 18 | 80 |
| Endless — endgame, per attempt (~13 min survived) | — | ~1,400 | ~170 | — | ~5 items |

A failed run still pays for every fight it won, so newcomers earn most of an
invested party's coins.

(0.63: the real-time Endless is parked behind GameData.ENDLESS_ENABLED; its
numbers below stay for when it returns.)

The Endless Rift is a real-time survival run (scripts/survivors). It pays
45 coins and 7 crystals a minute survived, 0.15 coins a kill, 3 crystals an
elite and 20 a warden, 12 XP a minute to every hero, and an item or relic per
4 elites and per warden. Autopilot survival (balance sim `-- survivors`):
Greater underleveled ~2:30, Greater invested ~6 min, endgame ~13 min; players
steering by hand do better.

## Tower of Trials (one-time, plus a weekly ladder)

First clears only, so the Tower can't be farmed. Floor *f* pays 20 + 4*f*
Coins and 8 + 1.5*f* Crystals; every 5th floor adds 2 + *f*/10 Seal Tokens;
every 10th gives its guardian's relic.

| | Coins | Crystals | Seal Tokens |
|---|---|---|---|
| Floors 1–100, all first clears | 22,200 | ~8,350 | 140 |
| Weekly ladder (floors 91–100 re-cleared at half) | ~2,000 / week | ~750 / week | — |

How far each profile climbs (sim, 3 tries a floor): Act II entry party ~9
(the floor-10 guardian), Greater-invested ~49, endgame ~85. The guardians are
the walls. The recommended power is fit to those numbers
(`GameState.tower_recommended_power`).

## Sinks

| Currency | Sink | Cost |
|---|---|---|
| Coins | Recruit a hero (0.62: a base class) | F 25 · E 60 · D 150 · C 330 · B 700 · A 1,350 · S 2,500 |
| | Reroll a recruit / Champion offers | 20 / 60 |
| | Train an attribute point | 50 × n, up to 8 per hero (1,800 per hero) |
| | Skill respec | 20 + 10 per SP spent |
| | Trait reroll | 60 |
| | Field Tonic · Incense · Runestone | 25 · 40 · 60 |
| | Shop item/relic | ~25–40, reroll 8 + 6 per reroll |
| | Forge: temper an item (0.61) | 40 × rarity mult × drop rank reward mult × level reached, 5 levels (Common F 600 in all, Epic S ~3,300); +6% stats per level |
| | Hall Works (0.61, after Act I) | 800 + 600 per wing built, 6 wings (13,800 in all) |
| | Evolving (0.62, at level 10) | E 60 · D 150 · C 300 · B 600 · A 1,100 · S 1,800 (plus Essence below) |
| | Subclass training (0.62) | stage 1 500 · stage 2 1,000 · stage 3 2,500 · Legend 3,500; x2 when changing Path |
| Crystals | Guild Management | 50 × next level per step; 750 per upgrade, 6,750 for all 9 (perks included) |
| | Relic upgrade to Lv5 | 15 × rarity mult × level per step (epic ≈ 285) |
| | Evolving (0.62) | E 60 · D 120 · C 220 · B 360 · A 560 · S 800 |
| | Subclass training (0.62) | stage 1 200 · stage 2 600 · stage 3 1,200 · Legend 1,800; x2 when changing Path |
| | Relic effect reroll / item reforge | 10 × mult × n / 8 × mult × n |
| Seal Tokens | Attribute reset | 5 × hero level |
| Evolution Stones | Evolution, Stonebound skill node | 1 each |

## Camp events and Wardcraft (0.63)

Camp events (GameStateBreach, camp_*) scale with the act: x(1 + 0.6 x (act - 1)),
so Act I x1.0, Act III x2.2, Act VI x4.0.

| Event | Cost (Act I) | What it buys |
|---|---|---|
| Merchant | 35 Gold a rare, 80 an epic | gear at the best sealed rank |
| Visiting hero | 40 Essence | one hero gains a level (at 10: attribute points) |
| Wandering recruit | 75% of the rank's recruit price | a base class one rank above the best seal |
| Relic peddler | 160 Gold | an epic relic (Act II+) |
| Smith's apprentice | half a Forge level | one Forge level on a worn piece |
| Scholar | 60 Gold | 30% of a level for every hero at camp |
| Festival | 50 Gold | +10 morale for all, +2 Renown (skipping: -3 morale) |
| Refugees | 45 Gold | +5 Renown |
| Debt | 70 Gold | or -5 Renown |
| Rival's quartermaster | (pays) 2x sale value | the rival +3 Renown |
| Threats | pay 60-90 Gold, send a hero, or the loss | fire/storm: a damaged building; fever: two heroes down 2 days; bandits: 25% of Gold above the bill; tremor: 10% Essence + a building |

Wardcraft (the old Defenses branch, Gold): Armory -5% breach foe HP/damage,
Quartermaster +10% breach pay, Palisade -10% of a lost defense (Lv5: one
building at most), Watchtower -4% breach foe damage (+warning days at 1/3).

## Target curve

- **First session (runs 1–3):** hire a second and third hero (D-rank after one
  run), a few Management levels, first relic.
- **Act I → II (runs 5–15):** a full roster, first Management upgrades at Lv3,
  relics climbing to Lv3.
- **Act II → III (runs 15–40):** training heroes toward the 8-point cap,
  epic relics to Lv5, most Management branches.
- **Post-campaign:** Endless and quests fund the last Management levels and
  rerolls; coins keep a use through training and recruits for new heroes.

## Watch list

- Coins outpaced sinks once the roster was full (0.60 sims: 5–27k Gold
  idle by day 45). 0.61 added the Forge and Hall Works; investor guilds now
  hold 2–7k at day 45, and casual guilds that follow the power advice reach
  Act IV 4/4 (was 2/4). If coins still pile up, the next lever is recruit
  prices for C+ ranks or a coin cost on relic upgrades.
- Seal Tokens have one sink (attribute resets); fine while they're earned
  slowly, revisit if players sit on hundreds.
