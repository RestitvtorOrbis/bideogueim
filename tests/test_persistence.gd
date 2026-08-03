extends RefCounted

func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var had_file := FileAccess.file_exists(GameState.HIGH_SCORE_PATH)
	var original := ""
	if had_file:
		var old_file := FileAccess.open(GameState.HIGH_SCORE_PATH, FileAccess.READ)
		if old_file != null:
			original = old_file.get_as_text()
	var original_high := GameState._high_score
	GameState._high_score = 0
	GameState._record_score_change(100, 100)
	_expect(results, "valid high score saves and loads", GameState.load_high_score() == 100)
	var malformed := FileAccess.open(GameState.HIGH_SCORE_PATH, FileAccess.WRITE)
	if malformed != null:
		malformed.store_string("{not valid json")
	_expect(results, "malformed high score falls back to zero", GameState.load_high_score() == 0)
	if had_file:
		var restore := FileAccess.open(GameState.HIGH_SCORE_PATH, FileAccess.WRITE)
		if restore != null:
			restore.store_string(original)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.HIGH_SCORE_PATH))
	GameState._high_score = original_high
	return results

func _expect(results: Array[Dictionary], name: String, condition: bool) -> void:
	results.append({"name": name, "passed": condition, "message": "" if condition else "Assertion failed"})
