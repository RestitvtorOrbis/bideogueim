extends Control

const POOL_LIMIT := 12
var _labels: Array[Label] = []
var _timers: Array[float] = []
var _velocities: Array[Vector2] = []
var _cursor := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _index in POOL_LIMIT:
		var label := Label.new()
		label.visible = false
		label.add_theme_font_size_override("font_size", 24)
		add_child(label)
		_labels.append(label)
		_timers.append(0.0)
		_velocities.append(Vector2.ZERO)

func _process(delta: float) -> void:
	for index in _labels.size():
		if _timers[index] <= 0.0:
			continue
		_timers[index] -= delta
		_labels[index].position += _velocities[index] * delta
		_labels[index].modulate.a = clampf(_timers[index] * 2.0, 0.0, 1.0)
		if _timers[index] <= 0.0:
			_labels[index].visible = false

func show_delta(delta: int) -> void:
	var index := _cursor
	_cursor = (_cursor + 1) % POOL_LIMIT
	var label := _labels[index]
	label.text = "%+d" % delta
	label.modulate = Color(0.35, 1.0, 0.45, 1.0) if delta > 0 else Color(1.0, 0.28, 0.25, 1.0)
	label.position = Vector2(570.0 + randf_range(-30.0, 30.0), 260.0)
	label.visible = true
	_timers[index] = 1.0
	_velocities[index] = Vector2(randf_range(-12.0, 12.0), -55.0)
