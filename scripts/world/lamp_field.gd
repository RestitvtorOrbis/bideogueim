class_name LampField
extends StaticBody3D

const MAX_LAMP_LEVEL: int = 5
const MAX_DAMAGE_POINTS: int = 8
const MIN_IMPACT_SPEED: float = 1.5
const MEDIUM_IMPACT_SPEED: float = 4.0
const HEAVY_IMPACT_SPEED: float = 8.0
const SUSTAINED_PUSH_SPEED: float = 0.5
const SUSTAINED_PUSH_FORCE: float = 2500.0
const SUSTAINED_PUSH_SECONDS: float = 0.75
const CONTACT_DELTA_FLOOR: float = 1.0 / 120.0

var _body_rid: RID
var _shared_shape_rid: RID
var _collision_shape_rids: Array[RID] = []
var _collision_transforms: Array[Transform3D] = []
var _base_post_transforms: Array[Transform3D] = []
var _base_glow_transforms: Array[Transform3D] = []
var _render_transforms: Array[Transform3D] = []
var _glow_transforms: Array[Transform3D] = []
var _post_multimesh: MultiMesh
var _glow_multimesh: MultiMesh
var _damage_points := PackedInt32Array()
var _lamp_levels := PackedByteArray()
var _distinct_hit_counts := PackedByteArray()
var _bend_degrees := PackedFloat32Array()
var _push_seconds := PackedFloat32Array()
var _contact_seen := PackedByteArray()
var _contact_active := PackedByteArray()
var _collision_disabled := PackedByteArray()
var _bend_axes := PackedVector3Array()
var _bend_directions := PackedVector3Array()
var _glow_lights: Dictionary = {}
var _initialized := false


func configure(
		post_transforms: Array,
		glow_transforms: Array,
		post_instance: MultiMeshInstance3D,
		glow_instance: MultiMeshInstance3D
	) -> void:
	if _initialized:
		return
	if post_instance == null or glow_instance == null:
		return
	if post_transforms.is_empty() or post_transforms.size() != glow_transforms.size():
		return

	_post_multimesh = post_instance.multimesh
	_glow_multimesh = glow_instance.multimesh
	if _post_multimesh == null or _glow_multimesh == null:
		return

	_base_post_transforms.clear()
	_base_glow_transforms.clear()
	_render_transforms.clear()
	_glow_transforms.clear()
	for index in range(post_transforms.size()):
		var post_transform: Transform3D = post_transforms[index]
		var glow_transform: Transform3D = glow_transforms[index]
		_base_post_transforms.append(post_transform)
		_base_glow_transforms.append(glow_transform)
		_render_transforms.append(post_transform)
		_glow_transforms.append(glow_transform)

	var lamp_count := _base_post_transforms.size()
	_damage_points.resize(lamp_count)
	_lamp_levels.resize(lamp_count)
	_distinct_hit_counts.resize(lamp_count)
	_bend_degrees.resize(lamp_count)
	_push_seconds.resize(lamp_count)
	_contact_seen.resize(lamp_count)
	_contact_active.resize(lamp_count)
	_collision_disabled.resize(lamp_count)
	_bend_axes.resize(lamp_count)
	_bend_directions.resize(lamp_count)

	_body_rid = get_rid()
	if not _body_rid.is_valid():
		return
	collision_layer = 1
	collision_mask = 31
	PhysicsServer3D.body_set_collision_layer(_body_rid, collision_layer)
	PhysicsServer3D.body_set_collision_mask(_body_rid, collision_mask)
	PhysicsServer3D.body_attach_object_instance_id(_body_rid, get_instance_id())

	_shared_shape_rid = PhysicsServer3D.cylinder_shape_create()
	PhysicsServer3D.shape_set_data(_shared_shape_rid, {"height": 3.6, "radius": 0.12})
	for index in range(lamp_count):
		_lamp_levels[index] = 1
		_collision_disabled[index] = 0
		var base_transform: Transform3D = _base_post_transforms[index]
		var base_collision_transform := Transform3D(base_transform.basis.orthonormalized(), base_transform.origin)
		PhysicsServer3D.body_add_shape(_body_rid, _shared_shape_rid, base_collision_transform, false)
		_collision_shape_rids.append(_shared_shape_rid)
		_collision_transforms.append(base_collision_transform)
		_post_multimesh.set_instance_transform(index, base_transform)
		_glow_multimesh.set_instance_transform(index, _base_glow_transforms[index])

	_initialized = true
	set_physics_process(true)


func register_glow_light(lamp_index: int, light: OmniLight3D) -> bool:
	if not _initialized or not _is_valid_shape_index(lamp_index) or light == null:
		return false
	_glow_lights[lamp_index] = light
	light.transform = _light_transform_for_glow(_glow_transforms[lamp_index])
	return true


func receive_vehicle_contact(
		vehicle: Node,
		collider_shape_index: int,
		vehicle_position: Vector3,
		vehicle_speed: float,
		impulse_proxy: Vector3,
		delta: float
	) -> void:
	if not _is_valid_vehicle(vehicle):
		return
	if not _is_valid_shape_index(collider_shape_index):
		return
	if vehicle_speed < 0.0 or _lamp_levels[collider_shape_index] >= MAX_LAMP_LEVEL:
		return

	var new_contact := _begin_contact(collider_shape_index)
	var horizontal_force := _get_horizontal_force_proxy(impulse_proxy, delta)
	var qualifies_for_push := vehicle_speed >= SUSTAINED_PUSH_SPEED or horizontal_force >= SUSTAINED_PUSH_FORCE
	if new_contact and vehicle_speed >= MIN_IMPACT_SPEED:
		_distinct_hit_counts[collider_shape_index] = mini(255, int(_distinct_hit_counts[collider_shape_index]) + 1)
		_set_bend_direction(collider_shape_index, vehicle_position, impulse_proxy)
		_add_damage(collider_shape_index, _damage_for_impact_speed(vehicle_speed))
	if not qualifies_for_push:
		_push_seconds[collider_shape_index] = 0.0
		return

	var safe_delta := maxf(delta, 0.0)
	_push_seconds[collider_shape_index] += safe_delta
	if _push_seconds[collider_shape_index] > 0.0:
		_set_bend_direction(collider_shape_index, vehicle_position, impulse_proxy)
	var completed_pushes := int(floor((_push_seconds[collider_shape_index] + 0.000001) / SUSTAINED_PUSH_SECONDS))
	if completed_pushes <= 0:
		return
	_push_seconds[collider_shape_index] = maxf(
		0.0,
		_push_seconds[collider_shape_index] - float(completed_pushes) * SUSTAINED_PUSH_SECONDS
	)
	_add_damage(collider_shape_index, completed_pushes * 2)


func receive_vehicle_impact(vehicle: Node, vehicle_speed: float, impulse_proxy: Vector3) -> void:
	if not _is_valid_vehicle(vehicle) or not _initialized or _base_post_transforms.is_empty() or vehicle_speed < 0.0:
		return
	var vehicle_position := (vehicle as Node3D).global_position
	var nearest_index := _find_nearest_lamp(vehicle_position)
	if _lamp_levels[nearest_index] >= MAX_LAMP_LEVEL:
		return
	var new_contact := _begin_contact(nearest_index)
	if new_contact and vehicle_speed >= MIN_IMPACT_SPEED:
		_distinct_hit_counts[nearest_index] = mini(255, int(_distinct_hit_counts[nearest_index]) + 1)
		_set_bend_direction(nearest_index, vehicle_position, impulse_proxy)
		_add_damage(nearest_index, _damage_for_impact_speed(vehicle_speed))


func get_lamp_count() -> int:
	return _base_post_transforms.size()


func get_collision_shape_count() -> int:
	if not _body_rid.is_valid():
		return 0
	return PhysicsServer3D.body_get_shape_count(_body_rid)


func get_lamp_index_for_shape(collider_shape_index: int) -> int:
	return collider_shape_index if _is_valid_shape_index(collider_shape_index) else -1


func get_render_transform(lamp_index: int) -> Transform3D:
	if not _is_valid_shape_index(lamp_index) or lamp_index >= _render_transforms.size():
		return Transform3D.IDENTITY
	return _render_transforms[lamp_index]


func get_glow_transform(lamp_index: int) -> Transform3D:
	if not _is_valid_shape_index(lamp_index) or lamp_index >= _glow_transforms.size():
		return Transform3D.IDENTITY
	return _glow_transforms[lamp_index]


func get_collision_transform(lamp_index: int) -> Transform3D:
	if not _is_valid_shape_index(lamp_index) or lamp_index >= _collision_transforms.size():
		return Transform3D.IDENTITY
	return _collision_transforms[lamp_index]


func get_bend_degrees(lamp_index: int) -> float:
	return _bend_degrees[lamp_index] if _is_valid_shape_index(lamp_index) else 0.0


func get_lamp_level(lamp_index: int) -> int:
	return int(_lamp_levels[lamp_index]) if _is_valid_shape_index(lamp_index) else 0


func get_damage_points(lamp_index: int) -> int:
	return _damage_points[lamp_index] if _is_valid_shape_index(lamp_index) else 0


func get_distinct_hit_count(lamp_index: int) -> int:
	return int(_distinct_hit_counts[lamp_index]) if _is_valid_shape_index(lamp_index) else 0


func get_sustained_push_seconds(lamp_index: int) -> float:
	return _push_seconds[lamp_index] if _is_valid_shape_index(lamp_index) else 0.0


func get_bend_direction(lamp_index: int) -> Vector3:
	return _bend_directions[lamp_index] if _is_valid_shape_index(lamp_index) else Vector3.ZERO


func is_collision_disabled(lamp_index: int) -> bool:
	return _collision_disabled[lamp_index] != 0 if _is_valid_shape_index(lamp_index) else false


func get_lamp_base_position(lamp_index: int) -> Vector3:
	if not _is_valid_shape_index(lamp_index):
		return Vector3.ZERO
	var base_transform: Transform3D = _base_post_transforms[lamp_index]
	var pivot := base_transform.origin - base_transform.basis * Vector3.UP
	return to_global(pivot)


func _physics_process(_delta: float) -> void:
	if not _initialized:
		return
	for index in range(_contact_seen.size()):
		if _contact_seen[index] == 0:
			_push_seconds[index] = 0.0
			_contact_active[index] = 0
		_contact_seen[index] = 0


func _begin_contact(lamp_index: int) -> bool:
	_contact_seen[lamp_index] = 1
	if _contact_active[lamp_index] != 0:
		return false
	_contact_active[lamp_index] = 1
	return true


func _get_horizontal_force_proxy(impulse_proxy: Vector3, delta: float) -> float:
	var horizontal_impulse := Vector3(impulse_proxy.x, 0.0, impulse_proxy.z)
	return horizontal_impulse.length() / maxf(delta, CONTACT_DELTA_FLOOR)


func _damage_for_impact_speed(vehicle_speed: float) -> int:
	if vehicle_speed < MIN_IMPACT_SPEED:
		return 0
	if vehicle_speed < MEDIUM_IMPACT_SPEED:
		return 4
	if vehicle_speed < HEAVY_IMPACT_SPEED:
		return 8
	return 16


func _level_for_damage(damage_points: int) -> int:
	if damage_points >= 8:
		return 5
	if damage_points >= 6:
		return 4
	if damage_points >= 4:
		return 3
	if damage_points >= 2:
		return 2
	return 1


func _target_angle_for_level(level: int) -> float:
	match level:
		2:
			return 18.0
		3:
			return 38.0
		4:
			return 62.0
		5:
			return 88.0
		_:
			return 0.0


func _add_damage(lamp_index: int, amount: int) -> void:
	if not _is_valid_shape_index(lamp_index) or amount <= 0 or _lamp_levels[lamp_index] >= MAX_LAMP_LEVEL:
		return
	_damage_points[lamp_index] = mini(MAX_DAMAGE_POINTS, _damage_points[lamp_index] + amount)
	var next_level := _level_for_damage(_damage_points[lamp_index])
	if next_level == _lamp_levels[lamp_index]:
		return
	_lamp_levels[lamp_index] = next_level
	_bend_degrees[lamp_index] = _target_angle_for_level(next_level)
	_update_lamp_transforms(lamp_index)
	if next_level >= MAX_LAMP_LEVEL:
		_collision_disabled[lamp_index] = 1
		PhysicsServer3D.body_set_shape_disabled(_body_rid, lamp_index, true)


func _set_bend_direction(lamp_index: int, vehicle_position: Vector3, impulse_proxy: Vector3) -> void:
	if not _is_valid_shape_index(lamp_index) or _bend_directions[lamp_index].length_squared() >= 0.0001:
		return
	var direction := _get_away_direction(lamp_index, vehicle_position, impulse_proxy)
	_bend_directions[lamp_index] = direction
	var axis := Vector3.UP.cross(direction)
	if axis.length_squared() < 0.0001:
		axis = Vector3.FORWARD
	_bend_axes[lamp_index] = axis.normalized()


func _update_lamp_transforms(lamp_index: int) -> void:
	var base_post: Transform3D = _base_post_transforms[lamp_index]
	var pivot := base_post.origin - base_post.basis * Vector3.UP
	var rotation_basis := Basis(_bend_axes[lamp_index], deg_to_rad(_bend_degrees[lamp_index]))
	var transform := Transform3D(
		rotation_basis * base_post.basis,
		pivot + rotation_basis * (base_post.basis * Vector3.UP)
	)
	var collision_transform := Transform3D(
		rotation_basis * base_post.basis.orthonormalized(),
		pivot + rotation_basis * (base_post.basis * Vector3.UP)
	)
	PhysicsServer3D.body_set_shape_transform(_body_rid, lamp_index, collision_transform)
	_collision_transforms[lamp_index] = collision_transform
	_post_multimesh.set_instance_transform(lamp_index, transform)
	_render_transforms[lamp_index] = transform

	var base_glow: Transform3D = _base_glow_transforms[lamp_index]
	var glow_offset := base_glow.origin - pivot
	var glow_transform := Transform3D(
		rotation_basis * base_glow.basis,
		pivot + rotation_basis * glow_offset
	)
	_glow_multimesh.set_instance_transform(lamp_index, glow_transform)
	_glow_transforms[lamp_index] = glow_transform
	var glow_light: Variant = _glow_lights.get(lamp_index, null)
	if glow_light is OmniLight3D and is_instance_valid(glow_light):
		(glow_light as OmniLight3D).transform = _light_transform_for_glow(glow_transform)


func _light_transform_for_glow(glow_transform: Transform3D) -> Transform3D:
	return Transform3D(glow_transform.basis.orthonormalized(), glow_transform.origin)


func _get_away_direction(lamp_index: int, vehicle_position: Vector3, impulse_proxy: Vector3) -> Vector3:
	var base_transform: Transform3D = _base_post_transforms[lamp_index]
	var vehicle_local := to_local(vehicle_position)
	var direction := base_transform.origin - vehicle_local
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = -(global_transform.basis.inverse() * impulse_proxy)
		direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = Vector3.RIGHT
	return direction.normalized()


func _find_nearest_lamp(vehicle_position: Vector3) -> int:
	var vehicle_local := to_local(vehicle_position)
	var nearest_index := 0
	var nearest_distance := INF
	for index in range(_base_post_transforms.size()):
		var distance := _base_post_transforms[index].origin.distance_squared_to(vehicle_local)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return nearest_index


func _is_valid_shape_index(lamp_index: int) -> bool:
	return lamp_index >= 0 and lamp_index < _base_post_transforms.size()


func _is_valid_vehicle(vehicle: Node) -> bool:
	return vehicle != null and vehicle is Node3D and vehicle.is_in_group("vehicle")


func _exit_tree() -> void:
	_glow_lights.clear()
	if _body_rid.is_valid():
		PhysicsServer3D.body_clear_shapes(_body_rid)
	if _shared_shape_rid.is_valid():
		PhysicsServer3D.free_rid(_shared_shape_rid)
	_shared_shape_rid = RID()
	_body_rid = RID()
