extends CharacterBody3D

enum State { INACTIVE, WANDER, ENGAGE, PANIC, FLEE, DISABLED }

const WEAPON_RECOIL_DURATION: float = 0.12
const WEAPON_RECOIL_DISTANCE: float = 0.11

@export var civilian_profile: NpcProfile
@export var hostile_profile: NpcProfile
@export var hostile_projectile_scene: PackedScene

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health: HealthComponent = $HealthComponent
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var warning_marker: Label3D = $RoleMarkerAnchor/WarningMarker
@onready var armed_prop: Node3D = $RoleMarkerAnchor/HostileProp
@onready var weapon_pivot: Node3D = $RoleMarkerAnchor/HostileProp/WeaponPivot

var profile: NpcProfile
var state: State = State.INACTIVE
var lifecycle_id: String = ""
var group_id: StringName
var target_player: Node
var impact_eligible: bool = false
var active: bool = false

var _wander_target := Vector3.ZERO
var _wander_time_left: float = 0.0
var _attack_cooldown: float = 0.0
var _panic_time_left: float = 0.0
var _disabled_time: float = 0.0
var _run_grace_active: bool = false
var _safe_radius: float = 0.0
var _rng := RandomNumberGenerator.new()
var _visual_profile: NpcProfile
var _visual_material: StandardMaterial3D
var _weapon_pivot_rest_position := Vector3.ZERO
var _weapon_recoil_time_left: float = 0.0
var _died: bool = false

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
	_died = false
	global_position = spawn_position
	velocity = Vector3.ZERO
	visible = true
	collision_layer = 8
	collision_mask = 5
	if health != null:
		health.configure(profile.maximum_health)
	_apply_profile_visuals()
	if profile.is_hostile():
		var hostile_service := _get_hostile_group_service()
		if group_id == &"":
			if hostile_service != null:
				group_id = hostile_service.call("create_group")
		if group_id != &"" and hostile_service != null:
			hostile_service.call("register_member", group_id, self)
	else:
		group_id = &""
	_reset_weapon_presentation()
	_select_wander_target()

func deactivate() -> void:
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
	_wander_target = global_position
	_wander_time_left = 0.0
	_attack_cooldown = 0.0
	_panic_time_left = 0.0
	_disabled_time = 0.0
	_run_grace_active = false
	_safe_radius = 0.0
	_died = false
	visible = false
	collision_layer = 0
	collision_mask = 0
	if navigation_agent != null:
		navigation_agent.target_position = global_position
	_reset_weapon_presentation()

func tick(delta: float, full_ai: bool) -> void:
	if not active:
		return
	if state == State.DISABLED:
		_disabled_time += delta
		return
	if state == State.PANIC or state == State.FLEE:
		_tick_flee(delta)
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
	_move_toward(_wander_target, delta, profile.walk_speed if profile != null else 2.4)

func _tick_far_movement(delta: float) -> void:
	_update_weapon_presentation(delta, null)
	if _wander_time_left <= 0.0 or global_position.distance_to(_wander_target) < 2.0:
		_select_wander_target()
	var speed := (profile.walk_speed if profile != null else 2.4) * 0.65
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

func fire_hostile_projectile(direction_override: Vector3 = Vector3.ZERO, spread_override: float = -1.0) -> Node:
	if not active or profile == null or not profile.is_hostile() or hostile_projectile_scene == null:
		return null
	var projectile := hostile_projectile_scene.instantiate() as Node3D
	if projectile == null:
		return null
	var projectile_parent: Node = get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_tree().root
	projectile_parent.add_child(projectile)
	var spawn_position := global_position + Vector3.UP * 1.05
	var direction := direction_override.normalized() if direction_override.length_squared() > 0.000001 else _get_hostile_aim_direction()
	var requested_spread := profile.aim_spread_degrees if spread_override < 0.0 else spread_override
	direction = _apply_aim_spread(direction, requested_spread)
	projectile.call(
		"launch",
		self,
		spawn_position,
		direction,
		profile.attack_damage,
		minf(profile.attack_range, profile.engagement_range),
		profile.projectile_speed
	)
	_trigger_weapon_recoil()
	_update_weapon_presentation(0.0, _get_current_aim_target())
	return projectile

func _get_hostile_aim_direction() -> Vector3:
	var target_node := _get_current_aim_target()
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
	_move_toward(flee_target, delta, (profile.walk_speed if profile != null else 2.4) * 1.7)
	if _panic_time_left <= 0.0 or global_position.distance_to(target_player.global_position) > 55.0:
		state = State.WANDER

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
	_enforce_safe_radius()

func _select_wander_target() -> void:
	var center := global_position
	if target_player != null:
		center = target_player.global_position
	var angle := _rng.randf_range(0.0, TAU)
	var minimum_radius := 5.0
	var maximum_radius := 22.0
	if _is_hostile_grace_active():
		minimum_radius = _safe_radius
		maximum_radius = maxf(minimum_radius, minimum_radius + 22.0)
	var radius := _rng.randf_range(minimum_radius, maximum_radius)
	_wander_target = center + Vector3(cos(angle), 0.0, sin(angle)) * radius
	_wander_target.y = global_position.y
	_wander_target = _clamp_wander_target_to_safe_radius(_wander_target)
	_wander_time_left = _rng.randf_range(3.0, 8.0)
	if navigation_agent != null:
		navigation_agent.target_position = _wander_target

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
		_move_toward(escape_target, delta, profile.walk_speed if profile != null else 2.4)
		return
	if _wander_time_left <= 0.0 or not _is_wander_target_safe():
		_select_wander_target()
	_move_toward(_wander_target, delta, profile.walk_speed if profile != null else 2.4)

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
	if profile == null or body_mesh == null:
		return
	if _visual_profile != profile:
		_visual_material = StandardMaterial3D.new()
		var palette := profile.material_palette
		_visual_material.albedo_color = palette[0] if not palette.is_empty() else Color.WHITE
		_visual_material.roughness = 0.84
		_visual_profile = profile
	body_mesh.material_override = _visual_material
	if warning_marker != null:
		warning_marker.visible = profile.is_hostile() and profile.warning_marker_enabled
	if warning_marker != null and warning_marker.visible:
		warning_marker.modulate = profile.warning_marker_color
	if armed_prop != null:
		armed_prop.visible = profile.is_hostile() and profile.equipped_prop_scene != null

func _on_health_died() -> void:
	if active and state != State.DISABLED:
		_died = true
		impact_eligible = false
		state = State.DISABLED
		_disabled_time = 1.5
		collision_layer = 0
		collision_mask = 0
		_reset_weapon_presentation()

func _get_hostile_group_service() -> Node:
	return get_node_or_null("/root/HostileGroupService")
