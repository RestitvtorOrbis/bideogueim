extends Node3D

@onready var district: Node3D = $District
@onready var player: CharacterBody3D = $Player
@onready var vehicle: RigidBody3D = $ArcadeVehicle
@onready var population: Node3D = $PopulationManager
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	var game_rules := load("res://resources/default_game_rules.tres") as GameRules
	if game_rules != null:
		ScoreManager.configure(game_rules)
		HostileGroupService.configure(game_rules)
	GameState.reset_run()
	player.global_position = district.get_player_spawn_position()
	vehicle.global_position = district.get_vehicle_spawn_position()
	vehicle.rotation = Vector3.ZERO
	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
	population.configure(district, player)
	hud.bind_player(player)
	hud.bind_vehicle(vehicle)
	if not GameState.restart_requested.is_connected(_restart_run):
		GameState.restart_requested.connect(_restart_run)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
