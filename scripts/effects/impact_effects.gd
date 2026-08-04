extends Node3D

const PARTICLE_POOL_LIMIT := 24
const DECAL_POOL_LIMIT := 32
const FRAGMENT_POOL_LIMIT := 48
const FLASH_POOL_LIMIT := 12

var _particle_pool: Array[GPUParticles3D] = []
var _decal_pool: Array[MeshInstance3D] = []
var _fragment_pool: Array[MeshInstance3D] = []
var _flash_pool: Array[OmniLight3D] = []
var _audio_pool: Array[AudioStreamPlayer3D] = []
var _decal_timers: Array[float] = []
var _fragment_timers: Array[float] = []
var _flash_timers: Array[float] = []
var _audio_timers: Array[float] = []
var _particle_cursor := 0
var _decal_cursor := 0
var _fragment_cursor := 0
var _flash_cursor := 0
var _audio_cursor := 0

func _ready() -> void:
	_build_pools()
	if is_instance_valid(ImpactBus) and not ImpactBus.impact_received.is_connected(_on_impact):
		ImpactBus.impact_received.connect(_on_impact)

func _process(delta: float) -> void:
	for index in _decal_timers.size():
		if _decal_timers[index] > 0.0:
			_decal_timers[index] -= delta
			if _decal_timers[index] <= 0.0:
				_decal_pool[index].visible = false
	for index in _fragment_timers.size():
		if _fragment_timers[index] > 0.0:
			_fragment_timers[index] -= delta
			if _fragment_timers[index] <= 0.0:
				_fragment_pool[index].visible = false
	for index in _flash_timers.size():
		if _flash_timers[index] > 0.0:
			_flash_timers[index] -= delta
			_flash_pool[index].light_energy = clampf(_flash_timers[index] * 22.0, 0.0, 5.0)
			if _flash_timers[index] <= 0.0:
				_flash_pool[index].visible = false
				_flash_pool[index].light_energy = 0.0
	for index in _audio_timers.size():
		if _audio_timers[index] > 0.0:
			_audio_timers[index] -= delta
			if _audio_timers[index] <= 0.0:
				_audio_pool[index].stop()

func _build_pools() -> void:
	var red_material := StandardMaterial3D.new()
	red_material.albedo_color = Color(0.78, 0.035, 0.02, 1.0)
	red_material.roughness = 0.7
	red_material.emission_enabled = true
	red_material.emission = Color(0.32, 0.008, 0.002, 1.0)
	red_material.emission_energy_multiplier = 0.8
	red_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	red_material.albedo_color.a = 0.86

	for _index in PARTICLE_POOL_LIMIT:
		var particles := GPUParticles3D.new()
		var process_material := ParticleProcessMaterial.new()
		process_material.direction = Vector3.UP
		process_material.spread = 180.0
		process_material.initial_velocity_min = 3.0
		process_material.initial_velocity_max = 8.0
		process_material.gravity = Vector3.DOWN * 9.0
		var particle_mesh := SphereMesh.new()
		particle_mesh.radius = 0.06
		particle_mesh.height = 0.12
		particle_mesh.material = red_material
		particles.process_material = process_material
		particles.draw_pass_1 = particle_mesh
		particles.amount = 18
		particles.lifetime = 0.65
		particles.one_shot = true
		particles.emitting = false
		add_child(particles)
		_particle_pool.append(particles)

	var decal_mesh := QuadMesh.new()
	decal_mesh.size = Vector2(1.2, 1.2)
	decal_mesh.material = red_material
	for _index in DECAL_POOL_LIMIT:
		var decal := MeshInstance3D.new()
		decal.mesh = decal_mesh
		decal.rotation_degrees.x = -90.0
		decal.visible = false
		add_child(decal)
		_decal_pool.append(decal)
		_decal_timers.append(0.0)

	var fragment_material := StandardMaterial3D.new()
	fragment_material.albedo_color = Color(0.12, 0.02, 0.02, 1.0)
	var fragment_mesh := BoxMesh.new()
	fragment_mesh.size = Vector3(0.22, 0.12, 0.18)
	fragment_mesh.material = fragment_material
	for _index in FRAGMENT_POOL_LIMIT:
		var fragment := MeshInstance3D.new()
		fragment.mesh = fragment_mesh
		fragment.visible = false
		add_child(fragment)
		_fragment_pool.append(fragment)
		_fragment_timers.append(0.0)

	for _index in FLASH_POOL_LIMIT:
		var flash := OmniLight3D.new()
		flash.light_color = Color(1.0, 0.22, 0.04, 1.0)
		flash.omni_range = 5.5
		flash.light_energy = 0.0
		flash.shadow_enabled = false
		flash.visible = false
		add_child(flash)
		_flash_pool.append(flash)
		_flash_timers.append(0.0)

	var placeholder_stream := AudioStreamGenerator.new()
	placeholder_stream.mix_rate = 22050.0
	for _index in 8:
		var player := AudioStreamPlayer3D.new()
		player.stream = placeholder_stream
		player.unit_size = 8.0
		player.max_distance = 38.0
		add_child(player)
		_audio_pool.append(player)
		_audio_timers.append(0.0)

func _on_impact(event: ImpactEvent) -> void:
	if event == null or not event.qualifying or event.is_disabled:
		return
	var position := _event_position(event)
	var settings: ViolenceSettings = SettingsService.violence if is_instance_valid(SettingsService) else ViolenceSettings.new()
	if settings.is_disabled():
		return
	if event.speed >= 5.0 and not _flash_pool.is_empty():
		var flash := _flash_pool[_flash_cursor]
		_flash_cursor = (_flash_cursor + 1) % _flash_pool.size()
		var flash_index := (_flash_cursor - 1) if _flash_cursor > 0 else _flash_pool.size() - 1
		flash.global_position = position + Vector3.UP * 0.7
		flash.visible = true
		flash.light_energy = 5.0
		_flash_timers[flash_index] = 0.22
	if event.speed >= 6.0 and settings.blood_particles_enabled:
		var particles := _particle_pool[_particle_cursor]
		_particle_cursor = (_particle_cursor + 1) % _particle_pool.size()
		particles.global_position = position + Vector3.UP * 0.8
		particles.amount = maxi(3, int(18.0 * settings.blood_particle_density))
		particles.restart()
		particles.emitting = true
	if settings.decals_enabled:
		var decal := _decal_pool[_decal_cursor]
		_decal_cursor = (_decal_cursor + 1) % _decal_pool.size()
		decal.global_position = position + Vector3.UP * 0.015
		decal.visible = true
		_decal_timers[_decal_cursor - 1 if _decal_cursor > 0 else _decal_pool.size() - 1] = 7.0
	if settings.fragments_enabled and event.speed >= 8.0:
		var fragment := _fragment_pool[_fragment_cursor]
		var fragment_index := _fragment_cursor
		_fragment_cursor = (_fragment_cursor + 1) % _fragment_pool.size()
		fragment.global_position = position + Vector3.UP * 0.55
		fragment.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		fragment.visible = true
		_fragment_timers[fragment_index] = 2.5
	if settings.vocal_impact_audio_enabled:
		var audio := _audio_pool[_audio_cursor]
		var audio_index := _audio_cursor
		_audio_cursor = (_audio_cursor + 1) % _audio_pool.size()
		audio.global_position = position
		audio.play()
		_audio_timers[audio_index] = 0.18
	if settings.impact_camera_shake_enabled and event.speed >= 5.0:
		CameraShake.request_shake(clampf(event.speed / 22.0, 0.0, 1.0))

func _event_position(event: ImpactEvent) -> Vector3:
	if event.source is Node3D:
		return (event.source as Node3D).global_position
	return Vector3.ZERO

func _exit_tree() -> void:
	for audio in _audio_pool:
		if is_instance_valid(audio):
			audio.stop()
	if is_instance_valid(ImpactBus) and ImpactBus.impact_received.is_connected(_on_impact):
		ImpactBus.impact_received.disconnect(_on_impact)
