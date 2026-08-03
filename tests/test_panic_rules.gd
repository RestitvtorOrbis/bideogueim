extends RefCounted

func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var rules := GameRules.new()
	rules.panic_threshold = 2
	rules.panic_window_seconds = 6.0
	HostileGroupService.configure(rules)
	HostileGroupService.reset_run()
	var group := HostileGroupService.create_group()
	_expect(results, "one impact does not panic group", not HostileGroupService.record_impact(group, 0.0))
	_expect(results, "second impact inside six seconds panics group", HostileGroupService.record_impact(group, 5.0))
	_expect(results, "recent impact history contains threshold events", HostileGroupService.get_recent_impact_count(group, 5.0) == 2)
	HostileGroupService.reset_run()
	group = HostileGroupService.create_group()
	HostileGroupService.record_impact(group, 0.0)
	_expect(results, "expired impact is removed from history", HostileGroupService.get_recent_impact_count(group, 7.0) == 0)
	_expect(results, "expired history does not trigger panic", not HostileGroupService.record_impact(group, 7.0))
	_expect(results, "new impact can start a fresh history", HostileGroupService.record_impact(group, 8.0))
	return results

func _expect(results: Array[Dictionary], name: String, condition: bool) -> void:
	results.append({"name": name, "passed": condition, "message": "" if condition else "Assertion failed"})
