extends RefCounted

const MUSIC_PATHS := [
	"res://assets/audio/music/bebop_night_drive.ogg",
	"res://assets/audio/music/bebop_night_drive.wav",
]
const WAV_PATH := "res://assets/audio/music/bebop_night_drive.wav"
const EXPECTED_SAMPLE_RATE := 44100
const EXPECTED_CHANNELS := 2
const EXPECTED_BITS_PER_SAMPLE := 16
const MIN_DURATION_SECONDS := 30.0
const MAX_DURATION_SECONDS := 60.0
const MAX_PEAK := 0.98
const MAX_LOOP_BOUNDARY_JUMP := 0.02


func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var music_path := _find_music_path()
	results.append(_result("music asset exists", not music_path.is_empty()))
	if music_path.is_empty():
		return results
	var wav_info := _read_wav_info(WAV_PATH)
	results.append(_result("lossless WAV master exists", not wav_info.is_empty()))
	if wav_info.is_empty():
		return results
	var file_size := FileAccess.get_file_as_bytes(music_path).size()
	results.append(_result("music asset is non-placeholder", file_size > 100000))
	var stream := load(music_path) as AudioStream
	var controller_source := FileAccess.get_file_as_string("res://scripts/audio/background_music_controller.gd")
	results.append(_result("music asset loads as AudioStream", stream != null))
	if stream != null:
		results.append(_result("music duration is background length", stream.get_length() >= MIN_DURATION_SECONDS and stream.get_length() <= MAX_DURATION_SECONDS))
		results.append(_result("music loop is configured", _stream_loops(stream) or controller_source.contains("LOOP_FORWARD") or controller_source.contains(".loop = true")))
	results.append(_result("WAV is RIFF PCM stereo 16-bit", wav_info.format_ok))
	results.append(_result("WAV sample rate is 44.1 kHz", wav_info.sample_rate == EXPECTED_SAMPLE_RATE))
	results.append(_result("WAV duration is reasonable", wav_info.duration >= MIN_DURATION_SECONDS and wav_info.duration <= MAX_DURATION_SECONDS))
	results.append(_result("WAV contains audible program material", wav_info.rms > 0.02 and wav_info.rms < 0.4))
	results.append(_result("WAV has headroom and no clipping", wav_info.peak < MAX_PEAK))
	results.append(_result("WAV loop boundary is click-safe", wav_info.boundary_jump < MAX_LOOP_BOUNDARY_JUMP))
	results.append(_result("dedicated player has moderate volume", controller_source.contains("volume_db := -12.0")))
	results.append(_result("controller configures AudioStreamPlayer loop", controller_source.contains("AudioStreamPlayer") and controller_source.contains("LOOP_FORWARD") and controller_source.contains(".loop = true")))
	var generator_source := FileAccess.get_file_as_string("res://tools/generate_bebop.py")
	results.append(_result("music is generated from deterministic original source", generator_source.contains("SEED = 26431") and generator_source.contains("random.Random") and generator_source.contains("wave")))
	results.append(_result("arrangement contains bebop rhythm-section layers", generator_source.contains("Walking bass") and generator_source.contains("swing ride") and generator_source.contains("piano voicings") and generator_source.contains("sax-like line")))
	var main_source := FileAccess.get_file_as_string("res://scenes/Main.tscn")
	results.append(_result("Main instantiates background music controller", main_source.contains("scripts/audio/background_music_controller.gd") and main_source.contains("BackgroundMusic")))
	return results


func _find_music_path() -> String:
	for path in MUSIC_PATHS:
		if FileAccess.file_exists(path) or ResourceLoader.exists(path):
			return path
	return ""


func _stream_loops(stream: AudioStream) -> bool:
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD
	return false


func _read_wav_info(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 44:
		return {}
	if file.get_buffer(4).get_string_from_ascii() != "RIFF":
		return {}
	file.get_32()
	if file.get_buffer(4).get_string_from_ascii() != "WAVE":
		return {}
	var audio_format := 0
	var channels := 0
	var sample_rate := 0
	var bits_per_sample := 0
	var block_align := 0
	var data_offset := -1
	var data_size := 0
	while file.get_position() + 8 <= file.get_length():
		var chunk_id := file.get_buffer(4).get_string_from_ascii()
		var chunk_size := file.get_32()
		var chunk_start := file.get_position()
		if chunk_id == "fmt " and chunk_size >= 16:
			audio_format = file.get_16()
			channels = file.get_16()
			sample_rate = file.get_32()
			file.get_32()
			block_align = file.get_16()
			bits_per_sample = file.get_16()
		elif chunk_id == "data":
			data_offset = chunk_start
			data_size = mini(chunk_size, file.get_length() - chunk_start)
			break
		file.seek(min(file.get_length(), chunk_start + chunk_size + (chunk_size & 1)))
	if data_offset < 0 or block_align <= 0 or data_size <= 0:
		return {}
	var frame_count: int = data_size / block_align
	var bytes := FileAccess.get_file_as_bytes(path)
	var peak_sample := 0
	var energy := 0.0
	var boundary_sample := 0
	var first_sample := 0
	var last_sample := 0
	for frame in range(frame_count):
		var offset := data_offset + frame * block_align
		for channel in range(channels):
			var sample_offset := offset + channel * 2
			if sample_offset + 1 >= bytes.size():
				continue
			var sample := int(bytes[sample_offset]) | (int(bytes[sample_offset + 1]) << 8)
			if sample >= 32768:
				sample -= 65536
			peak_sample = maxi(peak_sample, absi(sample))
			var normalized_sample := float(sample) / 32768.0
			energy += normalized_sample * normalized_sample
			if frame == 0 and channel == 0:
				first_sample = sample
			if frame == frame_count - 1 and channel == 0:
				last_sample = sample
	var normalized_peak := float(peak_sample) / 32768.0
	var normalized_boundary_jump := float(absi(first_sample - last_sample)) / 32768.0
	return {
		"format_ok": audio_format == 1 and channels == EXPECTED_CHANNELS and bits_per_sample == EXPECTED_BITS_PER_SAMPLE and block_align == EXPECTED_CHANNELS * EXPECTED_BITS_PER_SAMPLE / 8,
		"sample_rate": sample_rate,
		"duration": float(frame_count) / float(sample_rate) if sample_rate > 0 else 0.0,
		"rms": sqrt(energy / float(frame_count * channels)),
		"peak": normalized_peak,
		"boundary_jump": normalized_boundary_jump,
	}


func _result(name: String, passed: bool) -> Dictionary:
	return {"name": name, "passed": passed}
