# ArenaForge Art Pipeline

Goal: ship a clean, cheap, license-safe presentation layer that works on PC and mobile without a heavy art team.

## Direction

- Use CC0-first assets.
- Prefer simple 2D shapes, silhouettes, badges, and icons.
- Keep the UI readable on small screens.
- Tint reusable SVGs instead of creating many unique images early.

## Pipeline

1. Start with reusable placeholder SVGs in this folder.
2. Replace placeholders with free CC0 packs or original art later.
3. Track every imported asset in `assets/manifest.json`.
4. Keep replacement priority high for anything shown during core gameplay.

## Current placeholders

- `ui/arena_background.svg`
- `ui/card_frame.svg`
- `ui/board_tile.svg`
- `ui/bench_slot.svg`
- `ui/gold_icon.svg`
- `ui/trait_badge.svg`
- `portraits/placeholder_unit.svg`
- `items/placeholder_item.svg`

## Preferred sources

- Kenney CC0 packs for UI, icons, and simple 2D placeholders.
- OpenGameArt only when the license is explicitly CC0 or otherwise compatible.
- Original SVGs made in-house for generic board, badge, and silhouette shapes.

## Reference set used for this pass

- [Teamfight Tactics homepage](https://teamfighttactics.leagueoflegends.com/en-us/) for the high-level readability target and cross-platform framing.
- [Kenney UI Pack](https://kenney.nl/assets/ui-pack) and [Pixel UI pack (750 assets)](https://opengameart.org/content/pixel-ui-pack-750-assets) for CC0-safe UI proportions, panels, and button language.
- [UI Pack - Pixel Adventure](https://lpc.opengameart.org/content/ui-pack-pixel-adventure) for a more retro-friendly, pixel-forward UI direction.
- [Pixel icons](https://opengameart.org/content/pixel-icons) and [Ultimate Icons Pack](https://opengameart.org/content/ultimate-icons-pack) for icon clarity at small sizes.

## License note

The shipped ArenaForge art in this pass is original SVG work and CC0-inspired layout work, intended to be safe for commercial use. External references listed above were used to guide the visual direction, not to copy proprietary Riot assets.
