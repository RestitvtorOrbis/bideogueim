extends Node3D
class_name HumanCharacterVisual

const MIN_HEIGHT := 0.000001
const CATALOG_SCRIPT := preload("res://scripts/resources/human_character_catalog.gd")

const VISIBILITY_TIER_FULL := 0
const VISIBILITY_TIER_REDUCED := 1
const VISIBILITY_TIER_HIDDEN := 2

const ANIMATION_TIER_NORMAL := 0
const ANIMATION_TIER_THROTTLED := 1
const ANIMATION_TIER_FROZEN := 2
const THROTTLED_ANIMATION_INTERVAL := 0.10

const ACCESSORY_RENDER_POLICY := &"deferred_shared_skeleton"
const LOCOMOTION_SOURCE_PATH := "res://assets/characters/quaternius/animations/locomotion.glb"
const UAL2_SOURCE_PATH := "res://assets/characters/quaternius/animations/ual2_standard.glb"
const LOCOMOTION_CLIP_NAMES: Array[StringName] = [
	&"Idle_Loop",
	&"Walk_Loop",
	&"Jog_Fwd_Loop",
]
const UAL2_CLIP_NAMES: Array[StringName] = [
	&"UAL2_Walk_Carry_Loop",
	&"UAL2_Zombie_Idle_Loop",
]
const IDLE_SPEED_THRESHOLD := 0.10
const RUN_SPEED_THRESHOLD := 4.00

const LOCOMOTION_STATUS_UNINITIALIZED := 0
const LOCOMOTION_STATUS_READY := 1
const LOCOMOTION_STATUS_MISSING_SOURCE := 2
const LOCOMOTION_STATUS_INVALID_SOURCE := 3
const LOCOMOTION_STATUS_MISSING_LIBRARY := 4
const LOCOMOTION_STATUS_MISSING_SKELETON := 5
const LOCOMOTION_STATUS_MISSING_CLIP := 6
const LOCOMOTION_STATUS_AMBIGUOUS_CLIP := 7

const RIGHT_HAND_ALIASES: Array[StringName] = [
	&"hand_r",
	&"Hand_R",
	&"right_hand",
	&"RightHand",
	&"handRight",
]

const PALETTE_COLORS: Dictionary = {
	"civilian": {
		&"body": Color("#5c7fa3"),
		&"accent": Color("#d99c4a"),
		&"skin": Color("#d39b78"),
		&"hair": Color("#2f2522"),
	},
	"hostile": {
		&"body": Color("#863d4b"),
		&"accent": Color("#d46845"),
		&"skin": Color("#c78d6c"),
		&"hair": Color("#241b1b"),
	},
	"player": {
		&"body": Color("#3c9b86"),
		&"accent": Color("#e5c15d"),
		&"skin": Color("#d39b78"),
		&"hair": Color("#29252b"),
	},
}

const PALETTE_CACHE_META_KEY := &"human_character_palette_material_cache"
const LOCOMOTION_CACHE_META_KEY := &"human_character_locomotion_animation_cache"
const UAL2_CACHE_META_KEY := &"human_character_ual2_animation_cache"

@onready var _model_pivot: Node3D = $ModelPivot

var _body_instance: Node3D
var _normalized_aabb := AABB()
var _target_height := 0.0
var _uniform_scale := 1.0
var _forward_vector := Vector3.FORWARD

var _character_seed := 0
var _role := &"civilian"
var _palette_id := &"civilian"
var _body_variant_index := -1
var _hairstyle_variant_index := -1
var _eyebrow_variant_index := -1
var _selected_body_path := ""
var _selected_hairstyle_path := ""
var _selected_eyebrow_path := ""
var _selected_hairstyle_scene: PackedScene
var _selected_eyebrow_scene: PackedScene

var _visibility_tier := VISIBILITY_TIER_FULL
var _motion_speed := 0.0
var _animation_tier := ANIMATION_TIER_NORMAL
var _animation_player: AnimationPlayer
var _selected_animation_clip: StringName = &""
var _selected_animation_library: StringName = &""
var _manual_animation_elapsed := 0.0
var _manual_animation_advance_count := 0
var _animation_play_count := 0
var _visibility_apply_count := 0


func configure_body(path: String, height: float, source_positive_z := true) -> bool:

	_clear_body()
	var model_pivot := _get_model_pivot()
	if model_pivot == null or path.is_empty() or height <= MIN_HEIGHT:
		return false
	if not ResourceLoader.exists(path, "PackedScene"):
		return false

	var packed_scene := ResourceLoader.load(path, "PackedScene") as PackedScene
	if packed_scene == null:
		return false

	var instance := packed_scene.instantiate()
	if not instance is Node3D:
		instance.queue_free()
		return false

	_body_instance = instance as Node3D
	model_pivot.add_child(_body_instance)
	_body_instance.transform = Transform3D.IDENTITY

	var source_aabb := _merge_mesh_aabbs(_body_instance, _body_instance.transform)
	if source_aabb.size.y <= MIN_HEIGHT:
		_clear_body()
		return false

	_normalized_aabb = source_aabb
	_uniform_scale = height / source_aabb.size.y
	_target_height = height
	model_pivot.scale = Vector3.ONE
	model_pivot.position = Vector3.ZERO
	model_pivot.rotation = Vector3.ZERO
	if source_positive_z:
		model_pivot.rotation.y = PI
	var source_forward := Vector3.BACK
	if not source_positive_z:
		source_forward = Vector3.FORWARD
	model_pivot.scale = Vector3.ONE * _uniform_scale
	model_pivot.position.y = -source_aabb.position.y * _uniform_scale
	_normalized_aabb = _transform_aabb(source_aabb, model_pivot.transform)
	_forward_vector = (model_pivot.basis * source_forward).normalized()
	_apply_visibility_tier()
	_setup_animation_playback()
	return true


func configure_from_catalog(catalog: HumanCharacterCatalog, seed: Variant, role: StringName = &"civilian", height := 1.70, source_positive_z := true) -> bool:
	_clear_body()
	if catalog == null:
		return false
	if catalog.body_paths.is_empty():
		return false

	var normalized_role := _normalize_role(catalog, role)
	if normalized_role.is_empty():
		return false
	var normalized_seed := CATALOG_SCRIPT.stable_seed(seed)
	var body_index := CATALOG_SCRIPT.variant_index(normalized_seed, catalog.body_paths.size(), 1)
	if body_index < 0 or body_index >= catalog.body_paths.size():
		return false

	var selected_body_path: String = catalog.body_paths[body_index]
	if not configure_body(selected_body_path, height, source_positive_z):
		return false

	_character_seed = normalized_seed
	_role = normalized_role
	_body_variant_index = body_index
	_selected_body_path = selected_body_path
	_palette_id = _palette_id_for_role(catalog, normalized_role)
	_hairstyle_variant_index = CATALOG_SCRIPT.variant_index(normalized_seed, catalog.hairstyle_paths.size(), 11)
	_eyebrow_variant_index = CATALOG_SCRIPT.variant_index(normalized_seed, catalog.eyebrow_paths.size(), 17)
	_select_accessory(catalog.hairstyle_paths, _hairstyle_variant_index, true)
	_select_accessory(catalog.eyebrow_paths, _eyebrow_variant_index, false)
	_apply_palette_materials()
	_update_locomotion_playback()
	return true


func get_body_root() -> Node3D:
	return _body_instance


func get_normalized_aabb() -> AABB:
	return _normalized_aabb


func get_target_height() -> float:
	return _target_height


func get_uniform_scale() -> float:
	return _uniform_scale


func get_forward_vector() -> Vector3:
	return _forward_vector


func get_character_seed() -> int:
	return _character_seed


func get_role() -> StringName:
	return _role


func get_palette_id() -> StringName:
	return _palette_id


func get_body_variant_index() -> int:
	return _body_variant_index


func get_hairstyle_variant_index() -> int:
	return _hairstyle_variant_index


func get_eyebrow_variant_index() -> int:
	return _eyebrow_variant_index


func get_selected_body_path() -> String:
	return _selected_body_path


func get_selected_hairstyle_path() -> String:
	return _selected_hairstyle_path


func get_selected_eyebrow_path() -> String:
	return _selected_eyebrow_path


func get_selected_hairstyle_scene() -> PackedScene:
	return _selected_hairstyle_scene


func get_selected_eyebrow_scene() -> PackedScene:
	return _selected_eyebrow_scene


func get_accessory_render_policy() -> StringName:
	return ACCESSORY_RENDER_POLICY


func are_accessories_rendered() -> bool:
	return false


static func get_cached_palette_material(palette_id: StringName, variant: int, slot: StringName) -> StandardMaterial3D:
	var normalized_palette := _normalize_palette_id(palette_id)
	var normalized_slot := _normalize_palette_slot(slot)
	var normalized_variant := maxi(0, variant)
	var key := "%s|%d|%s" % [String(normalized_palette), normalized_variant, String(normalized_slot)]
	var cache := _get_palette_material_cache()
	if cache.has(key):
		return cache[key] as StandardMaterial3D

	var material := StandardMaterial3D.new()
	material.resource_name = "HumanPalette_%s_%d_%s" % [String(normalized_palette), normalized_variant, String(normalized_slot)]
	material.albedo_color = _palette_color(normalized_palette, normalized_slot)
	material.roughness = 0.82
	cache[key] = material
	return material


static func get_palette_material_cache_size() -> int:
	return _get_palette_material_cache().size()


func get_palette_material(slot: StringName = &"body") -> StandardMaterial3D:
	return get_cached_palette_material(_palette_id, _body_variant_index, slot)


func set_visibility_tier(value: Variant) -> int:
	var normalized := _normalize_visibility_tier(value)
	if normalized == _visibility_tier:
		return _visibility_tier
	_visibility_tier = normalized
	_apply_visibility_tier()
	return _visibility_tier


func get_visibility_tier() -> int:
	return _visibility_tier


func get_motion_speed() -> float:
	return _motion_speed


func get_animation_tier() -> int:
	return _animation_tier


func get_animation_process_mode() -> int:
	if not is_instance_valid(_animation_player):
		return AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	return _animation_player.callback_mode_process


func get_manual_animation_advance_count() -> int:
	return _manual_animation_advance_count


func get_animation_play_count() -> int:
	return _animation_play_count


func get_visibility_apply_count() -> int:
	return _visibility_apply_count


func get_locomotion_animation(clip_name: StringName) -> Animation:
	return get_shared_locomotion_animation(clip_name)


func lookup_locomotion_animation(clip_name: StringName) -> Animation:
	return get_locomotion_animation(clip_name)


static func get_shared_locomotion_animation(clip_name: StringName) -> Animation:
	var normalized_name := _normalize_locomotion_clip_name(clip_name)
	if normalized_name.is_empty():
		return null
	var cache := _get_locomotion_cache()
	if int(cache.get("status", LOCOMOTION_STATUS_UNINITIALIZED)) != LOCOMOTION_STATUS_READY:
		return null
	var animations: Variant = cache.get("animations", {})
	if not animations is Dictionary:
		return null
	return animations.get(String(normalized_name), null) as Animation


static func get_locomotion_clip_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for clip_name in LOCOMOTION_CLIP_NAMES:
		names.append(clip_name)
	return names


func get_locomotion_animation_library() -> AnimationLibrary:
	var cache := _get_locomotion_cache()
	return cache.get("library", null) as AnimationLibrary


func get_locomotion_load_status() -> int:
	return int(_get_locomotion_cache().get("status", LOCOMOTION_STATUS_UNINITIALIZED))


func get_locomotion_load_status_name() -> StringName:
	return _locomotion_status_name(get_locomotion_load_status())


func is_locomotion_ready() -> bool:
	return get_locomotion_load_status() == LOCOMOTION_STATUS_READY


func get_locomotion_animation_cache_size() -> int:
	var cache := _get_locomotion_cache()
	var animations: Variant = cache.get("animations", {})
	return animations.size() if animations is Dictionary else 0


func get_locomotion_source_load_count() -> int:
	return int(_get_locomotion_cache().get("load_count", 0))


func get_ual2_animation(clip_name: StringName) -> Animation:
	var normalized_name := _normalize_ual2_clip_name(clip_name)
	if normalized_name.is_empty():
		return null
	var animations: Variant = _get_ual2_cache().get("animations", {})
	return animations.get(String(normalized_name), null) as Animation if animations is Dictionary else null


func get_ual2_animation_library() -> AnimationLibrary:
	return _get_ual2_cache().get("library", null) as AnimationLibrary


func get_ual2_load_status() -> int:
	return int(_get_ual2_cache().get("status", LOCOMOTION_STATUS_UNINITIALIZED))


func get_ual2_load_status_name() -> StringName:
	return _locomotion_status_name(get_ual2_load_status())


func is_ual2_ready() -> bool:
	return get_ual2_load_status() == LOCOMOTION_STATUS_READY


func get_ual2_animation_cache_size() -> int:
	var animations: Variant = _get_ual2_cache().get("animations", {})
	return animations.size() if animations is Dictionary else 0


func get_ual2_source_load_count() -> int:
	return int(_get_ual2_cache().get("load_count", 0))


func get_selected_animation_clip() -> StringName:
	return _selected_animation_clip


func get_selected_animation_library() -> StringName:
	return _selected_animation_library


func set_motion_speed(value: Variant) -> float:
	var normalized := 0.0
	if value is int or value is float:
		var speed := float(value)
		if speed == speed and speed != INF and speed != -INF:
			normalized = maxf(0.0, speed)
	_motion_speed = normalized
	if _animation_tier == ANIMATION_TIER_NORMAL:
		_update_locomotion_playback()
	return _motion_speed


func set_animation_tier(value: Variant) -> int:
	var normalized := _normalize_animation_tier(value)
	if normalized == _animation_tier:
		return _animation_tier
	_animation_tier = normalized
	_manual_animation_elapsed = 0.0
	_apply_animation_process_mode()
	_update_locomotion_playback()
	return _animation_tier


func set_animation_role(role: StringName) -> StringName:
	_role = &"hostile" if String(role).to_lower() == "hostile" else &"civilian"
	if _animation_tier != ANIMATION_TIER_THROTTLED:
		_update_locomotion_playback()
	return _role


func update_locomotion() -> void:
	_update_locomotion_playback()


func advance_visual_animation(delta: float) -> bool:
	if _animation_tier != ANIMATION_TIER_THROTTLED or not is_instance_valid(_animation_player):
		return false
	_manual_animation_elapsed += maxf(0.0, delta)
	if _manual_animation_elapsed < THROTTLED_ANIMATION_INTERVAL:
		return false
	var advance_delta := _manual_animation_elapsed
	_manual_animation_elapsed = 0.0
	_update_locomotion_playback()
	_animation_player.advance(advance_delta)
	_manual_animation_advance_count += 1
	return true


func _setup_animation_playback() -> void:
	_animation_player = null
	if not is_instance_valid(_body_instance):
		return
	var old_library := get_locomotion_animation_library()
	var ual2_library := get_ual2_animation_library()
	if old_library == null and ual2_library == null:
		return
	var player := AnimationPlayer.new()
	player.name = "LocomotionAnimationPlayer"
	_body_instance.add_child(player)
	if old_library != null:
		player.add_animation_library(&"", old_library)
	if ual2_library != null:
		player.add_animation_library(&"ual2", ual2_library)
	_animation_player = player
	_apply_animation_process_mode()
	_update_locomotion_playback(true)


func _apply_animation_process_mode() -> void:
	if not is_instance_valid(_animation_player):
		return
	_animation_player.callback_mode_process = (
		AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
		if _animation_tier == ANIMATION_TIER_NORMAL
		else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	)


func _update_locomotion_playback(force_restart := false) -> void:
	if not is_instance_valid(_animation_player):
		_selected_animation_clip = &""
		_selected_animation_library = &""
		return
	var desired_clip := _locomotion_clip_for_state(_motion_speed, _role)
	var desired_library := &"ual2" if _is_ual2_clip(desired_clip) else &""
	if _animation_tier == ANIMATION_TIER_FROZEN:
		desired_clip = _idle_clip_for_role(_role)
		desired_library = &"ual2" if _is_ual2_clip(desired_clip) else &""
		if _selected_animation_clip != desired_clip or _selected_animation_library != desired_library or _animation_player.is_playing():
			_animation_player.stop()
			_selected_animation_clip = desired_clip
			_selected_animation_library = desired_library
		return
	var playback_name := String(desired_clip)
	if desired_library != &"":
		playback_name = "%s/%s" % [String(desired_library), String(desired_clip)]
	var has_animation := get_ual2_animation(desired_clip) != null if desired_library != &"" else get_locomotion_animation(desired_clip) != null
	if not has_animation:
		if desired_library != &"":
			desired_clip = _idle_clip_for_role(&"civilian")
			desired_library = &""
			playback_name = String(desired_clip)
		has_animation = get_locomotion_animation(desired_clip) != null
	if not has_animation:
		_animation_player.stop()
		_selected_animation_clip = &""
		_selected_animation_library = &""
		return
	if force_restart or not _animation_player.is_playing() or _selected_animation_clip != desired_clip or _selected_animation_library != desired_library:
		_animation_player.play(playback_name)
		_animation_play_count += 1
	_selected_animation_clip = desired_clip
	_selected_animation_library = desired_library


func _locomotion_clip_for_state(speed: float, role: StringName) -> StringName:
	if speed <= IDLE_SPEED_THRESHOLD:
		return _idle_clip_for_role(role)
	if speed >= RUN_SPEED_THRESHOLD:
		return &"Jog_Fwd_Loop"
	return &"UAL2_Walk_Carry_Loop" if String(role).to_lower() == "hostile" else &"Walk_Loop"


func _idle_clip_for_role(role: StringName) -> StringName:
	return &"UAL2_Zombie_Idle_Loop" if String(role).to_lower() == "hostile" and get_ual2_animation(&"UAL2_Zombie_Idle_Loop") != null else &"Idle_Loop"


func _is_ual2_clip(clip_name: StringName) -> bool:
	return UAL2_CLIP_NAMES.has(clip_name)


static func inspect_locomotion_source_path(source_path: String) -> Dictionary:
	return _load_locomotion_cache(source_path)


static func inspect_locomotion_source_tree(source_root: Node) -> Dictionary:
	return _extract_locomotion_resources(source_root, LOCOMOTION_SOURCE_PATH)


static func inspect_ual2_source_path(source_path: String) -> Dictionary:
	return _load_ual2_cache(source_path)


func find_right_hand_bone() -> Variant:
	var skeleton := _find_skeleton(_body_instance)
	if skeleton == null:
		return null
	for alias in RIGHT_HAND_ALIASES:
		var bone_index := skeleton.find_bone(String(alias))
		if bone_index >= 0:
			return {
				"skeleton": skeleton,
				"bone_index": bone_index,
				"bone_name": StringName(skeleton.get_bone_name(bone_index)),
			}
	return null


func get_right_hand_bone() -> Variant:
	return find_right_hand_bone()


func get_right_hand_bone_index() -> int:
	var descriptor: Variant = find_right_hand_bone()
	if descriptor == null:
		return -1
	return int(descriptor.get("bone_index", -1))


func _clear_body() -> void:
	_animation_player = null
	_selected_animation_clip = &""
	_selected_animation_library = &""
	_manual_animation_elapsed = 0.0
	_manual_animation_advance_count = 0
	_animation_play_count = 0
	_visibility_apply_count = 0
	if is_instance_valid(_body_instance):
		_body_instance.free()
	_body_instance = null
	_normalized_aabb = AABB()
	_target_height = 0.0
	_uniform_scale = 1.0
	_forward_vector = Vector3.FORWARD
	_character_seed = 0
	_role = &"civilian"
	_palette_id = &"civilian"
	_body_variant_index = -1
	_hairstyle_variant_index = -1
	_eyebrow_variant_index = -1
	_selected_body_path = ""
	_selected_hairstyle_path = ""
	_selected_eyebrow_path = ""
	_selected_hairstyle_scene = null
	_selected_eyebrow_scene = null
	_visibility_tier = VISIBILITY_TIER_FULL
	_motion_speed = 0.0
	_animation_tier = ANIMATION_TIER_NORMAL
	if is_instance_valid(_model_pivot):
		_model_pivot.transform = Transform3D.IDENTITY
		_model_pivot.visible = true


func _get_model_pivot() -> Node3D:
	if not is_instance_valid(_model_pivot):
		_model_pivot = get_node_or_null("ModelPivot") as Node3D
	return _model_pivot


func _normalize_role(catalog: HumanCharacterCatalog, role: StringName) -> StringName:
	var requested := String(role).to_lower()
	if catalog.shared_palette_metadata.has(requested):
		return StringName(requested)
	if catalog.shared_palette_metadata.has("civilian"):
		return &"civilian"
	return &""


func _palette_id_for_role(catalog: HumanCharacterCatalog, role: StringName) -> StringName:
	var metadata: Variant = catalog.shared_palette_metadata.get(String(role), {})
	if metadata is Dictionary:
		var value: Variant = metadata.get("palette_id", role)
		if value is String or value is StringName:
			return _normalize_palette_id(StringName(value))
	return _normalize_palette_id(role)


func _select_accessory(paths: Array[String], index: int, hairstyle: bool) -> void:
	if index < 0 or index >= paths.size():
		return
	var selected_path: String = paths[index]
	var selected_scene: PackedScene
	if not selected_path.is_empty() and ResourceLoader.exists(selected_path, "PackedScene"):
		selected_scene = ResourceLoader.load(selected_path, "PackedScene") as PackedScene
	if hairstyle:
		_selected_hairstyle_path = selected_path
		_selected_hairstyle_scene = selected_scene
	else:
		_selected_eyebrow_path = selected_path
		_selected_eyebrow_scene = selected_scene


func _apply_palette_materials() -> void:
	if not is_instance_valid(_body_instance):
		return
	for mesh_instance in _find_mesh_instances(_body_instance):
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue
		mesh_instance.material_override = null
		for surface_index in range(mesh.get_surface_count()):
			var source_material := mesh.surface_get_material(surface_index)
			if not source_material is StandardMaterial3D:
				continue
			var source_standard_material := source_material as StandardMaterial3D
			var slot := _palette_slot_for_surface(mesh_instance, source_standard_material)
			var palette_material := _get_cached_textured_palette_material(
				mesh_instance,
				surface_index,
				source_standard_material,
				slot
			)
			if palette_material != null:
				mesh_instance.set_surface_override_material(surface_index, palette_material)


func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		meshes.append_array(_find_mesh_instances(child))
	return meshes


func _get_cached_textured_palette_material(
		mesh_instance: MeshInstance3D,
		surface_index: int,
		source_material: StandardMaterial3D,
		slot: StringName
	) -> StandardMaterial3D:
	var key := _textured_palette_cache_key(mesh_instance, surface_index, source_material, slot)
	var cache := _get_palette_material_cache()
	if cache.has(key):
		return cache[key] as StandardMaterial3D
	var palette_material := source_material.duplicate() as StandardMaterial3D
	if palette_material == null:
		return null
	var normalized_slot := _normalize_palette_slot(slot)
	palette_material.resource_name = "HumanTexturedPalette_%s_%d_%s_%d_%s" % [
		String(_palette_id),
		_body_variant_index,
		String(normalized_slot),
		surface_index,
		mesh_instance.name,
	]
	palette_material.albedo_color = source_material.albedo_color * _palette_color(_palette_id, normalized_slot)
	cache[key] = palette_material
	return palette_material


func _textured_palette_cache_key(
		mesh_instance: MeshInstance3D,
		surface_index: int,
		source_material: StandardMaterial3D,
		slot: StringName
	) -> String:
	var source_id := source_material.resource_path
	if source_id.is_empty():
		source_id = source_material.resource_name
	if source_id.is_empty():
		source_id = "instance_%d" % source_material.get_instance_id()
	return "textured|%s|%s|%d|%s|%s|%d|%s|%s" % [
		String(_role),
		String(_palette_id),
		_body_variant_index,
		_selected_body_path,
		source_id,
		surface_index,
		mesh_instance.name,
		String(_normalize_palette_slot(slot)),
	]


func _palette_slot_for_surface(mesh_instance: MeshInstance3D, source_material: StandardMaterial3D) -> StringName:
	var mesh_name := mesh_instance.name.to_lower()
	var material_name := source_material.resource_name.to_lower()
	if material_name.contains("hair") or material_name.contains("brow") or material_name.contains("beard") or mesh_name.contains("hair") or mesh_name.contains("brow") or mesh_name.contains("beard"):
		return &"hair"
	if material_name.contains("eye") or mesh_name.contains("eye"):
		return &"accent"
	if material_name.contains("skin") or mesh_name.contains("skin") or mesh_name.contains("face"):
		return &"skin"
	return &"body"


func _apply_visibility_tier() -> void:
	_visibility_apply_count += 1
	var model_pivot := _get_model_pivot()
	if model_pivot != null:
		model_pivot.visible = _visibility_tier != VISIBILITY_TIER_HIDDEN


func _normalize_visibility_tier(value: Variant) -> int:
	if value is String or value is StringName:
		match String(value).to_lower():
			"full":
				return VISIBILITY_TIER_FULL
			"reduced":
				return VISIBILITY_TIER_REDUCED
			"hidden":
				return VISIBILITY_TIER_HIDDEN
		return VISIBILITY_TIER_FULL
	if value is int or value is float:
		return clampi(int(value), VISIBILITY_TIER_FULL, VISIBILITY_TIER_HIDDEN)
	return VISIBILITY_TIER_FULL


func _normalize_animation_tier(value: Variant) -> int:
	if value is String or value is StringName:
		match String(value).to_lower():
			"normal":
				return ANIMATION_TIER_NORMAL
			"throttled":
				return ANIMATION_TIER_THROTTLED
			"frozen":
				return ANIMATION_TIER_FROZEN
		return ANIMATION_TIER_NORMAL
	if value is int or value is float:
		return clampi(int(value), ANIMATION_TIER_NORMAL, ANIMATION_TIER_FROZEN)
	return ANIMATION_TIER_NORMAL


static func _normalize_palette_id(value: StringName) -> StringName:
	var text := String(value).to_lower()
	return StringName(text if PALETTE_COLORS.has(text) else "civilian")


static func _get_palette_material_cache() -> Dictionary:
	var main_loop := Engine.get_main_loop()
	if main_loop == null:
		return {}
	if main_loop.has_meta(PALETTE_CACHE_META_KEY):
		var cache: Variant = main_loop.get_meta(PALETTE_CACHE_META_KEY)
		if cache is Dictionary:
			return cache
	var new_cache: Dictionary = {}
	main_loop.set_meta(PALETTE_CACHE_META_KEY, new_cache)
	return new_cache


static func _get_locomotion_cache() -> Dictionary:
	var main_loop := Engine.get_main_loop()
	if main_loop == null:
		return _new_locomotion_cache(LOCOMOTION_SOURCE_PATH, LOCOMOTION_STATUS_UNINITIALIZED)
	var caches: Dictionary = {}
	if main_loop.has_meta(LOCOMOTION_CACHE_META_KEY):
		var cached_value: Variant = main_loop.get_meta(LOCOMOTION_CACHE_META_KEY)
		if cached_value is Dictionary:
			caches = cached_value
	if caches.has(LOCOMOTION_SOURCE_PATH) and caches[LOCOMOTION_SOURCE_PATH] is Dictionary:
		return caches[LOCOMOTION_SOURCE_PATH] as Dictionary
	var cache := _load_locomotion_cache(LOCOMOTION_SOURCE_PATH)
	caches[LOCOMOTION_SOURCE_PATH] = cache
	main_loop.set_meta(LOCOMOTION_CACHE_META_KEY, caches)
	return cache


static func _get_ual2_cache() -> Dictionary:
	var main_loop := Engine.get_main_loop()
	if main_loop == null:
		return _new_locomotion_cache(UAL2_SOURCE_PATH, LOCOMOTION_STATUS_UNINITIALIZED)
	var caches: Dictionary = {}
	if main_loop.has_meta(UAL2_CACHE_META_KEY):
		var cached_value: Variant = main_loop.get_meta(UAL2_CACHE_META_KEY)
		if cached_value is Dictionary:
			caches = cached_value
	if caches.has(UAL2_SOURCE_PATH) and caches[UAL2_SOURCE_PATH] is Dictionary:
		return caches[UAL2_SOURCE_PATH] as Dictionary
	var cache := _load_ual2_cache(UAL2_SOURCE_PATH)
	caches[UAL2_SOURCE_PATH] = cache
	main_loop.set_meta(UAL2_CACHE_META_KEY, caches)
	return cache


static func _load_ual2_cache(source_path: String) -> Dictionary:
	var cache := _new_locomotion_cache(source_path, LOCOMOTION_STATUS_UNINITIALIZED)
	cache["load_count"] = 1
	if source_path.is_empty() or not ResourceLoader.exists(source_path, "PackedScene"):
		cache["status"] = LOCOMOTION_STATUS_MISSING_SOURCE
		cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_MISSING_SOURCE)
		return cache
	var packed_scene := ResourceLoader.load(source_path, "PackedScene") as PackedScene
	if packed_scene == null:
		cache["status"] = LOCOMOTION_STATUS_INVALID_SOURCE
		cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_INVALID_SOURCE)
		return cache
	var source_root := packed_scene.instantiate()
	if source_root == null:
		cache["status"] = LOCOMOTION_STATUS_INVALID_SOURCE
		cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_INVALID_SOURCE)
		return cache
	var animation_player := _find_animation_player(source_root)
	if animation_player == null:
		source_root.free()
		cache["status"] = LOCOMOTION_STATUS_MISSING_LIBRARY
		cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_MISSING_LIBRARY)
		return cache
	if _find_skeleton_in_tree(source_root) == null:
		source_root.free()
		cache["status"] = LOCOMOTION_STATUS_MISSING_SKELETON
		cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_MISSING_SKELETON)
		return cache
	var aliases := {
		&"UAL2_Walk_Carry_Loop": [&"Walk_Carry", &"Walk_Carry_Loop"],
		&"UAL2_Zombie_Idle_Loop": [&"Zombie_Idle", &"Zombie_Idle_Loop"],
	}
	var selected: Dictionary = {}
	var library := AnimationLibrary.new()
	for public_name in UAL2_CLIP_NAMES:
		var animation: Animation
		for library_name in animation_player.get_animation_library_list():
			var source_library := animation_player.get_animation_library(StringName(library_name))
			if source_library == null:
				continue
			for raw_name in aliases[public_name]:
				if source_library.has_animation(raw_name):
					animation = source_library.get_animation(raw_name)
					break
			if animation != null:
				break
		if animation == null:
			source_root.free()
			cache["status"] = LOCOMOTION_STATUS_MISSING_CLIP
			cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_MISSING_CLIP)
			return cache
		selected[String(public_name)] = animation
		library.add_animation(public_name, animation)
	source_root.free()
	cache["status"] = LOCOMOTION_STATUS_READY
	cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_READY)
	cache["library"] = library
	cache["library_name"] = &"ual2"
	cache["animations"] = selected
	return cache


static func _load_locomotion_cache(source_path: String) -> Dictionary:
	var cache := _new_locomotion_cache(source_path, LOCOMOTION_STATUS_UNINITIALIZED)
	cache["load_count"] = 1
	if source_path.is_empty() or not ResourceLoader.exists(source_path, "PackedScene"):
		cache["status"] = LOCOMOTION_STATUS_MISSING_SOURCE
		cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_MISSING_SOURCE)
		return cache

	var packed_scene := ResourceLoader.load(source_path, "PackedScene") as PackedScene
	if packed_scene == null:
		cache["status"] = LOCOMOTION_STATUS_INVALID_SOURCE
		cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_INVALID_SOURCE)
		return cache
	var source_root := packed_scene.instantiate()
	if source_root == null:
		cache["status"] = LOCOMOTION_STATUS_INVALID_SOURCE
		cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_INVALID_SOURCE)
		return cache
	cache = _extract_locomotion_resources(source_root, source_path, false)
	source_root.free()
	cache["load_count"] = 1
	return cache


static func _new_locomotion_cache(source_path: String, status: int) -> Dictionary:
	return {
		"source_path": source_path,
		"status": status,
		"status_name": _locomotion_status_name(status),
		"library": null,
		"library_name": &"",
		"animations": {},
		"load_count": 0,
	}


static func _extract_locomotion_resources(source_root: Node, source_path: String, require_skeleton := true) -> Dictionary:
	var cache := _new_locomotion_cache(source_path, LOCOMOTION_STATUS_UNINITIALIZED)
	if source_root == null:
		cache["status"] = LOCOMOTION_STATUS_INVALID_SOURCE
		cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_INVALID_SOURCE)
		return cache

	var animation_player := _find_animation_player(source_root)
	if animation_player == null:
		cache["status"] = LOCOMOTION_STATUS_MISSING_LIBRARY
		cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_MISSING_LIBRARY)
		return cache
	var skeleton := _find_skeleton_in_tree(source_root)
	if require_skeleton and skeleton == null:
		cache["status"] = LOCOMOTION_STATUS_MISSING_SKELETON
		cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_MISSING_SKELETON)
		return cache

	var matches: Dictionary = {}
	var matched_library: AnimationLibrary
	var matched_library_name := &""
	for library_name in animation_player.get_animation_library_list():
		var library := animation_player.get_animation_library(StringName(library_name))
		if library == null:
			continue
		for raw_clip_name in library.get_animation_list():
			var public_clip_name := _normalize_locomotion_clip_name(StringName(raw_clip_name))
			if public_clip_name.is_empty():
				continue
			if matches.has(String(public_clip_name)):
				cache["status"] = LOCOMOTION_STATUS_AMBIGUOUS_CLIP
				cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_AMBIGUOUS_CLIP)
				return cache
			var animation := library.get_animation(StringName(raw_clip_name))
			if animation == null:
				cache["status"] = LOCOMOTION_STATUS_MISSING_CLIP
				cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_MISSING_CLIP)
				return cache
			matches[String(public_clip_name)] = animation
			matched_library = library
			matched_library_name = StringName(library_name)

	if matches.size() != LOCOMOTION_CLIP_NAMES.size():
		cache["status"] = LOCOMOTION_STATUS_MISSING_CLIP
		cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_MISSING_CLIP)
		return cache
	cache["status"] = LOCOMOTION_STATUS_READY
	cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_READY)
	var canonical_library := AnimationLibrary.new()
	for clip_name in LOCOMOTION_CLIP_NAMES:
		var animation: Animation = matches.get(String(clip_name), null) as Animation
		if animation == null:
			cache["status"] = LOCOMOTION_STATUS_MISSING_CLIP
			cache["status_name"] = _locomotion_status_name(LOCOMOTION_STATUS_MISSING_CLIP)
			return cache
		var retargeted_animation := _retarget_legacy_animation(animation)
		canonical_library.add_animation(clip_name, retargeted_animation)
		matches[String(clip_name)] = retargeted_animation
	cache["library"] = canonical_library
	cache["library_name"] = matched_library_name
	cache["animations"] = matches
	return cache


static func _retarget_legacy_animation(source: Animation) -> Animation:
	if source == null:
		return null
	var retargeted := source.duplicate() as Animation
	for track_index in retargeted.get_track_count():
		var source_path := String(retargeted.track_get_path(track_index))
		if source_path.contains(":"):
			continue
		var segments := source_path.split("/")
		if segments.is_empty():
			continue
		var bone_name := String(segments[segments.size() - 1])
		if bone_name.is_empty():
			continue
		retargeted.track_set_path(track_index, NodePath("Armature/Skeleton3D:%s" % bone_name))
	return retargeted


static func _find_animation_player(node: Node) -> AnimationPlayer:
	if not is_instance_valid(node):
		return null
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var player := _find_animation_player(child)
		if player != null:
			return player
	return null


static func _find_skeleton_in_tree(node: Node) -> Skeleton3D:
	if not is_instance_valid(node):
		return null
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var skeleton := _find_skeleton_in_tree(child)
		if skeleton != null:
			return skeleton
	return null


static func _normalize_locomotion_clip_name(value: StringName) -> StringName:
	var text := String(value)
	var slash_index := text.rfind("/")
	if slash_index >= 0:
		text = text.substr(slash_index + 1)
	match text:
		"Idle", "Idle_Loop":
			return &"Idle_Loop"
		"Walk", "Walk_Loop":
			return &"Walk_Loop"
		"Jog_Fwd", "Jog_Fwd_Loop":
			return &"Jog_Fwd_Loop"
	for clip_name in LOCOMOTION_CLIP_NAMES:
		if text == String(clip_name):
			return clip_name
	return &""


static func _normalize_ual2_clip_name(value: StringName) -> StringName:
	var text := String(value)
	var slash_index := text.rfind("/")
	if slash_index >= 0:
		text = text.substr(slash_index + 1)
	match text:
		"Walk_Carry", "Walk_Carry_Loop", "UAL2_Walk_Carry_Loop":
			return &"UAL2_Walk_Carry_Loop"
		"Zombie_Idle", "Zombie_Idle_Loop", "UAL2_Zombie_Idle_Loop":
			return &"UAL2_Zombie_Idle_Loop"
	return &""


static func _locomotion_status_name(status: int) -> StringName:
	match status:
		LOCOMOTION_STATUS_READY:
			return &"ready"
		LOCOMOTION_STATUS_MISSING_SOURCE:
			return &"missing_source"
		LOCOMOTION_STATUS_INVALID_SOURCE:
			return &"invalid_source"
		LOCOMOTION_STATUS_MISSING_LIBRARY:
			return &"missing_library"
		LOCOMOTION_STATUS_MISSING_SKELETON:
			return &"missing_skeleton"
		LOCOMOTION_STATUS_MISSING_CLIP:
			return &"missing_clip"
		LOCOMOTION_STATUS_AMBIGUOUS_CLIP:
			return &"ambiguous_clip"
	return &"uninitialized"


static func _normalize_palette_slot(value: StringName) -> StringName:
	var text := String(value).to_lower()
	if text == "accent" or text == "skin" or text == "hair":
		return StringName(text)
	return &"body"


static func _palette_color(palette_id: StringName, slot: StringName) -> Color:
	var palette: Dictionary = PALETTE_COLORS.get(String(palette_id), PALETTE_COLORS.civilian)
	return palette.get(slot, palette.body)


func _find_skeleton(node: Node) -> Skeleton3D:
	if not is_instance_valid(node):
		return null
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result != null:
			return result
	return null


func _merge_mesh_aabbs(node: Node3D, node_to_pivot: Transform3D) -> AABB:
	var merged := AABB()
	var has_mesh := false
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var mesh_aabb := mesh_instance.get_aabb()
			merged = _transform_aabb(mesh_aabb, node_to_pivot)
			has_mesh = true
	for child in node.get_children():
		var child_node := child as Node3D
		if child_node != null:
			var child_aabb := _merge_mesh_aabbs(child_node, node_to_pivot * child_node.transform)
			if child_aabb.size != Vector3.ZERO:
				if not has_mesh:
					merged = child_aabb
					has_mesh = true
				else:
					merged = merged.merge(child_aabb)
	return merged


func _transform_aabb(aabb: AABB, transform: Transform3D) -> AABB:
	var result := AABB()
	var has_point := false
	for x in [aabb.position.x, aabb.end.x]:
		for y in [aabb.position.y, aabb.end.y]:
			for z in [aabb.position.z, aabb.end.z]:
				var point := transform * Vector3(x, y, z)
				if not has_point:
					result = AABB(point, Vector3.ZERO)
					has_point = true
				else:
					result = result.expand(point)
	return result
