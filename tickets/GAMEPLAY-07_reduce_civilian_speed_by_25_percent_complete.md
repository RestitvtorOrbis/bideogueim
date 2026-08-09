# GAMEPLAY-07 - Reduce civilian speed by 25 percent

## Requested outcome and evidence

The user requests a 25% reduction to civilian NPC speed.

- `resources/default_civilian_profile.tres` currently defines civilian `walk_speed = 6.0` m/s.
- A 25% reduction is `6.0 * 0.75 = 4.5` m/s.
- NPC wandering and flee states already derive their movement from the active profile's `walk_speed`, so changing the default civilian profile preserves all existing state multipliers while reducing their resulting civilian speeds proportionally.
- `resources/default_hostile_profile.tres` independently defines hostile `walk_speed = 3.4` m/s and is outside this request.

## Goal

Set the default civilian base movement speed to exactly `4.5` m/s without changing hostile movement or AI behavior.

## Ownership boundary

- `resources/default_civilian_profile.tres`
- `tests/test_system_contracts.gd`
- this ticket file is owned by Sol; Luna must not edit it

## Implementation scope

- Change only the default civilian profile `walk_speed` from `6.0` to `4.5`.
- Update the existing system-contract assertion for civilian walk speed to expect `4.5` and describe the current contract accurately.
- Preserve every other civilian profile field and all runtime state multipliers.

## Non-goals

- Do not alter hostile speed, player or vehicle speed, NPC AI state logic, flee multipliers, acceleration, animation playback, population, spawn rules, markers, collisions, visuals, or city behavior.
- Do not modify the earlier `VISUAL-04` ticket; this ticket records the user's newer tuning decision.
- Do not touch user-owned untracked archives or `sourcesforblood.md`.

## Acceptance criteria

- The shipped default civilian profile has `walk_speed = 4.5`, exactly 75% of the prior `6.0`.
- The default hostile profile remains `3.4`.
- Existing civilian movement states continue consuming profile speed and retain their current multipliers.
- The focused system contract expects and passes at `4.5`.
- No tracked files outside the ownership boundary are changed for this ticket.

## Required minimum validation

- Run the existing system-contract runner through the pinned Godot container.
- Run `git diff --check` and inspect the ticket ownership boundary.
- Do not run broader regression or gameplay suites under the beta MVP policy.

## Dependencies and handoff

- This tuning follows the implemented `VISUAL-04` increase from `3.0` to `6.0`; the new requested value supersedes that speed only.
- Luna must report changed files, exact validation commands/results, limitations, and deferred decisions.
- Sol alone records acceptance evidence, renames this ticket with `_complete`, creates its dedicated atomic commit, and performs the mandatory Windows export/package workflow.

## Sol validation and acceptance

Accepted on 2026-08-09 in coordinated Luna xhigh round `019fe7c7-b1d0-7681-84a3-7b3123a13ef7`.

- Sol inspected the exact resource diff: civilian `walk_speed` changed only from `6.0` to `4.5`, which is a 25% reduction; every other civilian profile field is unchanged.
- The hostile profile remains at `3.4`, and targeted source inspection confirmed existing wander and flee paths continue deriving movement from `profile.walk_speed` with unchanged multipliers.
- The pre-existing system contract was corrected from its stale `3.0` expectation to the requested `4.5` value.
- Luna's isolated system-contract runner exited `0` with all assertions passing.
- Sol's first isolated run passed the new civilian `4.5` and hostile `3.4` contracts but exposed one unrelated nondeterministic failure in the random 2-to-5-second wander-retarget assertion. An immediate rerun exited `0` with every assertion passing, confirming suite flakiness rather than a speed regression. No unrelated correction was made under the beta policy.
- `git diff --check` exited `0` with only normal LF/CRLF conversion warnings.
- Final implementation ownership is limited to `resources/default_civilian_profile.tres` and `tests/test_system_contracts.gd`; temporary runners were removed and user-owned untracked files remain untouched.

All acceptance criteria and required minimum validation passed. GAMEPLAY-07 is accepted for its dedicated atomic commit.
