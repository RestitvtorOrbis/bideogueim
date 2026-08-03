extends Node3D

func _ready() -> void:
	var spawn_zones := get_node_or_null("SpawnZones")
	if spawn_zones == null:
		return
	for marker in spawn_zones.get_children():
		if marker.name.begins_with("Civilian"):
			marker.add_to_group(&"civilian_spawn")
		elif marker.name.begins_with("Hostile"):
			marker.add_to_group(&"hostile_spawn")

func get_player_spawn_position() -> Vector3:
	var marker := get_node_or_null("PlayerSpawn") as Marker3D
	return marker.global_position if marker != null else Vector3(0.0, 1.2, 0.0)

func get_vehicle_spawn_position() -> Vector3:
	var marker := get_node_or_null("VehicleSpawn") as Marker3D
	return marker.global_position if marker != null else Vector3(4.0, 1.0, 0.0)

func get_spawn_points(role: String) -> Array[Marker3D]:
	var group_name := "civilian_spawn" if role.to_lower() == "civilian" else "hostile_spawn"
	var points: Array[Marker3D] = []
	for node in get_tree().get_nodes_in_group(group_name):
		if node is Marker3D and is_ancestor_of(node):
			points.append(node)
	return points
