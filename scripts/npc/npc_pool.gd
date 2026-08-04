class_name NpcPool
extends Node

var npc_scene: PackedScene
var role_name: String = "civilian"
var _available: Array[Node] = []
var _all_instances: Array[Node] = []
var allocation_count: int = 0

func configure(scene: PackedScene, role: String) -> void:
	npc_scene = scene
	role_name = role

func checkout(
		profile: NpcProfile,
		spawn_position: Vector3,
		lifecycle_id: String,
		group_id: StringName,
		player: Node
	) -> Node:
	var npc := _take_available_instance()
	if npc == null:
		if npc_scene == null:
			return null
		npc = npc_scene.instantiate()
		if npc == null or not npc.has_method("activate"):
			if npc != null:
				npc.queue_free()
			return null
		add_child(npc)
		_all_instances.append(npc)
		allocation_count += 1
	if not is_instance_valid(npc) or not npc.has_method("activate"):
		return null
	npc.call("activate", profile, spawn_position, lifecycle_id, group_id, player)
	return npc

func release(npc: Node) -> void:
	if npc == null or not _all_instances.has(npc) or _available.has(npc):
		return
	if is_instance_valid(npc) and npc.has_method("deactivate"):
		npc.call("deactivate")
	_available.append(npc)

func release_all() -> void:
	_available.clear()
	for npc in _all_instances:
		if not is_instance_valid(npc):
			continue
		if npc.has_method("deactivate"):
			npc.call("deactivate")
		_available.append(npc)

func active_count() -> int:
	_prune_invalid_instances()
	return _all_instances.size() - _available.size()

func available_count() -> int:
	_prune_invalid_instances()
	return _available.size()

func total_count() -> int:
	_prune_invalid_instances()
	return _all_instances.size()

func _take_available_instance() -> Node:
	while not _available.is_empty():
		var npc: Node = _available.pop_back()
		if is_instance_valid(npc) and _all_instances.has(npc):
			return npc
	return null

func _prune_invalid_instances() -> void:
	var valid_instances: Array[Node] = []
	for npc in _all_instances:
		if is_instance_valid(npc):
			valid_instances.append(npc)
	_all_instances = valid_instances
	var valid_available: Array[Node] = []
	for npc in _available:
		if is_instance_valid(npc) and _all_instances.has(npc):
			valid_available.append(npc)
	_available = valid_available
