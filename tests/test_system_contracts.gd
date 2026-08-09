extends RefCounted

var _npc_damage_events: int = 0

func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	_test_resources(results)
	_test_projectile_contracts(results)
	_test_health(results)
	_test_world_and_vehicle(results)
	_test_npc_states(results)
	_test_effects_and_ui(results)
	return results

func _test_resources(results: Array[Dictionary]) -> void:
	var rules := load("res://resources/default_game_rules.tres") as GameRules
	var crowd := load("res://resources/default_crowd_settings.tres") as CrowdSettings
	var vehicle := load("res://resources/default_vehicle_config.tres") as VehicleConfig
	var civilian := load("res://resources/default_civilian_profile.tres") as NpcProfile
	var hostile := load("res://resources/default_hostile_profile.tres") as NpcProfile
	_expect(results, "default rules resource loads", rules != null)
	_expect(results, "default crowd resource loads", crowd != null)
	_expect(results, "default vehicle resource loads", vehicle != null)
	_expect(results, "default civilian profile loads", civilian != null)
	_expect(results, "default hostile profile loads", hostile != null)
	if rules != null:
		_expect(results, "default hostile score is 100", rules.hostile_score == 100)
		_expect(results, "default civilian penalty is 250", rules.civilian_penalty == 250)
		_expect(results, "default combo window is six seconds", is_equal_approx(rules.combo_window_seconds, 6.0))
		_expect(results, "default panic threshold is two", rules.panic_threshold == 2)
	if crowd != null:
		_expect(results, "crowd cap is 250", crowd.active_npc_cap == 250)
		_expect(results, "civilian target is 160", crowd.civilian_target_count == 160)
		_expect(results, "hostile target is 90", crowd.hostile_target_count == 90)
	if vehicle != null:
		_expect(results, "vehicle mass is positive", vehicle.mass > 0.0)
		_expect(results, "vehicle propulsion is configured", vehicle.engine_force > 0.0 and vehicle.maximum_speed > 0.0)
		_expect(results, "vehicle suspension is configured", vehicle.suspension_rest_length > 0.0 and vehicle.suspension_stiffness > 0.0)
	if civilian != null and hostile != null:
		_expect(results, "civilian profile is non-hostile", not civilian.is_hostile())
		_expect(results, "civilian walk speed is 3.0 m/s", is_equal_approx(civilian.walk_speed, 3.0))
		_expect(results, "hostile walk speed is 3.4 m/s", is_equal_approx(hostile.walk_speed, 3.4))
		_expect(results, "civilian profile has no equipped prop", civilian.equipped_prop_scene == null)
		_expect(results, "hostile profile is hostile", hostile.is_hostile())
		_expect(results, "hostile profile has an equipped prop", hostile.equipped_prop_scene != null)
		_expect(results, "hostile profile enables warning marker", hostile.warning_marker_enabled)
		_expect(results, "hostile civilian targeting probability is 0.06", is_equal_approx(hostile.civilian_target_probability, 0.06))
		_expect(results, "hostile civilian targeting cooldown is 12 seconds", is_equal_approx(hostile.civilian_target_cooldown, 12.0))
		_expect(results, "hostile civilian target damage covers default health", hostile.civilian_target_damage >= civilian.maximum_health)

	var impact := ImpactEvent.new("contract-life", "Hostile", null, 12.0, Vector3.FORWARD, 4.0)
	_expect(results, "impact event stores lifecycle contract", impact.npc_id == "contract-life" and impact.npc_role == "Hostile")
	_expect(results, "impact event stores physical data", is_equal_approx(impact.speed, 12.0) and impact.impulse == Vector3.FORWARD)
	_expect(results, "impact event defaults remain vehicle-compatible", impact.impact_kind == &"vehicle" and impact.world_position == Vector3.ZERO)

	var violence := ViolenceSettings.new()
	violence.apply_preset(ViolenceSettings.Preset.FULL)
	_expect(results, "full preset enables all impact channels", violence.blood_particles_enabled and violence.decals_enabled and violence.fragments_enabled and violence.impact_camera_shake_enabled and violence.vocal_impact_audio_enabled)
	violence.apply_preset(ViolenceSettings.Preset.REDUCED)
	_expect(results, "reduced preset lowers density", violence.blood_particle_density < 1.0 and violence.fragments_enabled == false)
	violence.apply_preset(ViolenceSettings.Preset.DISABLED)
	_expect(results, "disabled preset disables every impact channel", not violence.blood_particles_enabled and not violence.decals_enabled and not violence.fragments_enabled and not violence.impact_camera_shake_enabled and not violence.vocal_impact_audio_enabled)

func _test_projectile_contracts(results: Array[Dictionary]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var profile := load("res://resources/default_hostile_profile.tres") as NpcProfile
	_expect(results, "hostile engagement range is 18 meters", profile != null and is_equal_approx(profile.engagement_range, 18.0))
	_expect(results, "hostile attack range is 18 meters", profile != null and is_equal_approx(profile.attack_range, 18.0))
	_expect(results, "hostile attack interval is 1.5 seconds", profile != null and is_equal_approx(profile.attack_interval, 1.5))
	_expect(results, "hostile shot damage is 3", profile != null and is_equal_approx(profile.attack_damage, 3.0))
	_expect(results, "hostile aim spread is 14 degrees", profile != null and is_equal_approx(profile.aim_spread_degrees, 14.0))
	var projectile_scene := load("res://scenes/HostileProjectile.tscn") as PackedScene
	_expect(results, "hostile projectile scene loads", projectile_scene != null)
	if projectile_scene == null:
		return
	var presentation := projectile_scene.instantiate() as Node3D
	_expect(results, "projectile has emissive tracer body", presentation != null and presentation.get_node_or_null("TracerBody") != null)
	_expect(results, "projectile has tracer light or trail", presentation != null and (presentation.get_node_or_null("TracerLight") != null or presentation.get_node_or_null("Trail") != null))
	_expect(results, "projectile has short impact flash", presentation != null and presentation.get_node_or_null("ImpactFlash") != null and presentation.get_node_or_null("ImpactFlashTimer") != null)
	var impact_particles := presentation.get_node_or_null("ImpactParticles") as GPUParticles3D
	_expect(results, "projectile has a one-shot impact particle burst", impact_particles != null and impact_particles.one_shot and impact_particles.amount >= 16)
	tree.root.add_child(presentation)
	if presentation != null:
		presentation.call("launch", null, Vector3(0.0, 1.0, 0.0), Vector3.FORWARD, 3.0, 50.0, 24.0)
		presentation.call("advance", 1.0)
		_expect(results, "projectile hard-caps travel at 18 meters", float(presentation.get("traveled_distance")) <= 18.001)
		_expect(results, "projectile expires after finite travel", not bool(presentation.get("is_active")))
		presentation.queue_free()

	var impact_probe := projectile_scene.instantiate() as Node3D
	tree.root.add_child(impact_probe)
	impact_probe.call("launch", null, Vector3(4.0, 2.0, 0.0), Vector3.FORWARD, 3.0, 18.0, 24.0)
	impact_probe.call("_resolve_impact", {"collider": null})
	var emitted_particles := impact_probe.get_node_or_null("ImpactParticles") as GPUParticles3D
	var impact_timer := impact_probe.get_node_or_null("ImpactFlashTimer") as Timer
	_expect(results, "impact starts the particle burst before cleanup", emitted_particles != null and emitted_particles.emitting)
	_expect(results, "impact cleanup outlives the particle burst presentation", impact_timer != null and impact_timer.time_left > 0.3)
	impact_probe.queue_free()

	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(4.0, 4.0, 0.2)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	tree.root.add_child(wall)
	wall.global_position = Vector3(0.0, 1.0, -3.0)
	wall.force_update_transform()
	var blocked := projectile_scene.instantiate() as Node3D
	tree.root.add_child(blocked)
	blocked.call("launch", null, Vector3(0.0, 1.0, 0.0), Vector3.FORWARD, 3.0, 18.0, 24.0)
	blocked.call("advance", 0.25)
	_expect(results, "projectile collision mask sweeps World Player Vehicle NPC", int(blocked.get("collision_mask")) == 15)
	_expect(results, "world wall stops swept projectile before its endpoint", float(blocked.get("traveled_distance")) < 6.0 and not bool(blocked.get("is_active")))
	blocked.queue_free()
	wall.queue_free()

	var hostile_profile := load("res://resources/default_hostile_profile.tres") as NpcProfile
	var civilian_profile := load("res://resources/default_civilian_profile.tres") as NpcProfile
	var shooter := preload("res://scenes/Npc.tscn").instantiate() as Node3D
	var interceptor := preload("res://scenes/Npc.tscn").instantiate() as Node3D
	tree.root.add_child(shooter)
	tree.root.add_child(interceptor)
	shooter.call("activate", hostile_profile, Vector3(8.0, 1.0, 0.0), "projectile-shooter", &"", null)
	interceptor.call("activate", civilian_profile, Vector3(8.0, 1.0, -3.0), "projectile-interceptor", &"", null)
	shooter.force_update_transform()
	interceptor.force_update_transform()
	var interceptor_health := interceptor.get_node("HealthComponent") as HealthComponent
	var projectile_events: Array[ImpactEvent] = []
	var projectile_event_handler := func(event: ImpactEvent) -> void: projectile_events.append(event)
	ImpactBus.impact_received.connect(projectile_event_handler)
	var intercepted := projectile_scene.instantiate() as Node3D
	tree.root.add_child(intercepted)
	intercepted.call("launch", shooter, shooter.global_position + Vector3.UP * 1.05, Vector3.FORWARD, 3.0, 18.0, 24.0)
	var npc_query := intercepted.call("_build_swept_query", intercepted.global_position, intercepted.global_position + Vector3.FORWARD * 6.0) as PhysicsRayQueryParameters3D
	_expect(results, "NPC sweep retains shooter RID exclusion", npc_query != null and npc_query.exclude.has((shooter as CollisionObject3D).get_rid()))
	interceptor.call("apply_damage", interceptor_health.maximum_health - 3.0)
	intercepted.call("_resolve_impact", {"collider": interceptor, "position": interceptor.global_position})
	ImpactBus.impact_received.disconnect(projectile_event_handler)
	_expect(results, "NPC projectile impact applies damage once and reaches death lifecycle", interceptor_health != null and is_zero_approx(interceptor_health.current_health) and bool(interceptor.call("was_killed")))
	_expect(results, "NPC projectile impact emits explicit projectile position and kind", projectile_events.size() == 1 and projectile_events[0].impact_kind == &"projectile" and projectile_events[0].world_position == interceptor.global_position)
	_expect(results, "intervening NPC impact terminates the projectile", not bool(intercepted.get("is_active")))
	intercepted.queue_free()
	shooter.queue_free()
	interceptor.queue_free()

func _test_health(results: Array[Dictionary]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var health := HealthComponent.new()
	tree.root.add_child(health)
	health.configure(100.0)
	health.configure_regeneration(10.0, 60.0)
	var death_count: Array[int] = [0]
	health.died.connect(func() -> void: death_count[0] += 1)
	health.apply_damage(40.0)
	health.call("_physics_process", 59.99)
	_expect(results, "regeneration waits through 59.99 seconds", is_equal_approx(health.current_health, 60.0))
	health.call("_physics_process", 0.01)
	_expect(results, "regeneration does not heal at the exact 60 second crossing", is_equal_approx(health.current_health, 60.0))
	health.call("_physics_process", 1.0)
	_expect(results, "regeneration begins after the delay", is_equal_approx(health.current_health, 70.0))
	health.apply_damage(10.0)
	health.call("_physics_process", 59.99)
	_expect(results, "positive damage resets regeneration delay", is_equal_approx(health.current_health, 60.0))
	health.call("_physics_process", 0.01)
	_expect(results, "reset delay has no exact-threshold heal", is_equal_approx(health.current_health, 60.0))
	health.call("_physics_process", 0.5)
	_expect(results, "regeneration uses only post-threshold frame time", is_equal_approx(health.current_health, 65.0))
	health.call("_physics_process", 10.0)
	_expect(results, "regeneration clamps at maximum", is_equal_approx(health.current_health, 100.0))
	health.apply_damage(100.0)
	_expect(results, "health clamps damage at zero", is_zero_approx(health.current_health))
	_expect(results, "health emits one death signal", death_count[0] == 1)
	health.call("_physics_process", 60.0)
	_expect(results, "dead health never regenerates or revives", is_zero_approx(health.current_health))
	health.apply_damage(10.0)
	_expect(results, "dead health does not emit repeatedly", death_count[0] == 1)
	health.reset()
	_expect(results, "health reset restores configured maximum", is_equal_approx(health.current_health, 100.0))
	health.queue_free()

func _test_world_and_vehicle(results: Array[Dictionary]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var district := preload("res://scenes/District.tscn").instantiate()
	tree.root.add_child(district)
	var civilian_points: Array[Marker3D] = district.get_spawn_points("civilian")
	var hostile_points: Array[Marker3D] = district.get_spawn_points("hostile")
	_expect(results, "district has four civilian spawn zones", civilian_points.size() >= 4)
	_expect(results, "district has four hostile spawn zones", hostile_points.size() >= 4)
	_expect(results, "district exposes player spawn", district.get_player_spawn_position().y > 0.0)
	_expect(results, "district ground has collision", district.get_node_or_null("Ground/CollisionShape3D") != null)
	_expect(results, "district roads have collision", district.get_node_or_null("Roads/RoadX/CollisionShape3D") != null and district.get_node_or_null("Roads/RoadZ/CollisionShape3D") != null)
	_expect(results, "district provides a navigation region", district.get_node_or_null("NavigationRegion3D") != null and district.get_node("NavigationRegion3D").get("navigation_mesh") != null)

	var player: Node3D = preload("res://scenes/Player.tscn").instantiate() as Node3D
	var vehicle: Node = preload("res://scenes/ArcadeVehicle.tscn").instantiate()
	tree.root.add_child(player)
	tree.root.add_child(vehicle)
	player.global_position = Vector3(4.0, 1.2, 4.0)
	vehicle.set("global_position", player.global_position)
	var wheel_rays: Array[Node] = vehicle.find_children("*", "RayCast3D", true, false)
	var player_health := player.get_node("HealthComponent") as HealthComponent
	var vehicle_health := vehicle.get_node("HealthComponent") as HealthComponent
	_expect(results, "player health regenerates at 10 HP/s after 60 seconds", player_health != null and is_equal_approx(player_health.regeneration_rate, 10.0) and is_equal_approx(player_health.regeneration_delay, 60.0))
	_expect(results, "vehicle health regenerates at 10 HP/s after 60 seconds", vehicle_health != null and is_equal_approx(vehicle_health.regeneration_rate, 10.0) and is_equal_approx(vehicle_health.regeneration_delay, 60.0))
	_expect(results, "vehicle has four suspension raycasts", wheel_rays.size() == 4)
	var suspension_wiring_valid := true
	for ray_node in wheel_rays:
		var ray := ray_node as RayCast3D
		if ray == null or ray.target_position.y >= 0.0 or ray.collision_mask != 1:
			suspension_wiring_valid = false
	_expect(results, "suspension raycasts target the world", suspension_wiring_valid)
	_expect(results, "vehicle entry requires proximity", bool(vehicle.call("try_enter", player)))
	_expect(results, "vehicle entry assigns the driver", vehicle.get("occupied_driver") == player and player.get("occupied_vehicle") == vehicle)
	_expect(results, "vehicle entry activates vehicle camera", bool(vehicle.get_node("CameraRig/SpringArm3D/Camera3D").current))
	_expect(results, "vehicle exits to a clear side position", bool(vehicle.call("exit_vehicle")) and player.get("occupied_vehicle") == null)
	_expect(results, "vehicle exit restores on-foot camera", bool(player.get_node("CameraRig/SpringArm3D/Camera3D").current))
	var camera_rig := player.get_node("CameraRig") as Node3D
	var camera_position_before := camera_rig.global_position
	player.global_position += Vector3(6.0, 0.0, 0.0)
	camera_rig.call("_process", 0.25)
	_expect(results, "third-person camera follows player", camera_rig.global_position != camera_position_before)
	vehicle.set("global_position", Vector3(100.0, 8.0, -100.0))
	vehicle.call("reset_to_nearest_road")
	var reset_position := vehicle.get("global_position") as Vector3
	var city_extent := float(district.call("get_city_size")) * 0.5
	_expect(results, "vehicle reset stays inside district bounds", absf(reset_position.x) <= city_extent and absf(reset_position.z) <= city_extent and is_equal_approx(reset_position.y, 1.25))
	vehicle.set("linear_velocity", Vector3(100.0, 0.0, 0.0))
	vehicle.call("_limit_speed")
	var limited_velocity := vehicle.get("linear_velocity") as Vector3
	var vehicle_config := load("res://resources/default_vehicle_config.tres") as VehicleConfig
	_expect(results, "vehicle clamps configured maximum speed", vehicle_config != null and limited_velocity.length() <= vehicle_config.maximum_speed)
	GameState.finish_run()
	player.set("velocity", Vector3(3.0, 0.0, 3.0))
	player.call("_physics_process", 0.1)
	_expect(results, "on-foot movement disables on game over", player.get("velocity") == Vector3.ZERO)
	GameState.reset_run()
	vehicle.call("apply_damage", 1000.0)
	_expect(results, "vehicle destruction ends the run", GameState.is_game_over)
	GameState.reset_run()
	player.queue_free()
	vehicle.queue_free()
	district.queue_free()

func _test_npc_states(results: Array[Dictionary]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var target: Node3D = preload("res://scenes/Player.tscn").instantiate() as Node3D
	tree.root.add_child(target)
	target.global_position = Vector3.ZERO
	var hostile_profile := (load("res://resources/default_hostile_profile.tres") as NpcProfile).duplicate() as NpcProfile
	hostile_profile.aim_spread_degrees = 0.0
	var civilian_profile := load("res://resources/default_civilian_profile.tres") as NpcProfile
	HostileGroupService.reset_run()
	var hostile_group := HostileGroupService.create_group()
	var hostile: Node = preload("res://scenes/Npc.tscn").instantiate()
	tree.root.add_child(hostile)
	var target_health := target.get_node("HealthComponent") as HealthComponent
	_npc_damage_events = 0
	if target_health != null:
		target_health.damaged.connect(_on_npc_damage)
	hostile.call("activate", hostile_profile, Vector3(2.0, 1.2, 1.5), "contract-hostile", hostile_group, target)
	_expect(results, "active hostile registers in role groups", hostile.is_in_group("active_npc") and hostile.is_in_group("active_hostile") and not hostile.is_in_group("active_civilian"))
	hostile.call("tick", 0.1, true)
	_expect(results, "hostile enters engage state near player", int(hostile.get("state")) == 2)
	var first_projectile := _find_live_projectile()
	_expect(results, "hostile engagement spawns a projectile", first_projectile != null)
	var weapon_pivot := hostile.get_node("RoleMarkerAnchor/HostileProp/WeaponPivot") as Node3D
	_expect(results, "hostile weapon pivot tracks the on-foot target", weapon_pivot != null and absf(weapon_pivot.rotation.y) > 0.05)
	_expect(results, "hostile weapon recoils when a shot is fired", weapon_pivot != null and weapon_pivot.position.z > 0.05)
	if first_projectile != null:
		var expected_on_foot_aim: Vector3 = (hostile.global_position + Vector3.UP * 1.05).direction_to(target.global_position + Vector3.UP * 0.9)
		_expect(results, "on-foot hostile aim resolves to the player body", (first_projectile.get("fired_direction") as Vector3).dot(expected_on_foot_aim) > 0.999)
	_expect(results, "projectile fire does not damage before impact", target_health != null and is_equal_approx(target_health.current_health, target_health.maximum_health))
	if first_projectile != null:
		first_projectile.call("_resolve_impact", {"collider": target})
	_expect(results, "projectile impact damages the player", target_health != null and is_equal_approx(target_health.current_health, target_health.maximum_health - 3.0))
	_expect(results, "projectile impact emits exactly one damage event", _npc_damage_events == 1)

	var vehicle: Node = preload("res://scenes/ArcadeVehicle.tscn").instantiate()
	tree.root.add_child(vehicle)
	vehicle.set("global_position", target.global_position)
	var entered_vehicle := bool(vehicle.call("try_enter", target))
	var vehicle_health := vehicle.get_node("HealthComponent") as HealthComponent
	vehicle.set("global_position", Vector3(6.0, 0.0, 0.0))
	target_health.reset()
	var occupied_projectile := hostile.call("fire_hostile_projectile", Vector3.ZERO, 0.0) as Node
	if occupied_projectile != null:
		var expected_vehicle_aim: Vector3 = (hostile.global_position + Vector3.UP * 1.05).direction_to((vehicle.get("global_position") as Vector3) + Vector3.UP * 0.9)
		_expect(results, "occupied hostile aim resolves to the vehicle current position", (occupied_projectile.get("fired_direction") as Vector3).dot(expected_vehicle_aim) > 0.999)
		occupied_projectile.call("_resolve_impact", {"collider": target})
	_expect(results, "occupied player routes projectile damage to vehicle", entered_vehicle and vehicle_health != null and is_equal_approx(vehicle_health.current_health, vehicle_health.maximum_health - 3.0))
	_expect(results, "occupied player health remains protected", target_health != null and is_equal_approx(target_health.current_health, target_health.maximum_health))
	_expect(results, "NPC health has regeneration disabled", hostile.get_node("HealthComponent").get("regeneration_rate") == 0.0)

	var panic_distance_before: float = hostile.global_position.distance_to(target.global_position)
	HostileGroupService.record_impact(hostile_group, 0.0)
	HostileGroupService.record_impact(hostile_group, 1.0)
	_expect(results, "hostile group panic changes member state", int(hostile.get("state")) == 3)
	hostile.call("tick", 0.2, true)
	var panic_distance_after: float = hostile.global_position.distance_to(target.global_position)
	_expect(results, "panicked hostile moves away from player", panic_distance_after >= panic_distance_before)

	var civilian: Node = preload("res://scenes/Npc.tscn").instantiate()
	tree.root.add_child(civilian)
	civilian.call("activate", civilian_profile, Vector3(0.0, 1.2, 20.0), "contract-civilian", &"", target)
	_expect(results, "active civilian registers in role groups", civilian.is_in_group("active_npc") and civilian.is_in_group("active_civilian") and not civilian.is_in_group("active_hostile"))
	civilian.call("tick", 0.1, true)
	_expect(results, "civilian stays in wandering state", int(civilian.get("state")) == 1)
	_expect(results, "civilian selects a wander target", (civilian.get("_wander_target") as Vector3) != Vector3.ZERO)
	var civilian_wander_offset := (civilian.get("_wander_target") as Vector3) - (civilian.get("_roaming_anchor") as Vector3)
	civilian_wander_offset.y = 0.0
	_expect(results, "ordinary wander radius is between 8 and 28 meters", civilian_wander_offset.length() >= 8.0 and civilian_wander_offset.length() <= 28.0)
	_expect(results, "ordinary wander retarget time is between 2 and 5 seconds", float(civilian.get("_wander_time_left")) >= 2.0 and float(civilian.get("_wander_time_left")) <= 5.0)

	var civilian_target: Node = preload("res://scenes/Npc.tscn").instantiate()
	tree.root.add_child(civilian_target)
	civilian_target.call("activate", civilian_profile, Vector3(4.0, 1.2, 4.0), "contract-civilian-target", &"", target)
	var civilian_target_health := civilian_target.get_node("HealthComponent") as HealthComponent
	hostile.set("_civilian_target_cooldown", 0.0)
	var direction_override_projectile := hostile.call("fire_hostile_projectile", Vector3(3.0, 0.0, 4.0), 0.0) as Node
	var expected_direction_override := Vector3(3.0, 0.0, 4.0).normalized()
	var fired_direction_override := direction_override_projectile.get("fired_direction") as Vector3 if direction_override_projectile != null else Vector3.ZERO
	_expect(results, "non-zero direction override takes precedence over target aim", direction_override_projectile != null and is_equal_approx(fired_direction_override.length(), 1.0) and fired_direction_override.dot(expected_direction_override) > 0.999)
	if direction_override_projectile != null:
		direction_override_projectile.queue_free()
	var rejected_projectile := hostile.call("fire_hostile_projectile", Vector3.ZERO, 0.0, null, 0.99) as Node
	_expect(results, "probability gate preserves ordinary hostile shots", rejected_projectile != null and is_equal_approx(float(rejected_projectile.get("damage")), 3.0))
	if rejected_projectile != null:
		rejected_projectile.queue_free()
	hostile.set("_civilian_target_cooldown", 0.0)
	var rejected_target := hostile.call("select_deliberate_civilian_target", 0.99) as Node
	_expect(results, "civilian targeting rejects a failed deterministic probability roll", rejected_target == null and is_zero_approx(float(hostile.get("_civilian_target_cooldown"))))
	var deliberate_projectile := hostile.call("fire_hostile_projectile", Vector3.ZERO, 0.0, null, 0.0) as Node
	var expected_civilian_aim: Vector3 = (hostile.global_position + Vector3.UP * 1.05).direction_to(civilian_target.global_position + Vector3.UP * 0.9)
	_expect(results, "deterministic hostile shot selects a civilian", deliberate_projectile != null and (deliberate_projectile.get("fired_direction") as Vector3).dot(expected_civilian_aim) > 0.999)
	_expect(results, "deliberate civilian shot carries one-hit damage", deliberate_projectile != null and float(deliberate_projectile.get("damage")) >= civilian_target_health.maximum_health)
	var weapon_origin: Vector3 = weapon_pivot.global_position if weapon_pivot != null else hostile.global_position
	var weapon_target_direction: Vector3 = weapon_origin.direction_to(civilian_target.global_position)
	weapon_target_direction.y = 0.0
	var expected_civilian_yaw := atan2(-weapon_target_direction.x, -weapon_target_direction.z)
	var civilian_yaw_delta := absf(fposmod(weapon_pivot.rotation.y - expected_civilian_yaw + PI, TAU) - PI) if weapon_pivot != null else TAU
	_expect(results, "weapon aim follows the deliberate civilian target", civilian_yaw_delta < 0.01)
	_expect(results, "deliberate civilian shot starts its separate cooldown", is_equal_approx(float(hostile.get("_civilian_target_cooldown")), 12.0))
	var cooldown_target := hostile.call("select_deliberate_civilian_target", 0.0) as Node
	_expect(results, "civilian targeting cooldown blocks immediate repeat", cooldown_target == null)
	if deliberate_projectile != null:
		deliberate_projectile.call("_resolve_impact", {"collider": civilian_target})
	_expect(results, "deliberate civilian projectile kills a full-health civilian", civilian_target_health != null and is_zero_approx(civilian_target_health.current_health) and bool(civilian_target.call("was_killed")))
	var disabled_scan_timer_before := 0.0
	civilian_target.set("_disabled_time", 0.0)
	civilian_target.set("_hostile_awareness_time_left", disabled_scan_timer_before)
	_expect(results, "killed civilian remains disabled beside an active hostile", bool(civilian_target.call("is_disabled")) and bool(civilian_target.call("was_killed")) and not bool(civilian_target.call("is_hostile_fleeing")))
	_expect(results, "disabled dead civilian rejects hostile awareness", not bool(civilian_target.call("refresh_hostile_awareness")) and not bool(civilian_target.call("_scan_hostile_awareness")))
	civilian_target.call("_update_hostile_awareness", 0.1)
	civilian_target.call("tick", 0.75, true)
	civilian_target.call("tick", 0.75, true)
	_expect(results, "disabled timer advances and reaches recycle threshold", bool(civilian_target.call("is_disabled")) and is_equal_approx(float(civilian_target.get("_disabled_time")), 1.5) and bool(civilian_target.call("is_disabled_for_recycle")))
	_expect(results, "disabled awareness update leaves its timer untouched", is_equal_approx(float(civilian_target.get("_hostile_awareness_time_left")), disabled_scan_timer_before))
	civilian_target.call("deactivate")
	_expect(results, "inactive civilian rejects hostile awareness", bool(civilian_target.call("is_inactive")) and not bool(civilian_target.call("refresh_hostile_awareness")) and not bool(civilian_target.call("_scan_hostile_awareness")))

	var flee_hostile: Node = preload("res://scenes/Npc.tscn").instantiate()
	var fleeing_civilian: Node = preload("res://scenes/Npc.tscn").instantiate()
	tree.root.add_child(flee_hostile)
	tree.root.add_child(fleeing_civilian)
	flee_hostile.call("activate", hostile_profile, Vector3(46.0, 1.2, 0.0), "contract-flee-hostile", &"", null)
	fleeing_civilian.call("activate", civilian_profile, Vector3(40.0, 1.2, 0.0), "contract-flee-civilian", &"", null)
	_expect(results, "hostile activation registers a hostile role group", flee_hostile.is_in_group("active_hostile"))
	_expect(results, "civilian activation registers a civilian role group", fleeing_civilian.is_in_group("active_civilian"))
	var awareness_detected := bool(fleeing_civilian.call("refresh_hostile_awareness"))
	_expect(results, "civilian detects a nearby hostile", awareness_detected and bool(fleeing_civilian.call("is_hostile_fleeing")) and fleeing_civilian.get("_hostile_flee_target") == flee_hostile)
	_expect(results, "hostile awareness is throttled after a scan", is_equal_approx(float(fleeing_civilian.get("_hostile_awareness_time_left")), 0.30))
	var fleeing_start: Vector3 = fleeing_civilian.global_position
	fleeing_civilian.call("tick", 0.1, true)
	var fleeing_delta: Vector3 = fleeing_civilian.global_position - fleeing_start
	fleeing_delta.y = 0.0
	var expected_flee_direction: Vector3 = flee_hostile.global_position.direction_to(fleeing_start)
	expected_flee_direction.y = 0.0
	expected_flee_direction = expected_flee_direction.normalized()
	_expect(results, "civilian flees directly away from the hostile", fleeing_delta.length() > 0.0 and fleeing_delta.normalized().dot(expected_flee_direction) > 0.99)
	var fleeing_velocity := fleeing_civilian.get("velocity") as Vector3
	_expect(results, "civilian hostile-flee speed is 1.8x walk speed", is_equal_approx(fleeing_velocity.length(), civilian_profile.walk_speed * 1.8))
	flee_hostile.set("global_position", fleeing_civilian.global_position + Vector3(18.0, 0.0, 0.0))
	_expect(results, "civilian keeps fleeing inside the 20 meter release radius", bool(fleeing_civilian.call("refresh_hostile_awareness")) and bool(fleeing_civilian.call("is_hostile_fleeing")))
	flee_hostile.set("global_position", fleeing_civilian.global_position + Vector3(21.0, 0.0, 0.0))
	_expect(results, "civilian returns to wandering outside the release radius", not bool(fleeing_civilian.call("refresh_hostile_awareness")) and not bool(fleeing_civilian.call("is_hostile_fleeing")))
	_expect(results, "hostile awareness never makes hostiles flee hostiles", not bool(flee_hostile.call("is_hostile_fleeing")))
	for projectile in tree.get_nodes_in_group("hostile_projectile"):
		if is_instance_valid(projectile):
			projectile.queue_free()
	hostile.call("deactivate")
	_expect(results, "weapon pivot resets when the hostile returns to its pool", weapon_pivot != null and weapon_pivot.position.is_zero_approx() and weapon_pivot.rotation.is_zero_approx())
	_expect(results, "deactivation removes hostile role groups", not hostile.is_in_group("active_npc") and not hostile.is_in_group("active_hostile"))
	civilian_target.call("deactivate")
	flee_hostile.call("deactivate")
	fleeing_civilian.call("deactivate")
	civilian.call("deactivate")
	_expect(results, "deactivation removes civilian role groups", not civilian_target.is_in_group("active_npc") and not fleeing_civilian.is_in_group("active_civilian"))
	hostile.queue_free()
	civilian.queue_free()
	civilian_target.queue_free()
	flee_hostile.queue_free()
	fleeing_civilian.queue_free()
	vehicle.queue_free()
	target.queue_free()

func _find_live_projectile() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	for projectile in tree.get_nodes_in_group("hostile_projectile"):
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			return projectile
	return null

func _on_npc_damage(_amount: float, _current: float) -> void:
	_npc_damage_events += 1

func _test_effects_and_ui(results: Array[Dictionary]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var effects := Node3D.new()
	effects.set_script(load("res://scripts/effects/impact_effects.gd"))
	tree.root.add_child(effects)
	var particle_pool: Array = effects.get("_particle_pool")
	var decal_pool: Array = effects.get("_decal_pool")
	var fragment_pool: Array = effects.get("_fragment_pool")
	var audio_pool: Array = effects.get("_audio_pool")
	var blood_hit_pool: Array = effects.get("_blood_hit_pool")
	var decal_meshes: Array = effects.get("_decal_meshes")
	_expect(results, "impact particle pool has a hard limit", particle_pool.size() == 24)
	_expect(results, "impact decal pool has a hard limit", decal_pool.size() == 32)
	_expect(results, "impact fragment pool has a hard limit", fragment_pool.size() == 48)
	_expect(results, "impact audio pool has a hard limit", audio_pool.size() == 8)
	_expect(results, "animated blood-hit pool has a hard limit", blood_hit_pool.size() == 24)
	_expect(results, "retained Kenney splats share three decal meshes", decal_meshes.size() == 3)
	var source := Node3D.new()
	tree.root.add_child(source)
	var impact := ImpactEvent.new("effect-life", "Hostile", source, 12.0, Vector3.FORWARD, 1.0)
	var original_preset := int(SettingsService.violence.preset)
	SettingsService.violence.apply_preset(ViolenceSettings.Preset.DISABLED)
	effects.call("_on_impact", impact)
	var disabled_particles := false
	for particle in particle_pool:
		if particle.emitting:
			disabled_particles = true
	_expect(results, "disabled preset emits no impact particles", not disabled_particles)
	SettingsService.violence.apply_preset(ViolenceSettings.Preset.FULL)
	effects.call("_on_impact", impact)
	var full_particles := false
	for particle in particle_pool:
		if particle.emitting:
			full_particles = true
		break
	_expect(results, "full preset emits impact particles", full_particles)
	var projectile_particle_index := int(effects.get("_particle_cursor"))
	var projectile_impact := ImpactEvent.new("effect-projectile", "Hostile", source, 12.0, Vector3.FORWARD, 2.0, true, false, Vector3(1.0, 0.5, 0.0), &"projectile")
	effects.call("_on_impact", projectile_impact)
	var projectile_particle_amount := int(particle_pool[projectile_particle_index].amount)
	var vehicle_particle_index := int(effects.get("_particle_cursor"))
	effects.call("_on_impact", impact)
	var vehicle_particle_amount := int(particle_pool[vehicle_particle_index].amount)
	_expect(results, "full vehicle gore uses a heavier particle burst than projectile gore", vehicle_particle_amount > projectile_particle_amount)
	var full_decals := false
	for decal in decal_pool:
		if decal.visible:
			full_decals = true
			break
	var full_fragments := false
	for fragment in fragment_pool:
		if fragment.visible:
			full_fragments = true
			break
	var full_audio := false
	for audio in audio_pool:
		if audio.playing:
			full_audio = true
			break
	_expect(results, "full preset shows impact decals", full_decals)
	_expect(results, "full preset shows impact fragments", full_fragments)
	_expect(results, "full preset plays impact audio", full_audio)
	var shake_count: Array[int] = [0]
	var shake_handler := func(_intensity: float) -> void: shake_count[0] += 1
	CameraShake.shake_requested.connect(shake_handler)
	SettingsService.violence.apply_preset(ViolenceSettings.Preset.DISABLED)
	CameraShake.request_shake(1.0)
	var disabled_shakes := shake_count[0]
	SettingsService.violence.apply_preset(ViolenceSettings.Preset.FULL)
	CameraShake.request_shake(1.0)
	_expect(results, "disabled preset suppresses camera shake", disabled_shakes == 0)
	_expect(results, "full preset allows camera shake", shake_count[0] == 1)
	CameraShake.shake_requested.disconnect(shake_handler)
	SettingsService.violence.apply_preset(original_preset)

	var hud: Node = preload("res://scenes/HUD.tscn").instantiate()
	tree.root.add_child(hud)
	ScoreManager.score_changed.emit(50, 50)
	var score_label := hud.get_node("MarginContainer/Panel/VBox/Score") as Label
	_expect(results, "HUD reads score service signals", score_label != null and score_label.text == "Score: 50")
	var fps_label := hud.get_node_or_null("MarginContainer/Panel/VBox/FPS") as Label
	var fps_updates_before := int(hud.get("_fps_update_count"))
	_expect(results, "HUD exposes health, preset, and integer FPS labels", hud.get_node_or_null("MarginContainer/Panel/VBox/PlayerHealth") != null and hud.get_node_or_null("MarginContainer/Panel/VBox/VehicleHealth") != null and hud.get_node_or_null("MarginContainer/Panel/VBox/GorePreset") != null and fps_label != null and fps_label.text.begins_with("FPS: ") and hud.call("format_fps", 59.6) == "FPS: 60")
	hud.call("_process", 0.10)
	var fps_updates_after_short_delta := int(hud.get("_fps_update_count"))
	hud.call("_process", 0.15)
	_expect(results, "HUD FPS refresh is bounded to the quarter-second cadence", fps_updates_after_short_delta == fps_updates_before and int(hud.get("_fps_update_count")) == fps_updates_before + 1)
	hud.get_node("ScorePopupPool").call("show_delta", -25)
	var popup_visible := false
	for popup in hud.get_node("ScorePopupPool").get_children():
		if popup is Label and popup.visible:
			popup_visible = true
			break
	_expect(results, "score popup pool shows negative feedback", popup_visible)

	var game_over: Node = preload("res://scenes/GameOverScreen.tscn").instantiate()
	tree.root.add_child(game_over)
	GameState.reset_run()
	GameState.finish_run()
	_expect(results, "game-over screen responds to game state", bool(game_over.get_node("Panel").visible))
	GameState.reset_run()
	_expect(results, "game-over screen hides after reset", not bool(game_over.get_node("Panel").visible))

	var gore_menu: Node = preload("res://scenes/GoreMenu.tscn").instantiate()
	tree.root.add_child(gore_menu)
	var selector := gore_menu.get_node("Panel/VBox/Preset") as OptionButton
	_expect(results, "gore menu exposes three presets", selector != null and selector.item_count == 3)
	var original_settings_preset := int(SettingsService.violence.preset)
	SettingsService.set_preset(ViolenceSettings.Preset.DISABLED)
	SettingsService.load_settings()
	_expect(results, "gore preset persists through settings reload", int(SettingsService.violence.preset) == ViolenceSettings.Preset.DISABLED)
	SettingsService.set_preset(original_settings_preset)
	effects.queue_free()
	source.queue_free()
	hud.queue_free()
	game_over.queue_free()
	gore_menu.queue_free()

func _expect(results: Array[Dictionary], name: String, condition: bool) -> void:
	results.append({"name": name, "passed": condition, "message": "" if condition else "Assertion failed"})
