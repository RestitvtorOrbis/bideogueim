class_name LampField
extends StaticBody3D

const IMMEDIATE_BEND_SPEED: float = 7.0
const SUSTAINED_PUSH_SPEED: float = 1.0
const SUSTAINED_PUSH_SECONDS: float = 1.0
const MAX_BEND_DEGREES: float = 75.0
const BEND_RATE_DEGREES_PER_SECOND: float = 140.0
const INITIAL_IMPACT_BEND_DEGREES: float = 4.0

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
var _bend_degrees := PackedFloat32Array()
var _push_seconds := PackedFloat32Array()
var _contact_seen := PackedByteArray()
var _bend_axes := PackedVector3Array()
var _bend_directions := PackedVector3Array()
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
	_bend_degrees.resize(lamp_count)
	_push_seconds.resize(lamp_count)
	_contact_seen.resize(lamp_count)
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
		var base_transform: Transform3D = _base_post_transforms[index]
		var base_collision_transform := Transform3D(base_transform.basis.orthonormalized(), base_transform.origin)
		PhysicsServer3D.body_add_shape(_body_rid, _shared_shape_rid, base_collision_transform, false)
		_collision_shape_rids.append(_shared_shape_rid)
		_collision_transforms.append(base_collision_transform)
		_post_multimesh.set_instance_transform(index, base_transform)
		_glow_multimesh.set_instance_transform(index, _base_glow_transforms[index])

	_initialized = true
	set_physics_process(true)


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
	if vehicle_speed < 0.0:
		return

	_contact_seen[collider_shape_index] = 1
	if vehicle_speed < SUSTAINED_PUSH_SPEED:
		_push_seconds[collider_shape_index] = 0.0
		return

	var safe_delta := maxf(delta, 0.0)
	_push_seconds[collider_shape_index] += safe_delta
	var bend_now := vehicle_speed >= IMMEDIATE_BEND_SPEED
	if not bend_now and _push_seconds[collider_shape_index] < SUSTAINED_PUSH_SECONDS:
		return
	_request_bend(collider_shape_index, vehicle_position, impulse_proxy, safe_delta, bend_now)


func receive_vehicle_impact(vehicle: Node, vehicle_speed: float, impulse_proxy: Vector3) -> void:
	if not _is_valid_vehicle(vehicle) or not _initialized or _base_post_transforms.is_empty():
		return
	var vehicle_position := (vehicle as Node3D).global_position
	var nearest_index := _find_nearest_lamp(vehicle_position)
	if vehicle_speed >= IMMEDIATE_BEND_SPEED:
		_request_bend(nearest_index, vehicle_position, impulse_proxy, 0.0, true)


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


func get_sustained_push_seconds(lamp_index: int) -> float:
	return _push_seconds[lamp_index] if _is_valid_shape_index(lamp_index) else 0.0


func get_bend_direction(lamp_index: int) -> Vector3:
	return _bend_directions[lamp_index] if _is_valid_shape_index(lamp_index) else Vector3.ZERO


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
		_contact_seen[index] = 0


func _request_bend(
		lamp_index: int,
		vehicle_position: Vector3,
		impulse_proxy: Vector3,
		delta: float,
		immediate: bool
	) -> void:
	if not _is_valid_shape_index(lamp_index):
		return
	var direction := _get_away_direction(lamp_index, vehicle_position, impulse_proxy)
	if _bend_degrees[lamp_index] <= 0.0:
		_bend_directions[lamp_index] = direction
		_bend_axes[lamp_index] = Vector3.UP.cross(direction).normalized()
	var advance := maxf(delta, 1.0 / 60.0) * BEND_RATE_DEGREES_PER_SECOND
	if immediate:
		advance = maxf(advance, INITIAL_IMPACT_BEND_DEGREES)
	_bend_degrees[lamp_index] = minf(MAX_BEND_DEGREES, _bend_degrees[lamp_index] + advance)
	_update_lamp_transforms(lamp_index)


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
	if _body_rid.is_valid():
		PhysicsServer3D.body_clear_shapes(_body_rid)
	if _shared_shape_rid.is_valid():
		PhysicsServer3D.free_rid(_shared_shape_rid)
	_shared_shape_rid = RID()
	_body_rid = RID()
