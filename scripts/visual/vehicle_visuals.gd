extends Node3D

var _vehicle: RigidBody3D
var _wheels: Array[MeshInstance3D] = []
var _time := 0.0

func _ready() -> void:
	call_deferred("_cache_visuals")

func _cache_visuals() -> void:
	_vehicle = get_parent() as RigidBody3D
	if _vehicle == null:
		return
	for wheel_name in ["WheelVisualFrontLeft", "WheelVisualFrontRight", "WheelVisualRearLeft", "WheelVisualRearRight"]:
		var wheel := _vehicle.get_node_or_null(wheel_name) as MeshInstance3D
		if wheel != null:
			_wheels.append(wheel)

func _process(delta: float) -> void:
	_time += delta
	if not is_instance_valid(_vehicle):
		return
	var speed := _vehicle.linear_velocity.length()
	for wheel in _wheels:
		if is_instance_valid(wheel):
			wheel.rotate_x(speed * delta * 1.8)
	var accent := _vehicle.get_node_or_null("AccentStrip") as MeshInstance3D
	if accent != null:
		var material := accent.material_override as StandardMaterial3D
		if material != null:
			material.emission_energy_multiplier = 1.8 + sin(_time * 4.0) * 0.55
