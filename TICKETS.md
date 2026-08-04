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
