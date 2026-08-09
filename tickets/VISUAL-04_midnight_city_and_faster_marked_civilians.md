# VISUAL-04 - Midnight city and faster marked civilians

## Requested outcome

Make the sky true midnight black so illumination comes only from artificial city sources. Double civilian movement speed and give civilians a blue role signal similar to the hostiles' red signal. The user explicitly instructed that this implementation must not be validated.

## Evidence and decisions

- `scenes/District.tscn` currently uses a dark blue background, nonzero ambient light, nonzero fog light, and two nonzero directional lights. Neons and street lamps are already local `OmniLight3D` artificial sources.
- `resources/default_civilian_profile.tres` has `walk_speed = 3.0`; the exact requested doubled value is therefore `6.0`.
- `resources/default_hostile_profile.tres` has `walk_speed = 3.4`, but the user supplied no hostile multiplier. Preserve hostile speed and state logic instead of inventing combat tuning.
- `scripts/npc/npc.gd` currently shows the shared `WarningMarker` only for hostile profiles. Civilian profiles already expose `warning_marker_enabled` and `warning_marker_color`, so the same signal can be reused by role.
- Midnight-black means background and fog light color exactly black, ambient energy zero, and both directional light energies zero. Preserve artificial neon and street-lamp lights unchanged.

## Goal

Produce a city whose environment contributes no visible sky/key/fill light, double the base civilian movement speed, and display a blue exclamation signal above civilians while preserving the red hostile signal.

## Ownership boundary

- `scenes/District.tscn`
- `resources/default_civilian_profile.tres`
- `scripts/npc/npc.gd`
- this ticket file remains owned by Sol and must not be edited by Luna

## Implementation scope

- Set `background_color` to `Color(0, 0, 0, 1)`.
- Set `ambient_light_energy` to `0.0`; preserve the ambient source/color fields because zero energy disables their contribution.
- Set `fog_light_color` to `Color(0, 0, 0, 1)` while preserving fog density/height settings.
- Set both district `DirectionalLight3D` node energies to `0.0`; preserve their colors, rotations, shadow flags, and shadow distance.
- Preserve neons, street lamps, glow, bloom, tonemapping, reflected-light setting, city geometry, and all other artificial sources unchanged.
- Change only the default civilian profile base `walk_speed` from `3.0` to exactly `6.0`. Existing state multipliers continue to derive from this doubled base.
- Enable the civilian warning marker and set its profile color to a vivid blue `Color(0.08, 0.42, 1.0, 1)`.
- Generalize shared marker visibility so any profile with `warning_marker_enabled` displays the existing `Label3D` exclamation and uses that profile's marker color. Hostiles remain enabled and red.

## Non-goals

- Do not change hostile speed, combat cadence, AI state logic, flee multipliers, population, animation playback, collisions, vehicle behavior, NPC models, marker geometry/text/size, neons, street lamps, or city layout.
- Do not remove environment or directional-light nodes; zero their non-artificial contribution.
- Do not add or edit automated tests.
- Do not run tests, static validation, diff validation, headless parse validation, gameplay validation, or visual validation for this implementation.

## Acceptance criteria (intentionally unverified)

- The rendered sky is black and environment/key/fill sources contribute zero light; city illumination comes from artificial local sources.
- Default civilians use base speed `6.0`, exactly twice the prior `3.0`; hostiles remain at `3.4`.
- Civilians display the same exclamation marker presentation in blue; hostiles retain the red marker.
- No behavior outside the ownership boundary changes.

## Required tests and validation

None authorized. Per the user's explicit instruction, neither Luna nor Sol may validate this implementation. The mandatory post-feature export/package workflow may generate the Windows artifacts but must not be treated as acceptance validation.

## Ticket status and handoff

This ticket must remain open after implementation because repository policy permits `_complete` only after Sol validates every acceptance criterion. Record the implementation commit and export/package commit here only in a future validation-authorized follow-up; do not rename this file in the current task.
