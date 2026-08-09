# UXR-04A - Exercise vehicle camera transitions through the vehicle API

Status: Complete

**Goal**

Correct the camera transition regression fixture so entry and exit use the public ArcadeVehicle workflow that owns vehicle-camera activation.

**Ownership boundary**

- `_test_vehicle_camera_transition` in `tests/test_player_movement.gd` only.

**Non-goals**

- Do not modify Player, ArcadeVehicle, camera scripts, scenes, unrelated tests, `TICKETS.md`, or `AGENTS.md`.

**Acceptance criteria**

- The fixture enters with `vehicle.try_enter(player)` and exits with `vehicle.exit_vehicle()`.
- It still verifies VisualRoot state, active cameras, and preservation of close-camera hidden state.
- The complete Docker test suite passes.

**Required tests**

- Run the complete Docker test suite and report its assertion count.
- Run `git diff --check` for `tests/test_player_movement.gd`.

**Dependencies**

- UXR-04 implementation must be present.

**Validation evidence**

- Decision-owner review confirmed the fixture now enters through `vehicle.try_enter(player)` and exits through `vehicle.exit_vehicle()` without production changes.
- Six transition assertions cover VisualRoot, both cameras, and close-camera hidden-state preservation.
- `docker compose run --rm test` passed 194/194 assertions; `git diff --check -- tests/test_player_movement.gd` passed.
