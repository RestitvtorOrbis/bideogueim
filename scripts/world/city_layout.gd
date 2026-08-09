class_name CityLayout
extends RefCounted

## Pure, deterministic data generation for the procedural city.
## Keeping layout generation separate from scene construction makes it cheap to
## validate and guarantees that the same seed produces the same city.

const PERIMETER_CORNER_OVERLAP := 8.0
const PERIMETER_INTERVAL_OVERLAP := 0.25
const PERIMETER_MIN_WIDTH := 14.0
const PERIMETER_MAX_WIDTH := 22.0
const PERIMETER_MIN_DEPTH := 10.0
const PERIMETER_MAX_DEPTH := 16.0
const PERIMETER_HEIGHT_BANDS := [26.0, 33.0, 40.0, 47.0]

static func is_point_inside_building_footprint(
		world_position: Vector3,
		building: Dictionary,
		clearance: float = 0.5
	) -> bool:
	var center: Vector3 = building.get("position", Vector3.ZERO)
	var width := maxf(0.0, float(building.get("width", 0.0)))
	var depth := maxf(0.0, float(building.get("depth", 0.0)))
	var rotation := float(building.get("rotation", 0.0))
	var safe_clearance := maxf(0.0, clearance)
	var horizontal_offset := world_position - center
	horizontal_offset.y = 0.0
	var local_offset := Basis(Vector3.UP, -rotation) * horizontal_offset
	return absf(local_offset.x) <= width * 0.5 + safe_clearance and absf(local_offset.z) <= depth * 0.5 + safe_clearance

static func generate(
		city_seed: int,
		requested_grid_size: int,
		block_size: float,
		road_width: float,
		max_buildings_per_block: int,
		park_frequency: float,
		civilian_count: int,
		hostile_count: int
	) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = city_seed

	var grid_size := maxi(3, requested_grid_size)
	if grid_size % 2 == 0:
		grid_size += 1
	var safe_block_size := maxf(24.0, block_size)
	var safe_road_width := clampf(road_width, 8.0, safe_block_size * 0.45)
	var safe_park_frequency := clampf(park_frequency, 0.0, 0.45)
	var safe_max_buildings := clampi(max_buildings_per_block, 2, 9)
	var pitch := safe_block_size + safe_road_width
	var city_size := grid_size * safe_block_size + (grid_size + 1) * safe_road_width
	var half_extent := city_size * 0.5

	var road_centers: Array[float] = []
	for index in range(grid_size + 1):
		road_centers.append(-half_extent + safe_road_width * 0.5 + float(index) * pitch)

	var buildings: Array[Dictionary] = []
	var parks: Array[Dictionary] = []
	var block_records: Array[Dictionary] = []
	var center_index := grid_size / 2

	for block_x in range(grid_size):
		for block_z in range(grid_size):
			var block_center := Vector2(
				-half_extent + safe_road_width + safe_block_size * 0.5 + float(block_x) * pitch,
				-half_extent + safe_road_width + safe_block_size * 0.5 + float(block_z) * pitch
			)
			var is_central_block := block_x == center_index and block_z == center_index
			var is_park := is_central_block or rng.randf() < safe_park_frequency
			var block_record := {
				"center": block_center,
				"size": safe_block_size,
				"is_park": is_park,
			}
			block_records.append(block_record)

			if is_park:
				var park_margin := 4.5 if is_central_block else 6.0
				parks.append({
					"center": block_center,
					"size": Vector2(safe_block_size - park_margin * 2.0, safe_block_size - park_margin * 2.0),
					"central": is_central_block,
				})
				continue

			var subdivisions := 2 if rng.randf() < 0.72 else 3
			var lot_width := safe_block_size / float(subdivisions)
			for lot_x in range(subdivisions):
				for lot_z in range(subdivisions):
					if buildings.size() >= grid_size * grid_size * safe_max_buildings:
						break
					if rng.randf() < 0.10:
						continue
					var lot_center := Vector2(
						block_center.x - safe_block_size * 0.5 + lot_width * (float(lot_x) + 0.5),
						block_center.y - safe_block_size * 0.5 + lot_width * (float(lot_z) + 0.5)
					)
					var width := clampf(lot_width - rng.randf_range(3.5, 6.5), 8.0, lot_width - 2.0)
					var depth := clampf(lot_width - rng.randf_range(3.5, 6.5), 8.0, lot_width - 2.0)
					var floors := rng.randi_range(2, 10)
					var height := 3.25 * float(floors) + rng.randf_range(0.5, 2.0)
					var style := rng.randi_range(0, 3)
					var rotation := 0.0
					if rng.randf() < 0.18:
						rotation = PI * 0.5
					buildings.append({
						"position": Vector3(lot_center.x, height * 0.5, lot_center.y),
						"width": width,
						"depth": depth,
						"height": height,
						"floors": floors,
						"style": style,
						"rotation": rotation,
					})

	var player_spawn := Vector3(0.0, 1.25, 0.0)
	var vehicle_spawn := player_spawn + Vector3.FORWARD * 3.25
	# Marker generation uses an independent role/seed-derived stream. This keeps
	# the generated building set and its deterministic signature independent from
	# spawn coverage changes.
	var civilian_spawns := _make_spawns(city_seed, road_centers, half_extent, buildings, civilian_count, 0)
	var hostile_spawns := _make_spawns(city_seed, road_centers, half_extent, buildings, hostile_count, 1)
	# Perimeter generation has its own seed-derived stream. It is intentionally
	# generated after all interior and marker data so adding perimeter detail can
	# never consume values from those streams or change their signature.
	var perimeter_modules := make_perimeter(city_seed, half_extent)

	var signature_parts: Array[String] = [
		str(city_seed),
		str(grid_size),
		str(buildings.size()),
		str(parks.size()),
		"%.3f" % float(buildings[0]["height"]) if not buildings.is_empty() else "0.000",
		"%.3f" % float(civilian_spawns[0].x) if not civilian_spawns.is_empty() else "0.000",
	]

	return {
		"seed": city_seed,
		"grid_size": grid_size,
		"block_size": safe_block_size,
		"road_width": safe_road_width,
		"city_size": city_size,
		"half_extent": half_extent,
		"road_centers": road_centers,
		"blocks": block_records,
		"buildings": buildings,
		"parks": parks,
		"player_spawn": player_spawn,
		"vehicle_spawn": vehicle_spawn,
		"civilian_spawns": civilian_spawns,
		"hostile_spawns": hostile_spawns,
		"perimeter_modules": perimeter_modules,
		"signature": ":".join(signature_parts),
	}

static func make_perimeter(city_seed: int, half_extent: float) -> Array[Dictionary]:
	var perimeter_rng := RandomNumberGenerator.new()
	perimeter_rng.seed = _perimeter_seed(city_seed)
	var safe_half_extent := maxf(1.0, half_extent)
	var coverage_start := -safe_half_extent - PERIMETER_CORNER_OVERLAP
	var coverage_end := safe_half_extent + PERIMETER_CORNER_OVERLAP
	var side_names := ["north", "east", "south", "west"]
	var height_bands := [26.0, 33.0, 40.0, 47.0]
	var modules: Array[Dictionary] = []

	for side in range(4):
		var cursor := coverage_start
		var module_index := 0
		while cursor < coverage_end:
			var width := perimeter_rng.randf_range(PERIMETER_MIN_WIDTH, PERIMETER_MAX_WIDTH)
			var remaining := coverage_end - cursor
			if remaining <= width:
				# Keep the final module within the requested range while extending
				# its interval past the target by the standard overlap amount.
				width = clampf(remaining + PERIMETER_INTERVAL_OVERLAP, PERIMETER_MIN_WIDTH, PERIMETER_MAX_WIDTH)
			var interval_start := cursor
			var interval_end := cursor + width
			var depth := perimeter_rng.randf_range(PERIMETER_MIN_DEPTH, PERIMETER_MAX_DEPTH)
			var height_band := posmod(side + module_index, height_bands.size())
			var style := posmod(side * 2 + module_index, 4)
			var height: float = height_bands[height_band]
			var rotation := 0.0
			var position := Vector3.ZERO
			var inward_normal := Vector3.ZERO
			var inner_local_normal := Vector3.ZERO
			match side:
				0: # north, z = +half_extent
					position = Vector3((interval_start + interval_end) * 0.5, height * 0.5, safe_half_extent + depth * 0.5)
					inward_normal = Vector3(0.0, 0.0, -1.0)
					inner_local_normal = Vector3(0.0, 0.0, -1.0)
				1: # east, x = +half_extent
					rotation = PI * 0.5
					position = Vector3(safe_half_extent + depth * 0.5, height * 0.5, (interval_start + interval_end) * 0.5)
					inward_normal = Vector3(-1.0, 0.0, 0.0)
					inner_local_normal = Vector3(0.0, 0.0, -1.0)
				2: # south, z = -half_extent
					position = Vector3((interval_start + interval_end) * 0.5, height * 0.5, -safe_half_extent - depth * 0.5)
					inward_normal = Vector3(0.0, 0.0, 1.0)
					inner_local_normal = Vector3(0.0, 0.0, 1.0)
				3: # west, x = -half_extent
					rotation = PI * 0.5
					position = Vector3(-safe_half_extent - depth * 0.5, height * 0.5, (interval_start + interval_end) * 0.5)
					inward_normal = Vector3(1.0, 0.0, 0.0)
					inner_local_normal = Vector3(0.0, 0.0, 1.0)
			modules.append({
				"side": side,
				"side_name": side_names[side],
				"position": position,
				"width": width,
				"depth": depth,
				"height": height,
				"height_band": height_band,
				"style": style,
				"rotation": rotation,
				"interval_start": interval_start,
				"interval_end": interval_end,
				"inner_plane": safe_half_extent if side == 0 or side == 1 else -safe_half_extent,
				"inward_normal": inward_normal,
				"inner_local_normal": inner_local_normal,
			})
			cursor += width - PERIMETER_INTERVAL_OVERLAP
			module_index += 1
	return modules

static func _perimeter_seed(city_seed: int) -> int:
	return city_seed * 1664525 + 1013904223

static func _make_spawns(
		city_seed: int,
		road_centers: Array[float],
		half_extent: float,
		buildings: Array[Dictionary],
		count: int,
		role_offset: int
	) -> Array[Vector3]:
	var spawns: Array[Vector3] = []
	var safe_count := maxi(4, count)
	var marker_rng := RandomNumberGenerator.new()
	marker_rng.seed = _marker_seed(city_seed, role_offset)
	for index in range(safe_count):
		var cell_index := posmod(index + role_offset * 7, 16)
		var cell_x := cell_index % 4
		var cell_z := cell_index / 4
		var cell_min_x := -half_extent + float(cell_x) * half_extent * 0.5
		var cell_max_x := cell_min_x + half_extent * 0.5
		var cell_min_z := -half_extent + float(cell_z) * half_extent * 0.5
		var cell_max_z := cell_min_z + half_extent * 0.5
		var margin := minf(6.0, half_extent * 0.1)
		var options := _road_options_for_cell(road_centers, cell_min_x, cell_max_x, cell_min_z, cell_max_z)
		if options.is_empty():
			continue

		var position := Vector3.ZERO
		var found_valid_position := false
		for option_attempt in range(options.size()):
			var option_index := posmod(
				index * 13 + role_offset * 17 + option_attempt + marker_rng.randi(),
				options.size()
			)
			var option: Dictionary = options[option_index]
			var along_min := cell_min_x + margin if bool(option["horizontal"]) else cell_min_z + margin
			var along_max := cell_max_x - margin if bool(option["horizontal"]) else cell_max_z - margin
			var along := marker_rng.randf_range(along_min, along_max)
			var candidate := Vector3(
				along if bool(option["horizontal"]) else float(option["road_center"]),
				1.25,
				float(option["road_center"]) if bool(option["horizontal"]) else along
			)
			if not _is_valid_marker_position(candidate, half_extent, buildings):
				continue
			position = candidate
			found_valid_position = true
			break
		if found_valid_position:
			spawns.append(position)
	return spawns

static func _marker_seed(city_seed: int, role_offset: int) -> int:
	return city_seed * 1103515245 + role_offset * 12345 + 7919

static func _road_options_for_cell(
		road_centers: Array[float],
		cell_min_x: float,
		cell_max_x: float,
		cell_min_z: float,
		cell_max_z: float
	) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for road_center in road_centers:
		var center := float(road_center)
		if center > cell_min_z and center < cell_max_z:
			options.append({"horizontal": true, "road_center": center})
		if center > cell_min_x and center < cell_max_x:
			options.append({"horizontal": false, "road_center": center})
	return options

static func _is_valid_marker_position(
		position: Vector3,
		half_extent: float,
		buildings: Array[Dictionary]
	) -> bool:
	if position.x < -half_extent or position.x > half_extent or position.z < -half_extent or position.z > half_extent:
		return false
	for building in buildings:
		if is_point_inside_building_footprint(position, building, 0.5):
			return false
	return true
