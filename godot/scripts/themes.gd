extends RefCounted
## Level themes: heroine outfit key, colors, background and brick layout.
## Layout chars: '.' empty, '1'-'3' hits needed, 'X' unbreakable.

static func all() -> Array:
	return [
		{
			"key": "beach", "name": "Пляж",
			"sky_top": Color("#5ec8f2"), "sky_bottom": Color("#ffd59e"),
			"field": Color("#0f3d5c"), "accent": Color("#ff7a59"),
			"ball": Color("#ffffff"), "paddle": Color("#ffb347"),
			"bricks": [Color("#ff7a59"), Color("#ffc145"), Color("#4ecdc4")],
			"hello": "Привіт! Літо, сонце і м'ячик!",
			"layout": [
				"...........",
				".111111111.",
				".122222221.",
				".123333321.",
				".122222221.",
				".111111111.",
			],
		},
		{
			"key": "neon", "name": "Неон-сіті",
			"sky_top": Color("#12002b"), "sky_bottom": Color("#3a0a5e"),
			"field": Color("#0a0018"), "accent": Color("#00f0ff"),
			"ball": Color("#00f0ff"), "paddle": Color("#ff2bd6"),
			"bricks": [Color("#ff2bd6"), Color("#00f0ff"), Color("#faff00")],
			"hello": "Нічне місто світиться для нас!",
			"layout": [
				".....3.....",
				"....222....",
				"...11111...",
				"..2221222..",
				".X1111111X.",
				"..2221222..",
				"...11111...",
				"....222....",
			],
		},
		{
			"key": "space", "name": "Космос",
			"sky_top": Color("#02021a"), "sky_bottom": Color("#1b1450"),
			"field": Color("#03031a"), "accent": Color("#ffffff"),
			"ball": Color("#fff3b0"), "paddle": Color("#9fb4ff"),
			"bricks": [Color("#9fb4ff"), Color("#c39bff"), Color("#ff9bd2")],
			"hello": "Відкритий космос! Летимо!",
			"layout": [
				"3.3.3.3.3.3",
				".2.2.2.2.2.",
				"1111111111.",
				".1111111111",
				"2X2X2.2X2X2",
				"11111111111",
				".3.......3.",
			],
		},
		{
			"key": "fantasy", "name": "Казка",
			"sky_top": Color("#2b1055"), "sky_bottom": Color("#d16ba5"),
			"field": Color("#1a0b33"), "accent": Color("#ffd700"),
			"ball": Color("#ffd700"), "paddle": Color("#b57bff"),
			"bricks": [Color("#7bffb5"), Color("#b57bff"), Color("#ffd700")],
			"hello": "Фінальний рівень. Корона чекає!",
			"layout": [
				"X.X.X.X.X.X",
				"33333333333",
				"2.2.2.2.2.2",
				"22222222222",
				"1.1.1.1.1.1",
				"11111111111",
				"11111111111",
				"XX.......XX",
			],
		},
	]


static func _ellipse(ci: CanvasItem, c: Vector2, w: float, h: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * w * 0.5, sin(a) * h * 0.5))
	ci.draw_colored_polygon(pts, col)


static func draw_background(ci: CanvasItem, t: Dictionary, panel_w: float, w: float, h: float) -> void:
	# panel sky gradient
	ci.draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(panel_w, 0), Vector2(panel_w, h), Vector2(0, h)]),
		PackedColorArray([t.sky_top, t.sky_top, t.sky_bottom, t.sky_bottom]))
	ci.draw_rect(Rect2(panel_w, 0, w - panel_w, h), t.field)

	var rnd := RandomNumberGenerator.new()
	rnd.seed = hash(t.key)

	match t.key:
		"beach":
			ci.draw_circle(Vector2(270, 110), 70, Color("#fff3a0", 0.25))
			ci.draw_circle(Vector2(270, 110), 46, Color("#fff3a0"))
			ci.draw_rect(Rect2(0, 520, panel_w, 200), Color("#1e90c8"))
			for i in 4:
				ci.draw_rect(Rect2(0, 530 + i * 26, panel_w, 6), Color("#7fd4f5"))
			ci.draw_rect(Rect2(0, 640, panel_w, 80), Color("#f2d29b"))
			ci.draw_rect(Rect2(36, 300, 14, 340), Color("#8b5a2b"))
			_ellipse(ci, Vector2(10, 300), 90, 26, Color("#2e8b57"))
			_ellipse(ci, Vector2(80, 296), 90, 26, Color("#2e8b57"))
			_ellipse(ci, Vector2(44, 280), 26, 70, Color("#2e8b57"))
			for y in range(60, int(h), 70):
				var pts := PackedVector2Array()
				for x in range(int(panel_w), int(w) + 1, 20):
					pts.append(Vector2(x, y + sin(x / 40.0) * 6))
				ci.draw_polyline(pts, Color("#1a5a85", 0.6), 2)
		"neon":
			var neon := [Color("#ff2bd6"), Color("#00f0ff"), Color("#faff00")]
			for i in 9:
				var bw := 30 + rnd.randi_range(0, 20)
				var bh := 120 + rnd.randi_range(0, 220)
				var x := i * 40
				ci.draw_rect(Rect2(x, 640 - bh, bw, bh), Color("#1b0638"))
				var wy := 640 - bh + 10
				while wy < 630:
					var wx := x + 5
					while wx < x + bw - 6:
						if rnd.randf() > 0.55:
							ci.draw_rect(Rect2(wx, wy, 4, 6), Color(neon[rnd.randi() % 3], 0.8))
						wx += 10
					wy += 18
			ci.draw_rect(Rect2(0, 640, panel_w, 80), Color("#0a0018"))
			var grid := Color("#ff2bd6", 0.18)
			for x in range(int(panel_w), int(w) + 1, 46):
				ci.draw_line(Vector2(x, 0), Vector2(x, h), grid, 1)
			for y in range(0, int(h) + 1, 46):
				ci.draw_line(Vector2(panel_w, y), Vector2(w, y), grid, 1)
		"space":
			for i in 160:
				ci.draw_circle(Vector2(rnd.randf_range(0, w), rnd.randf_range(0, h)),
					rnd.randf_range(0.6, 2.0), Color(1, 1, 1, rnd.randf_range(0.2, 1.0)))
			ci.draw_circle(Vector2(80, 120), 50, Color("#ff9bd2"))
			var ring := PackedVector2Array()
			for i in 41:
				var a := TAU * i / 40.0
				ring.append(Vector2(80 + cos(a) * 80, 120 + sin(a) * 17))
			ci.draw_polyline(ring, Color("#ffd1ea", 0.8), 6)
			_ellipse(ci, Vector2(180, 700), 520, 160, Color("#3a3a6a"))
		_:
			for i in 40:
				ci.draw_circle(Vector2(rnd.randf_range(0, w), rnd.randf_range(0, h)),
					rnd.randf_range(1.0, 2.5), Color("#fff6c0", rnd.randf_range(0.3, 0.9)))
			ci.draw_circle(Vector2(290, 80), 34, Color("#f5f0ff", 0.9))
			var castle := Color("#2a1450")
			ci.draw_rect(Rect2(20, 420, 300, 220), castle)
			ci.draw_rect(Rect2(10, 330, 70, 310), castle)
			ci.draw_rect(Rect2(260, 330, 70, 310), castle)
			ci.draw_rect(Rect2(140, 300, 60, 340), castle)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(5, 330), Vector2(85, 330), Vector2(45, 260)]), castle)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(255, 330), Vector2(335, 330), Vector2(295, 260)]), castle)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(135, 300), Vector2(205, 300), Vector2(170, 220)]), castle)
			for r in [Rect2(38, 380, 12, 18), Rect2(290, 380, 12, 18), Rect2(164, 350, 12, 18)]:
				ci.draw_rect(r, Color("#ffd700", 0.8))
			ci.draw_rect(Rect2(0, 640, panel_w, 80), Color("#1a0b33"))

	ci.draw_rect(Rect2(panel_w - 4, 0, 4, h), t.accent)
