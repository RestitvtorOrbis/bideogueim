extends Node3D

const DEFAULT_DURATION_SECONDS := 600.0
const WARMUP_SECONDS := 3.0

var _population
var _elapsed := 0.0
var _frame_count := 0
var _frame_time_total := 0.0
var _frame_times: Array[float] = []
var _memory_samples: Array[int] = []
var _pool_baseline := -1
var _active_count_valid := true
var _report_path := "reports/benchmark.json"
var _duration := DEFAULT_DURATION_SECONDS
var _finished := false

func _ready() -> void:
	_parse_arguments()
	var district := preload("res://scenes/District.tscn").instantiate()
	add_child(district)
	var player: Node3D = preload("res://scenes/Player.tscn").instantiate() as Node3D
	add_child(player)
	player.global_position = district.get_player_spawn_position()
	_population = preload("res://scripts/npc/population_manager.gd").new()
	add_child(_population)
	_population.configure(district, player)

func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	_frame_count += 1
	_frame_time_total += delta
	_frame_times.append(delta)
	if int(_elapsed) != int(_elapsed - delta):
		_memory_samples.append(int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	if _elapsed >= WARMUP_SECONDS and _pool_baseline < 0:
		_pool_baseline = _population.pool_allocations
	if _elapsed >= WARMUP_SECONDS and _population.get_active_npc_count() != 250:
		_active_count_valid = false
	if _elapsed >= _duration:
		_finish()

func _finish() -> void:
	_finished = true
	var average_frame_time := _frame_time_total / float(maxi(1, _frame_count))
	var average_fps := 1.0 / maxf(0.0001, average_frame_time)
	var pool_allocations: int = int(_population.get("pool_allocations"))
	var memory_grew_continuously := _has_continuous_memory_growth()
	var passed: bool = average_fps >= 30.0 and _active_count_valid and not memory_grew_continuously and pool_allocations <= _pool_baseline
	var report := {
		"duration_seconds": _duration,
		"frames": _frame_count,
		"average_fps": average_fps,
		"peak_memory_bytes": _peak_memory(),
		"pool_allocations_after_warmup": pool_allocations,
		"pool_allocations_at_warmup": _pool_baseline,
		"active_npcs_at_finish": _population.get_active_npc_count(),
		"civilian_pool_active_at_finish": _population.get("_civilian_pool").active_count(),
		"hostile_pool_active_at_finish": _population.get("_hostile_pool").active_count(),
		"active_npcs_remained_at_250": _active_count_valid,
		"memory_grew_continuously": memory_grew_continuously,
		"passed": passed
	}
	_write_report(report)
	get_tree().quit(0 if passed else 1)

func _parse_arguments() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--benchmark-seconds" and index + 1 < args.size():
			_duration = maxf(1.0, float(args[index + 1]))
		elif args[index] == "--report" and index + 1 < args.size():
			_report_path = args[index + 1]

func _peak_memory() -> int:
	var peak := 0
	for sample in _memory_samples:
		peak = maxi(peak, sample)
	return peak

func _has_continuous_memory_growth() -> bool:
	if _memory_samples.size() < 8:
		return false
	var run := 0
	for index in range(1, _memory_samples.size()):
		if _memory_samples[index] >= _memory_samples[index - 1]:
			run += 1
			if run >= 8:
				return true
		else:
			run = 0
	return false

func _write_report(report: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(_report_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(_report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
