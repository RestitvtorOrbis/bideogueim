# UXR-05 - Create the shared human-character visual component

Status: Open

**Goal**

Create a reusable visual component that normalizes character transforms, selects deterministic variants, shares materials, and drives the three retained locomotion animations.

**Ownership boundary**

- New files under `scripts/visual/characters/**`
- `scripts/resources/human_character_catalog.gd`
- `resources/human_character_catalog.tres`
- New files under `scenes/visuals/characters/**`
- A new focused character visual test suite
- `tests/test_runner.gd` only to register that suite

**Non-goals**

- Do not edit `scenes/Player.tscn`, `scenes/Npc.tscn`, or gameplay behavior.

**Acceptance criteria**

- Every model wrapper places the feet at local Y zero and faces local negative Z.
- Uniform scale derives from the imported AABB and reaches the requested target height.
- A source model facing positive Z receives a 180-degree wrapper yaw.
- Variant selection is deterministic for a supplied lifecycle identifier or seed.
- Materials and animation resources are cached and shared rather than duplicated per actor.
- The component supports idle, walk, and run/jog selection from movement speed.

**Required tests**

- Verify normalized AABB height, foot origin, and forward orientation.
- Verify deterministic variant selection.
- Verify that 250 logical instances reference shared material and animation resources.

**Dependencies**

- UXR-01 must be completed and validated.

**Validation evidence**

- Pending.
