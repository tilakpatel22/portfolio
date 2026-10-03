extends Node
## Adaptive audio: per-level music + synced tension layer, stingers, ambience, pooled SFX.

const SFX := ["click", "select", "link", "dock", "crash", "warning", "horn_big", "horn_small",
	"error", "whoosh", "splash", "star", "seagull"]
const STINGERS := ["win", "lose", "newship", "reward", "start"]
const MUSIC := ["menu", "sea1", "sea2", "sea3", "rush"]
const MUSIC_DB := -7.0

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music := AudioStreamPlayer.new()
var _tension := AudioStreamPlayer.new()
var _stinger := AudioStreamPlayer.new()
var _ambience := AudioStreamPlayer.new()
var _track := ""
var _tension_target := 0.0
var _lowpass := AudioEffectLowPassFilter.new()
var _calm := false
var _muffled := false
var _gull_timer := 10.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	var music_bus := AudioServer.get_bus_index("Music")
	_lowpass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(music_bus, _lowpass)
	for s in SFX + STINGERS + MUSIC + ["tension", "ocean"]:
		var path := "res://assets/audio/%s.ogg" % s
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if stream is AudioStreamOggVorbis and (s in MUSIC or s in ["tension", "ocean"]):
				stream.loop = true
			_streams[s] = stream
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for p: AudioStreamPlayer in [_music, _tension, _stinger]:
		p.bus = "Music"
		add_child(p)
	_ambience.bus = "SFX"
	_ambience.volume_db = -16.0
	_ambience.stream = _streams.get("ocean")
	add_child(_ambience)
	if _ambience.stream:
		_ambience.play()
	_tension.stream = _streams.get("tension")
	_tension.volume_db = -60.0
	GameState.settings_changed.connect(apply_settings)
	apply_settings()


func _process(delta: float) -> void:
	# Tension layer follows danger smoothly; calm/pause muffle the music.
	var target_db := lerpf(-60.0, MUSIC_DB + 1.0, _tension_target)
	_tension.volume_db = move_toward(_tension.volume_db, target_db, delta * (90.0 if _tension_target > 0.0 else 30.0))
	var cutoff := 900.0 if _muffled else (1600.0 if _calm else 20000.0)
	_lowpass.cutoff_hz = lerpf(_lowpass.cutoff_hz, cutoff, 1.0 - exp(-delta * 6.0))
	_gull_timer -= delta
	if _gull_timer <= 0.0:
		_gull_timer = randf_range(9.0, 22.0)
		play("seagull", 0.15, randf_range(0.9, 1.15), -10.0)


func apply_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not GameState.music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not GameState.sfx_on)


func play(sfx: String, pitch_jitter := 0.06, pitch := 1.0, volume_db := 0.0) -> void:
	var stream: AudioStream = _streams.get(sfx)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	p.play()


## Level music rotates every 3 levels between three sea themes; rush levels get their own track.
func track_for_level(level: int, rush: bool) -> String:
	if rush:
		return "rush"
	return ["sea1", "sea2", "sea3"][((level - 1) / 3) % 3]


func play_music(track: String) -> void:
	if track == _track or not _streams.has(track):
		return
	_track = track
	var stream: AudioStream = _streams[track]
	var t := create_tween()
	if _music.playing:
		t.tween_property(_music, "volume_db", -40.0, 0.4)
	t.tween_callback(func() -> void:
		_music.stream = stream
		_music.play()
		# Game tracks share tempo and length, so the tension layer stays in sync.
		if track != "menu" and _tension.stream:
			_tension.play()
		else:
			_tension.stop())
	t.tween_property(_music, "volume_db", MUSIC_DB, 0.6)


func set_tension(amount: float) -> void:
	_tension_target = clampf(amount, 0.0, 1.0)


func set_calm(on: bool) -> void:
	_calm = on


func set_muffled(on: bool) -> void:
	_muffled = on


## One-shot musical cue; the music dips underneath it.
func stinger(name_: String) -> void:
	var stream: AudioStream = _streams.get(name_)
	if stream == null:
		return
	_stinger.stream = stream
	_stinger.volume_db = -2.0
	_stinger.play()
	var t := create_tween()
	t.tween_property(_music, "volume_db", MUSIC_DB - 14.0, 0.15)
	t.tween_interval(maxf(stream.get_length() - 0.6, 0.3))
	t.tween_property(_music, "volume_db", MUSIC_DB, 0.8)


## Silence everything while a full-screen ad is showing.
func duck(on: bool) -> void:
	AudioServer.set_bus_mute(0, on)
