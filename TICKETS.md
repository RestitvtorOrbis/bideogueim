# Urban Drive Prototype — Implementation Tickets

## Language Policy

All repository files, source code, identifiers, comments, documentation, commit messages, issue titles, ticket descriptions, UI copy, and asset manifests **must be written in English**. This applies even when product discussions with the project owner are in another language.

Add every future implementation ticket to this file in English. Keep each ticket independently implementable, narrowly scoped, and supplied with explicit acceptance criteria.

## Working Rules

- Engine: Godot `4.7.1`.
- Target: Windows desktop, single-player, keyboard/mouse and gamepad.
- Language: GDScript.
- Renderer: Forward+.
- Do not add gameplay systems outside the tickets without creating a new ticket first.
- Use only original placeholder assets or assets documented as CC0 in `ASSET_MANIFEST.md`.
- Target performance: 250 visible NPCs and at least 30 FPS at 1080p on the reference PC (Ryzen 5 3600, GTX 1660, 16 GB RAM).

## Backlog

### Foundation

#### [x] T-001 — Create the Godot project shell

Create a Godot 4.7.1 project with a `Main.tscn` startup scene and a 3D Forward+ renderer configuration.

**Acceptance criteria**

- Opening `project.godot` in Godot 4.7.1 succeeds without upgrade prompts.
- Running the project opens `Main.tscn` without errors.
- The project window is titled `Urban Drive Prototype`.

#### [x] T-002 — Create the source directory convention

Create the directories `scenes`, `scripts`, `resources`, `assets`, `tests`, `tools`, and `docs`, each with an English `.gitkeep` or README where otherwise empty.

**Acceptance criteria**

- Every directory exists in version control.
- No gameplay script is stored at the repository root.

#### [x] T-003 — Add repository ignore rules

Add a `.gitignore` for Godot imports, local editor data, export outputs, test reports, and Docker caches.

**Acceptance criteria**

- `.godot/`, `.import/`, `exports/`, `reports/`, and `.docker-cache/` are ignored.
- Project source, scenes, resources, tests, and Docker configuration are not ignored.

#### [x] T-004 — Define project input actions

Add named input actions for walking, looking, entering/exiting a vehicle, accelerating, braking/reversing, steering, handbrake, resetting the vehicle, and toggling the gore preset.

**Acceptance criteria**

- Every action has keyboard bindings.
- Driving and walking actions have gamepad bindings where applicable.
- Scripts refer only to named actions, not hard-coded physical keys.

#### [x] T-005 — Add a minimal game state service

Implement an autoload named `GameState` that exposes `is_game_over`, `current_score`, `high_score`, and a `reset_run()` method.

**Acceptance criteria**

- A new run resets only run-specific state.
- `high_score` remains unchanged by `reset_run()`.
- The service has no direct UI dependencies.

### Configurable Data

#### [x] T-006 — Create `GameRules` resource

Create an editable `GameRules` resource that defines hostile score, civilian penalty, combo window, and panic threshold defaults.

**Acceptance criteria**

- Default hostile score is `100`.
- Default civilian penalty is `250`.
- Default panic threshold is two group impact events within six seconds.
- No score constants are duplicated in gameplay scripts.

#### [x] T-007 — Create `CrowdSettings` resource

Create an editable resource containing the active NPC cap, civilian target count, hostile target count, spawn distance, and full-AI distance.

**Acceptance criteria**

- Defaults are 250 total NPCs, 160 civilians, and 90 hostiles.
- All values can be changed in the Inspector.

#### [x] T-008 — Create `VehicleConfig` resource

Create an editable resource for mass, engine force, steering angle, brake force, suspension values, maximum health, and impact damage multiplier.

**Acceptance criteria**

- The vehicle controller reads all listed tuning values from this resource.
- The resource has usable defaults for an arcade driving prototype.

#### [x] T-009 — Create `ViolenceSettings` resource

Create an editable resource with three presets: `Full`, `Reduced`, and `Disabled`.

**Acceptance criteria**

- Each preset controls blood particles, decals, comic fragments, impact camera shake, and vocal impact audio.
- `Disabled` spawns no blood or body-fragment visuals.

#### [x] T-010 — Create `NpcProfile` resource

Create a resource that defines NPC role, health, walk speed, material palette, equipped prop scene, and score category.

**Acceptance criteria**

- Roles available are `Civilian` and `Hostile`.
- A hostile profile includes an armed visual prop and a warning marker configuration.
- A civilian profile has no weapon prop.

### World and Player

#### [x] T-011 — Build a compact playable district

Create a single open district scene with roads, sidewalks, building-block geometry, directional lighting, a ground plane, and a player spawn location.

**Acceptance criteria**

- The player can traverse the district without falling through the world.
- Roads and sidewalks have collision.
- The scene contains no external commercial assets.

#### [x] T-012 — Add off-screen population spawn zones

Place spawn zones around the district perimeter and tag them for civilian or hostile crowd spawning.

**Acceptance criteria**

- Spawn zones are outside the initial camera view.
- At least four zones exist for each role.

#### [x] T-013 — Implement the on-foot player controller

Create a `CharacterBody3D` controller with walk, sprint, gravity, jump, and mouse/gamepad camera look.

**Acceptance criteria**

- The player can move reliably across roads and sidewalks.
- Camera pitch is clamped to prevent a full vertical flip.
- Input is disabled after game over.

#### [x] T-014 — Add third-person follow camera

Implement a collision-aware third-person camera for the on-foot player.

**Acceptance criteria**

- The camera follows the player smoothly.
- World geometry does not fully obscure the player for more than one frame.

#### [x] T-015 — Create the player health component

Implement a reusable health component for the player with damage, death signal, and reset behavior.

**Acceptance criteria**

- Damage cannot reduce health below zero.
- Reaching zero emits a single death signal.
- The player health maximum is configurable.

### Vehicle

#### [x] T-016 — Create the arcade vehicle body

Create a vehicle scene based on `RigidBody3D` with a placeholder body mesh, collision shape, and four wheel attachment points.

**Acceptance criteria**

- The vehicle rests stably on a flat surface.
- Its collision body has no visible jitter at rest.

#### [x] T-017 — Implement raycast suspension

Add one raycast-based suspension solver per wheel attachment point.

**Acceptance criteria**

- The vehicle remains driveable over small curbs.
- Suspension force is applied only while a wheel ray hits the ground.

#### [x] T-018 — Implement arcade steering and propulsion

Implement acceleration, reverse, steering, braking, drag, and handbrake using `VehicleConfig` values.

**Acceptance criteria**

- The vehicle accelerates, stops, reverses, and turns with keyboard and gamepad.
- The vehicle cannot accelerate indefinitely past its configured maximum speed.

#### [x] T-019 — Add vehicle health and destruction

Give the vehicle configurable health and damage from collisions and hostile attacks.

**Acceptance criteria**

- Vehicle health is exposed through a signal or readable property.
- Destroying the vehicle ends the current run.

#### [x] T-020 — Add vehicle reset action

Implement a reset action that places the vehicle upright on the nearest valid road position.

**Acceptance criteria**

- Reset works when the vehicle is upside down.
- Reset does not move the vehicle outside the district.

#### [x] T-021 — Implement vehicle camera mode

Create a third-person vehicle camera with speed-sensitive following distance and collision handling.

**Acceptance criteria**

- Entering a vehicle switches to this camera.
- Exiting restores the on-foot camera.

#### [x] T-022 — Implement entering and exiting the vehicle

Allow the on-foot player to enter the nearest unoccupied vehicle and exit it at a valid side position.

**Acceptance criteria**

- Entry only works inside an interaction radius.
- The player cannot control the vehicle while on foot.
- The player cannot exit into blocking geometry.

### NPCs and Crowd Simulation

#### [x] T-023 — Create the base NPC scene

Create an NPC scene with root collision, low-poly placeholder mesh, navigation agent, role marker anchor, and state-machine script.

**Acceptance criteria**

- One civilian and one hostile profile can be assigned in the Inspector.
- The scene can be instantiated without runtime errors.

#### [x] T-024 — Implement NPC wandering

Implement a low-cost wandering state that selects valid nearby navigation targets.

**Acceptance criteria**

- NPCs move on the navigation area without repeatedly selecting invalid targets.
- An NPC changes target after reaching its current target.

#### [x] T-025 — Implement hostile engagement

Implement hostile detection of the player and an `engage` state that approaches the player and applies periodic damage at range.

**Acceptance criteria**

- Civilians never enter `engage`.
- A hostile in range can damage the player or occupied vehicle.
- Attack rate and range are configurable.

#### [x] T-026 — Implement hostile group membership

Assign every hostile a group identifier when spawned and provide a group service that tracks recent hostile impact events.

**Acceptance criteria**

- Each hostile belongs to exactly one group.
- Group impact history expires after the configured six-second window.

#### [x] T-027 — Implement group panic

Transition surviving members of a hostile group to `panic` after the configured number of qualifying impact events.

**Acceptance criteria**

- Default behavior triggers after two impacts in six seconds.
- Civilians do not use hostile group panic.

#### [x] T-028 — Implement hostile fleeing

Implement `flee` behavior that moves panicked hostiles away from the player and avoids re-entering engagement while panic is active.

**Acceptance criteria**

- A panicked hostile visibly increases distance from the player.
- A fleeing hostile does not deal attack damage.

#### [x] T-029 — Add clear hostile identification

Give hostiles an armed prop, distinct outfit palette, and visible warning marker.

**Acceptance criteria**

- The marker is visible at typical driving distance.
- Identification does not depend on skin tone or other protected traits.

#### [x] T-030 — Implement NPC pooling

Create an NPC pool that reuses civilian and hostile instances instead of destroying and recreating them during normal population turnover.

**Acceptance criteria**

- Returning an NPC clears state, velocity, navigation target, group membership, and visual effects.
- Population management does not call `queue_free()` during ordinary despawn/reuse.

#### [x] T-031 — Implement distance-based NPC updates

Update near NPCs every frame, mid-range NPCs on a staggered interval, and far NPCs with simplified movement.

**Acceptance criteria**

- Full AI distance is configurable through `CrowdSettings`.
- Far NPCs do not run hostile attack checks.

#### [x] T-032 — Implement continuous population management

Spawn and recycle NPCs from off-screen zones to maintain the configured civilian and hostile targets.

**Acceptance criteria**

- Active NPC count does not exceed the configured cap.
- NPCs are not spawned inside the active camera frustum.
- The target population is restored after NPC removal.

### Impact, Score, and Effects

#### [x] T-033 — Define the impact event contract

Create an `ImpactEvent` data object with NPC ID, NPC role, source, speed, impulse, and timestamp.

**Acceptance criteria**

- Vehicle-to-NPC impacts emit exactly one qualifying event per NPC impact.
- The event has no UI references.

#### [x] T-034 — Implement the score manager

Create an autoload `ScoreManager` that receives `ImpactEvent` objects and is the only component allowed to change score.

**Acceptance criteria**

- A hostile impact adds 100 points by default.
- A civilian impact subtracts 250 points by default.
- Score changes emit a signal containing the delta and resulting total.

#### [x] T-035 — Implement hostile-only combos

Add a combo multiplier for qualifying hostile impacts inside the configurable combo window.

**Acceptance criteria**

- Consecutive qualifying hostile impacts increase the multiplier.
- A civilian impact or expired window resets the multiplier.
- The combo never multiplies civilian penalties.

#### [x] T-036 — Implement impact eligibility protection

Ensure an NPC can only score once per life cycle and is ignored after becoming `disabled`.

**Acceptance criteria**

- Repeated collision frames do not award repeated points.
- Reused pooled NPCs become score-eligible only after full reset.

#### [x] T-037 — Add comic impact particles

Create pooled particle effects for high-speed impacts, controlled by `ViolenceSettings`.

**Acceptance criteria**

- `Full` shows the complete effect.
- `Reduced` shows a lower-density effect.
- `Disabled` shows no gore particles.

#### [x] T-038 — Add comic decals and fragments

Create pooled ground decals and exaggerated comic fragments for impact effects.

**Acceptance criteria**

- Effects respect the selected gore preset.
- Active decals and fragments have hard pool limits.

#### [x] T-039 — Add impact audio

Add pooled placeholder CC0 impact and vocal reaction audio with distance attenuation.

**Acceptance criteria**

- Audio is not played when the preset is `Disabled`.
- The asset manifest records every included audio asset.

#### [x] T-040 — Add impact camera shake

Apply speed-scaled camera shake on qualifying vehicle impacts.

**Acceptance criteria**

- Low-speed contacts produce no or minimal shake.
- `Disabled` gore preset suppresses impact shake.

### UI, Persistence, and Game Flow

#### [x] T-041 — Create the gameplay HUD

Create a HUD showing score, high score, combo, player health, vehicle health, and the active gore preset.

**Acceptance criteria**

- HUD updates from service signals rather than polling scene nodes.
- Civilian penalties are visually distinct from positive score changes.

#### [x] T-042 — Add score feedback popups

Show a pooled world-space or screen-space popup for each score change.

**Acceptance criteria**

- Positive and negative deltas are visually distinct.
- Popups expire and return to their pool.

#### [x] T-043 — Persist the high score

Save and load the high score using `user://` storage.

**Acceptance criteria**

- A new high score persists after restarting the game.
- Missing or malformed save data safely falls back to zero.

#### [x] T-044 — Implement the game-over screen

Show a game-over screen when the player or vehicle reaches zero health.

**Acceptance criteria**

- Gameplay input is disabled on game over.
- The screen shows final score and high score.
- Restart creates a fresh world population and resets the run score and combo.

#### [x] T-045 — Add gore preset controls

Expose the three gore presets through a pause/settings menu and the configured toggle action.

**Acceptance criteria**

- Changing the preset applies immediately to subsequent effects.
- The choice persists for the next launch.

### Assets and Documentation

#### [x] T-046 — Add asset manifest

Create `ASSET_MANIFEST.md` documenting every non-original asset with name, source URL, author, license, modification notes, and local path.

**Acceptance criteria**

- All externally sourced assets are documented.
- The file states that only CC0 assets are allowed in this prototype.

#### [x] T-047 — Add placeholder asset attribution

Document all project-created placeholder meshes, materials, particles, and sounds as original temporary assets.

**Acceptance criteria**

- Every placeholder asset used by the project is traceable in the manifest.

#### [x] T-048 — Write the local development README

Create `README.md` with Windows editor setup, Godot version, controls, project layout, and test commands.

**Acceptance criteria**

- The README is entirely in English.
- It tells contributors to use Godot 4.7.1 exactly.

### Docker and Automation

#### [x] T-049 — Create the Godot tools Dockerfile

Create a Dockerfile that pins Godot 4.7.1 headless with export templates and runs as a non-root user.

**Acceptance criteria**

- The image can import the project headlessly.
- The container user is not root.
- The Godot version is asserted by the image build or entrypoint.

#### [x] T-050 — Create isolated Docker Compose configuration

Create Compose configuration for headless tooling with dropped capabilities, `no-new-privileges`, resource limits, named caches, and no runtime network.

**Acceptance criteria**

- The project directory, import cache, and export directory are the only mounts.
- Normal test/export services use `network_mode: none`.
- The configuration does not use privileged mode.

#### [x] T-051 — Add Docker build script

Create `tools/build.ps1` to build the pinned tools image.

**Acceptance criteria**

- The script fails clearly when Docker Desktop is unavailable.
- The script contains no administrator-elevation command.

#### [x] T-052 — Add Docker test script

Create `tools/test.ps1` to run the test suite inside the isolated container.

**Acceptance criteria**

- The command uses the Compose test service.
- A failing test returns a non-zero PowerShell exit code.

#### [x] T-053 — Add Docker benchmark script

Create `tools/benchmark.ps1` to run the crowd benchmark scene in the isolated container and save a report.

**Acceptance criteria**

- The report is written under `reports/`.
- The command returns non-zero when the configured performance threshold fails.

#### [x] T-054 — Add Docker export script

Create `tools/export.ps1` to create a Windows export in `exports/windows/` from the isolated container.

**Acceptance criteria**

- The output includes a Windows executable and required data files.
- The script fails clearly when export templates or export presets are missing.

### Tests and Benchmarking

#### [x] T-055 — Add a headless test runner

Create a dependency-free GDScript test runner that executes registered unit tests with `--headless` and produces a machine-readable report.

**Acceptance criteria**

- Passing tests return exit code zero.
- Failing assertions return a non-zero exit code.
- The report is written under `reports/`.

#### [x] T-056 — Test score rules

Write tests for hostile scoring, civilian penalty, and the rule that `ScoreManager` is the sole score mutator.

**Acceptance criteria**

- Tests verify default `+100` and `-250` outcomes.
- Tests verify no duplicate score from a disabled NPC.

#### [x] T-057 — Test combo rules

Write tests for combo increase, timeout reset, and civilian-impact reset.

**Acceptance criteria**

- Tests cover impacts inside and outside the configured combo window.
- Tests verify that penalties are never multiplied.

#### [x] T-058 — Test hostile panic rules

Write tests for group impact history expiry and transition to panic after two impacts in six seconds.

**Acceptance criteria**

- Tests cover threshold reached, threshold not reached, and expired impact history.

#### [x] T-059 — Test high score persistence

Write tests for saving, loading, and malformed high-score data handling.

**Acceptance criteria**

- Valid data is restored.
- Malformed data results in a safe zero value.

#### [x] T-060 — Create the 250-NPC benchmark scene

Create a headless benchmark scene that maintains 250 NPCs for ten minutes and records frame time, average FPS, peak memory, and pool allocations.

**Acceptance criteria**

- The scene runs without manual input.
- It writes a report suitable for `tools/benchmark.ps1`.
- It fails when average FPS is below 30 or memory grows continuously.

## Suggested Implementation Order

Implement tickets in numerical order unless an explicit dependency requires a small adjustment. Do not start a ticket until all referenced configuration, component, or scene tickets are complete.

## Active Orchestration: Human Characters and Safe Game Start

Status rule: every ticket remains unchecked until the decision-owning Sol orchestrator has inspected the implementation and recorded successful validation evidence. All implementation tickets are assigned to GPT-5.6 Luna with `reasoning_effort: xhigh`.

### [x] UXR-01 - Import the minimum CC0 character assets

**Goal**

Import the two adult Superhero Male/Female character models available in the free Standard archive, its six compatible hairstyles and two eyebrow accessories, and only the idle, walk, and run/jog animations needed by the game from the Quaternius Universal Base Characters Standard pack and Universal Animation Library.

**Ownership boundary**

- `assets/characters/quaternius/**`
- `ASSET_MANIFEST.md`

**Non-goals**

- Do not integrate the assets into Player or Npc scenes.
- Do not retain downloaded ZIP archives, FBX, OBJ, Blend sources, unavailable paid Regular models, teen models, or unused animations.
- Do not modify gameplay code.

**Acceptance criteria**

- The retained assets are limited to the free Superhero Male and Superhero Female bases, six low-cost non-clipping hairstyles, two eyebrow accessories, idle, walk, run/jog, and their referenced buffers and textures.
- Every retained model imports as glTF or GLB without missing dependencies in Godot 4.7.1.
- `ASSET_MANIFEST.md` records the canonical source URL, author, CC0 license, retrieval date, archive size, archive SHA-256, retained files, and modification notes.
- No downloaded archive or unused alternate format remains in the repository.

**Required tests**

- Run a clean headless Godot import.
- Inspect each retained model and animation for missing resources.
- Record the retained asset payload size and verify that all retained files are referenced.

**Dependencies**

- None.

**Validation evidence**

- The free Standard archive was inspected and found to contain only the Superhero Male/Female adult bases. After a required advisor consultation, the decision owner selected those two verified CC0 bases instead of purchasing the unavailable Regular models.
- Godot 4.7.1 headless import completed with exit code 0 and no import errors.
- The retained source audit found 39 files totaling 49,566,909 bytes: 10 BIN, 10 glTF, 1 GLB, and 18 PNG; all glTF dependencies resolve and no ZIP, FBX, OBJ, Blend, teen, or paid Regular asset remains.
- The trimmed animation GLB contains exactly `Idle_Loop`, `Walk_Loop`, and `Jog_Fwd_Loop` and has no external URI, mesh, material, or image payload.
- Decision-owner review confirmed that `ASSET_MANIFEST.md` records canonical sources, CC0, retrieval date, exact archive sizes and SHA-256 values, retained inventory, and modifications.

### [x] UXR-02 - Spawn the vehicle directly in front of the player

**Goal**

Place the vehicle exactly 3.25 meters in front of the initial player position so the player can enter it immediately with E.

**Ownership boundary**

- `scripts/world/city_layout.gd`
- `tests/test_city_generation.gd`

**Non-goals**

- Do not change vehicle physics, visuals, controls, or the four-meter interaction radius.

**Acceptance criteria**

- `vehicle_spawn` equals `player_spawn + Vector3.FORWARD * 3.25`.
- With default city settings the exact vehicle position is `Vector3(0.0, 1.25, -3.25)` and its rotation remains zero.
- The player and vehicle collision shapes do not overlap initially.
- Pressing E on the first playable frame successfully enters the vehicle.

**Required tests**

- Verify deterministic layout generation and the exact relative spawn vector.
- Instantiate Player and ArcadeVehicle at their initial positions and verify `try_enter()` succeeds without moving the player.

**Dependencies**

- None.

**Validation evidence**

- Decision-owner review confirmed that the implementation stayed within the two-file ownership boundary and uses the exact `player_spawn + Vector3.FORWARD * 3.25` contract.
- `docker compose run --rm test` passed 96/96 tests, including exact spawn, determinism, non-overlap, and first-frame vehicle entry assertions.
- `git diff --check -- scripts/world/city_layout.gd tests/test_city_generation.gd` passed.

### [x] UXR-03 - Add initial hostile safety

**Goal**

Prevent hostile NPCs from spawning dangerously close or damaging the player immediately after a run begins.

**Ownership boundary**

- `scripts/resources/crowd_settings.gd`
- `resources/default_crowd_settings.tres`
- `resources/default_hostile_profile.tres`
- `scripts/npc/population_manager.gd`
- `scripts/npc/npc.gd`
- `tests/test_population.gd`

**Non-goals**

- Do not change NPC models, animation, scoring, impact handling, or panic rules.

**Acceptance criteria**

- Initial civilians spawn at least 20 meters from the player.
- Initial hostiles spawn at least 35 meters from the player.
- Later hostile respawns occur at least 30 meters from the player.
- For 8.0 seconds after `PopulationManager.configure()`, hostiles cannot enter ENGAGE or deal damage.
- During the grace period, hostiles inside the 30-meter safe radius move outward and hostile wander targets cannot cross the safe radius.
- After the grace period, hostile combat resumes with engagement range 18.0, attack range 2.25, interval 1.25, and damage 8.0.

**Required tests**

- Use an injectable or directly controllable elapsed-time source; do not use real-time waits.
- Test behavior at 7.99 and 8.00 seconds.
- Verify zero damage and no ENGAGE during grace, valid attacks after grace, role-specific spawn distances, and correct behavior after pooled NPC reuse.

**Dependencies**

- None.

**Validation evidence**

- Decision-owner review confirmed role-specific spawn floors, the controlled 8.0-second boundary, safe-radius enforcement, post-grace melee tuning, and pooled-state reset within the recorded ownership boundary.
- The focused population assertions passed, including 7.99/8.00 seconds, zero grace damage, post-grace damage, role distances, safe wander targets, outward movement, and pool reuse.
- The integrated Docker suite passed 194/194 assertions after UXR-03A and UXR-04A.
- `git diff --check` passed with line-ending warnings only.

### [x] UXR-03A - Align the hostile system contract with melee range

**Goal**

Update the existing hostile damage contract test to exercise the validated 2.25-meter melee range instead of the obsolete four-meter assumption.

**Ownership boundary**

- Hostile engagement assertions in `tests/test_system_contracts.gd` only.

**Non-goals**

- Do not modify gameplay, profiles, scenes, unrelated system tests, `TICKETS.md`, or `AGENTS.md`.

**Acceptance criteria**

- The contract fixture places the hostile inside the configured 2.25-meter attack range.
- The test still verifies ENGAGE and exactly one damage application.
- The complete test suite passes with UXR-02, UXR-03, and UXR-04 present.

**Required tests**

- Run the complete Docker test suite and report the assertion count.
- Run `git diff --check` for `tests/test_system_contracts.gd`.

**Dependencies**

- UXR-03 implementation must be present.

**Validation evidence**

- Decision-owner review confirmed that only the hostile system fixture changed and now places the hostile at 1.5 meters, inside the 2.25-meter melee range.
- The fixture verifies ENGAGE, damage, and exactly one damage event.
- The integrated Docker suite passed 194/194 assertions; `git diff --check -- tests/test_system_contracts.gd` passed.

### [x] UXR-04 - Move the on-foot camera off the avatar

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

### [x] UXR-04A - Exercise vehicle camera transitions through the vehicle API

**Goal**

Correct the camera transition regression fixture so entry and exit use the public ArcadeVehicle workflow that owns vehicle-camera activation.

**Ownership boundary**

- `_test_vehicle_camera_transition` in `tests/test_player_movement.gd` only.

**Non-goals**

- Do not modify Player, ArcadeVehicle, camera scripts, scenes, unrelated tests, `TICKETS.md`, or `AGENTS.md`.

**Acceptance criteria**

- The fixture enters with `vehicle.try_enter(player)` and exits with `vehicle.exit_vehicle()`.
- It still verifies VisualRoot state, active cameras, and preservation of close-camera hidden state.
- The complete Docker test suite passes.

**Required tests**

- Run the complete Docker test suite and report its assertion count.
- Run `git diff --check` for `tests/test_player_movement.gd`.

**Dependencies**

- UXR-04 implementation must be present.

**Validation evidence**

- Decision-owner review confirmed the fixture now enters through `vehicle.try_enter(player)` and exits through `vehicle.exit_vehicle()` without production changes.
- Six transition assertions cover VisualRoot, both cameras, and close-camera hidden-state preservation.
- `docker compose run --rm test` passed 194/194 assertions; `git diff --check -- tests/test_player_movement.gd` passed.

### [ ] UXR-05 - Create the shared human-character visual component

**Goal**

Create a reusable visual component that normalizes character transforms, selects deterministic variants, shares materials, and drives the three retained locomotion animations.

**Ownership boundary**

- New files under `scripts/visual/characters/**`
- `scripts/resources/human_character_catalog.gd`
- `resources/human_character_catalog.tres`
- New files under `scenes/visuals/characters/**`
- A new focused character visual test suite
- `tests/test_runner.gd` only to register that suite

**Non-goals**

- Do not edit `scenes/Player.tscn`, `scenes/Npc.tscn`, or gameplay behavior.

**Acceptance criteria**

- Every model wrapper places the feet at local Y zero and faces local negative Z.
- Uniform scale derives from the imported AABB and reaches the requested target height.
- A source model facing positive Z receives a 180-degree wrapper yaw.
- Variant selection is deterministic for a supplied lifecycle identifier or seed.
- Materials and animation resources are cached and shared rather than duplicated per actor.
- The component supports idle, walk, and run/jog selection from movement speed.

**Required tests**

- Verify normalized AABB height, foot origin, and forward orientation.
- Verify deterministic variant selection.
- Verify that 250 logical instances reference shared material and animation resources.

**Dependencies**

- UXR-01 must be completed and validated.

**Validation evidence**

- Pending.

### [ ] UXR-05A - Build the shared body catalog and normalization wrapper

**Goal**

Implement the asset catalog, deterministic body/head-accessory selection, AABB normalization, shared material cache, and integration-facing API without animation playback.

**Ownership boundary**

- `scripts/resources/human_character_catalog.gd`
- `resources/human_character_catalog.tres`
- New files under `scripts/visual/characters/**`
- New files under `scenes/visuals/characters/**`
- New `tests/test_character_visuals.gd`
- `tests/test_runner.gd` only to register that suite

**Non-goals**

- Do not integrate locomotion animations yet.
- Do not edit Player, Npc, gameplay, assets, unrelated tests, `TICKETS.md`, or `AGENTS.md`.

**Acceptance criteria**

- The catalog exposes the two body bases, six hairstyles, two eyebrow accessories, and shared palette definitions.
- The wrapper places feet at local Y zero, faces local negative Z, and reaches a requested target height through uniform AABB-derived scale.
- Variant selection is deterministic from a supplied seed or lifecycle identifier.
- Materials are cached by variant and shared; 250 logical instances do not create per-instance material resources.
- The public API already exposes body, height, role palette, accessory variant, motion speed, animation tier, visibility tier, and right-hand attachment lookup needed by later tickets.

**Required tests**

- Run clean Godot import, the focused character visual suite, and the complete Docker suite.
- Verify AABB normalization, deterministic selection, shared Resource identities across 250 logical instances, and graceful missing-node handling.

**Dependencies**

- UXR-01 must be completed and validated.

**Validation evidence**

- Pending.

### [x] UXR-05A1 - Define the verified human asset catalog contract

**Goal**

Create the pure typed catalog contract that enumerates asset-path metadata, palette metadata, public locomotion clip names, and deterministic seed helpers without loading resources.

**Ownership boundary**

- `scripts/resources/human_character_catalog.gd`

**Non-goals**

- Do not create the `.tres` resource or tests in this ticket.
- Do not call `load`/`preload`, use `PackedScene`, instantiate models, normalize transforms, create materials/caches, or load/play animation resources.

**Acceptance criteria**

- The contract contains exactly two body paths, six hairstyle paths, and two eyebrow paths, each represented once.
- Stable seed and variant-index helpers are deterministic and handle empty arrays safely.
- Public clip identifiers are exactly `Idle_Loop`, `Walk_Loop`, and `Jog_Fwd_Loop`; this ticket stores identifiers only.
- The script parses in Godot 4.7.1 and contains none of `load(`, `preload(`, `PackedScene`, `StandardMaterial3D`, `AnimationPlayer`, or material-cache code.

**Required tests**

- Run clean Godot import/parse, a static forbidden-symbol audit, exact path/count audit, and `git diff --check`.

**Dependencies**

- UXR-01 must be completed and validated.

**Validation evidence**

- Decision-owner review confirmed the one-file ownership boundary and replacement of the prior out-of-scope partial implementation.
- Static audit found exactly 2 body paths, 6 hairstyle paths, 2 eyebrow paths, the three exact public clip identifiers, and zero forbidden runtime-loading/material/animation symbols.
- All ten listed asset paths exist; deterministic helpers handle non-positive counts safely.
- Godot 4.7.1 Docker import/parse completed with exit code 0; `git diff --check -- scripts/resources/human_character_catalog.gd` passed.

### [x] UXR-05A1B - Instantiate and test the default human catalog resource

**Goal**

Create the default catalog `.tres` and focused tests for the validated UXR-05A1 contract.

**Ownership boundary**

- `resources/human_character_catalog.tres`
- New `tests/test_character_catalog.gd`
- `tests/test_runner.gd` only to register that suite

**Non-goals**

- Do not edit the catalog script, wrapper files, models, materials, animation runtime, Player, Npc, or gameplay.

**Acceptance criteria**

- The resource records exactly the two verified body paths, six hairstyle paths, two eyebrow paths, shared role-palette metadata, and three public clip identifiers through the UXR-05A1 contract.
- Focused tests verify resource loading, exact counts/paths, deterministic seed/index behavior, safe empty-count handling, and exact public clip names.

**Required tests**

- Run clean import, focused catalog tests, complete Docker suite, and `git diff --check`.

**Dependencies**

- UXR-05A1 must be completed and validated.

**Validation evidence**

- Completed through validated microtickets UXR-05A1B1 and UXR-05A1B2.
- The default resource loads through the validated contract, 50 focused catalog assertions pass, and the complete Docker suite exits successfully.

### [x] UXR-05A1B1 - Create the default human catalog resource

**Goal**

Create the single default `.tres` instance of the validated HumanCharacterCatalog contract.

**Ownership boundary**

- `resources/human_character_catalog.tres`

**Non-goals**

- Do not edit scripts, tests, wrapper files, scenes, gameplay, or any other resource.

**Acceptance criteria**

- The resource uses `scripts/resources/human_character_catalog.gd` and loads with the contract's exact 2/6/2 paths, three clip identifiers, and civilian/hostile/player palette metadata.

**Required tests**

- Run a Godot 4.7.1 load/import smoke check and `git diff --check` for the resource.

**Dependencies**

- UXR-05A1 must be completed and validated.

**Validation evidence**

- Decision-owner review confirmed the one-file ownership boundary and that the `.tres` uses the validated HumanCharacterCatalog defaults without duplicating or overriding paths.
- Godot 4.7.1 Docker import/load smoke passed; all six default hairstyle paths exist.
- `git diff --check -- resources/human_character_catalog.tres` passed.

### [x] UXR-05A1B2 - Test and register the human catalog contract

**Goal**

Add focused catalog tests and register them in the dependency-free runner.

**Ownership boundary**

- New `tests/test_character_catalog.gd`
- `tests/test_runner.gd` only to register that suite

**Non-goals**

- Do not edit production scripts, resources, wrapper files, assets, scenes, or gameplay.

**Acceptance criteria**

- Tests cover resource loading, exact paths/counts/uniqueness, existing asset files, palette keys, exact clip names, deterministic seed/index behavior, salt behavior, and non-positive counts.

**Required tests**

- Run the focused catalog suite, complete Docker suite, and `git diff --check`.

**Dependencies**

- UXR-05A1B1 must be completed and validated.

**Validation evidence**

- Decision-owner review confirmed the two-file ownership boundary, exact six verified hairstyle expectations, all required catalog assertions, and preserved runner registration.
- The focused catalog suite passed 50 assertions; `docker compose run --rm test` passed.
- `git diff --check -- tests/test_character_catalog.gd tests/test_runner.gd` passed.

### [ ] UXR-05A2 - Implement the normalized human visual wrapper

**Goal**

Implement model/head-accessory instantiation, AABB normalization, deterministic shared palette materials, visibility tiers, and the integration-facing visual API on top of UXR-05A1.

**Ownership boundary**

- New files under `scripts/visual/characters/**`
- New files under `scenes/visuals/characters/**`
- New `tests/test_character_visuals.gd`
- `tests/test_runner.gd` only to register that suite

**Non-goals**

- Do not implement animation loading or playback.
- Do not edit the catalog, Player, Npc, gameplay, assets, or unrelated tests.

**Acceptance criteria**

- The wrapper reaches requested height via uniform AABB-derived scale, places feet at Y zero, and faces negative Z.
- Body, hairstyle, eyebrows, and shared palette selection are deterministic.
- Materials are cached and shared across 250 logical instances.
- Public API exposes motion-speed and animation-tier placeholders, visibility tier, and right-hand attachment lookup without requiring later redesign.
- Missing catalog/model/skeleton/accessory nodes fail gracefully.

**Required tests**

- Run clean import, focused visual tests, complete Docker suite, and `git diff --check`.
- Verify normalization and Resource identity across 250 logical instances.

**Dependencies**

- UXR-05A1 must be completed and validated.

**Validation evidence**

- Pending.

### [x] UXR-05A2A - Implement body instantiation and geometric normalization

**Goal**

Create the HumanCharacterVisual scene/script with only body loading, recursive visual AABB calculation, uniform target-height scale, foot-origin alignment, and negative-Z forward normalization.

**Ownership boundary**

- New `scripts/visual/characters/human_character_visual.gd`
- New `scenes/visuals/characters/HumanCharacterVisual.tscn`

**Non-goals**

- Do not add accessories, palette/material overrides, animation, visibility tiers, right-hand attachments, gameplay integration, or repository tests.

**Acceptance criteria**

- The scene loads either validated body path through a small explicit API.
- Recursive transformed AABB normalization reaches requested height, places the visual minimum Y at zero, uses uniform scale, and rotates a positive-Z source to face negative Z.
- Missing catalog/body/mesh data returns a clear failure without crashing.

**Required tests**

- Run clean Godot import and a temporary/non-repository smoke script for both body paths and requested heights 1.70 and 1.82.
- Run `git diff --check` for the two files.

**Dependencies**

- UXR-05A1B must be completed and validated.

**Validation evidence**

- Decision-owner review confirmed the exact two-file ownership boundary, deterministic body replacement, recursive transformed AABB merge, uniform scaling, foot-origin alignment, and negative-Z forward normalization.
- Godot 4.7.1 Docker import passed; temporary smoke checks passed for both body paths at target heights 1.70 and 1.82 with min Y zero and final forward negative Z.
- Invalid path/height/mesh paths fail without crashing; temporary artifacts were removed and `git diff --check` passed.

### [x] UXR-05A2B - Test geometric character normalization

**Goal**

Add persistent focused tests for the validated UXR-05A2A body wrapper and register them.

**Ownership boundary**

- New `tests/test_character_visuals.gd`
- `tests/test_runner.gd` only to register that suite

**Non-goals**

- Do not edit production files, assets, scenes, catalog, gameplay, or unrelated tests.

**Acceptance criteria**

- Tests cover both bodies, target heights 1.70/1.82, foot Y zero, uniform scale, negative-Z orientation, deterministic repeated configuration, and graceful invalid paths.

**Required tests**

- Run focused visual tests, complete Docker suite, and `git diff --check`.

**Dependencies**

- UXR-05A2A must be completed and validated.

**Validation evidence**

- Decision-owner review confirmed the two-file ownership boundary and persistent coverage for both verified bodies at 1.70/1.82 meters, foot origin, uniform scale, negative-Z forward, deterministic reconfiguration, root replacement, and invalid-input clearing.
- The focused character-visual suite passed 53/53 assertions; `docker compose run --rm --build test` passed 297/297 assertions with exit code 0.
- `git diff --check -- tests/test_character_visuals.gd tests/test_runner.gd` passed. Godot still reports the intentional nonexistent-resource negative fixture and shutdown cleanup warnings; UXR-08 retains responsibility for final leak/resource-lifetime validation.

### [ ] UXR-05A2C - Add deterministic accessories, shared palettes, and visual API

**Goal**

Extend the validated wrapper with deterministic hair/eyebrow selection, cached shared palette materials, visibility tiers, motion/animation-tier data setters, and right-hand bone lookup.

**Ownership boundary**

- `scripts/visual/characters/human_character_visual.gd`
- `scenes/visuals/characters/HumanCharacterVisual.tscn`
- `tests/test_character_visuals.gd`

**Non-goals**

- Do not load or play locomotion animations and do not integrate Player/Npc gameplay.

**Acceptance criteria**

- Seed/lifecycle selection is deterministic for body, six hairstyles, two eyebrows, and role palette.
- Palette materials are cached by variant and shared across 250 logical instances, never duplicated per actor.
- Visibility tier, motion speed, and animation tier APIs store/apply state without animation playback.
- Right-hand lookup resolves `hand_r` or fails gracefully.

**Required tests**

- Extend focused tests for determinism, shared Resource identity across 250 logical instances, tiers, state reset, and hand lookup; run complete Docker suite.

**Dependencies**

- UXR-05A2B must be completed and validated.

**Validation evidence**

- Pending.

### [ ] UXR-05B - Add the shared locomotion animation library

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

### [ ] UXR-05B1 - Load and share the trimmed locomotion resources

**Goal**

Load the retained locomotion GLB once, expose the exact three clips through the shared visual component, and prove that logical character instances reuse the same animation resources.

**Ownership boundary**

- `scripts/visual/characters/human_character_visual.gd`
- `scenes/visuals/characters/HumanCharacterVisual.tscn`
- `tests/test_character_visuals.gd`

**Non-goals**

- Do not select clips from movement speed, advance playback, retarget gameplay motion, or edit Player/Npc.
- Do not modify the GLB, catalog, test runner, unrelated tests, `TICKETS.md`, or `AGENTS.md`.

**Acceptance criteria**

- The component loads only `Idle_Loop`, `Walk_Loop`, and `Jog_Fwd_Loop` from `locomotion.glb` through a process-wide cache.
- Public lookup returns stable shared `Animation` Resource identities across 250 logical instances.
- Missing source, library, skeleton, or clip returns a defined failure without breaking scene instantiation or geometric/accessory state.
- No per-character duplicate animation library or clip Resource is created.

**Required tests**

- Verify exact clip names, shared Resource identity across 250 logical instances, missing-resource behavior, focused visual suite, complete Docker suite, and `git diff --check`.

**Dependencies**

- UXR-05A must be completed and validated.

**Validation evidence**

- Pending.

### [ ] UXR-05B2 - Drive locomotion clips from speed and animation tier

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

### [ ] UXR-06 - Replace the player primitive model

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

### [ ] UXR-07 - Replace NPC primitives and apply visual performance tiers

**Goal**

Use varied adult human models for civilians and hostiles while keeping 250 pooled NPCs within the project's performance target.

**Ownership boundary**

- `scenes/Npc.tscn`
- `scripts/npc/npc.gd`
- `scripts/npc/population_manager.gd`
- `scripts/visual/npc_visuals.gd`
- NPC and pooling-focused tests

**Non-goals**

- Do not alter the safety and combat decisions validated in UXR-03.
- Do not add teen models or additional animation libraries.

**Acceptance criteria**

- Civilians and hostiles both reuse the Superhero Male and Superhero Female bases; role-specific shared palettes, hairstyles, accessories, scale bands, and animation behavior provide differentiation.
- Civilian visual heights are deterministic between 1.68 and 1.86 meters; hostile visual heights are 1.78 or 1.86 meters.
- All NPCs use a common gameplay capsule 1.75 meters tall with radius 0.35 and center Y 0.875.
- NPC yaw interpolates toward movement direction.
- The hostile prop uses a right-hand `BoneAttachment3D`; the warning marker remains above the head.
- At 0-35 meters animations update normally; at 35-75 meters visual animation updates at no more than 10 Hz; at 75-100 meters the NPC is frozen in idle with hair and shadows disabled; beyond 100 meters its visual is hidden.
- NPC dynamic shadow casting is disabled.
- Role palettes and hairstyles use shared cached resources with no per-instance material duplication.
- Pool checkout and release reset all visual, animation, attachment, and tier state.

**Required tests**

- Test deterministic model, height, palette, and hairstyle distribution.
- Test movement orientation and each visual tier boundary.
- Test pooling reuse for civilians and hostiles.
- Re-run the UXR-03 hostile safety tests after integration.

**Dependencies**

- UXR-03 and UXR-05 must be completed and validated.

**Validation evidence**

- Pending.

### [ ] UXR-08 - Validate the integrated 250-NPC build

**Goal**

Validate functional integration, renderer performance, pooling, memory behavior, and asset size before release export.

**Ownership boundary**

- `scripts/benchmark/benchmark_scene.gd`
- `tests/test_runner.gd`
- `docs/ARCHITECTURE.md`
- Validation reports under `reports/**`

**Non-goals**

- Do not redesign or retune gameplay during validation.
- Do not make broad corrective changes. Create a focused follow-up ticket for any failed gate that requires implementation.

**Acceptance criteria**

- Godot 4.7.1 performs a clean import without errors.
- The complete automated test suite passes.
- The ten-minute headless benchmark maintains 250 NPCs, average FPS of at least 30, bounded pool allocations, and no continuous memory growth.
- A Forward+ visible benchmark with 250 NPCs meets the existing reference-PC renderer target.
- No unused character asset, archive, or duplicate source format remains.
- Manual verification confirms an unobstructed camera, visible nearby vehicle, immediate E entry, no initial hostile death, correct human models, and working NPC variation.

**Required tests**

- `godot --headless --path . --editor --import --quit`
- `godot --headless --path . --scene res://tests/TestRunner.tscn -- --report res://reports/test-results.json`
- `./tools/benchmark.ps1`
- A documented Forward+ rendered benchmark and manual startup checklist.

**Dependencies**

- UXR-02, UXR-06, and UXR-07 must be completed and validated.

**Validation evidence**

- Pending.

### [ ] UXR-09 - Export and smoke-test the Windows release

**Goal**

Produce the final Windows x86-64 release executable and its required PCK after every implementation and validation gate passes.

**Ownership boundary**

- `exports/windows/**`
- A release manifest under `reports/**`

**Non-goals**

- Do not modify source code, scenes, resources, tests, export presets, or build tooling during this ticket.
- Do not export before UXR-08 is completed and validated.

**Acceptance criteria**

- `./tools/export.ps1` completes successfully using the Godot 4.7.1 Windows Desktop release preset.
- `exports/windows/UrbanDrivePrototype.exe` and `exports/windows/UrbanDrivePrototype.pck` both exist and are non-empty.
- The executable launches successfully on Windows x86-64 and opens the configured Main scene without missing resources or import errors.
- A release smoke test confirms the camera, nearby vehicle, immediate E entry, hostile grace period, player model, and NPC models in the exported build.
- The release manifest records the build date, Godot version, file sizes, and SHA-256 values for both artifacts.

**Required tests**

- Run `./tools/export.ps1` and retain its exit result.
- Verify both artifacts and their hashes.
- Launch `UrbanDrivePrototype.exe` on Windows and complete the documented release smoke test.

**Dependencies**

- UXR-08 must be completed and validated.

**Validation evidence**

- Pending.

## UXR Execution Order

1. Run UXR-01, UXR-02, UXR-03, and UXR-04 in parallel only while their ownership boundaries remain disjoint.
2. Run UXR-05 after UXR-01.
3. Run UXR-06 after UXR-04 and UXR-05.
4. Run UXR-07 after UXR-03 and UXR-05. UXR-06 and UXR-07 may run in parallel because their write boundaries are disjoint.
5. Run UXR-08 only after UXR-02, UXR-06, and UXR-07 are validated.
6. Run UXR-09 only after UXR-08 is validated.
