class_name ViolenceSettings
extends Resource

## The active preset controls every impact presentation channel.

enum Preset { FULL, REDUCED, DISABLED }

@export_enum("Full", "Reduced", "Disabled") var preset: int = Preset.FULL
@export var blood_particles_enabled: bool = true
@export var blood_particle_density: float = 1.0
@export var decals_enabled: bool = true
@export var fragments_enabled: bool = true
@export var impact_camera_shake_enabled: bool = true
@export var vocal_impact_audio_enabled: bool = true

func apply_preset(value: int) -> void:
	preset = clampi(int(value), Preset.FULL, Preset.DISABLED)
	match preset:
		Preset.FULL:
			blood_particles_enabled = true
			blood_particle_density = 1.0
			decals_enabled = true
			fragments_enabled = true
			impact_camera_shake_enabled = true
			vocal_impact_audio_enabled = true
		Preset.REDUCED:
			blood_particles_enabled = true
			blood_particle_density = 0.35
			decals_enabled = true
			fragments_enabled = false
			impact_camera_shake_enabled = true
			vocal_impact_audio_enabled = true
		Preset.DISABLED:
			blood_particles_enabled = false
			blood_particle_density = 0.0
			decals_enabled = false
			fragments_enabled = false
			impact_camera_shake_enabled = false
			vocal_impact_audio_enabled = false

func is_disabled() -> bool:
	return preset == Preset.DISABLED

func label() -> String:
	return ["Full", "Reduced", "Disabled"][int(preset)]
