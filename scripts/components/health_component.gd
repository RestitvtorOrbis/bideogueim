class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, current: float)
signal died

@export_range(1.0, 10000.0, 1.0) var maximum_health: float = 100.0

var current_health: float:
	get:
		return _current_health

var _current_health: float = 100.0
var _death_emitted: bool = false

func _ready() -> void:
	_current_health = maximum_health
	_death_emitted = false

func configure(new_maximum: float, reset_now: bool = true) -> void:
	maximum_health = maxf(1.0, new_maximum)
	if reset_now:
		reset()

func apply_damage(amount: float) -> void:
	if _death_emitted or amount <= 0.0:
		return
	_current_health = maxf(0.0, _current_health - amount)
	damaged.emit(amount, _current_health)
	health_changed.emit(_current_health, maximum_health)
	if is_zero_approx(_current_health) and not _death_emitted:
		_death_emitted = true
		died.emit()

func heal(amount: float) -> void:
	if _death_emitted or amount <= 0.0:
		return
	_current_health = minf(maximum_health, _current_health + amount)
	health_changed.emit(_current_health, maximum_health)

func reset() -> void:
	_current_health = maximum_health
	_death_emitted = false
	health_changed.emit(_current_health, maximum_health)
