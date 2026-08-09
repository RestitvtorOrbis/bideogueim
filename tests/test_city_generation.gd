extends SceneTree

var _results: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_building_footprint_predicate()
	if OS.get_cmdline_user_args().has("--neon-only"):
		_run_neon_only()
		return
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
	_test_spawn_coverage(district_a, "civilian")
	_test_spawn_coverage(district_a, "hostile")
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
	_test_neon_contract(district_a, district_b)
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

func _run_neon_only() -> void:
	var district_a := preload("res://scenes/District.tscn").instantiate()
	var district_b := preload("res://scenes/District.tscn").instantiate()
	district_a.city_seed = 240817
	district_b.city_seed = 240817
	district_a.call("_ensure_city_built")
	district_b.call("_ensure_city_built")
	_test_neon_contract(district_a, district_b)
	_expect("neon-only city keeps the generated building set", district_a.get_building_count() >= 100)
	var failed := 0
	for result in _results:
		if not result["passed"]:
			failed += 1
		print("[CITY-NEON] %s: %s" % ["PASS" if result["passed"] else "FAIL", result["name"]])
	district_a.free()
	district_b.free()
	quit(1 if failed > 0 else 0)

func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

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

func _test_spawn_coverage(district: Node, role: String) -> void:
	var layout: Dictionary = district.get("_layout")
	var points: Array[Marker3D] = district.get_spawn_points(role)
	var bins: Array[int] = []
	bins.resize(16)
	bins.fill(0)
	var half_extent := float(layout.get("half_extent", 0.0))
	var city_size := float(layout.get("city_size", 0.0))
	var in_bounds := true
	var on_road := true
	var building_valid := true
	for point in points:
		var position := point.global_position
		var cell_x := clampi(int(floor((position.x + half_extent) / city_size * 4.0)), 0, 3)
		var cell_z := clampi(int(floor((position.z + half_extent) / city_size * 4.0)), 0, 3)
		bins[cell_z * 4 + cell_x] += 1
		in_bounds = in_bounds and absf(position.x) <= half_extent and absf(position.z) <= half_extent
		var matches_road := false
		for road_center in layout.get("road_centers", []):
			matches_road = matches_road or is_equal_approx(position.x, float(road_center)) or is_equal_approx(position.z, float(road_center))
		on_road = on_road and matches_road
		for building in layout.get("buildings", []):
			if CityLayout.is_point_inside_building_footprint(position, building, 0.5):
				building_valid = false
				break
	var non_empty_cells := 0
	var minimum_count := 2147483647
	var maximum_count := 0
	for count in bins:
		if count > 0:
			non_empty_cells += 1
		minimum_count = mini(minimum_count, count)
		maximum_count = maxi(maximum_count, count)
	_expect("%s markers cover every 4-by-4 map cell" % role, points.size() >= 16 and non_empty_cells == 16)
	_expect("%s marker cell counts stay balanced" % role, points.size() < 16 or maximum_count - minimum_count <= 1)
	_expect("%s markers stay within playable bounds" % role, in_bounds)
	_expect("%s markers stay on generated roads" % role, on_road)
	_expect("%s markers pass the pure building footprint predicate" % role, building_valid)

func _test_neon_contract(district_a: Node, district_b: Node) -> void:
	var neon_a := district_a.get_node_or_null("BuildingNeons") as Node3D
	var neon_b := district_b.get_node_or_null("BuildingNeons") as Node3D
	var positions_a: Array = neon_a.get_meta("fixture_positions", []) if neon_a != null else []
	var positions_b: Array = neon_b.get_meta("fixture_positions", []) if neon_b != null else []
	var sign_positions: Array = neon_a.get_meta("fixture_sign_positions", []) if neon_a != null else []
	var sign_positions_b: Array = neon_b.get_meta("fixture_sign_positions", []) if neon_b != null else []
	var colors_a: Array = neon_a.get_meta("fixture_colors", []) if neon_a != null else []
	var colors_b: Array = neon_b.get_meta("fixture_colors", []) if neon_b != null else []
	var fixture_buildings: Array = neon_a.get_meta("fixture_buildings", []) if neon_a != null else []
	var lights: Array[Node] = neon_a.find_children("*", "OmniLight3D", true, false) if neon_a != null else []
	var signs: Array[Node] = neon_a.find_children("*", "MultiMeshInstance3D", true, false) if neon_a != null else []
	_expect("building neon root exposes exactly eight fixtures", neon_a != null and district_a.get_neon_fixture_count() == 8 and int(neon_a.get_meta("fixture_count", 0)) == 8)
	_expect("building neons are deterministic for equal seeds", _arrays_match(positions_a, positions_b) and _arrays_match(sign_positions, sign_positions_b) and _arrays_match(colors_a, colors_b))
	_expect("building neons span the map", _neon_spans_map(positions_a, district_a.get_city_size()))
	var sign_count := 0
	var emissive_signs := true
	for sign_node in signs:
		var sign := sign_node as MultiMeshInstance3D
		if sign == null or sign.multimesh == null:
			emissive_signs = false
			continue
		sign_count += sign.multimesh.instance_count
		var sign_mesh := sign.multimesh.mesh as BoxMesh
		var material := sign_mesh.material as StandardMaterial3D if sign_mesh != null else null
		if material == null or not material.emission_enabled or material.emission_energy_multiplier < 5.0:
			emissive_signs = false
	_expect("every neon fixture has visible emissive sign geometry", sign_count == 8 and emissive_signs and signs.size() == 3)
	var lights_valid := lights.size() == 8
	for light_node in lights:
		var light := light_node as OmniLight3D
		if light == null or light.light_energy < 5.0 or light.omni_range < 16.0 or light.omni_range > 24.0 or light.shadow_enabled:
			lights_valid = false
			continue
		var fixture_index := int(light.get_meta("fixture_index", -1))
		if fixture_index < 0 or fixture_index >= colors_a.size() or light.light_color != colors_a[fixture_index]:
			lights_valid = false
	_expect("neon signs have matching bounded OmniLights", lights_valid)
	var outside_buildings := sign_positions.size() == 8 and positions_a.size() == 8 and fixture_buildings.size() == 8
	for index in range(mini(sign_positions.size(), fixture_buildings.size())):
		var building: Dictionary = fixture_buildings[index]
		var building_position: Vector3 = building["position"]
		var local_sign: Vector3 = Basis(Vector3.UP, -float(building["rotation"])) * (sign_positions[index] - building_position)
		var local_light: Vector3 = Basis(Vector3.UP, -float(building["rotation"])) * (positions_a[index] - building_position)
		var exterior_sign := absf(local_sign.x) > float(building["width"]) * 0.5 or absf(local_sign.z) > float(building["depth"]) * 0.5
		var exterior_light := absf(local_light.x) > float(building["width"]) * 0.5 or absf(local_light.z) > float(building["depth"]) * 0.5
		if not exterior_sign or not exterior_light:
			outside_buildings = false
	_expect("neon signs and lights stay outside building volumes", outside_buildings)
	_expect("neon node root stays compact", neon_a != null and _count_nodes(neon_a) <= 12)

func _arrays_match(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if left[index] != right[index]:
			return false
	return true

func _neon_spans_map(positions: Array, city_size: float) -> bool:
	if positions.size() != 8:
		return false
	var half_extent := city_size * 0.5
	var x_bins := {}
	var z_bins := {}
	for position in positions:
		var world_position: Vector3 = position
		x_bins[clampi(int(floor((world_position.x + half_extent) / city_size * 4.0)), 0, 3)] = true
		z_bins[clampi(int(floor((world_position.z + half_extent) / city_size * 2.0)), 0, 1)] = true
	return x_bins.size() == 4 and z_bins.size() == 2

func _expect(name: String, passed: bool) -> void:
	_results.append({"name": name, "passed": passed})

func _finish_city_test() -> void:
	var failed := 0
	for result in _results:
		if not result["passed"]:
			failed += 1
		print("[CITY] %s: %s" % ["PASS" if result["passed"] else "FAIL", result["name"]])
	quit(1 if failed > 0 else 0)
