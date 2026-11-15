extends Node
# shared sound players. slow-mo changes pitch, reverb and the music filter.

const ROOT := "res://audio/sfx100/"

var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


# background music: one track per level, and it slows down with the slow-mo.
var _music: AudioStreamPlayer
var _music_path := ""
var _voice: AudioStreamPlayer
var _reverb := AudioEffectReverb.new()
var _muffle := AudioEffectLowPassFilter.new()


func play_voice(path: String) -> void:
	_voice.stream = load(path)
	_voice.play()


func stop_voice() -> void:
	_voice.stop()


func play_music(path: String) -> void:
	if path == "" or (path == _music_path and _music.playing):
		return
	var stream := load(path) as AudioStreamMP3
	if stream == null:
		return
	stream.loop = true
	_music_path = path
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music_path = ""
	_music.stop()


# glider wind: a stream of low-passed noise made in code, faded in and out.
var _wind: AudioStreamGeneratorPlayback
var _wind_on := false
var _wind_level := 0.0
var _wind_lowpass := 0.0


func set_glide(on: bool) -> void:
	_wind_on = on


func _process(_delta: float) -> void:
	# same time scale as movement, but pitch only drops towards 0.6. full 0.12 pitch would be mush.
	var slow := 1.0 - clampf(Engine.time_scale, 0.0, 1.0)  # 0 = normal speed, ~0.9 = deep slow-mo
	_music.pitch_scale = lerpf(1.0, 0.6, slow)
	_reverb.wet = slow * 0.6
	_muffle.cutoff_hz = lerpf(20000.0, 2200.0, slow)
	if _wind == null or (not _wind_on and _wind_level <= 0.0):
		return  # no wind, so do not spend time making silence (this loop ran 22,000 times a second!)
	for i in range(_wind.get_frames_available()):
		_wind_level = move_toward(_wind_level, 0.5 if _wind_on else 0.0, 0.0001)
		_wind_lowpass = lerpf(_wind_lowpass, randf_range(-1.0, 1.0), 0.15)
		_wind.push_frame(Vector2.ONE * _wind_lowpass * _wind_level)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.volume_db = -9.0
	add_child(_music)
	_voice = AudioStreamPlayer.new()
	add_child(_voice)
	# the music goes through its own bus, so slow-mo can drown it in reverb and muffle it.
	# music bus + effects are created here; no hand-made bus layout needed in the audio dock.
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, "Music")
	_reverb.room_size = 0.85
	_reverb.wet = 0.0
	AudioServer.add_bus_effect(bus, _reverb)
	AudioServer.add_bus_effect(bus, _muffle)
	_music.bus = "Music"
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.15
	var wind_player := AudioStreamPlayer.new()
	wind_player.stream = generator
	wind_player.volume_db = -8.0
	add_child(wind_player)
	wind_player.play()
	_wind = wind_player.get_stream_playback() as AudioStreamGeneratorPlayback
	for i in range(12):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _cache.has(sound):
		_cache[sound] = load(ROOT + sound + ".ogg")
	# round-robin over a few players so sounds can overlap.
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _cache[sound]
	player.volume_db = volume_db
	player.pitch_scale = maxf(pitch * lerpf(0.55, 1.0, clampf(Engine.time_scale, 0.0, 1.0)), 0.05)
	player.play()


func pick(sounds: Array, volume_db := 0.0, pitch := 1.0) -> void:
	play(sounds.pick_random(), volume_db, pitch * randf_range(0.92, 1.08))


func shot(style: int) -> void:
	match style:
		Bullet.Style.ROCKET:
			play("slam_02", 0.0, 0.8)
			play("explosion", -10.0, 1.5)
		Bullet.Style.FART:
			pick(["plop_01", "plop_02", "splash_02"], 3.0, 0.6)
		_:
			pick(["shot_01", "shot_02"], -3.0)


func bounce(kind: Block.Kind, speed: float) -> void:
	var volume := lerpf(-16.0, 0.0, clampf(speed / 1400.0, 0.0, 1.0))
	match kind:
		Block.Kind.METAL:
			pick(["metal_01", "metal_02", "metal_03", "metal_04"], volume)
		Block.Kind.BOUNCY:
			pick(["spring_01", "spring_02", "spring_03"], volume + 3.0)
		Block.Kind.STICKY:
			pick(["splash_01", "plop_01"], volume + 3.0)
		_:
			pick(["hit_01", "hit_02", "hit_03", "wooden_01"], volume)
