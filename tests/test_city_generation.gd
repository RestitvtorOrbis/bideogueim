extends SceneTree

var _results: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
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
	_expect("repeated geometry uses MultiMesh", district_a.get_node_or_null("BuildingBlocks/Style0") is MultiMeshInstance3D and district_a.get_node_or_null("StreetFurniture/LampPosts") is MultiMeshInstance3D)
	_expect("scene tree stays compact", _count_nodes(district_a) < 180)

	var player := preload("res://scenes/Player.tscn").instantiate() as CharacterBody3D
	var vehicle := preload("res://scenes/ArcadeVehicle.tscn").instantiate() as RigidBody3D
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
	var failed := 0
	for result in _results:
		if not result["passed"]:
			failed += 1
		print("[CITY] %s: %s" % ["PASS" if result["passed"] else "FAIL", result["name"]])
	quit(1 if failed > 0 else 0)

func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

func _expect(name: String, passed: bool) -> void:
	_results.append({"name": name, "passed": passed})
