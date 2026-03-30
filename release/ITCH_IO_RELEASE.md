# ArenaForge itch.io Release

## Current blocker status

- `export_presets.cfg` is missing.
- No verified desktop export has been produced yet.
- No itch.io page art package exists yet.
- The game still needs one manual playtest pass after the latest UI and gameplay fixes.

## Recommended first release

Release the game as:

- `Platform`: Windows
- `Type`: Downloadable
- `Price`: Free
- `Status`: Prototype / Early build

Do not ship Web or mobile on itch.io first. Get one stable Windows build out first.

## Godot export plan

Create these export presets in Godot:

1. `Windows Desktop`
2. Optional later: `Linux/X11`

Recommended output:

- `build/windows/ArenaForge.exe`
- `build/windows/ArenaForge.pck`

Then zip the folder as:

- `build/itch/ArenaForge-windows.zip`

## Pre-upload checklist

1. Launch a clean build.
2. Buy units from the shop.
3. Place units from bench to board.
4. Confirm units are visible in preparation and combat.
5. Confirm enemy team spawns on the opposite side.
6. Confirm 3-of-a-kind auto-merge works for 1-star to 2-star.
7. Confirm 3-of-a-kind auto-merge works for 2-star to 3-star.
8. Confirm item equip and crafting still work.
9. Confirm tooltips work for shop units, bench units, board units, and synergies.
10. Confirm game over and restart flow works.

## itch.io page settings

- `Title`: ArenaForge
- `Short text`: Auto-battler prototype inspired by TFT.
- `Classification`: Game
- `Kind of project`: HTML not recommended yet; use downloadable
- `Platforms`: Windows
- `Tags`: autobattler, strategy, prototype, godot, tactics

## Upload steps

1. Export the Windows build from Godot.
2. Zip the exported folder.
3. Create a new itch.io project page.
4. Upload `ArenaForge-windows.zip`.
5. Mark it as playable on Windows.
6. Paste the text from `release/ITCH_IO_STORE_TEXT.md`.
7. Add screenshots and cover image.
8. Publish as public or restricted.

## Before public release

- Replace placeholder portraits if possible.
- Add at least 3 real screenshots.
- Add one 16:9 cover image.
- Run one balance pass so the first match feels coherent.
