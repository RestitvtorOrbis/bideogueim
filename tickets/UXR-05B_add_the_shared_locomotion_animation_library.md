# UXR-05B - Add the shared locomotion animation library

Status: Open

**Goal**

Integrate the trimmed locomotion GLB into the UXR-05A wrapper and map movement speed and animation tiers to shared idle, walk, and run/jog playback.

**Ownership boundary**

- UXR-05A files under `scripts/visual/characters/**`
- UXR-05A files under `scenes/visuals/characters/**`
- `tests/test_character_visuals.gd`

**Non-goals**

- Do not edit the asset GLB, Player, Npc, gameplay, catalog contents, test runner, `TICKETS.md`, or `AGENTS.md`.

**Acceptance criteria**

- Idle maps to zero/near-zero speed, walk to normal movement, and `Jog_Fwd_Loop` to running speed.
- The animation library and clips are shared resources rather than per-instance duplicates.
- Animation tier API supports normal, throttled/manual, and frozen-idle behavior for later NPC integration.
- Missing animation or skeleton paths fail gracefully without breaking scene instantiation.

**Required tests**

- Run the focused character visual suite and complete Docker suite.
- Verify exact clip names, speed mapping, shared animation Resource identities, tier transitions, and 250 logical instances.

**Dependencies**

- UXR-05A must be completed and validated.

**Validation evidence**

- Pending.
