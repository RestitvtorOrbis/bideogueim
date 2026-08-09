extends CharacterBody3D

enum State { INACTIVE, WANDER, ENGAGE, PANIC, FLEE, DISABLED, HOSTILE_FLEE }

const WEAPON_RECOIL_DURATION: float = 0.12
const WEAPON_RECOIL_DISTANCE: float = 0.11
const ACTIVE_NPC_GROUP: StringName = &"active_npc"
const ACTIVE_CIVILIAN_GROUP: StringName = &"active_civilian"
const ACTIVE_HOSTILE_GROUP: StringName = &"active_hostile"
const HOSTILE_FLEE_RADIUS: float = 15.0
const HOSTILE_FLEE_RELEASE_RADIUS: float = 20.0
const HOSTILE_FLEE_SPEED_MULTIPLIER: float = 1.8
const HOSTILE_AWARENESS_INTERVAL: float = 0.30
const FAR_MOVEMENT_SPEED_MULTIPLIER: float = 0.80
const HUMAN_CHARACTER_CATALOG := preload("res://resources/human_character_catalog.tres")
const CIVILIAN_VISUAL_HEIGHTS: Array[float] = [1.68, 1.74, 1.80, 1.86]
const HOSTILE_VISUAL_HEIGHTS: Array[float] = [1.78, 1.86]
const VISUAL_YAW_RESPONSE: float = 12.0
const GROUNDING_RAY_START_OFFSET: float = 2.0
const GROUNDING_RAY_END_Y: float = -2.0
const GROUNDING_CLEARANCE: float = 0.02
const VISUAL_TIER_FULL := 0
const VISUAL_TIER_MID := 1
const VISUAL_TIER_FAR := 2
const VISUAL_TIER_HIDDEN := 3

@export var civilian_profile: NpcProfile
@export var hostile_profile: NpcProfile
@export var hostile_projectile_scene: PackedScene

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health: HealthComponent = $HealthComponent
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var warning_marker: Label3D = $RoleMarkerAnchor/WarningMarker
@onready var armed_prop: Node3D = $RoleMarkerAnchor/HostileProp
@onready var weapon_pivot: Node3D = $RoleMarkerAnchor/HostileProp/WeaponPivot
@onready var human_visual: HumanCharacterVisual = $Visuals/HumanCharacterVisual

var profile: NpcProfile
var state: State = State.INACTIVE
var lifecycle_id: String = ""
var group_id: StringName
var target_player: Node
var impact_eligible: bool = false
var active: bool = false

var _wander_target := Vector3.ZERO
var _roaming_anchor := Vector3.ZERO
var _wander_time_left: float = 0.0
var _attack_cooldown: float = 0.0
var _panic_time_left: float = 0.0
var _disabled_time: float = 0.0
var _civilian_target_cooldown: float = 0.0
var _hostile_awareness_time_left: float = 0.0
var _hostile_flee_target: Node3D
var _run_grace_active: bool = false
var _safe_radius: float = 0.0
var _rng := RandomNumberGenerator.new()
var _visual_profile: NpcProfile
var _visual_material: StandardMaterial3D
var _weapon_pivot_rest_position := Vector3.ZERO
var _weapon_recoil_time_left: float = 0.0
var _died: bool = false
var _visual_yaw: float = 0.0
var _visual_tier := -1

func _ready() -> void:
	_rng.randomize()
	if weapon_pivot != null:
		_weapon_pivot_rest_position = weapon_pivot.position
	if civilian_profile == null:
		civilian_profile = load("res://resources/default_civilian_profile.tres") as NpcProfile
	if hostile_profile == null:
		hostile_profile = load("res://resources/default_hostile_profile.tres") as NpcProfile
	if hostile_projectile_scene == null:
		hostile_projectile_scene = load("res://scenes/HostileProjectile.tscn") as PackedScene
	if health != null and not health.died.is_connected(_on_health_died):
		health.died.connect(_on_health_died)
	deactivate()

func activate(
		new_profile: NpcProfile,
		spawn_position: Vector3,
		new_lifecycle_id: String,
		spawn_group_id: StringName = &"",
		player: Node = null
	) -> void:
	_remove_role_groups()
	profile = new_profile if new_profile != null else civilian_profile
	if profile == null:
		deactivate()
		return
	lifecycle_id = new_lifecycle_id
	group_id = spawn_group_id
	target_player = player
	active = true
	impact_eligible = true
	_run_grace_active = false
	_safe_radius = 0.0
	state = State.WANDER
	_disabled_time = 0.0
	_attack_cooldown = 0.0
	_panic_time_left = 0.0
	_civilian_target_cooldown = 0.0
	_hostile_flee_target = null
	_hostile_awareness_time_left = _get_hostile_awareness_phase(new_lifecycle_id)
	_died = false
	global_position = _resolve_grounded_spawn_position(spawn_position)
	_roaming_anchor = global_position
	velocity = Vector3.ZERO
	_visual_yaw = 0.0
	if human_visual != null:
		human_visual.rotation = Vector3.ZERO
	visible = true
	collision_layer = 8
	collision_mask = 5
	if health != null:
		health.configure(profile.maximum_health)
	_apply_profile_visuals()
	if human_visual != null:
		human_visual.set_animation_tier(HumanCharacterVisual.ANIMATION_TIER_NORMAL)
		human_visual.set_motion_speed(0.0)
	_visual_tier = VISUAL_TIER_FULL
	if profile.is_hostile():
		var hostile_service := _get_hostile_group_service()
		if group_id == &"":
			if hostile_service != null:
				group_id = hostile_service.call("create_group")
		if group_id != &"" and hostile_service != null:
			hostile_service.call("register_member", group_id, self)
	else:
		group_id = &""
	_register_role_group()
	_reset_weapon_presentation()
	_select_wander_target()

func deactivate() -> void:
	_remove_role_groups()
	var hostile_service := _get_hostile_group_service()
	if group_id != &"" and hostile_service != null:
		hostile_service.call("unregister_member", group_id, self)
	active = false
	impact_eligible = false
	state = State.INACTIVE
	group_id = &""
	lifecycle_id = ""
	target_player = null
	velocity = Vector3.ZERO
	_visual_yaw = 0.0
	_wander_target = global_position
	_roaming_anchor = Vector3.ZERO
	_wander_time_left = 0.0
	_attack_cooldown = 0.0
	_panic_time_left = 0.0
	_civilian_target_cooldown = 0.0
	_hostile_awareness_time_left = 0.0
	_hostile_flee_target = null
	_disabled_time = 0.0
	_run_grace_active = false
	_safe_radius = 0.0
	_died = false
	_visual_tier = -1
	visible = false
	collision_layer = 0
	collision_mask = 0
	if navigation_agent != null:
		navigation_agent.target_position = global_position
	_reset_weapon_presentation()
	if human_visual != null:
		human_visual.set_motion_speed(0.0)
		human_visual.set_animation_tier(HumanCharacterVisual.ANIMATION_TIER_FROZEN)
		human_visual.set_visibility_tier(HumanCharacterVisual.VISIBILITY_TIER_HIDDEN)
		human_visual.rotation = Vector3.ZERO

func tick(delta: float, full_ai: bool) -> void:
	if not active:
		return
	_update_visual_animation_state()
	if human_visual != null:
		human_visual.advance_visual_animation(delta)
	_civilian_target_cooldown = maxf(0.0, _civilian_target_cooldown - maxf(0.0, delta))
	if profile != null and not profile.is_hostile() and state != State.INACTIVE and state != State.DISABLED and state != State.PANIC and state != State.FLEE and not _died:
		_update_hostile_awareness(delta)
	if state == State.DISABLED:
		_disabled_time += delta
		return
	if state == State.PANIC or state == State.FLEE:
		_tick_flee(delta)
		return
	if state == State.HOSTILE_FLEE:
		_tick_hostile_flee(delta)
		return
	if _is_hostile_grace_active():
		_tick_grace(delta)
		return
	if not full_ai:
		_tick_far_movement(delta)
		return
	if profile != null and profile.is_hostile() and _can_engage():
		state = State.ENGAGE
		_tick_engage(delta)
	else:
		if state == State.ENGAGE:
			state = State.WANDER
		_tick_wander(delta)

func _tick_wander(delta: float) -> void:
	_update_weapon_presentation(delta, null)
	_wander_time_left -= delta
	if _wander_time_left <= 0.0 or global_position.distance_to(_wander_target) < 1.0:
		_select_wander_target()
	_move_toward(_wander_target, delta, profile.walk_speed if profile != null else 3.0)

func _tick_far_movement(delta: float) -> void:
	_update_weapon_presentation(delta, null)
	_wander_time_left -= delta
	if _wander_time_left <= 0.0 or global_position.distance_to(_wander_target) < 2.0:
		_select_wander_target()
	var speed := (profile.walk_speed if profile != null else 3.0) * FAR_MOVEMENT_SPEED_MULTIPLIER
	_move_toward(_wander_target, delta, speed)

func _tick_engage(delta: float) -> void:
	if _is_hostile_grace_active():
		state = State.WANDER
		_tick_grace(delta)
		return
	if target_player == null:
		state = State.WANDER
		return
	var target_node := _get_current_aim_target()
	if target_node == null:
		state = State.WANDER
		_update_weapon_presentation(delta, null)
		return
	var distance := global_position.distance_to(target_node.global_position)
	if distance > profile.engagement_range * 1.2:
		state = State.WANDER
		_update_weapon_presentation(delta, null)
		return
	_update_weapon_presentation(delta, target_node)
	_move_toward(target_node.global_position, delta, profile.walk_speed * 1.15)
	_attack_cooldown -= delta
	var fire_range := minf(profile.attack_range, profile.engagement_range)
	if distance <= fire_range and _attack_cooldown <= 0.0:
		fire_hostile_projectile()
		_attack_cooldown = profile.attack_interval

func fire_hostile_projectile(
		direction_override: Vector3 = Vector3.ZERO,
		spread_override: float = -1.0,
		target_override: Node3D = null,
		civilian_probability_roll: float = -1.0
	) -> Node:
	if not active or profile == null or not profile.is_hostile() or hostile_projectile_scene == null:
		return null
	var explicit_direction := direction_override.length_squared() > 0.000001
	var selected_target := target_override
	var deliberate_civilian := _is_living_active_civilian(selected_target)
	if selected_target == null and not explicit_direction:
		selected_target = select_deliberate_civilian_target(civilian_probability_roll)
		deliberate_civilian = selected_target != null
	if selected_target == null:
		selected_target = _get_current_aim_target()
	var projectile := hostile_projectile_scene.instantiate() as Node3D
	if projectile == null:
		return null
	var projectile_parent: Node = get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_tree().root
	projectile_parent.add_child(projectile)
	var spawn_position := global_position + Vector3.UP * 1.05
	var direction := direction_override.normalized() if explicit_direction else _get_hostile_aim_direction(selected_target)
	if direction.length_squared() <= 0.000001:
		direction = Vector3.FORWARD
	var requested_spread := profile.aim_spread_degrees if spread_override < 0.0 else spread_override
	direction = _apply_aim_spread(direction, requested_spread)
	var shot_damage := profile.attack_damage
	if deliberate_civilian:
		shot_damage = _get_civilian_target_damage(selected_target)
	projectile.call(
		"launch",
		self,
		spawn_position,
		direction,
		shot_damage,
		minf(profile.attack_range, profile.engagement_range),
		profile.projectile_speed
	)
	_trigger_weapon_recoil()
	var presentation_target := selected_target if selected_target != null else _get_current_aim_target()
	_update_weapon_presentation(0.0, presentation_target)
	return projectile

func fire_hostile_projectile_at(
	target: Node3D,
	direction_override: Vector3 = Vector3.ZERO,
	spread_override: float = -1.0
) -> Node:
	return fire_hostile_projectile(direction_override, spread_override, target, 1.0)

func _get_hostile_aim_direction(target_override: Node3D = null) -> Vector3:
	var target_node := target_override if target_override != null and is_instance_valid(target_override) else _get_current_aim_target()
	if target_node == null:
		return Vector3.FORWARD
	var spawn_position := global_position + Vector3.UP * 1.05
	return spawn_position.direction_to(target_node.global_position + Vector3.UP * 0.9)

func _get_current_aim_target() -> Node3D:
	if target_player == null or not is_instance_valid(target_player):
		return null
	if target_player.has_method("get_damage_target"):
		var damage_target := target_player.call("get_damage_target") as Node3D
		if damage_target != null and is_instance_valid(damage_target):
			return damage_target
		return null
	return target_player as Node3D

func _update_weapon_presentation(delta: float, aim_target: Node3D) -> void:
	if weapon_pivot == null:
		return
	if aim_target != null and is_instance_valid(aim_target):
		var aim_direction := aim_target.global_position - weapon_pivot.global_position
		aim_direction.y = 0.0
		if aim_direction.length_squared() > 0.000001:
			weapon_pivot.rotation = Vector3(0.0, atan2(-aim_direction.x, -aim_direction.z), 0.0)
	else:
		weapon_pivot.rotation = Vector3.ZERO
	_weapon_recoil_time_left = maxf(0.0, _weapon_recoil_time_left - maxf(0.0, delta))
	var recoil_offset := 0.0
	if _weapon_recoil_time_left > 0.0:
		recoil_offset = (_weapon_recoil_time_left / WEAPON_RECOIL_DURATION) * WEAPON_RECOIL_DISTANCE
	weapon_pivot.position = _weapon_pivot_rest_position + Vector3.BACK * recoil_offset

func _trigger_weapon_recoil() -> void:
	_weapon_recoil_time_left = WEAPON_RECOIL_DURATION

func _reset_weapon_presentation() -> void:
	_weapon_recoil_time_left = 0.0
	if weapon_pivot == null:
		return
	weapon_pivot.position = _weapon_pivot_rest_position
	weapon_pivot.rotation = Vector3.ZERO

func _apply_aim_spread(direction: Vector3, spread_degrees: float) -> Vector3:
	var forward := direction.normalized() if direction.length_squared() > 0.000001 else Vector3.FORWARD
	if spread_degrees <= 0.0:
		return forward
	var right := Vector3.UP.cross(forward)
	if right.length_squared() <= 0.000001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var up := forward.cross(right).normalized()
	var cone_angle := deg_to_rad(spread_degrees) * sqrt(_rng.randf())
	var azimuth := _rng.randf_range(0.0, TAU)
	var radial := right * cos(azimuth) + up * sin(azimuth)
	return (forward * cos(cone_angle) + radial * sin(cone_angle)).normalized()


func _tick_flee(delta: float) -> void:
	_update_weapon_presentation(delta, null)
	if target_player == null:
		state = State.WANDER
		return
	_panic_time_left -= delta
	var player_node := target_player as Node3D
	if player_node == null:
		state = State.WANDER
		return
	var away: Vector3 = player_node.global_position.direction_to(global_position)
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	var flee_target: Vector3 = global_position + away.normalized() * 18.0
	_move_toward(flee_target, delta, (profile.walk_speed if profile != null else 3.0) * 1.7)
	if _panic_time_left <= 0.0 or global_position.distance_to(target_player.global_position) > 55.0:
		state = State.WANDER

func _tick_hostile_flee(_delta: float) -> void:
	_update_weapon_presentation(_delta, null)
	if profile == null or profile.is_hostile() or not active:
		state = State.WANDER
		return
	var hostile := _hostile_flee_target
	if not _is_active_hostile_candidate(hostile):
		state = State.WANDER
		_hostile_flee_target = null
		_select_wander_target()
		return
	var away := _horizontal_direction_from(hostile as Node3D, self)
	if away.length_squared() < 0.0001:
		away = Vector3.FORWARD
	var flee_speed := profile.walk_speed * HOSTILE_FLEE_SPEED_MULTIPLIER
	velocity.x = away.x * flee_speed
	velocity.z = away.z * flee_speed
	move_and_slide()
	_update_visual_orientation(_delta)
	_enforce_safe_radius()

func refresh_hostile_awareness() -> bool:
	if not active or profile == null or profile.is_hostile() or state == State.INACTIVE or state == State.DISABLED or state == State.PANIC or state == State.FLEE or _died:
		return false
	_hostile_awareness_time_left = HOSTILE_AWARENESS_INTERVAL
	return _scan_hostile_awareness()

func is_hostile_fleeing() -> bool:
	return active and state == State.HOSTILE_FLEE

func _update_hostile_awareness(delta: float) -> void:
	if not active or profile == null or profile.is_hostile() or state == State.INACTIVE or state == State.DISABLED or state == State.PANIC or state == State.FLEE or _died:
		return
	_hostile_awareness_time_left -= maxf(0.0, delta)
	if _hostile_awareness_time_left > 0.0:
		return
	_hostile_awareness_time_left = HOSTILE_AWARENESS_INTERVAL
	_scan_hostile_awareness()

func _scan_hostile_awareness() -> bool:
	if not active or profile == null or profile.is_hostile() or state == State.INACTIVE or state == State.DISABLED or state == State.PANIC or state == State.FLEE or _died:
		return false
	var search_radius := HOSTILE_FLEE_RELEASE_RADIUS if state == State.HOSTILE_FLEE else HOSTILE_FLEE_RADIUS
	var nearest_hostile := _find_nearest_active_hostile(search_radius)
	if nearest_hostile != null:
		_hostile_flee_target = nearest_hostile
		state = State.HOSTILE_FLEE
		return true
	if state == State.HOSTILE_FLEE:
		_hostile_flee_target = null
		state = State.WANDER
		_select_wander_target()
	return false

func _find_nearest_active_hostile(max_distance: float) -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var nearest: Node3D = null
	var nearest_distance_squared := maxf(0.0, max_distance) * maxf(0.0, max_distance)
	for candidate in tree.get_nodes_in_group(ACTIVE_HOSTILE_GROUP):
		var hostile := candidate as Node3D
		if not _is_active_hostile_candidate(hostile):
			continue
		var offset := hostile.global_position - global_position
		offset.y = 0.0
		var distance_squared := offset.length_squared()
		if distance_squared <= nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest = hostile
	return nearest

func _is_active_hostile_candidate(candidate: Node3D) -> bool:
	if candidate == null or not is_instance_valid(candidate) or candidate == self or candidate.is_queued_for_deletion():
		return false
	if not bool(candidate.get("active")):
		return false
	return int(candidate.get("state")) != State.INACTIVE and int(candidate.get("state")) != State.DISABLED

func _horizontal_direction_from(origin: Node3D, destination: Node3D) -> Vector3:
	if origin == null or destination == null:
		return Vector3.ZERO
	var direction := origin.global_position.direction_to(destination.global_position)
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.ZERO

func _move_toward(destination: Vector3, delta: float, speed: float) -> void:
	var direction := global_position.direction_to(destination)
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		velocity = Vector3.ZERO
		return
	direction = direction.normalized()
	velocity.x = move_toward(velocity.x, direction.x * speed, 10.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 10.0 * delta)
	move_and_slide()
	_update_visual_orientation(delta)
	_enforce_safe_radius()


func _resolve_grounded_spawn_position(requested_position: Vector3) -> Vector3:
	var grounded_position := requested_position
	var world := get_world_3d()
	if world == null or world.direct_space_state == null:
		return grounded_position
	var ray_start := requested_position + Vector3.UP * GROUNDING_RAY_START_OFFSET
	var ray_end := Vector3(requested_position.x, GROUNDING_RAY_END_Y, requested_position.z)
	if ray_start.y <= ray_end.y:
		return grounded_position
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1)
	query.exclude = [get_rid()]
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return grounded_position
	var hit_position: Variant = hit.get("position", null)
	if hit_position is Vector3:
		grounded_position.y = (hit_position as Vector3).y + GROUNDING_CLEARANCE
	return grounded_position

func _select_wander_target() -> void:
	var center := global_position
	if profile != null and not profile.is_hostile():
		center = _roaming_anchor
	elif profile != null and profile.is_hostile() and target_player != null:
		center = target_player.global_position
	var angle := _rng.randf_range(0.0, TAU)
	var minimum_radius := 8.0
	var maximum_radius := 28.0
	var minimum_wander_time := 2.0
	var maximum_wander_time := 5.0
	if _is_hostile_grace_active():
		minimum_radius = _safe_radius
		maximum_radius = maxf(minimum_radius, minimum_radius + 22.0)
		minimum_wander_time = 3.0
		maximum_wander_time = 8.0
	var radius := _rng.randf_range(minimum_radius, maximum_radius)
	_wander_target = center + Vector3(cos(angle), 0.0, sin(angle)) * radius
	_wander_target.y = global_position.y
	_wander_target = _clamp_wander_target_to_safe_radius(_wander_target)
	_wander_time_left = _rng.randf_range(minimum_wander_time, maximum_wander_time)
	if navigation_agent != null:
		navigation_agent.target_position = _wander_target

func select_deliberate_civilian_target(probability_roll: float = -1.0) -> Node3D:
	if not active or profile == null or not profile.is_hostile() or _civilian_target_cooldown > 0.0:
		return null
	var civilian := _find_nearest_active_civilian(minf(profile.attack_range, profile.engagement_range))
	if civilian == null:
		return null
	var roll := _rng.randf() if probability_roll < 0.0 else clampf(probability_roll, 0.0, 1.0)
	if roll >= profile.civilian_target_probability:
		return null
	_civilian_target_cooldown = profile.civilian_target_cooldown
	return civilian

func _find_nearest_active_civilian(max_distance: float) -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var nearest: Node3D = null
	var nearest_distance_squared := maxf(0.0, max_distance) * maxf(0.0, max_distance)
	for candidate in tree.get_nodes_in_group(ACTIVE_CIVILIAN_GROUP):
		var civilian := candidate as Node3D
		if not _is_living_active_civilian(civilian):
			continue
		var offset := civilian.global_position - global_position
		offset.y = 0.0
		var distance_squared := offset.length_squared()
		if distance_squared <= nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest = civilian
	return nearest

func _is_living_active_civilian(candidate: Node3D) -> bool:
	if candidate == null or not is_instance_valid(candidate) or candidate == self or candidate.is_queued_for_deletion():
		return false
	if not bool(candidate.get("active")) or int(candidate.get("state")) == State.DISABLED:
		return false
	var candidate_profile := candidate.get("profile") as NpcProfile
	if candidate_profile == null or candidate_profile.is_hostile():
		return false
	var candidate_health := candidate.get_node_or_null("HealthComponent") as HealthComponent
	return candidate_health != null and candidate_health.current_health > 0.0

func _get_civilian_target_damage(target: Node3D) -> float:
	var configured_damage := profile.civilian_target_damage
	var target_health := target.get_node_or_null("HealthComponent") as HealthComponent if target != null else null
	if target_health == null:
		return configured_damage
	return maxf(configured_damage, target_health.maximum_health)

func _can_engage() -> bool:
	if profile == null or not profile.is_hostile() or state == State.PANIC or state == State.FLEE:
		return false
	if target_player == null:
		return false
	if _is_hostile_grace_active():
		return false
	var target_node := _get_current_aim_target()
	return target_node != null and global_position.distance_to(target_node.global_position) <= profile.engagement_range

func configure_run_safety(grace_active: bool, safe_radius: float) -> void:
	var was_grace_active := _run_grace_active
	_run_grace_active = grace_active
	_safe_radius = maxf(0.0, safe_radius)
	if not active or profile == null or not profile.is_hostile() or not _run_grace_active:
		return
	if state == State.ENGAGE:
		state = State.WANDER
	if not was_grace_active or not _is_wander_target_safe():
		_select_wander_target()

func _is_hostile_grace_active() -> bool:
	return _run_grace_active and profile != null and profile.is_hostile() and target_player != null

func _tick_grace(delta: float) -> void:
	_update_weapon_presentation(delta, null)
	if not _is_hostile_grace_active():
		return
	if _is_inside_safe_radius():
		var escape_target := _safe_radius_escape_target()
		_move_toward(escape_target, delta, profile.walk_speed if profile != null else 3.0)
		return
	if _wander_time_left <= 0.0 or not _is_wander_target_safe():
		_select_wander_target()
	_move_toward(_wander_target, delta, profile.walk_speed if profile != null else 3.0)

func _is_inside_safe_radius() -> bool:
	if not _is_hostile_grace_active() or _safe_radius <= 0.0:
		return false
	var player_node := target_player as Node3D
	if player_node == null:
		return false
	var offset := global_position - player_node.global_position
	offset.y = 0.0
	return offset.length_squared() < _safe_radius * _safe_radius

func _safe_radius_escape_target() -> Vector3:
	var player_node := target_player as Node3D
	if player_node == null:
		return global_position
	var offset := global_position - player_node.global_position
	offset.y = 0.0
	var direction := Vector3.FORWARD if offset.length_squared() < 0.0001 else offset.normalized()
	var target := player_node.global_position + direction * maxf(_safe_radius, 0.1)
	target.y = global_position.y
	return target

func _is_wander_target_safe() -> bool:
	if not _is_hostile_grace_active() or _safe_radius <= 0.0:
		return true
	var player_node := target_player as Node3D
	if player_node == null:
		return true
	var offset := _wander_target - player_node.global_position
	offset.y = 0.0
	return offset.length_squared() + 0.0001 >= _safe_radius * _safe_radius

func _clamp_wander_target_to_safe_radius(target: Vector3) -> Vector3:
	if not _is_hostile_grace_active() or _safe_radius <= 0.0:
		return target
	var player_node := target_player as Node3D
	if player_node == null:
		return target
	var offset := target - player_node.global_position
	offset.y = 0.0
	if offset.length_squared() >= _safe_radius * _safe_radius:
		return target
	var direction := Vector3.FORWARD if offset.length_squared() < 0.0001 else offset.normalized()
	var clamped_target := player_node.global_position + direction * _safe_radius
	clamped_target.y = target.y
	return clamped_target

func _enforce_safe_radius() -> void:
	if not _is_inside_safe_radius():
		return
	var target := _safe_radius_escape_target()
	global_position = target
	velocity.x = 0.0
	velocity.z = 0.0

func enter_panic() -> void:
	if not active or profile == null or not profile.is_hostile() or state == State.DISABLED:
		return
	state = State.PANIC
	_panic_time_left = 8.0

func receive_vehicle_impact(source: Node, speed: float, impulse: Vector3) -> void:
	if not active or state == State.DISABLED or not impact_eligible or source == null:
		return
	impact_eligible = false
	state = State.DISABLED
	_disabled_time = 0.0
	collision_layer = 0
	collision_mask = 0
	_reset_weapon_presentation()
	velocity = impulse.normalized() * minf(speed * 0.35, 18.0) if impulse.length() > 0.01 else Vector3.ZERO
	var role_name := "Hostile" if profile != null and profile.is_hostile() else "Civilian"
	var timestamp := Time.get_ticks_msec() / 1000.0
	var event := ImpactEvent.new(lifecycle_id, role_name, source, speed, impulse, timestamp, true, false)
	var impact_bus := get_node_or_null("/root/ImpactBus")
	if impact_bus != null:
		impact_bus.call("emit_impact", event)
	if role_name == "Hostile" and group_id != &"":
		var hostile_service := _get_hostile_group_service()
		if hostile_service != null:
			hostile_service.call("record_impact", group_id, timestamp)

func apply_damage(amount: float) -> void:
	if active and state != State.DISABLED and health != null:
		health.apply_damage(amount)

func is_disabled_for_recycle() -> bool:
	return active and state == State.DISABLED and _disabled_time >= 1.5

func is_score_eligible() -> bool:
	return impact_eligible and active and state != State.DISABLED

func is_inactive() -> bool:
	return state == State.INACTIVE

func is_disabled() -> bool:
	return state == State.DISABLED

func was_killed() -> bool:
	return active and _died

func _apply_profile_visuals() -> void:
	if profile == null:
		return
	var hostile := profile.is_hostile()
	if human_visual != null:
		var visual_height := _get_visual_height(lifecycle_id, hostile)
		var role := &"hostile" if hostile else &"civilian"
		var configured := human_visual.configure_from_catalog(HUMAN_CHARACTER_CATALOG, lifecycle_id, role, visual_height)
		if configured:
			human_visual.set_visibility_tier(HumanCharacterVisual.VISIBILITY_TIER_FULL)
			_disable_dynamic_shadows(human_visual.get_body_root())
			_visual_yaw = 0.0
			human_visual.rotation = Vector3.ZERO
	if body_mesh != null:
		body_mesh.visible = false
	_visual_profile = profile
	if warning_marker != null:
		warning_marker.visible = hostile and profile.warning_marker_enabled
	if warning_marker != null and warning_marker.visible:
		warning_marker.modulate = profile.warning_marker_color
	if armed_prop != null:
		armed_prop.visible = hostile and profile.equipped_prop_scene != null

func _get_visual_height(seed_text: String, hostile: bool) -> float:
	var heights := HOSTILE_VISUAL_HEIGHTS if hostile else CIVILIAN_VISUAL_HEIGHTS
	var seed := HumanCharacterCatalog.stable_seed(seed_text)
	return heights[posmod(seed, heights.size())]

func _disable_dynamic_shadows(root: Node3D) -> void:
	if root == null:
		return
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _update_visual_orientation(delta: float) -> void:
	if human_visual == null:
		return
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	human_visual.set_motion_speed(horizontal_velocity.length())
	if horizontal_velocity.length_squared() <= 0.0001:
		return
	var direction := horizontal_velocity.normalized()
	var target_yaw := atan2(-direction.x, -direction.z)
	_visual_yaw = lerp_angle(_visual_yaw, target_yaw, clampf(maxf(0.0, delta) * VISUAL_YAW_RESPONSE, 0.0, 1.0))
	human_visual.rotation.y = _visual_yaw


func _update_visual_animation_state() -> void:
	if human_visual == null:
		return
	human_visual.set_motion_speed(Vector3(velocity.x, 0.0, velocity.z).length())


func update_visual_tier(distance: float, full_distance: float, mid_distance: float, hide_distance: float) -> int:
	if not active or human_visual == null:
		return _visual_tier
	var full_boundary := maxf(0.0, full_distance)
	var mid_boundary := maxf(full_boundary, mid_distance)
	var hide_boundary := maxf(mid_boundary, hide_distance)
	var next_tier := VISUAL_TIER_FULL
	if distance > hide_boundary:
		next_tier = VISUAL_TIER_HIDDEN
	elif distance > mid_boundary:
		next_tier = VISUAL_TIER_FAR
	elif distance > full_boundary:
		next_tier = VISUAL_TIER_MID
	if next_tier == _visual_tier:
		return _visual_tier
	_visual_tier = next_tier
	match next_tier:
		VISUAL_TIER_FULL:
			human_visual.set_animation_tier(HumanCharacterVisual.ANIMATION_TIER_NORMAL)
			human_visual.set_visibility_tier(HumanCharacterVisual.VISIBILITY_TIER_FULL)
		VISUAL_TIER_MID:
			human_visual.set_animation_tier(HumanCharacterVisual.ANIMATION_TIER_THROTTLED)
			human_visual.set_visibility_tier(HumanCharacterVisual.VISIBILITY_TIER_REDUCED)
		VISUAL_TIER_FAR:
			human_visual.set_animation_tier(HumanCharacterVisual.ANIMATION_TIER_FROZEN)
			human_visual.set_visibility_tier(HumanCharacterVisual.VISIBILITY_TIER_REDUCED)
		VISUAL_TIER_HIDDEN:
			human_visual.set_animation_tier(HumanCharacterVisual.ANIMATION_TIER_FROZEN)
			human_visual.set_visibility_tier(HumanCharacterVisual.VISIBILITY_TIER_HIDDEN)
	return _visual_tier


func get_visual_tier() -> int:
	return _visual_tier

func _on_health_died() -> void:
	if active and state != State.DISABLED:
		_died = true
		impact_eligible = false
		state = State.DISABLED
		_disabled_time = 1.5
		collision_layer = 0
		collision_mask = 0
		_reset_weapon_presentation()

func _register_role_group() -> void:
	if not active:
		return
	add_to_group(ACTIVE_NPC_GROUP)
	add_to_group(ACTIVE_HOSTILE_GROUP if profile != null and profile.is_hostile() else ACTIVE_CIVILIAN_GROUP)

func _remove_role_groups() -> void:
	for group_name in [ACTIVE_NPC_GROUP, ACTIVE_CIVILIAN_GROUP, ACTIVE_HOSTILE_GROUP]:
		if is_in_group(group_name):
			remove_from_group(group_name)

func _get_hostile_awareness_phase(seed_text: String) -> float:
	var phase_bucket := absi(seed_text.hash()) % 30
	return float(phase_bucket) / 100.0

func _get_hostile_group_service() -> Node:
	return get_node_or_null("/root/HostileGroupService")
