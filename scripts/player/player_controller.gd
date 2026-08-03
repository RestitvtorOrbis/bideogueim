extends CharacterBody3D

@export_range(1.0, 20.0, 0.1) var walk_speed: float = 5.0
@export_range(1.0, 40.0, 0.1) var sprint_speed: float = 8.0
@export_range(1.0, 50.0, 0.1) var jump_velocity: float = 7.0
@export_range(0.001, 0.2, 0.001) var look_sensitivity: float = 0.006

@onready var health: HealthComponent = $HealthComponent
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D

var occupied_vehicle: Node
var _camera_pitch: float = -0.18

func _ready() -> void:
	add_to_group("player")
	health.configure(100.0)
	health.died.connect(_on_died)
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_game_over or occupied_vehicle != null:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		camera_rig.rotate_y(-motion.relative.x * look_sensitivity)
		_camera_pitch = clampf(_camera_pitch - motion.relative.y * look_sensitivity, -1.05, 0.75)
		camera_rig.rotation.x = _camera_pitch

func _physics_process(delta: float) -> void:
	if GameState.is_game_over:
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

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var basis := camera_rig.global_transform.basis
	var direction := (basis.x * input_vector.x + basis.z * input_vector.y)
	direction.y = 0.0
	direction = direction.normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * speed, 30.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, 30.0 * delta)
		var target_yaw := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 10.0, 0.0, 1.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	move_and_slide()

func apply_damage(amount: float) -> void:
	if occupied_vehicle != null and occupied_vehicle.has_method("apply_damage"):
		occupied_vehicle.apply_damage(amount)
	else:
		health.apply_damage(amount)

func set_occupied_vehicle(vehicle: Node) -> void:
	occupied_vehicle = vehicle
	var is_occupied := vehicle != null
	visible = not is_occupied
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
	GameState.finish_run()
