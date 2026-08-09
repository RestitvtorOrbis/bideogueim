# UXR-05A2B - Test geometric character normalization

Status: Complete

**Goal**

Add persistent focused tests for the validated UXR-05A2A body wrapper and register them.

**Ownership boundary**

- New `tests/test_character_visuals.gd`
- `tests/test_runner.gd` only to register that suite

**Non-goals**

- Do not edit production files, assets, scenes, catalog, gameplay, or unrelated tests.

**Acceptance criteria**

- Tests cover both bodies, target heights 1.70/1.82, foot Y zero, uniform scale, negative-Z orientation, deterministic repeated configuration, and graceful invalid paths.

**Required tests**

- Run focused visual tests, complete Docker suite, and `git diff --check`.

**Dependencies**

- UXR-05A2A must be completed and validated.

**Validation evidence**

- Decision-owner review confirmed the two-file ownership boundary and persistent coverage for both verified bodies at 1.70/1.82 meters, foot origin, uniform scale, negative-Z forward, deterministic reconfiguration, root replacement, and invalid-input clearing.
- The focused character-visual suite passed 53/53 assertions; `docker compose run --rm --build test` passed 297/297 assertions with exit code 0.
- `git diff --check -- tests/test_character_visuals.gd tests/test_runner.gd` passed. Godot still reports the intentional nonexistent-resource negative fixture and shutdown cleanup warnings; UXR-08 retains responsibility for final leak/resource-lifetime validation.
