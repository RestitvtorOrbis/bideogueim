extends Node3D

@export var crowd_settings: CrowdSettings
@export var civilian_profile: NpcProfile
@export var hostile_profile: NpcProfile
@export var npc_scene: PackedScene

var active_npc_count: int:
	get:
		return _active_npcs.size()

var pool_allocations: int:
	get:
		return _civilian_pool.allocation_count + _hostile_pool.allocation_count

var _district: Node3D
var _player: Node
var _civilian_pool := NpcPool.new()
var _hostile_pool := NpcPool.new()
var _active_npcs: Dictionary = {}
var _lifecycle_counter: int = 1
var _hostile_groups: Array[StringName] = []
var _mid_clock: float = 0.0
var _far_clock: float = 0.0
var _spawn_cursor: int = 0

func _ready() -> void:
	if crowd_settings == null:
		crowd_settings = load("res://resources/default_crowd_settings.tres") as CrowdSettings
	if civilian_profile == null:
		civilian_profile = load("res://resources/default_civilian_profile.tres") as NpcProfile
	if hostile_profile == null:
		hostile_profile = load("res://resources/default_hostile_profile.tres") as NpcProfile
	if npc_scene == null:
		npc_scene = preload("res://scenes/Npc.tscn")
	add_child(_civilian_pool)
	add_child(_hostile_pool)
	_civilian_pool.configure(npc_scene, "civilian")
	_hostile_pool.configure(npc_scene, "hostile")

func configure(world: Node3D, player: Node, settings: CrowdSettings = null) -> void:
	_district = world
	_player = player
	if settings != null:
		crowd_settings = settings
	if is_instance_valid(HostileGroupService):
		HostileGroupService.reset_run()
		_hostile_groups.clear()
		for _index in range(6):
			_hostile_groups.append(HostileGroupService.create_group())
	_ensure_population()

func _physics_process(delta: float) -> void:
	if _district == null or _player == null or crowd_settings == null:
		return
	_ensure_population()
	_recycle_disabled_npcs()
	_mid_clock += delta
	_far_clock += delta
	var run_mid_update := _mid_clock >= crowd_settings.mid_update_interval
	var run_far_update := _far_clock >= crowd_settings.far_update_interval
	if run_mid_update:
		_mid_clock = 0.0
	if run_far_update:
		_far_clock = 0.0
	var camera := get_viewport().get_camera_3d()
	for npc in _active_npcs.keys():
		if npc == null or not is_instance_valid(npc):
			continue
		var npc_node := npc as Node3D
		if npc_node == null:
			continue
		var distance: float = npc_node.global_position.distance_to(_player.global_position)
		if distance <= crowd_settings.full_ai_distance:
			npc.tick(delta, true)
		elif distance <= crowd_settings.mid_ai_distance:
			if run_mid_update:
				npc.tick(crowd_settings.mid_update_interval, true)
		elif run_far_update:
			npc.tick(crowd_settings.far_update_interval, false)
		if camera != null and distance > crowd_settings.spawn_distance + 45.0 and not npc.is_disabled():
			_release_npc(npc)

func _ensure_population() -> void:
	var civilian_target := mini(crowd_settings.civilian_target_count, crowd_settings.active_npc_cap)
	var hostile_target := mini(
		crowd_settings.hostile_target_count,
		maxi(0, crowd_settings.active_npc_cap - civilian_target)
	)
	var civilians := _count_role("civilian")
	var hostiles := _count_role("hostile")
	while civilians < civilian_target and active_npc_count < crowd_settings.active_npc_cap:
		if _spawn_role("civilian"):
			civilians += 1
		else:
			break
	while hostiles < hostile_target and active_npc_count < crowd_settings.active_npc_cap:
		if _spawn_role("hostile"):
			hostiles += 1
		else:
			break

func _spawn_role(role: String) -> bool:
	var points: Array[Marker3D] = _district.get_spawn_points(role) if _district.has_method("get_spawn_points") else []
	if points.is_empty():
		return false
	var point: Marker3D = points[_spawn_cursor % points.size()]
	_spawn_cursor += 1
	var spawn_position := point.global_position
	spawn_position += Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
	if _is_in_active_camera_frustum(spawn_position):
		return false
	var pool := _civilian_pool if role == "civilian" else _hostile_pool
	var profile := civilian_profile if role == "civilian" else hostile_profile
	var group_id: StringName = &""
	if role == "hostile" and not _hostile_groups.is_empty():
		group_id = _hostile_groups[_lifecycle_counter % _hostile_groups.size()]
	var lifecycle_id := "%s_life_%d" % [role, _lifecycle_counter]
	_lifecycle_counter += 1
	var npc := pool.checkout(profile, spawn_position, lifecycle_id, group_id, _player)
	if npc == null:
		return false
	_active_npcs[npc] = role
	return true

func _release_npc(npc: Node) -> void:
	if not _active_npcs.has(npc):
		return
	var role: String = _active_npcs[npc]
	_active_npcs.erase(npc)
	if role == "civilian":
		_civilian_pool.release(npc)
	else:
		_hostile_pool.release(npc)

func _recycle_disabled_npcs() -> void:
	for npc in _active_npcs.keys():
		if npc != null and npc.has_method("is_disabled_for_recycle") and npc.is_disabled_for_recycle():
			_release_npc(npc)

func _count_role(role: String) -> int:
	var count := 0
	for value in _active_npcs.values():
		if value == role:
			count += 1
	return count

func _is_in_active_camera_frustum(world_position: Vector3) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	if camera.is_position_behind(world_position):
		return false
	var screen_position := camera.unproject_position(world_position)
	return get_viewport().get_visible_rect().grow(24.0).has_point(screen_position)

func release_all() -> void:
	_active_npcs.clear()
	_civilian_pool.release_all()
	_hostile_pool.release_all()

func get_active_npc_count() -> int:
	return active_npc_count
