extends RigidBody3D

signal health_changed(current: float, maximum: float)
signal destroyed

@export var config: VehicleConfig

@onready var health: HealthComponent = $HealthComponent
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D

var occupied_driver: Node
var _wheel_rays: Array[RayCast3D] = []
var _last_speed: float = 0.0

func _ready() -> void:
	add_to_group("vehicle")
	if config == null:
		config = load("res://resources/default_vehicle_config.tres") as VehicleConfig
	if config == null:
		config = VehicleConfig.new()
	mass = config.mass
	center_of_mass_mode = 1
	center_of_mass = Vector3(0.0, -0.35, 0.0)
	contact_monitor = true
	max_contacts_reported = 8
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	health.configure(config.maximum_health)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_destroyed)
	camera.current = false
	for node in find_children("*", "RayCast3D", true, false):
		var ray := node as RayCast3D
		if ray == null:
			continue
		ray.add_to_group(&"vehicle_wheel_raycast")
		_wheel_rays.append(ray)
		ray.target_position = Vector3.DOWN * (config.suspension_rest_length + config.wheel_radius)
		ray.collision_mask = 1

func _physics_process(_delta: float) -> void:
	if GameState.is_game_over:
		return
	_apply_suspension()
	if occupied_driver == null:
		_apply_coast_drag()
		return

	var throttle := Input.get_action_strength("accelerate") - Input.get_action_strength("brake_reverse")
	var steering := Input.get_axis("steer_left", "steer_right")
	var forward := -global_transform.basis.z
	var forward_speed := linear_velocity.dot(forward)
	if absf(forward_speed) < config.maximum_speed or signf(throttle) != signf(forward_speed):
		apply_central_force(forward * throttle * config.engine_force)
	if Input.is_action_pressed("brake_reverse") and absf(forward_speed) > 0.5:
		apply_central_force(-linear_velocity.normalized() * config.brake_force)
	if Input.is_action_pressed("handbrake"):
		var lateral := global_transform.basis.x * linear_velocity.dot(global_transform.basis.x)
		apply_central_force(-lateral * (1.0 - config.handbrake_grip) * mass * 8.0)
	var steering_torque := steering * deg_to_rad(config.steering_angle_degrees) * maxf(absf(forward_speed), 1.0)
	apply_torque(Vector3.UP * steering_torque * mass * 0.18)
	_apply_coast_drag()
	_limit_speed()
	if Input.is_action_just_pressed("reset_vehicle"):
		reset_to_nearest_road()
	if Input.is_action_just_pressed("interact_vehicle"):
		exit_vehicle()

func _apply_suspension() -> void:
	for ray in _wheel_rays:
		if not ray.is_colliding():
			continue
		var hit_point := ray.get_collision_point()
		var distance := ray.global_position.distance_to(hit_point)
		var maximum_length := config.suspension_rest_length + config.wheel_radius
		var compression := clampf(1.0 - distance / maximum_length, 0.0, 1.0)
		var offset := ray.global_position - global_position
		var point_velocity := linear_velocity + angular_velocity.cross(offset)
		var damping_force := point_velocity.dot(Vector3.UP) * config.suspension_damping
		var force := maxf(0.0, compression * config.suspension_stiffness - damping_force)
		apply_force(Vector3.UP * force, offset)

func _apply_coast_drag() -> void:
	apply_central_force(-linear_velocity * config.rolling_drag * mass)

func _limit_speed() -> void:
	if linear_velocity.length() > config.maximum_speed:
		linear_velocity = linear_velocity.normalized() * config.maximum_speed

func try_enter(player: Node) -> bool:
	if player == null or occupied_driver != null or GameState.is_game_over:
		return false
	if global_position.distance_to(player.global_position) > 4.0:
		return false
	occupied_driver = player
	player.set_occupied_vehicle(self)
	camera.current = true
	return true

func exit_vehicle() -> bool:
	if occupied_driver == null:
		return false
	var side_positions := [
		global_position + global_transform.basis.x * 2.2,
		global_position - global_transform.basis.x * 2.2,
		global_position - global_transform.basis.z * 2.2
	]
	for candidate in side_positions:
		if _is_exit_position_clear(candidate):
			var driver := occupied_driver
			occupied_driver = null
			camera.current = false
			driver.exit_vehicle_at(candidate + Vector3.UP * 0.9)
			return true
	return false

func _is_exit_position_clear(position: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return true
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, position)
	query.collision_mask = 1
	return space.intersect_shape(query, 1).is_empty()

func reset_to_nearest_road() -> void:
	var reset_position := global_position
	reset_position.x = clampf(reset_position.x, -72.0, 72.0)
	reset_position.z = clampf(reset_position.z, -72.0, 72.0)
	if absf(reset_position.x) > absf(reset_position.z):
		reset_position.z = 0.0
	else:
		reset_position.x = 0.0
	reset_position.y = 1.25
	global_position = reset_position
	rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false

func apply_damage(amount: float) -> void:
	health.apply_damage(amount)

func get_damage_target() -> Node:
	return self if not GameState.is_game_over else null

func _on_body_entered(body: Node) -> void:
	var speed := linear_velocity.length()
	_last_speed = speed
	if body != null and body.has_method("receive_vehicle_impact"):
		body.receive_vehicle_impact(self, speed, linear_velocity * mass)
	elif body is RigidBody3D and speed > 8.0:
		var collision_damage := speed * config.impact_damage_multiplier
		health.apply_damage(collision_damage)

func _on_health_changed(current: float, maximum: float) -> void:
	health_changed.emit(current, maximum)

func _on_destroyed() -> void:
	if GameState.is_game_over:
		return
	destroyed.emit()
	GameState.finish_run()
