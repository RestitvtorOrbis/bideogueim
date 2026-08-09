# UXR-05A1B2 - Test and register the human catalog contract

Status: Complete

**Goal**

Add focused catalog tests and register them in the dependency-free runner.

**Ownership boundary**

- New `tests/test_character_catalog.gd`
- `tests/test_runner.gd` only to register that suite

**Non-goals**

- Do not edit production scripts, resources, wrapper files, assets, scenes, or gameplay.

**Acceptance criteria**

- Tests cover resource loading, exact paths/counts/uniqueness, existing asset files, palette keys, exact clip names, deterministic seed/index behavior, salt behavior, and non-positive counts.

**Required tests**

- Run the focused catalog suite, complete Docker suite, and `git diff --check`.

**Dependencies**

- UXR-05A1B1 must be completed and validated.

**Validation evidence**

- Decision-owner review confirmed the two-file ownership boundary, exact six verified hairstyle expectations, all required catalog assertions, and preserved runner registration.
- The focused catalog suite passed 50 assertions; `docker compose run --rm test` passed.
- `git diff --check -- tests/test_character_catalog.gd tests/test_runner.gd` passed.
