class_name ImpactEvent
extends RefCounted

## UI-free data contract for a qualifying NPC impact.

var npc_id: String
var npc_role: String
var source: Node
var speed: float
var impulse: Vector3
var timestamp: float
var qualifying: bool
var is_disabled: bool
var world_position: Vector3
var impact_kind: StringName

func _init(
		lifecycle_id: String = "",
		role: String = "",
		impact_source: Node = null,
		impact_speed: float = 0.0,
		impact_impulse: Vector3 = Vector3.ZERO,
		impact_timestamp: float = -1.0,
		is_qualifying: bool = true,
		disabled: bool = false,
		impact_world_position: Vector3 = Vector3.INF,
		kind: StringName = &"vehicle"
	) -> void:
	npc_id = lifecycle_id
	npc_role = role
	source = impact_source
	speed = impact_speed
	impulse = impact_impulse
	timestamp = impact_timestamp
	qualifying = is_qualifying
	is_disabled = disabled
	world_position = impact_world_position
	if world_position == Vector3.INF:
		world_position = (impact_source as Node3D).global_position if impact_source is Node3D else Vector3.ZERO
	impact_kind = kind if not kind.is_empty() else &"vehicle"

func has_valid_timestamp(fallback: float) -> bool:
	return timestamp >= 0.0 or fallback >= 0.0

func effective_timestamp(fallback: float) -> float:
	return timestamp if timestamp >= 0.0 else fallback
