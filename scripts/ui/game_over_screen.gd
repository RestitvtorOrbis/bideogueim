extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var final_score_label: Label = $Panel/VBox/FinalScore
@onready var high_score_label: Label = $Panel/VBox/HighScore
@onready var restart_button: Button = $Panel/VBox/Restart

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	GameState.game_over_changed.connect(_on_game_over_changed)
	GameState.restart_requested.connect(_on_restart_requested)
	restart_button.pressed.connect(_on_restart_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if panel.visible and event.is_action_pressed("ui_accept"):
		_on_restart_pressed()

func _on_game_over_changed(active: bool) -> void:
	panel.visible = active
	if active:
		final_score_label.text = "Final score: %d" % GameState.current_score
		high_score_label.text = "High score: %d" % GameState.high_score
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_restart_pressed() -> void:
	if panel.visible:
		GameState.request_restart()

func _on_restart_requested() -> void:
	get_tree().paused = false
