extends Node3D

@export var follow_smoothing: float = 12.0
@export var shake_decay: float = 8.0
@export var shake_position_scale: float = 0.045

var _target: Node3D
var _shake_amount: float = 0.0
var _base_camera_position := Vector3.ZERO
@onready var _camera := get_node_or_null("SpringArm3D/Camera3D") as Camera3D

func _ready() -> void:
	_target = get_parent() as Node3D
	if _camera != null:
		_base_camera_position = _camera.position
	if is_instance_valid(CameraShake) and not CameraShake.shake_requested.is_connected(_on_shake):
		CameraShake.shake_requested.connect(_on_shake)

func _process(delta: float) -> void:
	if _target == null:
		return
	var desired := _target.global_position + Vector3.UP * 1.25
	global_position = global_position.lerp(desired, clampf(delta * follow_smoothing, 0.0, 1.0))
	_shake_amount = move_toward(_shake_amount, 0.0, delta * shake_decay)
	if _camera != null:
		var random_offset := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * _shake_amount * shake_position_scale
		_camera.position = _base_camera_position + random_offset

func _on_shake(intensity: float) -> void:
	_shake_amount = maxf(_shake_amount, intensity)
