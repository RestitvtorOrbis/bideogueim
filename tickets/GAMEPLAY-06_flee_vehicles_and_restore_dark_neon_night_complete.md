# GAMEPLAY-06 - Flee vehicles and restore a dark neon night

## Requested outcome

Civilian NPCs should try to flee the car, NPCs must not collide with one another, and the district should return to a clearly nocturnal look whose readability comes primarily from artificial city lighting. Building-neon dispersion and reach must be amplified tenfold. The user explicitly requested no tests.

## Context and evidence

- `scripts/npc/npc.gd` currently gives civilians staggered hostile awareness and dedicated hostile-flee movement, but no awareness of nodes in the existing `vehicle` group.
- `scenes/ArcadeVehicle.tscn` and `scripts/vehicle/arcade_vehicle.gd` register the car in the `vehicle` group.
- Active NPCs use collision layer `8` and collision mask `5` (world layer `1` plus vehicle layer `4`). Because layer `8` is absent from their mask, NPC-to-NPC collision is already disabled while vehicle-to-NPC impact remains possible. Activation/recycling must preserve this contract.
- `scripts/world/district.gd` creates exactly eight deterministic non-shadowing building-neon `OmniLight3D` nodes at energy `9.0`, range `28.0`, and default attenuation `1.0`.
- `scenes/District.tscn` currently uses background `Color(0.035, 0.06, 0.1)`, ambient energy `0.38`, and two directional lights at energy `0.68` and `0.24`, making the non-artificial sky/key contribution too bright for the requested look.
- The user clarified that “dispersion 10x” means a much wider projection angle rather than distance falloff: light should spread broadly instead of directionally. Existing `OmniLight3D` fixtures already provide the maximum omnidirectional 360-degree projection and have no cone angle to multiply. Preserve that light type and its normal/default attenuation `1.0`; apply the literal tenfold multiplier only to reach, `omni_range: 28.0 -> 280.0`. Neon energy and global glow/bloom remain unchanged to avoid overexposure.

## Goal

Add bounded, performance-conscious civilian vehicle avoidance; preserve explicit NPC-to-NPC collision exclusion; and rebalance the district into a darker night dominated by much broader and farther-reaching neon illumination.

## Ownership boundary

Implementation may modify only:

- `scripts/npc/npc.gd`
- `scenes/Npc.tscn` only if needed to make the existing NPC collision contract explicit
- `scripts/world/district.gd`
- `scenes/District.tscn`
- this ticket file for Sol validation notes and completion rename

## Implementation decisions

- Add a dedicated civilian vehicle-flee state or an equivalently explicit vehicle-threat branch. Do not overload hostile role semantics.
- Only active, living civilians flee vehicles. Hostiles retain their current behavior.
- Detect the nearest valid node in the existing `vehicle` group on a staggered/throttled cadence, not through an all-frame query per NPC.
- Enter vehicle flee within an 18 m horizontal radius and release only when no valid vehicle remains within 24 m. This hysteresis prevents state flicker.
- Vehicle-flee movement is directly away from the threat at `2.0x` the civilian profile walk speed. If the direction degenerates, use a deterministic fallback direction.
- Vehicle fleeing takes precedence over ordinary wandering and hostile-flee movement while a vehicle is within its active/release radius, but existing panic/flee-from-player behavior remains higher priority and unchanged.
- A valid vehicle must be an in-tree, non-deleting `Node3D` in the `vehicle` group. Do not require it to be occupied or moving.
- Preserve active NPC collision layer `8` and mask `5`, and inactive/dead layer/mask `0`. Never add NPC layer `8` to the NPC mask. Preserve vehicle layer/mask and vehicle impact behavior.
- Keep every building neon as an omnidirectional `OmniLight3D` (360-degree projection), set range to exactly `280.0`, preserve normal/default attenuation `1.0`, energy `9.0`, count eight, and shadows disabled. Preserve deterministic fixture selection, sign geometry, colors, and placement. Do not substitute a directional or spot light.
- Darken the non-artificial base in `District.tscn`: background `Color(0.012, 0.022, 0.045, 1)`, ambient energy `0.18`, key directional energy `0.28`, and fill directional energy `0.08`. Preserve existing light colors, rotations, shadow flags/distance, fog density/height, tonemapping, glow intensity `0.85`, and bloom `0.12`.

## Non-goals

- Do not alter hostile combat, hostile targeting, panic duration, NPC population/spawn/recycling policy, player controls, vehicle physics/impact damage, or city layout.
- Do not add avoidance steering, navigation redesign, new vehicle sensors, new light fixtures, or per-NPC physics queries.
- Do not modify street-lamp lighting, neon colors/signs/count/placement, global glow/bloom, fog density, imported assets, export tooling, or unrelated tickets.
- Do not add, edit, update, or execute automated tests. Leave the pre-existing open `TEST-01` ticket untouched even though its old range contract becomes more stale.

## Acceptance criteria

- A living active civilian within 18 m horizontally of the car enters vehicle flee and moves away at `2.0x` walk speed.
- Vehicle flee persists until no valid car is within 24 m, then the civilian resumes its existing behavior without disrupting panic or hostile behavior.
- Vehicle awareness is staggered/throttled and does not scan the vehicle group on every NPC physics tick.
- Hostiles never enter vehicle flee.
- Active NPCs retain layer `8` / mask `5`; therefore NPCs do not collide with one another, while car-to-NPC impacts still work. Inactive/dead NPCs retain layer/mask `0`.
- The environment base is visibly darker with background, ambient, key, and fill values exactly as specified.
- Exactly eight deterministic omnidirectional neon lights remain at energy `9.0`, range `280.0`, normal/default attenuation `1.0`, with shadows disabled.
- No files outside the ownership boundary are modified and user-owned untracked archives/document remain untouched.

## Required validation (no tests)

- Do not run anything under `tests/` and do not run `tools/test.ps1`.
- Inspect the final diff and use targeted `rg`/file reads to verify the exact state radii, speed multiplier, stagger cadence, collision layer/mask, environment values, neon count/energy/range/attenuation, and unchanged ownership boundary.
- If a local Godot binary is already available without installing dependencies, run only a headless project parse/editor startup-and-quit command. This is syntax/resource validation, not an automated test. If unavailable, record that and do not install or export.

## Dependencies and handoff

- Builds on completed `GAMEPLAY-03`, `VISUAL-02`, and `VISUAL-03` behavior.
- Luna must report changed files, exact validation commands/results, known limitations, and deferred decisions.
- Sol alone inspects acceptance criteria, records validation here, renames this file with `_complete`, and closes it in one dedicated atomic commit containing only this ticket and its implementation.

## Sol validation and acceptance

Accepted on 2026-08-09 after the single Luna xhigh implementation round `019fe79c-132e-7203-ab40-703e0dfbf624` and direct Sol diff inspection.

- `git diff --check` completed with no whitespace errors; Git reported only the repository's normal LF-to-CRLF working-tree warnings.
- `git diff --name-only` listed exactly `scenes/District.tscn`, `scripts/npc/npc.gd`, and `scripts/world/district.gd`. This ticket is untracked until the closing commit. No automated test or unrelated tracked file changed.
- Targeted `rg` inspection confirmed the dedicated civilian `VEHICLE_FLEE` state, 18 m enter radius, 24 m release radius, `2.0x` speed, 0.30-second staggered awareness, living civilian gate, nearest valid `vehicle` group query, and hostiles excluded.
- Targeted `rg` inspection confirmed active NPC layer `8` / mask `5` both in the scene and activation path; NPC layer `8` remains absent from the mask, while vehicle layer `4` remains included. Inactive/dead clearing to layer/mask `0` remains unchanged.
- Targeted `rg` inspection confirmed exactly eight deterministic `OmniLight3D` fixtures remain, with energy `9.0`, range `280.0`, attenuation `1.0`, and shadows disabled. The fixtures therefore retain full 360-degree projection rather than a directional cone.
- Targeted `rg` inspection confirmed background `Color(0.012, 0.022, 0.045, 1)`, ambient energy `0.18`, key energy `0.28`, and fill energy `0.08`, while glow intensity `0.85`, bloom `0.12`, fog density `0.0018`, and shadow settings remain unchanged.
- Per explicit user instruction, no automated tests were added, edited, or executed. `tools/test.ps1` and everything under `tests/` were untouched.
- No local `godot` executable is available, so the optional headless parse/editor startup was not run and no dependency was installed. Visual confirmation remains a manual runtime follow-up rather than a blocker under the beta MVP/no-tests instruction.
- User-owned untracked archives and `sourcesforblood.md` remained untouched.

All acceptance criteria that can be established without running the game are satisfied. The ticket is accepted for its dedicated atomic closing commit.
