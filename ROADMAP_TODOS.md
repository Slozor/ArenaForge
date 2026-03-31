# ArenaForge Roadmap Todos

## Phase 1 - Core Systems

- [x] Add item inventory, item equip, and basic item combination rules.
- [x] Add round types: neutral, player combat, and shared draft/carousel placeholder.
- [x] Move combat content further into data where possible.
- [x] Expand roster, traits, and items so multiple team comps are viable.
- [~] Replace PvE-only flow with real multi-opponent match flow scaffolding.
- [~] Extend progression with 3-star upgrades and level/odds balancing pass.
- [~] Add end-of-game placement/results screen.

Owner: `Core Systems Agent`
Primary files:
- `scripts/autoload/*`
- `scripts/game/*`
- `data/*`

Status:
- Core item, reward, and round-data foundations are in.
- Multi-opponent flow and 3-star UI integration still need a follow-up pass.
- End-of-run placement data is recorded, but the visible results screen is still pending.

## Phase 2 - PC + Mobile UX

- [ ] Replace fixed-position UI with responsive container-driven layout.
- [ ] Support desktop and phone aspect ratios cleanly.
- [ ] Improve touch UX: tap-first interactions, larger targets, clearer feedback.
- [ ] Add tutorial/tooltips/help surfaces for core actions.
- [ ] Add settings screen with audio, quality, and input options.
- [ ] Add basic save/state flow for profile and settings.
- [ ] Review renderer/performance choices for mobile targets.

Owner: `Cross-Platform UX Agent`
Primary files:
- `scenes/*`
- `scripts/ui/*`
- `project.godot`

## Phase 3 - Art + Presentation

- [x] Define low-cost art direction for free-to-ship prototype visuals.
- [x] Build an asset intake plan using free CC0-first sources.
- [ ] Replace placeholder blocks with simple production-ready board/UI/icon visuals.
- [ ] Add trait icons, unit portraits/silhouettes, item icons, and background art.
- [ ] Add lightweight VFX/SFX plan for attacks, damage, purchases, and wins/losses.
- [x] Create an asset manifest with source, license, and replacement priority.

Owner: `Art Pipeline Agent`
Primary files:
- `assets/*`
- `scenes/*`
- `scripts/ui/*`

## Phase 4 - Release + Multiplayer

- [ ] Produce one verified browser export for itch.io.
- [ ] Finish browser/mobile-safe inspect and touch flows.
- [ ] Remove remaining placeholder art and missing textures.
- [ ] Tune visibility, audio, and feedback for launch quality.
- [ ] Stabilize combat state for replayable, network-ready resolution.
- [ ] Add PvP lobby, matchmaking, and authoritative battle sync.
- [ ] Add reconnect/disconnect handling and ghost/scout presentation.

Owner: `Release and PvP Planning`
Primary files:
- `release/*`
- `scripts/game/*`
- `scripts/combat/*`
- `scripts/ui/*`
- `data/*`

Status:
- Browser release is the next shipping target.
- PvP is intentionally planned after singleplayer and browser stability.
- `release/ITCH_IO_AND_PVP_ROADMAP.md` holds the staged release path.

## Shared Rules

- Keep changes small and data-driven.
- Prefer free and license-safe assets, CC0 first.
- Optimize for PC and mobile from the same codebase.
- Do not revert unrelated edits from other agents.

## Phase 5 - TFT-like Singleplayer Finish

Research basis:
- TFT relies on run-shaping systems beyond core combat, especially Augments, Carousel/Armory-style reward rounds, and set mechanics such as Opening Encounters/Hacks.
- For ArenaForge without PvP, the closest equivalent is a polished singleplayer run with clear encounter modifiers, richer reward rounds, stronger NPC identity, better inspect/tutorial surfaces, and more content/balance depth.

Tasks:
- [x] Add Opening Encounters that change the whole run.
- [x] Add richer Armory/Draft reward rounds with clearer choices and stronger rewards.
- [x] Give NPC opponents clearer identities through formations and themed boards.
- [x] Expand crafted item identity so late items are not just bigger stat sticks.
- [x] Add tutorial/help surfaces for the main loop: buy, place, merge, equip, cast.
- [x] Add more complete run polish: audio hooks, stronger round transitions, cleaner end-of-run summary.
- [~] Run repeated full-run QA and rebalance economy, rewards, and late rounds.

Current sequence:
1. Opening Encounters
2. Armory/Draft improvement
3. NPC identity and formations
4. Item identity
5. Tutorial/help
6. QA and rebalance
