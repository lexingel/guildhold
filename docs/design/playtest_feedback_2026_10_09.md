# Playtest feedback, 2026-10-09 (30 items)

Semih's own playthrough of 0.66.0. Each item: what's wrong, where, the fix. Causes marked **confirmed** were read in the code; **likely** means not reproduced yet.

## Batch A: combat bugs (one root cause covers most)

Two faults in the fight loop explain 15, 16, 22 and 24:
- **(A)** `_run_combat_turns` (BattleView.gd:1061) plays monster turns in a loop and never redraws the turn strip or the command bar, so the last hero's bar stays up.
- **(B)** At a round boundary the "is this a hero who needs input?" check is skipped (BattleView.gd:1074), so the hero who opens the new round is auto-played with last round's action. **Confirmed.**

| # | Item | Fix |
|---|---|---|
| 16 | Ranger's turns turned to auto play | Use `Combat.peek_next_turn(state)` for the hero check (one line). Not ranger-specific: any hero who opens a round. |
| 15 | Turn order stuck on the hero during monster turns | Rebuild the turn strip and an "Enemy turn" bar before each monster turn; clear stale hotkeys. |
| 24 | Previous hero's bar stays visible | Same as 15 + 16. |
| 21 | Guard has no ally pick; clicking a monster attacks | Ally-pick mode puts click targets on heroes (not monsters) and never falls through to Attack. Tonic has the same bug. |
| 22 | Momentum doesn't rise | Attack logic is right; the Guard leftover state, the stale replays (B) and the stun case (23) make turns not be the attack you clicked. Fixed by 16/21/23. |
| 23 | Shield Bash deals no damage | A stunned hero still gets the full bar; the bash animates but the turn is lost. Stunned heroes skip their turn visibly ("Stunned"). |
| 14 | Monsters shrink when one spawns; units float | Monster size divides by all monsters, dead ones included; give them the heroes' fixed size. Floating: back-row/odd monsters are lifted 6% without shrinking and the idle sway only rises; drop the lift (or shrink for depth) and centre the sway. |

## Batch B: other bugs

| # | Item | Cause | Fix |
|---|---|---|---|
| 17 | Rank D recruit can't spend skill points | **Confirmed.** Skill tree UI still checks the old level gate (`RosterView.gd:726`, Tier 1 needs Lv2, recruits are Lv1). Blocks every new hero. | Use `GameData.node_lock` like the backend does. Top priority. |
| 3 | Skipping the cinematic loses the Night of Breaking VA | **Confirmed.** Found runs `render()` before `_play_cinematic`, which marks the VA heard, then stops it (`Main.gd:2035`). | Swap the two lines; add a test. |
| 25 | Training Yard opened the Medical Bay | **Likely.** The guild status board's "N wounded" line sits over the front buildings and takes the click. | Keep the board clear of the building hotspots (cap its height / solid panel). |
| 26 | Yard warrior is a full-plate knight | Base warrior has no walk art; it falls back to the old knight walk cycle. | New walk frames matching the hero (PixelLab), or a static portrait as a stopgap. Check the other 4 roles too. |
| 12 | Treasure room has no pick button | Treasure uses a tile with an invisible button; loot after battles uses cards with "Take". | Reuse the battle loot cards. |

## Batch C: UI polish

| # | Item | Fix |
|---|---|---|
| 1 | No Settings on the title screen; no master volume | Add Settings to the title menu; add a Master slider (bus 0) saved with the others. |
| 5 | Quirks look like plain text | Style quirk chips like role tags (underline + hover card). |
| 7 | Guild: payroll/rival need borders; Records is a wall of text | Panels for payroll and rival; explanation paragraphs into tooltips; Records shows a few key numbers, the rest behind "Show all". Fix the stale "Epic relic" Renown tooltip. |
| 8 | Library is stale | Text pass: Campaign says 3 acts and the Endless Rift; Champions, Controls, Attributes (buying points), Renown (Epic relics), Riftbreaks (Wardcraft), Hero requests (5 of 20), Relics tab falls back to old relic-type icons. Hide parked-mode lines. Old coach tips for Champions/Overseer mention the Endless Rift too. |
| 9 | Rift Hall portals | Big centre portal = ranked rifts, small left = Endless (or the Descent while Endless is parked), with a marker on top. Swap the entries in the gates list (`Main.gd:2235`). |
| 10 | Party: front row from the right, back row from the left | Re-sort the party after each change: back row fills from the left, front row from the right next to the foes. |
| 11 | Hero pages button | Add one on the victory screen when someone levels up; make the node-map one a bigger, labelled button. |
| 13, 27, 12 | Campfire, Medical Bay, treasure art small | Size node art and hub banners by window width instead of fixed 320x200 / 640x160. Campfire art is the wrong shape (400x157); needs a 1.6:1 piece. |
| 18 | Lesser rift map | Bigger map and nodes on PC; legend in one row (or beside the map); fewer cross links so some choices close roads (Slay the Spire style). The lane generator already does lanes; lower the 50% neighbour-link chance and draw it larger. |
| 20 | No run buffs on the node map | Show boons, next-fight Momentum, relic ward and blessings in the run bar. Next-fight Momentum is never shown today. |
| 28 | Inventory doesn't show equipped items | Add an "Equipped" filter that badges the owner; Unequip from the item card. |

## Batch D: design (your call)

| # | Item | My recommendation |
|---|---|---|
| 2 | More crests / custom crests | A picker for the 8 crests now (today it's dice only), 8 more crests from PixelLab later. Upload on the web build is possible but touches ~8 places and the save; later. |
| 4 | Tips choice after the Act I lore screen | Build as asked: Guide me (all tips), Help a little (welcome, first battle, rift hall, party, plus the system-unlock toasts), No tips. Settings cycles the three. |
| 6 | Don't give 3 heroes at the start | Start with 1 hero (warrior) and enough Gold for 2 recruits plus 2 rerolls. Needs a sim check on Act I pacing. |
| 19 | Shrine "Move on" has no consequence | Make it a real choice: Kneel costs something (a hero's HP or 1 Resolve for the blessing), Move on gains a little (search the offerings: small Gold). Model: the Quiet Shrine event. |
| 29 | Training costs Gold, Act I is Gold-starved | Move the Training Yard fee to Essence ("Essence empowers" fits). Path Mastery also uses Essence; sim both. |
| 30 | Expeditions for idle heroes | Worth doing. Model it as a Training Yard job: pick a quest board job (size, risk, days), send 1-3 idle heroes, chance of success from their power, returns Gold/Essence/items and sometimes an injury. Reuses the away flag, day tick and reward code. Needs its own design pass. |

## Order of work
1. Batch A + 17 + 3 (the bugs that break play), one release.
2. Batch B/C rest, one release.
3. Batch D after your calls.
