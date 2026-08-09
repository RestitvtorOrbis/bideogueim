extends CharacterBody3D

const HEALTH_REGENERATION_RATE: float = 10.0
const HEALTH_REGENERATION_DELAY: float = 60.0

@export_range(1.0, 20.0, 0.1) var walk_speed: float = 5.0
@export_range(1.0, 40.0, 0.1) var sprint_speed: float = 8.0
@export_range(1.0, 50.0, 0.1) var jump_velocity: float = 7.0
@export_range(0.001, 0.2, 0.001) var look_sensitivity: float = 0.006

@onready var health: HealthComponent = $HealthComponent
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var visual_root := get_node_or_null("VisualRoot") as Node3D

var occupied_vehicle: Node
var _camera_pitch: float = -0.20
var _visual_visible_before_vehicle: bool = true

func _ready() -> void:
	add_to_group("player")
	health.configure(100.0)
	health.configure_regeneration(HEALTH_REGENERATION_RATE, HEALTH_REGENERATION_DELAY)
	health.died.connect(_on_died)
	if visual_root != null:
		_visual_visible_before_vehicle = visual_root.visible
	_configure_camera_rig()
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _configure_camera_rig() -> void:
	if camera_rig == null:
		return
	# The camera must orbit independently from the body. If it inherits the
	# body's yaw, turning the body toward camera-relative movement also turns
	# the movement reference and makes W appear to rotate the player.
	var camera_yaw := camera_rig.global_rotation.y
	if camera_rig.has_method("set_world_space_follow"):
		camera_rig.call("set_world_space_follow", true)
	else:
		camera_rig.top_level = true
		camera_rig.global_position = global_position + Vector3.UP * 1.70
	camera_rig.global_rotation = Vector3(_camera_pitch, camera_yaw, 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if _is_game_over() or occupied_vehicle != null:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		camera_rig.rotate_y(-motion.relative.x * look_sensitivity)
		_camera_pitch = clampf(_camera_pitch - motion.relative.y * look_sensitivity, -1.05, 0.75)
		camera_rig.rotation.x = _camera_pitch

func _physics_process(delta: float) -> void:
	if _is_game_over():
		velocity = Vector3.ZERO
		return
	if occupied_vehicle != null:
		return
	if Input.is_action_just_pressed("interact_vehicle"):
		_try_enter_nearest_vehicle()
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	var look_input := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look_input != Vector2.ZERO:
		var look_rate := 2.6 * delta
		camera_rig.rotate_y(-look_input.x * look_rate)
		_camera_pitch = clampf(_camera_pitch - look_input.y * look_rate, -1.05, 0.75)
		camera_rig.rotation.x = _camera_pitch

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := camera_relative_direction(input_vector, camera_rig.global_transform.basis)
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * speed, 30.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, 30.0 * delta)
		var target_yaw := yaw_for_direction(direction)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 10.0, 0.0, 1.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	move_and_slide()

static func camera_relative_direction(input_vector: Vector2, camera_basis: Basis) -> Vector3:
	var forward := Vector3(-camera_basis.z.x, 0.0, -camera_basis.z.z)
	if forward.length_squared() <= 0.000001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var right := Vector3(camera_basis.x.x, 0.0, camera_basis.x.z)
	if right.length_squared() <= 0.000001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var direction := right * input_vector.x + forward * -input_vector.y
	return direction.normalized() if direction.length_squared() > 0.000001 else Vector3.ZERO

static func yaw_for_direction(direction: Vector3) -> float:
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.000001:
		return 0.0
	return atan2(-flat_direction.x, -flat_direction.z)

func apply_damage(amount: float) -> void:
	if occupied_vehicle != null and occupied_vehicle.has_method("apply_damage"):
		occupied_vehicle.apply_damage(amount)
	else:
		health.apply_damage(amount)

func get_damage_target() -> Node:
	if occupied_vehicle != null and occupied_vehicle.has_method("get_damage_target"):
		return occupied_vehicle.call("get_damage_target") as Node
	return self if not _is_game_over() else null

func set_occupied_vehicle(vehicle: Node) -> void:
	var is_occupied := vehicle != null
	var was_occupied := occupied_vehicle != null
	if is_occupied and not was_occupied and visual_root != null:
		_visual_visible_before_vehicle = visual_root.visible
	occupied_vehicle = vehicle
	if visual_root != null:
		if is_occupied:
			visual_root.visible = false
		elif was_occupied:
			visual_root.visible = _visual_visible_before_vehicle
	collision_layer = 0 if is_occupied else 2
	collision_mask = 0 if is_occupied else 1
	set_physics_process(not is_occupied)
	if camera != null:
		camera.current = not is_occupied

func exit_vehicle_at(world_position: Vector3) -> void:
	global_position = world_position
	set_occupied_vehicle(null)

func _try_enter_nearest_vehicle() -> void:
	var nearest: Node
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("vehicle"):
		if not candidate.has_method("try_enter") or candidate.get("occupied_driver") != null:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance <= 4.0 and distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	if nearest != null:
		nearest.try_enter(self)

func _on_died() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("finish_run"):
		game_state.call("finish_run")

func _is_game_over() -> bool:
	var game_state := get_node_or_null("/root/GameState")
	return game_state != null and bool(game_state.get("is_game_over"))
