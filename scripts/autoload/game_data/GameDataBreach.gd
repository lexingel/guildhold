extends "res://scripts/autoload/game_data/GameDataChampions.gd"
## GameData, part 6c: Riftbreaks (docs/design/riftbreak.md). From Act II a
## rift swells every so often: a ladder rank, a region (the camp itself from
## BREACH_CAMP_RANK up) and a countdown in days. Seal a rift of that rank or
## higher first to prevent it; otherwise it breaks, rift runs wait, and the
## guild holds it in a breach rift (back-to-back fights, no camp between).

## A breach rift's floors: a gate (Act VI) holds one more elite.
const BREACH_RIFT_LAYERS := ["combat", "elite", "boss"]
const GATE_RIFT_LAYERS := ["combat", "elite", "elite", "boss"]

const BREACH_UNLOCK_ACT := 2       # campaign_act from which rifts swell (Act I done)
const BREACH_FIRST_DELAY := 3      # days after that until the first one
const BREACH_EVERY_MIN := 8        # days between one breach being dealt with and the next
const BREACH_EVERY_MAX := 12
const BREACH_WARN := 6             # days from swelling to breaking
const BREACH_UP_CHANCE := 0.35     # the breach is a rank above your best seal (when that rank is open)
const BREACH_CAMP_RANK := "S"      # this rank and up break at the camp
## Rewards scale with the rank: 1 + BREACH_RANK_SCALE per ladder step.
const BREACH_RANK_SCALE := 0.35
const BREACH_PREVENT_ESSENCE := 15
const BREACH_HELD_GOLD := 80
const BREACH_HELD_ESSENCE := 30
const BREACH_LOSS_SHARE := 0.2     # of stored Essence, and Gold above the coming payday's bill, when a defense is lost
## A lost tide (the Open Hollow) costs less: one breaks every week, and a
## Break guild at its wall lost 20% a week until it had nothing (0.35 sim).
const TIDE_LOSS_SHARE := 0.1
const BREACH_REPAIR_BASE := 40     # Gold to repair a damaged building: base + step x its level
const BREACH_REPAIR_STEP := 30
