# UXR-06A - Integrate the static human player visual

Status: Open

**Goal**

Replace the visible Player primitives with the validated shared human wrapper while preserving every existing movement, collision, camera, and vehicle contract.

**Ownership boundary**

- `scenes/Player.tscn`
- New `scripts/visual/player_visuals.gd`
- Player-visual assertions in `tests/test_player_movement.gd`

**Non-goals**

- Do not implement animation, wire motion speed, inspect the locomotion GLB, or claim UXR-06 complete.
- Do not edit `player_controller.gd`, camera code, input, movement, collision dimensions, vehicle code, or render hairstyle/eyebrow scenes.

**Acceptance criteria**

- Exactly one `HumanCharacterVisual` is a descendant of the existing `VisualRoot`, configured with fixed deterministic player seed, player palette, and 1.82-meter target height.
- No prior capsule, armor box, sphere, visor, boot, or shoulder primitive remains visible.
- The existing Player collision capsule, `VisualRoot` identity, close-camera hysteresis, and vehicle hide/restore behavior are unchanged.
- The wrapper reports feet at local Y zero and negative-Z forward; accessories remain explicitly metadata-only.

**Required tests**

- Instantiate Player headlessly and verify hierarchy, target height/AABB/orientation, fixed variant/palette, absence of visible primitives, unchanged collision, camera visibility thresholds, and vehicle entry/exit regression.
- Run the complete Docker suite and `git diff --check`.

**Dependencies**

- UXR-04 and UXR-05A must be completed and validated.

**Validation evidence**

- **Status: PENDING because the required global gate is red outside the UXR-06A ownership boundary.**
- Luna implemented one 1.82-meter deterministic player-role `HumanCharacterVisual` under the existing `VisualRoot`, hid legacy primitives, preserved the collision capsule, and added focused hierarchy/AABB/orientation/palette/camera/vehicle assertions in the permitted three files.
- Decision-owner review found no UXR-06A assertion failure and `git diff --check` passed, but the integrated suite exits 1 with 1,612 passes and 8 failures caused by the delayed unaccepted UXR-05B1 locomotion patch. Keep UXR-06A open until the complete suite is green.
