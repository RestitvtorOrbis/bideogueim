extends RefCounted

class SpawnFixtureDistrict extends Node3D:
	var _civilian_points: Array[Marker3D] = []
	var _hostile_points: Array[Marker3D] = []

	func get_spawn_points(role: String) -> Array[Marker3D]:
		return _civilian_points if role.to_lower() == "civilian" else _hostile_points

class DamageProbe extends Node3D:
	var damage_total: float = 0.0

	func apply_damage(amount: float) -> void:
		damage_total += amount

	func get_damage_target() -> Node:
		return self

func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	_test_settings_contract(results)
	_test_initial_population_and_budget(results)
	_test_role_specific_spawn_distances(results)
	_test_grace_boundaries_and_combat(results)
	_test_safe_radius_behavior(results)
	_test_recycling_and_pool_reuse(results)
	return results

func _test_settings_contract(results: Array[Dictionary]) -> void:
	var settings := load("res://resources/default_crowd_settings.tres") as CrowdSettings
	_expect(results, "crowd settings expose an immediate initial batch", settings != null and settings.initial_population_count > 0)
	_expect(results, "crowd settings expose a visible initial quota", settings != null and settings.initial_visible_count > 0)
	_expect(results, "crowd settings expose a bounded spawn budget", settings != null and settings.spawn_budget_per_frame > 0)
	_expect(results, "crowd settings expose bounded spawn attempts", settings != null and settings.spawn_candidate_attempts > 0)
	_expect(results, "crowd settings keep recycling outside the active radius", settings != null and settings.despawn_distance > settings.spawn_distance)
	_expect(results, "initial civilian spawn floor is 20 meters", settings != null and is_equal_approx(settings.initial_civilian_minimum_spawn_distance, 20.0))
	_expect(results, "initial hostile spawn floor is 35 meters", settings != null and is_equal_approx(settings.initial_hostile_minimum_spawn_distance, 35.0))
	_expect(results, "hostile respawn floor is 30 meters", settings != null and is_equal_approx(settings.hostile_respawn_minimum_spawn_distance, 30.0))
	_expect(results, "hostile safe radius is 30 meters", settings != null and is_equal_approx(settings.hostile_safe_radius, 30.0))
	_expect(results, "hostile grace period is 8 seconds", settings != null and is_equal_approx(settings.hostile_grace_period, 8.0))

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

func _test_role_specific_spawn_distances(results: Array[Dictionary]) -> void:
	var settings := _make_settings()
	settings.initial_population_count = 2
	settings.initial_visible_count = 0
	settings.spawn_budget_per_frame = 1
	settings.civilian_target_count = 1
	settings.hostile_target_count = 1
	var fixture := _create_fixture(settings)
	var manager: Node = fixture["manager"]
	var player: Node3D = fixture["player"]
	var initial_civilian := _find_role_npc(manager, "civilian")
	var initial_hostile := _find_role_npc(manager, "hostile")
	_expect(results, "initial civilians respect their role-specific floor", initial_civilian != null and _horizontal_distance(initial_civilian as Node3D, player) >= 20.0)
	_expect(results, "initial hostiles respect their role-specific floor", initial_hostile != null and _horizontal_distance(initial_hostile as Node3D, player) >= 35.0)

	var allocations_before := int(manager.get("pool_allocations"))
	var hostile_before := initial_hostile
	(initial_hostile as Node3D).global_position = Vector3(1000.0, 1.2, 0.0)
	manager.call("_physics_process", 0.01)
	var hostile_after := _find_role_npc(manager, "hostile")
	_expect(results, "later hostile respawns respect the 30 meter floor", hostile_after != null and _horizontal_distance(hostile_after as Node3D, player) >= 30.0)
	_expect(results, "later hostile respawns reuse the pooled instance", hostile_after == hostile_before)
	_expect(results, "hostile safety reuse does not allocate another NPC", int(manager.get("pool_allocations")) == allocations_before)
	_cleanup_fixture(fixture)

func _test_grace_boundaries_and_combat(results: Array[Dictionary]) -> void:
	var settings := _make_settings()
	settings.initial_population_count = 2
	settings.initial_visible_count = 0
	settings.spawn_budget_per_frame = 0
	settings.civilian_target_count = 1
	settings.hostile_target_count = 1
	var fixture := _create_fixture(settings)
	var manager: Node = fixture["manager"]
	var player := fixture["player"] as DamageProbe
	var hostile := _find_role_npc(manager, "hostile")
	var hostile_node := hostile as Node3D
	hostile_node.global_position = Vector3(1.0, 1.2, 0.0)
	manager.call("set_elapsed_time", 7.99)
	var damage_before := player.damage_total
	hostile.call("tick", 0.01, true)
	_expect(results, "7.99 seconds keeps hostile out of ENGAGE", int(hostile.get("state")) != 2)
	_expect(results, "7.99 seconds prevents hostile damage", is_equal_approx(player.damage_total, damage_before))

	hostile_node.global_position = Vector3(1.0, 1.2, 0.0)
	manager.call("set_elapsed_time", 8.0)
	hostile.call("tick", 0.01, true)
	_expect(results, "8.00 seconds resumes hostile ENGAGE", int(hostile.get("state")) == 2)
	_expect(results, "8.00 seconds permits the configured attack", is_equal_approx(player.damage_total - damage_before, 8.0))
	var profile := load("res://resources/default_hostile_profile.tres") as NpcProfile
	_expect(results, "post-grace engagement range is 18 meters", profile != null and is_equal_approx(profile.engagement_range, 18.0))
	_expect(results, "post-grace attack range is 2.25 meters", profile != null and is_equal_approx(profile.attack_range, 2.25))
	_expect(results, "post-grace attack interval is 1.25 seconds", profile != null and is_equal_approx(profile.attack_interval, 1.25))
	_expect(results, "post-grace attack damage is 8", profile != null and is_equal_approx(profile.attack_damage, 8.0))
	_cleanup_fixture(fixture)

func _test_safe_radius_behavior(results: Array[Dictionary]) -> void:
	var settings := _make_settings()
	settings.initial_population_count = 2
	settings.initial_visible_count = 0
	settings.spawn_budget_per_frame = 0
	settings.civilian_target_count = 1
	settings.hostile_target_count = 1
	var fixture := _create_fixture(settings)
	var manager: Node = fixture["manager"]
	var player: Node3D = fixture["player"]
	var hostile := _find_role_npc(manager, "hostile")
	var hostile_node := hostile as Node3D
	hostile_node.global_position = Vector3(5.0, 1.2, 0.0)
	manager.call("set_elapsed_time", 0.0)
	var wander_target := hostile.get("_wander_target") as Vector3
	_expect(results, "grace-period hostile wander target stays outside safe radius", _horizontal_distance_from(wander_target, player.global_position) >= 30.0)
	var distance_before := _horizontal_distance(hostile_node, player)
	hostile.call("tick", 0.1, true)
	var distance_after := _horizontal_distance(hostile_node, player)
	var updated_target := hostile.get("_wander_target") as Vector3
	_expect(results, "hostiles inside safe radius move outward during grace", distance_after > distance_before)
	_expect(results, "grace movement does not leave a hostile inside safe radius", distance_after >= 30.0)
	_expect(results, "grace movement keeps the active wander target safe", _horizontal_distance_from(updated_target, player.global_position) >= 30.0)
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
	settings.initial_civilian_minimum_spawn_distance = 20.0
	settings.initial_hostile_minimum_spawn_distance = 35.0
	settings.hostile_respawn_minimum_spawn_distance = 30.0
	settings.hostile_safe_radius = 30.0
	settings.hostile_grace_period = 8.0
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
	var player := DamageProbe.new()
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

func _find_role_npc(manager: Node, role: String) -> Node:
	var active: Dictionary = manager.get("_active_npcs")
	for npc in active.keys():
		if active[npc] == role:
			return npc
	return null

func _horizontal_distance(npc: Node3D, player: Node3D) -> float:
	return _horizontal_distance_from(npc.global_position, player.global_position)

func _horizontal_distance_from(position: Vector3, center: Vector3) -> float:
	var offset := position - center
	offset.y = 0.0
	return offset.length()

func _expect(results: Array[Dictionary], name: String, condition: bool) -> void:
	results.append({"name": name, "passed": condition, "message": "" if condition else "Assertion failed"})
