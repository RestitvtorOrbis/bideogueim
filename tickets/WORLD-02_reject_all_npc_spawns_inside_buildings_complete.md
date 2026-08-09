# WORLD-02 - Reject all NPC spawns inside buildings

Status: Complete

## Requested outcome and evidence

NPCs must never appear inside generated buildings.

Current evidence: building position, width, depth, and quarter-turn rotation live in `CityLayout.generate()` and are consumed by `district.gd`. Base role markers are placed on road center lines, but `population_manager.gd` jitters markers by up to 4 m and can generate ring-clamped candidates unrelated to a marker, with no building-footprint rejection.

## Goal

Make the district the authoritative source for rotated building footprints and require every initial, replenishment, and death-replacement candidate to pass a building-clearance test before pool checkout.

## Ownership boundary

- `scripts/world/city_layout.gd`
- `scripts/world/district.gd`
- `scripts/npc/population_manager.gd`
- Directly scoped assertions in `tests/test_city_generation.gd` and `tests/test_population.gd`

Do not edit NPC behavior, vehicle, lamp-field implementation, neon rendering, resources, scenes, ticket, export, or unrelated test files.

## Exact implementation scope and constraints

- Add a deterministic pure footprint predicate that handles each building's center, width, depth, and Y rotation. A point is invalid when its horizontal projection lies inside the rotated footprint expanded by 0.5 m NPC clearance.
- Expose a district query such as `is_npc_spawn_position_valid(world_position, clearance := 0.5)` that uses the generated layout and returns false inside an expanded building footprint.
- Population candidate selection must call the district query after all jitter/ring clamping and before visibility/separation fallback is recorded. Invalid candidates must be skipped, including ordinary fallback candidates and strict off-screen death replacements.
- If the district does not implement the query (test doubles/legacy fixtures), population behavior remains compatible and treats the position as valid.
- Base civilian/hostile markers must also satisfy the predicate for the default deterministic district.
- Preserve spawn budgets, role ratios, camera preference, distance limits, retry behavior, pooling, and deterministic city signature unless footprint data itself is intentionally added to the signature.

## Non-goals

- No navigation rewrite, sidewalk/park/prop avoidance, runtime depenetration of already-active NPCs, building geometry changes, population count changes, or spawn-point relocation beyond rejecting and retrying invalid candidates.

## Acceptance criteria

- All default district role markers lie outside expanded building footprints.
- Forced candidates at the center and rotated interior of representative buildings are rejected.
- Candidates just beyond the expanded footprint are accepted.
- Initial spawning, ordinary replenishment, and strict death replacement never check out an NPC at a district-invalid position and retry/fail cleanly when all attempted candidates are invalid.
- Existing population distance, off-screen, separation, role-preserving replacement, allocation, city determinism, and performance contracts remain green.

## Required tests and validation

- Add pure deterministic tests for unrotated and 90-degree rotated footprints, clearance boundary behavior, and every generated role marker.
- Add population tests using a district validity probe to prove invalid candidate rejection in ordinary and strict replacement paths and legacy-fixture compatibility.
- Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`.
- Run a headless import and bounded `Main.tscn` smoke through the repository workflow.
- Run `git diff --check`.

## Dependencies and handoff

- WORLD-01 remains open after its deterministic two-district city test timed out repeatedly. Under the beta policy's instruction to continue active user work after documenting an unresolved bug, WORLD-02 implementation may proceed sequentially on the current workspace because WORLD-01 editing has stopped.
- WORLD-02 must not change or diagnose lamp-field behavior. Its population and pure-footprint tests may be validated independently, but the ticket must remain open if the required city-generation validation is still blocked by WORLD-01.
- Luna must report changed files, exact validation commands/results, known limitations, and any deferred decision. Sol owns final acceptance, ticket completion, and the dedicated atomic commit.

## Open validation evidence

- Status remains Open. Luna xhigh implementation round `019fe579-2d38-7ad1-a58b-9d143ed2ea62` completed the bounded footprint and candidate-rejection implementation; Sol inspected the owned diff and confirmed validation occurs after jitter/ring clamping and before any fallback is recorded.
- `docker compose run --rm godot-tools --headless --path /workspace --script res://tests/test_population_runner.gd`: exit 0; 51/51 population assertions pass, including ordinary and strict replacement rejection of district-invalid candidates.
- The VISUAL-01 `--neon-only` seam also executes the pure unrotated/rotated footprint and clearance-boundary assertions; all six pass.
- Headless import and bounded Main smoke exit 0. `git diff --check` exits 0 with line-ending warnings only.
- The required full `tests/test_city_generation.gd` path remains blocked by WORLD-01's documented timeout before city assertions are emitted. Therefore generated-marker validation cannot be accepted through the required shared test, this ticket cannot be renamed complete, and its implementation remains uncommitted.

## Sol final acceptance

- After the WORLD-01 harness correction, Sol reran the full two-district city test: exit 0 in 12.9 seconds. All pure footprint boundary checks and all generated civilian/hostile marker validity assertions passed.
- The official suite completed in 25.7 seconds; every WORLD-02 population candidate and strict replacement assertion passed. Exit 1 remains limited to eight pre-existing locomotion-cache assertions outside this ticket.
- The bounded Main smoke exits 0 in 16.5 seconds with only the known two ObjectDB/one resource shutdown diagnostics. `git diff --check` exits 0 with line-ending warnings only.
- Sol inspected the footprint predicate, district query, and post-jitter/post-ring-clamp rejection path and confirms every WORLD-02 acceptance criterion is satisfied.
