extends Node2D
## NevelskyiArt Space: the ship shoots a green blaster at a descending asteroid formation.
## Asteroids and the ship are lit from the side by the level's star.

const Themes := preload("res://scripts/themes.gd")
const HeroineScript := preload("res://scripts/heroine.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const ParticlesScript := preload("res://scripts/particles.gd")

const W := 1280.0
const H := 720.0
const PANEL_W := 360.0
const FIELD_X := PANEL_W
const FIELD_W := W - PANEL_W
const SHIP_Y := 640.0
const SHIP_R := 30.0
const CELL_W := 80.0
const CELL_H := 58.0
const FORM_TOP := 112.0
const DANGER_Y := SHIP_Y - 50.0
const BOLT_SPEED := 950.0
const START_LIVES := 3
const MUTE_RECT := Rect2(1226, 12, 44, 40)
const STAR_POS := Vector2(FIELD_X + 64, 250)
const GREEN := Color("#39ff6a")

const BONUSES := {
	"triple": {"label": "x3", "color": Color("#39ff6a"), "say": "Потрійний бластер!"},
	"rapid": {"label": "R", "color": Color("#ffd23f"), "say": "Швидкий вогонь!"},
	"shield": {"label": "S", "color": Color("#40c4ff"), "say": "Щит активовано!"},
	"life": {"label": "+1", "color": Color("#ff4f8b"), "say": "Додаткове життя!"},
}

const PHRASES := {
	"streak": ["Серія x{n}!", "Влучно! x{n}", "Ти ас! x{n}", "Так тримати! x{n}"],
	"hit": ["Ой! Тримайся!", "Обережно!", "Корпус пошкоджено!", "Ухиляйся!"],
	"idle": ["Цілься в великі!", "Метеор праворуч!", "Гарний політ!", "Ти найкращий пілот!"],
	"win": ["Сектор чистий!", "Перемога!", "Летимо далі!"],
}

var levels: Array
var lvl: Dictionary
var level_index := 0
var state := "ready"   # ready, play, transition, over, won
var score := 0
var lives := START_LIVES
var streak := 0

var asteroids: Array = []   # formation rocks and free-flying meteors
var bolts: Array = []
var capsules: Array = []
var floats: Array = []
var stars: Array = []

var ship_x := FIELD_X + FIELD_W / 2
var ship_tilt := 0.0
var _ship_prev_x := ship_x
var firing := false
var fire_cd := 0.0
var invuln := 0.0
var shield_time := 0.0
var triple_time := 0.0
var rapid_time := 0.0
var formation_y := 0.0
var meteor_cd := 3.0

var bubble_text := ""
var bubble_alpha := 0.0
var bubble_scale := 1.0
var bubble_left := 0.0
var center_text := ""
var big_text := ""
var big_color := Color("#ffd23f")

var heroine: Node2D
var sfx: Node
var fx: Node2D
var font: Font
var _sb := StyleBoxFlat.new()
var _time := 0.0
var _run_id := 0
var _last_x := 0.0
var _drag_start := 0.0
var _chatter := 10.0


func _ready() -> void:
	randomize()
	font = ThemeDB.fallback_font
	levels = Themes.all()
	sfx = SfxScript.new()
	add_child(sfx)
	heroine = HeroineScript.new()
	heroine.position = Vector2(PANEL_W / 2, 470)
	add_child(heroine)
	heroine.set_theme({"key": "space"})
	fx = ParticlesScript.new()
	fx.z_index = 10
	add_child(fx)
	for layer in 2:
		for i in 70:
			stars.append({"pos": Vector2(randf_range(FIELD_X, W), randf_range(0, H)), "layer": layer,
				"r": randf_range(0.6, 1.4) + layer * 0.6, "a": randf_range(0.3, 1.0)})
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


func move_ship(x: float) -> void:
	ship_x = clampf(x, FIELD_X + 44, W - 44)


func make_rock(pos: Vector2, r: float, hp: int, armored := false) -> Dictionary:
	var pts := PackedVector2Array()
	var n := 11
	for i in n:
		var a := TAU * i / n + randf_range(-0.15, 0.15)
		pts.append(Vector2(cos(a), sin(a)) * r * randf_range(0.8, 1.0))
	var craters: Array = []
	for i in randi_range(2, 3):
		craters.append({"p": Vector2(randf_range(-0.45, 0.45), randf_range(-0.45, 0.45)) * r, "r": r * randf_range(0.12, 0.22)})
	return {"pos": pos, "base": pos, "r": r, "hp": hp, "max": hp, "pts": pts, "craters": craters,
		"rot": randf() * TAU, "spin": randf_range(-0.6, 0.6), "armored": armored, "flash": 0.0,
		"free": false, "vel": Vector2.ZERO}


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
					return
				firing = true
			else:
				firing = false
				if absf(e.position.x - _drag_start) < 18:
					_on_tap()
		elif e is InputEventScreenDrag and state not in ["over", "won"]:
			move_ship(ship_x + (e.position.x - _last_x) * 1.35)
			_last_x = e.position.x
	elif event.is_action_pressed("ui_accept"):
		_on_tap()


func _on_tap() -> void:
	if state == "ready":
		start_wave()
	elif state == "over" or state == "won":
		restart()


# ---------------- levels ----------------
func load_level(index: int, first := false) -> void:
	level_index = index
	lvl = levels[index]
	asteroids.clear()
	bolts.clear()
	capsules.clear()
	formation_y = -260.0
	streak = 0
	triple_time = 0.0
	rapid_time = 0.0
	big_text = ""

	var layout: Array = lvl.layout
	var cols: int = layout[0].length()
	var start_x := FIELD_X + (FIELD_W - cols * CELL_W) / 2 + CELL_W / 2
	for r in layout.size():
		var row: String = layout[r]
		for c in cols:
			var ch := row[c]
			if ch == ".":
				continue
			var pos := Vector2(start_x + c * CELL_W + randf_range(-8, 8), FORM_TOP + r * CELL_H + randf_range(-6, 6))
			if ch == "X":
				asteroids.append(make_rock(pos, 29, 6, true))
			else:
				var hp := int(ch)
				asteroids.append(make_rock(pos, 18.0 + hp * 5.0, hp))

	state = "ready"
	center_text = "Тапни — старт\nТримай палець — вогонь, веди — політ"
	if first:
		heroine.idle()
		say("Привіт, пілоте! Тапни, щоб злетіти!", 0)
	else:
		heroine.idle()
		heroine.cheer()
		say(lvl.hello, 2.6)


func start_wave() -> void:
	state = "play"
	center_text = ""
	meteor_cd = lvl.meteor_every
	_chatter = randf_range(9, 15)
	sfx.play("shield")
	say("Вогонь!", 1.2)


func formation_left() -> int:
	var n := 0
	for a in asteroids:
		if not a.free:
			n += 1
	return n


# ---------------- update ----------------
func _process(delta: float) -> void:
	_time += delta

	if Input.is_action_pressed("ui_left"):
		move_ship(ship_x - 700 * delta)
	if Input.is_action_pressed("ui_right"):
		move_ship(ship_x + 700 * delta)
	var kb_fire := Input.is_key_pressed(KEY_SPACE)

	ship_tilt = lerpf(ship_tilt, clampf((ship_x - _ship_prev_x) / maxf(delta, 0.001) / 1500.0, -0.25, 0.25), 0.2)
	_ship_prev_x = ship_x

	for s in stars:
		s.pos.y += (18.0 + s.layer * 40.0) * delta
		if s.pos.y > H:
			s.pos = Vector2(randf_range(FIELD_X, W), 0)

	_update_timers(delta)
	if state == "play":
		fire_cd -= delta
		if (firing or kb_fire) and fire_cd <= 0.0:
			_fire()
		_update_formation(delta)
		_update_meteors(delta)
	_update_bolts(delta)
	_update_capsules(delta)

	for a in asteroids:
		a.rot += a.spin * delta
		a.flash = maxf(a.flash - delta, 0.0)
	for f in floats:
		f.life -= delta
		f.pos.y -= 70 * delta
	floats = floats.filter(func(f): return f.life > 0)
	queue_redraw()


func _update_timers(delta: float) -> void:
	if bubble_left != INF:
		bubble_left -= delta
		if bubble_left <= 0:
			bubble_alpha = maxf(bubble_alpha - delta / 0.3, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	shield_time = maxf(shield_time - delta, 0.0)
	triple_time = maxf(triple_time - delta, 0.0)
	rapid_time = maxf(rapid_time - delta, 0.0)
	if state == "play":
		_chatter -= delta
		if _chatter <= 0:
			_chatter = randf_range(9, 15)
			if not heroine.busy:
				say(pick(PHRASES.idle), 1.8)


func _fire() -> void:
	fire_cd = 0.11 if rapid_time > 0 else 0.2
	var angles := [-0.16, 0.0, 0.16] if triple_time > 0 else [0.0]
	for a in angles:
		bolts.append({"pos": Vector2(ship_x, SHIP_Y - 40), "vel": Vector2(sin(a), -cos(a)) * BOLT_SPEED})
	sfx.play("laser")


func _update_bolts(delta: float) -> void:
	for b in bolts.duplicate():
		b.pos += b.vel * delta
		if b.pos.y < -20:
			bolts.erase(b)
			streak = 0
			continue
		for a in asteroids:
			if b.pos.distance_squared_to(a.pos) < a.r * a.r:
				bolts.erase(b)
				_hit_rock(a, b.pos)
				break
		if state != "play":
			return


func _hit_rock(a: Dictionary, at: Vector2) -> void:
	a.hp -= 1
	a.flash = 0.1
	fx.burst(at, 6, [GREEN, Color("#b8ffc9")])
	if a.hp > 0:
		sfx.play("hit")
		return
	_explode_rock(a, true)
	if formation_left() == 0 and state == "play":
		level_complete()


func _explode_rock(a: Dictionary, by_player: bool) -> void:
	asteroids.erase(a)
	sfx.play("explode")
	var rock: Color = lvl.armor if a.armored else lvl.rock
	fx.burst(a.pos, int(a.r), [rock, rock.lerp(lvl.light, 0.5), lvl.light])
	if not by_player:
		return
	streak += 1
	var points: int = 10 * a.max + streak * 2
	score += points
	float_text(a.pos, "+%d" % points)
	if randf() < 0.12:
		capsules.append({"pos": a.pos, "type": BONUSES.keys()[randi() % BONUSES.size()]})
	if streak >= 5 and streak % 5 == 0:
		heroine.cheer()
		say(pick(PHRASES.streak).replace("{n}", str(streak)), 1.5)
		fx.burst(Vector2(PANEL_W / 2, 250), 16, [Color("#ffd700"), Color.WHITE, GREEN], "star")
		sfx.play("combo")


func _update_formation(delta: float) -> void:
	formation_y += 140.0 * delta if formation_y < 0 else lvl.descend * delta
	var sway := sin(_time * 0.6) * 22.0
	for a in asteroids.duplicate():
		if a.free:
			continue
		a.pos = a.base + Vector2(sway, formation_y)
		if a.pos.y + a.r > DANGER_Y:
			_explode_rock(a, false)
			formation_y -= 110.0
			ship_hit()
			if state != "play":
				return
	if state == "play" and formation_left() == 0:
		level_complete()


func _update_meteors(delta: float) -> void:
	meteor_cd -= delta
	if meteor_cd <= 0:
		meteor_cd = lvl.meteor_every * randf_range(0.7, 1.3)
		var m := make_rock(Vector2(randf_range(FIELD_X + 40, W - 40), -30), 14, 1)
		m.free = true
		m.vel = Vector2(randf_range(-70, 70), randf_range(170, 230) + level_index * 25)
		m.spin = randf_range(-3, 3)
		asteroids.append(m)
	var ship := Vector2(ship_x, SHIP_Y)
	for m in asteroids.duplicate():
		if not m.free:
			continue
		m.pos += m.vel * delta
		if m.pos.x < FIELD_X + m.r or m.pos.x > W - m.r:
			m.vel.x = -m.vel.x
		if m.pos.distance_to(ship) < m.r + SHIP_R:
			_explode_rock(m, false)
			ship_hit()
			if state != "play":
				return
		elif m.pos.y > H + 40:
			asteroids.erase(m)


func ship_hit() -> void:
	if invuln > 0:
		return
	if shield_time > 0:
		shield_time = 0.0
		invuln = 1.0
		sfx.play("shield")
		say("Щит врятував!", 1.4)
		return
	lives -= 1
	streak = 0
	invuln = 2.0
	sfx.play("lose")
	_shake(0.3)
	fx.burst(Vector2(ship_x, SHIP_Y), 30, [Color("#ffb347"), Color("#ff5a3c"), Color.WHITE])
	if lives <= 0:
		game_over()
		return
	heroine.sad()
	say(pick(PHRASES.hit), 1.8)


func game_over() -> void:
	state = "over"
	firing = false
	bolts.clear()
	heroine.sad(true)
	say("Не здавайся! Спробуймо ще раз?", 0)
	sfx.play("game_over")
	big_text = "GAME OVER"
	big_color = Color("#ff4f6a")
	center_text = "Рахунок: %d\nТапни, щоб грати знову" % score


func _update_capsules(delta: float) -> void:
	for c in capsules.duplicate():
		c.pos.y += 150 * delta
		if c.pos.distance_to(Vector2(ship_x, SHIP_Y)) < 44:
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
	float_text(Vector2(ship_x, SHIP_Y - 60), info.say, info.color)
	match type:
		"triple": triple_time = 10.0
		"rapid": rapid_time = 10.0
		"shield": shield_time = 12.0
		"life": lives = mini(lives + 1, 6)


func level_complete() -> void:
	state = "transition"
	firing = false
	bolts.clear()
	capsules.clear()
	asteroids.clear()
	sfx.play("win")
	heroine.victory()
	fx.confetti_on = true
	later(1.8, func(): fx.confetti_on = false)
	score += 100 * (level_index + 1)

	if level_index == levels.size() - 1:
		state = "won"
		say("Ти найкращий пілот галактики!", 0)
		big_text = "ПЕРЕМОГА!"
		big_color = Color("#ffd23f")
		center_text = "Рахунок: %d\nТапни, щоб грати знову" % score
		_victory_stars()
		return
	say(pick(PHRASES.win), 2.4)
	big_text = "СЕКТОР %d ЧИСТИЙ" % (level_index + 1)
	big_color = GREEN
	later(2.6, func(): load_level(level_index + 1))


func _victory_stars() -> void:
	if state != "won":
		return
	fx.burst(Vector2(PANEL_W / 2, 300), 20, [Color("#ffd700"), Color.WHITE, GREEN], "star")
	later(2.5, _victory_stars)


func restart() -> void:
	_run_id += 1
	fx.confetti_on = false
	score = 0
	lives = START_LIVES
	invuln = 0.0
	shield_time = 0.0
	load_level(0, true)
	say("Поїхали ще раз!", 1.8)
	heroine.cheer()


func _shake(sec: float) -> void:
	var t := create_tween()
	for i in int(sec / 0.03):
		t.tween_property(self, "position", Vector2(randf_range(-7, 7), randf_range(-7, 7)), 0.03)
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
	Themes.draw_backdrop(self, lvl, level_index + 7, PANEL_W, W, H)
	for s in stars:
		draw_circle(s.pos, s.r, Color(1, 1, 1, s.a))
	_draw_star()
	for a in asteroids:
		_draw_rock(a)
	for c in capsules:
		var info: Dictionary = BONUSES[c.type]
		draw_circle(c.pos, 22, Color(info.color, 0.25))
		draw_circle(c.pos, 16, info.color)
		draw_circle(c.pos + Vector2(-5, -5), 5, Color(1, 1, 1, 0.6))
		_text_centered(c.pos, info.label, 16, Color.WHITE, 60, 3)
	for b in bolts:
		var tail: Vector2 = b.pos - b.vel.normalized() * 26
		draw_line(tail, b.pos, Color(GREEN, 0.25), 12)
		draw_line(tail, b.pos, Color(GREEN, 0.6), 6)
		draw_line(tail, b.pos, Color("#d9ffe3"), 2.5)
	if state not in ["over"]:
		_draw_ship()
	for f in floats:
		var col: Color = f.color
		col.a = clampf(f.life / 0.7, 0, 1)
		_text_centered(f.pos, f.text, 22, col, 300, 4)
	_draw_hud()
	_draw_bubble()


func _draw_star() -> void:
	var pulse := 1.0 + sin(_time * 2.0) * 0.04
	for i in 6:
		draw_circle(STAR_POS, (90 - i * 12) * pulse, Color(lvl.star, 0.06 + i * 0.03))
	draw_circle(STAR_POS, 22, lvl.light)
	draw_circle(STAR_POS, 14, Color.WHITE)
	# lens flare rays
	for i in 4:
		var d := Vector2.from_angle(i * PI / 4 + _time * 0.1)
		draw_line(STAR_POS - d * 70, STAR_POS + d * 70, Color(lvl.light, 0.25), 2)


func _light_dir(p: Vector2) -> Vector2:
	return (STAR_POS - p).normalized()


func _draw_rock(a: Dictionary) -> void:
	var L := _light_dir(a.pos)
	var base: Color = lvl.armor if a.armored else lvl.rock
	if a.flash > 0:
		base = base.lerp(Color.WHITE, 0.5)
	var r: float = a.r
	var shape := PackedVector2Array()
	for p in a.pts:
		shape.append(a.pos + p.rotated(a.rot))

	# shadow side, then lit layers shifted toward the star
	draw_colored_polygon(shape, base.darkened(0.55))
	var layers := [[0.86, 0.10, base.darkened(0.15)], [0.6, 0.28, base.lerp(lvl.light, 0.35)]]
	for ly in layers:
		var pts := PackedVector2Array()
		for p in a.pts:
			pts.append(a.pos + p.rotated(a.rot) * ly[0] + L * r * ly[1])
		draw_colored_polygon(pts, ly[2])

	# craters: dark pit with a lit far rim
	for c in a.craters:
		var cp: Vector2 = a.pos + c.p.rotated(a.rot)
		draw_circle(cp, c.r, base.darkened(0.4))
		draw_arc(cp, c.r, L.angle() + PI - 1.0, L.angle() + PI + 1.0, 8, base.lerp(lvl.light, 0.5), 1.5)

	if a.armored:
		draw_arc(a.pos, r * 0.55, a.rot, a.rot + PI * 1.2, 12, Color("#ffb347", 0.8), 3)
	if lvl.get("lava", false):
		draw_polyline(PackedVector2Array([a.pos + Vector2(-0.4, -0.2).rotated(a.rot) * r, a.pos, a.pos + Vector2(0.3, 0.4).rotated(a.rot) * r]), Color("#ff7a1f", 0.85), 2.5)
	if a.hp < a.max:
		draw_polyline(PackedVector2Array([a.pos + Vector2(0.1, -0.7).rotated(a.rot) * r, a.pos + Vector2(-0.1, -0.1).rotated(a.rot) * r, a.pos + Vector2(0.3, 0.5).rotated(a.rot) * r]), Color(0, 0, 0, 0.6), 2)

	# rim light on the edges facing the star
	var n := shape.size()
	for i in n:
		var p0 := shape[i]
		var p1 := shape[(i + 1) % n]
		var mid: Vector2 = (p0 + p1) / 2 - a.pos
		var facing: float = mid.normalized().dot(L)
		if facing > 0.25:
			draw_line(p0, p1, Color(lvl.light, clampf(facing, 0.0, 1.0)), 2.5)


func _draw_ship() -> void:
	if invuln > 0 and fmod(_time, 0.2) < 0.1:
		return
	var o := Vector2(ship_x, SHIP_Y)
	var L := _light_dir(o)
	var lit_left := L.x < 0
	var xf := Transform2D(ship_tilt, o)

	# engine flame
	var flick := 1.0 + sin(_time * 40.0) * 0.15
	for ex in [-6.0, 6.0]:
		draw_colored_polygon(xf * PackedVector2Array([Vector2(ex - 5, 32), Vector2(ex + 5, 32), Vector2(ex, 32 + 26 * flick)]), Color("#ff9a3d", 0.8))
		draw_colored_polygon(xf * PackedVector2Array([Vector2(ex - 2.5, 32), Vector2(ex + 2.5, 32), Vector2(ex, 32 + 14 * flick)]), Color("#fff3b0"))
	draw_circle(xf * Vector2(0, 38), 14, Color("#ff9a3d", 0.18))

	var hull := Color("#4a5470")
	var lit := hull.lerp(lvl.light, 0.45)
	var dark := hull.darkened(0.45)
	var left := [Vector2(0, -42), Vector2(0, 34), Vector2(-9, 34), Vector2(-13, 24), Vector2(-40, 30), Vector2(-38, 20), Vector2(-15, 6), Vector2(-10, -18)]
	var right: Array = []
	for p in left:
		right.append(Vector2(-p.x, p.y))
	draw_colored_polygon(xf * PackedVector2Array(left), lit if lit_left else dark)
	draw_colored_polygon(xf * PackedVector2Array(right), dark if lit_left else lit)
	# wing stripes and nose detail
	draw_colored_polygon(xf * PackedVector2Array([Vector2(-34, 24), Vector2(-20, 14), Vector2(-20, 19), Vector2(-33, 28)]), GREEN)
	draw_colored_polygon(xf * PackedVector2Array([Vector2(34, 24), Vector2(20, 14), Vector2(20, 19), Vector2(33, 28)]), GREEN.darkened(0.3))
	# cockpit glass
	var glass := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		glass.append(Vector2(cos(a) * 6, -8 + sin(a) * 12))
	draw_colored_polygon(xf * glass, Color("#1d6f8f"))
	draw_circle(xf * Vector2(-2 if lit_left else 2, -12), 2.5, Color("#c8f4ff"))
	# rim light along the edge facing the star
	var edge: Array = left if lit_left else right
	var rim := PackedVector2Array()
	for i in range(1, edge.size()):
		rim.append(edge[i])
	rim.append(edge[0])
	draw_polyline(xf * rim, Color(lvl.light, 0.9), 2)

	if shield_time > 0:
		var a := 0.35 + sin(_time * 6.0) * 0.1
		draw_circle(o, 50, Color("#40c4ff", 0.12))
		draw_arc(o, 50, 0, TAU, 40, Color("#40c4ff", a + 0.3), 2.5)


func _draw_hud() -> void:
	_text(Vector2(FIELD_X + 20, 44), "Рахунок %d" % score, 26, Color.WHITE)
	_text(Vector2(FIELD_X, 44), "%d/%d · %s" % [level_index + 1, levels.size(), lvl.name], 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, FIELD_W)
	for i in maxi(lives, 0):
		_heart(Vector2(W - 80 - i * 30, 34), 26, Color("#ff4f8b"))
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
	# active power-ups
	var px := FIELD_X + 20
	for k in [["triple", triple_time], ["rapid", rapid_time], ["shield", shield_time]]:
		if k[1] > 0:
			var info: Dictionary = BONUSES[k[0]]
			_rr(Rect2(px, 60, 70, 24), 12, Color(info.color, 0.85))
			_text_centered(Vector2(px + 35, 72), "%s %d" % [info.label, ceili(k[1])], 16, Color.WHITE, 70, 3)
			px += 80

	if center_text != "":
		_text_centered(Vector2(FIELD_X + FIELD_W / 2, 470), center_text, 30, Color.WHITE, FIELD_W - 80)
	if big_text != "":
		_text_centered(Vector2(FIELD_X + FIELD_W / 2, 330), big_text, 60, big_color, FIELD_W - 40, 10)


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
