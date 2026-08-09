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

	if lamp_field != null and lamp_field.get_lamp_count() >= 3:
		var immediate_index := 0
		var immediate_base := lamp_field.get_lamp_base_position(immediate_index)
		lamp_field.receive_vehicle_contact(vehicle, immediate_index, immediate_base - Vector3(3.0, 0.0, 0.0), 7.0, Vector3.RIGHT, 1.0 / 60.0)
		_expect(results, "7 m/s lamp contact bends immediately", lamp_field.get_bend_degrees(immediate_index) > 0.0)
		_expect(results, "lamp bends away from the vehicle", lamp_field.get_bend_direction(immediate_index).x > 0.9)
		var immediate_angle := lamp_field.get_bend_degrees(immediate_index)
		for _index in 90:
			lamp_field.receive_vehicle_contact(vehicle, immediate_index, immediate_base - Vector3(3.0, 0.0, 0.0), 12.0, Vector3.RIGHT, 0.1)
		var capped_render := lamp_field.get_render_transform(immediate_index)
		var capped_collision := lamp_field.get_collision_transform(immediate_index)
		_expect(results, "lamp bend is capped at 75 degrees", lamp_field.get_bend_degrees(immediate_index) <= 75.001 and lamp_field.get_bend_degrees(immediate_index) >= immediate_angle)
		_expect(results, "render and collision transforms stay aligned", _transforms_match(capped_render, capped_collision))
		_expect(results, "maximum bend clears the full-height obstruction", absf(capped_collision.basis.y.y) * 2.0 < 1.0)

		var sustained_index := 1
		var sustained_base := lamp_field.get_lamp_base_position(sustained_index)
		for _index in 59:
			lamp_field.receive_vehicle_contact(vehicle, sustained_index, sustained_base - Vector3(3.0, 0.0, 0.0), 1.2, Vector3.RIGHT, 0.016)
		_expect(results, "sub-threshold lamp contact waits before bending", lamp_field.get_bend_degrees(sustained_index) == 0.0)
		for _index in 5:
			lamp_field.receive_vehicle_contact(vehicle, sustained_index, sustained_base - Vector3(3.0, 0.0, 0.0), 1.2, Vector3.RIGHT, 0.016)
		_expect(results, "sustained 1 m/s contact bends within 1.5 seconds", lamp_field.get_bend_degrees(sustained_index) > 0.0 and lamp_field.get_sustained_push_seconds(sustained_index) <= 1.5)

		var reset_index := 2
		var reset_base := lamp_field.get_lamp_base_position(reset_index)
		for _index in 30:
			lamp_field.receive_vehicle_contact(vehicle, reset_index, reset_base - Vector3(3.0, 0.0, 0.0), 1.2, Vector3.RIGHT, 0.016)
		lamp_field.call("_physics_process", 0.016)
		lamp_field.call("_physics_process", 0.016)
		for _index in 30:
			lamp_field.receive_vehicle_contact(vehicle, reset_index, reset_base - Vector3(3.0, 0.0, 0.0), 1.2, Vector3.RIGHT, 0.016)
		_expect(results, "contact gap resets only the sustained-push timer", lamp_field.get_bend_degrees(reset_index) == 0.0 and lamp_field.get_sustained_push_seconds(reset_index) < 1.0)
		_expect(results, "already bent lamps do not repair after a gap", lamp_field.get_bend_degrees(immediate_index) > 0.0)
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
