extends CanvasLayer

@onready var score_label: Label = $MarginContainer/Panel/VBox/Score
@onready var high_score_label: Label = $MarginContainer/Panel/VBox/HighScore
@onready var combo_label: Label = $MarginContainer/Panel/VBox/Combo
@onready var player_health_label: Label = $MarginContainer/Panel/VBox/PlayerHealth
@onready var vehicle_health_label: Label = $MarginContainer/Panel/VBox/VehicleHealth
@onready var gore_label: Label = $MarginContainer/Panel/VBox/GorePreset
@onready var popup_pool: Node = $ScorePopupPool

func _ready() -> void:
	ScoreManager.score_changed.connect(_on_score_changed)
	ScoreManager.combo_changed.connect(_on_combo_changed)
	SettingsService.violence_preset_changed.connect(_on_preset_changed)
	_on_score_changed(0, GameState.current_score)
	_on_combo_changed(ScoreManager.combo_multiplier, ScoreManager.combo_streak)
	_on_preset_changed(int(SettingsService.violence.preset), SettingsService.violence.label())

func bind_player(player: Node) -> void:
	if player != null and player.has_node("HealthComponent"):
		var health := player.get_node("HealthComponent") as HealthComponent
		health.health_changed.connect(_on_player_health_changed)
		_on_player_health_changed(health.current_health, health.maximum_health)

func bind_vehicle(vehicle: Node) -> void:
	if vehicle != null and vehicle.has_node("HealthComponent"):
		var health := vehicle.get_node("HealthComponent") as HealthComponent
		health.health_changed.connect(_on_vehicle_health_changed)
		_on_vehicle_health_changed(health.current_health, health.maximum_health)

func _on_score_changed(delta: int, total: int) -> void:
	score_label.text = "Score: %d" % total
	high_score_label.text = "High score: %d" % GameState.high_score
	if delta != 0:
		popup_pool.show_delta(delta)

func _on_combo_changed(multiplier: int, streak: int) -> void:
	combo_label.text = "Combo: x%d (%d hostile impacts)" % [multiplier, streak]

func _on_player_health_changed(current: float, maximum: float) -> void:
	player_health_label.text = "Player health: %d / %d" % [roundi(current), roundi(maximum)]

func _on_vehicle_health_changed(current: float, maximum: float) -> void:
	vehicle_health_label.text = "Vehicle health: %d / %d" % [roundi(current), roundi(maximum)]

func _on_preset_changed(_preset: int, label: String) -> void:
	gore_label.text = "Impact preset: %s" % label
