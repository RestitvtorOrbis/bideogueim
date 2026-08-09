# GAMEPLAY-03 - Make NPCs flee, fight, and roam more dynamically

Status: Complete

## Requested outcome and evidence

Non-hostile NPCs must flee nearby hostiles. Hostiles must occasionally choose a non-hostile NPC as a deliberate projectile target, and a deliberate hostile shot must kill that non-hostile NPC in one hit. The overall crowd should spend more time moving so the city feels more dynamic.

Current evidence: `scripts/npc/npc.gd` only lets civilians wander or flee from the player after panic; hostile engagement always resolves the player or occupied vehicle as its aim target. Default wandering chooses a target for 3-8 seconds, civilian/hostile speeds are 2.4/2.8 m/s, and far movement runs at 65% speed. Existing projectiles already collide with NPCs and preserve pooled death replacement.

## Goal

Add bounded hostile awareness and deliberate civilian targeting while preserving player combat, projectile obstruction, pooling, grace, panic, and performance contracts.

## Ownership boundary

- `scripts/npc/npc.gd`
- `scripts/resources/npc_profile.gd`
- `resources/default_civilian_profile.tres`
- `resources/default_hostile_profile.tres`
- Directly scoped assertions in `tests/test_system_contracts.gd`

Do not edit population, city, vehicle, visual, scene, ticket, export, or unrelated test files.

## Exact implementation scope and constraints

- Active NPCs must register in role-addressable scene-tree groups on activation and unregister on deactivation so bounded nearby-role queries can work with pooling.
- Civilian hostile-awareness queries must be throttled/staggered, not performed as an all-NPC scan on every physics tick. A civilian within a default 15 m horizontal flee radius of an active hostile enters a hostile-flee behavior, moves directly away at 1.8x its configured walk speed, and returns to wandering only after no hostile remains within a 20 m release radius.
- Existing panic/flee-from-player behavior remains distinct and must still work. Hostile awareness must not make hostiles flee other hostiles.
- At a normal hostile firing opportunity, the hostile may deliberately select a living active civilian within normal projectile range. Default selection probability is 0.06 per firing opportunity and a successful deliberate civilian shot starts a separate 12-second per-hostile cooldown. If no valid civilian is selected, the existing player/vehicle target remains unchanged.
- A deliberate civilian-targeted projectile must use damage sufficient to kill a full-health default civilian in one hit. Player/vehicle shot damage remains 3, aim spread remains 14 degrees, attack interval remains 1.5 seconds, projectile range remains 18 m, and projectiles remain obstructable and non-homing.
- Target selection and shot construction must expose deterministic seams so automated tests do not depend on random outcomes. Weapon aim/recoil must follow the selected target for that shot.
- Increase default civilian/hostile walk speeds to 3.0/3.4 m/s, shorten ordinary wander retarget time to 2-5 seconds, widen ordinary wander radius to 8-28 m, and raise far movement to 80% configured speed. Preserve the safe-radius and grace-specific wander constraints.

## Non-goals

- No player weapons, new factions, squad tactics, navigation redesign, allocation-based NPC discovery, score-rule changes, gore changes, population count changes, or projectile visual redesign.
- Do not alter deliberate hostile shots against the player/vehicle except for choosing an occasional civilian target.
- Do not change NPC pooling or role-preserving death replacement.

## Acceptance criteria

- A civilian deterministically detects and flees a nearby hostile, moves away faster than walking, and stops hostile-fleeing only beyond the release radius.
- Hostile detection is throttled/staggered and pooled activation/deactivation leaves no stale role-group membership.
- A deterministic deliberate civilian shot aims at a civilian, carries one-shot civilian damage, and leaves ordinary player/vehicle shots at 3 damage.
- Default probability and cooldown keep deliberate civilian targeting infrequent, while ordinary hostile firing continues when no civilian is chosen.
- Existing panic, hostile grace, safe radius, player/vehicle aim routing, NPC projectile interception, pooling, and death lifecycle tests remain green.
- Default movement values and wander timing/radius match the recorded scope.

## Required tests and validation

- Add deterministic assertions covering role group lifecycle, civilian detection/flee direction/speed/release, civilian-only targeting, probability/cooldown gates, one-shot civilian damage, unchanged player damage, and updated movement defaults.
- Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`.
- Run a headless import and bounded `Main.tscn` smoke through the repository's Docker/Godot workflow if the test script does not already cover them.
- Run `git diff --check`.

## Dependencies and handoff

- Depends on completed COMBAT-01 and GAMEPLAY-02 behavior.
- May run in parallel with WORLD-01 because ownership is disjoint.
- Luna must report changed files, exact validation commands/results, known limitations, and any deferred decision. Sol owns final acceptance, ticket completion, and the dedicated atomic commit.

## Validation evidence

- Luna xhigh implementation round: `019fe551-ea33-7391-8b44-67d09582e35c`. Sol inspected the complete owned diff and found two preservation regressions before acceptance; GAMEPLAY-03A added focused review coverage while the bounded runtime corrections were incorporated into this parent implementation before closure.
- Sol review confirms civilians register by role, scan active hostiles on a staggered 0.30-second cadence, flee within 15 m at 1.8x walk speed, and release beyond 20 m. Pooled deactivation removes all role groups.
- Hostiles select a living civilian with default probability 0.06 and a separate 12-second cooldown, pass one-shot civilian damage to the existing obstructable projectile, and preserve 3-damage player/vehicle fire, 14-degree spread, 18 m range, and 1.5-second attack cadence.
- Default civilian/hostile speeds are 3.0/3.4 m/s; ordinary wander radius is 8-28 m, retarget time 2-5 seconds, and far movement is 80% speed. Grace-specific movement remains unchanged.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`: all GAMEPLAY-03 and GAMEPLAY-03A assertions pass. Exit 1 is limited to the eight pre-existing locomotion-cache failures outside this ownership boundary.
- `docker compose run --rm godot-tools --headless --path /workspace --editor --import --quit`: exit 0.
- `docker compose run --rm godot-tools --headless --path /workspace --scene res://scenes/Main.tscn --quit-after 300`: exit 0 with the existing two ObjectDB/one resource shutdown diagnostics.
- `git diff --check`: exit 0 with line-ending warnings only.
- Decision-owner result: ACCEPTED. Every GAMEPLAY-03 acceptance criterion and required regression contract is validated.
