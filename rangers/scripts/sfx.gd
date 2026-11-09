extends Node
## Tiny synth: all sounds are generated at startup, no audio files needed.

const RATE := 22050
var muted := false
var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	# note = [freq, duration, delay, wave, volume, slide_to]
	_sounds.paddle = _make([[330, 0.08, 0, "square", 0.12, 0]])
	_sounds.wall = _make([[220, 0.05, 0, "triangle", 0.1, 0]])
	_sounds.hard = _make([[160, 0.07, 0, "saw", 0.1, 0]])
	for c in 13:
		_sounds["brick%d" % c] = _make([[520 + c * 45, 0.09, 0, "square", 0.12, 0]])
	_sounds.bonus = _seq([660, 880, 1100], 0.1, 0.07, "triangle", 0.14)
	_sounds.combo = _seq([784, 988, 1175, 1568], 0.09, 0.05, "square", 0.1)
	_sounds.lose = _make([[440, 0.5, 0, "saw", 0.14, 110]])
	_sounds.win = _seq([523, 659, 784, 1047, 784, 1047], 0.16, 0.12, "triangle", 0.16)
	_sounds.game_over = _seq([392, 330, 262, 196], 0.3, 0.22, "triangle", 0.15)
	_sounds.laser = _make([[1500, 0.08, 0, "square", 0.05, 420]])
	_sounds.hit = _make([[180, 0.05, 0, "square", 0.07, 120]])
	_sounds.explode = _make([[120, 0.32, 0, "noise", 0.22, 0]])
	_sounds.shield = _seq([880, 1320], 0.12, 0.08, "triangle", 0.12)


func play(name: String) -> void:
	if muted or not _sounds.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[name]
	p.play()


func brick(combo: int) -> void:
	play("brick%d" % clampi(combo, 0, 12))


func _seq(freqs: Array, dur: float, step: float, wave: String, vol: float) -> AudioStreamWAV:
	var notes := []
	for i in freqs.size():
		notes.append([freqs[i], dur, i * step, wave, vol, 0])
	return _make(notes)


func _make(notes: Array) -> AudioStreamWAV:
	var total := 0.0
	for n in notes:
		total = max(total, n[2] + n[1])
	var count := int((total + 0.03) * RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	for n in notes:
		var f0: float = n[0]
		var dur: float = n[1]
		var start := int(n[2] * RATE)
		var vol: float = n[4]
		var slide: float = n[5]
		var phase := 0.0
		var len := int(dur * RATE)
		for i in len:
			var t := float(i) / len
			var f := f0 * pow(slide / f0, t) if slide > 0 else f0
			phase = fmod(phase + f / RATE, 1.0)
			var s := 0.0
			match n[3]:
				"square": s = 1.0 if phase < 0.5 else -1.0
				"triangle": s = 4.0 * abs(phase - 0.5) - 1.0
				"noise": s = randf() * 2.0 - 1.0
				_: s = 2.0 * phase - 1.0
			var env := vol * pow(0.001 / vol, t)
			var idx := start + i
			if idx < count:
				buf[idx] += s * env
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
