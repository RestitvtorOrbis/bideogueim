class_name CityLayout
extends RefCounted

## Pure, deterministic data generation for the procedural city.
## Keeping layout generation separate from scene construction makes it cheap to
## validate and guarantees that the same seed produces the same city.

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
	var civilian_spawns := _make_spawns(rng, road_centers, half_extent, civilian_count, 0)
	var hostile_spawns := _make_spawns(rng, road_centers, half_extent, hostile_count, 1)

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
		"signature": ":".join(signature_parts),
	}

static func _make_spawns(
		rng: RandomNumberGenerator,
		road_centers: Array[float],
		half_extent: float,
		count: int,
		role_offset: int
	) -> Array[Vector3]:
	var spawns: Array[Vector3] = []
	var safe_count := maxi(4, count)
	for index in range(safe_count):
		var road_index := posmod(index * 3 + role_offset * 5 + rng.randi_range(0, road_centers.size() - 1), road_centers.size())
		var along := rng.randf_range(-half_extent + 12.0, half_extent - 12.0)
		var position := Vector3.ZERO
		if (index + role_offset) % 2 == 0:
			position = Vector3(along, 1.25, road_centers[road_index])
		else:
			position = Vector3(road_centers[road_index], 1.25, along)
		spawns.append(position)
	return spawns
