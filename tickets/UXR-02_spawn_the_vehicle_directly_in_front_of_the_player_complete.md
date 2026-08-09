# UXR-02 - Spawn the vehicle directly in front of the player

Status: Complete

**Goal**

Place the vehicle exactly 3.25 meters in front of the initial player position so the player can enter it immediately with E.

**Ownership boundary**

- `scripts/world/city_layout.gd`
- `tests/test_city_generation.gd`

**Non-goals**

- Do not change vehicle physics, visuals, controls, or the four-meter interaction radius.

**Acceptance criteria**

- `vehicle_spawn` equals `player_spawn + Vector3.FORWARD * 3.25`.
- With default city settings the exact vehicle position is `Vector3(0.0, 1.25, -3.25)` and its rotation remains zero.
- The player and vehicle collision shapes do not overlap initially.
- Pressing E on the first playable frame successfully enters the vehicle.

**Required tests**

- Verify deterministic layout generation and the exact relative spawn vector.
- Instantiate Player and ArcadeVehicle at their initial positions and verify `try_enter()` succeeds without moving the player.

**Dependencies**

- None.

**Validation evidence**

- Decision-owner review confirmed that the implementation stayed within the two-file ownership boundary and uses the exact `player_spawn + Vector3.FORWARD * 3.25` contract.
- `docker compose run --rm test` passed 96/96 tests, including exact spawn, determinism, non-overlap, and first-frame vehicle entry assertions.
- `git diff --check -- scripts/world/city_layout.gd tests/test_city_generation.gd` passed.
