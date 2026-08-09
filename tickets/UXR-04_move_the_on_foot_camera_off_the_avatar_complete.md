# UXR-04 - Move the on-foot camera off the avatar

Status: Complete

**Goal**

Provide an unobstructed over-the-shoulder camera and hide only the player visual when collision compression places the camera too close.

**Ownership boundary**

- `scripts/player/third_person_camera.gd`
- `scripts/player/player_controller.gd`
- `scenes/Player.tscn`
- `tests/test_player_movement.gd`

**Non-goals**

- Do not replace the player model in this ticket.
- Do not change movement speeds, input bindings, collision dimensions, or vehicle camera behavior.

**Acceptance criteria**

- On-foot camera settings are follow height 1.70, SpringArm local X offset 0.75, spring length 6.5, initial pitch -0.20 radians, and FOV 72 degrees.
- SpringArm collision continues to query only world geometry.
- `VisualRoot` hides below 1.35 meters of actual camera distance and reappears above 1.65 meters.
- Entering and exiting the vehicle leaves the avatar and active camera in the correct state.
- Camera-relative movement and independent orbit remain unchanged.

**Required tests**

- Test both visibility thresholds and hysteresis.
- Run existing player movement tests.
- Test on-foot to vehicle and vehicle to on-foot camera transitions.

**Dependencies**

- None.

**Validation evidence**

- Decision-owner review confirmed the exact camera values, world-only SpringArm mask, VisualRoot hierarchy, distance hysteresis, and preserved vehicle state within the four-file boundary.
- Godot import, Player scene smoke execution, and camera/controller checks passed.
- The integrated Docker suite passed 194/194 assertions after the focused UXR-04A fixture correction.
- `git diff --check` passed with line-ending warnings only.
