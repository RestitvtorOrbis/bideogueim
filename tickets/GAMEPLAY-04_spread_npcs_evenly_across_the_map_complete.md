# GAMEPLAY-04 - Spread NPCs evenly across the map

Status: Complete

## Requested outcome and evidence

NPCs must be more evenly distributed across the playable map instead of clustering in a small number of areas.

Current evidence: `CityLayout._make_spawns()` selects road centers randomly and does not guarantee map-cell coverage. `population_manager.gd` accepts early valid candidates from a player-centered annulus and allows a fallback without separation; defaults use only 2.5 m minimum separation.

## Goal

Make generated role markers and active runtime NPC placement measurably more even while preserving role counts, pooling, distance safety, and deterministic city generation.

## Ownership boundary

- `scripts/world/city_layout.gd`
- `scripts/npc/population_manager.gd`
- `scripts/resources/crowd_settings.gd`
- `resources/default_crowd_settings.tres`
- Directly scoped assertions in `tests/test_city_generation.gd` and `tests/test_population.gd`
- This ticket file

Do not edit lamp behavior, vehicle behavior, district rendering/collision, NPC AI/combat, scenes, export, or unrelated tests.

## Exact implementation scope and constraints

- Generate civilian and hostile marker positions using deterministic 4-by-4 map stratification. For each role, all 16 cells must be represented when marker count is at least 16 and per-cell counts may differ by at most one.
- Markers must remain on valid road locations, within the playable extent, and outside expanded building footprints. Use role/seed-derived deterministic ordering that does not perturb interior building generation.
- Raise the default minimum NPC separation from 2.5 m to 4.5 m and default candidate attempts from 8 to 24; keep those values resource-configurable.
- During spawn selection, evaluate the bounded candidate set instead of returning the first acceptable candidate. Classify candidates into 16 player-relative buckets: eight angular sectors by two radial bands within the active spawn radius.
- Select lexicographically by lowest active occupancy in the candidate bucket, then greatest horizontal distance to the nearest active NPC, then the existing visibility preference. Keep deterministic tie behavior for deterministic inputs.
- Never accept a fallback that violates configured minimum separation. If no candidate passes all hard validity/range/distance/separation constraints, defer spawning to a later frame.
- Preserve initial role ratios, target counts, hostile safety/grace distances, death-replacement role preservation, pooling, despawn/recycling, visibility preference as a soft tie-breaker, and update tiers.

## Non-goals

- No NPC AI rewrite, navigation rewrite, cap increase, role rebalance, building/road changes, runtime depenetration, or persistence of all 250 NPCs across the full city simultaneously.

## Acceptance criteria

- Default generated civilian and hostile markers each cover all 16 map cells with count imbalance no greater than one, remain on roads, remain in bounds, and pass the building-footprint validity predicate.
- Default settings expose 4.5 m separation and 24 attempts.
- Candidate choice favors an unoccupied/less-occupied sector-band and then the more isolated candidate while preserving hard constraints.
- No ordinary, initial, or strict replacement spawn violates minimum separation; failure defers cleanly without pool checkout.
- The default initial population reaches 40 NPCs under the normal setup and occupies at least 12 of 16 sector-band buckets, with no bucket holding more than five NPCs.
- Existing role, safe-distance, building-validity, pooling, and budget contracts remain green.

## Required tests and validation

- Add deterministic city assertions for 4-by-4 per-role coverage, balance, road alignment, bounds, and building validity.
- Add population assertions for settings, occupancy-first selection, nearest-NPC tie-breaking, no invalid fallback, 4.5 m pair separation, initial count 40, and default bucket spread.
- Run the narrow city-generation and population tests through repository workflows or the official suite.
- Run a bounded headless `Main.tscn` smoke.
- Run `git diff --check`.

## Dependencies and handoff

- Implement after WORLD-03 and before WORLD-04; validation ownership overlaps `tests/test_city_generation.gd` with WORLD-04.
- Luna must report changed files, exact validation commands/results, known limitations, and deferred decisions.
- The decision owner must inspect the implementation, record validation here, rename this file with `_complete`, and close it in one dedicated atomic commit containing no unrelated changes.

## Final acceptance

- The decision owner inspected the independent marker RNG/4-by-4 stratification, hard-separation candidate filtering, and occupancy/isolation/visibility ordering. Changes remain within the ticket ownership boundary and preserve role, safety, pooling, and budget behavior.
- `docker compose run --rm godot-tools --headless --path /workspace --script res://tests/test_city_generation.gd`: exit 0 in 13.6 seconds; all 47 city assertions passed, including per-role 4-by-4 coverage, balance, road alignment, bounds, footprint validity, and deterministic generation.
- `docker compose run --rm godot-tools --headless --path /workspace --script res://tests/test_population_runner.gd`: exit 0 in 13.1 seconds; all 59 population assertions passed, including 40 initial NPCs, at least 12 occupied buckets, maximum five per bucket, 4.5 m pair separation, scoring order, and no invalid fallback.
- `docker compose run --rm godot-tools --headless --path /workspace --scene res://scenes/Main.tscn --quit-after 300`: exit 0 in 18.4 seconds.
- `git diff --check`: exit 0 with line-ending warnings only.
- All acceptance criteria are satisfied. Broader performance and multi-seed regression sweeps are deferred under the beta MVP policy.
