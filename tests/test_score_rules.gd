extends RefCounted

func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var rules := GameRules.new()
	rules.hostile_score = 100
	rules.civilian_penalty = 250
	rules.combo_window_seconds = 6.0
	ScoreManager.configure(rules)
	ScoreManager.reset_run()

	var hostile := ImpactEvent.new("hostile-life-1", "Hostile", null, 12.0, Vector3.ZERO, 1.0)
	_expect(results, "hostile impact awards default score", ScoreManager.process_impact(hostile) == 100)
	_expect(results, "duplicate lifecycle cannot score twice", ScoreManager.process_impact(hostile) == 0)
	var civilian := ImpactEvent.new("civilian-life-1", "Civilian", null, 12.0, Vector3.ZERO, 2.0)
	_expect(results, "civilian impact applies default penalty", ScoreManager.process_impact(civilian) == -250)
	var disabled := ImpactEvent.new("hostile-life-disabled", "Hostile", null, 12.0, Vector3.ZERO, 3.0, true, true)
	_expect(results, "disabled impact is ignored", ScoreManager.process_impact(disabled) == 0)
	_expect(results, "score manager is sole score writer", not _has_external_score_assignment())
	return results

func _has_external_score_assignment() -> bool:
	var score_path := "res://scripts/services/score_manager.gd"
	var directory := DirAccess.open("res://scripts")
	if directory == null:
		return true
	return _scan_for_score_assignment(directory, score_path)

func _scan_for_score_assignment(directory: DirAccess, score_path: String) -> bool:
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry in [".", ".."]:
			entry = directory.get_next()
			continue
		var path := directory.get_current_dir().path_join(entry)
		if directory.current_is_dir():
			var child := DirAccess.open(path)
			if child != null and _scan_for_score_assignment(child, score_path):
				directory.list_dir_end()
				return true
		elif path.ends_with(".gd") and path != score_path:
			var text := FileAccess.get_file_as_string(path)
			if text.contains("_current_score =") or text.contains("current_score ="):
				directory.list_dir_end()
				return true
		entry = directory.get_next()
	directory.list_dir_end()
	return false

func _expect(results: Array[Dictionary], name: String, condition: bool) -> void:
	results.append({"name": name, "passed": condition, "message": "" if condition else "Assertion failed"})
