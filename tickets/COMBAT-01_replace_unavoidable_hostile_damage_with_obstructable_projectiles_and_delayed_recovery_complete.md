# COMBAT-01 - Replace unavoidable hostile damage with obstructable projectiles and delayed recovery

Status: Complete

**Goal**

Make hostile fire readable, avoidable, and survivable by replacing direct damage with visible world-colliding projectiles and by allowing the player and vehicle to recover after a sustained damage-free interval.

**Ownership boundary**

- `scripts/npc/npc.gd`
- `scripts/resources/npc_profile.gd`
- `resources/default_hostile_profile.tres`
- New hostile-projectile runtime files under `scripts/npc/` and `scenes/`
- `scenes/Npc.tscn`, limited to injecting the hostile projectile scene used by `scripts/npc/npc.gd`
- `scripts/components/health_component.gd`
- Player and vehicle health configuration in `scripts/player/player_controller.gd`, `scripts/vehicle/arcade_vehicle.gd`, `scenes/Player.tscn`, and `scenes/ArcadeVehicle.tscn`
- Directly scoped combat and health assertions in `tests/test_system_contracts.gd` and `tests/test_population.gd`
- `AGENTS.md`, limited to documenting the required `multi_agent_v1` launch path for GPT-5.6 Luna subagents

**Non-goals**

- Do not change NPC spawning, grace-period, panic, flee, pooling, navigation, character visuals, player weapons, vehicle physics, UI layout, or violence presets.
- Do not regenerate NPC health or revive dead actors.
- Do not add commercial or third-party assets.

**Acceptance criteria**

- Hostiles no longer apply damage directly from `npc.gd`; every ranged attack spawns a visible projectile that advances through the 3D world and applies damage only after a physical hit.
- Projectile motion uses swept collision so walls and other World-layer geometry stop it before it can damage a player or vehicle behind the obstruction; the shooter is excluded from its own collision query.
- Each projectile expires after at most 18 meters of travel, even if it hits nothing, and hostile firing remains limited to the configured 18-meter engagement/attack distance.
- Default hostile aim has a 14-degree spread and does not silently home after firing. Tests may inject zero spread or a deterministic direction to verify collision behavior.
- The default hostile shot deals 3 health damage with a 1.5-second attack interval. Its emissive tracer body, light/trail treatment, and short impact flash make the shot substantially more visually prominent than its damage value.
- Projectile impact resolves a damage receiver through `apply_damage`; an occupied player's existing `get_damage_target()` routing continues to put the vehicle at risk instead of the hidden driver.
- Player and vehicle health, and only those two uses of `HealthComponent`, regenerate 10 health per second after 60 continuous seconds without damage. Any positive damage restarts the full 60-second delay; regeneration clamps at maximum health and never revives a dead target.
- Existing initial hostile grace, safe-radius, panic/flee, pooling, game-over, and health signal contracts remain intact.

**Required tests**

- Add automated assertions for projectile finite range, swept world obstruction, target hit routing, low default damage, configured spread, and visible tracer/impact presentation nodes.
- Add automated assertions that player and vehicle regeneration begins only at 60 seconds, resets its delay after new damage, clamps to maximum, and remains disabled for NPC health.
- Update the UXR-03 combat assertions to validate projectile spawning/impact instead of immediate direct damage while preserving grace-boundary coverage.
- Run the complete Godot test suite, a headless project import, a bounded Main-scene smoke, and `git diff --check`.

**Dependencies**

- UXR-03 and UXR-03A are completed. Open visual/animation tickets are unrelated and must remain unchanged.

**Validation evidence**

- The implementation ran in the single authorized GPT-5.6 Luna xhigh local task `019fd2fa-a43f-7ab0-8fab-dfc708850d99` on host `local`; the decision owner inspected the complete diff and confirmed it stayed inside the recorded ownership boundary. `scenes/Npc.tscn` required no final change.
- Static review confirms `npc.gd` no longer applies attack damage directly: it spawns a non-homing projectile with immutable fired direction, 14-degree default spread, 18-meter hard cap, shooter RID exclusion, and swept collision mask `World | Player | Vehicle`.
- The projectile scene provides an emissive tracer mesh, light, particle trail, and 0.08-second impact flash; default hostile tuning is 3 damage at a 1.5-second interval.
- Player and vehicle health opt into 10 HP/s regeneration after 60 damage-free seconds. NPC regeneration remains disabled; new damage resets the delay, healing clamps at maximum, and dead health does not revive.
- `'/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe' compose run --rm --build test`: 1,649 assertions; 1,641 pass. The only eight failures are the pre-existing authorized UXR-05B1 locomotion allowlist (`Idle_Loop`, `Walk_Loop`, `Jog_Fwd_Loop`, cache-ready, three-clip cache, shared library, bounded 250-instance cache, and unsupported-clip cache invariance). Every COMBAT-01 assertion passes.
- Automated COMBAT-01 coverage passes for finite travel, swept wall obstruction, collision layers, low damage, spread configuration, tracer/impact presentation, direct and occupied-vehicle target routing, grace boundaries, regeneration threshold/reset/clamp/death behavior, and NPC regeneration opt-out.
- `docker.exe compose run --rm --build godot-tools --headless --path /workspace --editor --import --quit`: exit 0 under Godot 4.7.1 with no parse/import failure.
- `docker.exe compose run --rm --build godot-tools --headless --path /workspace --scene res://scenes/Main.tscn --quit-after 300`: exit 0. The pre-existing shutdown diagnostics remain two leaked ObjectDB instances and one Resource in use.
- `git diff --check`: exit 0. Luna-owned temporary files were removed and the new Godot script UID is retained with its source.
- Decision-owner result: ACCEPTED. Every COMBAT-01 acceptance criterion is validated; unrelated pending UXR tickets remain unchanged.
