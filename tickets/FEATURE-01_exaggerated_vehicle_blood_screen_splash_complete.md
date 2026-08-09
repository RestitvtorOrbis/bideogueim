# FEATURE-01 — Exaggerated vehicle blood screen splash

## Goal

When a qualifying NPC is hit by the vehicle, cover a conspicuous portion of the player's screen with an intentionally exaggerated, short-lived blood-splatter overlay, while preserving the existing world-space impact effects and gore preset controls.

## Context and evidence

- `Npc.receive_vehicle_impact()` already emits one qualifying `ImpactEvent` with `impact_kind == &"vehicle"` and the NPC world position.
- `scripts/effects/impact_effects.gd` already subscribes to `ImpactBus` and owns bounded pools for world-space blood hits, particles, decals, fragments, flash, and audio.
- The retained CC0 Kenney splat PNGs in `assets/vfx/blood/` have transparent backgrounds and are suitable for screen-space overlays.
- `ViolenceSettings` already defines FULL, REDUCED, and DISABLED presets. The new overlay must obey `blood_particles_enabled` and density, and must emit nothing for DISABLED.

## Ownership boundary

- `scripts/effects/impact_effects.gd`
- `tests/test_system_contracts.gd`
- This ticket file

## Exact implementation scope

- Add a bounded, reusable screen-splash pool under a runtime `CanvasLayer` owned by `ImpactEffects`; do not allocate new overlay nodes per impact.
- Use the existing retained Kenney splat textures, with varied placement, scale, rotation, and opacity that visibly covers the screen without obscuring it permanently.
- Trigger multiple splats only for `impact_kind == &"vehicle"`; projectile impacts must not trigger the screen overlay.
- FULL must be deliberately excessive; REDUCED may be visibly lighter through the existing density setting; DISABLED must remain silent.
- Fade and hide every overlay entry automatically within a short finite lifetime and ensure recycled entries reset their visual state.
- Keep the pool count finite and low enough for the beta build.

## Non-goals

- Do not change NPC impact detection, scoring, physics, health, respawn, camera behavior, or existing world-space gore behavior.
- Do not add, download, or modify image assets.
- Do not change the gore menu labels or preset semantics.
- Do not touch vehicle model files or vehicle scenes.

## Acceptance criteria

- A qualifying vehicle impact with FULL gore makes several blood splats visible in screen space immediately.
- A projectile impact does not activate the screen-splash pool.
- DISABLED gore does not activate the screen-splash pool.
- Active splats fade and become hidden after a finite lifetime.
- The pool has a hard upper bound and reuses its nodes.
- Existing impact pools and effects continue to satisfy their current contracts.

## Required validation

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`
- Minimum direct contract assertions in `tests/test_system_contracts.gd` for bounded pool size, FULL vehicle activation, projectile exclusion, DISABLED exclusion, and finite fade/hide lifecycle.
- Decision-owner review of the diff and all test output.

## Dependencies and handoff

- Depends only on the existing ImpactBus/ImpactEvent/ViolenceSettings contracts and retained Kenney textures.
- Handoff must list changed files, validation commands/results, known limitations, and deferred decisions.

## Validation record

- Decision-owner diff review: accepted. The implementation remains within the stated ownership boundary and meets every acceptance criterion.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`: PASS (exit code 0; all contract assertions passed, including the new bounded pool, vehicle-only activation, disabled exclusion, and fade lifecycle checks).
- `git diff --check`: PASS.
- Known baseline diagnostics: Godot still reports 6 leaked ObjectDB instances and 2 resources in use at process exit; the suite nevertheless exits 0 and this ticket does not alter those lifetimes.
- No deferred product decisions.
