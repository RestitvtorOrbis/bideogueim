# VISUAL-06 — Expand street lighting, neon ads, and NPC marker readability

## Requested outcome

Add more artificial light to the streets, add more neon fixtures that read as advertisements, and make NPC role markers brighter and easier to distinguish at night.

## Context and evidence

- The district is intentionally midnight-black with zero ambient and directional contribution; artificial sources must remain the only illumination.
- `scripts/world/district.gd` currently constructs exactly 48 deterministic amber street-lamp `OmniLight3D` nodes at energy `3.2` and range `30.0`, all without shadows and synchronized to bendable lamp glows.
- The same builder currently selects eight building neon fixtures over a 4×2 grid. Their signs are emissive colored boxes with matching non-shadowed lights, but they contain no advertising copy.
- Current neon lights intentionally use energy `9.0`, range `280.0`, attenuation `1.0`, and the cyan/magenta/purple palette established by GAMEPLAY-06; preserve those values.
- Every active civilian and hostile uses the shared `RoleMarkerAnchor/WarningMarker` `Label3D`. The marker currently uses font size `64`, outline `12`, default pixel size, and the profile color without an HDR brightness multiplier.
- The dedicated full city-generation script has unrelated stale assertions for pre-midnight environment lighting and a pre-expanded global node limit. Its `--neon-only` seam is the appropriate focused validation path and currently fails only because its neon range upper bound predates the accepted `280.0` runtime value.
- User-owned untracked ZIP archives and `sourcesforblood.md` must remain untouched.

## Goal

Increase bounded artificial street coverage, expand deterministic building neon coverage with readable advertising copy, and strengthen both civilian and hostile marker presentation while preserving gameplay, midnight environment decisions, and bounded no-shadow rendering.

## Ownership boundary

- `scripts/world/district.gd`
- `scenes/Npc.tscn`
- `scripts/npc/npc.gd`
- `tests/test_city_generation.gd`
- `tests/test_pooling.gd`
- This ticket file

## Exact implementation scope and decisions

### Street lighting

- Increase `STREET_LAMP_LIGHT_COUNT` from `48` to exactly `72`.
- Increase `STREET_LAMP_LIGHT_RANGE` from `30.0` to exactly `34.0` metres.
- Increase `STREET_LAMP_LIGHT_ENERGY` from `3.2` to exactly `3.8`.
- Preserve deterministic even selection from generated lamp transforms, amber `#ffb35c`, disabled shadows, compact named root/metadata, and bendable-lamp transform synchronization.

### Neon advertisements

- Increase `NEON_FIXTURE_COUNT` from `8` to exactly `12` and change deterministic spatial bins from `4×2` to `4×3` so the additional fixtures cover the map rather than clustering.
- Preserve neon light energy `9.0`, range `280.0`, attenuation `1.0`, disabled shadows, existing palette, exterior placement, deterministic ranking, and emissive backing panels.
- Add exactly one facade-aligned `Label3D` advertisement per selected fixture, positioned approximately `0.08 m` outward from its backing panel to avoid z-fighting while remaining occluded by buildings normally (`no_depth_test = false`).
- Use deterministic cycling through exactly these lightweight built-in-font advertising strings: `NOVA`, `ARCADE`, `24H`, `RAMEN`, `CLUB`, `BYTE`.
- Configure each ad with font size `72`, pixel size `0.009`, outline size `10`, double-sided rendering, black high-opacity outline, and its matching palette color multiplied to HDR intensity `2.0` with alpha restored to `1.0`.
- Name ads deterministically (`Ad00` through `Ad11`) and expose ordered ad copy through `BuildingNeons` metadata for focused tests.
- Do not import fonts, textures, logos, or other assets.

### NPC marker readability

- Increase the shared `WarningMarker` font size from `64` to exactly `88`, outline size from `12` to exactly `18`, and set pixel size to exactly `0.006`.
- Give it a black outline with alpha at least `0.95`; preserve billboard and no-depth-test behavior so markers remain camera-facing and visible against geometry.
- In `Npc._apply_profile_visuals()`, multiply the visible marker profile color's RGB channels by exactly `2.0` while preserving alpha. Apply this identically to civilian blue and hostile red profiles; do not alter the profile resources or role logic.
- Keep marker visibility driven solely by `warning_marker_enabled` and preserve hostile prop behavior.

### Focused contracts

- Update the existing `--neon-only` city seam to assert the new exact 12-fixture/4×3 deterministic neon contract, the 12 deterministic advertising labels/copy/style, and the exact 72-light street contract.
- Update the neon light assertion to the accepted runtime values: energy `9.0`, range `280.0`, attenuation `1.0`, and shadows disabled.
- Raise only the neon-root compactness ceiling to the exact structure required by one root, 12 lights, 12 ad labels, and three palette-batched sign nodes (maximum `28` nodes). Do not change the unrelated full-district `<180` stale assertion.
- Extend pooling contracts to verify both civilian and hostile markers remain enabled with their role-dominant color, HDR intensity, and exact shared scene sizing/outline properties.

## Non-goals

- Do not change sky, fog, ambient light, directional lights, glow/tonemapping, city geometry/layout, lamp placement or damage, NPC gameplay/AI/speed/population, profile colors, marker text/role semantics, models, animations, vehicle behavior, or combat.
- Do not add shadows, flicker, per-window lights, unbounded nodes, imported ad assets, or unique materials/resources per NPC.
- Do not repair or relax unrelated stale full city-generation assertions.
- Do not touch other tickets or user-owned untracked files.

## Acceptance criteria

- The default district constructs exactly 72 evenly selected amber street lights at energy `3.8`, range `34.0`, without shadows, and registered lights still follow bent lamp glows.
- The default district constructs exactly 12 deterministic, spatially distributed exterior neon fixtures with matching emissive panels, accepted long-range lights, and one readable deterministic ad label each.
- The neon root remains bounded at no more than 28 nodes and equal seeds produce identical fixture positions, colors, and ad copy.
- Civilian blue and hostile red exclamation markers are visibly larger, have a stronger outline, and use HDR brightness `2.0×` while preserving profile hue and role visibility behavior.
- Midnight environment and all gameplay contracts remain unchanged.
- Focused visual-city tests, official repository tests, and bounded startup smoke pass at the beta MVP level.

## Required validation

- `docker compose run --rm godot-tools --headless --path /workspace --script res://tests/test_city_generation.gd -- --neon-only`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`
- `docker compose run --rm godot-tools --headless --path /workspace --scene res://scenes/Main.tscn --quit-after 300`
- `git diff --check -- scripts/world/district.gd scenes/Npc.tscn scripts/npc/npc.gd tests/test_city_generation.gd tests/test_pooling.gd tickets/VISUAL-06_expand_street_lighting_neon_ads_and_npc_marker_readability.md`
- Sol inspection of exact constants, deterministic construction, ownership boundary, and focused output.
- After the dedicated accepted VISUAL-06 commit, run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\export.ps1`, rebuild `exports/closed_beta.zip` from the matching non-empty EXE/PCK, verify exactly those two entries, commit the ZIP, and push normally to `origin`.

## Dependencies and handoff

- Builds on completed VISUAL-01, VISUAL-02, VISUAL-05, and the committed runtime portions of VISUAL-04/GAMEPLAY-06.
- The open `TEST-01` ticket describes an older 28 m neon contract superseded in runtime by GAMEPLAY-06; this ticket updates only the directly relevant focused assertion to the current accepted 280 m value plus the new fixture/ad contract and does not close TEST-01.
- One Luna xhigh agent owns all implementation files because the city tests and marker runtime/tests overlap behaviorally; no parallel implementation is permitted.
- Luna must report changed files, exact commands/results, known limitations, and deferred decisions. Sol alone records validation, renames the ticket `_complete`, commits, exports, packages, and pushes.

## Validation record

- Luna xhigh implementation round `019fec8b-3937-7870-8aa8-7ccce113fb00` changed only the five delegated runtime/test files. Sol inspected the complete diff and confirmed the ticket ownership boundary, exact constants, deterministic selection, outward ad offset, normal building occlusion, bounded node construction, preserved midnight environment, and unchanged gameplay/profile behavior.
- `docker compose run --rm godot-tools --headless --path /workspace --script res://tests/test_city_generation.gd -- --neon-only`: PASS (exit code 0). All focused assertions pass for 12 deterministic 4×3 neons, 12 emissive advertising labels, accepted long-range light values, exterior placement, 28-node neon bound, exactly 72 amber street lights, and equal-seed lamp selection.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`: PASS (exit code 0), including civilian blue and hostile red HDR marker readability contracts and existing gameplay/physics suites.
- `docker compose run --rm godot-tools --headless --path /workspace --scene res://scenes/Main.tscn --quit-after 300`: PASS (exit code 0) with no startup script/resource error.
- `git diff --check -- scripts/world/district.gd scenes/Npc.tscn scripts/npc/npc.gd tests/test_city_generation.gd tests/test_pooling.gd tickets/VISUAL-06_expand_street_lighting_neon_ads_and_npc_marker_readability_complete.md`: PASS; only normal LF/CRLF checkout notices were emitted.
- Baseline diagnostics remain non-fatal: the focused city process reports two leaked shape RIDs; the official suite reports six leaked ObjectDB instances and two resources in use; the smoke reports two ObjectDB instances and one resource in use. All commands exit 0.
- No implementation limitation or deferred product decision remains. The unrelated stale full city assertions were intentionally left unchanged.
