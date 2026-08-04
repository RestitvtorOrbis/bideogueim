extends Node3D

var _time := 0.0
var _core: MeshInstance3D
var _visor: MeshInstance3D

func _ready() -> void:
	call_deferred("_cache_visuals")

func _cache_visuals() -> void:
	var player := get_parent() as Node3D
	if player == null:
		return
	_core = player.get_node_or_null("ChestCore") as MeshInstance3D
	_visor = player.get_node_or_null("Head/Visor") as MeshInstance3D

func _process(delta: float) -> void:
	_time += delta
	var pulse := 2.4 + sin(_time * 3.6) * 0.8
	if is_instance_valid(_core):
		var core_material := _core.material_override as StandardMaterial3D
		if core_material != null:
			core_material.emission_energy_multiplier = pulse
	if is_instance_valid(_visor):
		var visor_material := _visor.material_override as StandardMaterial3D
		if visor_material != null:
			visor_material.emission_energy_multiplier = 0.9 + sin(_time * 2.2) * 0.18
