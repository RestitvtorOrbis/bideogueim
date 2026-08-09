class_name NpcProfile
extends Resource

## A role profile contains only data; NPC behavior remains in npc.gd.

enum Role { CIVILIAN, HOSTILE }

@export_enum("Civilian", "Hostile") var role: int = Role.CIVILIAN
@export_range(1.0, 500.0, 1.0) var maximum_health: float = 100.0
@export_range(0.1, 15.0, 0.1) var walk_speed: float = 2.4
@export var material_palette: Array[Color] = [
	Color(0.18, 0.45, 0.72, 1.0),
	Color(0.82, 0.45, 0.24, 1.0),
	Color(0.85, 0.75, 0.42, 1.0)
]
@export var equipped_prop_scene: PackedScene
@export var score_category: String = "civilian"
@export var warning_marker_enabled: bool = false
@export var warning_marker_color: Color = Color(0.95, 0.12, 0.08, 1.0)
@export_range(0.5, 100.0, 0.5) var engagement_range: float = 18.0
@export_range(0.1, 20.0, 0.1) var attack_range: float = 18.0
@export_range(0.1, 10.0, 0.1) var attack_interval: float = 1.5
@export_range(0.0, 500.0, 1.0) var attack_damage: float = 3.0
@export_range(0.0, 90.0, 0.1) var aim_spread_degrees: float = 14.0
@export_range(1.0, 100.0, 0.5) var projectile_speed: float = 24.0

func is_hostile() -> bool:
	return role == Role.HOSTILE
