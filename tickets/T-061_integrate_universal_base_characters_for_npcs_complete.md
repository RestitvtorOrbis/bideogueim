# T-061 - Integrate Universal Base Characters for NPCs

Status: Complete

## Goal

Replace the visible primitive NPC bodies with the two adult Godot-compatible models from `Universal Base Characters[Standard].zip`, while preserving gameplay and making hostile NPCs immediately distinguishable from civilians.

## Context and evidence

- The user supplied `Universal Base Characters[Standard].zip` at the repository root. Its SHA-256 is `FDBF1804C90DFC1EA03E992BFF7DA2DFD1A79318E13270A660180F9308455F40`.
- The archive license is CC0 1.0 Universal / Public Domain Dedication and identifies Quaternius as the model author.
- The archive's Godot exports contain only `Superhero_Male_FullBody.gltf` and `Superhero_Female_FullBody.gltf`; both use the same verified 65-joint skeleton.
- Those verified model, texture, and compatible rigged-hairstyle files already exist under `assets/characters/quaternius/**` and are documented in `ASSET_MANIFEST.md`; do not duplicate them or commit the source ZIP.
- `HumanCharacterVisual.tscn`, `human_character_visual.gd`, and `human_character_catalog.tres` already provide deterministic body selection, normalization, and shared civilian/hostile palettes.
- `Npc.tscn` still renders primitive `BodyMesh`, `Jacket`, `Head`, `AccentBar`, and shoe nodes. `npc.gd` applies a material only to the primitive body and does not instantiate the shared human wrapper.
- The working tree contains an unrelated user change in `scripts/world/lamp_field.gd`; it is outside this ticket and must remain untouched.

## Ownership boundary

- `scenes/Npc.tscn`
- `scripts/npc/npc.gd`
- `scripts/visual/npc_visuals.gd`
- NPC/pooling-focused assertions in `tests/test_pooling.gd` and `tests/test_population.gd`
- This ticket file, only for implementation handoff details; Sol owns validation evidence, completion rename, and commit.

The existing character assets, catalog, and shared wrapper are read-only dependencies for this ticket. If a defect in those dependencies prevents integration, report it to Sol instead of expanding this boundary.

## Exact implementation scope

- Add exactly one `HumanCharacterVisual` instance to the NPC visual hierarchy and configure it on pool checkout/activation from `human_character_catalog.tres` using the lifecycle identifier as the deterministic seed.
- Use both Standard adult body bases through the catalog's deterministic selection; do not hard-code a single model per role.
- Use deterministic role-appropriate height bands: civilians from the existing 1.68, 1.74, 1.80, and 1.86 metre set; hostiles from 1.78 and 1.86 metres.
- Make roles unmistakable through the existing shared palettes: civilian cool blue/gold and hostile red/orange. Hostiles must also retain the warning marker and equipped prop; civilians must have neither.
- Remove or hide the visible primitive body kit so no legacy body mesh overlaps the imported character. Keep collision and gameplay nodes intact.
- Normalize the common gameplay capsule to total height 1.75 metres, radius 0.35 metres, and centre Y 0.875 metres, independent of visual height.
- Rotate the visual root smoothly toward non-zero horizontal movement direction without changing navigation velocity or AI decisions.
- Reset model, role presentation, yaw state, marker/prop visibility, and any cached per-lifecycle visual state on pool release and reuse.
- Disable dynamic shadow casting on imported NPC meshes to protect the 250-NPC beta target.

## Non-goals

- Do not implement or select animation clips; T-062 owns animation resources and playback.
- Do not change NPC AI, combat, damage, movement speeds, spawn counts, scoring, camera behavior, or player/vehicle visuals.
- Do not render the currently metadata-only hairstyle/eyebrow scenes if doing so requires a second skeleton or retargeting work.
- Do not modify, delete, or stage either root ZIP or the user's `lamp_field.gd` change.
- Do not close or rename existing UXR tickets; Sol will reconcile backlog status separately.

## Constraints and dependencies

- Godot 4.7.1, Forward+, GDScript, Windows target.
- Preserve existing node paths used by gameplay unless tests prove a safe replacement.
- Reuse shared catalog/material resources; no per-NPC duplicated material resources.
- Maintain the existing 250-NPC pooling architecture and avoid per-frame allocations in visual orientation.
- Depends on the completed imported assets/catalog and existing shared visual wrapper. T-062 depends on this ticket.

## Acceptance criteria

- A civilian and hostile NPC both instantiate a valid Standard human body from the two-path catalog, with feet at local Y zero and deterministic selection for a lifecycle ID.
- No visible legacy primitive body remains when the human wrapper is configured.
- Civilian and hostile palettes differ, and hostile marker/prop presentation remains exclusive to hostiles across pool reuse.
- Gameplay capsule dimensions are exactly height 1.75, radius 0.35, centre Y 0.875.
- The visual faces movement direction without altering physics velocity, navigation, or AI state.
- Pool release/checkout cannot leak the prior role's model, palette, marker, prop, height, or orientation.
- Imported NPC meshes cast no dynamic shadows.
- Existing hostile safety and population behavior remains unchanged.

## Minimum MVP validation

- Add focused tests for deterministic civilian/hostile visual configuration, role distinction, legacy-mesh suppression, capsule dimensions, movement-facing yaw, and hostile-to-civilian/civilian-to-hostile pool reuse.
- Run the focused NPC/pooling assertions through the repository test harness.
- Run `git diff --check`.
- Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1` once and report all failures. The pre-ticket baseline has 15 known failures: eight locomotion-cache assertions in the open UXR-05B1 area and seven lamp-impact assertions caused by the unrelated user-owned `lamp_field.gd` change. T-061 must introduce no additional failures; T-061-owned assertions must pass.

## Dependencies

- Existing imported Quaternius assets and `human_character_catalog.tres`.
- Existing `HumanCharacterVisual` normalization and palette API.
- T-062 must start only after Sol accepts and commits T-061.

## Required handoff

Report changed files, the civilian/hostile model and palette selection behavior, exact validation commands/results, any known limitation, and every deferred decision. Do not commit, stage, rename the ticket, or touch unrelated work; Sol owns acceptance and the atomic ticket commit.

## Validation evidence

- Sol inspected the final diff for `scenes/Npc.tscn`, `scripts/npc/npc.gd`, and `tests/test_pooling.gd` and confirmed that the implementation remained within the ownership boundary. `scripts/visual/npc_visuals.gd` and `tests/test_population.gd` required no changes.
- `git diff --check`: passed; only Git's existing LF-to-CRLF checkout warnings were emitted.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`: completed in Godot 4.7.1 with exactly 15 assertion failures, matching the pre-ticket baseline. All new T-061 assertions passed. The remaining failures are the eight pre-existing locomotion cache/lookup assertions owned by T-062 and seven unrelated lamp-impact assertions caused by the preserved user modification in `scripts/world/lamp_field.gd`.
- Verified passing T-061 assertions cover human-body instantiation, civilian and hostile palette assignment, civilian and hostile height bands, primitive-body suppression, exact capsule dimensions, movement-facing yaw, pooled instance reuse, and hostile-only warning marker/prop presentation.
- The source ZIPs and the user-owned lamp change remained unmodified and unstaged.

## Accepted implementation

- NPCs instantiate exactly one shared `HumanCharacterVisual` wrapper and choose either Standard male or female body deterministically from the lifecycle ID.
- Civilians use the civilian shared palette at 1.68, 1.74, 1.80, or 1.86 metres; hostiles use the hostile shared palette at 1.78 or 1.86 metres and retain their exclusive warning marker and prop.
- Legacy primitive body meshes remain present for node-path compatibility but are hidden.
- The gameplay capsule is height 1.75, radius 0.35, centred at Y 0.875; imported meshes have dynamic shadows disabled.
- Pool activation replaces prior body/role state and pool deactivation hides and zeroes the visual orientation. Horizontal movement smoothly drives visual yaw without changing gameplay velocity.
