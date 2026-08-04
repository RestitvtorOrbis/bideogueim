extends RefCounted

var _npc_damage_events: int = 0

func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	_test_resources(results)
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
		_expect(results, "civilian profile has no equipped prop", civilian.equipped_prop_scene == null)
		_expect(results, "hostile profile is hostile", hostile.is_hostile())
		_expect(results, "hostile profile has an equipped prop", hostile.equipped_prop_scene != null)
		_expect(results, "hostile profile enables warning marker", hostile.warning_marker_enabled)

	var impact := ImpactEvent.new("contract-life", "Hostile", null, 12.0, Vector3.FORWARD, 4.0)
	_expect(results, "impact event stores lifecycle contract", impact.npc_id == "contract-life" and impact.npc_role == "Hostile")
	_expect(results, "impact event stores physical data", is_equal_approx(impact.speed, 12.0) and impact.impulse == Vector3.FORWARD)

	var violence := ViolenceSettings.new()
	violence.apply_preset(ViolenceSettings.Preset.FULL)
	_expect(results, "full preset enables all impact channels", violence.blood_particles_enabled and violence.decals_enabled and violence.fragments_enabled and violence.impact_camera_shake_enabled and violence.vocal_impact_audio_enabled)
	violence.apply_preset(ViolenceSettings.Preset.REDUCED)
	_expect(results, "reduced preset lowers density", violence.blood_particle_density < 1.0 and violence.fragments_enabled == false)
	violence.apply_preset(ViolenceSettings.Preset.DISABLED)
	_expect(results, "disabled preset disables every impact channel", not violence.blood_particles_enabled and not violence.decals_enabled and not violence.fragments_enabled and not violence.impact_camera_shake_enabled and not violence.vocal_impact_audio_enabled)

func _test_health(results: Array[Dictionary]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var health := HealthComponent.new()
	tree.root.add_child(health)
	health.configure(50.0)
	var death_count: Array[int] = [0]
	health.died.connect(func() -> void: death_count[0] += 1)
	health.apply_damage(80.0)
	_expect(results, "health clamps damage at zero", is_zero_approx(health.current_health))
	_expect(results, "health emits one death signal", death_count[0] == 1)
	health.apply_damage(10.0)
	_expect(results, "dead health does not emit repeatedly", death_count[0] == 1)
	health.reset()
	_expect(results, "health reset restores configured maximum", is_equal_approx(health.current_health, 50.0))
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
	var hostile_profile := load("res://resources/default_hostile_profile.tres") as NpcProfile
	var civilian_profile := load("res://resources/default_civilian_profile.tres") as NpcProfile
	HostileGroupService.reset_run()
	var hostile_group := HostileGroupService.create_group()
	var hostile: Node = preload("res://scenes/Npc.tscn").instantiate()
	tree.root.add_child(hostile)
	var target_health := target.get_node("HealthComponent") as HealthComponent
	_npc_damage_events = 0
	if target_health != null:
		target_health.damaged.connect(_on_npc_damage)
	hostile.call("activate", hostile_profile, Vector3(0.0, 1.2, 1.5), "contract-hostile", hostile_group, target)
	hostile.call("tick", 0.1, true)
	_expect(results, "hostile enters engage state near player", int(hostile.get("state")) == 2)
	_expect(results, "hostile engagement damages the player", target_health != null and target_health.current_health < target_health.maximum_health)
	_expect(results, "hostile engagement applies exactly one damage event", _npc_damage_events == 1)
	var panic_distance_before: float = hostile.global_position.distance_to(target.global_position)
	HostileGroupService.record_impact(hostile_group, 0.0)
	HostileGroupService.record_impact(hostile_group, 1.0)
	_expect(results, "hostile group panic changes member state", int(hostile.get("state")) == 3)
	hostile.call("tick", 0.2, true)
	var panic_distance_after: float = hostile.global_position.distance_to(target.global_position)
	_expect(results, "panicked hostile moves away from player", panic_distance_after >= panic_distance_before)

	var civilian: Node = preload("res://scenes/Npc.tscn").instantiate()
	tree.root.add_child(civilian)
	civilian.call("activate", civilian_profile, Vector3(0.0, 1.2, 4.0), "contract-civilian", &"", target)
	civilian.call("tick", 0.1, true)
	_expect(results, "civilian stays in wandering state", int(civilian.get("state")) == 1)
	_expect(results, "civilian selects a wander target", (civilian.get("_wander_target") as Vector3) != Vector3.ZERO)
	hostile.queue_free()
	civilian.queue_free()
	target.queue_free()

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
	_expect(results, "impact particle pool has a hard limit", particle_pool.size() == 24)
	_expect(results, "impact decal pool has a hard limit", decal_pool.size() == 32)
	_expect(results, "impact fragment pool has a hard limit", fragment_pool.size() == 48)
	_expect(results, "impact audio pool has a hard limit", audio_pool.size() == 8)
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
	_expect(results, "HUD exposes health and preset labels", hud.get_node_or_null("MarginContainer/Panel/VBox/PlayerHealth") != null and hud.get_node_or_null("MarginContainer/Panel/VBox/VehicleHealth") != null and hud.get_node_or_null("MarginContainer/Panel/VBox/GorePreset") != null)
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
