extends CharacterBody3D

enum State { INACTIVE, WANDER, ENGAGE, PANIC, FLEE, DISABLED }

@export var civilian_profile: NpcProfile
@export var hostile_profile: NpcProfile

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health: HealthComponent = $HealthComponent
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var warning_marker: Label3D = $RoleMarkerAnchor/WarningMarker
@onready var armed_prop: Node3D = $RoleMarkerAnchor/HostileProp

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
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	if civilian_profile == null:
		civilian_profile = load("res://resources/default_civilian_profile.tres") as NpcProfile
	if hostile_profile == null:
		hostile_profile = load("res://resources/default_hostile_profile.tres") as NpcProfile
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
	lifecycle_id = new_lifecycle_id
	group_id = spawn_group_id
	target_player = player
	active = true
	impact_eligible = true
	state = State.WANDER
	_disabled_time = 0.0
	_attack_cooldown = 0.0
	_panic_time_left = 0.0
	global_position = spawn_position
	velocity = Vector3.ZERO
	visible = true
	collision_layer = 8
	collision_mask = 5
	health.configure(profile.maximum_health)
	_apply_profile_visuals()
	if profile.is_hostile():
		if group_id == &"":
			group_id = HostileGroupService.create_group()
		HostileGroupService.register_member(group_id, self)
	else:
		group_id = &""
	_select_wander_target()

func deactivate() -> void:
	if group_id != &"":
		HostileGroupService.unregister_member(group_id, self)
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
	visible = false
	collision_layer = 0
	collision_mask = 0
	if navigation_agent != null:
		navigation_agent.target_position = global_position

func tick(delta: float, full_ai: bool) -> void:
	if not active:
		return
	if state == State.DISABLED:
		_disabled_time += delta
		return
	if state == State.PANIC or state == State.FLEE:
		_tick_flee(delta)
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
	_wander_time_left -= delta
	if _wander_time_left <= 0.0 or global_position.distance_to(_wander_target) < 1.0:
		_select_wander_target()
	_move_toward(_wander_target, delta, profile.walk_speed if profile != null else 2.4)

func _tick_far_movement(delta: float) -> void:
	if _wander_time_left <= 0.0 or global_position.distance_to(_wander_target) < 2.0:
		_select_wander_target()
	var speed := (profile.walk_speed if profile != null else 2.4) * 0.65
	_move_toward(_wander_target, delta, speed)

func _tick_engage(delta: float) -> void:
	if target_player == null:
		state = State.WANDER
		return
	var distance := global_position.distance_to(target_player.global_position)
	if distance > profile.engagement_range * 1.2:
		state = State.WANDER
		return
	_move_toward(target_player.global_position, delta, profile.walk_speed * 1.15)
	_attack_cooldown -= delta
	if distance <= profile.attack_range and _attack_cooldown <= 0.0:
		var receiver: Node = target_player.get_damage_target() if target_player.has_method("get_damage_target") else target_player
		if receiver != null and receiver.has_method("apply_damage"):
			receiver.apply_damage(profile.attack_damage)
		_attack_cooldown = profile.attack_interval

func _tick_flee(delta: float) -> void:
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

func _select_wander_target() -> void:
	var center := global_position
	if target_player != null:
		center = target_player.global_position
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf_range(5.0, 22.0)
	_wander_target = center + Vector3(cos(angle), 0.0, sin(angle)) * radius
	_wander_target.x = clampf(_wander_target.x, -70.0, 70.0)
	_wander_target.z = clampf(_wander_target.z, -70.0, 70.0)
	_wander_target.y = global_position.y
	_wander_time_left = _rng.randf_range(3.0, 8.0)
	if navigation_agent != null:
		navigation_agent.target_position = _wander_target

func _can_engage() -> bool:
	if profile == null or not profile.is_hostile() or state == State.PANIC or state == State.FLEE:
		return false
	if target_player == null:
		return false
	return global_position.distance_to(target_player.global_position) <= profile.engagement_range

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
	velocity = impulse.normalized() * minf(speed * 0.35, 18.0) if impulse.length() > 0.01 else Vector3.ZERO
	var role_name := "Hostile" if profile != null and profile.is_hostile() else "Civilian"
	var timestamp := Time.get_ticks_msec() / 1000.0
	var event := ImpactEvent.new(lifecycle_id, role_name, source, speed, impulse, timestamp, true, false)
	ImpactBus.emit_impact(event)
	if role_name == "Hostile" and group_id != &"":
		HostileGroupService.record_impact(group_id, timestamp)

func apply_damage(amount: float) -> void:
	if active and state != State.DISABLED:
		health.apply_damage(amount)

func is_disabled_for_recycle() -> bool:
	return active and state == State.DISABLED and _disabled_time >= 1.5

func is_score_eligible() -> bool:
	return impact_eligible and active and state != State.DISABLED

func is_inactive() -> bool:
	return state == State.INACTIVE

func is_disabled() -> bool:
	return state == State.DISABLED

func _apply_profile_visuals() -> void:
	if profile == null:
		return
	var material := StandardMaterial3D.new()
	var palette := profile.material_palette
	material.albedo_color = palette[0] if not palette.is_empty() else Color.WHITE
	body_mesh.material_override = material
	warning_marker.visible = profile.is_hostile() and profile.warning_marker_enabled
	if warning_marker.visible:
		warning_marker.modulate = profile.warning_marker_color
	armed_prop.visible = profile.is_hostile() and profile.equipped_prop_scene != null

func _on_health_died() -> void:
	if active and state != State.DISABLED:
		impact_eligible = false
		state = State.DISABLED
		_disabled_time = 1.5
		collision_layer = 0
		collision_mask = 0
