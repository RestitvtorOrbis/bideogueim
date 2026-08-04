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

const ACCESSORY_RENDER_POLICY := &"deferred_shared_skeleton"
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
	_visibility_tier = _normalize_visibility_tier(value)
	_apply_visibility_tier()
	return _visibility_tier


func get_visibility_tier() -> int:
	return _visibility_tier


func set_motion_speed(value: Variant) -> float:
	var normalized := 0.0
	if value is int or value is float:
		var speed := float(value)
		if speed == speed and speed != INF and speed != -INF:
			normalized = maxf(0.0, speed)
	_motion_speed = normalized
	return _motion_speed


func get_motion_speed() -> float:
	return _motion_speed


func set_animation_tier(value: Variant) -> int:
	_animation_tier = _normalize_animation_tier(value)
	return _animation_tier


func get_animation_tier() -> int:
	return _animation_tier


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
		var slot := _palette_slot_for_mesh(mesh_instance)
		mesh_instance.material_override = get_palette_material(slot)


func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		meshes.append_array(_find_mesh_instances(child))
	return meshes


func _palette_slot_for_mesh(mesh_instance: MeshInstance3D) -> StringName:
	var mesh_name := mesh_instance.name.to_lower()
	if mesh_name.contains("hair") or mesh_name.contains("brow") or mesh_name.contains("beard"):
		return &"hair"
	if mesh_name.contains("face") or mesh_name.contains("skin"):
		return &"skin"
	if mesh_name.contains("eye"):
		return &"accent"
	return &"body"


func _apply_visibility_tier() -> void:
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
