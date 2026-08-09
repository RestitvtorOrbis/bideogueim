# VISUAL-02 - Ground textured NPCs and rebalance night lighting

Status: Complete

## Requested outcome and evidence

NPCs using the new human models appear above the ground, their materials read as flat solid colors, and portions of the city are too dark. The requested night treatment is warm, old-street-lamp illumination in otherwise unlit areas, with colder neon and accent lights that are stronger and reach farther.

Repository evidence:

- NPC spawn markers are generated at Y `1.25` and `Npc.activate()` assigns that value directly. NPC movement has no gravity or floor snap. The NPC capsule bottom and the normalized human visual feet are both at local Y zero, so the whole NPC remains above the road/sidewalk surface.
- Both Quaternius body GLTFs already reference base-color, normal, and roughness textures. `HumanCharacterVisual._apply_palette_materials()` replaces every imported material with a cached solid `StandardMaterial3D`, discarding those textures.
- Street lamps render emissive glow spheres but have no `Light3D`. The environment ambient light is cool and relatively bright. Building neons use eight bounded, non-shadowing OmniLight3D nodes at energy `7.0` and range `20.0`.

## Goal

Ground active NPC bodies on the actual traversable surface, preserve and tint the imported textured character materials, and rebalance the city night lighting around dim warm ambience, bounded amber street lamps, and colder stronger/farther-reaching neons.

## Ownership boundary

- `scripts/npc/npc.gd`
- `scripts/visual/characters/human_character_visual.gd`
- `scripts/world/district.gd`
- `scripts/world/lamp_field.gd` only if needed to keep selected lamp lights aligned when a lamp bends
- `scripts/world/city_meshes.gd`
- `scenes/District.tscn`
- This ticket file

Do not edit population density/selection, NPC AI/combat/animation selection, player or vehicle behavior, city layout/building placement, imported GLTF/PNG assets, export tooling, or automated test files.

## Exact implementation scope and decisions

### NPC grounding

- On NPC activation, resolve the walkable surface directly below the requested spawn X/Z with a bounded downward physics ray against world collision layer 1, excluding the NPC itself.
- Start the ray safely above the incoming spawn and end below the city ground. Set the NPC root Y to the hit position plus at most `0.02 m` clearance. Preserve X/Z exactly.
- If no physics world/hit is available, fall back to the incoming position without error. Do not add per-frame raycasts, gravity, floor snapping, or movement changes.
- Because both the collision capsule and normalized visual feet start at local Y zero, grounding the root must align both gameplay collision and rendered feet rather than adding a visual-only offset.

### Textured NPC materials

- Preserve each imported surface material's albedo/base-color texture, normal texture, and roughness/metallic texture instead of assigning a textureless solid override.
- Apply deterministic civilian/hostile palette tinting by duplicating and caching textured source materials. Cache keys must distinguish role/palette, body variant, source material/surface, and visual slot so 250 NPCs do not allocate unique materials.
- Determine hair/eye/body slots from imported material names and mesh names. The body texture may contain both clothing and exposed skin, so do not attempt an unsupported UV-region split or generate new textures.
- Keep the existing public palette material API usable for current callers, preserve deterministic role distinction, and retain the source material when it is not a compatible `StandardMaterial3D` rather than replacing it with a flat fallback.

### Night lighting

- Retune `District.tscn` to a dim warm ambient fill: warm brown/amber ambient color with energy between `0.30` and `0.45`; warm the fog and directional key while keeping the night background dark and preserving glow/tonemapping.
- Keep street-lamp emissive geometry amber and increase its emissive readability modestly.
- Add a deterministic, evenly distributed, strictly bounded set of at most `24` non-shadowing amber `OmniLight3D` street-lamp sources selected from generated lamp transforms. Use energy `2.6`, range `22 m`, and a warm old-lamp color close to `#ffb35c`. Put them at the lamp glow position and expose their count/index mapping through a named root or metadata.
- If a selected physical lamp bends, update its corresponding light transform with the glow transform; do not redesign lamp damage behavior.
- Keep exactly eight building neon lights. Raise neon energy from `7.0` to `9.0` and range from `20.0 m` to `28.0 m`; retain cold cyan/magenta/purple colors and disabled shadows.
- Keep total new dynamic-light count bounded and do not add shadows, flicker, per-window lights, or unbounded per-lamp nodes.

## Non-goals

- No new texture generation/import, UV editing, accessory rendering, character redesign, shader development, day/night cycle, baked GI, lightmap work, volumetric redesign, lamp placement changes, or broad performance tuning.
- No new regression suite or deeper visual automation. Broader lighting/performance QA belongs in a future ticket after beta.

## Acceptance criteria

- A newly activated NPC with a valid surface below it has root/capsule/visual feet within `0.02 m` of that surface, with unchanged X/Z and no per-frame grounding work.
- Civilian and hostile bodies visibly use the existing imported textures and retain normal/roughness data while remaining deterministically role-tinted.
- Material instances are shared through a bounded cache rather than allocated once per NPC.
- Unlit geometry receives dim warm fill; the key/fog read warm rather than blue.
- Up to 24 evenly distributed amber street lights cast local light with energy `2.6`, range `22 m`, no shadows, and remain aligned with selected bendable lamps.
- Exactly eight cold neon lights remain, each at energy `9.0`, range `28 m`, and no shadows.
- NPC activation/movement, lamp bending, deterministic city construction, and `Main.tscn` startup still function.

## Required minimum validation

- Do not add tests. Inspect the final diff and run `git diff --check`.
- Run only the existing focused character-visual seam needed to confirm imports/material setup still load, if it has a repository command that does not require modifying tests.
- Run one bounded headless `Main.tscn` smoke through the repository Docker workflow and confirm clean startup/no new script or resource errors.
- Do not run the complete regression suite or export pipeline for this beta visual correction.

## Dependencies and handoff

- Existing untracked source archives `Universal Animation Library 2[Standard].zip` and `Universal Base Characters[Standard].zip` are user-owned and must remain untouched.
- This is one coordinated beta bug-fix round. Luna must reproduce/confirm the three evidence paths, implement only this ticket, and report changed files, exact validation commands/results, known limitations, and deferred decisions. If the stated evidence is contradicted, do not make a speculative correction; return the contradiction to Sol.
- Sol owns final inspection, acceptance, ticket completion rename, dedicated atomic commit, and any repository push required by the repository policy.

## Implementation and validation evidence

- Luna xhigh implementation round `019fe67b-c388-76b0-bbac-540428f0b4a8` confirmed all three evidence paths and changed only the six allowed runtime/scene files. The two user-owned untracked source ZIP archives remained untouched.
- NPC activation now performs one bounded layer-1 downward ray, excludes the NPC RID, preserves X/Z, and places the root at the hit surface plus `0.02 m`; no per-frame grounding work was added.
- Character surfaces now clear the flat whole-mesh override, duplicate compatible imported `StandardMaterial3D` resources into a shared keyed cache, preserve their imported texture maps, and apply deterministic role/body/surface tinting. Unsupported source materials remain unchanged.
- The environment uses warm ambient energy `0.38`, warm fog/key light, 24 deterministically distributed non-shadowing amber street-lamp lights at energy `2.6` and range `22 m`, and eight cold non-shadowing neon lights at energy `9.0` and range `28 m`. Registered street lights follow their glow transform when the matching lamp bends.
- Sol inspected the complete diff and confirmed the implementation remains within the ticket ownership boundary and acceptance decisions.
- `docker compose run --rm godot-tools --headless --path /workspace --scene res://scenes/Main.tscn --quit-after 300`: exit `0` in 29.5 seconds with no startup script/resource errors. The known shutdown-only diagnostics remain: two leaked ObjectDB instances and one resource still in use.
- `git diff --check`: exit `0`; only line-ending conversion warnings were emitted.
- Per the requested beta minimum, no automated tests, full regression suite, export, or package build were run.

## Sol final acceptance

Every acceptance criterion is satisfied at the requested Minimum Viable Product validation level. The ticket is accepted and renamed complete for its dedicated atomic commit.
