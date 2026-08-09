# UXR-05A1B1 - Create the default human catalog resource

Status: Complete

**Goal**

Create the single default `.tres` instance of the validated HumanCharacterCatalog contract.

**Ownership boundary**

- `resources/human_character_catalog.tres`

**Non-goals**

- Do not edit scripts, tests, wrapper files, scenes, gameplay, or any other resource.

**Acceptance criteria**

- The resource uses `scripts/resources/human_character_catalog.gd` and loads with the contract's exact 2/6/2 paths, three clip identifiers, and civilian/hostile/player palette metadata.

**Required tests**

- Run a Godot 4.7.1 load/import smoke check and `git diff --check` for the resource.

**Dependencies**

- UXR-05A1 must be completed and validated.

**Validation evidence**

- Decision-owner review confirmed the one-file ownership boundary and that the `.tres` uses the validated HumanCharacterCatalog defaults without duplicating or overriding paths.
- Godot 4.7.1 Docker import/load smoke passed; all six default hairstyle paths exist.
- `git diff --check -- resources/human_character_catalog.tres` passed.
