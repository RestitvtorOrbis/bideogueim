# UXR-05A1 - Define the verified human asset catalog contract

Status: Complete

**Goal**

Create the pure typed catalog contract that enumerates asset-path metadata, palette metadata, public locomotion clip names, and deterministic seed helpers without loading resources.

**Ownership boundary**

- `scripts/resources/human_character_catalog.gd`

**Non-goals**

- Do not create the `.tres` resource or tests in this ticket.
- Do not call `load`/`preload`, use `PackedScene`, instantiate models, normalize transforms, create materials/caches, or load/play animation resources.

**Acceptance criteria**

- The contract contains exactly two body paths, six hairstyle paths, and two eyebrow paths, each represented once.
- Stable seed and variant-index helpers are deterministic and handle empty arrays safely.
- Public clip identifiers are exactly `Idle_Loop`, `Walk_Loop`, and `Jog_Fwd_Loop`; this ticket stores identifiers only.
- The script parses in Godot 4.7.1 and contains none of `load(`, `preload(`, `PackedScene`, `StandardMaterial3D`, `AnimationPlayer`, or material-cache code.

**Required tests**

- Run clean Godot import/parse, a static forbidden-symbol audit, exact path/count audit, and `git diff --check`.

**Dependencies**

- UXR-01 must be completed and validated.

**Validation evidence**

- Decision-owner review confirmed the one-file ownership boundary and replacement of the prior out-of-scope partial implementation.
- Static audit found exactly 2 body paths, 6 hairstyle paths, 2 eyebrow paths, the three exact public clip identifiers, and zero forbidden runtime-loading/material/animation symbols.
- All ten listed asset paths exist; deterministic helpers handle non-positive counts safely.
- Godot 4.7.1 Docker import/parse completed with exit code 0; `git diff --check -- scripts/resources/human_character_catalog.gd` passed.
