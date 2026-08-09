extends Node3D

@export_category("Procedural City")
@export var city_seed: int = 240817
@export_range(3, 15, 2) var grid_size: int = 9
@export_range(24.0, 72.0, 1.0) var block_size: float = 44.0
@export_range(8.0, 20.0, 0.5) var road_width: float = 12.0
@export_range(2, 9, 1) var max_buildings_per_block: int = 6
@export_range(0.0, 0.45, 0.01) var park_frequency: float = 0.16
@export_range(4, 128, 1) var civilian_spawn_count: int = 48
@export_range(4, 128, 1) var hostile_spawn_count: int = 32

const NEON_FIXTURE_COUNT := 8
const NEON_BIN_COLUMNS := 4
const NEON_BIN_ROWS := 2
const NEON_LIGHT_RANGE := 280.0
const NEON_LIGHT_ENERGY := 9.0
const STREET_LAMP_LIGHT_COUNT := 48
const STREET_LAMP_LIGHT_RANGE := 30.0
const STREET_LAMP_LIGHT_ENERGY := 3.2
const STREET_LAMP_LIGHT_COLOR := Color("#ffb35c")

var _layout: Dictionary = {}
var _materials: Dictionary = {}
var _city_built := false

func _ready() -> void:
	_ensure_city_built()

func _ensure_city_built() -> void:
	if _city_built:
		return
	_layout = CityLayout.generate(
		city_seed,
		grid_size,
		block_size,
		road_width,
		max_buildings_per_block,
		park_frequency,
		civilian_spawn_count,
		hostile_spawn_count
	)
	_materials = CityMeshes.make_materials()
	_build_ground()
	_build_roads()
	_build_sidewalks()
	_build_buildings()
	_build_perimeter()
	_build_parks_and_props()
	_build_navigation()
	_build_spawns()
	set_meta("city_seed", city_seed)
	set_meta("city_size", float(_layout["city_size"]))
	set_meta("building_count", (_layout["buildings"] as Array).size())
	_city_built = true

func get_player_spawn_position() -> Vector3:
	_ensure_city_built()
	return _layout["player_spawn"]

func get_vehicle_spawn_position() -> Vector3:
	_ensure_city_built()
	return _layout["vehicle_spawn"]

func get_spawn_points(role: String) -> Array[Marker3D]:
	_ensure_city_built()
	var group_name := &"civilian_spawn" if role.to_lower() == "civilian" else &"hostile_spawn"
	var points: Array[Marker3D] = []
	for node in get_tree().get_nodes_in_group(group_name):
		if node is Marker3D and is_ancestor_of(node):
			points.append(node)
	return points

func get_city_size() -> float:
	_ensure_city_built()
	return float(_layout.get("city_size", 0.0))

func get_city_bounds() -> AABB:
	_ensure_city_built()
	var size := get_city_size()
	return AABB(Vector3(-size * 0.5, -1.0, -size * 0.5), Vector3(size, 8.0, size))

func get_building_count() -> int:
	_ensure_city_built()
	return (_layout.get("buildings", []) as Array).size()

func get_perimeter_modules() -> Array[Dictionary]:
	_ensure_city_built()
	var modules: Array[Dictionary] = _layout.get("perimeter_modules", [])
	return modules

func get_perimeter_module_count() -> int:
	_ensure_city_built()
	var perimeter := get_node_or_null("Perimeter")
	return int(perimeter.get_meta("module_count", 0)) if perimeter != null else 0

func get_perimeter_style_count() -> int:
	_ensure_city_built()
	var perimeter := get_node_or_null("Perimeter")
	return int(perimeter.get_meta("style_count", 0)) if perimeter != null else 0

func get_perimeter_height_band_count() -> int:
	_ensure_city_built()
	var perimeter := get_node_or_null("Perimeter")
	return int(perimeter.get_meta("height_band_count", 0)) if perimeter != null else 0

func get_boundary_shape_count() -> int:
	_ensure_city_built()
	var boundary := get_node_or_null("Perimeter/Boundary")
	return int(boundary.get_meta("shape_count", 0)) if boundary != null else 0

func get_neon_fixture_count() -> int:
	_ensure_city_built()
	var neon_root := get_node_or_null("BuildingNeons")
	return int(neon_root.get_meta("fixture_count", 0)) if neon_root != null else 0

func get_park_count() -> int:
	_ensure_city_built()
	return (_layout.get("parks", []) as Array).size()

func get_generation_signature() -> String:
	_ensure_city_built()
	return str(_layout.get("signature", ""))

func is_npc_spawn_position_valid(world_position: Vector3, clearance: float = 0.5) -> bool:
	_ensure_city_built()
	var local_position := to_local(world_position)
	var buildings: Array = _layout.get("buildings", [])
	for building in buildings:
		if CityLayout.is_point_inside_building_footprint(local_position, building, clearance):
			return false
	return true

func get_nearest_road_position(world_position: Vector3) -> Vector3:
	_ensure_city_built()
	var centers: Array = _layout.get("road_centers", [])
	if centers.is_empty():
		return get_vehicle_spawn_position()
	var nearest_x := float(centers[0])
	var nearest_z := float(centers[0])
	for center_value in centers:
		var center := float(center_value)
		if absf(world_position.x - center) < absf(world_position.x - nearest_x):
			nearest_x = center
		if absf(world_position.z - center) < absf(world_position.z - nearest_z):
			nearest_z = center
	var extent := get_city_size() * 0.5 - road_width * 0.5
	var result := world_position
	result.x = clampf(result.x, -extent, extent)
	result.z = clampf(result.z, -extent, extent)
	if absf(world_position.x - nearest_x) < absf(world_position.z - nearest_z):
		result.x = nearest_x
	else:
		result.z = nearest_z
	result.y = 1.25
	return result

func _build_ground() -> void:
	var size: float = _layout["city_size"]
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 31
	add_child(ground)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = CityMeshes.box_mesh(Vector3(size, 0.6, size), _materials["ground"])
	mesh_instance.position = Vector3(0.0, -0.3, 0.0)
	ground.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(size, 0.6, size)
	collision.shape = shape
	collision.position = Vector3(0.0, -0.3, 0.0)
	ground.add_child(collision)

func _build_roads() -> void:
	var size: float = _layout["city_size"]
	var extent := size * 0.5
	var centers: Array = _layout["road_centers"]
	var road_root := Node3D.new()
	road_root.name = "Roads"
	add_child(road_root)

	var road_x := StaticBody3D.new()
	road_x.name = "RoadX"
	road_x.collision_layer = 1
	road_x.collision_mask = 31
	road_root.add_child(road_x)
	var road_z := StaticBody3D.new()
	road_z.name = "RoadZ"
	road_z.collision_layer = 1
	road_z.collision_mask = 31
	road_root.add_child(road_z)

	var horizontal_mesh := CityMeshes.box_mesh(Vector3(size, 0.14, road_width - 0.2), _materials["road"])
	var vertical_mesh := CityMeshes.box_mesh(Vector3(road_width - 0.2, 0.14, size), _materials["road"])
	var horizontal_transforms: Array = []
	var vertical_transforms: Array = []
	for center in centers:
		horizontal_transforms.append(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.06, float(center))))
		vertical_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(center), 0.06, 0.0)))
	_add_multimesh(road_x, "Surface", horizontal_mesh, horizontal_transforms)
	_add_multimesh(road_z, "Surface", vertical_mesh, vertical_transforms)

	var road_faces := PackedVector3Array()
	for center in centers:
		_append_box_faces(road_faces, Vector3(0.0, 0.06, float(center)), Vector3(size, 0.14, road_width), 0.0)
		_append_box_faces(road_faces, Vector3(float(center), 0.06, 0.0), Vector3(road_width, 0.14, size), 0.0)
	var road_collision := CollisionShape3D.new()
	road_collision.name = "CollisionShape3D"
	var road_shape := ConcavePolygonShape3D.new()
	road_shape.set_faces(road_faces)
	road_collision.shape = road_shape
	road_x.add_child(road_collision)

	var compatibility_collision := CollisionShape3D.new()
	compatibility_collision.name = "CollisionShape3D"
	var compatibility_shape := BoxShape3D.new()
	compatibility_shape.size = Vector3(0.2, 0.2, 0.2)
	compatibility_collision.shape = compatibility_shape
	compatibility_collision.position = Vector3(extent + 8.0, -1.0, extent + 8.0)
	road_z.add_child(compatibility_collision)

	var horizontal_markings: Array = []
	var vertical_markings: Array = []
	var lane_mesh := CityMeshes.box_mesh(Vector3(4.0, 0.025, 0.16), _materials["road_marking"])
	for center in centers:
		for offset in range(-int(extent) + 10, int(extent) - 8, 12):
			horizontal_markings.append(Transform3D(Basis.IDENTITY, Vector3(float(offset), 0.145, float(center))))
			vertical_markings.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(float(center), 0.145, float(offset))))
	_add_multimesh(road_x, "LaneMarkings", lane_mesh, horizontal_markings)
	_add_multimesh(road_z, "LaneMarkings", lane_mesh, vertical_markings)

func _build_sidewalks() -> void:
	var size: float = _layout["city_size"]
	var centers: Array = _layout["road_centers"]
	var root := Node3D.new()
	root.name = "Sidewalks"
	add_child(root)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 31
	root.add_child(body)

	var strip_width := 2.5
	var offset := road_width * 0.5 - strip_width * 0.5 - 0.25
	var horizontal_mesh := CityMeshes.box_mesh(Vector3(size, 0.22, strip_width), _materials["sidewalk"])
	var vertical_mesh := CityMeshes.box_mesh(Vector3(strip_width, 0.22, size), _materials["sidewalk"])
	var horizontal_transforms: Array = []
	var vertical_transforms: Array = []
	var faces := PackedVector3Array()
	for center in centers:
		for side in [-1.0, 1.0]:
			var horizontal_position := Vector3(0.0, 0.22, float(center) + offset * side)
			var vertical_position := Vector3(float(center) + offset * side, 0.22, 0.0)
			horizontal_transforms.append(Transform3D(Basis.IDENTITY, horizontal_position))
			vertical_transforms.append(Transform3D(Basis.IDENTITY, vertical_position))
			_append_box_faces(faces, horizontal_position, Vector3(size, 0.22, strip_width), 0.0)
			_append_box_faces(faces, vertical_position, Vector3(strip_width, 0.22, size), 0.0)
	_add_multimesh(root, "Horizontal", horizontal_mesh, horizontal_transforms)
	_add_multimesh(root, "Vertical", vertical_mesh, vertical_transforms)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	collision.shape = shape
	body.add_child(collision)

func _build_buildings() -> void:
	var root := Node3D.new()
	root.name = "BuildingBlocks"
	add_child(root)
	var style_transforms: Array = [[], [], [], []]
	var roof_transforms: Array = []
	var window_transforms: Array = []
	var building_faces := PackedVector3Array()

	for building in _layout["buildings"]:
		var position: Vector3 = building["position"]
		var width: float = building["width"]
		var depth: float = building["depth"]
		var height: float = building["height"]
		var rotation: float = building["rotation"]
		var style: int = clampi(int(building["style"]), 0, 3)
		var yaw_basis := Basis(Vector3.UP, rotation)
		style_transforms[style].append(Transform3D(yaw_basis.scaled(Vector3(width, height, depth)), position))
		roof_transforms.append(Transform3D(
			yaw_basis.scaled(Vector3(width * 0.92, 0.45, depth * 0.92)),
			Vector3(position.x, height + 0.225, position.z)
		))
		_append_building_windows(building, window_transforms)
		_append_box_faces(building_faces, position, Vector3(width, height, depth), rotation)

	for style in range(4):
		var mesh := CityMeshes.box_mesh(Vector3.ONE, _materials["building_%d" % style])
		_add_multimesh(root, "Style%d" % style, mesh, style_transforms[style])
	_add_multimesh(root, "Roofs", CityMeshes.box_mesh(Vector3.ONE, _materials["building_roof"]), roof_transforms)
	_add_multimesh(root, "Windows", CityMeshes.box_mesh(Vector3.ONE, _materials["glass"]), window_transforms)

	var collision_body := StaticBody3D.new()
	collision_body.name = "Collision"
	collision_body.collision_layer = 1
	collision_body.collision_mask = 31
	root.add_child(collision_body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(building_faces)
	collision.shape = shape
	collision_body.add_child(collision)
	_build_building_neons()

func _build_perimeter() -> void:
	var modules: Array[Dictionary] = _layout.get("perimeter_modules", [])
	var perimeter_root := Node3D.new()
	perimeter_root.name = "Perimeter"
	add_child(perimeter_root)
	var style_transforms: Array = [[], [], [], []]
	var roof_transforms: Array = []
	var window_transforms: Array = []
	var styles_seen: Dictionary = {}
	var height_bands_seen: Dictionary = {}

	for module in modules:
		var position: Vector3 = module["position"]
		var width := float(module["width"])
		var depth := float(module["depth"])
		var height := float(module["height"])
		var rotation := float(module["rotation"])
		var style := clampi(int(module["style"]), 0, 3)
		var yaw_basis := Basis(Vector3.UP, rotation)
		style_transforms[style].append(Transform3D(yaw_basis.scaled(Vector3(width, height, depth)), position))
		roof_transforms.append(Transform3D(
			yaw_basis.scaled(Vector3(width * 0.92, 0.45, depth * 0.92)),
			Vector3(position.x, height + 0.225, position.z)
		))
		_append_perimeter_windows(module, window_transforms)
		styles_seen[style] = true
		height_bands_seen[int(module["height_band"])] = true

	for style in range(4):
		_add_multimesh(
			perimeter_root,
			"Style%d" % style,
			CityMeshes.box_mesh(Vector3.ONE, _materials["building_%d" % style]),
			style_transforms[style]
		)
	_add_multimesh(perimeter_root, "Roofs", CityMeshes.box_mesh(Vector3.ONE, _materials["building_roof"]), roof_transforms)
	_add_multimesh(perimeter_root, "Windows", CityMeshes.box_mesh(Vector3.ONE, _materials["glass"]), window_transforms)

	var boundary := StaticBody3D.new()
	boundary.name = "Boundary"
	boundary.collision_layer = 1
	boundary.collision_mask = 31
	perimeter_root.add_child(boundary)
	var extent := float(_layout["half_extent"])
	var city_size := float(_layout["city_size"])
	var wall_thickness := 8.0
	var wall_bottom := -1.0
	var wall_top := 24.0
	var wall_height := wall_top - wall_bottom
	var wall_center_y := (wall_top + wall_bottom) * 0.5
	var wall_length := city_size + wall_thickness * 2.0
	var wall_specs := [
		{"name": "North", "size": Vector3(wall_length, wall_height, wall_thickness), "position": Vector3(0.0, wall_center_y, extent + wall_thickness * 0.5)},
		{"name": "East", "size": Vector3(wall_thickness, wall_height, wall_length), "position": Vector3(extent + wall_thickness * 0.5, wall_center_y, 0.0)},
		{"name": "South", "size": Vector3(wall_length, wall_height, wall_thickness), "position": Vector3(0.0, wall_center_y, -extent - wall_thickness * 0.5)},
		{"name": "West", "size": Vector3(wall_thickness, wall_height, wall_length), "position": Vector3(-extent - wall_thickness * 0.5, wall_center_y, 0.0)},
	]
	for spec in wall_specs:
		var collision := CollisionShape3D.new()
		collision.name = spec["name"]
		var shape := BoxShape3D.new()
		shape.size = spec["size"]
		collision.shape = shape
		collision.position = spec["position"]
		boundary.add_child(collision)
	boundary.set_meta("shape_count", wall_specs.size())
	boundary.set_meta("wall_thickness", wall_thickness)
	boundary.set_meta("wall_bottom", wall_bottom)
	boundary.set_meta("wall_top", wall_top)
	boundary.set_meta("wall_length", wall_length)

	perimeter_root.set_meta("module_count", modules.size())
	perimeter_root.set_meta("style_count", styles_seen.size())
	perimeter_root.set_meta("height_band_count", height_bands_seen.size())
	perimeter_root.set_meta("modules", modules)

func _append_perimeter_windows(module: Dictionary, output: Array) -> void:
	var position: Vector3 = module["position"]
	var width := float(module["width"])
	var depth := float(module["depth"])
	var height := float(module["height"])
	var rotation := float(module["rotation"])
	var local_normal: Vector3 = module["inner_local_normal"]
	var yaw_basis := Basis(Vector3.UP, rotation)
	var floors := clampi(int(height / 3.25) - 1, 1, 8)
	var columns := clampi(int(width / 3.1), 2, 8)
	for floor in range(floors):
		var local_y := 2.4 + floor * 3.25
		for column in range(columns):
			var along := lerpf(-width * 0.5 + 1.5, width * 0.5 - 1.5, float(column) / float(maxi(1, columns - 1)))
			var local_position := Vector3(along, local_y, local_normal.z * (depth * 0.5 + 0.045))
			var world_position := Vector3(position.x, 0.0, position.z) + yaw_basis * local_position
			output.append(Transform3D(yaw_basis.scaled(Vector3(1.1, 0.9, 0.08)), world_position))

func _build_building_neons() -> void:
	var neon_root := Node3D.new()
	neon_root.name = "BuildingNeons"
	add_child(neon_root)

	var palette := CityMeshes.neon_palette()
	var material_keys := ["neon_cyan", "neon_magenta", "neon_purple"]
	var color_names := ["Cyan", "Magenta", "Purple"]
	var sign_transforms: Array = [[], [], []]
	var sign_fixture_indices: Array = [[], [], []]
	var fixture_positions: Array[Vector3] = []
	var fixture_sign_positions: Array[Vector3] = []
	var fixture_colors: Array[Color] = []
	var fixture_building_indices: Array[int] = []
	var fixture_buildings: Array[Dictionary] = []
	var selected := _select_neon_buildings()

	for fixture_index in range(selected.size()):
		var selected_entry: Dictionary = selected[fixture_index]
		var building: Dictionary = selected_entry["building"]
		var palette_index := fixture_index % palette.size()
		var facade := _make_neon_facade(building)
		var sign_transform: Transform3D = facade["sign_transform"]
		var sign_position := sign_transform.origin
		var light_position: Vector3 = facade["light_position"]
		sign_transforms[palette_index].append(sign_transform)
		sign_fixture_indices[palette_index].append(fixture_index)
		fixture_positions.append(light_position)
		fixture_sign_positions.append(sign_position)
		fixture_colors.append(palette[palette_index])
		fixture_building_indices.append(int(selected_entry["index"]))
		fixture_buildings.append(building)

		var light := OmniLight3D.new()
		light.name = "OmniLight%02d" % fixture_index
		light.position = light_position
		light.light_color = palette[palette_index]
		light.light_energy = NEON_LIGHT_ENERGY
		light.omni_range = NEON_LIGHT_RANGE
		light.omni_attenuation = 1.0
		light.shadow_enabled = false
		light.set_meta("fixture_index", fixture_index)
		light.set_meta("sign_position", sign_position)
		light.set_meta("building_index", int(selected_entry["index"]))
		neon_root.add_child(light)

	for palette_index in range(palette.size()):
		if sign_transforms[palette_index].is_empty():
			continue
		var signs := _add_multimesh(
			neon_root,
			"Signs%s" % color_names[palette_index],
			CityMeshes.box_mesh(Vector3.ONE, _materials[material_keys[palette_index]]),
			sign_transforms[palette_index]
		)
		signs.set_meta("fixture_indices", sign_fixture_indices[palette_index])
		signs.set_meta("color", palette[palette_index])

	neon_root.set_meta("fixture_count", selected.size())
	neon_root.set_meta("fixture_positions", fixture_positions)
	neon_root.set_meta("fixture_sign_positions", fixture_sign_positions)
	neon_root.set_meta("fixture_colors", fixture_colors)
	neon_root.set_meta("fixture_building_indices", fixture_building_indices)
	neon_root.set_meta("fixture_buildings", fixture_buildings)
	set_meta("neon_fixture_count", selected.size())

func _select_neon_buildings() -> Array[Dictionary]:
	var buildings: Array = _layout.get("buildings", [])
	var candidates_by_bin: Dictionary = {}
	var eligible_indices: Array[int] = []
	var city_size := float(_layout.get("city_size", 1.0))
	var half_extent := float(_layout.get("half_extent", city_size * 0.5))

	for index in range(buildings.size()):
		var building: Dictionary = buildings[index]
		if float(building.get("width", 0.0)) <= 0.0 or float(building.get("depth", 0.0)) <= 0.0:
			continue
		eligible_indices.append(index)
		var position: Vector3 = building["position"]
		var bin_x := clampi(int(floor((position.x + half_extent) / city_size * NEON_BIN_COLUMNS)), 0, NEON_BIN_COLUMNS - 1)
		var bin_z := clampi(int(floor((position.z + half_extent) / city_size * NEON_BIN_ROWS)), 0, NEON_BIN_ROWS - 1)
		var bin_index := bin_z * NEON_BIN_COLUMNS + bin_x
		if not candidates_by_bin.has(bin_index):
			candidates_by_bin[bin_index] = []
		var candidates: Array = candidates_by_bin[bin_index]
		candidates.append(index)
		candidates_by_bin[bin_index] = candidates

	var selected_indices: Array[int] = []
	for bin_index in range(NEON_BIN_COLUMNS * NEON_BIN_ROWS):
		if not candidates_by_bin.has(bin_index):
			continue
		var candidates: Array = candidates_by_bin[bin_index]
		var selected_index := _lowest_neon_rank(candidates)
		if selected_index >= 0:
			selected_indices.append(selected_index)

	while selected_indices.size() < NEON_FIXTURE_COUNT:
		var remaining: Array = []
		for index in eligible_indices:
			if not selected_indices.has(index):
				remaining.append(index)
		if remaining.is_empty():
			break
		var selected_index := _lowest_neon_rank(remaining)
		if selected_index < 0:
			break
		selected_indices.append(selected_index)

	if selected_indices.size() > NEON_FIXTURE_COUNT:
		selected_indices.resize(NEON_FIXTURE_COUNT)
	var selected: Array[Dictionary] = []
	for index in selected_indices:
		selected.append({"index": index, "building": buildings[index]})
	return selected

func _lowest_neon_rank(indices: Array) -> int:
	var selected_index := -1
	var selected_rank := 2147483647
	for value in indices:
		var index := int(value)
		var rank := _neon_rank(index)
		if selected_index < 0 or rank < selected_rank or (rank == selected_rank and index < selected_index):
			selected_index = index
			selected_rank = rank
	return selected_index

func _neon_rank(building_index: int) -> int:
	var key := "%d:%d" % [int(_layout.get("seed", city_seed)), building_index]
	return int(key.hash()) & 0x7fffffff

func _make_neon_facade(building: Dictionary) -> Dictionary:
	var position: Vector3 = building["position"]
	var width := float(building["width"])
	var depth := float(building["depth"])
	var height := float(building["height"])
	var rotation := float(building["rotation"])
	var yaw_basis := Basis(Vector3.UP, rotation)
	var nearest_x := _nearest_road_center(position.x)
	var nearest_z := _nearest_road_center(position.z)
	var use_x_facade := absf(position.x - nearest_x) < absf(position.z - nearest_z)
	var local_normal: Vector3
	var facade_span: float
	var normal_extent: float
	var sign_rotation := 0.0
	if use_x_facade:
		local_normal = Vector3(-1.0 if nearest_x < position.x else 1.0, 0.0, 0.0)
		facade_span = depth
		normal_extent = width * 0.5
		sign_rotation = PI * 0.5
	else:
		local_normal = Vector3(0.0, 0.0, -1.0 if nearest_z < position.z else 1.0)
		facade_span = width
		normal_extent = depth * 0.5

	var sign_world_y := clampf(height * 0.66, 2.2, maxf(2.4, height - 0.9))
	var local_y := sign_world_y - position.y
	var sign_local_position := Vector3(0.0, local_y, 0.0) + local_normal * (normal_extent + 0.20)
	var sign_position := position + yaw_basis * sign_local_position
	var sign_width := clampf(facade_span * 0.52, 2.5, maxf(2.5, facade_span - 1.0))
	var sign_height := clampf(height * 0.075, 0.65, 1.25)
	var sign_basis := yaw_basis * Basis(Vector3.UP, sign_rotation)
	var sign_transform := Transform3D(
		sign_basis.scaled(Vector3(sign_width, sign_height, 0.12)),
		sign_position
	)
	var light_position := position + yaw_basis * (Vector3(0.0, local_y, 0.0) + local_normal * (normal_extent + 0.85))
	return {
		"sign_transform": sign_transform,
		"light_position": light_position,
	}

func _nearest_road_center(value: float) -> float:
	var centers: Array = _layout.get("road_centers", [])
	var closest := 0.0
	var closest_distance := INF
	for center in centers:
		var distance := absf(value - float(center))
		if distance < closest_distance:
			closest_distance = distance
			closest = float(center)
	return closest

func _build_parks_and_props() -> void:
	var parks_root := Node3D.new()
	parks_root.name = "Parks"
	add_child(parks_root)
	var park_transforms: Array = []
	var path_transforms: Array = []
	var tree_transforms: Array = []
	var canopy_transforms: Array = []
	var bench_transforms: Array = []
	var planter_transforms: Array = []
	for park in _layout["parks"]:
		var center: Vector2 = park["center"]
		var park_size: Vector2 = park["size"]
		park_transforms.append(Transform3D(
			Basis.IDENTITY.scaled(Vector3(park_size.x, 0.16, park_size.y)),
			Vector3(center.x, 0.08, center.y)
		))
		path_transforms.append(Transform3D(
			Basis.IDENTITY.scaled(Vector3(park_size.x * 0.18, 0.19, park_size.y)),
			Vector3(center.x, 0.18, center.y)
		))
		path_transforms.append(Transform3D(
			Basis.IDENTITY.scaled(Vector3(park_size.x, 0.2, park_size.y * 0.18)),
			Vector3(center.x, 0.19, center.y)
		))
		for local_x in range(-int(park_size.x * 0.35), int(park_size.x * 0.36), 12):
			for local_z in range(-int(park_size.y * 0.35), int(park_size.y * 0.36), 12):
				if abs(local_x) < 5 or abs(local_z) < 5:
					continue
				var tree_position := Vector3(center.x + local_x, 1.9, center.y + local_z)
				tree_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.22, 1.0, 0.22)), tree_position))
				canopy_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.45, 1.6, 1.45)), tree_position + Vector3.UP * 1.9))
			bench_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.8, 0.35, 0.75)), Vector3(center.x + park_size.x * 0.32, 0.58, center.y)))
			planter_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.15, 0.42, 1.15)), Vector3(center.x - park_size.x * 0.32, 0.35, center.y)))

	_add_multimesh(parks_root, "Lawn", CityMeshes.box_mesh(Vector3.ONE, _materials["park"]), park_transforms)
	_add_multimesh(parks_root, "Paths", CityMeshes.box_mesh(Vector3.ONE, _materials["park_path"]), path_transforms)
	_add_multimesh(parks_root, "TreeTrunks", CityMeshes.cylinder_mesh(1.0, 2.0, _materials["trunk"]), tree_transforms)
	_add_multimesh(parks_root, "TreeCanopies", CityMeshes.sphere_mesh(1.0, _materials["leaves"]), canopy_transforms)
	_add_multimesh(parks_root, "Benches", CityMeshes.box_mesh(Vector3.ONE, _materials["bench"]), bench_transforms)
	_add_multimesh(parks_root, "Planters", CityMeshes.box_mesh(Vector3.ONE, _materials["planter"]), planter_transforms)

	var props_root := Node3D.new()
	props_root.name = "StreetFurniture"
	add_child(props_root)
	var lamp_transforms: Array = []
	var lamp_glow_transforms: Array = []
	var centers: Array = _layout["road_centers"]
	var extent: float = float(_layout["city_size"]) * 0.5
	for center in centers:
		for along in range(-int(extent) + 22, int(extent) - 18, 34):
			for side in [-1.0, 1.0]:
				var horizontal_position := Vector3(float(along), 1.8, float(center) + side * (road_width * 0.5 - 1.1))
				var vertical_position := Vector3(float(center) + side * (road_width * 0.5 - 1.1), 1.8, float(along))
				lamp_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.12, 1.8, 0.12)), horizontal_position))
				lamp_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.12, 1.8, 0.12)), vertical_position))
				lamp_glow_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.24, 0.24, 0.24)), horizontal_position + Vector3.UP * 1.8))
				lamp_glow_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.24, 0.24, 0.24)), vertical_position + Vector3.UP * 1.8))
	var lamp_posts := _add_multimesh(props_root, "LampPosts", CityMeshes.cylinder_mesh(1.0, 2.0, _materials["lamp"]), lamp_transforms)
	var lamp_glows := _add_multimesh(props_root, "LampGlows", CityMeshes.sphere_mesh(1.0, _materials["lamp_glow"]), lamp_glow_transforms)
	var lamp_field := LampField.new()
	lamp_field.name = "LampCollision"
	props_root.add_child(lamp_field)
	lamp_field.configure(lamp_transforms, lamp_glow_transforms, lamp_posts, lamp_glows)
	_build_street_lamp_lights(props_root, lamp_field, lamp_glow_transforms)
	set_meta("lamp_count", lamp_transforms.size())
	set_meta("lamp_shape_count", lamp_field.get_collision_shape_count())


func _build_street_lamp_lights(parent: Node3D, lamp_field: LampField, glow_transforms: Array) -> void:
	var light_root := Node3D.new()
	light_root.name = "StreetLampLights"
	parent.add_child(light_root)
	var light_count := mini(STREET_LAMP_LIGHT_COUNT, glow_transforms.size())
	var lamp_indices: Array[int] = []
	if light_count > 0:
		for light_index in range(light_count):
			var lamp_index := 0
			if light_count > 1:
				lamp_index = int(round(float(light_index) * float(glow_transforms.size() - 1) / float(light_count - 1)))
			lamp_indices.append(lamp_index)
			var glow_transform: Transform3D = glow_transforms[lamp_index]
			var light := OmniLight3D.new()
			light.name = "OmniLight%02d" % light_index
			light.transform = Transform3D(glow_transform.basis.orthonormalized(), glow_transform.origin)
			light.light_color = STREET_LAMP_LIGHT_COLOR
			light.light_energy = STREET_LAMP_LIGHT_ENERGY
			light.omni_range = STREET_LAMP_LIGHT_RANGE
			light.shadow_enabled = false
			light.set_meta("light_index", light_index)
			light.set_meta("lamp_index", lamp_index)
			light_root.add_child(light)
			lamp_field.register_glow_light(lamp_index, light)
	light_root.set_meta("light_count", light_count)
	light_root.set_meta("lamp_indices", lamp_indices)
	light_root.set_meta("light_energy", STREET_LAMP_LIGHT_ENERGY)
	light_root.set_meta("light_range", STREET_LAMP_LIGHT_RANGE)
	light_root.set_meta("light_color", STREET_LAMP_LIGHT_COLOR)
	set_meta("street_lamp_light_count", light_count)
	set_meta("street_lamp_light_indices", lamp_indices)

func _build_navigation() -> void:
	var nav_region := get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	if nav_region == null:
		nav_region = NavigationRegion3D.new()
		nav_region.name = "NavigationRegion3D"
		nav_region.navigation_layers = 1
		add_child(nav_region)
	var nav_mesh := NavigationMesh.new()
	var vertices := PackedVector3Array()
	var polygons: Array[PackedInt32Array] = []
	var size: float = _layout["city_size"]
	var extent := size * 0.5
	var centers: Array = _layout["road_centers"]
	for center in centers:
		_append_navigation_quad(vertices, polygons, Vector3(-extent, 0.27, float(center)), Vector3(extent, 0.27, float(center)), road_width - 1.0, true)
		_append_navigation_quad(vertices, polygons, Vector3(float(center), 0.27, -extent), Vector3(float(center), 0.27, extent), road_width - 1.0, false)
	for park in _layout["parks"]:
		var park_center: Vector2 = park["center"]
		var park_size: Vector2 = park["size"]
		_append_navigation_rectangle(vertices, polygons, Vector3(park_center.x, 0.27, park_center.y), park_size)
	nav_mesh.vertices = vertices
	for polygon in polygons:
		nav_mesh.add_polygon(polygon)
	nav_mesh.cell_size = 0.5
	nav_mesh.cell_height = 0.25
	nav_region.navigation_mesh = nav_mesh

func _build_spawns() -> void:
	var spawn_zones := Node3D.new()
	spawn_zones.name = "SpawnZones"
	add_child(spawn_zones)
	var civilian_spawns: Array = _layout["civilian_spawns"]
	for index in range(civilian_spawns.size()):
		_add_spawn_marker(spawn_zones, "Civilian%03d" % index, civilian_spawns[index], &"civilian_spawn")
	var hostile_spawns: Array = _layout["hostile_spawns"]
	for index in range(hostile_spawns.size()):
		_add_spawn_marker(spawn_zones, "Hostile%03d" % index, hostile_spawns[index], &"hostile_spawn")

func _add_spawn_marker(parent: Node3D, marker_name: String, position: Vector3, group_name: StringName) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = position
	marker.add_to_group(group_name)
	parent.add_child(marker)

func _add_multimesh(parent: Node, node_name: String, mesh: Mesh, transforms: Array) -> MultiMeshInstance3D:
	if transforms.is_empty():
		return null
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = CityMeshes.make_multimesh(mesh, transforms)
	parent.add_child(instance)
	return instance

func _append_building_windows(building: Dictionary, output: Array) -> void:
	var position: Vector3 = building["position"]
	var width: float = building["width"]
	var depth: float = building["depth"]
	var height: float = building["height"]
	var rotation: float = building["rotation"]
	var yaw_basis := Basis(Vector3.UP, rotation)
	var floors := clampi(int(height / 3.25) - 1, 1, 8)
	var front_columns := clampi(int(width / 3.1), 2, 8)
	var side_columns := clampi(int(depth / 3.1), 2, 8)
	for floor in range(floors):
		var local_y := 2.4 + floor * 3.25
		for column in range(front_columns):
			var front_x := lerpf(-width * 0.5 + 1.5, width * 0.5 - 1.5, float(column) / float(maxi(1, front_columns - 1)))
			var front_position := Vector3(position.x, 0.0, position.z) + yaw_basis * Vector3(front_x, local_y, -depth * 0.5 - 0.045)
			var back_position := Vector3(position.x, 0.0, position.z) + yaw_basis * Vector3(front_x, local_y, depth * 0.5 + 0.045)
			output.append(Transform3D(yaw_basis.scaled(Vector3(1.1, 0.9, 0.08)), front_position))
			output.append(Transform3D(yaw_basis.scaled(Vector3(1.1, 0.9, 0.08)), back_position))
		for column in range(side_columns):
			var side_z := lerpf(-depth * 0.5 + 1.5, depth * 0.5 - 1.5, float(column) / float(maxi(1, side_columns - 1)))
			var left_position := Vector3(position.x, 0.0, position.z) + yaw_basis * Vector3(-width * 0.5 - 0.045, local_y, side_z)
			var right_position := Vector3(position.x, 0.0, position.z) + yaw_basis * Vector3(width * 0.5 + 0.045, local_y, side_z)
			output.append(Transform3D(yaw_basis.scaled(Vector3(0.08, 0.9, 1.1)), left_position))
			output.append(Transform3D(yaw_basis.scaled(Vector3(0.08, 0.9, 1.1)), right_position))

func _append_box_faces(faces: PackedVector3Array, position: Vector3, size: Vector3, rotation: float) -> void:
	var half := size * 0.5
	var basis := Basis(Vector3.UP, rotation)
	var corners: Array[Vector3] = [
		Vector3(-half.x, -half.y, -half.z),
		Vector3(half.x, -half.y, -half.z),
		Vector3(half.x, -half.y, half.z),
		Vector3(-half.x, -half.y, half.z),
		Vector3(-half.x, half.y, -half.z),
		Vector3(half.x, half.y, -half.z),
		Vector3(half.x, half.y, half.z),
		Vector3(-half.x, half.y, half.z),
	]
	var world_corners: Array[Vector3] = []
	for corner in corners:
		world_corners.append(position + basis * corner)
	var triangles := [
		[0, 2, 1], [0, 3, 2],
		[4, 5, 6], [4, 6, 7],
		[0, 1, 5], [0, 5, 4],
		[1, 2, 6], [1, 6, 5],
		[2, 3, 7], [2, 7, 6],
		[3, 0, 4], [3, 4, 7],
	]
	for triangle in triangles:
		faces.append(world_corners[triangle[0]])
		faces.append(world_corners[triangle[1]])
		faces.append(world_corners[triangle[2]])

func _append_navigation_quad(
		vertices: PackedVector3Array,
		polygons: Array[PackedInt32Array],
		start: Vector3,
		end: Vector3,
		width: float,
		horizontal: bool
	) -> void:
	var base := vertices.size()
	if horizontal:
		vertices.append(Vector3(start.x, start.y, start.z - width * 0.5))
		vertices.append(Vector3(end.x, end.y, end.z - width * 0.5))
		vertices.append(Vector3(end.x, end.y, end.z + width * 0.5))
		vertices.append(Vector3(start.x, start.y, start.z + width * 0.5))
	else:
		vertices.append(Vector3(start.x - width * 0.5, start.y, start.z))
		vertices.append(Vector3(start.x + width * 0.5, start.y, start.z))
		vertices.append(Vector3(end.x + width * 0.5, end.y, end.z))
		vertices.append(Vector3(end.x - width * 0.5, end.y, end.z))
	polygons.append(PackedInt32Array([base, base + 1, base + 2, base + 3]))

func _append_navigation_rectangle(
		vertices: PackedVector3Array,
		polygons: Array[PackedInt32Array],
		center: Vector3,
		size: Vector2
	) -> void:
	var base := vertices.size()
	vertices.append(center + Vector3(-size.x * 0.5, 0.0, -size.y * 0.5))
	vertices.append(center + Vector3(size.x * 0.5, 0.0, -size.y * 0.5))
	vertices.append(center + Vector3(size.x * 0.5, 0.0, size.y * 0.5))
	vertices.append(center + Vector3(-size.x * 0.5, 0.0, size.y * 0.5))
	polygons.append(PackedInt32Array([base, base + 1, base + 2, base + 3]))
