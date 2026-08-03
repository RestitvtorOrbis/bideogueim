extends RefCounted

func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var rules := GameRules.new()
	rules.hostile_score = 100
	rules.civilian_penalty = 250
	rules.combo_window_seconds = 6.0
	ScoreManager.configure(rules)
	ScoreManager.reset_run()
	_expect(results, "first hostile impact uses x1", ScoreManager.process_impact(ImpactEvent.new("h1", "Hostile", null, 10.0, Vector3.ZERO, 0.0)) == 100)
	_expect(results, "consecutive hostile impact increases multiplier", ScoreManager.process_impact(ImpactEvent.new("h2", "Hostile", null, 10.0, Vector3.ZERO, 5.0)) == 200)
	_expect(results, "expired combo window resets multiplier", ScoreManager.process_impact(ImpactEvent.new("h3", "Hostile", null, 10.0, Vector3.ZERO, 12.0)) == 100)
	_expect(results, "civilian penalty is never multiplied", ScoreManager.process_impact(ImpactEvent.new("c1", "Civilian", null, 10.0, Vector3.ZERO, 13.0)) == -250)
	_expect(results, "civilian impact resets combo", ScoreManager.combo_multiplier == 1 and ScoreManager.combo_streak == 0)
	return results

func _expect(results: Array[Dictionary], name: String, condition: bool) -> void:
	results.append({"name": name, "passed": condition, "message": "" if condition else "Assertion failed"})
