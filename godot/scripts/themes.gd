extends RefCounted
## Space waves: star light color, asteroid colors, background and asteroid formation.
## Layout chars: '.' empty, '1'-'3' asteroid size/hits, 'X' armored asteroid (6 hits).

static func all() -> Array:
	return [
		{
			"name": "Пояс астероїдів",
			"light": Color("#fff1b0"), "star": Color("#ffe27a"),
			"space_top": Color("#05061a"), "space_bottom": Color("#140c33"),
			"nebula": Color("#6b3fa0"),
			"rock": Color("#7a685a"), "armor": Color("#8a93a6"),
			"descend": 5.0, "meteor_every": 6.0,
			"hello": "Пілоте, бачу пояс астероїдів! Вогонь!",
			"layout": [
				"...........",
				".111111111.",
				".122222221.",
				".123333321.",
				".111111111.",
			],
		},
		{
			"name": "Метеорний дощ",
			"light": Color("#ffc08a"), "star": Color("#ff9a3d"),
			"space_top": Color("#0a0410"), "space_bottom": Color("#2a0f1f"),
			"nebula": Color("#a0402f"),
			"rock": Color("#7a4f3e"), "armor": Color("#8d8a99"),
			"descend": 6.5, "meteor_every": 3.2,
			"hello": "Метеорний дощ! Ухиляйся!",
			"layout": [
				".....3.....",
				"....222....",
				"...11111...",
				"..2221222..",
				".X1111111X.",
				"..2221222..",
			],
		},
		{
			"name": "Крижані комети",
			"light": Color("#d6ecff"), "star": Color("#9fd2ff"),
			"space_top": Color("#020a1a"), "space_bottom": Color("#0b2440"),
			"nebula": Color("#2f6fa0"),
			"rock": Color("#5f86a8"), "armor": Color("#9aa7bd"),
			"descend": 7.5, "meteor_every": 2.8,
			"hello": "Тут холодно... але ми впораємось!",
			"layout": [
				"3.3.3.3.3.3",
				".2.2.2.2.2.",
				"1111111111.",
				".1111111111",
				"2X2X2.2X2X2",
				"11111111111",
			],
		},
		{
			"name": "Вогняна зірка",
			"light": Color("#ff8a5c"), "star": Color("#ff4a1f"),
			"space_top": Color("#140202"), "space_bottom": Color("#3a0a06"),
			"nebula": Color("#c0391f"),
			"rock": Color("#4a3030"), "armor": Color("#7d6f6f"),
			"lava": true,
			"descend": 8.5, "meteor_every": 2.2,
			"hello": "Фінал біля червоного гіганта!",
			"layout": [
				"X.X.X.X.X.X",
				"33333333333",
				"2.2.2.2.2.2",
				"22222222222",
				"1.1.1.1.1.1",
				"11111111111",
			],
		},
	]


static func _ellipse(ci: CanvasItem, c: Vector2, w: float, h: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * w * 0.5, sin(a) * h * 0.5))
	ci.draw_colored_polygon(pts, col)


## Static backdrop: heroine cockpit panel + deep space with nebula.
static func draw_backdrop(ci: CanvasItem, t: Dictionary, seed_key: int, panel_w: float, w: float, h: float) -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = seed_key

	# field: deep space gradient
	ci.draw_polygon(
		PackedVector2Array([Vector2(panel_w, 0), Vector2(w, 0), Vector2(w, h), Vector2(panel_w, h)]),
		PackedColorArray([t.space_top, t.space_top, t.space_bottom, t.space_bottom]))
	# nebula clouds
	for i in 7:
		var c := Vector2(rnd.randf_range(panel_w + 100, w), rnd.randf_range(80, h - 80))
		var r := rnd.randf_range(90, 200)
		for k in 12:
			ci.draw_circle(c, r * (1.0 - k * 0.075), Color(t.nebula, 0.016))

	# panel: cockpit window
	ci.draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(panel_w, 0), Vector2(panel_w, h), Vector2(0, h)]),
		PackedColorArray([t.space_top, t.space_top, t.space_bottom, t.space_bottom]))
	for i in 70:
		ci.draw_circle(Vector2(rnd.randf_range(0, panel_w), rnd.randf_range(0, 520)), rnd.randf_range(0.6, 1.8), Color(1, 1, 1, rnd.randf_range(0.3, 1.0)))
	ci.draw_circle(Vector2(70, 230), 46, t.rock.darkened(0.3))
	ci.draw_circle(Vector2(56, 220), 40, t.rock.lerp(t.light, 0.25))
	# console
	ci.draw_rect(Rect2(0, 640, panel_w, 80), Color("#1b2030"))
	ci.draw_rect(Rect2(0, 640, panel_w, 4), Color("#39ff6a", 0.7))
	for i in 6:
		ci.draw_circle(Vector2(40 + i * 55, 680), 6, [Color("#39ff6a"), Color("#ffd23f"), Color("#ff4f6a")][i % 3])
	ci.draw_rect(Rect2(panel_w - 4, 0, 4, h), Color("#39ff6a", 0.8))
