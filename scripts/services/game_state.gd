extends Node

signal score_state_changed(delta: int, total: int)
signal high_score_changed(value: int)
signal game_over_changed(active: bool)
signal restart_requested

const HIGH_SCORE_PATH := "user://urban_drive_high_score.json"

var is_game_over: bool:
	get:
		return _is_game_over

var current_score: int:
	get:
		var score_service := get_node_or_null("/root/ScoreManager")
		return score_service.current_score if score_service != null else 0

var high_score: int:
	get:
		return _high_score

var _is_game_over := false
var _high_score := 0

func _ready() -> void:
	_high_score = load_high_score()

func reset_run() -> void:
	_is_game_over = false
	if is_instance_valid(ScoreManager):
		ScoreManager.reset_run()
	game_over_changed.emit(false)

func finish_run() -> void:
	if _is_game_over:
		return
	_is_game_over = true
	game_over_changed.emit(true)

func request_restart() -> void:
	restart_requested.emit()

func _record_score_change(delta: int, total: int) -> void:
	var old_high := _high_score
	if total > _high_score:
		_high_score = total
		save_high_score()
		if old_high != _high_score:
			high_score_changed.emit(_high_score)
	score_state_changed.emit(delta, total)

func save_high_score() -> bool:
	var file := FileAccess.open(HIGH_SCORE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"high_score": _high_score}))
	return true

func load_high_score() -> int:
	if not FileAccess.file_exists(HIGH_SCORE_PATH):
		return 0
	var file := FileAccess.open(HIGH_SCORE_PATH, FileAccess.READ)
	if file == null:
		return 0
	return parse_high_score(file.get_as_text())

static func parse_high_score(text: String) -> int:
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return 0
	var parsed = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	var value = parsed.get("high_score", 0)
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return 0
	return maxi(0, int(value))
