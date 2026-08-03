extends Node

signal shake_requested(intensity: float)

func request_shake(intensity: float) -> void:
	if is_instance_valid(SettingsService) and SettingsService.violence.is_disabled():
		return
	shake_requested.emit(maxf(0.0, intensity))
