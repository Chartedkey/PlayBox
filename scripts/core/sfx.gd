class_name Sfx
extends Node
## Звуки создаются в коде, поэтому файлы для них не нужны.

const RATE := 22050
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_streams["move"] = tone(520.0, 0.05, 0.25, 0.0)
	_streams["back"] = tone(300.0, 0.08, 0.25, 0.0)
	_streams["open"] = thud(0.22, 0.5)
	_streams["disc"] = tone(170.0, 1.1, 0.14, 520.0)
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(name: String) -> void:
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.play()


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


static func tone(freq: float, length: float, volume: float, sweep: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * (freq + sweep * t) / RATE
		s[i] = sin(phase) * volume * minf(t * 20.0, 1.0) * (1.0 - t)
	return _wav(s)


static func thud(length: float, volume: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var low := 0.0
	for i in n:
		var t := float(i) / n
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.08)
		s[i] = (low * 2.0 + sin(TAU * 90.0 * i / RATE)) * volume * pow(1.0 - t, 3.0)
	return _wav(s)
