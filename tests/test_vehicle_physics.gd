extends RefCounted

func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var tree := Engine.get_main_loop() as SceneTree
	var district: Node3D = preload("res://scenes/District.tscn").instantiate() as Node3D
	var player: Node3D = preload("res://scenes/Player.tscn").instantiate() as Node3D
	var vehicle: Node = preload("res://scenes/ArcadeVehicle.tscn").instantiate()
	tree.root.add_child(district)
	tree.root.add_child(player)
	tree.root.add_child(vehicle)
	var vehicle_body := vehicle as RigidBody3D
	_expect(results, "shipped vehicle enables continuous collision detection", vehicle_body != null and int(vehicle_body.continuous_cd) != 0)
	player.global_position = Vector3(0.0, 1.2, 0.0)
	vehicle.set("global_position", player.global_position)
	GameState.reset_run()
	await tree.physics_frame
	player.global_position = vehicle.get("global_position") as Vector3
	var entered := bool(vehicle.call("try_enter", player))
	_expect(results, "physics smoke enters vehicle", entered)
	_expect(results, "forward motion keeps brake force available", bool(vehicle.call("_should_apply_forward_brake", true, 4.0)))
	_expect(results, "reverse propulsion is not counter-braked", not bool(vehicle.call("_should_apply_forward_brake", true, -4.0)))
	Input.action_press("accelerate", 1.0)
	for _index in 30:
		await tree.physics_frame
	Input.action_release("accelerate")
	var speed: float = (vehicle.get("linear_velocity") as Vector3).length()
	var config := load("res://resources/default_vehicle_config.tres") as VehicleConfig
	_expect(results, "accelerate action produces propulsion", speed > 0.05)
	_expect(results, "physics propulsion respects maximum speed", config != null and speed <= config.maximum_speed + 0.25)

	var lamp_field := district.get_node_or_null("StreetFurniture/LampCollision") as LampField
	var lamp_posts := district.get_node_or_null("StreetFurniture/LampPosts") as MultiMeshInstance3D
	var lamp_glows := district.get_node_or_null("StreetFurniture/LampGlows") as MultiMeshInstance3D
	_expect(results, "lamp field has a compact collision owner", lamp_field != null and lamp_field is StaticBody3D)
	_expect(results, "lamp collision count matches generated lamps", lamp_field != null and lamp_field.get_collision_shape_count() == lamp_field.get_lamp_count())
	_expect(results, "lamp render instances match generated lamps", lamp_field != null and lamp_posts != null and lamp_glows != null and lamp_posts.multimesh.instance_count == lamp_field.get_lamp_count() and lamp_glows.multimesh.instance_count == lamp_field.get_lamp_count())
	_expect(results, "lamp shape mapping is stable at both ends", lamp_field != null and lamp_field.get_lamp_index_for_shape(0) == 0 and lamp_field.get_lamp_index_for_shape(lamp_field.get_collision_shape_count() - 1) == lamp_field.get_lamp_count() - 1)
	_expect(results, "vehicle exposes continuous static-contact forwarding", vehicle.has_method("_integrate_forces") and int(vehicle.get("max_contacts_reported")) >= 8)

	if lamp_field != null and lamp_field.get_lamp_count() >= 12:
		var initial_index := 0
		_expect(results, "every lamp starts at level 1", lamp_field.get_lamp_level(initial_index) == 1)
		_expect(results, "every lamp starts with zero damage and hits", lamp_field.get_damage_points(initial_index) == 0 and lamp_field.get_distinct_hit_count(initial_index) == 0)
		_expect(results, "every lamp starts upright and colliding", is_zero_approx(lamp_field.get_bend_degrees(initial_index)) and not lamp_field.is_collision_disabled(initial_index))

		var below_impact_index := 1
		_contact(lamp_field, vehicle, below_impact_index, 1.49, 0.0)
		_expect(results, "speed below 1.5 m/s adds no impact damage", lamp_field.get_damage_points(below_impact_index) == 0 and lamp_field.get_distinct_hit_count(below_impact_index) == 0)
		_gap(lamp_field)

		var light_impact_index := 2
		_contact(lamp_field, vehicle, light_impact_index, 1.5, 0.0)
		_expect(results, "1.5 m/s impact adds four points and reaches level 3", lamp_field.get_damage_points(light_impact_index) == 4 and lamp_field.get_distinct_hit_count(light_impact_index) == 1 and lamp_field.get_lamp_level(light_impact_index) == 3)
		_gap(lamp_field)

		var light_band_index := 3
		_contact(lamp_field, vehicle, light_band_index, 3.99, 0.0)
		_expect(results, "under 4 m/s impact stays in the four-point band", lamp_field.get_damage_points(light_band_index) == 4 and lamp_field.get_lamp_level(light_band_index) == 3)
		_gap(lamp_field)

		var medium_impact_index := 4
		_contact(lamp_field, vehicle, medium_impact_index, 4.0, 0.0)
		_expect(results, "4 m/s impact adds eight points and uproots the lamp", lamp_field.get_damage_points(medium_impact_index) == 8 and lamp_field.get_lamp_level(medium_impact_index) == 5 and is_equal_approx(lamp_field.get_bend_degrees(medium_impact_index), 88.0))
		_gap(lamp_field)

		var medium_band_index := 5
		_contact(lamp_field, vehicle, medium_band_index, 7.99, 0.0)
		_expect(results, "under 8 m/s impact stays in the eight-point band", lamp_field.get_damage_points(medium_band_index) == 8 and lamp_field.get_lamp_level(medium_band_index) == 5)
		_gap(lamp_field)

		var heavy_impact_index := 6
		_contact(lamp_field, vehicle, heavy_impact_index, 8.0, 0.0)
		_expect(results, "8 m/s impact saturates damage and uproots the lamp", lamp_field.get_damage_points(heavy_impact_index) == 8 and lamp_field.get_lamp_level(heavy_impact_index) == 5 and is_equal_approx(lamp_field.get_bend_degrees(heavy_impact_index), 88.0))
		_expect(results, "lamp bends away from the vehicle", lamp_field.get_bend_direction(heavy_impact_index).x > 0.9)
		_gap(lamp_field)

		var repeated_index := 7
		_contact(lamp_field, vehicle, repeated_index, 1.5, 0.0)
		_contact(lamp_field, vehicle, repeated_index, 1.5, 0.0)
		_expect(results, "repeated physics contacts count as one distinct hit", lamp_field.get_damage_points(repeated_index) == 4 and lamp_field.get_distinct_hit_count(repeated_index) == 1)
		_gap(lamp_field)
		_contact(lamp_field, vehicle, repeated_index, 1.5, 0.0)
		_expect(results, "a contact gap permits a later distinct hit", lamp_field.get_damage_points(repeated_index) == 8 and lamp_field.get_distinct_hit_count(repeated_index) == 2 and lamp_field.get_lamp_level(repeated_index) == 5)
		_gap(lamp_field)

		var resting_index := 8
		for _index in 4:
			_contact(lamp_field, vehicle, resting_index, 0.0, 0.75)
		_expect(results, "resting contact without speed or force is a no-op", lamp_field.get_damage_points(resting_index) == 0 and lamp_field.get_lamp_level(resting_index) == 1 and is_zero_approx(lamp_field.get_sustained_push_seconds(resting_index)))
		_gap(lamp_field)

		var force_index := 9
		var force_delta := 0.75
		var force_proxy := Vector3(2500.0 * force_delta, 0.0, 0.0)
		for expected_level in [2, 3, 4, 5]:
			_contact(lamp_field, vehicle, force_index, 0.0, force_delta, force_proxy)
			var expected_angle: float = [18.0, 38.0, 62.0, 88.0][expected_level - 2]
			_expect(results, "stationary force reaches exact level %d" % expected_level, lamp_field.get_lamp_level(force_index) == expected_level and lamp_field.get_damage_points(force_index) == (expected_level - 1) * 2 and is_equal_approx(lamp_field.get_bend_degrees(force_index), expected_angle))
		_expect(results, "stationary force reaches level 5 within 3 seconds", lamp_field.get_damage_points(force_index) == 8 and lamp_field.is_collision_disabled(force_index))
		var force_render := lamp_field.get_render_transform(force_index)
		var force_collision := lamp_field.get_collision_transform(force_index)
		_expect(results, "level 5 render and collision transforms stay aligned", _transforms_match(force_render, force_collision))
		_expect(results, "level 5 uproots the lamp", absf(force_collision.basis.y.y) * 2.0 < 0.1)
		var force_level := lamp_field.get_lamp_level(force_index)
		var force_damage := lamp_field.get_damage_points(force_index)
		var force_hits := lamp_field.get_distinct_hit_count(force_index)
		_gap(lamp_field)
		_expect(results, "lamp level and pose persist after a contact gap", lamp_field.get_lamp_level(force_index) == force_level and lamp_field.get_damage_points(force_index) == force_damage and is_equal_approx(lamp_field.get_bend_degrees(force_index), 88.0))
		_contact(lamp_field, vehicle, force_index, 12.0, 0.75, force_proxy)
		_expect(results, "post-uproot contacts are harmless no-ops", lamp_field.get_lamp_level(force_index) == force_level and lamp_field.get_damage_points(force_index) == force_damage and lamp_field.get_distinct_hit_count(force_index) == force_hits and lamp_field.is_collision_disabled(force_index))

		var shape_count := lamp_field.get_collision_shape_count()
		_expect(results, "level 5 preserves total collision shape count", shape_count == lamp_field.get_lamp_count())
		_expect(results, "level 5 preserves stable shape mapping", lamp_field.get_lamp_index_for_shape(force_index) == force_index and lamp_field.get_lamp_index_for_shape(shape_count - 1) == lamp_field.get_lamp_count() - 1)
	vehicle.call("exit_vehicle")
	player.queue_free()
	vehicle.queue_free()
	district.queue_free()
	return results

func _expect(results: Array[Dictionary], name: String, condition: bool) -> void:
	results.append({"name": name, "passed": condition, "message": "" if condition else "Assertion failed"})

func _transforms_match(first: Transform3D, second: Transform3D) -> bool:
	return first.origin.distance_to(second.origin) < 0.001 \
		and first.basis.x.normalized().distance_to(second.basis.x.normalized()) < 0.001 \
		and first.basis.y.normalized().distance_to(second.basis.y.normalized()) < 0.001 \
		and first.basis.z.normalized().distance_to(second.basis.z.normalized()) < 0.001

func _contact(field: LampField, vehicle: Node, lamp_index: int, speed: float, delta: float, impulse_proxy: Vector3 = Vector3.ZERO) -> void:
	var base := field.get_lamp_base_position(lamp_index)
	field.receive_vehicle_contact(vehicle, lamp_index, base - Vector3(3.0, 0.0, 0.0), speed, impulse_proxy, delta)

func _gap(field: LampField) -> void:
	field.call("_physics_process", 0.016)
	field.call("_physics_process", 0.016)
