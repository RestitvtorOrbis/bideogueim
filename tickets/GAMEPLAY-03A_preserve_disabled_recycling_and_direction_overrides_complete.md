# GAMEPLAY-03A - Preserve disabled recycling and projectile direction overrides

Status: Complete

## Problem and evidence

Sol review of the GAMEPLAY-03 implementation found two bounded regressions before acceptance:

1. `npc.gd::tick()` runs civilian hostile-awareness before the existing `State.DISABLED` early return. `_scan_hostile_awareness()` does not reject `DISABLED`, so a dead civilian near an active hostile can transition to `HOSTILE_FLEE`; its disabled timer then stops advancing and population recycling can stall.
2. `fire_hostile_projectile()` computes `explicit_direction` but always derives the launch vector from `selected_target` whenever a player target exists. Existing callers that pass `direction_override` therefore no longer control projectile direction, violating the deterministic projectile seam preserved by COMBAT-01/GAMEPLAY-02.

## Goal

Correct only these two review failures while preserving all intended GAMEPLAY-03 behavior.

## Ownership boundary

- `scripts/npc/npc.gd`
- Directly scoped assertions in `tests/test_system_contracts.gd`

Do not edit profiles, resources, population, world, vehicle, scene, ticket, export, or unrelated test files.

## Exact implementation scope

- A civilian in `INACTIVE` or `DISABLED` must never run hostile-awareness scanning or transition to `HOSTILE_FLEE`. Its disabled timer must continue advancing exactly as before GAMEPLAY-03 so `is_disabled_for_recycle()` remains reachable.
- `refresh_hostile_awareness()`, `_update_hostile_awareness()`, and `_scan_hostile_awareness()` must consistently reject inactive/disabled/dead actors.
- A non-zero `direction_override` passed to `fire_hostile_projectile()` must be normalized and used as the projectile launch direction before spread, exactly as the pre-GAMEPLAY-03 contract. An explicit `target_override` may still control deliberate-civilian damage and weapon presentation, but must not silently replace a non-zero direction override.
- Calls without `direction_override` must retain GAMEPLAY-03 target selection, civilian one-shot damage, player fallback, aim spread, recoil, and cooldown behavior.

## Non-goals

- No retuning, new behavior, API redesign, additional target classes, population changes, or changes to WORLD-01.

## Acceptance criteria

- Killing a civilian next to an active hostile leaves it in `DISABLED`; repeated ticks advance its disabled timer and it becomes recyclable.
- Awareness entry points return false/do nothing for inactive, disabled, and dead civilians.
- A deterministic non-zero direction override produces a matching normalized fired direction when spread is zero, even while a player and eligible civilian exist.
- Deliberate civilian targeting without a direction override still aims at and one-shots the civilian, and ordinary player shots remain unchanged.

## Required tests and validation

- Add focused regression assertions for disabled-state stability/recycle timing and explicit direction precedence.
- Run the official test suite, headless import, bounded Main smoke, and `git diff --check`.

## Dependencies and handoff

- Depends on the unaccepted GAMEPLAY-03 implementation and must be validated together with it.
- This is the single coordinated implementation round for these review-discovered regressions.
- Luna must report changed files, exact validation commands/results, known limitations, and deferred decisions. Sol owns acceptance and commits. If accepted, GAMEPLAY-03A must close in its own dedicated atomic commit after GAMEPLAY-03 is committed, without duplicating unrelated changes.

## Integration and validation evidence

- Luna xhigh follow-up round: `019fe565-9c6e-7121-bd47-b67c72c993bb` reproduced both review cases and supplied the bounded runtime guards plus deterministic assertions.
- Because both runtime guards preserve explicit acceptance criteria and pre-existing contracts of the still-open parent, Sol incorporated the guards into the validated GAMEPLAY-03 runtime commit `4c79ff4`. This dedicated follow-up commit owns the non-duplicative regression assertions that permanently exercise those corrections.
- The direction test proves a non-zero `(3, 0, 4)` override is normalized and retained with zero spread even when other targets exist.
- Disabled/dead tests prove hostile awareness entry points reject the actor, `DISABLED` remains stable beside a hostile, the disabled timer reaches 1.5 seconds/recycle eligibility, and inactive actors reject awareness.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test.ps1`: all GAMEPLAY-03A assertions pass. Exit 1 is limited to the eight pre-existing locomotion-cache failures outside this boundary.
- Headless import and bounded Main smoke both exit 0; `git diff --check` exits 0 with line-ending warnings only.
- Decision-owner result: ACCEPTED. The follow-up is bounded to regression coverage and contains no unrelated implementation.
