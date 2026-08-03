class_name VehicleConfig
extends Resource

## Arcade vehicle tuning. The vehicle controller reads every value from here.

@export_range(100.0, 5000.0, 1.0) var mass: float = 1250.0
@export_range(100.0, 40000.0, 10.0) var engine_force: float = 12500.0
@export_range(0.0, 70.0, 0.1) var maximum_speed: float = 28.0
@export_range(1.0, 80.0, 0.1) var steering_angle_degrees: float = 32.0
@export_range(100.0, 50000.0, 10.0) var brake_force: float = 11500.0
@export_range(0.0, 50.0, 0.1) var suspension_rest_length: float = 0.45
@export_range(0.0, 100000.0, 10.0) var suspension_stiffness: float = 26000.0
@export_range(0.0, 10000.0, 1.0) var suspension_damping: float = 2600.0
@export_range(0.0, 100.0, 0.1) var wheel_radius: float = 0.34
@export_range(0.0, 100.0, 0.01) var impact_damage_multiplier: float = 0.45
@export_range(1.0, 1000.0, 1.0) var maximum_health: float = 100.0
@export_range(0.0, 1.0, 0.01) var rolling_drag: float = 0.08
@export_range(0.0, 1.0, 0.01) var handbrake_grip: float = 0.35
