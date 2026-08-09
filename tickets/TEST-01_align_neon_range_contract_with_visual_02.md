# TEST-01 - Align the neon range contract with VISUAL-02

## Problem

The dedicated city-generation test rejects the current validated building-neon range even though the runtime and completed VISUAL-02 ticket intentionally use that value.

## Evidence

- `scripts/world/district.gd` defines `NEON_LIGHT_RANGE := 28.0` and `NEON_LIGHT_ENERGY := 9.0`.
- `tickets/VISUAL-02_ground_textured_npcs_and_rebalance_night_lighting_complete.md` records and accepts exactly eight non-shadowing neon lights at range `28.0 m` and energy `9.0`.
- `tests/test_city_generation.gd` still marks any neon range above `24.0 m` invalid.
- On 2026-08-09, `docker compose run --rm --build godot-tools --headless --path /workspace --script res://tests/test_city_generation.gd` passed every city assertion except `neon signs have matching bounded OmniLights` for this stale upper bound.

## Goal

Make the dedicated city-generation neon assertion match the already accepted VISUAL-02 runtime contract.

## Ownership boundary

- `tests/test_city_generation.gd`
- this ticket file

## Non-goals

- Do not change runtime neon count, placement, colors, energy, range, shadows, signs, street lights, or sky lighting.
- Do not redesign or broaden city-generation tests.

## Acceptance criteria

- The neon contract accepts exactly eight matching non-shadowing `OmniLight3D` fixtures at energy `9.0` and range `28.0 m`.
- Existing deterministic placement, color matching, exterior positioning, sign geometry, and compact-node assertions remain unchanged and pass.
- The dedicated city-generation script exits with code 0.

## Required validation

- `docker compose run --rm --build godot-tools --headless --path /workspace --script res://tests/test_city_generation.gd`

## Dependencies

- Depends on the completed VISUAL-02 runtime contract. Independent of VISUAL-03 implementation.
