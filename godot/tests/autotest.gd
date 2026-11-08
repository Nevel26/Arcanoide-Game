extends Node
## Dev-only smoke test: runs the game with an autopilot paddle and saves screenshots.
## Usage: godot --path godot res://tests/autotest.tscn -- <output_dir>

var game: Node2D
var out := "user://"


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
	if game and game.balls.size() > 0:
		game.move_paddle(game.balls[0].pos.x + 20)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _run() -> void:
	await _wait(1.0)
	await _shot("g_start")
	var start: int = game.bricks.size()
	game.launch()
	await _wait(15.0)
	print("AUTOPLAY bricks %d -> %d, score %d, lives %d, state %s" % [start, game.bricks.size(), game.score, game.lives, game.state])
	await _shot("g_play")
	for i in 3:
		for br in game.bricks.duplicate():
			if br.hp > 0:
				game.bricks.erase(br)
		game.level_complete()
		await _wait(0.6)
		if i == 0:
			await _shot("g_victory")
		await _wait(3.2)
		await _shot("g_level%d" % (i + 2))
	game.heroine.sad()
	await _wait(0.5)
	await _shot("g_sad")
	game.lives = 1
	game.launch()
	game.balls.clear()
	await _wait(0.5)
	await _shot("g_over")
	print("STATE after loss: ", game.state)
	get_tree().quit()
