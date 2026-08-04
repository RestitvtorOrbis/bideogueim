extends Node

var _report_path := "reports/test-results.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_parse_arguments()
	var suites: Array = [
		preload("res://tests/test_score_rules.gd").new(),
		preload("res://tests/test_combo_rules.gd").new(),
		preload("res://tests/test_panic_rules.gd").new(),
		preload("res://tests/test_persistence.gd").new(),
		preload("res://tests/test_pooling.gd").new(),
		preload("res://tests/test_system_contracts.gd").new(),
		preload("res://tests/test_player_movement.gd").new(),
		preload("res://tests/test_population.gd").new(),
		preload("res://tests/test_music.gd").new(),
		preload("res://tests/test_character_catalog.gd").new(),
		preload("res://tests/test_character_visuals.gd").new()
	]
	var results: Array[Dictionary] = []
	for suite in suites:
		results.append_array(suite.run())
	var physics_suite := preload("res://tests/test_vehicle_physics.gd").new()
	results.append_array(await physics_suite.run())
	results.append_array(await _run_music_runtime())
	var failures := results.filter(func(result: Dictionary) -> bool: return not bool(result.get("passed", false)))
	var report := {
		"passed": failures.is_empty(),
		"total": results.size(),
		"passed_count": results.size() - failures.size(),
		"failed_count": failures.size(),
		"tests": results
	}
	_write_report(report)
	for result in results:
		print("[%s] %s" % ["PASS" if result.passed else "FAIL", result.name])
	if not failures.is_empty():
		push_error("%d test assertion(s) failed" % failures.size())
	var exit_code := 0 if failures.is_empty() else 1
	suites.clear()
	results.clear()
	failures.clear()
	report.clear()
	physics_suite = null
	get_tree().process_frame.connect(_quit_after_frame.bind(exit_code), CONNECT_ONE_SHOT)


func _quit_after_frame(exit_code: int) -> void:
	get_tree().quit(exit_code)


func _run_music_runtime() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var controller := preload("res://scripts/audio/background_music_controller.gd").new()
	add_child(controller)
	await get_tree().process_frame
	var player := controller.get_node_or_null("BebopMusicPlayer") as AudioStreamPlayer
	results.append(_runtime_result("music runtime creates dedicated player", player != null))
	results.append(_runtime_result("music runtime loads a stream", player != null and player.stream != null))
	results.append(_runtime_result("music runtime starts playback", player != null and player.playing))
	results.append(_runtime_result("music runtime enables loop", controller.is_loop_configured()))
	results.append(_runtime_result("music runtime keeps moderate volume", player != null and is_equal_approx(player.volume_db, -12.0)))
	controller.free()
	player = null
	controller = null
	await get_tree().process_frame
	return results


func _runtime_result(name: String, passed: bool) -> Dictionary:
	return {"name": name, "passed": passed}

func _parse_arguments() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--report" and index + 1 < args.size():
			_report_path = args[index + 1]

func _write_report(report: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(_report_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(_report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
