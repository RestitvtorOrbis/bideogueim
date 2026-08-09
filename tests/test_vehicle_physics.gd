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
	vehicle.call("exit_vehicle")
	player.queue_free()
	vehicle.queue_free()
	district.queue_free()
	return results

func _expect(results: Array[Dictionary], name: String, condition: bool) -> void:
	results.append({"name": name, "passed": condition, "message": "" if condition else "Assertion failed"})
