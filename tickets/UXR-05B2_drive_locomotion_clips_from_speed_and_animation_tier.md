# UXR-05B2 - Drive locomotion clips from speed and animation tier

Status: Open

**Goal**

Map the existing motion-speed and animation-tier API to idle, walk, and run/jog state and playback without changing gameplay movement.

**Ownership boundary**

- `scripts/visual/characters/human_character_visual.gd`
- `scenes/visuals/characters/HumanCharacterVisual.tscn`
- `tests/test_character_visuals.gd`

**Non-goals**

- Do not edit animation assets, Player/Npc, movement speeds, collision, catalog, test runner, unrelated tests, `TICKETS.md`, or `AGENTS.md`.

**Acceptance criteria**

- Zero/near-zero speed selects idle, ordinary movement selects walk, and running speed selects `Jog_Fwd_Loop` at documented deterministic thresholds.
- Normal tier updates continuously, throttled/manual tier changes only through its explicit update API, and frozen tier holds idle without advancing locomotion.
- Reconfiguration and reset leave no stale clip, playback, or tier state.
- Missing animation/skeleton data degrades to state-only selection without crashes.

**Required tests**

- Verify threshold boundaries, exact selected clip, normal/throttled/frozen transitions, reset/reconfigure behavior, 250-instance resource sharing, focused visual suite, complete Docker suite, and `git diff --check`.

**Dependencies**

- UXR-05B1 must be completed and validated.

**Validation evidence**

- Pending.
