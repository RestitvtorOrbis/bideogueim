# PERF-01 - Apply NPC visual tiers and add an FPS counter

Status: Complete

## Problem and evidence

The recent human-model and locomotion integration made the playable build feel slower. AI calls are distance-throttled in `population_manager.gd`, but all activated human visuals are initialized at normal animation tier and full visibility. No runtime code changes those tiers by distance, so up to 250 `AnimationPlayer`/skeleton instances continue processing even when their NPC AI ticks only every 0.15 or 0.5 seconds. `HumanCharacterVisual` stores throttled/frozen tiers, but throttled currently limits locomotion state selection rather than demonstrably limiting animation evaluation. The HUD has no FPS readout.

Reference evidence from `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\benchmark.ps1 -DurationSeconds 15`: 250 active NPCs, 62.6 headless average FPS, 316,641,966 peak static-memory bytes. This is a structural baseline, not a rendered-GPU target.

## Goal

Reduce per-frame NPC visual/animation work according to distance while preserving nearby animation quality, and show a low-overhead live FPS counter in the gameplay HUD.

## Ownership boundary

- `scripts/npc/npc.gd`
- `scripts/npc/population_manager.gd`
- `scripts/visual/characters/human_character_visual.gd`
- `scripts/resources/crowd_settings.gd`
- `resources/default_crowd_settings.tres`
- `scripts/ui/hud.gd`
- `scenes/HUD.tscn`
- Directly scoped assertions in `tests/test_population.gd`, `tests/test_character_visuals.gd`, and/or a focused HUD test if one already fits the runner
- This ticket file

## Exact implementation scope

- Apply visual distance tiers from the population manager without changing gameplay AI decisions:
  - 0 through 35 m: full visibility and normal continuous animation.
  - over 35 through 75 m: reduced visibility and animation evaluation/state refresh at no more than 10 Hz.
  - over 75 through 100 m: reduced visibility with locomotion frozen in idle and no continuous animation evaluation.
  - over 100 m: hidden visual with locomotion frozen and no continuous animation evaluation.
- Keep thresholds resource-configurable, retaining the existing 35 m and 75 m AI thresholds and adding only the minimum visual threshold setting needed for 100 m hiding.
- Tier transitions must be idempotent: do not restart/stop animations, traverse meshes, or reapply visibility every physics frame when the tier did not change.
- Pool activation starts from a valid nearby/full state; pool release leaves animation frozen and visual hidden; reuse must not retain a stale tier.
- Preserve model choice, palettes, locomotion clip mapping, collision, combat, movement, spawn/recycling, role behavior, and the 250-NPC cap.
- Add an `FPS` label to the existing HUD. Update it at a low fixed cadence (roughly 2-4 times per second) from `Engine.get_frames_per_second()`, with no per-frame text allocation requirement.
- Keep the FPS counter visible during normal gameplay and avoid changing score/health/combo behavior.

## Non-goals

- No model replacement, texture downgrade, population reduction, gameplay-speed change, renderer setting change, new graphics menu, profiler overlay, benchmark redesign, export logic change, or broad regression suite expansion.

## Acceptance criteria

- Distance transitions produce the four specified visual/animation behaviors at exact boundaries and on both outward and inward movement.
- Mid-tier animation work is explicitly bounded to 10 Hz or less; frozen and hidden tiers do not continuously evaluate skeleton animation.
- Repeated assignment of an unchanged tier performs no playback restart or repeated visibility work.
- Pool release/reactivation resets all visual-tier state correctly.
- The HUD displays an integer `FPS: N` value and refreshes it at a bounded cadence without affecting existing HUD signals.
- Focused visual/population tests and the complete minimum repository test workflow pass.
- A post-change 15-second headless benchmark still holds 250 NPCs, makes no post-warmup pool allocations, passes its 30 FPS gate, and records its result for comparison without claiming rendered-GPU equivalence.

## Required validation

- Add focused assertions for exact distance boundaries, idempotent transitions, bounded/manual animation evaluation, frozen/hidden processing, pool reset/reuse, and FPS formatting/cadence.
- Run the focused character-visual and population test entry points.
- Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1` as the minimum complete suite.
- Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\benchmark.ps1 -DurationSeconds 15`.
- Run a bounded headless `Main.tscn` smoke.
- Run `git diff --check`.

## Dependencies and handoff

- Implement after GAMEPLAY-05 is accepted and committed because ownership overlaps.
- Existing open UXR-07/UXR-05B2 describe broader visual work; this ticket is limited to the observed performance regression and FPS visibility and must not claim those tickets complete.
- Luna must report changed files, exact commands/results, known limitations, and deferred decisions.
- Sol must inspect all changes, record validation below, rename this file with `_complete`, and close it in one dedicated atomic commit containing no unrelated changes.

## Validation evidence

### Paused checkpoint - 2026-08-09

- User requested that work stop and be saved for later. The single Luna xhigh round was interrupted cleanly with no command left running; no PERF-01 commit or ticket rename was made.
- Modified implementation/test files at pause: `scripts/npc/npc.gd`, `scripts/npc/population_manager.gd`, `scripts/visual/characters/human_character_visual.gd`, `scripts/resources/crowd_settings.gd`, `resources/default_crowd_settings.tres`, `scripts/ui/hud.gd`, `scenes/HUD.tscn`, `tests/test_population.gd`, `tests/test_character_visuals.gd`, and `tests/test_system_contracts.gd`.
- Focused population runner passed.
- Full suite reported the new PERF-01 assertions passing, with two asserted failures reported as pre-existing/adjacent: ordinary wander radius and initial population marker height. Sol has not independently reviewed that classification.
- The 15-second benchmark retained 250 NPCs and made no post-warmup pool allocations, but averaged 13.66 FPS and failed the 30 FPS gate. This is below the 62.6 FPS pre-change headless reference and blocks acceptance.
- `git diff --check` passed before Luna's final small test adjustment and must be rerun.
- Main-scene smoke was not run.
- Remaining work: Sol must inspect the diff and benchmark regression, determine whether the current manual/throttled animation mechanism caused the slowdown, perform only evidence-backed correction within the existing round constraints, rerun focused/full validation, benchmark, smoke, and diff check, then decide acceptance. Keep this ticket open until all gates pass.

### Final acceptance

- Sol inspected all implementation and tests. The change remains inside the ticket boundary and preserves GAMEPLAY-05 roaming anchors, gameplay AI, combat, spawning, pooling, model/palette selection, locomotion clip mapping, and the 250-NPC cap.
- Runtime tiers are exact and idempotent: `0..35 m` uses full/continuous animation, `>35..75 m` uses reduced/manual animation advanced at a bounded 0.10-second cadence, `>75..100 m` is reduced/frozen, and `>100 m` is hidden/frozen. Pool release freezes/hides and checkout restores full/normal state.
- The HUD exposes an integer `FPS: N` label and refreshes it every 0.25 seconds while preserving existing score, combo, health, and gore behavior.
- The fresh GPT-5.6 Sol medium advisor recommended repeating benchmarks in isolation before changing code because the failed 13.66 FPS run could be contaminated by concurrent Docker work and the code-side workload did not explain a 4.6x throughput loss. Sol adopted that evidence-backed recommendation.
- Two sequential isolated warm runs of `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\benchmark.ps1 -DurationSeconds 15` passed: 119.176965620541 FPS / 1,788 frames / 316,856,864 peak static-memory bytes, then 121.118438701576 FPS / 1,817 frames / 316,922,676 bytes. Both retained all 250 NPCs and made no pool allocations after warmup. The earlier 13.66 FPS result is classified as contaminated; no speculative code change was made.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`: exit 0. The first independent run exposed two stale assertions: ordinary civilian radius still measured from the player despite GAMEPLAY-05, and marker height still required exactly 1.2 despite VISUAL-02 grounding. Sol updated only those assertions to the already-approved anchor-relative radius and grounded-clearance-to-marker-height contract; the rerun passed, including all PERF-01 tier, manual-processing, idempotence, pool-reuse, and FPS cadence assertions.
- `docker compose run --rm godot-tools --headless --path /workspace --scene res://scenes/Main.tscn --quit-after 300`: exit 0. Godot retained the existing bounded-shutdown warnings for two ObjectDB instances and one resource still in use.
- `git diff --check`: exit 0 with line-ending conversion warnings only.
- All acceptance criteria and required beta-MVP validation are satisfied. Rendered Windows GPU performance remains distinct from the headless benchmark and is covered by the exported candidate smoke rather than inferred from these numbers.
