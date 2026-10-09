# Open design calls from the 2026-10-09 playtest

Three calls: the starting roster (6), expeditions (30), and what Renown pays now that the old relic reward has gone.

## 1. The founders (item 6)

**Today:** a new guild is handed a warrior, a cleric and a ranger or mage (all Rank F, hired free), plus 100 Gold and a week of wages. A recruit reroll costs 20 Gold, doubling up to 4 times.

**The problem:** the first thing the player owns is a party they didn't choose. Rerolling to shape it costs the same Gold they need for payday.

**Options**
- **A. Founding board (recommended).** No starters. The first recruit board is a founding board: 6 Rank F offers covering all five roles. You sign 3, free as now, and get 3 free rerolls on the offers you haven't taken. After that the board works as normal. You still start with 3 heroes, which is what Act I is balanced on, but they're yours.
- **B. One founder plus a purse.** You start with a warrior and enough Gold for 2 signings plus rerolls. This is closer to your note, but every hire costs Gold, and Gold is what Act I is short of. The sim would need rebalancing.
- **C. Keep the three starters and make the first week's rerolls free.** This is the smallest change and the weakest fix.

**Price (story rule):** a founder picked from the board stays as a founder. Founders get a "Founder" title that matters later, for example +5 morale floor. Optional.

**Text change:** the welcome tip "Your first three heroes have signed on" becomes "Sign three founders from the board".

## 2. Expeditions (item 30)

**The idea:** heroes who are idle while others train, rest or wait for Gold can be sent on a job off the map. They come back days later with resources if they succeed. It runs alongside the rifts and never replaces them.

**Recommended shape**
- **Where:** the Quest board's second tab, "Expeditions". It opens with the Training Yard (2 seals), when idle heroes first exist.
- **The board:** 3 postings, replaced with the quests every 3 days. Each posting has:
  - a name
  - a region
  - a length of 1–3 days
  - a party size of 1–3 heroes
  - a **Need** (power)
  - a reward line
  - a risk line
- **The chance:** shown before you send anyone, `50% + 50% × (party power / Need − 1)`, capped at 10–95%. Some roles add to it: a ranger scouts (+10%), a rogue finds more (+25% reward), and a cleric halves the injury roll.
- **Outcomes:**
  - **Success:** the full reward.
  - **Partial:** under half the chance roll. Half the reward and one hero comes back wounded.
  - **Failure:** no reward and an injury roll per hero.
  - Nobody dies. Heroes always gain about a third of a level of XP per day away, like training.
- **Rewards:** mostly Gold, because Act I is short of it. Sometimes Essence, and on long jobs an item roll. As a balance guard, an expedition pays about 60% of what the same heroes would earn in a rift that day, so rifts stay the main loop.
- **The price:**
  - the heroes are gone for the days (no rifts, no training), and their wages still run
  - the injury risk
  - one expedition at a time, two at Scouts' Lodge Lv3
- **Reports:** short notes from Dobbs when the party gets back, in the plain voice. For example: "Back from the salt marsh. Two crates of copper, one sprained ankle. Bryn wants a raise."
- **Code:** a hero away on an expedition reuses the Training Yard's job (`h.training = {"program": "expedition:<id>", ...}`). The away flag, day tick, recall and roster tag all exist already, and the reward reuses `_camp_fx`. New pieces: an `EXPEDITIONS` table, the board tab and the outcome roll.

**Questions for you**
1. Should it open with the Training Yard (2 seals)? I recommend yes. The alternative is Act II.
2. Can a failed expedition scar a hero (a lasting quirk), or only wound them? I recommend wounds only.
3. Should some expeditions carry story, such as a fragment of the story web or a hero request? I recommend later, once the base works.

## 3. Renown's reward

**Today:** the Renown tooltip promised that "every 20 Renown arms an Epic relic". Since 0.66 that has done nothing: `pending_shop_boost` is set and never read. I removed the text. Renown still decides the rival race, recruit picks at payday and the monthly prize.

**Options**
- **A. Leave it (recommended for now).** Renown already pulls its weight through the rival. Adding nothing keeps the focus plan's "one system per job".
- **B. Restore it in 0.66 terms:** every 20 Renown puts one unique relic in your next shop. It's cheap to build, since shops already stock relics 20% of the time.
- **C. Royal contracts:** at 50/100/150 Renown the quest board posts a Crown contract (bigger, harder, pays Laurels). This is the most interesting option and the most work.

## Decided and built (2026-10-09)
- Expeditions open with the Training Yard; a failed perilous job can scar.
- Every class and every Path has an expedition bonus (GameData.EXPEDITION_BONUS), counted once per party.
- Heroes are locked away for the whole days while rifts and breaches go on: splitting the roster between expeditions and training is a risk taken for resources, so a job pays well. Sim-checked in 0.67.1: Need comes from the lower third of the roster's power and pay from the rank those heroes could run (EXPEDITION_GOLD 1.8/2.2/2.8 and EXPEDITION_ESSENCE 0/1.8/3.2 x a fight's coin and Essence there, per hero-day). Bench heroes earn about 81 Gold and 25 Essence a hero-day after the odds (the top four make 144 and 59 in the rifts), with wages at 39% of income. The first cut (pay at the best sealed rank) gave investors 242 Gold a hero-day and about 100k Gold in 45 days. Casual guilds first reached Act V later with expeditions on (1 of 8 by day 45, against 4 of 8 without). Not wounds and not short parties: the sim's casual player sent the two spare heroes away before training, so with six heroes nobody could fill in for a capped hero on a Path course (10 courses in 8 guilds, against 22). With expeditions sent after training it is 3 of 8 by day 45 (4 by day 46) and 15 courses: about even. A real player can make the same mistake; the Act panel's advice already points at the course.
- Founders: option A, the founding board (6 Rank F offers with every role, 3 sign free and pay their first week, 3 free rerolls). Tests and sims still found with `hire_starters`.
- Renown: option A, it stays the rival race; nothing added.
