extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var selector: OptionButton = $Panel/VBox/Preset

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	selector.add_item("Full")
	selector.add_item("Reduced")
	selector.add_item("Disabled")
	selector.select(int(SettingsService.violence.preset))
	selector.item_selected.connect(_on_preset_selected)
	panel.visible = false
	SettingsService.violence_preset_changed.connect(_on_preset_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_gore_preset") and not GameState.is_game_over:
		SettingsService.cycle_preset()
	if event.is_action_pressed("pause") and not GameState.is_game_over:
		panel.visible = not panel.visible
		get_tree().paused = panel.visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if panel.visible else Input.MOUSE_MODE_CAPTURED

func _on_preset_selected(index: int) -> void:
	SettingsService.set_preset(index)

func _on_preset_changed(preset: int, _label: String) -> void:
	if selector.selected != preset:
		selector.select(preset)
