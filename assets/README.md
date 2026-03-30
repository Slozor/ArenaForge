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
- `ui/gold_icon.svg`
- `ui/trait_badge.svg`
- `portraits/placeholder_unit.svg`
- `items/placeholder_item.svg`

## Preferred sources

- Kenney CC0 packs for UI, icons, and simple 2D placeholders.
- OpenGameArt only when the license is explicitly CC0 or otherwise compatible.
- Original SVGs made in-house for generic board, badge, and silhouette shapes.
