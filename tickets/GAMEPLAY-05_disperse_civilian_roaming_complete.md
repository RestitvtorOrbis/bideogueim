# GAMEPLAY-05 - Disperse civilian roaming

Status: Complete

## Problem and evidence

Civilian spawn placement is already stratified and separated by GAMEPLAY-04, but active civilians visibly reconverge and travel together. `Npc._select_wander_target()` currently centers every ordinary wander target on `target_player.global_position` and samples the same 8-28 meter annulus. That shared attractor defeats the initial distribution over time.

## Goal

Keep ordinary civilians roaming independently around their own activation area so they remain spatially dispersed instead of converging around the player.

## Ownership boundary

- `scripts/npc/npc.gd`
- Directly scoped assertions in `tests/test_population.gd`
- This ticket file

## Exact implementation scope

- Record a per-lifecycle roaming anchor from the grounded activation position and reset it on pool release.
- For ordinary civilian `WANDER`, select targets around that civilian's own roaming anchor, not around the player.
- Preserve the current bounded wander radius and timing unless a directly scoped correction is needed to satisfy the tests.
- Preserve hostile grace/safe-radius behavior and hostile engagement behavior; hostiles may retain their existing player-relative rules.
- Preserve panic, flee, hostile-awareness, pooling, spawn distribution, role counts, collision, and movement speed.
- Do not add per-frame all-NPC neighbor scans or another O(N^2) crowd pass.

## Non-goals

- No navigation rewrite, reciprocal avoidance, spawn algorithm change, population cap change, model/animation change, performance-tier change, HUD change, export, or unrelated cleanup.

## Acceptance criteria

- Two civilians activated at distinct positions retain distinct roaming anchors matching their grounded activation positions.
- Repeated ordinary civilian target selection remains bounded around each civilian's own anchor and is not centered on the player's current position.
- Moving the player does not drag existing civilians' ordinary roaming regions with it.
- Pool release and reactivation replace the old roaming anchor without stale lifecycle state.
- Hostile grace wander targets still satisfy the configured player safe radius.
- Existing population, panic, hostile-awareness, role, pooling, and spawn-separation contracts remain green.

## Required validation

- Add focused deterministic assertions to `tests/test_population.gd` for independent anchors, player movement, bounded targets, pool reset/reactivation, and unchanged hostile grace safety.
- Run `docker compose run --rm godot-tools --headless --path /workspace --script res://tests/test_population_runner.gd`.
- Run a bounded headless `Main.tscn` smoke.
- Run `git diff --check`.

## Dependencies and handoff

- Implement before PERF-01 because both tickets may touch `scripts/npc/npc.gd` and population tests.
- Luna must report changed files, exact commands/results, known limitations, and deferred decisions.
- Sol must inspect all changes, record validation below, rename this file with `_complete`, and close it in one dedicated atomic commit containing no unrelated changes.

## Validation evidence

- Sol inspected the implementation and confirmed it remains within `scripts/npc/npc.gd`, `tests/test_population.gd`, and this ticket. Ordinary civilians use a grounded per-lifecycle anchor; hostile player-relative grace behavior is unchanged; no neighbor scan or new population pass was added.
- `docker compose run --rm godot-tools --headless --path /workspace --script res://tests/test_population_runner.gd`: exit 0; all 65 population assertions passed, including independent grounded anchors, bounded anchor-relative targets, player-independent roaming, pool reset/reactivation, and hostile safe-radius regressions.
- `docker compose run --rm godot-tools --headless --path /workspace --scene res://scenes/Main.tscn --quit-after 300`: exit 0. Godot reported two ObjectDB instances and one resource still in use during shutdown; these pre-existing bounded-smoke warnings do not fail the command or indicate a GAMEPLAY-05 regression.
- `git diff --check`: exit 0 with line-ending conversion warnings only.
- Every acceptance criterion and required MVP validation is satisfied. Broader multi-seed crowd observation is deferred under the beta policy.
