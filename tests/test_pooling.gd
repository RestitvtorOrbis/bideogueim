extends RefCounted

func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var pool := NpcPool.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(pool)
	pool.configure(preload("res://scenes/Npc.tscn"), "civilian")
	var profile := load("res://resources/default_civilian_profile.tres") as NpcProfile
	var hostile_profile := load("res://resources/default_hostile_profile.tres") as NpcProfile
	var first := pool.checkout(profile, Vector3.ZERO, "civilian_life_1", &"", null)
	var civilian_visual := first.get_node_or_null("Visuals/HumanCharacterVisual") as HumanCharacterVisual
	_expect(results, "civilian checkout instantiates one human visual", civilian_visual != null and civilian_visual.get_body_root() != null)
	_expect(results, "civilian checkout uses civilian palette", civilian_visual != null and civilian_visual.get_role() == &"civilian" and civilian_visual.get_palette_id() == &"civilian")
	_expect(results, "civilian visual height stays in civilian band", civilian_visual != null and [1.68, 1.74, 1.80, 1.86].has(civilian_visual.get_target_height()))
	_expect(results, "civilian checkout suppresses primitive body kit", not bool(first.get_node("BodyMesh").visible) and not bool(first.get_node("Jacket").visible) and not bool(first.get_node("Head").visible))
	var civilian_shape := first.get_node("CollisionShape3D").shape as CapsuleShape3D
	_expect(results, "NPC gameplay capsule is 1.75m by 0.35m", civilian_shape != null and is_equal_approx(civilian_shape.height, 1.75) and is_equal_approx(civilian_shape.radius, 0.35) and is_equal_approx(first.get_node("CollisionShape3D").position.y, 0.875))
	var civilian_marker := first.get_node_or_null("RoleMarkerAnchor/WarningMarker") as Label3D
	_expect(results, "civilian marker is enabled, blue, and HDR-readable", _marker_matches_profile(civilian_marker, profile.warning_marker_color))
	first.set("velocity", Vector3.RIGHT)
	first.call("_update_visual_orientation", 1.0)
	_expect(results, "NPC visual yaw follows horizontal movement", civilian_visual != null and is_zero_approx(wrapf(civilian_visual.rotation.y + PI * 0.5, -PI, PI)))
	pool.release(first)
	_expect(results, "pool return deactivates NPC", not bool(first.get("active")) and bool(first.call("is_inactive")))
	var second: Node = pool.checkout(profile, Vector3.ZERO, "civilian_life_2", &"", null)
	_expect(results, "pool checkout reuses instance", first == second)
	_expect(results, "reused NPC receives new lifecycle id", String(second.get("lifecycle_id")) == "civilian_life_2")
	_expect(results, "reused NPC is score eligible", bool(second.call("is_score_eligible")))
	pool.release(second)
	var hostile := pool.checkout(hostile_profile, Vector3.ZERO, "hostile_life_1", &"hostile_group", null)
	var hostile_visual := hostile.get_node_or_null("Visuals/HumanCharacterVisual") as HumanCharacterVisual
	_expect(results, "hostile checkout reuses the pooled NPC", hostile == second)
	_expect(results, "hostile checkout uses hostile palette", hostile_visual != null and hostile_visual.get_role() == &"hostile" and hostile_visual.get_palette_id() == &"hostile")
	var hostile_marker := hostile.get_node_or_null("RoleMarkerAnchor/WarningMarker") as Label3D
	_expect(results, "hostile marker is enabled, red, and HDR-readable", _marker_matches_profile(hostile_marker, hostile_profile.warning_marker_color))
	_expect(results, "hostile checkout has exclusive marker and prop", bool(hostile.get_node("RoleMarkerAnchor/WarningMarker").visible) and bool(hostile.get_node("RoleMarkerAnchor/HostileProp").visible))
	_expect(results, "hostile visual height stays in hostile band", hostile_visual != null and (is_equal_approx(hostile_visual.get_target_height(), 1.78) or is_equal_approx(hostile_visual.get_target_height(), 1.86)))
	if hostile_visual != null:
		hostile_visual.set_motion_speed(3.4)
		_expect(results, "hostile pool checkout selects UAL2 carry walking", hostile_visual.get_selected_animation_clip() == &"UAL2_Walk_Carry_Loop")
		hostile_visual.set_motion_speed(5.0)
		_expect(results, "hostile pool checkout selects jog running", hostile_visual.get_selected_animation_clip() == &"Jog_Fwd_Loop")
	pool.release(hostile)
	pool.queue_free()
	return results

func _marker_matches_profile(marker: Label3D, profile_color: Color) -> bool:
	if marker == null:
		return false
	var expected_color := Color(profile_color.r * 2.0, profile_color.g * 2.0, profile_color.b * 2.0, profile_color.a)
	return marker.visible and marker.modulate == expected_color and marker.font_size == 88 and is_equal_approx(marker.pixel_size, 0.006) and marker.outline_size == 18 and marker.outline_modulate.r == 0.0 and marker.outline_modulate.g == 0.0 and marker.outline_modulate.b == 0.0 and marker.outline_modulate.a >= 0.95 and int(marker.billboard) == 1 and marker.no_depth_test

func _expect(results: Array[Dictionary], name: String, condition: bool) -> void:
	results.append({"name": name, "passed": condition, "message": "" if condition else "Assertion failed"})
