extends SceneTree

var _results: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_building_footprint_predicate()
	var district_a := preload("res://scenes/District.tscn").instantiate()
	var district_b := preload("res://scenes/District.tscn").instantiate()
	district_a.city_seed = 918273
	district_b.city_seed = 918273
	root.add_child(district_a)
	root.add_child(district_b)
	await process_frame

	_expect("same seed produces the same signature", district_a.get_generation_signature() == district_b.get_generation_signature())
	_expect("city is substantially larger than the old district", district_a.get_city_size() > 400.0)
	_expect("city contains many generated buildings", district_a.get_building_count() >= 100)
	_expect("city contains multiple parks", district_a.get_park_count() >= 2)
	_expect("civilian spawns are distributed", district_a.get_spawn_points("civilian").size() >= 32)
	_expect("hostile spawns are distributed", district_a.get_spawn_points("hostile").size() >= 24)
	_expect("all generated civilian markers avoid buildings", _all_spawn_points_are_valid(district_a, "civilian"))
	_expect("all generated hostile markers avoid buildings", _all_spawn_points_are_valid(district_a, "hostile"))
	_expect("player spawn is available", district_a.get_player_spawn_position().y > 0.0)
	_expect("vehicle spawn is available", district_a.get_vehicle_spawn_position().y > 0.0)
	var player_spawn_a: Vector3 = district_a.get_player_spawn_position()
	var vehicle_spawn_a: Vector3 = district_a.get_vehicle_spawn_position()
	var player_spawn_b: Vector3 = district_b.get_player_spawn_position()
	var vehicle_spawn_b: Vector3 = district_b.get_vehicle_spawn_position()
	_expect("vehicle spawn is exactly 3.25 m forward", vehicle_spawn_a - player_spawn_a == Vector3.FORWARD * 3.25)
	_expect("default spawn positions are exact", player_spawn_a == Vector3(0.0, 1.25, 0.0) and vehicle_spawn_a == Vector3(0.0, 1.25, -3.25))
	_expect("spawn positions are deterministic", player_spawn_a == player_spawn_b and vehicle_spawn_a == vehicle_spawn_b)
	_expect("ground collision is generated", district_a.get_node_or_null("Ground/CollisionShape3D") != null)
	_expect("horizontal road collision is generated", district_a.get_node_or_null("Roads/RoadX/CollisionShape3D") != null)
	_expect("vertical road contract is preserved", district_a.get_node_or_null("Roads/RoadZ/CollisionShape3D") != null)
	_expect("building collision is batched", district_a.get_node_or_null("BuildingBlocks/Collision/CollisionShape3D") != null)
	var navigation_region := district_a.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	_expect("navigation region has generated navigation data", navigation_region != null and navigation_region.navigation_mesh != null)
	var lamp_field := district_a.get_node_or_null("StreetFurniture/LampCollision") as LampField
	var lamp_posts := district_a.get_node_or_null("StreetFurniture/LampPosts") as MultiMeshInstance3D
	var lamp_glows := district_a.get_node_or_null("StreetFurniture/LampGlows") as MultiMeshInstance3D
	_expect("repeated geometry uses MultiMesh", district_a.get_node_or_null("BuildingBlocks/Style0") is MultiMeshInstance3D and lamp_posts != null and lamp_glows != null)
	_expect("every generated lamp has one collision shape", lamp_field != null and lamp_field.get_lamp_count() > 0 and lamp_field.get_collision_shape_count() == lamp_field.get_lamp_count())
	_expect("lamp render and collision indices are stable", lamp_field != null and lamp_posts != null and lamp_glows != null and lamp_posts.multimesh.instance_count == lamp_field.get_lamp_count() and lamp_glows.multimesh.instance_count == lamp_field.get_lamp_count() and lamp_field.get_lamp_index_for_shape(0) == 0)
	_expect("scene tree stays compact", _count_nodes(district_a) < 180)

	var vehicle_script := load("res://scripts/vehicle/arcade_vehicle.gd") as GDScript
	var vehicle := preload("res://scenes/ArcadeVehicle.tscn").instantiate() as RigidBody3D
	if vehicle_script == null or vehicle == null or vehicle.get_script() == null or not vehicle.has_method("try_enter"):
		_expect("vehicle script loads and exposes try_enter", false)
		if vehicle != null:
			vehicle.free()
		_finish_city_test()
		return
	var player := preload("res://scenes/Player.tscn").instantiate() as CharacterBody3D
	root.add_child(player)
	root.add_child(vehicle)
	player.global_position = player_spawn_a
	vehicle.global_position = vehicle_spawn_a
	await process_frame
	var player_shape := player.get_node("CollisionShape3D") as CollisionShape3D
	var overlap_query := PhysicsShapeQueryParameters3D.new()
	overlap_query.shape = player_shape.shape
	overlap_query.transform = player_shape.global_transform
	overlap_query.collision_mask = 4
	var initial_overlaps: Array[Dictionary] = district_a.get_world_3d().direct_space_state.intersect_shape(overlap_query, 16)
	_expect("initial player and vehicle collision shapes do not overlap", initial_overlaps.is_empty())
	var player_position_before_entry := player.global_position
	var entered_on_first_frame := bool(vehicle.call("try_enter", player))
	_expect("vehicle entry succeeds on first frame without moving player", entered_on_first_frame and player.global_position == player_position_before_entry)
	player.queue_free()
	vehicle.queue_free()

	district_a.queue_free()
	district_b.queue_free()
	await process_frame
	_finish_city_test()

func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

func _expect(name: String, passed: bool) -> void:
func _test_building_footprint_predicate() -> void:
	var unrotated := {
		"position": Vector3(10.0, 8.0, -4.0),
		"width": 10.0,
		"depth": 6.0,
		"rotation": 0.0,
	}
	_expect("footprint rejects an unrotated building center", CityLayout.is_point_inside_building_footprint(Vector3(10.0, 1.25, -4.0), unrotated))
	_expect("footprint includes the unrotated clearance boundary", CityLayout.is_point_inside_building_footprint(Vector3(15.5, 1.25, -4.0), unrotated))
	_expect("footprint accepts just beyond the unrotated clearance boundary", not CityLayout.is_point_inside_building_footprint(Vector3(15.51, 1.25, -4.0), unrotated))

	var rotated := unrotated.duplicate()
	rotated["rotation"] = PI * 0.5
	_expect("footprint rejects a rotated interior point", CityLayout.is_point_inside_building_footprint(Vector3(10.0, 1.25, 1.0), rotated))
	_expect("rotated footprint includes its clearance boundary", CityLayout.is_point_inside_building_footprint(Vector3(10.0, 1.25, 1.5), rotated))
	_expect("rotated footprint accepts just beyond its clearance boundary", not CityLayout.is_point_inside_building_footprint(Vector3(10.0, 1.25, 1.51), rotated))

func _all_spawn_points_are_valid(district: Node, role: String) -> bool:
	for point in district.get_spawn_points(role):
		if not district.is_npc_spawn_position_valid(point.global_position):
			return false
	return true

	_results.append({"name": name, "passed": passed})

func _finish_city_test() -> void:
	var failed := 0
	for result in _results:
		if not result["passed"]:
			failed += 1
		print("[CITY] %s: %s" % ["PASS" if result["passed"] else "FAIL", result["name"]])
	quit(1 if failed > 0 else 0)
