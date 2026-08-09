extends RefCounted

const VISUAL_SCENE_PATH := "res://scenes/visuals/characters/HumanCharacterVisual.tscn"
const VISUAL_SCRIPT_PATH := "res://scripts/visual/characters/human_character_visual.gd"
const CATALOG_RESOURCE_PATH := "res://resources/human_character_catalog.tres"
const MALE_BODY_PATH := "res://assets/characters/quaternius/models/Superhero_Male_FullBody.gltf"
const FEMALE_BODY_PATH := "res://assets/characters/quaternius/models/Superhero_Female_FullBody.gltf"
const MISSING_MODEL_PATH := "res://assets/characters/quaternius/models/does_not_exist.gltf"
const MISSING_ACCESSORY_PATH := "res://assets/characters/quaternius/hairstyles/does_not_exist.gltf"
const MISSING_LOCOMOTION_PATH := "res://assets/characters/quaternius/animations/does_not_exist.glb"
const UAL2_SOURCE_PATH := "res://assets/characters/quaternius/animations/ual2_standard.glb"
const MISSING_UAL2_PATH := "res://assets/characters/quaternius/animations/ual2_missing.glb"
const AABB_TOLERANCE := 0.0001

const BODY_FIXTURES := [
	{"label": "male", "path": MALE_BODY_PATH, "height": 1.70},
	{"label": "female", "path": FEMALE_BODY_PATH, "height": 1.70},
	{"label": "male", "path": MALE_BODY_PATH, "height": 1.82},
	{"label": "female", "path": FEMALE_BODY_PATH, "height": 1.82},
]


func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var visual_scene := load(VISUAL_SCENE_PATH) as PackedScene
	var visual_script := load(VISUAL_SCRIPT_PATH) as Script
	_expect(results, "human visual scene loads", visual_scene != null)
	_expect(results, "human visual script loads", visual_script != null)
	if visual_scene == null or visual_script == null:
		return results

	var scene_fixture := visual_scene.instantiate() as Node3D
	_expect(results, "human visual scene instantiates", scene_fixture != null)
	_expect(results, "human visual scene uses the visual script", scene_fixture != null and scene_fixture.get_script() == visual_script)
	if scene_fixture != null:
		scene_fixture.free()

	_test_body_configurations(results, visual_scene)
	_test_repeated_configuration(results, visual_scene)
	_test_reconfiguration_replaces_root(results, visual_scene)
	_test_invalid_configurations_clear_state(results, visual_scene)
	_test_catalog_configuration(results, visual_scene)
	_test_shared_palette_materials(results)
	_test_visual_state_apis(results, visual_scene)
	_test_hand_lookup_and_accessory_policy(results, visual_scene)
	_test_locomotion_resources(results, visual_scene)
	_test_locomotion_failure_statuses(results)
	_test_ual2_locomotion(results, visual_scene)
	return results


func _test_body_configurations(results: Array[Dictionary], visual_scene: PackedScene) -> void:
	for fixture in BODY_FIXTURES:
		var label: String = fixture.label
		var height: float = fixture.height
		var visual := _create_visual(visual_scene)
		var configured := visual.configure_body(fixture.path, height)
		_expect(results, "%s body configures at %.2fm" % [label, height], configured)
		if configured:
			var normalized_aabb := visual.get_normalized_aabb()
			var model_pivot := visual.get_node("ModelPivot") as Node3D
			_expect(results, "%s %.2fm normalized feet are at Y zero" % [label, height], is_zero_approx(normalized_aabb.position.y))
			_expect(results, "%s %.2fm normalized height matches target" % [label, height], is_equal_approx(normalized_aabb.size.y, height))
			_expect(results, "%s %.2fm reports a positive uniform scale" % [label, height], visual.get_uniform_scale() > 0.0)
			_expect(results, "%s %.2fm applies uniform ModelPivot scale" % [label, height], model_pivot != null and _is_uniform_positive_scale(model_pivot.scale))
			_expect(results, "%s %.2fm faces negative Z" % [label, height], visual.get_forward_vector().is_equal_approx(Vector3.FORWARD))
			_expect(results, "%s %.2fm exposes a valid body root" % [label, height], is_instance_valid(visual.get_body_root()))
		_dispose_visual(visual)


func _test_repeated_configuration(results: Array[Dictionary], visual_scene: PackedScene) -> void:
	var visual := _create_visual(visual_scene)
	var first_configured := visual.configure_body(MALE_BODY_PATH, 1.70)
	var first_aabb := visual.get_normalized_aabb()
	var first_pivot := visual.get_node("ModelPivot") as Node3D
	var first_transform := first_pivot.transform if first_pivot != null else Transform3D.IDENTITY
	var first_forward := visual.get_forward_vector()
	var first_scale := visual.get_uniform_scale()
	var first_root := visual.get_body_root()
	var second_configured := visual.configure_body(MALE_BODY_PATH, 1.70)
	var second_pivot := visual.get_node("ModelPivot") as Node3D
	var second_transform := second_pivot.transform if second_pivot != null else Transform3D.IDENTITY
	_expect(results, "repeated male configuration succeeds", first_configured and second_configured)
	_expect(results, "repeated configuration keeps the normalized AABB deterministic", _aabb_matches(first_aabb, visual.get_normalized_aabb()))
	_expect(results, "repeated configuration keeps the pivot transform deterministic", _transform_matches(first_transform, second_transform))
	_expect(results, "repeated configuration keeps the scale deterministic", is_equal_approx(first_scale, visual.get_uniform_scale()))
	_expect(results, "repeated configuration keeps the forward vector deterministic", first_forward.is_equal_approx(visual.get_forward_vector()))
	_expect(results, "repeated configuration replaces the prior body root", not is_instance_valid(first_root) and is_instance_valid(visual.get_body_root()))
	_dispose_visual(visual)


func _test_reconfiguration_replaces_root(results: Array[Dictionary], visual_scene: PackedScene) -> void:
	var visual := _create_visual(visual_scene)
	var first_configured := visual.configure_body(MALE_BODY_PATH, 1.70)
	var first_root := visual.get_body_root()
	var second_configured := visual.configure_body(FEMALE_BODY_PATH, 1.82)
	var second_root := visual.get_body_root()
	_expect(results, "reconfiguration from male to female succeeds", first_configured and second_configured)
	_expect(results, "reconfiguration frees the prior body root", not is_instance_valid(first_root))
	_expect(results, "reconfiguration exposes the replacement body root", is_instance_valid(second_root) and second_root != first_root)
	_dispose_visual(visual)


func _test_invalid_configurations_clear_state(results: Array[Dictionary], visual_scene: PackedScene) -> void:
	var invalid_fixtures := [
		{"label": "empty path", "path": "", "height": 1.70},
		{"label": "nonexistent path", "path": "res://assets/characters/quaternius/models/does_not_exist.gltf", "height": 1.70},
		{"label": "zero height", "path": MALE_BODY_PATH, "height": 0.0},
		{"label": "negative height", "path": MALE_BODY_PATH, "height": -1.0},
	]
	var visual := _create_visual(visual_scene)
	for fixture in invalid_fixtures:
		visual.configure_body(MALE_BODY_PATH, 1.70)
		var prior_root := visual.get_body_root()
		var configured := visual.configure_body(fixture.path, fixture.height)
		_expect(results, "%s returns false" % fixture.label, not configured)
		_expect(results, "%s clears the prior body root" % fixture.label, not is_instance_valid(prior_root) and visual.get_body_root() == null)
		_expect(results, "%s clears all visual state" % fixture.label, _is_clear(visual))
	_dispose_visual(visual)


func _test_catalog_configuration(results: Array[Dictionary], visual_scene: PackedScene) -> void:
	var catalog := load(CATALOG_RESOURCE_PATH) as HumanCharacterCatalog
	_expect(results, "catalog resource is available to the visual wrapper", catalog != null)
	if catalog == null:
		return

	var first := _create_visual(visual_scene)
	var second := _create_visual(visual_scene)
	var seed := "crowd-lifecycle-250"
	var first_configured := first.configure_from_catalog(catalog, seed, &"hostile", 1.70)
	var second_configured := second.configure_from_catalog(catalog, seed, &"hostile", 1.70)
	_expect(results, "catalog configuration succeeds", first_configured and second_configured)
	_expect(results, "catalog stores a stable lifecycle seed", first.get_character_seed() == second.get_character_seed() and first.get_character_seed() == HumanCharacterCatalog.stable_seed(seed))
	_expect(results, "catalog selects a body inside the two-model range", first.get_body_variant_index() >= 0 and first.get_body_variant_index() < catalog.body_paths.size())
	_expect(results, "catalog selects one of six hairstyles", first.get_hairstyle_variant_index() >= 0 and first.get_hairstyle_variant_index() < catalog.hairstyle_paths.size())
	_expect(results, "catalog selects one of two eyebrow sets", first.get_eyebrow_variant_index() >= 0 and first.get_eyebrow_variant_index() < catalog.eyebrow_paths.size())
	_expect(results, "catalog selects the hostile palette", first.get_role() == &"hostile" and first.get_palette_id() == &"hostile")
	_expect(results, "catalog selection is deterministic for the body", first.get_selected_body_path() == second.get_selected_body_path())
	_expect(results, "catalog selection is deterministic for hairstyle", first.get_selected_hairstyle_path() == second.get_selected_hairstyle_path())
	_expect(results, "catalog selection is deterministic for eyebrows", first.get_selected_eyebrow_path() == second.get_selected_eyebrow_path())
	_expect(results, "catalog selection is deterministic for indices", first.get_body_variant_index() == second.get_body_variant_index() and first.get_hairstyle_variant_index() == second.get_hairstyle_variant_index() and first.get_eyebrow_variant_index() == second.get_eyebrow_variant_index())
	_expect(results, "catalog loads the selected hairstyle without instantiating a second skeleton", first.get_selected_hairstyle_scene() != null and not first.are_accessories_rendered() and first.get_accessory_render_policy() == &"deferred_shared_skeleton")
	_expect(results, "catalog loads the selected eyebrows without instantiating a second skeleton", first.get_selected_eyebrow_scene() != null and not first.are_accessories_rendered())

	var player := _create_visual(visual_scene)
	var civilian := player.configure_from_catalog(catalog, 19, &"civilian", 1.70)
	_expect(results, "catalog maps civilian to civilian palette", civilian and player.get_palette_id() == &"civilian")
	var player_configured := player.configure_from_catalog(catalog, 19, &"player", 1.70)
	_expect(results, "catalog maps player to player palette", player_configured and player.get_palette_id() == &"player")
	var invalid_role_configured := player.configure_from_catalog(catalog, 19, &"unknown_role", 1.70)
	_expect(results, "unknown role normalizes to civilian palette", invalid_role_configured and player.get_role() == &"civilian" and player.get_palette_id() == &"civilian")
	_dispose_visual(first)
	_dispose_visual(second)
	_dispose_visual(player)


func _test_shared_palette_materials(results: Array[Dictionary]) -> void:
	var before := HumanCharacterVisual.get_palette_material_cache_size()
	var first_material: StandardMaterial3D
	var logical_instances: Array[HumanCharacterVisual] = []
	for index in 250:
		var logical_visual := HumanCharacterVisual.new()
		logical_instances.append(logical_visual)
		var material := logical_visual.get_palette_material(&"body")
		if index == 0:
			first_material = material
		else:
			_expect(results, "logical palette instance %d reuses the same Resource" % index, material == first_material)
	for logical_visual in logical_instances:
		logical_visual.free()
	var after := HumanCharacterVisual.get_palette_material_cache_size()
	_expect(results, "250 logical instances add at most one body palette cache entry", after - before <= 1)
	_expect(results, "shared palette Resource is valid", first_material != null and is_instance_valid(first_material))

	var hostile_body := HumanCharacterVisual.get_cached_palette_material(&"hostile", 0, &"body")
	var hostile_body_again := HumanCharacterVisual.get_cached_palette_material(&"hostile", 0, &"body")
	var hostile_body_variant := HumanCharacterVisual.get_cached_palette_material(&"hostile", 1, &"body")
	var hostile_accent := HumanCharacterVisual.get_cached_palette_material(&"hostile", 0, &"accent")
	_expect(results, "palette cache keys by palette and variant", hostile_body == hostile_body_again and hostile_body != hostile_accent)
	_expect(results, "palette cache separates body variants", hostile_body != hostile_body_variant)
	_expect(results, "palette cache exposes all shared slots", HumanCharacterVisual.get_cached_palette_material(&"player", 1, &"body") != null and HumanCharacterVisual.get_cached_palette_material(&"player", 1, &"accent") != null and HumanCharacterVisual.get_cached_palette_material(&"player", 1, &"skin") != null and HumanCharacterVisual.get_cached_palette_material(&"player", 1, &"hair") != null)


func _test_visual_state_apis(results: Array[Dictionary], visual_scene: PackedScene) -> void:
	var visual := _create_visual(visual_scene)
	_expect(results, "visual state starts at full visibility", visual.get_visibility_tier() == HumanCharacterVisual.VISIBILITY_TIER_FULL and (visual.get_node("ModelPivot") as Node3D).visible)
	_expect(results, "invalid visibility values normalize to full", visual.set_visibility_tier(-10) == HumanCharacterVisual.VISIBILITY_TIER_FULL)
	_expect(results, "named reduced visibility is accepted", visual.set_visibility_tier(&"reduced") == HumanCharacterVisual.VISIBILITY_TIER_REDUCED and (visual.get_node("ModelPivot") as Node3D).visible)
	_expect(results, "hidden visibility applies to ModelPivot", visual.set_visibility_tier(&"hidden") == HumanCharacterVisual.VISIBILITY_TIER_HIDDEN and not (visual.get_node("ModelPivot") as Node3D).visible)
	_expect(results, "invalid visibility values clamp to hidden", visual.set_visibility_tier(99) == HumanCharacterVisual.VISIBILITY_TIER_HIDDEN)
	_expect(results, "negative motion speed normalizes to zero", is_zero_approx(visual.set_motion_speed(-3.0)))
	_expect(results, "non-numeric motion speed normalizes to zero", is_zero_approx(visual.set_motion_speed("fast")))
	_expect(results, "motion speed stores finite non-negative values", is_equal_approx(visual.set_motion_speed(4.25), 4.25) and is_equal_approx(visual.get_motion_speed(), 4.25))
	_expect(results, "named throttled animation tier is stored as data", visual.set_animation_tier(&"throttled") == HumanCharacterVisual.ANIMATION_TIER_THROTTLED and visual.get_animation_tier() == HumanCharacterVisual.ANIMATION_TIER_THROTTLED)
	_expect(results, "named frozen animation tier is stored as data", visual.set_animation_tier(&"frozen") == HumanCharacterVisual.ANIMATION_TIER_FROZEN and visual.get_animation_tier() == HumanCharacterVisual.ANIMATION_TIER_FROZEN)
	_expect(results, "invalid animation tier clamps to frozen", visual.set_animation_tier(99) == HumanCharacterVisual.ANIMATION_TIER_FROZEN)
	_expect(results, "invalid animation tier text normalizes to normal", visual.set_animation_tier("unknown") == HumanCharacterVisual.ANIMATION_TIER_NORMAL)

	var catalog := load(CATALOG_RESOURCE_PATH) as HumanCharacterCatalog
	var configured := visual.configure_from_catalog(catalog, 5, &"civilian", 1.70)
	visual.set_visibility_tier(&"hidden")
	visual.set_motion_speed(8.0)
	visual.set_animation_tier(&"frozen")
	var reconfigured := visual.configure_from_catalog(catalog, 6, &"civilian", 1.70)
	var model_pivot := visual.get_node("ModelPivot") as Node3D
	_expect(results, "reconfigure succeeds after state changes", configured and reconfigured)
	_expect(results, "reconfigure resets visibility state", visual.get_visibility_tier() == HumanCharacterVisual.VISIBILITY_TIER_FULL and model_pivot != null and model_pivot.visible)
	_expect(results, "reconfigure resets motion speed", is_zero_approx(visual.get_motion_speed()))
	_expect(results, "reconfigure resets animation tier to normal", visual.get_animation_tier() == HumanCharacterVisual.ANIMATION_TIER_NORMAL)
	var visibility_apply_count := visual.get_visibility_apply_count()
	var animation_play_count := visual.get_animation_play_count()
	visual.set_visibility_tier(HumanCharacterVisual.VISIBILITY_TIER_FULL)
	visual.set_animation_tier(HumanCharacterVisual.ANIMATION_TIER_NORMAL)
	_expect(results, "unchanged visual tiers do not reapply visibility or restart playback", visual.get_visibility_apply_count() == visibility_apply_count and visual.get_animation_play_count() == animation_play_count)
	_dispose_visual(visual)


func _test_hand_lookup_and_accessory_policy(results: Array[Dictionary], visual_scene: PackedScene) -> void:
	var empty_visual := _create_visual(visual_scene)
	_expect(results, "missing skeleton hand lookup returns null", empty_visual.get_right_hand_bone() == null and empty_visual.get_right_hand_bone_index() == -1)
	_dispose_visual(empty_visual)
	var missing_catalog_visual := _create_visual(visual_scene)
	_expect(results, "missing catalog fails gracefully", not missing_catalog_visual.configure_from_catalog(null, 0, &"civilian", 1.70) and missing_catalog_visual.get_body_root() == null)
	_dispose_visual(missing_catalog_visual)

	var catalog := load(CATALOG_RESOURCE_PATH) as HumanCharacterCatalog
	var visual := _create_visual(visual_scene)
	var configured := visual.configure_from_catalog(catalog, 42, &"player", 1.70)
	var descriptor: Variant = visual.get_right_hand_bone()
	_expect(results, "configured body resolves a right-hand descriptor", configured and descriptor != null)
	if descriptor != null:
		var skeleton := descriptor.get("skeleton", null) as Skeleton3D
		var bone_index := int(descriptor.get("bone_index", -1))
		_expect(results, "right-hand descriptor points at a Skeleton3D", skeleton != null)
		_expect(results, "right-hand descriptor resolves hand_r", skeleton != null and bone_index >= 0 and String(skeleton.get_bone_name(bone_index)).to_lower() == "hand_r")
		_expect(results, "right-hand index API matches descriptor", visual.get_right_hand_bone_index() == bone_index)

	var missing_accessory_catalog := HumanCharacterCatalog.new()
	missing_accessory_catalog.body_paths = [MALE_BODY_PATH]
	missing_accessory_catalog.hairstyle_paths = [MISSING_ACCESSORY_PATH]
	missing_accessory_catalog.eyebrow_paths = [MISSING_ACCESSORY_PATH]
	var missing_accessory_visual := _create_visual(visual_scene)
	var missing_accessory_configured := missing_accessory_visual.configure_from_catalog(missing_accessory_catalog, 3, &"civilian", 1.70)
	_expect(results, "missing accessories do not fail body configuration", missing_accessory_configured)
	_expect(results, "missing hairstyle resource is reported as null", missing_accessory_visual.get_selected_hairstyle_scene() == null)
	_expect(results, "missing eyebrow resource is reported as null", missing_accessory_visual.get_selected_eyebrow_scene() == null)
	_expect(results, "missing accessory selection remains deterministic", missing_accessory_visual.get_selected_hairstyle_path() == MISSING_ACCESSORY_PATH and missing_accessory_visual.get_selected_eyebrow_path() == MISSING_ACCESSORY_PATH and not missing_accessory_visual.are_accessories_rendered())

	var missing_model_catalog := HumanCharacterCatalog.new()
	missing_model_catalog.body_paths = [MISSING_MODEL_PATH]
	var missing_model_visual := _create_visual(visual_scene)
	_expect(results, "missing body model fails gracefully", not missing_model_visual.configure_from_catalog(missing_model_catalog, 3, &"civilian", 1.70) and missing_model_visual.get_body_root() == null)
	_dispose_visual(visual)
	_dispose_visual(missing_accessory_visual)
	_dispose_visual(missing_model_visual)


func _test_locomotion_resources(results: Array[Dictionary], visual_scene: PackedScene) -> void:
	var expected_names: Array[StringName] = [&"Idle_Loop", &"Walk_Loop", &"Jog_Fwd_Loop"]
	var first := _create_visual(visual_scene)
	var names := first.get_locomotion_clip_names()
	_expect(results, "locomotion exposes exactly three public clip names", names == expected_names)
	var first_animations: Dictionary = {}
	for clip_name in expected_names:
		first_animations[String(clip_name)] = first.get_locomotion_animation(clip_name)
		_expect(results, "locomotion exposes %s" % String(clip_name), first_animations[String(clip_name)] != null)
	_expect(results, "locomotion cache is ready", first.is_locomotion_ready() and first.get_locomotion_load_status_name() == &"ready")
	_expect(results, "locomotion cache contains three clips", first.get_locomotion_animation_cache_size() == 3)
	_expect(results, "locomotion source is loaded once", first.get_locomotion_source_load_count() == 1)
	var library := first.get_locomotion_animation_library()
	_expect(results, "locomotion exposes one shared animation library", library != null)
	var logical_instances: Array[HumanCharacterVisual] = []
	for index in 250:
		var logical_visual := HumanCharacterVisual.new()
		logical_instances.append(logical_visual)
		_expect(results, "logical locomotion instance %d shares the library" % index, logical_visual.get_locomotion_animation_library() == library)
		for clip_name in expected_names:
			var animation := logical_visual.get_locomotion_animation(clip_name)
			_expect(results, "logical locomotion instance %d shares %s" % [index, String(clip_name)], animation == first_animations[String(clip_name)])
	for logical_visual in logical_instances:
		logical_visual.free()
	_expect(results, "locomotion cache remains bounded after 250 instances", first.get_locomotion_animation_cache_size() == 3 and first.get_locomotion_source_load_count() == 1)
	_expect(results, "unsupported locomotion clip fails without changing cache", first.get_locomotion_animation(&"Run_Loop") == null and first.get_locomotion_animation_cache_size() == 3)
	_dispose_visual(first)


func _test_locomotion_failure_statuses(results: Array[Dictionary]) -> void:
	var missing_source := HumanCharacterVisual.inspect_locomotion_source_path(MISSING_LOCOMOTION_PATH)
	_expect(results, "missing locomotion source has a defined failure", int(missing_source.get("status", -1)) == HumanCharacterVisual.LOCOMOTION_STATUS_MISSING_SOURCE and missing_source.get("animations", {}).is_empty())

	var missing_library_root := Node3D.new()
	missing_library_root.add_child(Skeleton3D.new())
	var missing_library := HumanCharacterVisual.inspect_locomotion_source_tree(missing_library_root)
	_expect(results, "missing locomotion library has a defined failure", int(missing_library.get("status", -1)) == HumanCharacterVisual.LOCOMOTION_STATUS_MISSING_LIBRARY)
	missing_library_root.free()

	var missing_skeleton_root := _create_locomotion_fixture(false, [&"Idle_Loop", &"Walk_Loop", &"Jog_Fwd_Loop"])
	var missing_skeleton := HumanCharacterVisual.inspect_locomotion_source_tree(missing_skeleton_root)
	_expect(results, "missing locomotion skeleton has a defined failure", int(missing_skeleton.get("status", -1)) == HumanCharacterVisual.LOCOMOTION_STATUS_MISSING_SKELETON)
	missing_skeleton_root.free()

	var missing_clip_root := _create_locomotion_fixture(true, [&"Idle_Loop", &"Walk_Loop"])
	var missing_clip := HumanCharacterVisual.inspect_locomotion_source_tree(missing_clip_root)
	_expect(results, "missing locomotion clip has a defined failure", int(missing_clip.get("status", -1)) == HumanCharacterVisual.LOCOMOTION_STATUS_MISSING_CLIP)
	missing_clip_root.free()

	var complete_fixture := _create_locomotion_fixture(true, [&"Idle_Loop", &"Walk_Loop", &"Jog_Fwd_Loop"])
	var complete := HumanCharacterVisual.inspect_locomotion_source_tree(complete_fixture)
	_expect(results, "complete in-memory locomotion source shares its exact three clips", int(complete.get("status", -1)) == HumanCharacterVisual.LOCOMOTION_STATUS_READY and complete.get("animations", {}).size() == 3)
	complete_fixture.free()


func _test_ual2_locomotion(results: Array[Dictionary], visual_scene: PackedScene) -> void:
	var visual := _create_visual(visual_scene)
	var expected_names: Array[StringName] = [&"UAL2_Walk_Carry_Loop", &"UAL2_Zombie_Idle_Loop"]
	var first_animations: Dictionary = {}
	for clip_name in expected_names:
		var animation := visual.get_ual2_animation(clip_name)
		first_animations[String(clip_name)] = animation
		_expect(results, "UAL2 exposes %s" % String(clip_name), animation != null and animation.loop_mode != Animation.LOOP_NONE)
	_expect(results, "UAL2 source is ready", visual.is_ual2_ready() and visual.get_ual2_load_status_name() == &"ready")
	_expect(results, "UAL2 cache contains only selected clips", visual.get_ual2_animation_cache_size() == 2)
	_expect(results, "UAL2 source is loaded once", visual.get_ual2_source_load_count() == 1)
	var library := visual.get_ual2_animation_library()
	_expect(results, "UAL2 exposes a shared animation library", library != null)
	for index in 250:
		var logical_visual := HumanCharacterVisual.new()
		_expect(results, "logical UAL2 instance %d shares the library" % index, logical_visual.get_ual2_animation_library() == library)
		for clip_name in expected_names:
			_expect(results, "logical UAL2 instance %d shares %s" % [index, String(clip_name)], logical_visual.get_ual2_animation(clip_name) == first_animations[String(clip_name)])
		logical_visual.free()
	_expect(results, "UAL2 cache remains bounded after 250 instances", visual.get_ual2_animation_cache_size() == 2 and visual.get_ual2_source_load_count() == 1)
	_expect(results, "unsupported UAL2 clip fails without changing cache", visual.get_ual2_animation(&"UAL2_Run_Loop") == null and visual.get_ual2_animation_cache_size() == 2)

	var catalog := load(CATALOG_RESOURCE_PATH) as HumanCharacterCatalog
	var configured := visual.configure_from_catalog(catalog, "ual2-hostile", &"hostile", 1.78)
	_expect(results, "hostile UAL2 playback fixture configures", configured)
	if configured:
		var animation_player := visual.get_body_root().get_node_or_null("LocomotionAnimationPlayer") as AnimationPlayer
		visual.set_animation_tier(HumanCharacterVisual.ANIMATION_TIER_NORMAL)
		visual.set_motion_speed(3.4)
		_expect(results, "normal tier applies motion speed immediately", visual.get_selected_animation_clip() == &"UAL2_Walk_Carry_Loop" and animation_player != null and animation_player.is_playing())
		var throttled_clip := visual.get_selected_animation_clip()
		var throttled_playback: StringName = &""
		if animation_player != null:
			throttled_playback = animation_player.current_animation
		visual.set_animation_tier(HumanCharacterVisual.ANIMATION_TIER_THROTTLED)
		visual.set_motion_speed(5.0)
		_expect(results, "throttled tier defers motion clip changes", visual.get_selected_animation_clip() == throttled_clip and animation_player != null and animation_player.current_animation == throttled_playback and animation_player.is_playing())
		_expect(results, "throttled tier uses manual animation processing", visual.get_animation_process_mode() == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL)
		visual.update_locomotion()
		_expect(results, "throttled tier applies pending motion on explicit update", visual.get_selected_animation_clip() == &"Jog_Fwd_Loop" and animation_player != null and animation_player.is_playing())
		var throttled_advances := visual.get_manual_animation_advance_count()
		_expect(results, "throttled animation does not advance before 0.1 seconds", not visual.advance_visual_animation(0.09) and visual.get_manual_animation_advance_count() == throttled_advances)
		_expect(results, "throttled animation advances at the bounded 10 Hz cadence", visual.advance_visual_animation(0.02) and visual.get_manual_animation_advance_count() == throttled_advances + 1)
		visual.set_animation_tier(HumanCharacterVisual.ANIMATION_TIER_FROZEN)
		var frozen_advances := visual.get_manual_animation_advance_count()
		_expect(results, "frozen tier uses manual processing and stops on role idle", visual.get_animation_process_mode() == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL and visual.get_selected_animation_clip() == &"UAL2_Zombie_Idle_Loop" and animation_player != null and not animation_player.is_playing())
		_expect(results, "frozen tier does not manually advance animation", not visual.advance_visual_animation(1.0) and visual.get_manual_animation_advance_count() == frozen_advances)
		visual.set_motion_speed(5.0)
		_expect(results, "frozen tier keeps idle stopped while storing speed", visual.get_selected_animation_clip() == &"UAL2_Zombie_Idle_Loop" and is_equal_approx(visual.get_motion_speed(), 5.0) and animation_player != null and not animation_player.is_playing())
		visual.set_animation_tier(HumanCharacterVisual.ANIMATION_TIER_NORMAL)
		_expect(results, "normal tier resumes continuous idle processing", visual.get_animation_process_mode() == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE and visual.get_selected_animation_clip() == &"Jog_Fwd_Loop" and animation_player != null and animation_player.is_playing())
		visual.set_animation_tier(HumanCharacterVisual.ANIMATION_TIER_THROTTLED)
		visual.set_motion_speed(3.4)
		var pending_before_reconfigure := visual.get_motion_speed()
		var reconfigured_from_throttled := visual.configure_from_catalog(catalog, "ual2-hostile-reconfigure", &"hostile", 1.78)
		var reconfigured_player := visual.get_body_root().get_node_or_null("LocomotionAnimationPlayer") as AnimationPlayer
		animation_player = reconfigured_player
		_expect(results, "reconfigure clears pending throttled speed", reconfigured_from_throttled and is_equal_approx(pending_before_reconfigure, 3.4) and is_zero_approx(visual.get_motion_speed()) and visual.get_animation_tier() == HumanCharacterVisual.ANIMATION_TIER_NORMAL and visual.get_selected_animation_clip() == &"UAL2_Zombie_Idle_Loop" and reconfigured_player != null and reconfigured_player.is_playing())

		visual.set_motion_speed(3.4)
		_expect(results, "hostile walk selects UAL2 carry loop", visual.get_selected_animation_clip() == &"UAL2_Walk_Carry_Loop" and visual.get_selected_animation_library() == &"ual2")
		visual.set_motion_speed(5.0)
		_expect(results, "running selects the legacy jog loop", visual.get_selected_animation_clip() == &"Jog_Fwd_Loop" and visual.get_selected_animation_library() == &"")
		visual.set_motion_speed(0.0)
		_expect(results, "hostile idle selects the UAL2 hostile loop", visual.get_selected_animation_clip() == &"UAL2_Zombie_Idle_Loop" and visual.get_selected_animation_library() == &"ual2")
		var before := visual.global_position
		if animation_player != null:
			animation_player.advance(0.25)
		_expect(results, "locomotion animation does not move the gameplay visual root", visual.global_position.is_equal_approx(before))
		visual.set_animation_tier(HumanCharacterVisual.ANIMATION_TIER_FROZEN)
		_expect(results, "frozen tier stops on idle", animation_player != null and not animation_player.is_playing() and visual.get_selected_animation_clip() == &"UAL2_Zombie_Idle_Loop")
		visual.set_animation_tier(HumanCharacterVisual.ANIMATION_TIER_NORMAL)
		_expect(results, "normal tier resumes selected idle", animation_player != null and animation_player.is_playing())

	var missing := HumanCharacterVisual.inspect_ual2_source_path(MISSING_UAL2_PATH)
	_expect(results, "missing UAL2 source has a defined failure", int(missing.get("status", -1)) == HumanCharacterVisual.LOCOMOTION_STATUS_MISSING_SOURCE and missing.get("animations", {}).is_empty())
	_dispose_visual(visual)


func _create_locomotion_fixture(include_skeleton: bool, clip_names: Array[StringName]) -> Node3D:
	var root := Node3D.new()
	var player := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	for clip_name in clip_names:
		library.add_animation(clip_name, Animation.new())
	player.add_animation_library(&"", library)
	root.add_child(player)
	if include_skeleton:
		root.add_child(Skeleton3D.new())
	return root


func _create_visual(visual_scene: PackedScene) -> HumanCharacterVisual:
	var visual := visual_scene.instantiate() as HumanCharacterVisual
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(visual)
	return visual


func _dispose_visual(visual: HumanCharacterVisual) -> void:
	if is_instance_valid(visual):
		visual.free()


func _is_uniform_positive_scale(scale: Vector3) -> bool:
	return scale.x > 0.0 and is_equal_approx(scale.x, scale.y) and is_equal_approx(scale.x, scale.z)


func _aabb_matches(left: AABB, right: AABB) -> bool:
	return left.position.is_equal_approx(right.position) and left.size.is_equal_approx(right.size)


func _transform_matches(left: Transform3D, right: Transform3D) -> bool:
	return left.origin.is_equal_approx(right.origin) and left.basis.x.is_equal_approx(right.basis.x) and left.basis.y.is_equal_approx(right.basis.y) and left.basis.z.is_equal_approx(right.basis.z)


func _is_clear(visual: HumanCharacterVisual) -> bool:
	var model_pivot := visual.get_node("ModelPivot") as Node3D
	return visual.get_normalized_aabb() == AABB() and is_zero_approx(visual.get_target_height()) and is_equal_approx(visual.get_uniform_scale(), 1.0) and visual.get_forward_vector().is_equal_approx(Vector3.FORWARD) and model_pivot != null and _transform_matches(model_pivot.transform, Transform3D.IDENTITY)


func _expect(results: Array[Dictionary], name: String, passed: bool) -> void:
	results.append({"name": name, "passed": passed, "message": "" if passed else "Assertion failed"})
