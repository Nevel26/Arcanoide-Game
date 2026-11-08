extends Node2D
## NevelskyiArt Arkanoid: game logic, simple custom ball physics and all field drawing.

const Themes := preload("res://scripts/themes.gd")
const HeroineScript := preload("res://scripts/heroine.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const ParticlesScript := preload("res://scripts/particles.gd")

const W := 1280.0
const H := 720.0
const PANEL_W := 360.0
const FIELD_X := PANEL_W
const FIELD_W := W - PANEL_W
const PADDLE_Y := 672.0
const PADDLE_W := 150.0
const PADDLE_H := 22.0
const BALL_R := 11.0
const BRICK_W := 80.0
const BRICK_H := 36.0
const BRICK_TOP := 92.0
const START_LIVES := 3
const MUTE_RECT := Rect2(1226, 12, 44, 40)

const BONUSES := {
	"wide": {"label": "W", "color": Color("#4cd964"), "say": "Широка платформа!"},
	"multi": {"label": "x3", "color": Color("#b57bff"), "say": "Три м'ячі! Ура!"},
	"slow": {"label": "S", "color": Color("#40c4ff"), "say": "Повільніше... так легше!"},
	"life": {"label": "+1", "color": Color("#ff4f8b"), "say": "Додаткове життя!"},
}

const PHRASES := {
	"combo": ["Комбо x{n}!", "Вау, x{n}!", "Так тримати! x{n}", "Ти вогонь! x{n}"],
	"sad": ["Ой ні...", "Нічого, ще спроба!", "Я вірю в тебе!", "Ех... збери себе!"],
	"idle": ["Ти молодець!", "Ще трошки!", "Цілься в кути!", "Мені подобається грати з тобою!", "Супер!"],
	"win": ["Рівень пройдено!", "Перемога!", "Чудово! Далі!"],
}

var themes: Array
var theme: Dictionary
var level_index := 0
var state := "ready"   # ready, play, wait, transition, over, won
var score := 0
var lives := START_LIVES
var combo := 0
var speed := 470.0

var bricks: Array = []
var balls: Array = []
var capsules: Array = []
var floats: Array = []

var paddle_x := FIELD_X + FIELD_W / 2
var paddle_scale := 1.0
var paddle_squash := 1.0
var wide_time := 0.0
var slow_time := 0.0

var bubble_text := ""
var bubble_alpha := 0.0
var bubble_scale := 1.0
var bubble_left := 0.0
var center_text := ""
var big_text := ""
var big_color := Color("#ffd700")

var heroine: Node2D
var sfx: Node
var fx: Node2D
var font: Font
var _sb := StyleBoxFlat.new()
var _time := 0.0
var _run_id := 0
var _level_time := 0.0
var _last_x := 0.0
var _drag_start := 0.0
var _chatter := 10.0


func _ready() -> void:
	randomize()
	font = ThemeDB.fallback_font
	themes = Themes.all()
	sfx = SfxScript.new()
	add_child(sfx)
	heroine = HeroineScript.new()
	heroine.position = Vector2(PANEL_W / 2, 470)
	add_child(heroine)
	fx = ParticlesScript.new()
	fx.z_index = 10
	add_child(fx)
	load_level(0, true)


# ---------------- helpers ----------------
func later(sec: float, fn: Callable) -> void:
	var id := _run_id
	get_tree().create_timer(sec).timeout.connect(func():
		if id == _run_id:
			fn.call())


func say(text: String, sec := 2.2) -> void:
	bubble_text = text
	bubble_alpha = 1.0
	bubble_scale = 0.85
	bubble_left = sec if sec > 0 else INF
	create_tween().tween_property(self, "bubble_scale", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func pick(list: Array) -> String:
	return list[randi() % list.size()]


func float_text(pos: Vector2, text: String, color := Color.WHITE) -> void:
	floats.append({"pos": pos, "text": text, "color": color, "life": 0.7})


func current_speed() -> float:
	return speed * 0.72 if slow_time > 0 else speed


func paddle_width() -> float:
	return PADDLE_W * paddle_scale


func paddle_rect() -> Rect2:
	var w := paddle_width()
	return Rect2(paddle_x - w / 2, PADDLE_Y - PADDLE_H / 2, w, PADDLE_H)


func move_paddle(x: float) -> void:
	var half := paddle_width() / 2
	paddle_x = clampf(x, FIELD_X + half, W - half)


# ---------------- input ----------------
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		var e: InputEvent = make_input_local(event)
		if e is InputEventScreenTouch:
			if e.pressed:
				_last_x = e.position.x
				_drag_start = e.position.x
				if MUTE_RECT.has_point(e.position):
					sfx.muted = not sfx.muted
					_drag_start = INF
			elif absf(e.position.x - _drag_start) < 18:
				_on_tap()
		elif e is InputEventScreenDrag and state not in ["over", "won"]:
			move_paddle(paddle_x + e.relative.x * 1.35)
	elif event.is_action_pressed("ui_accept"):
		_on_tap()


func _on_tap() -> void:
	if state == "ready":
		launch()
	elif state == "over" or state == "won":
		restart()


# ---------------- levels ----------------
func load_level(index: int, first := false) -> void:
	level_index = index
	theme = themes[index]
	speed = 470.0 + index * 35.0
	bricks.clear()
	balls.clear()
	capsules.clear()
	_level_time = 0.0

	var layout: Array = theme.layout
	var cols: int = layout[0].length()
	var start_x := FIELD_X + (FIELD_W - cols * BRICK_W) / 2
	for r in layout.size():
		var row: String = layout[r]
		for c in cols:
			var ch := row[c]
			if ch == ".":
				continue
			var rect := Rect2(start_x + c * BRICK_W + 2, BRICK_TOP + r * BRICK_H - 15, BRICK_W - 4, 30)
			var hp := -1 if ch == "X" else int(ch)
			bricks.append({
				"rect": rect, "hp": hp, "max": hp,
				"color": Color("#8d93a8") if hp < 0 else theme.bricks[hp - 1],
				"delay": (r * cols + c) * 0.012, "flash": 0.0,
			})

	paddle_x = FIELD_X + FIELD_W / 2
	paddle_scale = 1.0
	wide_time = 0.0
	slow_time = 0.0
	combo = 0
	big_text = ""

	if first:
		heroine.set_theme(theme)
		heroine.idle()
		say("Привіт! Тапни, щоб почати!", 0)
	else:
		heroine.change_outfit(theme, func(): say(theme.hello, 2.6))
		fx.burst(Vector2(PANEL_W / 2, 330), 30, [Color("#ffd700"), Color.WHITE, Color("#ff8fd2"), Color("#7bffb5")], "star")
	ready_ball()


func ready_ball() -> void:
	state = "ready"
	balls.append({"pos": Vector2(paddle_x, PADDLE_Y - 24), "vel": Vector2.ZERO, "on_paddle": true})
	center_text = "Тапни — запуск\nВеди пальцем — платформа"


func launch() -> void:
	state = "play"
	center_text = ""
	for b in balls:
		if b.on_paddle:
			b.on_paddle = false
			var a := deg_to_rad(randf_range(-25, 25))
			b.vel = Vector2(sin(a), -cos(a)) * current_speed()
	sfx.play("paddle")
	_chatter = randf_range(9, 15)


func breakable_left() -> int:
	var n := 0
	for br in bricks:
		if br.hp > 0:
			n += 1
	return n


# ---------------- update ----------------
func _process(delta: float) -> void:
	_time += delta
	_level_time += delta

	if Input.is_action_pressed("ui_left"):
		move_paddle(paddle_x - 900 * delta)
	if Input.is_action_pressed("ui_right"):
		move_paddle(paddle_x + 900 * delta)

	_update_timers(delta)
	_update_balls(delta)
	_update_capsules(delta)

	for f in floats:
		f.life -= delta
		f.pos.y -= 70 * delta
	floats = floats.filter(func(f): return f.life > 0)
	for br in bricks:
		br.flash = maxf(br.flash - delta, 0.0)

	if state == "play" and balls.is_empty():
		lose_life()
	queue_redraw()


func _update_timers(delta: float) -> void:
	if bubble_left != INF:
		bubble_left -= delta
		if bubble_left <= 0:
			bubble_alpha = maxf(bubble_alpha - delta / 0.3, 0.0)
	if wide_time > 0:
		wide_time -= delta
		if wide_time <= 0:
			create_tween().tween_method(func(v): paddle_scale = v; move_paddle(paddle_x), paddle_scale, 1.0, 0.2)
	if slow_time > 0:
		slow_time -= delta
	if state == "play":
		_chatter -= delta
		if _chatter <= 0:
			_chatter = randf_range(9, 15)
			if not heroine.busy:
				say(pick(PHRASES.idle), 1.8)


func _update_balls(delta: float) -> void:
	var s := current_speed()
	var steps := 4
	var dt := delta / steps
	for b in balls.duplicate():
		if b.on_paddle:
			b.pos = Vector2(paddle_x, PADDLE_Y - 24)
			continue
		for i in steps:
			b.pos += b.vel * dt
			if b.pos.x < FIELD_X + BALL_R:
				b.pos.x = FIELD_X + BALL_R
				b.vel.x = absf(b.vel.x)
				sfx.play("wall")
			elif b.pos.x > W - BALL_R:
				b.pos.x = W - BALL_R
				b.vel.x = -absf(b.vel.x)
				sfx.play("wall")
			if b.pos.y < BALL_R:
				b.pos.y = BALL_R
				b.vel.y = absf(b.vel.y)
				sfx.play("wall")
			if b.vel.y > 0 and _circle_hits(b.pos, paddle_rect()):
				_on_paddle_hit(b)
			for br in bricks:
				if _resolve_brick(b, br):
					_on_brick_hit(br)
					break
			if state != "play":
				return
		# keep constant speed and avoid near-horizontal endless bouncing
		if absf(b.vel.y) < s * 0.28:
			b.vel.y = (-1.0 if b.vel.y < 0 else 1.0) * s * 0.28
		b.vel = b.vel.normalized() * s
		if b.pos.y > H + 30:
			balls.erase(b)


func _circle_hits(p: Vector2, r: Rect2) -> bool:
	var closest := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return p.distance_squared_to(closest) < BALL_R * BALL_R


func _resolve_brick(b: Dictionary, br: Dictionary) -> bool:
	var r: Rect2 = br.rect
	var closest := Vector2(clampf(b.pos.x, r.position.x, r.end.x), clampf(b.pos.y, r.position.y, r.end.y))
	var d: Vector2 = b.pos - closest
	if d.length_squared() >= BALL_R * BALL_R:
		return false
	if d == Vector2.ZERO:
		b.vel.y = -b.vel.y
		return true
	if absf(d.x) > absf(d.y):
		b.vel.x = signf(d.x) * absf(b.vel.x)
	else:
		b.vel.y = signf(d.y) * absf(b.vel.y)
	b.pos = closest + d.normalized() * BALL_R
	return true


func _on_paddle_hit(b: Dictionary) -> void:
	var diff := clampf((b.pos.x - paddle_x) / (paddle_width() / 2), -1.0, 1.0)
	var a := deg_to_rad(diff * 62.0)
	b.vel = Vector2(sin(a), -cos(a)) * current_speed()
	b.pos.y = PADDLE_Y - PADDLE_H / 2 - BALL_R
	combo = 0
	sfx.play("paddle")
	var t := create_tween()
	t.tween_property(self, "paddle_squash", 0.7, 0.07)
	t.tween_property(self, "paddle_squash", 1.0, 0.07)


func _on_brick_hit(br: Dictionary) -> void:
	br.flash = 0.12
	if br.hp < 0:
		sfx.play("hard")
		return
	if br.hp > 1:
		br.hp -= 1
		br.color = theme.bricks[br.hp - 1]
		sfx.play("hard")
		return

	combo += 1
	var points := 10 + (combo - 1) * 5
	score += points
	sfx.brick(combo)
	var center: Vector2 = br.rect.get_center()
	fx.burst(center, 14, [br.color])
	float_text(center, "+%d" % points)
	bricks.erase(br)

	if randf() < 0.15:
		capsules.append({"pos": center, "type": BONUSES.keys()[randi() % BONUSES.size()]})

	if combo >= 3 and combo % 3 == 0:
		heroine.cheer()
		say(pick(PHRASES.combo).replace("{n}", str(combo)), 1.5)
		fx.burst(Vector2(PANEL_W / 2, 250), 16, [Color("#ffd700"), Color.WHITE, Color("#ff8fd2")], "star")
		sfx.play("combo")

	if breakable_left() == 0:
		level_complete()


func _update_capsules(delta: float) -> void:
	var pr := paddle_rect()
	for c in capsules.duplicate():
		c.pos.y += 190 * delta
		var cr := Rect2(c.pos.x - 27, c.pos.y - 12, 54, 24)
		if cr.intersects(pr):
			capsules.erase(c)
			apply_bonus(c.type)
		elif c.pos.y > H + 30:
			capsules.erase(c)


func apply_bonus(type: String) -> void:
	var info: Dictionary = BONUSES[type]
	sfx.play("bonus")
	heroine.surprised()
	say(info.say, 1.6)
	score += 25
	float_text(Vector2(paddle_x, PADDLE_Y - 40), info.say, info.color)
	match type:
		"wide":
			wide_time = 12.0
			create_tween().tween_method(func(v): paddle_scale = v; move_paddle(paddle_x), paddle_scale, 1.55, 0.2)
		"multi":
			var src = null
			for b in balls:
				if not b.on_paddle:
					src = b
					break
			if src:
				for rot in [-0.45, 0.45]:
					var v: Vector2 = src.vel.rotated(rot)
					v.y = -absf(v.y)
					balls.append({"pos": src.pos, "vel": v, "on_paddle": false})
		"slow":
			slow_time = 10.0
		"life":
			lives = mini(lives + 1, 6)


# ---------------- life / win ----------------
func lose_life() -> void:
	lives -= 1
	combo = 0
	sfx.play("lose")
	_shake(0.25)
	capsules.clear()
	wide_time = 0.0
	slow_time = 0.0
	paddle_scale = 1.0

	if lives <= 0:
		state = "over"
		heroine.sad(true)
		say("Не здавайся! Спробуймо ще раз?", 0)
		sfx.play("game_over")
		big_text = "GAME OVER"
		big_color = Color("#ff4f8b")
		center_text = "Рахунок: %d\nТапни, щоб грати знову" % score
		return
	state = "wait"
	heroine.sad()
	say(pick(PHRASES.sad), 1.8)
	later(0.7, func():
		if state == "wait":
			ready_ball())


func level_complete() -> void:
	state = "transition"
	balls.clear()
	capsules.clear()
	sfx.play("win")
	heroine.victory()
	fx.confetti_on = true
	later(1.8, func(): fx.confetti_on = false)
	score += 100 * (level_index + 1)

	if level_index == themes.size() - 1:
		state = "won"
		say("Ти справжній чемпіон!", 0)
		big_text = "ПЕРЕМОГА!"
		big_color = Color("#ffd700")
		center_text = "Рахунок: %d\nТапни, щоб грати знову" % score
		_victory_stars()
		return
	say(pick(PHRASES.win), 2.4)
	big_text = "РІВЕНЬ %d ✓" % (level_index + 1)
	big_color = Color("#ffd700")
	later(2.6, func(): load_level(level_index + 1))


func _victory_stars() -> void:
	if state != "won":
		return
	fx.burst(Vector2(PANEL_W / 2, 300), 20, [Color("#ffd700"), Color.WHITE, Color("#ff8fd2"), Color("#7bffb5")], "star")
	later(2.5, _victory_stars)


func restart() -> void:
	_run_id += 1
	fx.confetti_on = false
	score = 0
	lives = START_LIVES
	load_level(0, true)
	say("Поїхали ще раз!", 1.8)
	heroine.cheer()


func _shake(sec: float) -> void:
	var t := create_tween()
	for i in int(sec / 0.03):
		t.tween_property(self, "position", Vector2(randf_range(-6, 6), randf_range(-6, 6)), 0.03)
	t.tween_property(self, "position", Vector2.ZERO, 0.03)


# ---------------- drawing ----------------
func _rr(r: Rect2, radius: float, c: Color) -> void:
	_sb.bg_color = c
	_sb.set_corner_radius_all(int(radius))
	_sb.anti_aliasing = true
	draw_style_box(_sb, r)


func _text(pos: Vector2, text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 5) -> void:
	if outline > 0:
		draw_multiline_string_outline(font, pos, text, align, width, size, -1, outline * 2, Color(0, 0, 0, color.a))
	draw_multiline_string(font, pos, text, align, width, size, -1, color)


func _text_centered(center: Vector2, text: String, size: int, color: Color, width: float, outline := 5) -> void:
	var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, size)
	var top := center.y - sz.y / 2 + font.get_ascent(size)
	_text(Vector2(center.x - width / 2, top), text, size, color, HORIZONTAL_ALIGNMENT_CENTER, width, outline)


func _heart(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(-s * 0.25, -s * 0.1), s * 0.3, col)
	draw_circle(c + Vector2(s * 0.25, -s * 0.1), s * 0.3, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.54, 0), c + Vector2(s * 0.54, 0), c + Vector2(0, s * 0.5)]), col)


func _draw() -> void:
	Themes.draw_background(self, theme, PANEL_W, W, H)
	_draw_bricks()
	_draw_paddle()
	for c in capsules:
		var info: Dictionary = BONUSES[c.type]
		_rr(Rect2(c.pos.x - 27, c.pos.y - 12, 54, 24), 12, info.color)
		_rr(Rect2(c.pos.x - 21, c.pos.y - 9, 42, 5), 3, Color(1, 1, 1, 0.5))
		_text_centered(c.pos, info.label, 18, Color.WHITE, 54, 3)
	for b in balls:
		draw_circle(b.pos, BALL_R, theme.ball)
		draw_circle(b.pos + Vector2(2, 2), BALL_R * 0.7, theme.ball.darkened(0.12))
		draw_circle(b.pos + Vector2(-3, -3), 4, Color.WHITE)
	for f in floats:
		var col: Color = f.color
		col.a = clampf(f.life / 0.7, 0, 1)
		_text_centered(f.pos, f.text, 22, col, 300, 4)
	_draw_hud()
	_draw_bubble()


func _draw_bricks() -> void:
	for br in bricks:
		var r: Rect2 = br.rect
		var k := clampf((_level_time - br.delay) / 0.3, 0.0, 1.0)
		if k <= 0.0:
			continue
		var s := 1.0 + 2.7 * pow(k - 1, 3) + 1.7 * pow(k - 1, 2)  # back-out ease
		if br.flash > 0:
			s *= 1.08
		var rr := Rect2(r.get_center() - r.size * s / 2, r.size * s)
		var col: Color = br.color
		_rr(rr, 6, col.darkened(0.3))
		_rr(Rect2(rr.position, Vector2(rr.size.x, rr.size.y - 4 * s)), 6, col.lightened(0.15) if br.flash > 0 else col)
		draw_rect(Rect2(rr.position + Vector2(6, 4) * s, Vector2(rr.size.x - 12 * s, 4 * s)), Color(1, 1, 1, 0.35))
		if br.hp < 0:
			for p in [Vector2(8, 8), Vector2(68, 8), Vector2(8, 20), Vector2(68, 20)]:
				draw_circle(rr.position + p * s, 3 * s, Color("#c9cede"))
		elif br.hp < br.max:
			var o := rr.position
			draw_polyline(PackedVector2Array([o + Vector2(20, 2), o + Vector2(28, 12), o + Vector2(22, 18), o + Vector2(32, 28)]), Color(0, 0, 0, 0.45), 2)
			draw_polyline(PackedVector2Array([o + Vector2(52, 4), o + Vector2(46, 14), o + Vector2(56, 24)]), Color(0, 0, 0, 0.45), 2)


func _draw_paddle() -> void:
	var w := paddle_width()
	var h := 24.0 * paddle_squash
	var r := Rect2(paddle_x - w / 2, PADDLE_Y - h / 2, w, h)
	var col: Color = theme.paddle
	_rr(r, 12 * paddle_squash, col.darkened(0.3))
	_rr(Rect2(r.position, Vector2(w, h - 6 * paddle_squash)), 10 * paddle_squash, col)
	_rr(Rect2(r.position + Vector2(10, 3), Vector2(w - 20, 5)), 3, Color(1, 1, 1, 0.5))


func _draw_hud() -> void:
	_text(Vector2(FIELD_X + 20, 44), "Рахунок %d" % score, 26, Color.WHITE)
	_text(Vector2(FIELD_X, 44), "%d/%d · %s" % [level_index + 1, themes.size(), theme.name], 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, FIELD_W)
	for i in maxi(lives, 0):
		_heart(Vector2(W - 80 - i * 30, 34), 26, Color("#ff4f8b"))
	# sound toggle
	var c := MUTE_RECT.get_center()
	var ic := Color(1, 1, 1, 0.9)
	draw_rect(Rect2(c.x - 14, c.y - 6, 8, 12), ic)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -6), c + Vector2(4, -14), c + Vector2(4, 14), c + Vector2(-6, 6)]), ic)
	if sfx.muted:
		draw_line(c + Vector2(8, -7), c + Vector2(20, 7), ic, 3)
		draw_line(c + Vector2(8, 7), c + Vector2(20, -7), ic, 3)
	else:
		draw_arc(c + Vector2(4, 0), 9, -0.9, 0.9, 8, ic, 3)
		draw_arc(c + Vector2(4, 0), 16, -0.9, 0.9, 10, ic, 3)

	if center_text != "":
		_text_centered(Vector2(FIELD_X + FIELD_W / 2, 440), center_text, 30, Color.WHITE, FIELD_W - 80)
	if big_text != "":
		_text_centered(Vector2(FIELD_X + FIELD_W / 2, 300), big_text, 64, big_color, FIELD_W - 40, 10)


func _draw_bubble() -> void:
	if bubble_alpha <= 0.0 or bubble_text == "":
		return
	var center := Vector2(PANEL_W / 2, 68)
	draw_set_transform(center * (1 - bubble_scale), 0, Vector2.ONE * bubble_scale)
	var a := bubble_alpha
	_rr(Rect2(18, 16, PANEL_W - 36, 104), 22, Color(1, 1, 1, 0.96 * a))
	draw_colored_polygon(PackedVector2Array([Vector2(150, 118), Vector2(200, 118), Vector2(178, 150)]), Color(1, 1, 1, 0.96 * a))
	_text_centered(center, bubble_text, 24, Color(0.16, 0.1, 0.25, a), PANEL_W - 70, 0)
	draw_set_transform(Vector2.ZERO)
