# VISUAL-01 - Add bright deterministic building neons

Status: Complete

## Requested outcome and evidence

Some buildings need bright neon fixtures that cast substantial colored light onto nearby parts of the map.

Current evidence: buildings and windows are batched MultiMeshes in `district.gd`; `District.tscn` already enables Forward+ glow. Window material emission alone does not cast local light. The city contains at least 100 buildings, so adding a light to every building would be an avoidable performance risk.

## Goal

Select a bounded deterministic subset of generated buildings, attach visible emissive neon signs to exterior facades, and pair them with strong colored OmniLight3D illumination while preserving city determinism and performance.

## Ownership boundary

- `scripts/world/district.gd`
- `scripts/world/city_meshes.gd`
- Directly scoped assertions in `tests/test_city_generation.gd`

Do not edit city layout/spawn data, population, NPC, vehicle, lamp field, scenes, environment settings, ticket, export, or unrelated test files.

## Exact implementation scope and constraints

- Deterministically select exactly 8 eligible buildings for the default city seed, spread across the map rather than clustered in one block. Selection must derive from stable layout data/city seed and produce the same result for equal seeds.
- Create emissive cyan/magenta/purple sign geometry on an exterior facade, offset beyond the building surface to avoid z-fighting. Batch sign meshes by color where practical.
- Add exactly one OmniLight3D per selected sign, with shadow disabled, range between 16 and 24 m, energy at least 5.0, and a color matching its sign. Place lights outside the facade so roads/sidewalks receive visible illumination.
- Keep light count strictly bounded at 8 and expose a deterministic count or named root for tests. The district must remain under the existing 180-node compactness limit.
- Preserve existing windows, building collision, lamp visuals/collision, navigation, spawn validity, glow environment, city signature, and equal-seed generation behavior.

## Non-goals

- No animated text, logos, imported fonts/assets, flicker, shadows, environment retuning, new shaders, building redesign, extra street lights, or per-window lights.

## Acceptance criteria

- The default district contains exactly 8 spatially distributed neon fixtures under a clearly named root.
- Each fixture has visible emissive geometry and a matching OmniLight3D with required energy/range and shadows disabled.
- Equal seeds produce identical neon positions/colors; different layout seeds may differ.
- Signs are outside building surfaces, local lights face/occupy exterior space, and no fixture is placed inside a building volume.
- Existing building count/collision, lamp field, spawn validity, navigation, MultiMesh, deterministic signature, compact node count, and test suite remain green.

## Required tests and validation

- Add deterministic assertions for count, equal-seed transforms/colors, spatial distribution, emissive material, light type/energy/range/shadow state, facade offset, and node-count limit.
- Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`.
- Run a headless import and bounded `Main.tscn` smoke through the repository workflow.
- Run `git diff --check`.

## Dependencies and handoff

- WORLD-01 remains open after its deterministic two-district city test timed out repeatedly; WORLD-02 implementation is present and its focused population/footprint validation passes. Under the beta policy's instruction to continue active user work after documenting an unresolved bug, VISUAL-01 implementation may proceed sequentially because editing for both prior tickets has stopped.
- VISUAL-01 must not change or diagnose lamp-field, spawn-footprint, or population behavior. It may validate deterministic neon construction independently, but must remain open if the required shared city-generation test is still blocked by WORLD-01.
- Luna must report changed files, exact validation commands/results, known limitations, and any deferred decision. Sol owns final acceptance, ticket completion, and the dedicated atomic commit.

## Open validation evidence

- Status remains Open. Luna xhigh implementation round `019fe581-77e3-78c2-99c9-7d4dc5e5f284` completed the bounded neon implementation; Sol inspected deterministic 4x2-bin selection, exterior facade placement, three emissive sign MultiMeshes, and exactly eight non-shadowed OmniLight3D nodes at energy 7/range 20.
- `docker compose run --rm godot-tools --headless --path /workspace --script res://tests/test_city_generation.gd -- --neon-only`: exit 0; all 14 footprint/neon assertions pass, including equal-seed determinism, map distribution, exterior placement, matching color/light properties, and compact neon node count.
- The seam emits the known projectless `GameState` compile diagnostic and two lamp-shape RID shutdown diagnostics, but every scoped assertion passes. Full project import and bounded Main smoke both exit 0.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`: all scoped runtime behavior passes; exit 1 is limited to the eight pre-existing locomotion-cache failures.
- `git diff --check`: exit 0 with line-ending warnings only.
- The required full `tests/test_city_generation.gd` path remains blocked by WORLD-01's documented timeout. This ticket cannot be renamed complete and its implementation remains uncommitted until the shared validation gate is available.

## Sol final acceptance

- After the WORLD-01 harness correction, Sol reran the full two-district city test: exit 0 in 12.9 seconds. Exactly eight deterministic fixtures, 4x2 map distribution, exterior placement, emissive signs, matching bounded non-shadowed lights, and compact node limits all passed.
- The official suite completed in 25.7 seconds; exit 1 remains limited to eight pre-existing locomotion-cache assertions outside this ticket. No VISUAL-01 regression was reported.
- The bounded Main smoke exits 0 in 16.5 seconds with only the known two ObjectDB/one resource shutdown diagnostics. `git diff --check` exits 0 with line-ending warnings only.
- Sol inspected the deterministic selection, three-color MultiMesh batching, fixture metadata, and light bounds and confirms every VISUAL-01 acceptance criterion is satisfied.
