# WORLD-04 - Build an uncrossable varied-building perimeter

Status: Complete

## Requested outcome and evidence

The car must not cross the playable-area limits. Buildings with visibly different appearances must surround the map and form the boundary.

Current evidence: the generated ground and road surfaces end at `city_size`, but no continuous perimeter collider prevents a physics vehicle from leaving. Existing interior buildings already use four facade styles, roofs, windows, MultiMeshes, and batched collision.

## Goal

Add a deterministic, gapless visual ring of varied buildings immediately outside the playable extent and a compact continuous physical barrier aligned to the same boundary.

## Ownership boundary

- `scripts/world/city_layout.gd` only for a pure deterministic perimeter-module generator if needed
- `scripts/world/district.gd`
- `scripts/world/city_meshes.gd` only to reuse or expose existing mesh/material helpers
- Directly scoped assertions in `tests/test_city_generation.gd`
- This ticket file

Do not edit lamps, vehicle controller, NPC/population behavior or settings, interior building generation, scenes, export, or unrelated tests.

## Exact implementation scope and constraints

- Generate building modules around all four sides immediately outside `get_city_bounds()`. Inner facades align with the playable boundary at plus/minus half city extent.
- Module facade widths range from 14 to 22 m, depths from 10 to 16 m, and heights from 24 to 48 m. Adjacent facade intervals overlap by about 0.25 m, including corners, so no visible drive-through gap exists.
- Default generation must use at least three of the existing facade styles and at least four distinct height bands. Facades/windows face inward where orientation matters.
- Use a dedicated seed-derived deterministic RNG stream so perimeter generation does not alter existing interior layout, spawn, or signature behavior unless perimeter data is deliberately added to the signature.
- Render perimeter bodies, roofs, and windows with compact MultiMeshes reusing existing city materials and mesh helpers. Do not create one scene node per building.
- Add one `StaticBody3D` boundary owner with exactly four `BoxShape3D` collision children or an equivalently inspectable four-shape PhysicsServer body. Inner wall planes align exactly with the playable bounds; thickness is 8 m; vertical span is approximately y=-1 to y=24; side lengths overlap at corners by at least 8 m.
- Collision layer/mask match existing static buildings and must physically block the vehicle from either direction. Keep the barrier visually covered by perimeter buildings.
- Expose small deterministic queries/metadata for module count, style count, height-band count, and boundary-shape count as needed by tests.

## Non-goals

- No city-size increase, invisible teleport/reset boundary, vehicle controller clamp, destructible perimeter, new external art assets, interior building redesign, or per-building rigid bodies.

## Acceptance criteria

- All four sides have continuous deterministic facade coverage with no interval gap and visibly varied style/height/depth.
- Perimeter rendering uses batched MultiMeshes and adds only a compact constant number of scene nodes.
- Exactly four continuous collision walls align to the playable bounds, overlap at corners, and cover sufficient height to prevent vehicle crossing or jumping through under normal gameplay.
- A deterministic physics probe cannot move a vehicle-shaped body from inside to outside through any side.
- Existing interior building count/layout/signature, roads, lamps, spawns, navigation, and compact node-count contracts remain green.

## Required tests and validation

- Add deterministic city assertions for repeatability, four-side interval coverage, no gaps, style count, height bands, dimension ranges, inward placement, batched rendering, four wall shapes, exact inner planes, corner overlap, and compact node count.
- Add a minimal physics containment probe for all four sides using a vehicle-sized body or shape query.
- Run the narrow city-generation test through the repository workflow or official suite.
- Run a bounded headless `Main.tscn` smoke.
- Run `git diff --check`.

## Dependencies and handoff

- Implement after GAMEPLAY-04 because both own `city_layout.gd` and `tests/test_city_generation.gd`.
- Luna must report changed files, exact validation commands/results, known limitations, and deferred decisions.
- The decision owner must inspect the implementation, record validation here, rename this file with `_complete`, and close it in one dedicated atomic commit containing no unrelated changes.

## Final acceptance

- The decision owner inspected the independent perimeter generator, batched rendering, inward facade placement, and four-wall static boundary. Changes remain inside the ownership boundary and preserve interior generation, lamps, population, and compact scene construction.
- `docker compose run --rm godot-tools --headless --path /workspace --script res://tests/test_city_generation.gd`: exit 0 in 12.3 seconds; all 60 city assertions passed, including deterministic modules, four-side gapless coverage, style/height variation, dimension ranges, batched visuals, exact wall planes, corner overlap, four physics probes, and compact node count.
- `docker compose run --rm godot-tools --headless --path /workspace --scene res://scenes/Main.tscn --quit-after 300`: exit 0 in 18.0 seconds. The existing two ObjectDB/one resource shutdown diagnostics remain.
- `git diff --check`: exit 0 with line-ending warnings only.
- All acceptance criteria are satisfied. Broader high-speed perimeter driving and additional-seed visual regression sweeps are deferred under the beta MVP policy.
