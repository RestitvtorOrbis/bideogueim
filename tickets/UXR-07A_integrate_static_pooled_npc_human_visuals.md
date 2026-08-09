# UXR-07A - Integrate static pooled NPC human visuals

Status: Open

**Goal**

Replace visible NPC primitives with validated shared human wrappers and deterministic pooled visual state, without animation or population-behavior changes.

**Ownership boundary**

- `scenes/Npc.tscn`
- `scripts/npc/npc.gd`
- New `scripts/visual/npc_visuals.gd`
- NPC visual/pooling assertions in `tests/test_population.gd`

**Non-goals**

- Do not load/play animations, implement animation tiers or speed-to-clip mapping, inspect the locomotion GLB, change yaw/movement behavior, edit population management, alter combat/safety, change pooling allocation strategy, render hairstyle/eyebrow scenes, or claim UXR-07 complete.

**Acceptance criteria**

- Each NPC owns exactly one `HumanCharacterVisual`, configured deterministically from role plus lifecycle identifier using both adult body bases, role palette, and metadata-only accessory selection.
- Civilian visual height is deterministic in 1.68-1.86 meters; hostile height is deterministically 1.78 or 1.86 meters.
- Pool activation/reuse reconfigures the visual and pool release clears role/lifecycle visual state without allocating per-NPC materials.
- Shared palette Resource identity holds across 250 logical NPC configurations.
- The existing 1.75-meter/radius-0.35 collision capsule, hostile warning marker, equipped prop behavior, and all UXR-03 safety contracts remain unchanged.

**Required tests**

- Test deterministic role/lifecycle body, height, palette, and accessory metadata; 250-instance shared material identity; checkout/release/reuse reset; unchanged collision/marker/prop; and all UXR-03 grace/safety regressions.
- Run the complete Docker suite and `git diff --check`.

**Dependencies**

- UXR-03 and UXR-05A must be completed and validated.

**Validation evidence**

- **Status: PENDING (unresolved in the single beta implementation round).**
- Reproduction: dispatch the bounded Luna xhigh UXR-07A implementation against the four-file ownership boundary; the agent connector did not execute repository actions and eventually closed without a patch.
- Impact: NPC primitives remain in place and no static human/pooling integration gate can be claimed.
- Evidence collected: none of `scenes/Npc.tscn`, `scripts/npc/npc.gd`, `scripts/visual/npc_visuals.gd`, or the scoped population assertions changed during the round; no UXR-07A tests ran.
- Suspected scope remains the four files listed above. Do not start a replacement agent round without explicit authorization to override the repository beta one-round rule.
