# UXR-05A2A - Implement body instantiation and geometric normalization

Status: Complete

**Goal**

Create the HumanCharacterVisual scene/script with only body loading, recursive visual AABB calculation, uniform target-height scale, foot-origin alignment, and negative-Z forward normalization.

**Ownership boundary**

- New `scripts/visual/characters/human_character_visual.gd`
- New `scenes/visuals/characters/HumanCharacterVisual.tscn`

**Non-goals**

- Do not add accessories, palette/material overrides, animation, visibility tiers, right-hand attachments, gameplay integration, or repository tests.

**Acceptance criteria**

- The scene loads either validated body path through a small explicit API.
- Recursive transformed AABB normalization reaches requested height, places the visual minimum Y at zero, uses uniform scale, and rotates a positive-Z source to face negative Z.
- Missing catalog/body/mesh data returns a clear failure without crashing.

**Required tests**

- Run clean Godot import and a temporary/non-repository smoke script for both body paths and requested heights 1.70 and 1.82.
- Run `git diff --check` for the two files.

**Dependencies**

- UXR-05A1B must be completed and validated.

**Validation evidence**

- Decision-owner review confirmed the exact two-file ownership boundary, deterministic body replacement, recursive transformed AABB merge, uniform scaling, foot-origin alignment, and negative-Z forward normalization.
- Godot 4.7.1 Docker import passed; temporary smoke checks passed for both body paths at target heights 1.70 and 1.82 with min Y zero and final forward negative Z.
- Invalid path/height/mesh paths fail without crashing; temporary artifacts were removed and `git diff --check` passed.
