# Guildhold art style guide

The rules every art batch follows, so new art sits with the old. Written for 0.52 (October 2026) from what the 0.47–0.52 passes learned.

## Look

- Dark-fantasy pixel art, muted and detailed: deep violets, ember oranges, cold blues; no saturated "mobile game" colour.
- Heroes wear their role colour: warrior steel with a deep red tabard, ranger forest green and brown leathers, mage deep blue robes, cleric white and gold, rogue dark violet leathers.
- Light falls from above; dark outlines; heavy shading on foes.

## Native sizes

| Art | Size | Notes |
|---|---|---|
| Hero and champion portraits | 96 × 200 | `create_image_pro_flash`, style ref Brannoch |
| Foe battle sprites | up to 200 × 200 | pixflux 200, seed 7, palette-locked to the old sprite |
| Walk cycles | 64 × 64 | 8 frames from a 64 px copy hosted on GitHub raw |
| Skill icons | 32 × 32 | generated at 64, box-downscaled |
| Item and relic icons | 40 × 40 | generated at 64, box-downscaled |
| Battle effects | 128 × 128, 7 frames | shown at up to ~1.5× in a fight |
| Story pictures | 288 × 120 | `create_image_pro`, style ref the cinematic night |

Icons are drawn at whole multiples of their size (`UiKit.pixel_size`).

## Facing

- Foes stand on the right and face **left**. Heroes and champions stand on the left and face **right** (or front).
- Every foe sprite has an entry in `GameData.FOE_FACING` (left, right or front), checked by eye against the battle sprite and walk frames together. A foe drawn facing right is mirrored automatically. `test_sprite_facing` fails if a foe sprite has no entry.

## Animation

- Attack, hit and skill: 4 generated frames plus the base (5 in all). Fights play them with `ACTION_BEAT` timing (a held wind-up and strike).
- Prompts say "body motion only, keep every colour exactly the same, no effects". Generators add flashes and explosions otherwise; effects come from the separate effect sets.
- When a frame still flashes, hold the neighbouring pose instead of re-rolling a third time (`patchframes.py`, `foe_patch.py`).

## Effects

- One set per way of fighting (`Fx.hero_hit`, `Fx.foe_hit`): cleave (warrior), twin cut (rogue), arrow hit (ranger), holy strike (cleric), a burst per element for mages (fire, frost, arcane, shadow, thorn), rake (melee foes), element bursts or acid (ranged foes).
- They swell and fade over their second half in code (`Fx.FADES`).

## UI

- Light, not boxed: borders mean state (ember = needs you, violet = selected), at most two boxes deep.
- Cards are 9-slice textures with pixel-stepped corners and a small corner bracket one shade lighter than the fill (`assets/ui/card_*.png`). Ember cards keep their 1 px ember border.
- Text is never drawn under 14 px on a 1280 × 800 canvas (`UiKit.ui_size`).

## Checks before installing a batch

1. A review sheet of every frame next to the art it replaces.
2. No flashes, no wrong colours, facing recorded.
3. Run the tests (`test_art_coverage`, `test_media`, `test_sprite_facing`).
