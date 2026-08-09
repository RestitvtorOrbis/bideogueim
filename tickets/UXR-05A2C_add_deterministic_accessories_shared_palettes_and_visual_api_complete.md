# UXR-05A2C - Add deterministic accessories, shared palettes, and visual API

Status: Complete

**Goal**

Extend the validated wrapper with deterministic hair/eyebrow selection, cached shared palette materials, visibility tiers, motion/animation-tier data setters, and right-hand bone lookup.

**Ownership boundary**

- `scripts/visual/characters/human_character_visual.gd`
- `scenes/visuals/characters/HumanCharacterVisual.tscn`
- `tests/test_character_visuals.gd`

**Non-goals**

- Do not load or play locomotion animations and do not integrate Player/Npc gameplay.

**Acceptance criteria**

- Seed/lifecycle selection is deterministic for body, six hairstyles, two eyebrows, and role palette.
- Palette materials are cached by variant and shared across 250 logical instances, never duplicated per actor.
- Visibility tier, motion speed, and animation tier APIs store/apply state without animation playback.
- Right-hand lookup resolves `hand_r` or fails gracefully.

**Required tests**

- Extend focused tests for determinism, shared Resource identity across 250 logical instances, tiers, state reset, and hand lookup; run complete Docker suite.

**Dependencies**

- UXR-05A2B must be completed and validated.

**Validation evidence**

- Decision-owner review confirmed deterministic 2/6/2 body-hairstyle-eyebrow selection, role palettes, normal/throttled/frozen tier semantics, finite non-negative speed state, reset/reconfigure behavior, and graceful `hand_r`/missing-resource handling within the permitted production/test files.
- Accessories are loaded as shared `PackedScene` selections but deliberately not instantiated because their imported scenes contain independent complete skeletons; the API reports `deferred_shared_skeleton` and tests prevent accidental duplicate-rig rendering.
- Palette materials are process-cached by palette, body variant, and slot; 250 logical instances reuse the same Resource identity and add at most one matching cache entry.
- Decision-owner final run: `docker compose run --rm test` exited 0 with 594/594 assertions and zero failures; `git diff --check` passed. Godot reports two leaked ObjectDB instances and one cached Resource still in use at shutdown; UXR-08 must distinguish intentional process-lifetime cache retention from growth.
