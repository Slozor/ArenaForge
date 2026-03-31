# ArenaForge Release and PvP Roadmap

## Current Position

ArenaForge is now beyond placeholder-prototype stage in the core loop:
- shop, bench, board, combat, items, synergies, and upgrades exist
- UI is being hardened for browser and mobile
- art direction is moving toward a consistent licensed/CC0-first presentation
- NPC-driven matches and unit abilities are in progress

## Stage 1 - Browser Release for itch.io

Goal: ship a stable HTML5 build that is fun to click through in a browser.

Must-have:
- one verified Godot Web export
- no missing assets or broken `class_name`/parser issues in browser builds
- responsive UI on common browser sizes
- touch-safe tap flows for unit inspect, buy, move, and item equip
- visible match result and restart loop
- readable board, bench, shop, tooltips, and combat feedback
- acceptable performance on mid-range laptops

Nice-to-have before launch:
- final pass on placeholder art replacements
- better sound cues for buy, cast, hit, and victory
- short browser onboarding text

Release checklist:
1. Export Web build locally.
2. Test one clean browser session.
3. Test mouse, trackpad, and touch if available.
4. Fix layout breaks at narrow and wide aspect ratios.
5. Upload HTML build to itch.io with screenshots and a short description.

## Stage 2 - Singleplayer Finish

Goal: make the game feel complete before any real PvP networking.

Must-have:
- finalize NPC opponent presentation and round variety
- finish mana abilities and item tuning
- improve visual clarity for units on board/combat
- balance opening rounds, creep rewards, and economy
- add more polish to animations, hit feedback, and sound

Nice-to-have:
- fuller set of units, traits, and items
- a better tactician/avatar layer
- better end-of-run summary and progression hooks

## Stage 3 - Real PvP

Goal: replace NPC opponent simulation with real online matches.

Core systems needed:
- matchmaking and lobby flow
- deterministic combat resolution or authoritative server simulation
- sync for shop rolls, unit placement, combat start/end, and RNG
- reconnect handling and disconnect rules
- anti-cheat strategy
- region/timeouts/lobby recovery

Design changes needed:
- 8-player lobby flow
- visible opponent scouting
- live placement snapshots and combat result delivery
- better spectator/ghost handling

Technical prerequisites:
- lock down combat rules so they are fully data-driven
- remove any hidden client-only state from battle resolution
- log run summaries and replayable state

## Suggested Order

1. Finish browser release readiness.
2. Lock the singleplayer content loop.
3. Add replay/reconnect-safe combat state.
4. Implement PvP lobby and authoritative match flow.
5. Expand balance and live-ops tooling after PvP is stable.
