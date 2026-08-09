# WORLD-03 - Add five-state breakaway street lamps

Status: Complete

## Requested outcome and evidence

Street lamps are currently too resistant. They must bend from a stationary vehicle applying force, bend at lower driving speeds, progress through exactly five persistent states according to speed, distinct impacts, and sustained pushing, and become non-obstacles when uprooted at level 5.

Current evidence: `scripts/world/lamp_field.gd` ignores contact below 1 m/s, requires 7 m/s for immediate bending, stores a continuous angle capped at 75 degrees, does not count impacts, and never disables collision.

## Goal

Replace the continuous threshold-only lamp response with a deterministic five-level damage/state model while preserving the compact MultiMesh and indexed PhysicsServer representation.

## Ownership boundary

- `scripts/world/lamp_field.gd`
- `scripts/vehicle/arcade_vehicle.gd` only if contact data must be corrected to expose meaningful force while stationary
- Directly scoped assertions in `tests/test_vehicle_physics.gd`
- This ticket file

Do not edit NPC, population, city layout, building generation, scene, resource, export, or unrelated test files.

## Exact implementation scope and constraints

- Levels and target poses are fixed: level 1 at 0 degrees, level 2 at 18 degrees, level 3 at 38 degrees, level 4 at 62 degrees, and level 5 at 88 degrees.
- Store persistent per-lamp damage points, level, distinct-hit count, sustained-push progress, contact state/gap, bend axis, and direction using bounded packed arrays or equivalent compact storage.
- Damage floors are 0, 2, 4, 6, and 8 points for levels 1 through 5.
- A new distinct qualifying impact increments hit count and adds speed-based damage: 1 point at 1.5 to under 4 m/s, 2 points at 4 to under 8 m/s, and 4 points at 8 m/s or above. Below 1.5 m/s contributes no impact damage. A contact must end before another impact on the same lamp counts; repeated physics contacts from one collision must not inflate hit count.
- Sustained pushing qualifies when contact continues and either vehicle speed is at least 0.5 m/s or horizontal force proxy is at least 2500 N. Convert the provided impulse proxy to force with a delta floor of 1/120 s when appropriate to the existing contact contract.
- Every complete 0.75 seconds of qualifying continuous push adds 2 damage points. Zero-speed contact with sufficient force must therefore progress an untouched lamp to level 5 in at most 3.0 seconds. Resting contact without speed or meaningful force must not progress it.
- Damage and level never regress. A contact gap resets only current push accumulation and permits a later distinct hit.
- Visual post, glow, and collision transforms update to the exact pose for the current level and bend away from the vehicle/contact direction.
- At level 5, disable the existing indexed PhysicsServer shape rather than removing it, preserving stable shape/lamp mapping and shape count. Further contacts on that lamp are harmless no-ops.
- Preserve invalid-contact tolerance, bounded allocations, vehicle NPC impact behavior, speed cap, and propulsion behavior.

## Non-goals

- No debris, scoring, audio, particles, repair, rigid-body joint simulation, lamp placement changes, or visual asset replacement.

## Acceptance criteria

- Every lamp starts at level 1, 0 damage, 0 hits, upright and colliding.
- Exact speed bands and repeated distinct hits produce the specified point totals and levels.
- Qualifying stationary-force pushing advances one level per 0.75 seconds and reaches level 5 within 3 seconds; non-qualifying resting contact does not advance.
- Levels map to the five exact angles, persist after contact gaps, and never skip collision-index ownership.
- Level 5 is visually uprooted at 88 degrees, exposes level 5 through a query, and its shape is disabled/non-obstructing while total shape count remains unchanged.
- Existing compact lamp count/mapping and vehicle impact regressions remain green.

## Required tests and validation

- Extend deterministic vehicle-physics assertions for initial state, all speed bands, distinct-hit counting, contact-gap behavior, stationary-force progression, resting no-op, exact five poses, persistence, level-5 disabled collision, stable count/mapping, and post-uproot no-op.
- Run the narrow vehicle physics test through the repository test runner or official suite.
- Run a bounded headless `Main.tscn` smoke.
- Run `git diff --check`.

## Dependencies and handoff

- Implement before WORLD-04 because both validate district lamp/building integration indirectly.
- Luna must report changed files, exact validation commands/results, known limitations, and deferred decisions.
- The decision owner must inspect the implementation, record validation here, rename this file with `_complete`, and close it in one dedicated atomic commit containing no unrelated changes.

## Final acceptance

- The decision owner inspected `lamp_field.gd` and the scoped vehicle-physics assertions. The implementation remains inside the ownership boundary and preserves stable MultiMesh/PhysicsServer index mapping.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`: completed in 28.9 seconds. Every WORLD-03 assertion passed, including exact levels, speed bands, distinct-hit behavior, stationary-force progression, persistence, and disabled level-5 collision. Exit 1 is limited to the eight pre-existing locomotion-cache assertions outside this ticket.
- `docker compose run --rm godot-tools --headless --path /workspace --scene res://scenes/Main.tscn --quit-after 300`: exit 0 in 18.5 seconds.
- `git diff --check`: exit 0 with line-ending warnings only.
- All acceptance criteria are satisfied. Broader gameplay feel tuning across additional speeds and physics rates is deferred under the beta MVP policy.
