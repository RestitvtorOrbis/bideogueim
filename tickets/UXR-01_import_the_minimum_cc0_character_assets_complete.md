# UXR-01 - Import the minimum CC0 character assets

Status: Complete

**Goal**

Import the two adult Superhero Male/Female character models available in the free Standard archive, its six compatible hairstyles and two eyebrow accessories, and only the idle, walk, and run/jog animations needed by the game from the Quaternius Universal Base Characters Standard pack and Universal Animation Library.

**Ownership boundary**

- `assets/characters/quaternius/**`
- `ASSET_MANIFEST.md`

**Non-goals**

- Do not integrate the assets into Player or Npc scenes.
- Do not retain downloaded ZIP archives, FBX, OBJ, Blend sources, unavailable paid Regular models, teen models, or unused animations.
- Do not modify gameplay code.

**Acceptance criteria**

- The retained assets are limited to the free Superhero Male and Superhero Female bases, six low-cost non-clipping hairstyles, two eyebrow accessories, idle, walk, run/jog, and their referenced buffers and textures.
- Every retained model imports as glTF or GLB without missing dependencies in Godot 4.7.1.
- `ASSET_MANIFEST.md` records the canonical source URL, author, CC0 license, retrieval date, archive size, archive SHA-256, retained files, and modification notes.
- No downloaded archive or unused alternate format remains in the repository.

**Required tests**

- Run a clean headless Godot import.
- Inspect each retained model and animation for missing resources.
- Record the retained asset payload size and verify that all retained files are referenced.

**Dependencies**

- None.

**Validation evidence**

- The free Standard archive was inspected and found to contain only the Superhero Male/Female adult bases. After a required advisor consultation, the decision owner selected those two verified CC0 bases instead of purchasing the unavailable Regular models.
- Godot 4.7.1 headless import completed with exit code 0 and no import errors.
- The retained source audit found 39 files totaling 49,566,909 bytes: 10 BIN, 10 glTF, 1 GLB, and 18 PNG; all glTF dependencies resolve and no ZIP, FBX, OBJ, Blend, teen, or paid Regular asset remains.
- The trimmed animation GLB contains exactly `Idle_Loop`, `Walk_Loop`, and `Jog_Fwd_Loop` and has no external URI, mesh, material, or image payload.
- Decision-owner review confirmed that `ASSET_MANIFEST.md` records canonical sources, CC0, retrieval date, exact archive sizes and SHA-256 values, retained inventory, and modifications.
