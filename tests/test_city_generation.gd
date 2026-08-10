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
	_test_district_lighting(district_a)

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
	_test_perimeter_contract(district_a, district_b)
	_test_perimeter_physics(district_a)
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


func _test_district_lighting(district: Node) -> void:
	var directional_lights: Array[DirectionalLight3D] = []
	for child in district.get_children():
		if child is DirectionalLight3D:
			directional_lights.append(child as DirectionalLight3D)
	var key: DirectionalLight3D
	var fill: DirectionalLight3D
	for light in directional_lights:
		if light.shadow_enabled:
			key = light
		else:
			fill = light
	var light_contract_valid := directional_lights.size() == 2 and key != null and fill != null and key != fill and key.light_energy > fill.light_energy and absf(key.rotation_degrees.y - fill.rotation_degrees.y) >= 120.0
	_expect("district has exactly one shadowed key and one opposing fill", light_contract_valid)
	if key != null and fill != null:
		_expect("district key and fill use the requested energies", is_equal_approx(key.light_energy, 0.68) and is_equal_approx(fill.light_energy, 0.24))
		_expect("district key and fill keep the requested shadow policy", key.shadow_enabled and not fill.shadow_enabled)
	var world_environment := district.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var environment := world_environment.environment if world_environment != null else null
	_expect("district key color is restrained ivory", key != null and key.light_color == Color(1.0, 0.94, 0.78, 1.0))
	_expect("district ambient color is restrained pale yellow", environment != null and environment.ambient_light_color == Color(0.64, 0.61, 0.47, 1.0))
	_expect("district fog color is restrained pale yellow", environment != null and environment.fog_light_color == Color(0.34, 0.32, 0.25, 1.0))

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
	var ad_copy_a: Array = neon_a.get_meta("ad_copy", []) if neon_a != null else []
	var ad_copy_b: Array = neon_b.get_meta("ad_copy", []) if neon_b != null else []
	var ad_positions_a: Array = neon_a.get_meta("ad_positions", []) if neon_a != null else []
	var ad_positions_b: Array = neon_b.get_meta("ad_positions", []) if neon_b != null else []
	var lights: Array[Node] = neon_a.find_children("*", "OmniLight3D", true, false) if neon_a != null else []
	var signs: Array[Node] = neon_a.find_children("*", "MultiMeshInstance3D", true, false) if neon_a != null else []
	var ads: Array[Node] = neon_a.find_children("*", "Label3D", true, false) if neon_a != null else []
	var expected_ad_copy: Array = ["NOVA", "ARCADE", "24H", "RAMEN", "CLUB", "BYTE", "NOVA", "ARCADE", "24H", "RAMEN", "CLUB", "BYTE"]
	_expect("building neon root exposes exactly twelve fixtures", neon_a != null and district_a.get_neon_fixture_count() == 12 and int(neon_a.get_meta("fixture_count", 0)) == 12)
	_expect("building neons are deterministic for equal seeds", _arrays_match(positions_a, positions_b) and _arrays_match(sign_positions, sign_positions_b) and _arrays_match(colors_a, colors_b) and _arrays_match(ad_copy_a, ad_copy_b) and _arrays_match(ad_positions_a, ad_positions_b))
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
	_expect("every neon fixture has visible emissive sign geometry", sign_count == 12 and emissive_signs and signs.size() == 3)
	var ads_valid := ads.size() == 12 and ad_copy_a == expected_ad_copy and ad_positions_a.size() == 12
	for index in range(ads.size()):
		var ad := ads[index] as Label3D
		if ad == null or index >= colors_a.size():
			ads_valid = false
			continue
		var expected_color := Color(colors_a[index].r * 2.0, colors_a[index].g * 2.0, colors_a[index].b * 2.0, 1.0)
		if ad.name != "Ad%02d" % index or ad.text != expected_ad_copy[index] or ad.font_size != 72 or not is_equal_approx(ad.pixel_size, 0.009) or ad.outline_size != 10 or ad.outline_modulate != Color(0.0, 0.0, 0.0, 0.98) or ad.modulate != expected_color or not ad.double_sided or ad.no_depth_test:
			ads_valid = false
	_expect("neon fixtures have deterministic readable advertising labels", ads_valid)
	var lights_valid := lights.size() == 12
	for light_node in lights:
		var light := light_node as OmniLight3D
		if light == null or not is_equal_approx(light.light_energy, 9.0) or not is_equal_approx(light.omni_range, 280.0) or not is_equal_approx(light.omni_attenuation, 1.0) or light.shadow_enabled:
			lights_valid = false
			continue
		var fixture_index := int(light.get_meta("fixture_index", -1))
		if fixture_index < 0 or fixture_index >= colors_a.size() or light.light_color != colors_a[fixture_index]:
			lights_valid = false
	_expect("neon signs have matching long-range OmniLights", lights_valid)
	var outside_buildings := sign_positions.size() == 12 and positions_a.size() == 12 and fixture_buildings.size() == 12
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
	_expect("neon node root stays compact", neon_a != null and _count_nodes(neon_a) <= 28)

	var street_lights_a := district_a.get_node_or_null("StreetFurniture/StreetLampLights") as Node3D
	var street_lights_b := district_b.get_node_or_null("StreetFurniture/StreetLampLights") as Node3D
	var street_light_nodes: Array[Node] = street_lights_a.find_children("*", "OmniLight3D", true, false) if street_lights_a != null else []
	var lamp_indices_a: Array = street_lights_a.get_meta("lamp_indices", []) if street_lights_a != null else []
	var lamp_indices_b: Array = street_lights_b.get_meta("lamp_indices", []) if street_lights_b != null else []
	var street_lights_valid := street_lights_a != null and street_light_nodes.size() == 72 and lamp_indices_a.size() == 72
	for light_node in street_light_nodes:
		var light := light_node as OmniLight3D
		if light == null or light.light_color != Color("#ffb35c") or not is_equal_approx(light.light_energy, 3.8) or not is_equal_approx(light.omni_range, 34.0) or light.shadow_enabled:
			street_lights_valid = false
	_expect("district constructs exactly 72 bright amber street lights", street_lights_valid)
	_expect("street light selection is deterministic for equal seeds", _arrays_match(lamp_indices_a, lamp_indices_b))

func _test_perimeter_contract(district_a: Node, district_b: Node) -> void:
	var modules_a: Array[Dictionary] = district_a.get_perimeter_modules()
	var modules_b: Array[Dictionary] = district_b.get_perimeter_modules()
	var perimeter := district_a.get_node_or_null("Perimeter") as Node3D
	var boundary := district_a.get_node_or_null("Perimeter/Boundary") as StaticBody3D
	var half_extent: float = district_a.get_city_size() * 0.5
	var city_size: float = district_a.get_city_size()
	_expect("perimeter modules are deterministic for equal seeds", modules_a == modules_b and modules_a.size() > 0)
	_expect("perimeter has all four sides", _perimeter_has_all_sides(modules_a))
	var style_set: Dictionary = {}
	var height_band_set: Dictionary = {}
	var side_seen := [false, false, false, false]
	var side_ends := [0.0, 0.0, 0.0, 0.0]
	var intervals_cover := true
	var dimensions_valid := true
	var inward_placement_valid := true
	for module in modules_a:
		var side := int(module["side"])
		var interval_start := float(module["interval_start"])
		var interval_end := float(module["interval_end"])
		var width := float(module["width"])
		var depth := float(module["depth"])
		var height := float(module["height"])
		style_set[int(module["style"])] = true
		height_band_set[int(module["height_band"])] = true
		dimensions_valid = dimensions_valid and width >= 14.0 and width <= 22.0 and depth >= 10.0 and depth <= 16.0 and height >= 24.0 and height <= 48.0
		if side_seen[side]:
			intervals_cover = intervals_cover and interval_start <= side_ends[side] + 0.001
		side_seen[side] = true
		side_ends[side] = interval_end
		var position: Vector3 = module["position"]
		if side == 0:
			inward_placement_valid = inward_placement_valid and is_equal_approx(position.z - depth * 0.5, half_extent)
		elif side == 1:
			inward_placement_valid = inward_placement_valid and is_equal_approx(position.x - depth * 0.5, half_extent)
		elif side == 2:
			inward_placement_valid = inward_placement_valid and is_equal_approx(position.z + depth * 0.5, -half_extent)
		else:
			inward_placement_valid = inward_placement_valid and is_equal_approx(position.x + depth * 0.5, -half_extent)
	for side in range(4):
		var side_modules: Array = []
		for module in modules_a:
			if int(module["side"]) == side:
				side_modules.append(module)
		if side_modules.is_empty():
			intervals_cover = false
			continue
		intervals_cover = intervals_cover and float(side_modules[0]["interval_start"]) <= -half_extent - 8.0 and float(side_modules[-1]["interval_end"]) >= half_extent + 8.0
	_expect("perimeter intervals overlap with no gaps", intervals_cover)
	_expect("perimeter uses at least three facade styles", style_set.size() >= 3)
	_expect("perimeter uses four height bands", height_band_set.size() >= 4)
	_expect("perimeter module dimensions stay in contract ranges", dimensions_valid)
	_expect("perimeter inner facades align to playable bounds", inward_placement_valid)
	_expect("perimeter exposes deterministic generation metadata", perimeter != null and district_a.get_perimeter_module_count() == modules_a.size() and district_a.get_perimeter_style_count() == style_set.size() and district_a.get_perimeter_height_band_count() == height_band_set.size())
	var batched_visuals: bool = perimeter != null and perimeter.get_node_or_null("Roofs") is MultiMeshInstance3D and perimeter.get_node_or_null("Windows") is MultiMeshInstance3D
	for style in range(4):
		var style_instance := perimeter.get_node_or_null("Style%d" % style) as MultiMeshInstance3D if perimeter != null else null
		batched_visuals = batched_visuals and style_instance != null and style_instance.multimesh != null and style_instance.multimesh.instance_count > 0
	_expect("perimeter bodies roofs and windows use batched MultiMeshes", batched_visuals and perimeter != null and perimeter.get_child_count() == 7)
	var boundary_shapes_valid: bool = boundary != null and boundary.get_child_count() == 4 and district_a.get_boundary_shape_count() == 4
	var expected_wall_length: float = city_size + 16.0
	if boundary != null:
		for child in boundary.get_children():
			var collision := child as CollisionShape3D
			var shape := collision.shape as BoxShape3D if collision != null else null
			boundary_shapes_valid = boundary_shapes_valid and collision != null and shape != null and is_equal_approx(shape.size.y, 25.0)
			if collision != null and shape != null:
				var north_or_south := absf(shape.size.x - expected_wall_length) < 0.001
				var east_or_west := absf(shape.size.z - expected_wall_length) < 0.001
				boundary_shapes_valid = boundary_shapes_valid and ((north_or_south and is_equal_approx(absf(collision.position.z), half_extent + 4.0)) or (east_or_west and is_equal_approx(absf(collision.position.x), half_extent + 4.0)))
	_expect("boundary has exactly four eight-metre walls", boundary_shapes_valid)
	_expect("boundary walls overlap corners by eight metres", boundary != null and is_equal_approx(float(boundary.get_meta("wall_length", 0.0)), expected_wall_length) and is_equal_approx(float(boundary.get_meta("wall_thickness", 0.0)), 8.0))
	_expect("boundary wall planes align exactly to city bounds", boundary != null and is_equal_approx(float(boundary.get_meta("wall_bottom", 0.0)), -1.0) and is_equal_approx(float(boundary.get_meta("wall_top", 0.0)), 24.0))

func _perimeter_has_all_sides(modules: Array[Dictionary]) -> bool:
	var sides: Dictionary = {}
	for module in modules:
		sides[int(module["side"])] = true
	return sides.size() == 4

func _test_perimeter_physics(district: Node) -> void:
	var boundary := district.get_node_or_null("Perimeter/Boundary") as StaticBody3D
	if boundary == null:
		_expect("vehicle-shaped probes meet every perimeter wall", false)
		return
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 1.6, 4.0)
	var half_extent: float = district.get_city_size() * 0.5
	var probes := [
		Vector3(0.0, 1.0, half_extent + 1.0),
		Vector3(half_extent + 1.0, 1.0, 0.0),
		Vector3(0.0, 1.0, -half_extent - 1.0),
		Vector3(-half_extent - 1.0, 1.0, 0.0),
	]
	var blocked := true
	for probe in probes:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, probe)
		query.collision_mask = 1
		blocked = blocked and not district.get_world_3d().direct_space_state.intersect_shape(query, 8).is_empty()
	_expect("vehicle-shaped probes meet every perimeter wall", blocked)

func _arrays_match(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if left[index] != right[index]:
			return false
	return true

func _neon_spans_map(positions: Array, city_size: float) -> bool:
	if positions.size() != 12:
		return false
	var half_extent := city_size * 0.5
	var x_bins := {}
	var z_bins := {}
	var bins := {}
	for position in positions:
		var world_position: Vector3 = position
		x_bins[clampi(int(floor((world_position.x + half_extent) / city_size * 4.0)), 0, 3)] = true
		var z_bin := clampi(int(floor((world_position.z + half_extent) / city_size * 3.0)), 0, 2)
		var x_bin := clampi(int(floor((world_position.x + half_extent) / city_size * 4.0)), 0, 3)
		z_bins[z_bin] = true
		bins["%d:%d" % [x_bin, z_bin]] = true
	return x_bins.size() == 4 and z_bins.size() == 3 and bins.size() == 12

func _expect(name: String, passed: bool) -> void:
	_results.append({"name": name, "passed": passed})

func _finish_city_test() -> void:
	var failed := 0
	for result in _results:
		if not result["passed"]:
			failed += 1
		print("[CITY] %s: %s" % ["PASS" if result["passed"] else "FAIL", result["name"]])
	quit(1 if failed > 0 else 0)
