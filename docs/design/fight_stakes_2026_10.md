# Fight stakes: wounds and the cost of falling

Status: design approved section by section on 2026-10-09; spec for review. Target release: 0.68.

## Why

Ordinary rift fights don't matter. The sims (0.56, 0.61) showed:

- **Ordinary fights:** won 99% of the time, from 97-98% party HP. At Rank SS, 40% of fights are over in round one.
- **Why HP never drops:** parties mend up to 40% of their HP a round (`MEND_CAP`) and dodge up to 60% (`DODGE_CAP`), so a won fight costs about 3% HP.
- **Where runs are decided:** at the boss, never by wear on the way there.
- **Tuning can't fix it:** doubling or quadrupling foe damage, or a 0.15 mend cap, still brought HP to the boss at 91-96% and only slowed pacing. Combat is burst. Numbers can't make HP carry, so it needs a structural mechanic.

The haul (0.56) and Resolve (0.64) put stakes on the run, but not on an ordinary fight.

## What the player should feel (the user's call)

The layers go by rift rank:

| Ranks | Layer |
|---|---|
| F, E, D (Lesser, Act I) | As today: the learning ranks. |
| C, B, A | **Fights can go wrong.** Each ordinary fight has a real decision, and a misplay costs something now. **Falling hurts the guild**: a fall leaves a lasting mark. |
| S, SS, SSS | All of the above, plus **the run wears down**: damage carries toward the boss, so "push on or turn back?" is a real question. |

## 1. Wounds

**What wounds** (from Rank C)
- A landed heavy blow: a wind-up's charged strike.
- Any single hit worth 25% or more of the target's max HP. This is the existing "heavy" test in `_monster_strike`.

**How much**
- The hero takes the damage as now, and `WOUND_SHARE` (0.5) of the damage dealt also becomes a wound.

**What a wound does**
- It lowers the hero's effective max HP while it lasts.
- Mending, heal skills, relics, tonics, campfires and `POST_FIGHT_MEND` all fill only up to that lower ceiling.
- A hero's wounds stop at `WOUND_CAP` (0.6) of max HP, so a hero always keeps 40% to fight with.

**How to avoid them**
- A blow taken on **Guard** or **Defend** never wounds, though it still deals its reduced damage.
- A dodged or evaded blow deals nothing and never wounds.
- Breaking the wind-up (stun, snare, Foresight) or killing the charger first prevents the blow.

That is the decision in each fight: see the telegraph and answer it.

**Every C+ fight has a decision**
- In an ordinary fight from Rank C, at least one foe is set to wind up in round 1 or 2.
- Today wind-ups are random (`WINDUP_CHANCE`).
- Elites and bosses keep their own patterns.

**How long wounds last**

| Ranks | Duration |
|---|---|
| C, B, A | Wounds close when the fight ends, won or fled. Only this fight is at stake; the guild-level cost comes from falling (part 2). |
| S, SS, SSS | Wounds last the whole run. A campfire's Rest halves them (`WOUND_REST_CLOSE` 0.5), a shrine closes 25% of max HP (`WOUND_SHRINE_CLOSE`), and they all clear when the run ends (sealed, fallen, retreated or left). |

**Implementation**
- `Hero.wound: int`, saved, 0 outside a run.
- `Combat.max_hp(h)` returns the base max HP minus the wound. Every heal, readout, threshold and campfire reads `max_hp`, so they respect wounds without special cases.
- The base value stays available (`base_max_hp`) for the wound cap, the 25%-of-max-HP heavy-hit test and HP bar scale, so a wound doesn't make the next hit count as heavier.
- **Where wounds don't apply in 0.68:**
  - The Tower of Trials.
  - The Descent: its own depth loop is untouched in 0.68. Revisit after the playtest.
  - Breach rifts: they keep their back-to-back rule. The rank rules apply to their ordinary fights only if the sim shows breaches turned too soft or too hard. Default: excluded.
- **Not at all:** training fights and the Daily.

## 2. The cost of falling (from Rank C)

A hero knocked out in a C+ rift fight pays the costs below, on top of today's (`knock_out`: about 2 runs out and a morale hit).

**Scar chance** by rank:

| Rank | C | B | A | S | SS / SSS |
|---|---|---|---|---|---|
| Chance (`FALL_SCAR_CHANCE`) | 15% | 20% | 25% | 30% | 35% |

- A scar is one of the existing scar quirks (`Combat.roll_scar`: at most `SCARS_MAX` = 2), treatable at the Medical Bay (`treat_quirk`).
- **What lowers the chance:** the party's expedition-style guards apply, multiplied once each. A cleric halves it, and a Warding or Aegis hero cuts it by a quarter each. The Healers' Wing halves it again.

**A dropped item**
- The fallen hero drops one worn **gear** piece, picked at random. Path relics and the guild's relics are never dropped.
- The item sits in the run (`run["dropped"]`). It comes home if the party seals the rift, and is lost if the party falls, retreats or leaves early.
- One drop per hero per run: a hero who falls twice drops only once.
- The run map shows "Dropped: <item>" until it is resolved.

**Death at SS and SSS**
- A hero who falls with two scars already dies with `FALL_DEATH_CHANCE` (0.5).
- **What happens to them:** they go to the memorial (`_memorialize`, cause "Fell in a Rank %s rift"). Their gear returns to the inventory, except an item dropped in this run, which follows the drop rule. Their Path relic returns to the guild.
- **Warnings:** the Party screen says so before the run, for each hero at risk: "%s has two scars: a fall here can kill them." The rift card at SS/SSS says it too.
- No death is ever a surprise.

**Safety net:** no fall costs in training fights, the Daily, or before the guild's third seal (the same rule that spares the haul).

## 3. Screens, sim and tuning

**What the player sees**
- **HP bars:** a dark, hatched wound segment on fight portraits, the run map's party strip and the hero page. Hover reads "Wounded −X".
- **Wind-up intents:** "Heavy blow: wounds unless guarded or defended" (C+ only).
- **Run map at S+:** the party's total wounds and the dropped item, beside Resolve and the haul.
- **Rift cards, C+:** "Heavy blows wound. A fall can scar and drop gear." At S+: "...Wounds last until a campfire."
- **Party screen:** the death warning at SS/SSS.
- **Reveals,** in the 0.65 one-new-thing style: Wen when Rank C opens (wounds and fall costs), and again when Rank S opens (wounds now last the run).
- **Library entry:** under Fights.
- **Defeat card:** a line such as "Heavy blows taken unguarded wounded %d heroes."
- **Languages:** all new text in Turkish, Spanish and Chinese.

**Auto-fight and the sim**
- `Combat.auto_action` already defends against a heavy blow aimed at the acting hero and breaks wind-ups with Shield Bash or Frost Nova.
- **To add:** Guard an ally who is the target of a heavy blow when the acting hero can't break it. Auto-fight players get the same fix.
- **New campaign_sim counters:**
  - wounds taken and avoided (guarded, defended, dodged, broken);
  - HP share at the boss door;
  - falls per run;
  - scars from falls;
  - items dropped and recovered;
  - deaths.

**Targets** (16 guilds × 45 days, `advice`)

| Measure | Today | Target |
|---|---|---|
| Ordinary fights won, C-A | 99% | 92-95% |
| HP at the boss door, S+ | 91-96% | 65-80% |
| Seals at Recommended power | ~65% | ~65%, after recalibrating rank `rec` and the finales (`balance_sim -- calibrate`) |
| Act pace | — | within about 2 days of today |
| Scars from falls by day 45, casual guild | — | 2-5 |
| Deaths in 45 days | — | 0-1, investor guilds only |

**Knobs**
- Every number is a `var` in GameData, so the sim can sweep it.
- The numbers: `WOUND_SHARE`, `WOUND_CAP`, `WOUND_HEAVY_PCT`, `WOUND_REST_CLOSE`, `WOUND_SHRINE_CLOSE`, `FALL_SCAR_CHANCE`, `FALL_DEATH_CHANCE`.
- The ranks: `WOUND_FROM_RANK` "C" and `WOUND_PERSIST_RANK` "S".
- **If a target can't be reached by tuning,** stop and bring it back to the user rather than ship it.

**Tests**
- Wound math: share, cap, effective max HP, heals stop at the ceiling, and Guard/Defend/dodge never wound.
- Duration: wounds close at fight end at C-A, and last at S+ with a campfire halving them, a shrine closing some, and run end clearing them.
- Ranks F-D never wound. Every C+ ordinary fight has a wind-up by round 2.
- Fall costs: scar chance applied (seeded), the item dropped and recovered on a seal, lost on a retreat, at most one drop per hero, relics never dropped.
- Death only at SS/SSS with two scars, memorialized, with gear returned.
- Safety net: training, the Daily and seals 0-2 have no fall costs.
- Save/load keeps `Hero.wound` and `run["dropped"]`.
- An old save loads with wound 0.

## Out of scope

- The Tower, the Descent's depth loop and breach rifts (revisit after the playtest).
- New foe types or fight objectives. "Clock fights" (approach B) stay an option if wounds alone feel samey.
- Changing `MEND_CAP` or `DODGE_CAP`: wounds go around them instead.
