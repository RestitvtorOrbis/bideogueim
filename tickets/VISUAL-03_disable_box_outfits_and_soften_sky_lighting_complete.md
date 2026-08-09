# VISUAL-03 - Disable box outfits and soften sky lighting

## Requested outcome

Remove the procedural outfit change presentation because its torso and accessory shapes appear as boxes around the imported character models. Reduce the excessive building darkness by using more than one sky light, and replace the current brown lighting cast with a subtle, cleaner yellow.

## Context and evidence

- `HumanCharacterVisual._configure_outfit()` currently creates a `BoxMesh` torso shell and one `BoxMesh` detail for every configured catalog character. It is called during both direct body configuration and catalog configuration.
- The imported Quaternius body models already include textured clothing, so removing the procedural overlay must preserve the base model and its palette/material handling.
- `District.tscn` currently defines one shadow-casting `DirectionalLight3D`. Its key color, environment ambient color, and fog color all carry strong red/brown components.
- Building shadows need fill illumination without doubling shadow rendering cost.

## Goal

Disable procedural box outfit geometry for all shared human character visuals and rebalance the district sky lighting around a subtle clean-yellow key plus a non-shadowing directional fill light.

## Ownership boundary

Allowed implementation files:

- `scripts/visual/characters/human_character_visual.gd`
- `scenes/District.tscn`
- `tests/test_character_visuals.gd`
- `tests/test_city_generation.gd` only if a small scene-contract assertion is the simplest reliable lighting check
- this ticket file

## Non-goals

- Do not remove, replace, recolor, or reimport the textured Quaternius body models.
- Do not alter hairstyle or eyebrow resource selection, locomotion, NPC behavior, population, city geometry, street lamps, building neon lights, fog density, or shadow distance.
- Do not add per-building, per-window, or unbounded lights.
- Do not disable shadows on the existing key directional light.
- Do not delete the outfit implementation API or cached helper code unless required for a clean, narrowly scoped disablement; callers must remain safe.

## Implementation requirements

- Stop normal character configuration from creating `SharedLowPolyOutfit`, torso, cap, glasses, or backpack geometry. Reconfiguration and body clearing must remain safe and leave no stale outfit nodes.
- Preserve base body meshes, textured palette materials, animation, visibility tiers, and catalog role selection.
- Keep one existing shadow-casting directional key light and add exactly one district-level directional fill light oriented from a meaningfully different/opposing azimuth.
- The fill light must have shadows disabled and lower energy than the key light.
- Change the key, ambient, and fog lighting away from brown/orange toward a restrained ivory or pale-yellow hue. The scene must remain a night scene rather than becoming neutral white daylight.
- Keep the total district sky-light count fixed at exactly two.

## Acceptance criteria

- Configuring player, civilian, or hostile shared human visuals produces no procedural outfit torso/detail nodes and reports no active outfit geometry through the existing inspection API.
- Repeated configuration and clear/reconfigure paths remain error-free and do not leave stale outfit nodes or attachments.
- Imported body models and their textured palette materials still configure successfully.
- `District.tscn` contains exactly two `DirectionalLight3D` children: one shadow-casting key and one lower-energy, non-shadowing fill from a different direction.
- Key, ambient, and fog colors are visibly pale yellow/ivory and no longer brown-dominant.
- Relevant headless tests pass.

## Required validation

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`
- Inspect the final diff to confirm the ownership boundary and the fixed two-light, one-shadow arrangement.

## Handoff

Report changed files, the exact light colors/energies/orientations selected, test command and result, known limitations, and any deferred decision.

## Validation record

Implemented in the allowed runtime, scene, and focused test files.

- `_configure_outfit()` now only clears any legacy outfit nodes/references; normal body/catalog configuration adds no procedural torso, cap, glasses, or backpack geometry.
- `District.tscn` now has one shadowed key at `Vector3(-52, -28, 0)`, color `Color(1.0, 0.94, 0.78, 1.0)`, energy `0.68`, plus one opposing non-shadowing fill at `Vector3(-38, 152, 0)`, color `Color(0.84, 0.88, 0.72, 1.0)`, energy `0.24`. Ambient is `Color(0.64, 0.61, 0.47, 1.0)` and fog is `Color(0.34, 0.32, 0.25, 1.0)`; fog density and shadow distance are unchanged.
- Focused character tests now cover player/civilian/hostile catalog roles, direct body configuration, repeated `_configure_outfit()` calls, clear, and reconfiguration with no active outfit geometry.
- City tests now assert exactly two district-level directional lights, one shadow policy, lower fill energy, opposing azimuth, and the requested pale colors.
- Validation: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1` passed with exit code 0. The initial sandboxed invocation was denied by Docker daemon permissions; the same required command then passed with process-scoped elevated access.

Decision-owner review on 2026-08-09 confirmed the implementation remained inside the recorded ownership boundary and satisfied every VISUAL-03 acceptance criterion.

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1` -- exit 0 in the final review; all assertions passed. Godot emitted only existing shutdown diagnostics about six leaked ObjectDB instances and two resources still in use.
- `docker compose run --rm --build godot-tools --headless --path /workspace --script res://tests/test_city_generation.gd` -- all six new district-lighting assertions passed, including exactly two directional lights, one shadowed key, one lower-energy opposing fill, and the ivory/pale-yellow color contract. The script exited 1 only because its pre-existing neon assertion still rejects the VISUAL-02 range of 28 m; that independent stale-test defect is recorded as `TEST-01_align_neon_range_contract_with_visual_02.md` and is outside this ticket.
- Final diff inspection confirmed no changes to imported character assets, animation, NPC behavior, city geometry, street lamps, neons, fog density, or directional shadow distance. Unrelated source archives and `sourcesforblood.md` remain untouched.
