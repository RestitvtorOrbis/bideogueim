extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var results: Array[Dictionary] = preload("res://tests/test_player_movement.gd").new().run()
	var failures := results.filter(func(result: Dictionary) -> bool: return not bool(result.get("passed", false)))
	for result in results:
		print("[%s] %s" % ["PASS" if result.passed else "FAIL", result.name])
	if not failures.is_empty():
		push_error("%d player movement test assertion(s) failed" % failures.size())
	quit(0 if failures.is_empty() else 1)
