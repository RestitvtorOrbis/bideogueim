class_name CrowdSettings
extends Resource

## Inspector-editable population and update-tier settings.

@export_range(1, 2500, 1) var active_npc_cap: int = 250
@export_range(0, 2500, 1) var civilian_target_count: int = 160
@export_range(0, 2500, 1) var hostile_target_count: int = 90
@export_range(10.0, 500.0, 1.0) var spawn_distance: float = 90.0
@export_range(0, 2500, 1) var initial_population_count: int = 40
@export_range(0, 2500, 1) var initial_visible_count: int = 16
@export_range(1, 250, 1) var spawn_budget_per_frame: int = 12
@export_range(1, 64, 1) var spawn_candidate_attempts: int = 8
@export_range(0.0, 100.0, 0.5) var minimum_spawn_distance: float = 14.0
@export_range(0.0, 100.0, 0.5) var minimum_npc_separation: float = 2.5
@export_range(0.0, 100.0, 0.5) var spawn_edge_padding: float = 8.0
@export_range(0.0, 20.0, 0.25) var spawn_jitter_radius: float = 4.0
@export_range(10.0, 500.0, 1.0) var initial_spawn_distance: float = 65.0
@export_range(10.0, 1000.0, 1.0) var despawn_distance: float = 130.0
@export_range(5.0, 250.0, 1.0) var full_ai_distance: float = 35.0
@export_range(5.0, 500.0, 1.0) var mid_ai_distance: float = 75.0
@export_range(0.02, 1.0, 0.01) var mid_update_interval: float = 0.15
@export_range(0.05, 2.0, 0.01) var far_update_interval: float = 0.5
