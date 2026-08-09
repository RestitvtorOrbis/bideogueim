# BUG-02 - Prevent vehicle ground tunneling

## Problem and evidence

The user frequently drives through the district floor and then falls indefinitely.

- `resources/default_vehicle_config.tres` permits a maximum vehicle speed of `56.0` m/s.
- The generated district ground collision in `scripts/world/district.gd` is a `0.6` m-thick static box.
- `scenes/ArcadeVehicle.tscn` configures the car as a `RigidBody3D` without continuous collision detection.
- At the default 60 physics ticks per second, maximum-speed displacement is approximately `0.933` m per step, greater than the entire ground thickness. Discrete collision sampling can therefore move the car from above to below the floor without registering contact.

## Goal

Prevent the arcade vehicle from tunneling through the static district floor at supported gameplay speeds by enabling the engine's continuous collision detection contract on the vehicle body.

## Ownership boundary

- `scenes/ArcadeVehicle.tscn`
- `tests/test_vehicle_physics.gd`
- this ticket file is owned by Sol; Luna must not edit it

## Implementation scope

- Enable continuous collision detection on the root `RigidBody3D` in `scenes/ArcadeVehicle.tscn` using the Godot 4 property supported by the project.
- Add a focused regression contract to `tests/test_vehicle_physics.gd` that instantiates the scene and proves CCD is enabled on the shipped vehicle.
- Before editing, run or otherwise capture a deterministic pre-fix failure of the new contract (a temporary diagnostic is acceptable and must not remain in the final diff).
- Preserve the existing collision layer `4`, collision mask `11`, body shape, ground geometry, suspension, speed, mass, controls, damage, and manual reset behavior.

## Non-goals

- Do not thicken or reshape the world floor, reduce vehicle speed, alter physics tick rate, add teleport recovery, redesign suspension, or modify any NPC behavior.
- Do not change city generation, road/building collisions, camera behavior, input mappings, or unrelated tests.
- Do not touch user-owned untracked archives or `sourcesforblood.md`.

## Acceptance criteria

- The shipped `ArcadeVehicle` root has continuous collision detection enabled.
- Vehicle collision layer/mask remain exactly `4`/`11` and its existing collision shape remains enabled.
- A focused deterministic vehicle-physics assertion fails before the change and passes after it.
- No tracked files outside the ownership boundary are changed for this ticket.

## Required minimum validation

- Run the dedicated vehicle physics runner through the existing pinned Godot container, or the narrowest existing runner that executes `tests/test_vehicle_physics.gd`.
- Run `git diff --check` and inspect the ticket ownership boundary.
- Do not run broader regression or gameplay suites; record those as future beta work if needed.

## Dependencies and handoff

- This is the single coordinated investigation/correction round for this bug under the beta policy.
- Luna must report the pre-fix reproduction, changed files, exact validation commands/results, limitations, and deferred decisions.
- Sol alone records acceptance evidence, renames this ticket with `_complete`, creates its dedicated atomic commit, and performs the mandatory Windows export/package workflow.

## Sol validation and acceptance

Accepted on 2026-08-09 in the single coordinated Luna xhigh round `019fe7c7-b1d0-7681-84a3-7b3123a13ef7`.

- The pre-fix CCD contract failed deterministically before the scene change (`exit 1`).
- Sol inspected the final diff and confirmed `continuous_cd = 2` (`CCD_MODE_CAST_SHAPE`) on the shipped root `RigidBody3D`; collision layer `4`, collision mask `11`, and the existing enabled body shape are preserved.
- The new assertion instantiates `res://scenes/ArcadeVehicle.tscn` and verifies that continuous collision detection is active.
- `docker compose run --rm godot-tools --headless --path /workspace --scene res://tests/_sol_vehicle_physics_runner.tscn` exited `0`; all 35 focused vehicle/lamp physics assertions passed. The temporary Sol runner used for this isolated execution was removed afterward.
- The first Sol runner attempt exited `1` because `_ready()` invoked the suite while the scene root was still adding children. Deferring the temporary runner by one call fixed the harness; this was not a product failure and the accepted rerun passed.
- `git diff --check` exited `0` with only normal LF/CRLF conversion warnings.
- Final implementation ownership is limited to `scenes/ArcadeVehicle.tscn` and `tests/test_vehicle_physics.gd`; user-owned untracked files remain untouched.

All acceptance criteria and required minimum validation passed. BUG-02 is accepted for its dedicated atomic commit.
