extends Node2D
## The heroine mascot, drawn with code from simple shapes.
## Her outfit changes per level and her face/arms animate per mood.
## To use your own sprites later, keep the public methods:
## set_theme, idle, cheer, surprised, sad, victory, change_outfit.

const SKIN := Color("#ffd9c2")
const SKIN_SHADE := Color("#f0b89a")
const HAIR := Color("#5a2e1a")
const HAIR_LIGHT := Color("#7a4128")
const EYE := Color("#3b7dd8")
const LINE := Color("#2a1a14")
const LIP := Color("#8a1c2b")

var theme: Dictionary = {}
var base_y := 0.0

# animated pose values (tweened)
var arm_l := 0.15
var arm_r := -0.15
var head_rot := 0.0
var bob := 0.0
var squash := 1.0
var spin := 1.0

var eyes := "normal"   # normal, happy, sad, surprised, wink
var mouth := "smile"   # smile, grin, frown, o
var busy := false

var _blinking := false
var _next_blink := 2.0
var _time := 0.0
var _tweens: Array[Tween] = []
var _token := 0
var _sb := StyleBoxFlat.new()


func _ready() -> void:
	base_y = position.y


func set_theme(t: Dictionary) -> void:
	theme = t
	queue_redraw()


# ---------------- poses ----------------
func _stop_pose() -> void:
	for t in _tweens:
		if t.is_valid():
			t.kill()
	_tweens.clear()
	_token += 1


func _tw() -> Tween:
	var t := create_tween()
	_tweens.append(t)
	return t


func _pose(al: float, ar: float, hr: float, dur := 0.25) -> void:
	var t := _tw().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "arm_l", al, dur)
	t.tween_property(self, "arm_r", ar, dur)
	t.tween_property(self, "head_rot", hr, dur)


func _back_to_idle(sec: float) -> void:
	var my := _token
	get_tree().create_timer(sec).timeout.connect(func():
		if my == _token:
			idle())


func idle() -> void:
	_stop_pose()
	busy = false
	eyes = "normal"
	mouth = "smile"
	_pose(0.15, -0.15, 0.0, 0.4)
	var t := _tw().set_parallel(true)
	t.tween_property(self, "bob", 0.0, 0.3)
	t.tween_property(self, "squash", 1.0, 0.3)


func cheer() -> void:
	_stop_pose()
	busy = true
	eyes = "happy"
	mouth = "grin"
	_pose(2.6, -2.6, -0.08, 0.18)
	bob = 0.0
	var t := _tw().set_loops(2)
	t.tween_property(self, "bob", -34.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "bob", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_back_to_idle(1.3)


func surprised() -> void:
	if busy:
		return
	_stop_pose()
	eyes = "surprised"
	mouth = "o"
	_pose(0.9, -0.9, 0.0, 0.15)
	var t := _tw()
	t.tween_property(self, "bob", -16.0, 0.14)
	t.tween_property(self, "bob", 0.0, 0.14)
	_back_to_idle(0.9)


func sad(stay := false) -> void:
	_stop_pose()
	busy = true
	eyes = "sad"
	mouth = "frown"
	_pose(0.02, -0.02, 0.22, 0.4)
	var t := _tw().set_parallel(true)
	t.tween_property(self, "bob", 8.0, 0.4)
	t.tween_property(self, "squash", 0.97, 0.4)
	if not stay:
		_back_to_idle(1.9)


func victory() -> void:
	_stop_pose()
	busy = true
	eyes = "wink"
	mouth = "grin"
	_pose(0.55, -2.5, -0.14, 0.3)
	var wave := _tw().set_loops()
	wave.tween_interval(0.3)
	wave.tween_property(self, "arm_r", -2.9, 0.26).set_trans(Tween.TRANS_SINE)
	wave.tween_property(self, "arm_r", -2.5, 0.26).set_trans(Tween.TRANS_SINE)
	var hop := _tw().set_loops()
	hop.tween_property(self, "bob", -10.0, 0.5).set_trans(Tween.TRANS_SINE)
	hop.tween_property(self, "bob", 0.0, 0.5).set_trans(Tween.TRANS_SINE)


## Spin-change outfit: half turn, redraw with the new theme, turn back.
func change_outfit(t: Dictionary, on_done: Callable = Callable()) -> void:
	_stop_pose()
	busy = true
	var tw := create_tween()
	tw.tween_property(self, "spin", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): set_theme(t))
	tw.tween_property(self, "spin", 1.0, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		idle()
		cheer()
		if on_done.is_valid():
			on_done.call())


func _process(delta: float) -> void:
	_time += delta
	if not busy:
		arm_l = 0.15 + sin(_time / 0.9) * 0.04
		arm_r = -0.15 - sin(_time / 0.9) * 0.04
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blinking = not _blinking
		_next_blink = 0.12 if _blinking else randf_range(1.8, 4.2)
	position.y = base_y + bob
	scale = Vector2(spin, squash)
	queue_redraw()


# ---------------- drawing helpers ----------------
func _rr(x: float, y: float, w: float, h: float, r: float, c: Color) -> void:
	_sb.bg_color = c
	_sb.set_corner_radius_all(int(min(r, min(w, h) * 0.5)))
	_sb.anti_aliasing = true
	draw_style_box(_sb, Rect2(x, y, w, h))


func _ell(cx: float, cy: float, w: float, h: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(Vector2(cx + cos(a) * w * 0.5, cy + sin(a) * h * 0.5))
	draw_colored_polygon(pts, c)


func _poly(arr: Array, c: Color) -> void:
	var pts := PackedVector2Array()
	for p in arr:
		pts.append(Vector2(p[0], p[1]))
	draw_colored_polygon(pts, c)


func _xf(pos: Vector2, rot := 0.0, scl := Vector2.ONE) -> void:
	draw_set_transform(pos, rot, scl)


# ---------------- drawing ----------------
func _draw() -> void:
	if theme.is_empty():
		return
	var k: String = theme.key

	_xf(Vector2.ZERO)
	if k == "fantasy":
		_poly([[-40, -150], [40, -150], [95, 168], [-95, 168]], Color("#b0124a"))
		draw_rect(Rect2(-95, 162, 190, 6), Color("#ffd700"))

	# long hair behind the body (follows the head a little)
	_xf(Vector2(0, -150), head_rot * 0.5)
	var long := 70.0 if k == "space" else 120.0
	_rr(-52, -70, 104, long + 70, 30, HAIR)
	_rr(-40, -40, 10, long + 20, 5, HAIR_LIGHT)

	_xf(Vector2.ZERO)
	_draw_legs(k)
	var breathe := 1.0 if busy else 1.0 + sin(_time / 0.6) * 0.008
	_xf(Vector2.ZERO, 0.0, Vector2(1, breathe))
	_draw_torso(k)

	_xf(Vector2(-36, -145), arm_l)
	_draw_arm(k, -1)
	_xf(Vector2(36, -145), arm_r)
	_draw_arm(k, 1)

	_xf(Vector2(0, -150), head_rot)
	_draw_head()
	_draw_face()
	_draw_hair_front()
	_draw_hat(k)
	_xf(Vector2.ZERO)


func _draw_legs(k: String) -> void:
	_rr(-28, 0, 22, 165, 10, SKIN)
	_rr(6, 0, 22, 165, 10, SKIN)
	match k:
		"beach":
			_rr(-32, 160, 30, 10, 4, Color("#ff7a59"))
			_rr(2, 160, 30, 10, 4, Color("#ff7a59"))
			draw_rect(Rect2(-20, 156, 6, 6), Color.WHITE)
			draw_rect(Rect2(14, 156, 6, 6), Color.WHITE)
		"neon":
			_rr(-31, -4, 27, 160, 8, Color("#1b1b2e"))
			_rr(4, -4, 27, 160, 8, Color("#1b1b2e"))
			draw_rect(Rect2(-31, 10, 4, 140), Color("#00f0ff"))
			draw_rect(Rect2(27, 10, 4, 140), Color("#00f0ff"))
			_rr(-34, 148, 32, 22, 6, Color("#ff2bd6"))
			_rr(2, 148, 32, 22, 6, Color("#ff2bd6"))
		"space":
			_rr(-32, -4, 29, 160, 10, Color("#eef2ff"))
			_rr(3, -4, 29, 160, 10, Color("#eef2ff"))
			draw_rect(Rect2(-32, 60, 29, 8), Color("#ff8a3d"))
			draw_rect(Rect2(3, 60, 29, 8), Color("#ff8a3d"))
			_rr(-36, 140, 36, 30, 8, Color("#8a90a8"))
			_rr(0, 140, 36, 30, 8, Color("#8a90a8"))
		_:
			_rr(-32, 160, 28, 10, 4, Color("#ffd700"))
			_rr(4, 160, 28, 10, 4, Color("#ffd700"))


func _draw_torso(k: String) -> void:
	var body := [[-36, -150], [36, -150], [24, -62], [31, 6], [-31, 6], [-24, -62]]
	_poly(body, SKIN)
	match k:
		"beach":
			# sporty one-piece swimsuit + pareo wrap skirt
			_poly([[-30, -126], [30, -126], [24, -62], [32, 10], [-32, 10], [-24, -62]], Color("#ff7a59"))
			draw_rect(Rect2(-24, -150, 8, 26), Color("#ff7a59"))
			draw_rect(Rect2(16, -150, 8, 26), Color("#ff7a59"))
			for d in [[-14, -100], [10, -90], [-6, -60], [14, -40], [-16, -20]]:
				draw_circle(Vector2(d[0], d[1]), 4, Color(1, 1, 1, 0.9))
			_poly([[-36, -4], [36, -4], [42, 80], [-6, 100], [-40, 70]], Color("#4ecdc4", 0.95))
			draw_circle(Vector2(30, 0), 8, Color("#2a9d94"))
		"neon":
			_poly(body, Color("#1b1b2e"))
			_poly([[-38, -152], [-6, -152], [-6, -40], [-28, -40]], Color("#2a2a48"))
			_poly([[38, -152], [6, -152], [6, -40], [28, -40]], Color("#2a2a48"))
			draw_line(Vector2(-6, -150), Vector2(-6, -40), Color("#00f0ff"), 3)
			draw_line(Vector2(6, -150), Vector2(6, -40), Color("#00f0ff"), 3)
			draw_rect(Rect2(-31, -6, 62, 8), Color("#ff2bd6"))
			draw_rect(Rect2(-4, -8, 8, 12), Color("#faff00"))
		"space":
			_poly(body, Color("#eef2ff"))
			_rr(-20, -120, 40, 40, 6, Color("#c9d1f0"))
			draw_circle(Vector2(-10, -108), 4, Color("#00e676"))
			draw_circle(Vector2(2, -108), 4, Color("#ff5252"))
			draw_rect(Rect2(-12, -96, 24, 6), Color("#40c4ff"))
			draw_rect(Rect2(-30, -40, 60, 8), Color("#ff8a3d"))
			var ring := PackedVector2Array()
			for i in 33:
				var a := TAU * i / 32.0
				ring.append(Vector2(cos(a) * 40, -152 + sin(a) * 11))
			draw_polyline(ring, Color("#c9d1f0"), 10)
		_:
			# royal gown
			_poly([[-32, -132], [32, -132], [24, -62], [70, 162], [-70, 162], [-24, -62]], Color("#7b3fc4"))
			_poly([[-10, -60], [10, -60], [24, 162], [-24, 162]], Color("#9b5fe4"))
			draw_rect(Rect2(-26, -66, 52, 8), Color("#ffd700"))
			draw_rect(Rect2(-72, 156, 144, 8), Color("#ffd700"))
			draw_circle(Vector2(0, -120), 6, Color("#ffd700"))
			draw_rect(Rect2(-32, -136, 64, 6), Color("#ffd700"))


func _draw_arm(k: String, side: int) -> void:
	_rr(-9, 0, 18, 115, 9, SKIN)
	draw_circle(Vector2(0, 118), 11, SKIN)
	match k:
		"beach":
			draw_rect(Rect2(-9, 98, 18, 5), Color("#4ecdc4"))
		"neon":
			_rr(-11, -4, 22, 98, 9, Color("#2a2a48"))
			draw_rect(Rect2(-11, 88, 22, 6), Color("#00f0ff"))
			draw_rect(Rect2(side * 7 - 2, 6, 4, 70), Color("#ff2bd6"))
		"space":
			_rr(-12, -4, 24, 104, 10, Color("#eef2ff"))
			draw_rect(Rect2(-12, 50, 24, 6), Color("#ff8a3d"))
			draw_circle(Vector2(0, 116), 13, Color("#8a90a8"))
		_:
			_ell(0, 14, 34, 40, Color("#9b5fe4"))
			_rr(-10, 20, 20, 80, 8, Color("#7b3fc4"))
			draw_rect(Rect2(-10, 96, 20, 6), Color("#ffd700"))


func _draw_head() -> void:
	draw_circle(Vector2(0, -66), 54, HAIR)
	draw_rect(Rect2(-9, -26, 18, 30), SKIN_SHADE)
	draw_circle(Vector2(-45, -58), 9, SKIN)
	draw_circle(Vector2(45, -58), 9, SKIN)
	draw_circle(Vector2(0, -60), 46, SKIN)
	_ell(0, -34, 70, 40, SKIN)


func _draw_hair_front() -> void:
	_ell(-24, -100, 54, 36, HAIR)
	_ell(12, -104, 64, 34, HAIR)
	_ell(36, -90, 30, 42, HAIR)
	_rr(-54, -92, 16, 76, 8, HAIR)
	_rr(38, -92, 16, 76, 8, HAIR)
	_ell(6, -110, 26, 8, HAIR_LIGHT)


func _draw_hat(k: String) -> void:
	match k:
		"beach":
			_ell(0, -102, 160, 30, Color("#f4d58d"))
			_ell(0, -116, 86, 50, Color("#f4d58d"))
			draw_rect(Rect2(-42, -112, 84, 9), Color("#ff7a59"))
			draw_circle(Vector2(32, -108), 7, Color.WHITE)
		"neon":
			draw_arc(Vector2(0, -64), 58, PI * 1.05, PI * 1.95, 24, Color("#00f0ff"), 7)
			_rr(-62, -78, 18, 36, 6, Color("#ff2bd6"))
			_rr(44, -78, 18, 36, 6, Color("#ff2bd6"))
			draw_circle(Vector2(-53, -60), 5, Color("#00f0ff", 0.6))
			draw_circle(Vector2(53, -60), 5, Color("#00f0ff", 0.6))
		"space":
			_rr(44, -74, 14, 28, 5, Color("#8a90a8"))
			draw_line(Vector2(51, -74), Vector2(60, -120), Color("#8a90a8"), 3)
			draw_circle(Vector2(60, -122), 5, Color("#ff5252"))
			draw_line(Vector2(46, -50), Vector2(20, -28), Color("#8a90a8"), 3)
			draw_circle(Vector2(-30, -104), 6, Color("#40c4ff"))
		_:
			_poly([[-34, -106], [-34, -136], [-18, -118], [0, -144], [18, -118], [34, -136], [34, -106]], Color("#ffd700"))
			draw_circle(Vector2(0, -118), 5, Color("#ff2b6a"))
			draw_circle(Vector2(-22, -114), 4, Color("#2bd6ff"))
			draw_circle(Vector2(22, -114), 4, Color("#2bd6ff"))


func _draw_eye(x: float, type: String) -> void:
	var ey := -58.0
	match type:
		"happy":
			draw_polyline(PackedVector2Array([Vector2(x - 9, ey + 3), Vector2(x, ey - 6), Vector2(x + 9, ey + 3)]), LINE, 4)
		"blink":
			draw_line(Vector2(x - 8, ey + 1), Vector2(x + 8, ey + 1), LINE, 3)
		_:
			_ell(x, ey, 16, 20, Color.WHITE)
			draw_circle(Vector2(x, ey + 1), 6.5, EYE)
			draw_circle(Vector2(x, ey + 1), 3.2, Color("#10131f"))
			draw_circle(Vector2(x + 2.5, ey - 3), 2.2, Color.WHITE)
			draw_line(Vector2(x - 9, ey - 10), Vector2(x + 9, ey - 10), LINE, 3)


func _draw_face() -> void:
	var e := "blink" if _blinking and eyes == "normal" else eyes
	if e == "wink":
		_draw_eye(-17, "normal")
		_draw_eye(17, "happy")
	else:
		_draw_eye(-17, e)
		_draw_eye(17, e)

	# brows
	if e == "sad":
		draw_line(Vector2(-26, -76), Vector2(-10, -80), HAIR, 3)
		draw_line(Vector2(10, -80), Vector2(26, -76), HAIR, 3)
		draw_circle(Vector2(-22, -40), 4, Color("#6ec6ff", 0.9))
		_poly([[-26, -40], [-18, -40], [-22, -48]], Color("#6ec6ff", 0.9))
	elif e == "surprised":
		draw_line(Vector2(-26, -82), Vector2(-10, -84), HAIR, 3)
		draw_line(Vector2(10, -84), Vector2(26, -82), HAIR, 3)
	else:
		draw_line(Vector2(-26, -76), Vector2(-10, -78), HAIR, 3)
		draw_line(Vector2(10, -78), Vector2(26, -76), HAIR, 3)

	_ell(-30, -42, 16, 9, Color("#ff8fa3", 0.45))
	_ell(30, -42, 16, 9, Color("#ff8fa3", 0.45))
	draw_circle(Vector2(0, -45), 2.5, SKIN_SHADE)

	var my := -32.0
	match mouth:
		"grin":
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI * i / 12.0
				pts.append(Vector2(cos(a) * 12, my - 2 + sin(a) * 12))
			draw_colored_polygon(pts, LIP)
			_ell(0, my + 6, 12, 5, Color("#ff7a8a"))
		"frown":
			draw_arc(Vector2(0, my + 10), 9, PI * 1.15, PI * 1.85, 12, LIP, 3)
		"o":
			_ell(0, my + 2, 9, 11, LIP)
		_:
			draw_arc(Vector2(0, my - 4), 9, PI * 0.15, PI * 0.85, 12, LIP, 3)
