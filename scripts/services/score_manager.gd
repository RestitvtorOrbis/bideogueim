extends Node

signal score_changed(delta: int, total: int)
signal combo_changed(multiplier: int, streak: int)

var rules: GameRules = GameRules.new()

var current_score: int:
	get:
		return _current_score

var combo_multiplier: int:
	get:
		return _combo_multiplier

var combo_streak: int:
	get:
		return _combo_streak

var _current_score: int = 0
var _combo_multiplier: int = 1
var _combo_streak: int = 0
var _last_hostile_timestamp: float = -INF
var _processed_lifecycle_ids: Dictionary = {}

func _ready() -> void:
	var configured_rules := load("res://resources/default_game_rules.tres") as GameRules
	if configured_rules != null:
		rules = configured_rules
	if is_instance_valid(ImpactBus) and not ImpactBus.impact_received.is_connected(_on_impact_received):
		ImpactBus.impact_received.connect(_on_impact_received)

func configure(new_rules: GameRules) -> void:
	if new_rules != null:
		rules = new_rules

func reset_run() -> void:
	_current_score = 0
	_combo_multiplier = 1
	_combo_streak = 0
	_last_hostile_timestamp = -INF
	_processed_lifecycle_ids.clear()
	score_changed.emit(0, _current_score)
	combo_changed.emit(_combo_multiplier, _combo_streak)

func process_impact(event: ImpactEvent) -> int:
	if event == null or not event.qualifying or event.is_disabled:
		return 0
	if event.npc_id.is_empty() or _processed_lifecycle_ids.has(event.npc_id):
		return 0
	_processed_lifecycle_ids[event.npc_id] = true

	var timestamp := event.effective_timestamp(Time.get_ticks_msec() / 1000.0)
	var delta := 0
	if event.npc_role.to_lower() == "hostile":
		if timestamp - _last_hostile_timestamp <= rules.combo_window_seconds:
			_combo_multiplier += 1
		else:
			_combo_multiplier = 1
		_combo_streak += 1
		_last_hostile_timestamp = timestamp
		delta = rules.hostile_score * _combo_multiplier
	else:
		_reset_combo()
		if event.npc_role.to_lower() == "civilian":
			delta = -rules.civilian_penalty

	if delta == 0:
		return 0
	_current_score += delta
	score_changed.emit(delta, _current_score)
	combo_changed.emit(_combo_multiplier, _combo_streak)
	if is_instance_valid(GameState):
		GameState._record_score_change(delta, _current_score)
	return delta

func _on_impact_received(event: ImpactEvent) -> void:
	process_impact(event)

func _reset_combo() -> void:
	_combo_multiplier = 1
	_combo_streak = 0
	_last_hostile_timestamp = -INF

func get_processed_lifecycle_count() -> int:
	return _processed_lifecycle_ids.size()
