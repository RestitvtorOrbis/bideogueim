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
- Los 12 mapas JPG externos descargados en esta iteración están enumerados arriba con su página oficial, autor, licencia, tamaño y uso; el resto de geometría y shaders es original y procedural.
