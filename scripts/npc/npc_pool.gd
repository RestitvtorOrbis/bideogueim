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
	var npc: Node
	if _available.is_empty():
		if npc_scene == null:
			return null
		npc = npc_scene.instantiate()
		add_child(npc)
		_all_instances.append(npc)
		allocation_count += 1
	else:
		npc = _available.pop_back()
	npc.activate(profile, spawn_position, lifecycle_id, group_id, player)
	return npc

func release(npc: Node) -> void:
	if npc == null or npc not in _all_instances or npc in _available:
		return
	if npc.has_method("deactivate"):
		npc.deactivate()
	_available.append(npc)

func release_all() -> void:
	for npc in _all_instances:
		if npc != null and npc.has_method("deactivate"):
			npc.deactivate()
	_available.clear()
	for npc in _all_instances:
		if npc != null:
			_available.append(npc)

func active_count() -> int:
	return _all_instances.size() - _available.size()
