# UXR-05A1B - Instantiate and test the default human catalog resource

Status: Complete

**Goal**

Create the default catalog `.tres` and focused tests for the validated UXR-05A1 contract.

**Ownership boundary**

- `resources/human_character_catalog.tres`
- New `tests/test_character_catalog.gd`
- `tests/test_runner.gd` only to register that suite

**Non-goals**

- Do not edit the catalog script, wrapper files, models, materials, animation runtime, Player, Npc, or gameplay.

**Acceptance criteria**

- The resource records exactly the two verified body paths, six hairstyle paths, two eyebrow paths, shared role-palette metadata, and three public clip identifiers through the UXR-05A1 contract.
- Focused tests verify resource loading, exact counts/paths, deterministic seed/index behavior, safe empty-count handling, and exact public clip names.

**Required tests**

- Run clean import, focused catalog tests, complete Docker suite, and `git diff --check`.

**Dependencies**

- UXR-05A1 must be completed and validated.

**Validation evidence**

- Completed through validated microtickets UXR-05A1B1 and UXR-05A1B2.
- The default resource loads through the validated contract, 50 focused catalog assertions pass, and the complete Docker suite exits successfully.
