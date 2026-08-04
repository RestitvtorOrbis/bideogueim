extends Node
class_name BackgroundMusicController

## Dedicated background music player. It only owns the Music/Master playback
## node and never changes the SFX players or their buses.
const AUDIO_CANDIDATES := [
	"res://assets/audio/music/bebop_night_drive.ogg",
	"res://assets/audio/music/bebop_night_drive.wav",
]

@export_range(-24.0, 0.0, 0.5) var volume_db := -12.0

var player: AudioStreamPlayer
var active_audio_path := ""


func _ready() -> void:
	_create_player()
	call_deferred("_start_music")


func _create_player() -> void:
	player = AudioStreamPlayer.new()
	player.name = "BebopMusicPlayer"
	player.autoplay = true
	player.volume_db = volume_db
	player.bus = _resolve_bus()
	add_child(player)


func _resolve_bus() -> StringName:
	return &"Music" if AudioServer.get_bus_index(&"Music") >= 0 else &"Master"


func resolve_audio_path() -> String:
	for candidate in AUDIO_CANDIDATES:
		if ResourceLoader.exists(candidate) or FileAccess.file_exists(candidate):
			return candidate
	return ""


func _start_music() -> void:
	if not is_instance_valid(player):
		return
	active_audio_path = resolve_audio_path()
	if active_audio_path.is_empty():
		push_warning("Bebop music asset was not found; continuing without background music")
		return
	var stream := load(active_audio_path) as AudioStream
	if stream == null:
		push_warning("Bebop music asset could not be loaded: %s" % active_audio_path)
		return
	_configure_loop(stream)
	player.stream = stream
	player.play()


func _configure_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if wav.loop_end <= wav.loop_begin:
			wav.loop_begin = 0
			wav.loop_end = int(stream.get_length() * wav.mix_rate)


func is_loop_configured() -> bool:
	if not is_instance_valid(player) or player.stream == null:
		return false
	if player.stream is AudioStreamOggVorbis:
		return (player.stream as AudioStreamOggVorbis).loop
	if player.stream is AudioStreamWAV:
		return (player.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD
	return false


func _exit_tree() -> void:
	if is_instance_valid(player):
		player.stop()
		player.stream = null
