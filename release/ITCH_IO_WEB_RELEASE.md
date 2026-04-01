# ArenaForge itch.io Web Release

## Release target

- `Platform`: HTML5 / Browser
- `Host`: itch.io
- `Price`: Free
- `Status`: Prototype

## Main risks for browser build

- hover-only UX is weaker on touch devices
- performance must stay stable in Web export
- audio can behave differently until user interaction
- browser canvas scaling must be checked on multiple aspect ratios

## Web-specific playtest checklist

1. Load the game in browser without missing assets.
2. Confirm mouse input works for shop, bench, board, and items.
3. Confirm touch input still works well enough in landscape.
4. Confirm tooltip-critical information is still readable without hover.
5. Confirm no text overlaps at common browser sizes.
6. Confirm combat runs smoothly without obvious frame drops.
7. Confirm restart flow works after game over.
8. Confirm browser refresh does not soft-lock the game.

## Recommended itch.io page settings

- `Kind of project`: HTML
- `Embed`: click to play
- `Viewport`: 1280x720 or responsive page embed
- `Fullscreen button`: enabled
- `Automatically start`: disabled
- `Mobile friendly`: enabled only after a real touch pass

## Before public browser release

- upload `build/ArenaForge-web.zip`
- set `index.html` as the launch file
- verify tap/click inspect for board and combat units in exported HTML
- do one browser-specific UI polish pass
- verify one exported HTML build locally before switching visibility from draft
- keep [CREDITS_AND_LICENSES.md](C:\Users\krist\Documents\ArenaForge\release\CREDITS_AND_LICENSES.md) alongside release notes for attribution hygiene
