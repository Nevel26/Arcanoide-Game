extends Node
## Dev-only smoke test: runs the game with an autopilot ship and saves screenshots.
## Usage: godot --path godot res://tests/autotest.tscn -- <output_dir>

var game: Node2D
var out := "user://"
var autopilot := true


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	game = load("res://main.tscn").instantiate()
	add_child(game)
	_run()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))


func _process(_d: float) -> void:
	if not autopilot or game.state != "play":
		return
	# aim at the lowest formation asteroid, dodge nothing (keeps the test simple)
	var target = null
	for a in game.asteroids:
		if not a.free and (target == null or a.pos.y > target.pos.y):
			target = a
	if target:
		game.move_ship(move_toward(game.ship_x, target.pos.x, 12))
	game.firing = true


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _run() -> void:
	await _wait(1.0)
	await _shot("s_start")
	var start: int = game.asteroids.size()
	game.start_wave()
	await _wait(6.0)
	await _shot("s_play")
	await _wait(14.0)
	print("AUTOPLAY rocks %d -> %d, score %d, lives %d, state %s, level %d" % [start, game.formation_left(), game.score, game.lives, game.state, game.level_index])
	await _shot("s_play2")
	autopilot = false
	for i in range(game.level_index, 3):
		game.state = "play"
		game.level_complete()
		await _wait(0.8)
		if i == 0:
			await _shot("s_victory")
		await _wait(3.0)
		game.start_wave()
		await _wait(4.0)
		await _shot("s_level%d" % (game.level_index + 1))
	game.shield_time = 5.0
	game.triple_time = 5.0
	game.firing = true
	autopilot = true
	await _wait(0.6)
	await _shot("s_powerups")
	autopilot = false
	game.firing = false
	game.shield_time = 0
	game.lives = 1
	game.invuln = 0
	game.ship_hit()
	await _wait(0.6)
	await _shot("s_over")
	print("STATE after loss: ", game.state)
	get_tree().quit()
