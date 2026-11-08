extends Node2D
## Lightweight particles: sparks, stars and confetti, drawn with code.

var _parts: Array = []
var confetti_on := false
var _confetti_colors := [Color("#ff2bd6"), Color("#00f0ff"), Color("#faff00"), Color("#ff7a59"), Color("#7bffb5")]


func burst(pos: Vector2, n: int, colors: Array, kind := "spark") -> void:
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(80, 280) if kind == "spark" else randf_range(120, 320)
		var life := 0.52 if kind == "spark" else 0.9
		_parts.append({
			"pos": pos, "vel": Vector2(cos(a), sin(a)) * sp, "life": life, "max": life,
			"color": colors[randi() % colors.size()], "kind": kind,
			"size": 5.0 if kind == "spark" else 9.0, "rot": randf() * TAU, "spin": randf_range(-6, 6),
		})


func _process(delta: float) -> void:
	if confetti_on:
		for i in 4:
			_parts.append({
				"pos": Vector2(randf_range(0, 1280), -20), "vel": Vector2(randf_range(-80, 80), randf_range(160, 360)),
				"life": 3.2, "max": 3.2, "color": _confetti_colors[randi() % 5], "kind": "confetti",
				"size": 7.0, "rot": randf() * TAU, "spin": randf_range(-9, 9),
			})
	var alive: Array = []
	for p in _parts:
		p.life -= delta
		if p.life <= 0:
			continue
		p.pos += p.vel * delta
		p.rot += p.spin * delta
		if p.kind != "confetti":
			p.vel *= 0.97
		alive.append(p)
	_parts = alive
	queue_redraw()


func _draw() -> void:
	for p in _parts:
		var k: float = p.life / p.max
		match p.kind:
			"spark":
				draw_circle(p.pos, p.size * k, p.color)
			"star":
				var pts := PackedVector2Array()
				var r: float = p.size * (0.4 + k)
				for i in 8:
					var rr := r if i % 2 == 0 else r * 0.4
					var a: float = p.rot + TAU * i / 8.0
					pts.append(p.pos + Vector2(cos(a), sin(a)) * rr)
				draw_colored_polygon(pts, p.color)
			_:
				draw_set_transform(p.pos, p.rot)
				draw_rect(Rect2(-4, -7, 8, 14), p.color)
				draw_set_transform(Vector2.ZERO)
