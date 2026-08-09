class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, current: float)
signal died

@export_range(1.0, 10000.0, 1.0) var maximum_health: float = 100.0
@export_range(0.0, 1000.0, 0.1) var regeneration_rate: float = 0.0
@export_range(0.0, 600.0, 0.1) var regeneration_delay: float = 60.0

var current_health: float:
	get:
		return _current_health

var _current_health: float = 100.0
var _death_emitted: bool = false
var _time_since_damage: float = 0.0

func _ready() -> void:
	_current_health = maximum_health
	_death_emitted = false
	_time_since_damage = 0.0

func _physics_process(delta: float) -> void:
	if _death_emitted or regeneration_rate <= 0.0 or delta <= 0.0:
		return
	var delay := maxf(0.0, regeneration_delay)
	var previous_time_since_damage := _time_since_damage
	_time_since_damage += delta
	if _time_since_damage < delay:
		return
	var active_regeneration_delta := delta if previous_time_since_damage >= delay else _time_since_damage - delay
	if active_regeneration_delta > 0.0:
		heal(regeneration_rate * active_regeneration_delta)

func configure(new_maximum: float, reset_now: bool = true) -> void:
	maximum_health = maxf(1.0, new_maximum)
	if reset_now:
		reset()

func configure_regeneration(rate: float, delay: float = 60.0) -> void:
	regeneration_rate = maxf(0.0, rate)
	regeneration_delay = maxf(0.0, delay)
	_time_since_damage = 0.0

func apply_damage(amount: float) -> void:
	if _death_emitted or amount <= 0.0:
		return
	_time_since_damage = 0.0
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
	_time_since_damage = 0.0
	health_changed.emit(_current_health, maximum_health)
