extends Node3D

const SPAWN_ANGULAR_SECTOR_COUNT := 8
const SPAWN_RADIAL_BAND_COUNT := 2

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
var _spawn_rng := RandomNumberGenerator.new()
var _role_cursor: int = 0
var _initial_spawned_count: int = 0
var _initial_visible_slots_used: int = 0
var _configured: bool = false
var _elapsed_since_configure: float = 0.0
var _pending_death_replacements: Dictionary = {
	"civilian": 0,
	"hostile": 0,
}

func _ready() -> void:
	_spawn_rng.randomize()
	if crowd_settings == null:
		crowd_settings = load("res://resources/default_crowd_settings.tres") as CrowdSettings
	if crowd_settings == null:
		crowd_settings = CrowdSettings.new()
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
	if _configured or not _active_npcs.is_empty():
		release_all()
	_district = world
	_player = player
	if settings != null:
		crowd_settings = settings
	_initial_spawned_count = 0
	_initial_visible_slots_used = 0
	_role_cursor = 0
	_mid_clock = 0.0
	_far_clock = 0.0
	_elapsed_since_configure = 0.0
	_clear_pending_death_replacements()
	_configured = _district != null and _player != null and crowd_settings != null
	if not _configured:
		return
	var hostile_service := _get_hostile_group_service()
	if hostile_service != null:
		hostile_service.call("reset_run")
		_hostile_groups.clear()
		for _index in range(6):
			_hostile_groups.append(hostile_service.call("create_group"))
	var initial_count := mini(
		maxi(0, crowd_settings.initial_population_count),
		_get_effective_target_total()
	)
	# The first batch is deliberate: the player sees a living city immediately,
	# while all later replacements are capped in _physics_process.
	_ensure_population(initial_count, true, initial_count)

func _physics_process(delta: float) -> void:
	if not _configured or _district == null or _player == null or crowd_settings == null:
		return
	advance_elapsed_time(delta)
	# Recycle before replenishing so a dead or distant NPC frees its slot this frame.
	_recycle_disabled_npcs()
	_recycle_out_of_range_npcs()
	var spawn_budget := clampi(crowd_settings.spawn_budget_per_frame, 0, maxi(0, crowd_settings.active_npc_cap))
	_ensure_population(spawn_budget)
	_mid_clock += delta
	_far_clock += delta
	var run_mid_update := _mid_clock >= maxf(0.02, crowd_settings.mid_update_interval)
	var run_far_update := _far_clock >= maxf(0.05, crowd_settings.far_update_interval)
	if run_mid_update:
		_mid_clock = 0.0
	if run_far_update:
		_far_clock = 0.0
	var player_node := _player as Node3D
	if player_node == null:
		return
	for npc in _active_npcs.keys():
		if not is_instance_valid(npc) or not npc.has_method("tick"):
			continue
		var npc_node := npc as Node3D
		if npc_node == null:
			continue
		if npc.has_method("configure_run_safety"):
			npc.call("configure_run_safety", _is_hostile_grace_active(), crowd_settings.hostile_safe_radius)
		var distance: float = npc_node.global_position.distance_to(player_node.global_position)
		if npc.has_method("update_visual_tier"):
			npc.call(
				"update_visual_tier",
				distance,
				crowd_settings.full_ai_distance,
				crowd_settings.mid_ai_distance,
				crowd_settings.visual_hide_distance
			)
		if distance <= crowd_settings.full_ai_distance:
			npc.call("tick", delta, true)
		elif distance <= crowd_settings.mid_ai_distance:
			if run_mid_update:
				npc.call("tick", maxf(0.02, crowd_settings.mid_update_interval), true)
		elif run_far_update:
			npc.call("tick", maxf(0.05, crowd_settings.far_update_interval), false)

func _ensure_population(spawn_budget: int, initial_phase: bool = false, initial_limit: int = -1) -> int:
	if spawn_budget <= 0 or _district == null or _player == null:
		return 0
	var cap := maxi(0, crowd_settings.active_npc_cap)
	var target_total := _get_effective_target_total()
	if initial_phase:
		target_total = mini(target_total, maxi(0, initial_limit))
	if target_total <= 0:
		return 0
	var spawned := 0
	var blocked_roles: Dictionary = {}
	var blocked_replacement_roles: Dictionary = {}
	while spawned < spawn_budget and active_npc_count < cap:
		var replacement_role := _next_pending_death_replacement(blocked_replacement_roles)
		if not replacement_role.is_empty():
			if _spawn_role(replacement_role, false, false, true):
				_pending_death_replacements[replacement_role] = maxi(
					0,
					int(_pending_death_replacements.get(replacement_role, 0)) - 1
				)
				spawned += 1
				blocked_replacement_roles.clear()
				continue
			blocked_replacement_roles[replacement_role] = true
			if _all_pending_death_replacements_blocked(blocked_replacement_roles):
				break
			continue
		if active_npc_count >= target_total:
			break
		var role := _choose_role_for_spawn(initial_phase, initial_limit, blocked_roles)
		if role.is_empty():
			break
		var prefer_visible := initial_phase and _initial_visible_slots_used < maxi(0, crowd_settings.initial_visible_count)
		if _spawn_role(role, prefer_visible, initial_phase):
			spawned += 1
			if initial_phase:
				_initial_spawned_count += 1
				_initial_visible_slots_used += 1 if prefer_visible else 0
			blocked_roles.clear()
			continue
		# A role without usable points must not prevent the other role from spawning.
		blocked_roles[role] = true
		_role_cursor = 1 - _role_cursor
		if blocked_roles.has("civilian") and blocked_roles.has("hostile"):
			break
	return spawned

func _next_pending_death_replacement(blocked_roles: Dictionary) -> String:
	for role in ["civilian", "hostile"]:
		if int(_pending_death_replacements.get(role, 0)) > 0 and not blocked_roles.has(role):
			return role
	return ""

func _all_pending_death_replacements_blocked(blocked_roles: Dictionary) -> bool:
	for role in ["civilian", "hostile"]:
		if int(_pending_death_replacements.get(role, 0)) > 0 and not blocked_roles.has(role):
			return false
	return true

func _choose_role_for_spawn(initial_phase: bool, initial_limit: int, blocked_roles: Dictionary) -> String:
	var targets := _effective_targets()
	var civilian_target := int(targets["civilian"])
	var hostile_target := int(targets["hostile"])
	if initial_phase:
		var initial_total := mini(maxi(0, initial_limit), civilian_target + hostile_target)
		var configured_total := civilian_target + hostile_target
		if configured_total > 0:
			civilian_target = mini(civilian_target, int(round(float(initial_total) * float(civilian_target) / float(configured_total))))
			hostile_target = mini(hostile_target, initial_total - civilian_target)
			if civilian_target + hostile_target < initial_total:
				civilian_target = mini(int(targets["civilian"]), initial_total - hostile_target)
	var civilian_deficit := civilian_target - _count_role("civilian")
	var hostile_deficit := hostile_target - _count_role("hostile")
	var civilian_available := civilian_deficit > 0 and not blocked_roles.has("civilian")
	var hostile_available := hostile_deficit > 0 and not blocked_roles.has("hostile")
	if not civilian_available and not hostile_available:
		return ""
	if civilian_available and not hostile_available:
		return "civilian"
	if hostile_available and not civilian_available:
		return "hostile"
	var civilian_ratio := float(_count_role("civilian")) / float(maxi(1, civilian_target))
	var hostile_ratio := float(_count_role("hostile")) / float(maxi(1, hostile_target))
	if civilian_ratio < hostile_ratio:
		_role_cursor = 0
	elif hostile_ratio < civilian_ratio:
		_role_cursor = 1
	var selected := "civilian" if _role_cursor == 0 else "hostile"
	_role_cursor = 1 - _role_cursor
	return selected

func _spawn_role(
		role: String,
		prefer_visible: bool = false,
		near_player: bool = false,
		strict_death_replacement: bool = false
	) -> bool:
	var points := _get_spawn_points(role)
	if points.is_empty():
		return false
	var spawn_result := _find_spawn_position(
		points,
		prefer_visible,
		near_player,
		_get_spawn_minimum_distance(role, near_player, strict_death_replacement),
		strict_death_replacement
	)
	if not bool(spawn_result.get("found", false)):
		return false
	var pool := _civilian_pool if role == "civilian" else _hostile_pool
	var profile := civilian_profile if role == "civilian" else hostile_profile
	var group_id: StringName = &""
	if role == "hostile" and not _hostile_groups.is_empty():
		group_id = _hostile_groups[(_lifecycle_counter - 1) % _hostile_groups.size()]
	var lifecycle_id := "%s_life_%d" % [role, _lifecycle_counter]
	_lifecycle_counter += 1
	var npc := pool.checkout(profile, spawn_result["position"], lifecycle_id, group_id, _player)
	if npc == null:
		return false
	if npc.has_method("configure_run_safety"):
		npc.call("configure_run_safety", _is_hostile_grace_active(), crowd_settings.hostile_safe_radius)
	_active_npcs[npc] = role
	return true

func _find_spawn_position(
		points: Array[Marker3D],
		prefer_visible: bool,
		near_player: bool,
		spawn_minimum_distance: float = -1.0,
		strict_offscreen: bool = false
	) -> Dictionary:
	var shuffled_points := _shuffled_points(points)
	var attempts := maxi(1, crowd_settings.spawn_candidate_attempts)
	var best_position := Vector3.ZERO
	var best_occupancy := 0
	var best_nearest_distance := -INF
	var best_visibility_preference := false
	var has_best := false
	for attempt in range(attempts):
		var point: Marker3D = shuffled_points[attempt % shuffled_points.size()]
		var candidate := _build_spawn_candidate(point, near_player, spawn_minimum_distance)
		if not _is_valid_npc_spawn_position(candidate):
			continue
		if not _is_in_spawn_range(candidate):
			continue
		if strict_offscreen and not _is_at_least_player_distance(candidate, spawn_minimum_distance):
			continue
		var is_visible := _is_in_active_camera_frustum(candidate)
		if strict_offscreen and is_visible:
			continue
		if not _is_separated_from_active(candidate):
			continue
		var bucket := _get_spawn_bucket(candidate)
		var occupancy := _get_spawn_bucket_occupancy(bucket)
		var nearest_distance := _get_nearest_active_npc_distance(candidate)
		var visibility_preference := is_visible == prefer_visible
		if not has_best or _is_better_spawn_candidate(
				occupancy,
				nearest_distance,
				visibility_preference,
				best_occupancy,
				best_nearest_distance,
				best_visibility_preference
			):
			best_position = candidate
			best_occupancy = occupancy
			best_nearest_distance = nearest_distance
			best_visibility_preference = visibility_preference
			has_best = true
	if has_best:
		return {"found": true, "position": best_position}
	# A candidate that fails hard validity, range, player-distance, or separation
	# constraints defers spawning until a later frame.
	return {"found": false, "position": Vector3.ZERO}

func _is_better_spawn_candidate(
		candidate_occupancy: int,
		candidate_nearest_distance: float,
		candidate_visibility_preference: bool,
		best_occupancy: int,
		best_nearest_distance: float,
		best_visibility_preference: bool
	) -> bool:
	if candidate_occupancy != best_occupancy:
		return candidate_occupancy < best_occupancy
	if candidate_nearest_distance > best_nearest_distance + 0.001:
		return true
	if best_nearest_distance > candidate_nearest_distance + 0.001:
		return false
	if candidate_visibility_preference != best_visibility_preference:
		return candidate_visibility_preference
	# Keep the first candidate for an exact score tie. Candidate iteration is
	# deterministic for deterministic point order and RNG state.
	return false

func _get_spawn_bucket(world_position: Vector3) -> int:
	var player_node := _player as Node3D
	if player_node == null:
		return 0
	var offset := world_position - player_node.global_position
	offset.y = 0.0
	var angle := fposmod(atan2(offset.z, offset.x) + PI, TAU)
	var sector := clampi(
		int(floor(angle / TAU * float(SPAWN_ANGULAR_SECTOR_COUNT))),
		0,
		SPAWN_ANGULAR_SECTOR_COUNT - 1
	)
	var active_radius := _get_active_spawn_radius()
	var radial_band := 0 if offset.length() <= active_radius * 0.5 else 1
	return radial_band * SPAWN_ANGULAR_SECTOR_COUNT + sector

func _get_active_spawn_radius() -> float:
	return maxf(1.0, crowd_settings.spawn_distance - crowd_settings.spawn_edge_padding)

func _get_spawn_bucket_occupancy(bucket: int) -> int:
	var occupancy := 0
	for npc in _active_npcs.keys():
		if not is_instance_valid(npc):
			continue
		var npc_node := npc as Node3D
		if npc_node != null and _get_spawn_bucket(npc_node.global_position) == bucket:
			occupancy += 1
	return occupancy

func _get_nearest_active_npc_distance(world_position: Vector3) -> float:
	var nearest_distance := INF
	for npc in _active_npcs.keys():
		if not is_instance_valid(npc):
			continue
		var npc_node := npc as Node3D
		if npc_node == null:
			continue
		var offset := npc_node.global_position - world_position
		offset.y = 0.0
		nearest_distance = minf(nearest_distance, offset.length())
	return nearest_distance

func _is_valid_npc_spawn_position(position: Vector3) -> bool:
	if _district == null or not _district.has_method("is_npc_spawn_position_valid"):
		return true
	return bool(_district.call("is_npc_spawn_position_valid", position, 0.5))

func _build_spawn_candidate(point: Marker3D, near_player: bool, spawn_minimum_distance: float = -1.0) -> Vector3:
	var anchor := point.global_position
	var player_node := _player as Node3D
	if player_node == null:
		return anchor + Vector3(
			_spawn_rng.randf_range(-crowd_settings.spawn_jitter_radius, crowd_settings.spawn_jitter_radius),
			0.0,
			_spawn_rng.randf_range(-crowd_settings.spawn_jitter_radius, crowd_settings.spawn_jitter_radius)
		)
	var player_position := player_node.global_position
	var horizontal_anchor := anchor - player_position
	horizontal_anchor.y = 0.0
	var anchor_distance := horizontal_anchor.length()
	var maximum_distance := maxf(1.0, crowd_settings.spawn_distance - crowd_settings.spawn_edge_padding)
	if near_player:
		maximum_distance = minf(maximum_distance, maxf(1.0, crowd_settings.initial_spawn_distance))
	var requested_minimum := crowd_settings.minimum_spawn_distance if spawn_minimum_distance < 0.0 else spawn_minimum_distance
	var minimum_distance := clampf(requested_minimum, 0.0, maximum_distance)
	var candidate := anchor
	if near_player or anchor_distance > maximum_distance:
		var angle := _spawn_rng.randf_range(0.0, TAU)
		if anchor_distance > 0.01:
			angle = atan2(horizontal_anchor.z, horizontal_anchor.x) + _spawn_rng.randf_range(-0.42, 0.42)
		var radius := _spawn_rng.randf_range(minimum_distance, maximum_distance)
		candidate = player_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
	else:
		candidate += Vector3(
			_spawn_rng.randf_range(-crowd_settings.spawn_jitter_radius, crowd_settings.spawn_jitter_radius),
			0.0,
			_spawn_rng.randf_range(-crowd_settings.spawn_jitter_radius, crowd_settings.spawn_jitter_radius)
		)
	candidate.y = anchor.y
	return _clamp_to_spawn_ring(candidate, player_position, minimum_distance, maximum_distance)

func _clamp_to_spawn_ring(candidate: Vector3, center: Vector3, minimum_distance: float, maximum_distance: float) -> Vector3:
	var offset := candidate - center
	offset.y = 0.0
	var distance := offset.length()
	if distance < 0.01:
		var angle := _spawn_rng.randf_range(0.0, TAU)
		offset = Vector3(cos(angle), 0.0, sin(angle)) * minimum_distance
	elif distance < minimum_distance:
		offset = offset.normalized() * minimum_distance
	elif distance > maximum_distance:
		offset = offset.normalized() * maximum_distance
	return Vector3(center.x + offset.x, candidate.y, center.z + offset.z)

func _get_spawn_points(role: String) -> Array[Marker3D]:
	var points: Array[Marker3D] = []
	if _district == null or not _district.has_method("get_spawn_points"):
		return points
	var raw_points = _district.call("get_spawn_points", role)
	if raw_points is Array:
		for candidate in raw_points:
			var point := candidate as Marker3D
			if point != null and is_instance_valid(point):
				points.append(point)
	return points

func _get_spawn_minimum_distance(
		role: String,
		initial_phase: bool,
		strict_death_replacement: bool = false
	) -> float:
	var configured_minimum := maxf(0.0, crowd_settings.minimum_spawn_distance)
	if strict_death_replacement:
		return maxf(configured_minimum, crowd_settings.death_replacement_minimum_spawn_distance)
	if initial_phase:
		if role == "hostile":
			return maxf(configured_minimum, crowd_settings.initial_hostile_minimum_spawn_distance)
		return maxf(configured_minimum, crowd_settings.initial_civilian_minimum_spawn_distance)
	if role == "hostile":
		return maxf(configured_minimum, crowd_settings.hostile_respawn_minimum_spawn_distance)
	return configured_minimum

func _shuffled_points(points: Array[Marker3D]) -> Array[Marker3D]:
	var shuffled: Array[Marker3D] = points.duplicate()
	for index in range(shuffled.size() - 1, 0, -1):
		var swap_index := _spawn_rng.randi_range(0, index)
		var temporary: Marker3D = shuffled[index]
		shuffled[index] = shuffled[swap_index]
		shuffled[swap_index] = temporary
	return shuffled

func _is_in_spawn_range(position: Vector3) -> bool:
	var player_node := _player as Node3D
	if player_node == null:
		return true
	var offset := position - player_node.global_position
	offset.y = 0.0
	var maximum_distance := maxf(1.0, crowd_settings.spawn_distance - crowd_settings.spawn_edge_padding)
	return offset.length_squared() <= maximum_distance * maximum_distance + 0.01

func _is_at_least_player_distance(position: Vector3, minimum_distance: float) -> bool:
	var player_node := _player as Node3D
	if player_node == null:
		return false
	var offset := position - player_node.global_position
	offset.y = 0.0
	var required_distance := maxf(0.0, minimum_distance)
	return offset.length_squared() + 0.01 >= required_distance * required_distance

func _is_separated_from_active(position: Vector3) -> bool:
	var separation := maxf(0.0, crowd_settings.minimum_npc_separation)
	if separation <= 0.0:
		return true
	var separation_squared := separation * separation
	for npc in _active_npcs.keys():
		if not is_instance_valid(npc):
			continue
		var npc_node := npc as Node3D
		if npc_node == null:
			continue
		var offset := npc_node.global_position - position
		offset.y = 0.0
		if offset.length_squared() < separation_squared:
			return false
	return true

func _is_in_active_camera_frustum(world_position: Vector3) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	if camera.is_position_behind(world_position):
		return false
	var screen_position := camera.unproject_position(world_position)
	return get_viewport().get_visible_rect().grow(24.0).has_point(screen_position)

func _recycle_out_of_range_npcs() -> void:
	var player_node := _player as Node3D
	if player_node == null:
		return
	var recycle_distance := maxf(crowd_settings.despawn_distance, crowd_settings.spawn_distance + 1.0)
	var recycle_distance_squared := recycle_distance * recycle_distance
	for npc in _active_npcs.keys():
		if not is_instance_valid(npc):
			_active_npcs.erase(npc)
			continue
		var npc_node := npc as Node3D
		if npc_node == null:
			continue
		var offset := npc_node.global_position - player_node.global_position
		offset.y = 0.0
		if offset.length_squared() > recycle_distance_squared:
			_release_npc(npc)

func _recycle_disabled_npcs() -> void:
	for npc in _active_npcs.keys():
		if is_instance_valid(npc) and npc.has_method("is_disabled_for_recycle") and npc.call("is_disabled_for_recycle"):
			var replacement_role := ""
			if npc.has_method("was_killed") and bool(npc.call("was_killed")):
				replacement_role = String(_active_npcs.get(npc, ""))
			_release_npc(npc)
			if not replacement_role.is_empty():
				_pending_death_replacements[replacement_role] = int(
					_pending_death_replacements.get(replacement_role, 0)
				) + 1

func _release_npc(npc: Node) -> void:
	if not _active_npcs.has(npc):
		return
	var role: String = String(_active_npcs[npc])
	_active_npcs.erase(npc)
	if role == "civilian":
		_civilian_pool.release(npc)
	else:
		_hostile_pool.release(npc)

func _effective_targets() -> Dictionary:
	var cap := maxi(0, crowd_settings.active_npc_cap)
	var civilian_target := mini(maxi(0, crowd_settings.civilian_target_count), cap)
	var hostile_target := mini(maxi(0, crowd_settings.hostile_target_count), maxi(0, cap - civilian_target))
	return {"civilian": civilian_target, "hostile": hostile_target}

func _get_effective_target_total() -> int:
	var targets := _effective_targets()
	return int(targets["civilian"]) + int(targets["hostile"])

func _count_role(role: String) -> int:
	var count := 0
	for value in _active_npcs.values():
		if value == role:
			count += 1
	return count

func _get_hostile_group_service() -> Node:
	return get_node_or_null("/root/HostileGroupService")

func release_all() -> void:
	_active_npcs.clear()
	_civilian_pool.release_all()
	_hostile_pool.release_all()
	_initial_spawned_count = 0
	_initial_visible_slots_used = 0
	_elapsed_since_configure = 0.0
	_clear_pending_death_replacements()

func _clear_pending_death_replacements() -> void:
	_pending_death_replacements["civilian"] = 0
	_pending_death_replacements["hostile"] = 0

func advance_elapsed_time(delta: float) -> void:
	if delta <= 0.0:
		return
	_elapsed_since_configure += delta
	_sync_npc_safety()

func set_elapsed_time(elapsed: float) -> void:
	_elapsed_since_configure = maxf(0.0, elapsed)
	_sync_npc_safety()

func get_elapsed_since_configure() -> float:
	return _elapsed_since_configure

func is_hostile_grace_active() -> bool:
	return _is_hostile_grace_active()

func _is_hostile_grace_active() -> bool:
	return crowd_settings != null and _elapsed_since_configure < maxf(0.0, crowd_settings.hostile_grace_period)

func _sync_npc_safety() -> void:
	if crowd_settings == null:
		return
	for npc in _active_npcs.keys():
		if is_instance_valid(npc) and npc.has_method("configure_run_safety"):
			npc.call("configure_run_safety", _is_hostile_grace_active(), crowd_settings.hostile_safe_radius)

func get_active_npc_count() -> int:
	return active_npc_count
