# NPC-01 - Gate NPC movement by visibility and add sourced gore and outfit detail

Status: Open

## Requested outcome and repository evidence

The user requested three coordinated NPC changes: NPCs may move only while they are within the player's immediate 20 meter surroundings or in the player's line of sight; gunshots and vehicle impacts need stronger gore based on the resources documented in `sourcesforblood.md`; and NPCs need clothing and additional visual detail.

Repository evidence:

- `PopulationManager._physics_process()` currently ticks every active NPC. NPCs beyond `mid_ai_distance` still execute `_tick_far_movement()`, so off-camera and occluded NPCs continue moving.
- `PopulationManager._is_in_active_camera_frustum()` already provides a camera-frustum seam for spawn selection, but movement does not use it and there is no world-occlusion check.
- `Npc.receive_vehicle_impact()` emits an `ImpactEvent`, while projectile damage goes directly through `HostileProjectile._resolve_impact()` to `apply_damage()` and never reaches `ImpactEffects`.
- `ImpactEffects` uses bounded pools, but only procedural red spheres, a flat untextured quad, and box fragments. Its event position is inferred from `event.source`, which is the vehicle for run-over events rather than the struck NPC.
- `sourcesforblood.md` identifies OpenGameArt Animated Particle Effects #2 blood-hit atlases and Kenney Splat Pack as CC0, lightweight options. The official pages confirm OpenGameArt blood hits are 4x4, 16-frame sheets at 128x128 cells and Kenney provides 30 CC0 splat textures.
- Quaternius NPC body models preserve textured clothing, but selected hairstyle/eyebrow resources remain intentionally unrendered. `HumanCharacterVisual` already has the body skeleton, deterministic lifecycle seed, palette cache, and visibility tiers needed for lightweight procedural outfit details.

## Goal

Reduce NPC simulation cost by freezing movement outside the player's immediate surroundings unless the NPC is actually camera-visible and unobstructed, route both projectile and vehicle hits through a richer but strictly pooled blood presentation, and add deterministic low-cost clothing/accessory detail to NPC visuals.

## Ownership boundary

- `scripts/npc/population_manager.gd`
- `scripts/npc/npc.gd`
- `scripts/npc/hostile_projectile.gd`
- `scripts/resources/impact_event.gd`
- `scripts/effects/impact_effects.gd`
- `scripts/visual/characters/human_character_visual.gd`
- `tests/test_population.gd`
- `tests/test_system_contracts.gd`
- `tests/test_character_visuals.gd`
- `assets/vfx/blood/**` for the narrowly retained CC0 source images and license/readme metadata
- `ASSET_MANIFEST.md`
- This ticket file

Do not modify user-owned untracked source ZIP archives, NPC population counts/spawn rules, combat balance/damage values, vehicle physics, player controls, imported Quaternius files, project settings, export tooling, or unrelated tests.

## Exact implementation scope and decisions

### Movement activation

- Define the immediate activation radius as exactly `20.0 m`, measured horizontally from the active player/damage-target root to each NPC.
- NPCs at or inside 20 m remain active regardless of camera direction or world occlusion.
- Outside 20 m, an NPC may be ticked only when its representative point (root plus approximately 1 m vertical offset) is in the active camera frustum and a ray from the camera to that point is not blocked by world collision layer 1.
- Treat a missing active camera as no long-range line of sight; only NPCs within 20 m may tick.
- Distribute outside-radius line-of-sight checks through a deterministic bounded per-frame budget and cache the result per active NPC. Refresh visible entries frequently enough to avoid obvious stutter (target maximum stale interval about 0.25 seconds at 60 FPS), clear cache entries on release/reconfigure, and immediately reject cached visibility when the NPC leaves the frustum. Do not perform one ray per NPC per frame.
- When movement is inactive, do not call `Npc.tick()` at all. Continue existing population recycling and visual-tier updates. When active, retain the existing near/mid/far AI cadence and `full_ai` behavior.
- Expose a small pure/helper seam so focused tests can establish the 20 m boundary, missing-camera behavior, and cached/frustum gating without broad integration testing.

### Projectile and vehicle gore events

- Extend `ImpactEvent` compatibly with an explicit world position and impact kind (`projectile` or `vehicle`), keeping existing constructor call sites valid through defaults.
- `Npc.receive_vehicle_impact()` must emit the struck NPC position and `vehicle` kind.
- Add a projectile-hit entry point on NPCs that applies the existing damage exactly once and emits a qualifying `projectile` impact containing hit position, shot direction/impulse, source, and projectile speed. `HostileProjectile` must call it when available and fall back to the existing `apply_damage()` contract for other receivers.
- Gore presentation must respect all existing `ViolenceSettings` presets. Disabled produces none; Reduced keeps a lower-density blood hit and decal without fragments; Full enables the richer channels.
- Retain a small, representative CC0 subset: at least two OpenGameArt `blood_hit_*.png` 4x4 atlases and at least three visually distinct Kenney splat PNGs. Do not retain the complete archives or unrelated images. Record canonical URL, author, license, retrieval date, exact local path, size, SHA-256, and modifications in `ASSET_MANIFEST.md` and a local source note if useful.
- Add a bounded pool of camera-facing animated blood-hit sprites using the OpenGameArt sheets. Play their 16 frames once at approximately 30 FPS, with deterministic or cursor-based variation, scale/intensity higher for vehicle impacts than projectile impacts, and no per-impact allocation.
- Replace flat untextured decal presentation with pooled Kenney splat textures, randomized/cursor-based texture, yaw, and scale. Keep decals on/just above the ground and bounded by the existing decal limit.
- Preserve bounded droplet and fragment pools, but make Full vehicle impacts visibly heavier than projectile impacts through particle count/velocity, sprite scale, decal scale, and multiple bounded fragment/decal emissions. Do not add high-poly 3D blood, Alembic conversion, new dynamic shadows, or unbounded nodes.

### Clothing and visual details

- Add deterministic low-poly outfit details constructed from shared primitive meshes/material resources and attached to existing skeleton bones when available. Every configured NPC must receive a torso clothing layer (vest/jacket-like shell or equivalent), plus one deterministic detail variant chosen from at least three visibly distinct options such as cap, glasses, backpack, scarf, belt/pouches, or shoulder detail.
- Select colors and detail variants from the existing stable lifecycle seed and role while preserving clear hostile/civilian distinction. Cache/share meshes and materials; do not allocate unique material resources per NPC.
- Bone attachments must follow animation and fail gracefully when an expected bone is absent. Outfit nodes must be replaced cleanly on reconfiguration and removed/hidden with the visual wrapper lifecycle.
- Hide nonessential outfit detail at reduced/hidden visibility tiers so the extra geometry does not negate the performance change. The torso clothing layer may remain at reduced tier if required for silhouette, but all outfit nodes must be hidden at hidden tier.
- Do not attempt to render the deferred Quaternius hairstyle/eyebrow skeleton resources, alter their policy, or edit vendor assets.

## Non-goals

- No player weapon feature, dismemberment system, ragdoll redesign, persistent wall-projected decals, shader-based wound system, high-poly fluid simulation, paid/CGTrader assets, broad AI redesign, population reduction, model replacement, or full performance benchmark campaign.
- No regression expansion beyond focused contracts for the changed seams. Deeper performance profiling and visual acceptance across hardware remain follow-up work after beta.

## Acceptance criteria

- At exactly 20 m an NPC can tick regardless of visibility; beyond 20 m an off-frustum or world-occluded NPC receives no movement tick, while an unobstructed in-frustum NPC retains the existing cadence.
- Outside-radius visibility raycasts are bounded/staggered rather than performed for all NPCs every frame, stale visible entries are rejected when leaving the frustum, and cache state is cleared when NPCs are released or the manager is reconfigured.
- Vehicle impacts use the struck NPC position and trigger visibly heavier pooled gore than projectile hits.
- Projectile impacts on NPCs apply damage once and trigger pooled animated blood, particles, and decals according to the violence preset.
- The retained blood assets are from the two documented CC0 sources, load in Godot, and have complete provenance/hash entries.
- Pools remain hard-bounded with no per-impact node/material allocation.
- Each configured NPC has a deterministic torso clothing layer and one of at least three deterministic detail variants; shared resources remain bounded and detail visibility follows visual tiers.
- Existing NPC pooling/reconfiguration, projectile damage fallback, vehicle impact scoring, role readability, animation selection, and startup continue to work.

## Required minimum validation

- Add/update only focused assertions in `tests/test_population.gd`, `tests/test_system_contracts.gd`, and `tests/test_character_visuals.gd` for the new seams and run the repository's existing headless test command once.
- Run `git diff --check`.
- Run one bounded headless `Main.tscn` smoke through the repository Docker workflow and confirm no new script/resource/startup errors.
- Do not run the full export/package pipeline or broad benchmark suite for this beta change.

## Dependencies and handoff

- Preserve the user-owned untracked files `sourcesforblood.md`, `Universal Animation Library 2[Standard].zip`, and `Universal Base Characters[Standard].zip` unchanged.
- This is one coordinated implementation round. One GPT-5.6 Luna xhigh worker owns the entire ticket because runtime and test seams overlap. The worker must confirm evidence, implement only this scope, and report changed files, exact validation commands/results, asset provenance/hashes, known limitations, and deferred decisions.
- If a material ambiguity remains or the same command/test/build failure occurs twice for the same apparent cause, the worker must use `$avisor-skill` before proceeding.
- The decision owner must inspect the final diff and validate every acceptance criterion before recording results, renaming this ticket `_complete`, and creating its dedicated atomic commit. Do not push unless separately required by repository policy.

## Implementation evidence — 2026-08-09

Implemented within the stated ownership boundary. `PopulationManager` now uses an exact horizontal 20.0m movement gate, a deterministic twenty-entry-per-frame outside-radius layer-1 camera LOS budget, a 0.25s visibility cache, immediate frustum invalidation, and cache clearing on release/reconfigure. NPC projectile hits now route through `receive_projectile_impact()` exactly once, while vehicle events carry the struck NPC world position and explicit `vehicle` kind. `ImpactEffects` now owns bounded animated 16-frame blood-hit sprites, three pooled textured Kenney decal meshes, heavier vehicle particle/fragment/decal/sprite channels, and preset-aware reduced/disabled behavior. `HumanCharacterVisual` now creates shared primitive torso clothing plus deterministic cap/glasses/backpack detail variants, attaches the torso to a matching spine/chest bone with graceful fallback, and applies visual-tier visibility handling; vendor hairstyle/eyebrow rendering remains deferred.

Focused review correction: `get_visibility_refresh_seconds(250, 60.0)` evaluates to `13.0 / 60.0` seconds, remaining within the 0.25s stale limit while retaining a fixed per-frame raycast bound. Focused visual assertions cover torso bone attachment, clean replacement, reduced/hidden visibility, and fallback geometry when no matching bone exists.

Retained assets are exactly two OpenGameArt `blood_hit` atlases and three Kenney Splat Pack PNGs under `assets/vfx/blood/`; complete provenance, retrieval date, dimensions, sizes, hashes, and modification notes are recorded in `ASSET_MANIFEST.md`.

Validation completed:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1` — exit 0 under Godot 4.7.1; all emitted assertions passed. The initial sandbox invocation could not access Docker, so the same required command was rerun through the approved Docker-engine path. Shutdown-only diagnostics reported 40 leaked ObjectDB instances and one resource still in use.
- `docker compose run --rm --build godot-tools --headless --path /workspace --scene res://scenes/Main.tscn --quit-after 300` — exit 0; no startup parse/resource errors. Shutdown-only diagnostics reported 81 leaked ObjectDB instances and one resource still in use.
- `git diff --check` — exit 0; only Git LF-to-CRLF normalization warnings were emitted.

Focused correction: `docker compose run --rm godot-tools --headless --path /workspace --script res://tests/test_population_runner.gd` — exit 0; all population assertions passed, including the 250-NPC visibility cadence assertions.

Direct `res://tests/test_character_visuals.gd` execution was not applicable: Godot exited before running assertions because the suite extends `RefCounted`, not `SceneTree` or `MainLoop`; the broad test runner was intentionally not invoked.

Final `git diff --check` — exit 0; only Git LF-to-CRLF normalization warnings were emitted.

No export, package, benchmark, commit, push, or ticket rename was performed. Deferred decisions remain the vendor hairstyle/eyebrow rendering policy, broader performance profiling, and rendered-hardware visual QA outside this beta MVP round. The Avisor consultation path was unavailable as a callable tool after the initial two temporary-download TLS failures; the approved external-network path then retrieved and verified the ticket-approved assets successfully.

## Decision-owner final acceptance — 2026-08-09

The final diff was inspected against every ownership boundary and acceptance criterion. Review identified and corrected two issues within the same coordinated Luna round: the outside-radius visibility budget was raised from 8 to 20 so all 250 configured NPCs refresh in 13 frames (approximately 0.217 seconds at 60 FPS), and the torso clothing layer now follows a spine/chest bone when available with a tested static fallback. No unrelated file or user-owned source archive was changed.

Final validation performed by the decision owner:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1` — exit 0; all assertions passed, including the 20 m boundary, 250-NPC LOS cadence, single projectile damage/event, bounded VFX pools, heavier vehicle gore, shared outfit resources, bone attachment/fallback, and visual-tier behavior. Godot reported only the known shutdown diagnostics: four leaked ObjectDB instances and one resource still in use.
- `docker compose run --rm --build godot-tools --headless --path /workspace --scene res://scenes/Main.tscn --quit-after 300` — exit 0 with no new parse, resource, script, or startup errors. Godot reported only the known shutdown diagnostics: two leaked ObjectDB instances and one resource still in use.
- `git diff --check` — exit 0; only line-ending normalization warnings.
- SHA-256 verification matched every retained blood PNG entry in `ASSET_MANIFEST.md`. `sourcesforblood.md` remained `89F1BF1E1AF3BDD402760A584AC624FA527A9CFC0BBA6E8E57E3E60DF92D4C5D`; the user-owned UAL2 and base-character ZIPs remained `4008EA208A604773A2B2177D965F0F5D3195498B5BF838C3F5785D68E95F2A68` and `FDBF1804C90DFC1EA03E992BFF7DA2DFD1A79318E13270A660180F9308455F40`.

Every acceptance criterion is satisfied at the requested beta MVP validation level. The ticket is accepted for its dedicated atomic commit.
