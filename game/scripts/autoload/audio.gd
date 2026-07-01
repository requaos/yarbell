extends Node
## Procedural audio, autoloaded as "Audio". Synthesises all sound at runtime
## (no binary audio assets): short SFX one-shots and a looping ambient music bed
## — a pulsing drone + bass with light chime variation sequenced over four
## measures (MIDI-style, since Godot can't play .mid directly). Music and SFX
## have their own buses so their volume can be controlled independently.

const MIX := 22050

var _music_bus := 1
var _sfx_bus := 2
var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _sfx: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_build_sfx()
	_build_sfx_pool()
	_build_music()

# --- buses / volume -----------------------------------------------------------

func _setup_buses() -> void:
	_music_bus = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(_music_bus, "Music")
	AudioServer.set_bus_send(_music_bus, "Master")
	_sfx_bus = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(_sfx_bus, "SFX")
	AudioServer.set_bus_send(_sfx_bus, "Master")
	set_music_volume(0.5)
	set_sfx_volume(0.8)

func set_music_volume(v: float) -> void:
	AudioServer.set_bus_mute(_music_bus, v <= 0.001)
	AudioServer.set_bus_volume_db(_music_bus, linear_to_db(clampf(v, 0.001, 1.0)))

func set_sfx_volume(v: float) -> void:
	AudioServer.set_bus_mute(_sfx_bus, v <= 0.001)
	AudioServer.set_bus_volume_db(_sfx_bus, linear_to_db(clampf(v, 0.001, 1.0)))

# --- playback -----------------------------------------------------------------

func play_sfx(sfx_name: String) -> void:
	if not _sfx.has(sfx_name) or _sfx_pool.is_empty():
		return
	var player := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	player.stream = _sfx[sfx_name]
	player.play()

func _build_sfx_pool() -> void:
	for i in 10:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_pool.append(player)

func _build_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.stream = _make_wav(_render_music(), true)
	add_child(_music_player)
	_music_player.play()

# --- SFX synthesis ------------------------------------------------------------

func _build_sfx() -> void:
	_sfx["fire"] = _make_wav(_sfx_fire(), false)
	_sfx["boom"] = _make_wav(_sfx_boom(), false)
	_sfx["death"] = _make_wav(_sfx_death(), false)

func _sfx_fire() -> PackedFloat32Array:
	var n := int(0.09 * MIX)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		phase += TAU * lerpf(1300.0, 520.0, k) / MIX
		buf[i] = sin(phase) * 0.5 * pow(1.0 - k, 2.0)
	return buf

func _sfx_boom() -> PackedFloat32Array:
	var n := int(0.30 * MIX)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		phase += TAU * lerpf(150.0, 50.0, k) / MIX
		var noise := (randf() * 2.0 - 1.0) * (1.0 - k)
		buf[i] = (sin(phase) * 0.6 + noise * 0.5) * pow(1.0 - k, 1.4)
	return buf

func _sfx_death() -> PackedFloat32Array:
	var n := int(0.22 * MIX)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		phase += TAU * lerpf(520.0, 90.0, k) / MIX
		var noise := (randf() * 2.0 - 1.0) * 0.3 * (1.0 - k)
		buf[i] = (sin(phase) * 0.5 + noise) * pow(1.0 - k, 1.6)
	return buf

# --- music synthesis ----------------------------------------------------------

func _render_music() -> PackedFloat32Array:
	var bpm := 80.0
	var beat := 60.0 / bpm
	var beats := 16                     # four 4/4 measures
	var n := int(beat * beats * MIX)
	var buf := PackedFloat32Array()
	buf.resize(n)

	# Ambient pulsing drone (freqs chosen for whole cycles over the loop so it
	# repeats seamlessly).
	_mix_drone(buf, 110.0, 0.06)        # A2
	_mix_drone(buf, 165.0, 0.04)        # ~E3

	# Pulsing bass on every beat.
	for b in beats:
		_mix_note(buf, b * beat, 110.0, beat * 0.9, 0.26, 0.01, 3.0)

	# Light chime variation across the four measures (A-minor pentatonic).
	var scale := [440.0, 523.25, 587.33, 659.25, 783.99]  # A C D E G
	var chimes := [
		[0.5, 3], [2.5, 0],
		[4.0, 4], [6.5, 2],
		[8.5, 1], [10.0, 3], [11.5, 0],
		[12.0, 2], [14.0, 4],
	]
	for c in chimes:
		var t: float = c[0] * beat
		var f: float = scale[c[1]]
		_mix_note(buf, t, f, 1.3, 0.14, 0.005, 2.2)
		_mix_note(buf, t, f * 2.0, 1.0, 0.05, 0.005, 2.5)

	_normalize(buf, 0.75)
	return buf

func _mix_drone(buf: PackedFloat32Array, freq: float, amp: float) -> void:
	var phase := 0.0
	for i in buf.size():
		phase += TAU * freq / MIX
		var lfo := 0.6 + 0.4 * sin(TAU * 0.5 * float(i) / MIX)  # 0.5 Hz pulse
		buf[i] += sin(phase) * amp * lfo

func _mix_note(buf: PackedFloat32Array, start_t: float, freq: float, dur: float, amp: float, attack: float, decay_pow: float) -> void:
	var start := int(start_t * MIX)
	var n := int(dur * MIX)
	var phase := 0.0
	for i in n:
		var idx := start + i
		if idx >= buf.size():
			break
		var k := float(i) / n
		phase += TAU * freq / MIX
		var atk := clampf(float(i) / maxf(1.0, attack * MIX), 0.0, 1.0)
		buf[idx] += sin(phase) * amp * atk * pow(1.0 - k, decay_pow)

func _normalize(buf: PackedFloat32Array, target: float) -> void:
	var peak := 0.0
	for v in buf:
		peak = maxf(peak, absf(v))
	if peak > 0.0001:
		var scale := target / peak
		for i in buf.size():
			buf[i] *= scale

# --- helpers ------------------------------------------------------------------

func _make_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav
