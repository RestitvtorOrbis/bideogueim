# WORLD-01 - Add compact bendable street lamps

Status: Complete

## Requested outcome and evidence

The vehicle can become trapped in crowded roadside situations. Street lamps should yield when hit at sufficient speed or when the vehicle keeps pushing them, allowing escape instead of acting as permanent upright blockers.

Current evidence: `scripts/world/district.gd` renders every lamp through `MultiMeshInstance3D` and creates no lamp collision body. `scripts/vehicle/arcade_vehicle.gd` reports `body_entered` impacts and can call `receive_vehicle_impact`, but has no continuous contact reporting. Creating hundreds of lamp scene nodes would violate the compact scene-tree and 250-NPC performance contracts.

## Goal

Give all generated street lamps compact collision and persistent visual/physical bending, with both high-speed impact and sustained-push activation, without replacing the MultiMesh representation with hundreds of scene nodes.

## Ownership boundary

- `scripts/world/district.gd`
- `scripts/world/city_meshes.gd` only if required to expose/reuse lamp mesh data
- `scripts/vehicle/arcade_vehicle.gd`
- New lamp-field runtime scripts under `scripts/world/`
- Directly scoped assertions in `tests/test_vehicle_physics.gd` and `tests/test_city_generation.gd`

Do not edit NPC, population, building layout, spawn, neon, scene, resource, ticket, export, or unrelated test files.

## Exact implementation scope and constraints

- Retain one compact lamp MultiMesh for rendered posts and one for glows. Do not instantiate one multi-node lamp scene per generated lamp.
- Add one compact static collision owner for the lamp field, using PhysicsServer-backed shapes or an equivalently compact representation that keeps the district scene-tree under the existing 180-node limit.
- Keep a stable index mapping between generated lamp transforms, collision shapes, and MultiMesh instances.
- Add vehicle continuous-contact forwarding from `_integrate_forces` (or the equivalent direct-body-state hook), including collider shape index, vehicle speed, impulse/force proxy, and delta. Preserve existing `body_entered` NPC impact behavior.
- A lamp bends immediately when contacted at 7 m/s or faster. Repeated contact at at least 1 m/s accumulates push time and begins bending no later than 1.5 continuous seconds. Contact gaps reset only the sustained-push timer, not already accumulated bend.
- Bend away from the vehicle/contact direction, progress smoothly, clamp at 75 degrees, and update both the visible MultiMesh transform and the physical collision transform. At maximum bend, the remaining collision must no longer form a full-height upright trap.
- Bent state persists for the life of the district. No automatic lamp repair is required.
- The implementation must tolerate invalid/non-vehicle contacts and repeated contacts without errors or unbounded allocations.

## Non-goals

- No breakable debris, score, damage, sound, particles, lamp repair, rigid-body chain simulation, vehicle reset redesign, NPC collision redesign, or third-party assets.
- Do not change road/building geometry or lamp placement.

## Acceptance criteria

- Every generated lamp has a matching compact collision shape and stable instance mapping.
- A deterministic 7+ m/s vehicle contact starts bending immediately.
- A deterministic sustained 1+ m/s contact starts bending within 1.5 seconds even when below the impact threshold.
- Visual and physical transforms agree, bending is directional and capped at 75 degrees, and the final collider clears the former upright obstruction.
- Existing vehicle propulsion, braking, speed cap, NPC impact, district MultiMesh, and compact scene-tree contracts remain intact.

## Required tests and validation

- Add deterministic coverage for lamp/shape counts and mapping, immediate impact threshold, sustained-push threshold, timer reset behavior, directional/capped bend, matching render/collision transforms, and compact node count.
- Add/retain vehicle regression coverage for `body_entered` NPC impacts and continuous static-contact forwarding.
- Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`.
- Run a headless import and bounded `Main.tscn` smoke through the repository workflow.
- Run `git diff --check`.

## Dependencies and handoff

- May run in parallel with GAMEPLAY-03 because ownership is disjoint.
- WORLD-02 and VISUAL-01 depend on this ticket because they also own `district.gd`.
- Luna must report changed files, exact validation commands/results, known limitations, and any deferred decision. Sol owns final acceptance, ticket completion, and the dedicated atomic commit.

## Open validation failure evidence

- Status remains Open. The implementation is not accepted and must not be committed as complete.
- The official suite completed in 26 seconds. Every WORLD-01 assertion in `tests/test_vehicle_physics.gd` passed; the suite's only failures were the existing eight locomotion-cache assertions outside this ticket.
- `docker compose run --rm godot-tools --headless --path /workspace --script res://tests/test_city_generation.gd` timed out with no assertion output after 120 seconds.
- The same command was repeated once with a 300-second limit and again timed out with no assertion output. This established a repeated validation failure rather than an assertion failure.
- Per `avisor-skill`, fresh GPT-5.6 Sol medium advisor `019fe573-1bd4-73e0-9727-262efe3dd931` identified per-shape broadphase synchronization as the likely cause and recommended configuring the lamp field before tree insertion.
- Sol applied only that bounded construction-order change and reran the city test with a 120-second bound. It timed out again, so the suggested root cause was not verified. The ineffective construction-order change was reverted.
- Impact: functional lamp tests, headless import, and Main smoke passed in the worker round, but the required deterministic two-district city test cannot complete within five minutes. WORLD-01 therefore fails its required validation gate and remains unresolved.
- Suspected scope: interaction among hundreds of PhysicsServer-backed lamp shapes, two simultaneously active district physics bodies, first physics-frame synchronization, or teardown. MultiMesh rendering and scene-node count are less likely because the official one-district paths complete and the node-count assertion was not reached in the blocked test.
- No further speculative implementation or repeated city-test attempt is authorized in this beta bug round. A future investigation must use profiling or progress instrumentation to locate construction, first-frame, assertion, or teardown cost before changing runtime behavior.

## Projectless city-test bug-fix round

- Confirmed root cause: the two-district generation path itself constructs both districts, reaches a physics frame, performs the overlap query, and tears down quickly. The projectless `--script` seam then loaded `scripts/vehicle/arcade_vehicle.gd` without its project autoload class binding, producing `Compile Error: Identifier not found: GameState` at the former direct reference on line 47. The packed Vehicle node consequently had no usable script, so the dynamic `try_enter` call aborted the coroutine before `SceneTree.quit()`, which presented as an indefinite hang.
- Advisor conclusion: the measured construction and teardown timings provide no evidence of a lamp RID leak. One shared shape RID is attached to all lamp slots, `StaticBody3D` owns its body RID, and `LampField` clears slots before freeing the shared shape RID. Successful teardown measurements disprove the leak hypothesis; lamp RID construction and cleanup remain unchanged.
- Exact correction: `scripts/vehicle/arcade_vehicle.gd` now resolves `/root/GameState` at runtime through `_is_game_over()` and `_finish_run()`. With the autoload present, the four former direct uses retain their game-over gating and finish-run behavior; without it, the vehicle loads and safely treats the run as active without attempting a null call. `tests/test_city_generation.gd` now checks the loaded vehicle script, instantiated script, and `try_enter` capability before the dynamic call; unavailable capability records a failed CITY assertion and uses the normal result printer plus nonzero quit path. `tests/_world01_probe.gd` and its temporary UID sidecar were removed.
- Worker validation: the literal `docker compose run --rm godot-tools --headless --path /workspace --script res://tests/test_city_generation.gd` completed within the external 60-second bound in 12.675 seconds with exit 0. All CITY assertions, including lamp counts/mapping, compactness, and first-frame vehicle entry, passed; no GameState compile error or RID shutdown diagnostic appeared. `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1` completed in 38.863 seconds with exit 1 because the existing eight locomotion-cache assertions failed; all WORLD-01 lamp and vehicle assertions passed.

## Sol final acceptance

- Sol inspected the owned implementation and confirmed the compact MultiMesh/PhysicsServer mapping, directional persistent bend behavior, continuous vehicle contact forwarding, safe projectless GameState lookup, and deterministic test failure path remain within WORLD-01.
- Sol reran `docker compose run --rm godot-tools --headless --path /workspace --script res://tests/test_city_generation.gd`: exit 0 in 12.9 seconds; all 37 CITY assertions passed, including lamp mapping, compact node count, and first-frame vehicle entry. No GameState compile error or lamp RID shutdown diagnostic appeared.
- Sol reran `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`: exit 1 in 25.7 seconds, limited to the eight pre-existing locomotion-cache assertions outside WORLD-01. Every WORLD-01 lamp and vehicle assertion passed.
- Sol ran `docker compose run --rm godot-tools --headless --path /workspace --scene res://scenes/Main.tscn --quit-after 300`: exit 0 in 16.5 seconds. The known two ObjectDB/one resource shutdown diagnostics remain and are not lamp-RID evidence.
- `git diff --check` exits 0 with line-ending warnings only. Every WORLD-01 acceptance criterion and required scoped validation is satisfied.
