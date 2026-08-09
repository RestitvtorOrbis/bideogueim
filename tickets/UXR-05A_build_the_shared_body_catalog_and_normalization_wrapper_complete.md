# UXR-05A - Build the shared body catalog and normalization wrapper

Status: Complete

**Goal**

Implement the asset catalog, deterministic body/head-accessory selection, AABB normalization, shared material cache, and integration-facing API without animation playback.

**Ownership boundary**

- `scripts/resources/human_character_catalog.gd`
- `resources/human_character_catalog.tres`
- New files under `scripts/visual/characters/**`
- New files under `scenes/visuals/characters/**`
- New `tests/test_character_visuals.gd`
- `tests/test_runner.gd` only to register that suite

**Non-goals**

- Do not integrate locomotion animations yet.
- Do not edit Player, Npc, gameplay, assets, unrelated tests, `TICKETS.md`, or `AGENTS.md`.

**Acceptance criteria**

- The catalog exposes the two body bases, six hairstyles, two eyebrow accessories, and shared palette definitions.
- The wrapper places feet at local Y zero, faces local negative Z, and reaches a requested target height through uniform AABB-derived scale.
- Variant selection is deterministic from a supplied seed or lifecycle identifier.
- Materials are cached by variant and shared; 250 logical instances do not create per-instance material resources.
- The public API already exposes body, height, role palette, accessory variant, motion speed, animation tier, visibility tier, and right-hand attachment lookup needed by later tickets.

**Required tests**

- Run clean Godot import, the focused character visual suite, and the complete Docker suite.
- Verify AABB normalization, deterministic selection, shared Resource identities across 250 logical instances, and graceful missing-node handling.

**Dependencies**

- UXR-01 must be completed and validated.

**Validation evidence**

- Completed through validated UXR-05A1 and UXR-05A2 microtickets.
- The final shared catalog/wrapper tree passed 594/594 assertions with deterministic body/accessory metadata, normalized geometry, shared palette Resource identity, tier-state APIs, and graceful hand/accessory failure behavior.
- Accessory scenes are selected and cached but intentionally not instantiated because each retained accessory glTF imports its own full skeleton; direct instantiation would duplicate incompatible rigs. Later integration must preserve this explicit deferred policy rather than render broken duplicate skeletons.
