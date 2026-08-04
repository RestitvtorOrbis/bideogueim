extends Node3D

var _time := 0.0
var _accent: MeshInstance3D

func _ready() -> void:
	_accent = get_node_or_null("../AccentBar") as MeshInstance3D

func _process(delta: float) -> void:
	_time += delta
	if not is_instance_valid(_accent):
		return
	var material := _accent.material_override as StandardMaterial3D
	if material != null:
		material.emission_energy_multiplier = 1.5 + sin(_time * 2.6) * 0.35
