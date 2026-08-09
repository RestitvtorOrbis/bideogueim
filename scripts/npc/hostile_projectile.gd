class_name HostileProjectile
extends Node3D

signal impacted(hit_position: Vector3, collider: Node)
signal expired

const HARD_MAX_TRAVEL_DISTANCE: float = 18.0
const WORLD_COLLISION_MASK: int = 1
const PLAYER_COLLISION_MASK: int = 2
const VEHICLE_COLLISION_MASK: int = 4
const TARGET_COLLISION_MASK: int = WORLD_COLLISION_MASK | PLAYER_COLLISION_MASK | VEHICLE_COLLISION_MASK

@export_range(0.1, 100.0, 0.1) var speed: float = 24.0
@export_range(0.0, 18.0, 0.1) var max_travel_distance: float = HARD_MAX_TRAVEL_DISTANCE
@export_range(0.0, 500.0, 0.1) var damage: float = 3.0
@export_flags_3d_physics var collision_mask: int = TARGET_COLLISION_MASK

@onready var tracer_body: MeshInstance3D = get_node_or_null("TracerBody") as MeshInstance3D
@onready var tracer_light: OmniLight3D = get_node_or_null("TracerLight") as OmniLight3D
@onready var trail: GPUParticles3D = get_node_or_null("Trail") as GPUParticles3D
@onready var impact_flash: OmniLight3D = get_node_or_null("ImpactFlash") as OmniLight3D
@onready var impact_flash_mesh: MeshInstance3D = get_node_or_null("ImpactFlashMesh") as MeshInstance3D
@onready var impact_flash_timer: Timer = get_node_or_null("ImpactFlashTimer") as Timer

var shooter: Node
var fired_direction: Vector3 = Vector3.FORWARD
var traveled_distance: float = 0.0
var is_active: bool = false

func _ready() -> void:
	add_to_group("hostile_projectile")
	if impact_flash_timer != null and not impact_flash_timer.timeout.is_connected(_on_impact_flash_timeout):
		impact_flash_timer.timeout.connect(_on_impact_flash_timeout)

func launch(
		shooter_node: Node,
		spawn_position: Vector3,
		initial_direction: Vector3,
		projectile_damage: float = 3.0,
		travel_limit: float = HARD_MAX_TRAVEL_DISTANCE,
		projectile_speed: float = 24.0
	) -> void:
	shooter = shooter_node
	global_position = spawn_position
	fired_direction = initial_direction.normalized() if initial_direction.length_squared() > 0.000001 else Vector3.FORWARD
	damage = maxf(0.0, projectile_damage)
	max_travel_distance = minf(HARD_MAX_TRAVEL_DISTANCE, maxf(0.0, travel_limit))
	speed = maxf(0.0, projectile_speed)
	traveled_distance = 0.0
	is_active = true
	visible = true
	if fired_direction.length_squared() > 0.000001:
		look_at(global_position + fired_direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not is_active or delta <= 0.0:
		return
	var remaining_distance := maxf(0.0, max_travel_distance - traveled_distance)
	if remaining_distance <= 0.0001:
		_expire()
		return
	var step_distance := minf(speed * delta, remaining_distance)
	if step_distance <= 0.0001:
		_expire()
		return
	var start := global_position
	var end := start + fired_direction * step_distance
	var hit := _swept_world_query(start, end)
	if not hit.is_empty():
		var hit_position: Vector3 = hit.get("position", end)
		global_position = hit_position
		traveled_distance += start.distance_to(global_position)
		_resolve_impact(hit)
		return
	global_position = end
	traveled_distance += step_distance
	if traveled_distance >= max_travel_distance - 0.0001:
		_expire()

func _swept_world_query(start: Vector3, end: Vector3) -> Dictionary:
	var world := get_world_3d()
	if world == null:
		return {}
	var space := world.direct_space_state
	if space == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(start, end, collision_mask)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	var excluded_rids: Array[RID] = []
	if shooter is CollisionObject3D:
		excluded_rids.append((shooter as CollisionObject3D).get_rid())
	query.exclude = excluded_rids
	return space.intersect_ray(query)

func _resolve_impact(hit: Dictionary) -> void:
	is_active = false
	var collider := hit.get("collider") as Node
	var receiver := _resolve_damage_receiver(collider)
	if receiver != null and receiver.has_method("apply_damage") and damage > 0.0:
		receiver.call("apply_damage", damage)
	_show_impact_flash()
	impacted.emit(global_position, collider)

func _resolve_damage_receiver(collider: Node) -> Node:
	if collider == null:
		return null
	var receiver := collider
	if receiver.has_method("get_damage_target"):
		receiver = receiver.call("get_damage_target") as Node
	elif not receiver.has_method("apply_damage"):
		var parent := receiver.get_parent()
		if parent != null and parent.has_method("get_damage_target"):
			receiver = parent.call("get_damage_target") as Node
		elif parent != null and parent.has_method("apply_damage"):
			receiver = parent
	return receiver

func _show_impact_flash() -> void:
	visible = true
	if tracer_body != null:
		tracer_body.visible = false
	if tracer_light != null:
		tracer_light.visible = false
	if trail != null:
		trail.emitting = false
	if impact_flash != null:
		impact_flash.visible = true
	if impact_flash_mesh != null:
		impact_flash_mesh.visible = true
	if impact_flash_timer != null:
		impact_flash_timer.start()
	else:
		queue_free()

func _on_impact_flash_timeout() -> void:
	queue_free()

func _expire() -> void:
	if not is_active:
		return
	is_active = false
	expired.emit()
	queue_free()
