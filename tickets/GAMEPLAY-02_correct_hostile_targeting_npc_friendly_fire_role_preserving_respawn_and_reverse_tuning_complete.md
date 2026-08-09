# GAMEPLAY-02 - Correct hostile targeting, NPC friendly fire, role-preserving respawn, and reverse tuning

Status: Complete

**Goal**

Make hostile fire track the player's current vulnerable body, visibly aim and recoil the weapon, produce a readable particle impact, collide with and damage intervening NPCs, restore dead NPCs as the same role at a distant off-screen location, and modestly improve vehicle reverse performance.

**Ownership boundary**

- `scripts/npc/npc.gd`
- `scripts/npc/hostile_projectile.gd`
- `scripts/npc/population_manager.gd`
- `scripts/resources/crowd_settings.gd`
- `resources/default_crowd_settings.tres`
- `scripts/vehicle/arcade_vehicle.gd`
- `scenes/Npc.tscn`
- `scenes/HostileProp.tscn`
- `scenes/HostileProjectile.tscn`
- Directly scoped assertions in `tests/test_system_contracts.gd`, `tests/test_population.gd`, and `tests/test_vehicle_physics.gd`
- This GAMEPLAY-02 record in `TICKETS.md`

**Non-goals**

- Do not change hostile damage, fire interval, engagement range, aim spread, player/vehicle regeneration, score rules, panic/flee behavior, population targets, general forward speed, visual character replacement, or gore-preset behavior.
- Do not add third-party assets or replace pooling with allocation-based respawning.
- Do not modify or complete UXR-09B or unrelated pending UXR tickets.

**Acceptance criteria**

- Hostiles resolve the current damage target before aiming: on foot they aim at the player's body; while the player occupies a vehicle they aim at the vehicle rather than the player's stale hidden position.
- The hostile weapon pivot visibly turns toward the resolved aim point while engaging, resets on pooling/deactivation, and performs a short recoil animation on each shot without changing projectile spread or homing after launch.
- Projectile impacts include a clearly visible one-shot particle burst in addition to the existing flash, and the projectile remains alive long enough for the burst to render before cleanup.
- Swept projectile collision includes the NPC physics layer. The first intervening civilian or hostile receives projectile damage through `apply_damage`, blocks the shot, and can die through its existing health/death lifecycle; the shooter remains excluded.
- After any NPC reaches the disabled/dead recycle state, population management restores the same role using the existing pool at least 30 horizontal meters from the player and outside the active camera frustum. A visible fallback is not accepted for death replacements.
- Holding brake/reverse while moving forward still brakes. Once reversing, the brake force no longer opposes reverse propulsion, producing a modestly faster reverse response while preserving the configured overall speed cap and forward tuning.
- Existing grace-period, finite-range, world obstruction, occupied-vehicle damage routing, pooling allocation, role target, and game-over contracts remain intact.

**Required tests**

- Add deterministic automated coverage for on-foot and occupied-vehicle aim targets, weapon aim/reset/recoil hooks, NPC collision-mask inclusion, NPC interception/damage/death, and particle impact lifetime.
- Add population coverage proving same-role pooled replacement, a 30-meter minimum horizontal distance, and strict off-screen placement after civilian and hostile death.
- Add vehicle coverage proving forward braking remains active, reverse propulsion is no longer counter-braked, reverse response increases, and maximum speed remains capped.
- Run the complete Godot test suite, a headless import, a bounded Main-scene smoke, and `git diff --check`.

**Dependencies**

- COMBAT-01 must remain completed and its validated projectile/regeneration behavior must be preserved.

**Validation evidence**

- The single coordinated GPT-5.6 Luna xhigh implementation round ran under agent `019fe485-8d19-7653-8fb0-ccd3982f3bc9`. Decision-owner review inspected the complete diff and confirmed that implementation stayed within the recorded ownership boundary; the worker did not edit this ticket, UXR-09B, or the pre-existing closed-beta ZIP.
- Static and automated review confirms hostile aim resolves `get_damage_target()` before firing, so on-foot shots use the player body and occupied shots use the vehicle's current position. The weapon pivot tracks that target, applies a 0.12-second recoil, and resets on deactivation, panic/flee, grace, and death paths.
- Hostile projectile collision now sweeps `World | Player | Vehicle | NPC` while excluding the shooter's RID. Civilian and hostile interceptors receive `apply_damage`, terminate the projectile on first hit, and enter the existing death lifecycle. Impacts emit a 24-particle one-shot burst and retain the projectile for 0.4 seconds so the effect can render.
- Death replacement is tracked separately from ordinary replenishment. Civilian and hostile deaths preserve their exact role, reuse their pool allocation, require at least 30 horizontal meters from the player, reject visible fallbacks, and retry in a later frame when no strict off-screen candidate is available.
- Vehicle review confirms brake/reverse still applies braking while forward speed exceeds 0.5, but no longer applies brake force while already reversing. Forward engine tuning and the configured overall maximum-speed clamp remain unchanged.
- `docker compose run --rm godot-tools --headless --path /workspace --script res://tests/test_population_runner.gd`: exit 0; every population assertion passes, including same-role pooled replacement, 30-meter floors, strict off-screen placement, and retry behavior.
- `docker compose run --rm test`: every GAMEPLAY-02 and COMBAT-01 assertion passes. Exit 1 is limited exactly to the eight pre-existing authorized UXR-05B1 locomotion failures: `Idle_Loop`, `Walk_Loop`, `Jog_Fwd_Loop`, cache-ready, three-clip cache, shared library, bounded 250-instance cache, and unsupported-clip cache invariance.
- `docker compose run --rm godot-tools --headless --path /workspace --editor --import --quit`: exit 0 under Godot 4.7.1 with no parse or import failure.
- `docker compose run --rm godot-tools --headless --path /workspace --scene res://scenes/Main.tscn --quit-after 300`: exit 0. The pre-existing shutdown diagnostics remain two leaked ObjectDB instances and one Resource in use.
- `git diff --check`: exit 0; only the repository's existing Windows LF-to-CRLF conversion warnings are emitted.
- Decision-owner result: ACCEPTED. Every GAMEPLAY-02 acceptance criterion and required regression contract is validated; unrelated pending UXR tickets remain unchanged.
