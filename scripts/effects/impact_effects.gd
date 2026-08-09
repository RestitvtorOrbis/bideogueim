extends Node3D

const PARTICLE_POOL_LIMIT := 24
const DECAL_POOL_LIMIT := 32
const FRAGMENT_POOL_LIMIT := 48
const FLASH_POOL_LIMIT := 12
const BLOOD_HIT_POOL_LIMIT := 24
const BLOOD_HIT_FRAME_RATE := 30.0
const BLOOD_HIT_FRAME_COUNT := 16
const BLOOD_HIT_DURATION := BLOOD_HIT_FRAME_COUNT / BLOOD_HIT_FRAME_RATE
const BLOOD_HIT_TEXTURES: Array[Texture2D] = [
	preload("res://assets/vfx/blood/blood_hit_01.png"),
	preload("res://assets/vfx/blood/blood_hit_02.png"),
]
const KENNEY_SPLAT_TEXTURES: Array[Texture2D] = [
	preload("res://assets/vfx/blood/kenney_splat_00.png"),
	preload("res://assets/vfx/blood/kenney_splat_10.png"),
	preload("res://assets/vfx/blood/kenney_splat_20.png"),
]

var _particle_pool: Array[GPUParticles3D] = []
var _decal_pool: Array[MeshInstance3D] = []
var _fragment_pool: Array[MeshInstance3D] = []
var _flash_pool: Array[OmniLight3D] = []
var _audio_pool: Array[AudioStreamPlayer3D] = []
var _blood_hit_pool: Array[Sprite3D] = []
var _decal_meshes: Array[QuadMesh] = []
var _decal_timers: Array[float] = []
var _fragment_timers: Array[float] = []
var _flash_timers: Array[float] = []
var _audio_timers: Array[float] = []
var _blood_hit_timers: Array[float] = []
var _fragment_velocities: Array[Vector3] = []
var _particle_cursor := 0
var _blood_hit_cursor := 0
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
			_fragment_velocities[index] += Vector3.DOWN * 12.0 * delta
			_fragment_pool[index].global_position += _fragment_velocities[index] * delta
			_fragment_timers[index] -= delta
			if _fragment_timers[index] <= 0.0:
				_fragment_pool[index].visible = false
				_fragment_velocities[index] = Vector3.ZERO
	for index in _blood_hit_timers.size():
		if _blood_hit_timers[index] > 0.0:
			_blood_hit_timers[index] -= delta
			var elapsed := BLOOD_HIT_DURATION - maxf(0.0, _blood_hit_timers[index])
			_blood_hit_pool[index].frame = mini(BLOOD_HIT_FRAME_COUNT - 1, int(floor(elapsed * BLOOD_HIT_FRAME_RATE)))
			if _blood_hit_timers[index] <= 0.0:
				_blood_hit_pool[index].visible = false
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
		_fragment_velocities.append(Vector3.ZERO)

	for index in BLOOD_HIT_POOL_LIMIT:
		var blood_hit := Sprite3D.new()
		blood_hit.name = "PooledBloodHit_%02d" % index
		blood_hit.hframes = 4
		blood_hit.vframes = 4
		blood_hit.texture = BLOOD_HIT_TEXTURES[index % BLOOD_HIT_TEXTURES.size()]
		blood_hit.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		blood_hit.pixel_size = 0.0035
		blood_hit.modulate = Color(0.82, 0.02, 0.01, 0.92)
		blood_hit.visible = false
		add_child(blood_hit)
		_blood_hit_pool.append(blood_hit)
		_blood_hit_timers.append(0.0)

	for texture in KENNEY_SPLAT_TEXTURES:
		var decal_material := StandardMaterial3D.new()
		decal_material.albedo_color = Color(0.62, 0.012, 0.008, 0.88)
		decal_material.albedo_texture = texture
		decal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		decal_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		decal_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var textured_mesh := QuadMesh.new()
		textured_mesh.size = Vector2(1.2, 1.2)
		textured_mesh.material = decal_material
		_decal_meshes.append(textured_mesh)

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
	var is_vehicle := event.impact_kind == &"vehicle"
	if settings.blood_particles_enabled:
		var blood_hit_count := 2 if is_vehicle and settings.preset == ViolenceSettings.Preset.FULL else 1
		for _index in blood_hit_count:
			_spawn_blood_hit(position, settings.blood_particle_density, is_vehicle)
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
		var particle_multiplier := 1.65 if is_vehicle else 0.75
		particles.amount = maxi(3, int(18.0 * settings.blood_particle_density * particle_multiplier))
		particles.restart()
		particles.emitting = true
	if settings.decals_enabled:
		var decal_count := 2 if is_vehicle and settings.preset == ViolenceSettings.Preset.FULL else 1
		for decal_index in decal_count:
			_spawn_decal(position, is_vehicle, decal_index)
	if settings.fragments_enabled and event.speed >= 8.0:
		var fragment_count := 3 if is_vehicle else 1
		for fragment_index in fragment_count:
			_spawn_fragment(position, event.impulse, is_vehicle, fragment_index)
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
	return event.world_position

func _spawn_blood_hit(position: Vector3, density: float, is_vehicle: bool) -> void:
	if _blood_hit_pool.is_empty():
		return
	var index := _blood_hit_cursor
	_blood_hit_cursor = (_blood_hit_cursor + 1) % _blood_hit_pool.size()
	var blood_hit := _blood_hit_pool[index]
	blood_hit.texture = BLOOD_HIT_TEXTURES[(index + (1 if is_vehicle else 0)) % BLOOD_HIT_TEXTURES.size()]
	blood_hit.frame = 0
	blood_hit.global_position = position + Vector3.UP * (0.78 if is_vehicle else 0.70)
	var intensity := (1.18 if is_vehicle else 0.82) * clampf(density, 0.25, 1.0)
	blood_hit.scale = Vector3.ONE * intensity
	blood_hit.visible = true
	_blood_hit_timers[index] = BLOOD_HIT_DURATION

func _spawn_decal(position: Vector3, is_vehicle: bool, variation: int) -> void:
	if _decal_pool.is_empty() or _decal_meshes.is_empty():
		return
	var index := _decal_cursor
	_decal_cursor = (_decal_cursor + 1) % _decal_pool.size()
	var decal := _decal_pool[index]
	decal.mesh = _decal_meshes[(index + variation) % _decal_meshes.size()]
	decal.global_position = position + Vector3.UP * 0.015
	decal.rotation = Vector3(-PI * 0.5, fposmod(float(index + variation) * 2.399963, TAU), 0.0)
	var scale_factor := (1.55 if is_vehicle else 0.92) * (1.0 + float((index + variation) % 3) * 0.08)
	decal.scale = Vector3.ONE * scale_factor
	decal.visible = true
	_decal_timers[index] = 7.0

func _spawn_fragment(position: Vector3, impulse: Vector3, is_vehicle: bool, variation: int) -> void:
	if _fragment_pool.is_empty():
		return
	var index := _fragment_cursor
	_fragment_cursor = (_fragment_cursor + 1) % _fragment_pool.size()
	var fragment := _fragment_pool[index]
	fragment.global_position = position + Vector3.UP * (0.55 + float(variation) * 0.08)
	fragment.rotation = Vector3(
		fposmod(float(index + variation) * 1.31, TAU),
		fposmod(float(index + variation) * 2.17, TAU),
		fposmod(float(index + variation) * 0.73, TAU)
	)
	fragment.visible = true
	var direction := impulse.normalized() if impulse.length_squared() > 0.0001 else Vector3.UP
	var velocity_multiplier := 10.0 if is_vehicle else 5.0
	_fragment_velocities[index] = direction * velocity_multiplier + Vector3.UP * (3.0 + float(variation))
	_fragment_timers[index] = 2.5

func _exit_tree() -> void:
	for audio in _audio_pool:
		if is_instance_valid(audio):
			audio.stop()
	if is_instance_valid(ImpactBus) and ImpactBus.impact_received.is_connected(_on_impact):
		ImpactBus.impact_received.disconnect(_on_impact)
