extends RefCounted

func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var pool := NpcPool.new()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(pool)
	pool.configure(preload("res://scenes/Npc.tscn"), "civilian")
	var profile := load("res://resources/default_civilian_profile.tres") as NpcProfile
	var first := pool.checkout(profile, Vector3.ZERO, "civilian_life_1", &"", null)
	pool.release(first)
	_expect(results, "pool return deactivates NPC", not bool(first.get("active")) and bool(first.call("is_inactive")))
	var second: Node = pool.checkout(profile, Vector3.ZERO, "civilian_life_2", &"", null)
	_expect(results, "pool checkout reuses instance", first == second)
	_expect(results, "reused NPC receives new lifecycle id", String(second.get("lifecycle_id")) == "civilian_life_2")
	_expect(results, "reused NPC is score eligible", bool(second.call("is_score_eligible")))
	pool.release(second)
	pool.queue_free()
	return results

func _expect(results: Array[Dictionary], name: String, condition: bool) -> void:
	results.append({"name": name, "passed": condition, "message": "" if condition else "Assertion failed"})
