extends Node

signal group_panicked(group_id: StringName)

var rules: GameRules = GameRules.new()
var _groups: Dictionary = {}
var _next_group_id: int = 1

func _ready() -> void:
	var configured_rules := load("res://resources/default_game_rules.tres") as GameRules
	if configured_rules != null:
		rules = configured_rules

func configure(new_rules: GameRules) -> void:
	if new_rules != null:
		rules = new_rules

func reset_run() -> void:
	_groups.clear()
	_next_group_id = 1

func create_group() -> StringName:
	var group_id := StringName("hostile_group_%d" % _next_group_id)
	_next_group_id += 1
	_groups[group_id] = {
		"members": [],
		"impacts": [],
		"panicked": false
	}
	return group_id

func register_member(group_id: StringName, member: Node) -> void:
	if not _groups.has(group_id) or member == null:
		return
	var members: Array = _groups[group_id]["members"]
	for weak_member in members:
		if weak_member is WeakRef and weak_member.get_ref() == member:
			return
	members.append(weakref(member))
	_groups[group_id]["members"] = members

func unregister_member(group_id: StringName, member: Node) -> void:
	if not _groups.has(group_id):
		return
	var members: Array = _groups[group_id]["members"]
	members = members.filter(func(reference: WeakRef) -> bool:
		return reference.get_ref() != null and reference.get_ref() != member
	)
	_groups[group_id]["members"] = members

func record_impact(group_id: StringName, timestamp: float = -1.0) -> bool:
	if not _groups.has(group_id):
		return false
	var now := timestamp if timestamp >= 0.0 else Time.get_ticks_msec() / 1000.0
	var history: Array = _groups[group_id]["impacts"]
	history = history.filter(func(value: float) -> bool:
		return now - value <= rules.panic_window_seconds
	)
	history.append(now)
	_groups[group_id]["impacts"] = history
	if not bool(_groups[group_id]["panicked"]) and history.size() >= rules.panic_threshold:
		_groups[group_id]["panicked"] = true
		group_panicked.emit(group_id)
		for reference in _groups[group_id]["members"]:
			var member: Node = null
			if reference is WeakRef:
				member = reference.get_ref() as Node
			if member != null and member.has_method("enter_panic"):
				member.enter_panic()
		return true
	return false

func get_recent_impact_count(group_id: StringName, timestamp: float) -> int:
	if not _groups.has(group_id):
		return 0
	var history: Array = _groups[group_id]["impacts"]
	return history.filter(func(value: float) -> bool:
		return timestamp - value <= rules.panic_window_seconds
	).size()

func is_panicked(group_id: StringName) -> bool:
	return _groups.has(group_id) and bool(_groups[group_id]["panicked"])
