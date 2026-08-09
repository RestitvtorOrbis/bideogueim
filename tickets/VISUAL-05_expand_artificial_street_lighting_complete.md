# VISUAL-05 - Expand artificial street lighting

## Requested outcome

Add more artificial light throughout the city while preserving the midnight-black sky and zero non-artificial environment/key/fill contribution.

## Context

- The district currently has exactly eight broad neon `OmniLight3D` sources and 24 deterministic amber street-lamp `OmniLight3D` sources.
- Street lamps currently use energy `2.6`, range `22.0`, no shadows, and follow selected bendable lamp glow transforms.
- The current environment background/fog are black and ambient plus both directional lights have zero energy. Those midnight values must remain unchanged.

## Goal

Increase local artificial illumination coverage by expanding the bounded street-lamp light set and modestly increasing each lamp's strength/range, without reintroducing sky light or changing neon behavior.

## Ownership boundary

- `scripts/world/district.gd`
- this ticket file is owned by Sol; Luna must not edit it

## Implementation scope

- Increase `STREET_LAMP_LIGHT_COUNT` from `24` to exactly `48`.
- Increase `STREET_LAMP_LIGHT_RANGE` from `22.0` to exactly `30.0` metres.
- Increase `STREET_LAMP_LIGHT_ENERGY` from `2.6` to exactly `3.2`.
- Preserve deterministic even selection from generated lamp transforms, amber color `#ffb35c`, no shadows, lamp-bending transform synchronization, metadata, and bounded node construction.
- Preserve all neon constants/placement/type and all `District.tscn` environment/directional values unchanged.

## Non-goals

- Do not modify `District.tscn`, ambient/sky/fog/directional lighting, neons, lamp geometry/damage, city layout, NPCs, population, tests, or export tooling.
- Do not add per-window lights, shadows, flicker, or unbounded light creation.

## Acceptance criteria

- The default district constructs up to exactly 48 evenly distributed amber street-lamp lights when at least 48 lamp glows exist.
- Every selected street light has energy `3.2`, range `30.0`, color `#ffb35c`, and shadows disabled.
- Registered lights still follow their matching bendable lamp glow transform.
- Midnight sky/environment and all eight neon lights remain unchanged.

## Required minimum validation

- Run `git diff --check` and targeted source inspection for the three exact constants and ownership boundary.
- Run the pinned headless `Main.tscn` startup for a bounded 300 frames to establish that the expanded bounded light set constructs without startup/resource errors.
- Do not run the stale full city-generation suite; its unrelated historical sky/neon assertions are already tracked separately.

## Dependencies and handoff

- Independent of BUG-01 and owns disjoint files, so it may run in parallel.
- Luna must report changed files, exact validation commands/results, limitations, and deferred decisions.
- Sol alone records final evidence, renames to `_complete`, and creates the dedicated atomic ticket commit after accepting all criteria.

## Sol validation and acceptance

Accepted on 2026-08-09 after Luna xhigh round `019fe7b6-447d-7270-94d8-30312583e678`.

- Sol inspected the complete diff and confirmed the implementation changes only the three bounded street-lamp constants in `scripts/world/district.gd` plus this ticket.
- Street-lamp light count is exactly `48`, range `30.0`, and energy `3.2`; deterministic selection, amber color, disabled shadows, bend synchronization, and metadata code remain unchanged.
- Neon constants and `District.tscn` are untouched, preserving the midnight-black/zero-sky-light contract.
- `docker compose run --rm godot-tools --headless --path /workspace --scene res://scenes/Main.tscn --quit-after 300` exited `0` with no startup or resource errors.
- `git diff --check` exited `0` with only normal LF/CRLF conversion warnings.
- The stale city-generation suite was not run, as required. User-owned untracked files remain untouched.

All acceptance criteria and required minimum validation passed. VISUAL-05 is accepted for its dedicated atomic commit.
