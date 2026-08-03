class_name GameRules
extends Resource

## Shared tuning for score, combo, and hostile panic behavior.

@export_range(0, 100000, 1) var hostile_score: int = 100
@export_range(0, 100000, 1) var civilian_penalty: int = 250
@export_range(0.1, 60.0, 0.1) var combo_window_seconds: float = 6.0
@export_range(1, 20, 1) var panic_threshold: int = 2
@export_range(0.1, 60.0, 0.1) var panic_window_seconds: float = 6.0
