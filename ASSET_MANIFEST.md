# Asset Manifest

## Política de procedencia

Los mapas PBR externos de esta iteración proceden de páginas oficiales de Poly Haven. Cada página identifica al autor y muestra licencia CC0; los JPG 1K se descargaron sin modificaciones y se conservan dentro de `assets/textures/**`. Los materiales se conectan desde `scripts/world/city_meshes.gd` usando albedo, normal OpenGL (`nor_gl`) y roughness. Los assets procedurales originales anteriores siguen dedicados a dominio público bajo [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

## Texturas PBR CC0 verificadas

| Asset / uso | Página oficial | Autor | Licencia | Archivos locales 1K (tamaño exacto) | Integración |
|---|---|---|---|---|---|
| Clean Asphalt — asfalto | [polyhaven.com/a/clean_asphalt](https://polyhaven.com/a/clean_asphalt) | Dimitrios Savva | CC0 | `assets/textures/clean_asphalt/clean_asphalt_diff_1k.jpg` (697,630 B); `assets/textures/clean_asphalt/clean_asphalt_nor_gl_1k.jpg` (776,360 B); `assets/textures/clean_asphalt/clean_asphalt_rough_1k.jpg` (641,634 B) | Material `road` |
| Concrete Pavement 02 — acera, hormigón y caminos | [polyhaven.com/a/concrete_pavement_02](https://polyhaven.com/a/concrete_pavement_02) | Charlotte Baglioni | CC0 | `assets/textures/concrete_pavement_02/concrete_pavement_02_diff_1k.jpg` (1,052,909 B); `assets/textures/concrete_pavement_02/concrete_pavement_02_nor_gl_1k.jpg` (1,212,387 B); `assets/textures/concrete_pavement_02/concrete_pavement_02_rough_1k.jpg` (541,803 B) | Materiales `sidewalk`, `park_path`, `building_0`, `building_1` |
| Factory Brick — fachadas/ladrillo | [polyhaven.com/a/factory_brick](https://polyhaven.com/a/factory_brick) | Rob Tuytel | CC0 | `assets/textures/factory_brick/factory_brick_diff_1k.jpg` (1,018,112 B); `assets/textures/factory_brick/factory_brick_nor_gl_1k.jpg` (1,057,278 B); `assets/textures/factory_brick/factory_brick_rough_1k.jpg` (942,580 B) | Materiales `building_2`, `building_3` |
| Sparse Grass — terreno y parques | [polyhaven.com/a/sparse_grass](https://polyhaven.com/a/sparse_grass) | Amal Kumar | CC0 | `assets/textures/sparse_grass/sparse_grass_diff_1k.jpg` (955,945 B); `assets/textures/sparse_grass/sparse_grass_nor_gl_1k.jpg` (1,440,314 B); `assets/textures/sparse_grass/sparse_grass_rough_1k.jpg` (463,340 B) | Materiales `ground`, `park` |

| Asset | Source URL | Author | License | Modification notes | Local path |
|---|---|---|---|---|---|
| Urban surface procedural shader | No external source; original procedural code | Urban Drive Prototype team | CC0 1.0 dedication | World-space grid variation, facade accent seams, controlled metallic/roughness and optional emission | `assets/shaders/urban_surface.gdshader` |
| Procedural city generation | No external source; generated at runtime | Urban Drive Prototype team | CC0 1.0 dedication | Seeded road grid, sidewalks, varied buildings, parks, street furniture, shared materials, collisions, navigation and distributed spawn points | `scripts/world/district.gd`, `scripts/world/city_layout.gd`, `scripts/world/city_meshes.gd`, `scenes/District.tscn` |
| Player hard-surface character kit | No external source; original Godot primitive meshes | Urban Drive Prototype team | CC0 1.0 dedication | Added armor plate, shoulder pods, boots, neck, emissive chest core and visor; camera rig is top-level and follows position only to prevent accumulated yaw | `scenes/Player.tscn`, `scripts/visual/player_visuals.gd` |
| NPC modular character kit | No external source; original Godot primitive meshes | Urban Drive Prototype team | CC0 1.0 dedication | Added head, jacket, shoes, emissive accent bar and pulse controller; existing role palette override remains supported | `scenes/Npc.tscn`, `scripts/visual/npc_visuals.gd` |
| Arcade vehicle hard-surface kit | No external source; original Godot primitive meshes | Urban Drive Prototype team | CC0 1.0 dedication | Added hood, roof, glass separation, accent strip, tail lights, visible tires and hubs; existing vehicle camera hierarchy is preserved | `scenes/ArcadeVehicle.tscn`, `scripts/visual/vehicle_visuals.gd` |
| Impact flash and particle polish | No external source; original runtime materials/lights | Urban Drive Prototype team | CC0 1.0 dedication | Added pooled orange impact flashes, emissive red particles, and retained existing pooled decals/fragments/audio | `scripts/effects/impact_effects.gd` |

## Verificación

- No external commercial, marketplace, or non-CC0 asset is referenced.
- No addon or project setting was introduced.
- Procedural city geometry preserves the collision, navigation and spawn contracts used by gameplay systems.
- Original background music: `assets/audio/music/bebop_night_drive.wav`, composed and rendered by `tools/generate_bebop.py` under CC0 1.0. Deterministic seed `26431`; SHA-256 `7e629cfcdd1eea839da66e7f3b49fe85388b44dbf1892a7867ba1a33dca125ac`; stereo 16-bit PCM, 44,100 Hz, 40.851066 seconds, measured quantized peak `0.779968` (-2.158 dBFS). The arrangement contains walking bass, ride/snare swing, piano comping and an original sax-like lead. No song or artist is imitated. The generator always retains this lossless WAV and may add an OGG delivery when FFmpeg is available; the controller uses the existing `Music` bus when available and otherwise falls back to `Master` without changing SFX.

## UXR-01 — Quaternius Universal Base Characters

Decision-owner resolution: Option A. The free Standard archive is intentionally limited to the two available adult body bases, Superhero Male and Superhero Female. Regular models were not required and no paid Source archive was purchased.

Retrieval date: 2026-08-04. Author: Quaternius. License: CC0 1.0 Universal / Public Domain Dedication. Canonical sources: [Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html), [Universal Base Characters itch landing page](https://quaternius.itch.io/universal-base-characters), and [Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html).

### Source archives

| Archive | Canonical source | Exact archive size | SHA-256 |
|---|---|---:|---|
| `Universal Base Characters[Standard].zip` | [itch.io Standard download](https://quaternius.itch.io/universal-base-characters) | 128,968,391 bytes | `FDBF1804C90DFC1EA03E992BFF7DA2DFD1A79318E13270A660180F9308455F40` |
| `Universal Animation Library[Standard].zip` | [Quaternius animation library](https://quaternius.com/packs/universalanimationlibrary.html) | 15,904,933 bytes | `CC73FC4E495B82958207316596317A3F40B9FA38065BDE1027937452DA537724` |

### Retained files

Only glTF/GLB payloads and their referenced buffers/textures are retained. Generated Godot `.import` metadata is local import output and is not part of the retained source inventory.

```text
assets/characters/quaternius/animations/locomotion.glb

assets/characters/quaternius/models/Superhero_Female_FullBody.gltf
assets/characters/quaternius/models/Superhero_Female_FullBody.bin
assets/characters/quaternius/models/Superhero_Male_FullBody.gltf
assets/characters/quaternius/models/Superhero_Male_FullBody.bin
assets/characters/quaternius/models/T_Eye_Brown.png
assets/characters/quaternius/models/T_Eye_Normal.png
assets/characters/quaternius/models/T_Eye_Normal_png.png
assets/characters/quaternius/models/T_Hair_1_BaseColor.png
assets/characters/quaternius/models/T_Hair_1_Normal.png
assets/characters/quaternius/models/T_Hair_1_Normal_png.png
assets/characters/quaternius/models/T_Hair_2_BaseColor.png
assets/characters/quaternius/models/T_Hair_2_Normal.png
assets/characters/quaternius/models/T_Superhero_Female_Dark_BaseColor.png
assets/characters/quaternius/models/T_Superhero_Female_Normal.png
assets/characters/quaternius/models/T_Superhero_Female_Roughness.png
assets/characters/quaternius/models/T_Superhero_Male_Dark.png
assets/characters/quaternius/models/T_Superhero_Male_Normal.png
assets/characters/quaternius/models/T_Superhero_Male_Roughness.png

assets/characters/quaternius/hairstyles/Eyebrows_Female.gltf
assets/characters/quaternius/hairstyles/Eyebrows_Female.bin
assets/characters/quaternius/hairstyles/Eyebrows_Regular.gltf
assets/characters/quaternius/hairstyles/Eyebrows_Regular.bin
assets/characters/quaternius/hairstyles/Hair_Beard.gltf
assets/characters/quaternius/hairstyles/Hair_Beard.bin
assets/characters/quaternius/hairstyles/Hair_Buns.gltf
assets/characters/quaternius/hairstyles/Hair_Buns.bin
assets/characters/quaternius/hairstyles/Hair_Buzzed.gltf
assets/characters/quaternius/hairstyles/Hair_Buzzed.bin
assets/characters/quaternius/hairstyles/Hair_BuzzedFemale.gltf
assets/characters/quaternius/hairstyles/Hair_BuzzedFemale.bin
assets/characters/quaternius/hairstyles/Hair_Long.gltf
assets/characters/quaternius/hairstyles/Hair_Long.bin
assets/characters/quaternius/hairstyles/Hair_SimpleParted.gltf
assets/characters/quaternius/hairstyles/Hair_SimpleParted.bin
assets/characters/quaternius/hairstyles/T_Hair_1_BaseColor.png
assets/characters/quaternius/hairstyles/T_Hair_1_Normal.png
assets/characters/quaternius/hairstyles/T_Hair_2_BaseColor.png
assets/characters/quaternius/hairstyles/T_Hair_2_Normal.png
```

### Selection and modifications

- The two retained body bases are the Standard pack's `Superhero_Female_FullBody.gltf` and `Superhero_Male_FullBody.gltf` Godot exports.
- The eight retained hairstyles are the Standard pack's `Rigged to Head Bone/glTF (Godot -Unreal)` exports: `Eyebrows_Female`, `Eyebrows_Regular`, `Hair_Beard`, `Hair_Buns`, `Hair_Buzzed`, `Hair_BuzzedFemale`, `Hair_Long`, and `Hair_SimpleParted`. These are the complete eight low-cost head-rigged hairstyle assets in the Standard payload; their meshes range from 830 to 3,284 triangles.
- `animations/locomotion.glb` is a derived, compact GLB from `UAL1_Standard.glb`. The source library contained 43 animations; only `Idle_Loop`, `Walk_Loop`, and `Jog_Fwd_Loop` remain. The mannequin mesh, materials, embedded image, unused animation accessors, and unused animation data were removed. The result has no external URI dependencies.
- The Standard male glTF references two unavailable exported texture names, `T_Eye_Normal_png.png` and `T_Hair_1_Normal_png.png`. The retained same-content alias files supply those exact references without modifying the vendor glTF JSON. Their bytes match `T_Eye_Normal.png` and `T_Hair_1_Normal.png`, respectively.
- No ZIP archive, FBX, OBJ, Blend source, teen model, unused animation, scene integration, gameplay code, or product file was added.

## T-062 - Universal Animation Library 2 Standard

The user-supplied `Universal Animation Library 2[Standard].zip` has SHA-256 `4008EA208A604773A2B2177D965F0F5D3195498B5BF838C3F5785D68E95F2A68`. Its `License.txt` grants CC0 1.0 Universal / Public Domain Dedication and credits Quaternius.

Only the non-root-motion Godot export `Unreal-Godot/UAL2_Standard.glb` is retained at `assets/characters/quaternius/animations/ual2_standard.glb` (8,091,444 bytes; SHA-256 `8CEE20AB1BC55130092447E810E26DF22DD2803ECCC54F52137A7D54D7AB88A8`). The archive contains 43 clips and a 65-joint skeleton matching both Standard body models. Godot imports loop suffixes away for this source, so the runtime maps `Walk_Carry` to the public `UAL2_Walk_Carry_Loop` name and `Zombie_Idle` to `UAL2_Zombie_Idle_Loop`.

The runtime exposes and retains only those two UAL2 clips in its shared cache: armed hostile walking uses `UAL2_Walk_Carry_Loop`, hostile idle uses `UAL2_Zombie_Idle_Loop`, and civilian idle/walk continue to use the neutral retained clips. The retained vendor GLB still contains all 43 source clips, but unrelated actions are not added to the runtime library. UAL2 Standard has no normal run/jog clip; both roles therefore use the verified same-rig `Jog_Fwd_Loop` from the existing compact locomotion asset for running. The root-motion GLB variant is not retained.
- Los 12 mapas JPG externos descargados en esta iteración están enumerados arriba con su página oficial, autor, licencia, tamaño y uso; el resto de geometría y shaders es original y procedural.
