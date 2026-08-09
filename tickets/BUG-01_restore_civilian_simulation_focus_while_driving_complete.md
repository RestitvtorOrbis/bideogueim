# BUG-01 - Restore civilian simulation focus while driving

## Problem

The user reports that civilians still run incorrectly and appear not to move. The symptom is especially relevant after civilians were made to flee vehicles and given a higher base speed.

## Reproduction and evidence

- `PlayerController.set_occupied_vehicle()` stores the occupied vehicle and disables the player's physics process, but does not move the player body with the car. The player remains at the entry position until exiting.
- `PopulationManager` uses `_player.global_position` for NPC tick distance, movement activation, visual tiers, visibility-cache membership, spawn buckets/candidates/range, and out-of-range recycling.
- While driving away from the entry point, the active camera and car move but the manager's simulation center remains at the stale on-foot player position. Civilians near the car can therefore be skipped by `_can_npc_move()`, remain visually frozen, and never execute vehicle-awareness/flee logic.
- Existing vehicle-flee code in `npc.gd` only works when `PopulationManager` calls `tick()`; changing civilian profile speed cannot correct skipped ticks.

## Goal

Use the occupied vehicle as the population simulation focus while driving and the player body otherwise, so visible/nearby civilians continue ticking and moving around the current gameplay location.

## Ownership boundary

- `scripts/npc/population_manager.gd`
- `tests/test_population.gd`
- this ticket file is owned by Sol; Luna must not edit it

## Implementation scope

- Add one bounded helper that returns the current simulation focus as `Node3D`: a valid, in-tree, non-deleting `_player.occupied_vehicle` when present; otherwise the configured player `Node3D`.
- Use that resolved focus consistently for runtime distance-based population decisions: NPC tick/visual-tier distance, movement activation, spawn bucket/candidate/range and minimum-distance checks, outside-radius visibility membership, and out-of-range recycling.
- Continue passing the real `_player` into pooled NPC activation so hostile damage routing and player/vehicle target APIs remain unchanged.
- Keep the active camera as the source for frustum and line-of-sight checks.
- Clear the visibility cache when the resolved focus switches between player and vehicle so cached membership cannot bridge the transition.
- Do not add per-NPC group searches. Resolve the focus once per top-level operation or frame and reuse it where practical.

## Non-goals

- Do not modify `npc.gd`, civilian/hostile profiles, animations, camera behavior, vehicle physics, spawn counts, distance thresholds, visibility budgets, city code, lighting, or unrelated tests.
- Do not change which node receives hostile attacks or damage.
- Do not speculate about additional animation defects unless the focused regression still fails for a separately evidenced cause.

## Acceptance criteria

- With no occupied vehicle, the manager resolves the configured player as its simulation focus and preserves current behavior.
- With a valid occupied vehicle, the manager resolves the vehicle and all listed population-distance decisions use its current position.
- Switching into or out of a vehicle invalidates the outside-radius visibility cache once.
- An NPC near the vehicle but far from the stale player position is eligible for normal movement/ticking rather than being frozen by the 20 m activation rule.
- Pooled NPC activation still receives the player controller as `target_player`.

## Required minimum validation

- Add a deterministic regression in `tests/test_population.gd` covering player fallback, occupied-vehicle focus, transition cache invalidation, and movement eligibility near the vehicle/far from the stale player.
- Run only the dedicated population test script or its existing runner through the pinned Godot container.
- Run `git diff --check` and inspect the ticket ownership boundary. Do not run the full suite.

## Dependencies and handoff

- This is the only coordinated investigation/correction round for this bug under the beta policy.
- Depends on the existing player `occupied_vehicle` contract and current population manager.
- Luna must report changed files, exact validation commands/results, limitations, and deferred decisions.
- Sol alone records final evidence, renames to `_complete`, and creates the dedicated atomic ticket commit after accepting all criteria.

## Sol validation and acceptance

Accepted on 2026-08-09 after the single coordinated Luna xhigh round `019fe7b6-4325-72a1-9b60-b6f5583cef9a`.

- Sol inspected the complete diff and confirmed ownership is limited to `scripts/npc/population_manager.gd`, `tests/test_population.gd`, and this ticket.
- The manager now resolves the occupied in-tree vehicle as simulation focus, falls back to the configured player, clears visibility cache only on focus transitions, and uses the focus consistently for tick tiers, movement eligibility, spawn distribution/range, visibility membership, and recycling.
- Pool checkout still receives `_player`, preserving hostile target/damage routing.
- `docker compose run --rm --build godot-tools --headless --path /workspace --script res://tests/test_population_runner.gd` exited `0`; every population assertion passed, including player fallback, occupied-vehicle focus, entry/exit cache invalidation, and eligibility for an NPC near the vehicle but far from the stale player transform.
- Godot reported four leaked ObjectDB instances and one resource in use at runner shutdown; these are non-assertion shutdown diagnostics and no functional failure occurred.
- `git diff --check` exited `0` with only normal LF/CRLF conversion warnings.
- User-owned untracked archives and `sourcesforblood.md` remain untouched.

All acceptance criteria and the required minimum regression passed. BUG-01 is accepted for its dedicated atomic commit.

