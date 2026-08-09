# UXR-05A2 - Implement the normalized human visual wrapper

Status: Complete

**Goal**

Implement model/head-accessory instantiation, AABB normalization, deterministic shared palette materials, visibility tiers, and the integration-facing visual API on top of UXR-05A1.

**Ownership boundary**

- New files under `scripts/visual/characters/**`
- New files under `scenes/visuals/characters/**`
- New `tests/test_character_visuals.gd`
- `tests/test_runner.gd` only to register that suite

**Non-goals**

- Do not implement animation loading or playback.
- Do not edit the catalog, Player, Npc, gameplay, assets, or unrelated tests.

**Acceptance criteria**

- The wrapper reaches requested height via uniform AABB-derived scale, places feet at Y zero, and faces negative Z.
- Body, hairstyle, eyebrows, and shared palette selection are deterministic.
- Materials are cached and shared across 250 logical instances.
- Public API exposes motion-speed and animation-tier placeholders, visibility tier, and right-hand attachment lookup without requiring later redesign.
- Missing catalog/model/skeleton/accessory nodes fail gracefully.

**Required tests**

- Run clean import, focused visual tests, complete Docker suite, and `git diff --check`.
- Verify normalization and Resource identity across 250 logical instances.

**Dependencies**

- UXR-05A1 must be completed and validated.

**Validation evidence**

- Completed through validated UXR-05A2A, UXR-05A2B, and UXR-05A2C microtickets.
- Geometry, deterministic selection, shared palette identity across 250 logical instances, visual/animation-tier state, reset behavior, and right-hand lookup passed in the 594/594 integrated assertion run.
