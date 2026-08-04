extends RefCounted

class SpawnFixtureDistrict extends Node3D:
	var _civilian_points: Array[Marker3D] = []
	var _hostile_points: Array[Marker3D] = []

	func get_spawn_points(role: String) -> Array[Marker3D]:
		return _civilian_points if role.to_lower() == "civilian" else _hostile_points

func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	_test_settings_contract(results)
	_test_initial_population_and_budget(results)
	_test_recycling_and_pool_reuse(results)
	return results

func _test_settings_contract(results: Array[Dictionary]) -> void:
	var settings := load("res://resources/default_crowd_settings.tres") as CrowdSettings
	_expect(results, "crowd settings expose an immediate initial batch", settings != null and settings.initial_population_count > 0)
	_expect(results, "crowd settings expose a visible initial quota", settings != null and settings.initial_visible_count > 0)
	_expect(results, "crowd settings expose a bounded spawn budget", settings != null and settings.spawn_budget_per_frame > 0)
	_expect(results, "crowd settings expose bounded spawn attempts", settings != null and settings.spawn_candidate_attempts > 0)
	_expect(results, "crowd settings keep recycling outside the active radius", settings != null and settings.despawn_distance > settings.spawn_distance)

func _test_initial_population_and_budget(results: Array[Dictionary]) -> void:
	var settings := _make_settings()
	settings.initial_population_count = 6
	settings.initial_visible_count = 3
	settings.spawn_budget_per_frame = 1
	var fixture := _create_fixture(settings)
	var manager: Node = fixture["manager"]
	var initial_count := int(manager.get("active_npc_count"))
	_expect(results, "configure spawns NPCs before the first physics frame", initial_count == 6)
	_expect(results, "initial population stays within the cap", initial_count <= settings.active_npc_cap)
	_expect(results, "initial population contains both configured roles", _count_role(manager, "civilian") > 0 and _count_role(manager, "hostile") > 0)
	var spawn_heights_are_grounded := true
	for npc in (manager.get("_active_npcs") as Dictionary).keys():
		if is_instance_valid(npc) and not is_equal_approx((npc as Node3D).global_position.y, 1.2):
			spawn_heights_are_grounded = false
			break
	_expect(results, "initial population keeps the district marker height", spawn_heights_are_grounded)
	var before_budget := int(manager.get("active_npc_count"))
	manager.call("_physics_process", 0.016)
	var after_budget := int(manager.get("active_npc_count"))
	_expect(results, "replenishment is capped per frame", after_budget - before_budget <= settings.spawn_budget_per_frame)
	_expect(results, "visible spawn preference never aborts a spawn", bool(manager.call("_spawn_role", "civilian", true, true)))
	_cleanup_fixture(fixture)

func _test_recycling_and_pool_reuse(results: Array[Dictionary]) -> void:
	var settings := _make_settings()
	settings.initial_population_count = 4
	settings.spawn_budget_per_frame = 0
	var fixture := _create_fixture(settings)
	var manager: Node = fixture["manager"]
	var civilian_pool: NpcPool = manager.get("_civilian_pool")
	var hostile_pool: NpcPool = manager.get("_hostile_pool")
	var allocations_before := int(manager.get("pool_allocations"))
	var player: Node3D = fixture["player"]
	player.global_position = Vector3(1000.0, 1.2, 1000.0)
	manager.call("_physics_process", 0.016)
	_expect(results, "out-of-range NPCs are recycled without a camera", int(manager.get("active_npc_count")) == 0)
	_expect(results, "recycling leaves pooled instances available", civilian_pool.available_count() + hostile_pool.available_count() == allocations_before)
	settings.spawn_budget_per_frame = 2
	player.global_position = Vector3.ZERO
	manager.call("_physics_process", 0.016)
	_expect(results, "recycled NPCs are reused within the next budget", int(manager.get("active_npc_count")) <= settings.spawn_budget_per_frame)
	_expect(results, "recycling does not allocate a second population", int(manager.get("pool_allocations")) == allocations_before)
	_cleanup_fixture(fixture)

func _make_settings() -> CrowdSettings:
	var settings := CrowdSettings.new()
	settings.active_npc_cap = 8
	settings.civilian_target_count = 4
	settings.hostile_target_count = 4
	settings.spawn_distance = 90.0
	settings.initial_spawn_distance = 65.0
	settings.minimum_spawn_distance = 14.0
	settings.minimum_npc_separation = 2.0
	settings.spawn_edge_padding = 8.0
	settings.spawn_candidate_attempts = 6
	settings.despawn_distance = 110.0
	return settings

func _create_fixture(settings: CrowdSettings) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var district := SpawnFixtureDistrict.new()
	for index in range(4):
		var civilian_marker := Marker3D.new()
		civilian_marker.position = [Vector3(0.0, 1.2, -78.0), Vector3(0.0, 1.2, 78.0), Vector3(-78.0, 1.2, 0.0), Vector3(78.0, 1.2, 0.0)][index]
		district.add_child(civilian_marker)
		district._civilian_points.append(civilian_marker)
		var hostile_marker := Marker3D.new()
		hostile_marker.position = [Vector3(-72.0, 1.2, -72.0), Vector3(72.0, 1.2, -72.0), Vector3(-72.0, 1.2, 72.0), Vector3(72.0, 1.2, 72.0)][index]
		district.add_child(hostile_marker)
		district._hostile_points.append(hostile_marker)
	var player := Node3D.new()
	var manager := preload("res://scripts/npc/population_manager.gd").new() as Node3D
	tree.root.add_child(district)
	tree.root.add_child(player)
	tree.root.add_child(manager)
	player.global_position = Vector3.ZERO
	manager.configure(district, player, settings)
	return {"district": district, "player": player, "manager": manager}

func _cleanup_fixture(fixture: Dictionary) -> void:
	var manager: Node = fixture["manager"]
	manager.call("release_all")
	fixture["manager"].queue_free()
	fixture["player"].queue_free()
	fixture["district"].queue_free()

func _count_role(manager: Node, role: String) -> int:
	var count := 0
	var active: Dictionary = manager.get("_active_npcs")
	for value in active.values():
		if value == role:
			count += 1
	return count

func _expect(results: Array[Dictionary], name: String, condition: bool) -> void:
	results.append({"name": name, "passed": condition, "message": "" if condition else "Assertion failed"})
