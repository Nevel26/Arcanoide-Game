extends Node2D
## Draws the backdrop of every screen: menu, star map, planet surface, space encounter.
## Everything is lit from the side by the system's star, like in NevelskyiArt Space.

const STAR := Vector2(70, 360)
const LIGHT := Color("#fff1b0")
const PLANET_POS := [Vector2(470, 250), Vector2(660, 470), Vector2(880, 240), Vector2(1090, 470)]
const PLANET_R := [46.0, 56.0, 42.0, 50.0]
const HOME := Vector2(250, 560)

var mode := "menu"
var planet: Dictionary = {}
var encounter: Dictionary = {}
var planets: Array = []
var ship_pos := HOME
var ship_angle := 0.0
var ship_moving := false
var talking := 0.0
var _time := 0.0
var _stars: Array = []
var _blink := 0.0


func _ready() -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 42
	for i in 220:
		_stars.append({"p": Vector2(rnd.randf_range(0, 1280), rnd.randf_range(0, 720)),
			"r": rnd.randf_range(0.5, 1.8), "a": rnd.randf_range(0.3, 1.0), "ph": rnd.randf() * TAU})


func _process(delta: float) -> void:
	_time += delta
	talking = maxf(talking - delta, 0.0)
	_blink -= delta
	if _blink < -0.12:
		_blink = randf_range(2.0, 4.5)
	queue_redraw()


# ---------------- primitives ----------------
func _space(top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)]),
		PackedColorArray([top, top, bottom, bottom]))
	for s in _stars:
		var a: float = s.a * (0.7 + 0.3 * sin(_time * 2.0 + s.ph))
		draw_circle(s.p, s.r, Color(1, 1, 1, a))


func _star(pos: Vector2, size: float) -> void:
	var pulse := 1.0 + sin(_time * 1.6) * 0.04
	for i in 7:
		draw_circle(pos, (size * 2.2 - i * size * 0.25) * pulse, Color(Color("#ffe27a"), 0.05 + i * 0.03))
	draw_circle(pos, size * 0.5, LIGHT)
	draw_circle(pos, size * 0.33, Color.WHITE)


func lit_sphere(c: Vector2, r: float, col: Color, light_from: Vector2) -> void:
	var L := (light_from - c).normalized()
	var dark := col.darkened(0.65)
	draw_circle(c, r, dark)
	for k in range(1, 6):
		var t := k / 5.0
		draw_circle(c + L * r * 0.11 * k, r * (1.0 - 0.12 * k), dark.lerp(col.lerp(LIGHT, 0.35), t))
	draw_arc(c, r + 2, L.angle() - 1.2, L.angle() + 1.2, 24, Color(LIGHT, 0.6), 3)
	draw_arc(c, r + 7, L.angle() - 1.0, L.angle() + 1.0, 24, Color(col.lightened(0.3), 0.18), 8)


func ellipse_pts(c: Vector2, rx: float, ry: float, from := 0.0, to := TAU, n := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := from + (to - from) * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func draw_ship(pos: Vector2, angle: float, s: float, hull := Color("#4a5470"), accent := Color("#39ff6a")) -> void:
	var xf := Transform2D(angle, Vector2(s, s), 0.0, pos)
	var L := (STAR - pos).normalized().rotated(-angle)
	var lit_left := L.x < 0
	var flick := 1.0 + sin(_time * 40.0) * 0.15
	var flame := 26.0 if ship_moving else 12.0
	for ex in [-6.0, 6.0]:
		draw_colored_polygon(xf * PackedVector2Array([Vector2(ex - 5, 32), Vector2(ex + 5, 32), Vector2(ex, 32 + flame * flick)]), Color("#ff9a3d", 0.8))
		draw_colored_polygon(xf * PackedVector2Array([Vector2(ex - 2.5, 32), Vector2(ex + 2.5, 32), Vector2(ex, 32 + flame * 0.55 * flick)]), Color("#fff3b0"))
	var lit := hull.lerp(LIGHT, 0.45)
	var dark := hull.darkened(0.45)
	var left := [Vector2(0, -42), Vector2(0, 34), Vector2(-9, 34), Vector2(-13, 24), Vector2(-40, 30), Vector2(-38, 20), Vector2(-15, 6), Vector2(-10, -18)]
	var right: Array = []
	for p in left:
		right.append(Vector2(-p.x, p.y))
	draw_colored_polygon(xf * PackedVector2Array(left), lit if lit_left else dark)
	draw_colored_polygon(xf * PackedVector2Array(right), dark if lit_left else lit)
	draw_colored_polygon(xf * PackedVector2Array([Vector2(-34, 24), Vector2(-20, 14), Vector2(-20, 19), Vector2(-33, 28)]), accent)
	draw_colored_polygon(xf * PackedVector2Array([Vector2(34, 24), Vector2(20, 14), Vector2(20, 19), Vector2(33, 28)]), accent.darkened(0.3))
	draw_colored_polygon(xf * ellipse_pts(Vector2(0, -8), 6, 12, 0, TAU, 16), Color("#1d6f8f"))
	var edge: Array = left if lit_left else right
	var rim := PackedVector2Array()
	for i in range(1, edge.size()):
		rim.append(edge[i])
	rim.append(edge[0])
	draw_polyline(xf * rim, Color(LIGHT, 0.9), 2.0 / s)


# ---------------- screens ----------------
func _draw() -> void:
	match mode:
		"menu": _draw_menu()
		"map": _draw_map()
		"planet": _draw_planet()
		"encounter": _draw_encounter()


func _draw_menu() -> void:
	_space(Color("#05061a"), Color("#1a0f3a"))
	_star(Vector2(120, 140), 70)
	lit_sphere(Vector2(1060, 600), 260, Color("#5fb8ff"), Vector2(120, 140))
	draw_polyline(ellipse_pts(Vector2(1060, 600), 380, 70, PI * 1.05, PI * 1.95), Color("#ffd23f", 0.7), 4)
	draw_ship(Vector2(800 + sin(_time) * 20, 300 + cos(_time * 1.3) * 10), 0.6, 1.4)


func _draw_map() -> void:
	_space(Color("#05061a"), Color("#140c33"))
	_star(STAR, 70)
	for i in planets.size():
		var c: Vector2 = PLANET_POS[i]
		var d := c.distance_to(STAR)
		draw_arc(STAR, d, -0.9, 0.9, 64, Color(1, 1, 1, 0.07), 1.5)
	# home station
	draw_rect(Rect2(HOME + Vector2(-34, -6), Vector2(68, 12)), Color("#6a7590"))
	draw_circle(HOME, 14, Color("#9aa7bd"))
	draw_circle(HOME + Vector2(-4, -4), 6, LIGHT)
	for i in planets.size():
		var p: Dictionary = planets[i]
		var c: Vector2 = PLANET_POS[i]
		var r: float = PLANET_R[i]
		if p.id == "market":
			draw_polyline(ellipse_pts(c, r * 1.8, r * 0.45, PI, TAU), Color("#ffd9a0", 0.6), 4)
		lit_sphere(c, r, p.color, STAR)
		_planet_details(p.id, c, r)
		if p.id == "market":
			draw_polyline(ellipse_pts(c, r * 1.8, r * 0.45, 0, PI), Color("#ffd9a0", 0.8), 4)
	draw_ship(ship_pos, ship_angle, 0.8)


func _planet_details(id: String, c: Vector2, r: float) -> void:
	var L := (STAR - c).normalized()
	match id:
		"port":
			for k in 7:
				var p := c - L * r * 0.45 + Vector2(cos(k * 1.7), sin(k * 2.3)) * r * 0.35
				draw_circle(p, 2, Color("#ffe27a", 0.8 + 0.2 * sin(_time * 3 + k)))
		"repair":
			for k in 3:
				draw_arc(c, r * (0.45 + k * 0.17), 0.2, PI - 0.2, 20, Color(0, 0, 0, 0.25), 3)
		"medbay":
			draw_rect(Rect2(c + L * r * 0.2 + Vector2(-4, -14), Vector2(8, 28)), Color(1, 1, 1, 0.8))
			draw_rect(Rect2(c + L * r * 0.2 + Vector2(-14, -4), Vector2(28, 8)), Color(1, 1, 1, 0.8))


func _draw_planet() -> void:
	var col: Color = planet.get("color", Color("#5fb8ff"))
	_space(col.darkened(0.85), col.darkened(0.55))
	_star(Vector2(60, 90), 40)
	lit_sphere(Vector2(440, 150), 50, col.lerp(Color.WHITE, 0.2), Vector2(60, 90))
	# ground and buildings
	draw_colored_polygon(ellipse_pts(Vector2(640, 980), 1100, 420), col.darkened(0.6))
	draw_polyline(ellipse_pts(Vector2(640, 980), 1100, 420, PI * 1.15, PI * 1.6), Color(LIGHT, 0.5), 3)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = hash(planet.get("id", ""))
	for i in 6:
		var x := 40 + i * 90 + rnd.randf_range(-10, 10)
		var h := rnd.randf_range(90, 220)
		var w := rnd.randf_range(40, 70)
		draw_rect(Rect2(x, 600 - h, w, h + 30), col.darkened(0.72))
		draw_rect(Rect2(x, 600 - h, 4, h + 30), Color(LIGHT, 0.25))
		for wy in range(int(600 - h + 14), 590, 22):
			if rnd.randf() > 0.4:
				draw_rect(Rect2(x + 12, wy, 8, 8), Color(col.lightened(0.4), 0.7))
	_draw_npc(Vector2(300, 470), planet.get("npc_color", Color("#7ee0c8")))


func _draw_npc(pos: Vector2, col: Color) -> void:
	var L := (Vector2(60, 90) - pos).normalized()
	var bob := sin(_time * 2.0) * 4.0
	var p := pos + Vector2(0, bob)
	# body
	var body := PackedVector2Array([p + Vector2(-60, 0), p + Vector2(60, 0), p + Vector2(85, 170), p + Vector2(-85, 170)])
	draw_colored_polygon(body, col.darkened(0.45))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-60, 0), p + Vector2(10, 0), p + Vector2(0, 170), p + Vector2(-85, 170)]), col.darkened(0.15))
	draw_circle(p + Vector2(0, 60), 14, Color(LIGHT, 0.8))
	# head
	var hc := p + Vector2(0, -80)
	lit_sphere(hc, 78, col, Vector2(60, 90))
	# antennae
	for sx in [-1.0, 1.0]:
		var top := hc + Vector2(sx * 40, -110 + sin(_time * 3 + sx) * 6)
		draw_line(hc + Vector2(sx * 25, -65), top, col.darkened(0.3), 5)
		draw_circle(top, 10, Color("#ffd23f"))
	# eyes
	for sx in [-1.0, 1.0]:
		var e := hc + Vector2(sx * 28, -12)
		if _blink < 0:
			draw_line(e + Vector2(-14, 0), e + Vector2(14, 0), Color("#1a1030"), 4)
		else:
			draw_circle(e, 20, Color.WHITE)
			draw_circle(e + Vector2(L.x * 4, 2), 11, Color("#1a1030"))
			draw_circle(e + Vector2(L.x * 4 - 4, -3), 4, Color.WHITE)
	# mouth: moves while talking
	var open := 4.0 + (absf(sin(_time * 16.0)) * 14.0 if talking > 0 else 0.0)
	draw_colored_polygon(ellipse_pts(hc + Vector2(0, 32), 18, open, 0, TAU, 16), Color("#5a1030"))
	draw_arc(hc + Vector2(0, 26), 22, 0.3, PI - 0.3, 12, col.darkened(0.5), 3)


func _draw_encounter() -> void:
	_space(Color("#05061a"), Color("#120a2a"))
	_star(Vector2(-20, 160), 90)
	var col: Color = encounter.get("color", Color("#ffd23f"))
	var c := Vector2(290, 360) + Vector2(sin(_time * 0.8) * 10, cos(_time) * 8)
	match encounter.get("id", ""):
		"trader":
			for k in 3:
				lit_sphere(c + Vector2(-90 + k * 90, 70), 40, col.darkened(0.2), Vector2(-20, 160))
			draw_rect(Rect2(c + Vector2(-130, 60), Vector2(260, 20)), Color("#6a7590"))
			lit_sphere(c, 80, Color("#9aa7bd"), Vector2(-20, 160))
			draw_colored_polygon(ellipse_pts(c + Vector2(-10, -10), 40, 26), Color("#1d6f8f"))
		"distress":
			lit_sphere(c, 90, Color("#dfe6f5"), Vector2(-20, 160))
			for k in 6:
				var sm := c + Vector2(60 + k * 22, -40 - k * 30 - fmod(_time * 30, 30))
				draw_circle(sm, 16 + k * 4, Color(0.4, 0.4, 0.45, 0.35 - k * 0.05))
			if fmod(_time, 0.8) < 0.4:
				draw_circle(c + Vector2(0, -95), 14, col)
				draw_circle(c + Vector2(0, -95), 30, Color(col, 0.3))
			draw_colored_polygon(ellipse_pts(c + Vector2(-20, -10), 34, 22), Color("#1d6f8f"))
		_:
			var pts := PackedVector2Array([c + Vector2(0, -120), c + Vector2(50, -40), c + Vector2(130, -20), c + Vector2(70, 30), c + Vector2(90, 110), c + Vector2(0, 60), c + Vector2(-90, 110), c + Vector2(-70, 30), c + Vector2(-130, -20), c + Vector2(-50, -40)])
			draw_colored_polygon(pts, col.darkened(0.55))
			var lit := PackedVector2Array([c + Vector2(0, -120), c + Vector2(0, 60), c + Vector2(-90, 110), c + Vector2(-70, 30), c + Vector2(-130, -20), c + Vector2(-50, -40)])
			draw_colored_polygon(lit, col.darkened(0.15))
			draw_polyline(lit, Color(LIGHT, 0.8), 2)
			draw_circle(c + Vector2(-22, -10), 12, Color("#ffe27a"))
			draw_circle(c + Vector2(22, -10), 12, Color("#ffe27a"))
	draw_ship(Vector2(440, 610), -0.5, 1.0)
