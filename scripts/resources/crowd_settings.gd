class_name CrowdSettings
extends Resource

## Inspector-editable population and update-tier settings.

@export_range(1, 2500, 1) var active_npc_cap: int = 250
@export_range(0, 2500, 1) var civilian_target_count: int = 160
@export_range(0, 2500, 1) var hostile_target_count: int = 90
@export_range(10.0, 500.0, 1.0) var spawn_distance: float = 90.0
@export_range(5.0, 250.0, 1.0) var full_ai_distance: float = 35.0
@export_range(5.0, 500.0, 1.0) var mid_ai_distance: float = 75.0
@export_range(0.02, 1.0, 0.01) var mid_update_interval: float = 0.15
@export_range(0.05, 2.0, 0.01) var far_update_interval: float = 0.5
