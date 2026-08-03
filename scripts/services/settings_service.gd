extends Node

signal violence_preset_changed(preset: int, label: String)

const SETTINGS_PATH := "user://urban_drive_settings.json"
var violence: ViolenceSettings = ViolenceSettings.new()

func _ready() -> void:
	load_settings()

func set_preset(preset: int) -> void:
	violence.apply_preset(preset)
	save_settings()
	violence_preset_changed.emit(int(violence.preset), violence.label())

func cycle_preset() -> void:
	var next := (int(violence.preset) + 1) % 3
	set_preset(next)

func save_settings() -> bool:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"violence_preset": int(violence.preset)}))
	return true

func load_settings() -> void:
	var preset := ViolenceSettings.Preset.FULL
	if FileAccess.file_exists(SETTINGS_PATH):
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				var raw = parsed.get("violence_preset", int(preset))
				if typeof(raw) in [TYPE_INT, TYPE_FLOAT]:
					preset = clampi(int(raw), 0, 2)
	violence.apply_preset(preset)
