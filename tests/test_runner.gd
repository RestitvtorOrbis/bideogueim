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
		preload("res://tests/test_pooling.gd").new()
	]
	var results: Array[Dictionary] = []
	for suite in suites:
		results.append_array(suite.run())
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
	get_tree().quit(0 if failures.is_empty() else 1)

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
