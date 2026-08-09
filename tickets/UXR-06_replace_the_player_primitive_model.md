# UXR-06 - Replace the player primitive model

Status: Open

**Goal**

Replace the current primitive player visuals with the Superhero Male human model from the free Standard archive while preserving all player gameplay contracts.

**Ownership boundary**

- `scenes/Player.tscn`
- `scripts/visual/player_visuals.gd`
- Player-focused assertions in `tests/test_system_contracts.gd`

**Non-goals**

- Do not change movement, health, input, interaction radius, or collision shape.

**Acceptance criteria**

- The human visual is exactly 1.82 meters tall, has feet at the player root, and faces negative Z.
- No previous capsule, armor box, sphere, visor, boot, or shoulder primitive remains visible.
- The player uses one shared dark teal palette and a deterministic hairstyle.
- Idle, walk, and run/jog respond to actual movement speed.
- `VisualRoot` cooperates with camera obstruction handling and becomes hidden while driving.
- The existing 1.8-meter player capsule remains the gameplay collision authority.

**Required tests**

- Verify visual hierarchy, AABB, orientation, and unchanged collision contract.
- Run player movement and vehicle entry/exit regressions.
- Verify the close-camera visibility behavior with the imported model.

**Dependencies**

- UXR-04 and UXR-05 must be completed and validated.

**Validation evidence**

- Pending.
