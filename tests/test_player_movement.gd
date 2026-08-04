extends RefCounted

var _player_controller_script: Script

func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	_player_controller_script = load("res://scripts/player/player_controller.gd") as Script
	_expect(results, "player controller script loads", _player_controller_script != null)
	if _player_controller_script == null:
		return results
	_test_camera_relative_axes(results)
	_test_yaw_alignment(results)
	_test_input_mappings(results)
	_test_runtime_camera_decoupling(results)
	return results

func _test_camera_relative_axes(results: Array[Dictionary]) -> void:
	var identity_basis := Basis.IDENTITY
	_expect(results, "W maps to camera forward", _is_vector_close(_camera_relative_direction(Vector2(0.0, -1.0), identity_basis), Vector3(0.0, 0.0, -1.0)))
	_expect(results, "S maps to camera backward", _is_vector_close(_camera_relative_direction(Vector2(0.0, 1.0), identity_basis), Vector3(0.0, 0.0, 1.0)))
	_expect(results, "A maps to camera left", _is_vector_close(_camera_relative_direction(Vector2(-1.0, 0.0), identity_basis), Vector3(-1.0, 0.0, 0.0)))
	_expect(results, "D maps to camera right", _is_vector_close(_camera_relative_direction(Vector2(1.0, 0.0), identity_basis), Vector3(1.0, 0.0, 0.0)))

	var rotated_basis := Basis(Vector3.UP, PI * 0.5)
	var rotated_forward := _camera_relative_direction(Vector2(0.0, -1.0), rotated_basis)
	_expect(results, "W follows camera yaw", _is_vector_close(rotated_forward, Vector3(-1.0, 0.0, 0.0)))

func _test_yaw_alignment(results: Array[Dictionary]) -> void:
	var right_yaw := _yaw_for_direction(Vector3.RIGHT)
	var back_yaw := _yaw_for_direction(Vector3.BACK)
	_expect(results, "visual yaw faces movement direction", is_zero_approx(_wrapped_angle_difference(right_yaw, -PI * 0.5)))
	_expect(results, "backward movement faces backward", is_zero_approx(_wrapped_angle_difference(back_yaw, PI)))
	_expect(results, "zero direction has stable yaw", is_zero_approx(_yaw_for_direction(Vector3.ZERO)))

func _test_input_mappings(results: Array[Dictionary]) -> void:
	_expect(results, "movement actions exist", InputMap.has_action("move_forward") and InputMap.has_action("move_backward") and InputMap.has_action("move_left") and InputMap.has_action("move_right"))
	_expect(results, "W is bound to forward", _has_physical_key("move_forward", 87))
	_expect(results, "S is bound to backward", _has_physical_key("move_backward", 83))
	_expect(results, "A is bound to left", _has_physical_key("move_left", 65))
	_expect(results, "D is bound to right", _has_physical_key("move_right", 68))

func _test_runtime_camera_decoupling(results: Array[Dictionary]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_expect(results, "player runtime fixture has a scene tree", false)
		return
	var game_state := tree.root.get_node_or_null("GameState")
	if game_state != null and game_state.has_method("reset_run"):
		game_state.call("reset_run")
	var player := preload("res://scenes/Player.tscn").instantiate() as CharacterBody3D
	tree.root.add_child(player)
	var camera_rig := player.get_node("CameraRig") as Node3D
	var camera_yaw := PI * 0.5
	camera_rig.global_rotation = Vector3(-0.18, camera_yaw, 0.0)
	player.rotation = Vector3.ZERO
	Input.action_press("move_forward", 1.0)
	player.call("_physics_process", 0.1)
	Input.action_release("move_forward")
	var motion := player.velocity
	_expect(results, "player camera rig is world-space followed", camera_rig.top_level)
	_expect(results, "runtime W travels along camera forward", motion.x < -0.01 and absf(motion.z) < 0.01)
	_expect(results, "body turns toward camera-relative motion", absf(_wrapped_angle_difference(player.rotation.y, camera_yaw)) < 0.01)
	_expect(results, "body rotation does not turn camera orbit", absf(_wrapped_angle_difference(camera_rig.global_rotation.y, camera_yaw)) < 0.01)
	player.set_physics_process(false)
	player.queue_free()

func _has_physical_key(action: StringName, keycode: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false

func _camera_relative_direction(input_vector: Vector2, camera_basis: Basis) -> Vector3:
	return _player_controller_script.call("camera_relative_direction", input_vector, camera_basis) as Vector3

func _yaw_for_direction(direction: Vector3) -> float:
	return float(_player_controller_script.call("yaw_for_direction", direction))

func _is_vector_close(actual: Vector3, expected: Vector3) -> bool:
	return actual.distance_to(expected) <= 0.001

func _wrapped_angle_difference(actual: float, expected: float) -> float:
	return wrapf(actual - expected, -PI, PI)

func _expect(results: Array[Dictionary], name: String, passed: bool) -> void:
	results.append({"name": name, "passed": passed, "message": "" if passed else "Assertion failed"})
