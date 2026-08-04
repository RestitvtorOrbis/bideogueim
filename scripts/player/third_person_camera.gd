extends Node3D

@export var follow_smoothing: float = 12.0
@export var follow_height: float = 1.70
@export var shake_decay: float = 8.0
@export var shake_position_scale: float = 0.045
@export var close_camera_hide_distance: float = 1.35
@export var close_camera_show_distance: float = 1.65

var _target: Node3D
var _shake_amount: float = 0.0
var _base_camera_position := Vector3.ZERO
var _visual_root: Node3D
@onready var _spring_arm := get_node_or_null("SpringArm3D") as SpringArm3D
@onready var _camera := get_node_or_null("SpringArm3D/Camera3D") as Camera3D

func _ready() -> void:
	_target = get_parent() as Node3D
	if _target != null:
		_visual_root = _target.get_node_or_null("VisualRoot") as Node3D
	if _camera != null:
		_base_camera_position = _camera.position
	var camera_shake := get_node_or_null("/root/CameraShake")
	if camera_shake != null and camera_shake.has_signal("shake_requested") and not camera_shake.is_connected("shake_requested", Callable(self, "_on_shake")):
		camera_shake.connect("shake_requested", Callable(self, "_on_shake"))

func set_world_space_follow(enabled: bool) -> void:
	# Player movement rotates the visual body, while the orbit yaw must remain
	# stable until the player explicitly looks. Vehicle cameras keep their
	# normal parent-relative transform because they do not call this method.
	top_level = enabled
	if enabled and is_instance_valid(_target):
		global_position = _target.global_position + Vector3.UP * follow_height

func _process(delta: float) -> void:
	if _target == null:
		return
	var desired := _target.global_position + Vector3.UP * follow_height
	global_position = global_position.lerp(desired, clampf(delta * follow_smoothing, 0.0, 1.0))
	_shake_amount = move_toward(_shake_amount, 0.0, delta * shake_decay)
	if _camera != null:
		var random_offset := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * _shake_amount * shake_position_scale
		_camera.position = _base_camera_position + random_offset
	_update_visual_visibility()

func _update_visual_visibility() -> void:
	if _visual_root == null or _spring_arm == null:
		return
	if _target != null and _target.get("occupied_vehicle") != null:
		return
	_update_visual_visibility_for_distance(_spring_arm.get_hit_length())

func _update_visual_visibility_for_distance(actual_camera_distance: float) -> void:
	if _visual_root == null:
		return
	if actual_camera_distance < close_camera_hide_distance:
		_visual_root.visible = false
	elif actual_camera_distance > close_camera_show_distance:
		_visual_root.visible = true

func _on_shake(intensity: float) -> void:
	_shake_amount = maxf(_shake_amount, intensity)
