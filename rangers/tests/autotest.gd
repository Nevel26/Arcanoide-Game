extends Node
## Dev-only smoke test: walks through every screen and saves screenshots.
## Usage: godot --path rangers res://tests/autotest.tscn -- <output_dir>

var game: Node
var out := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://rangers.cfg"))
	game = load("res://main.tscn").instantiate()
	add_child(game)
	_run()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _pick(correct: bool) -> void:
	for b in game._w.options.get_children():
		if b.get_meta("correct") == correct:
			b.pressed.emit()
			return


func _run() -> void:
	await _wait(1.0)
	await _shot("r_menu")
	game.show_map()
	await _wait(1.0)
	await _shot("r_map")
	game.show_planet(0)
	await _wait(0.8)
	await _shot("r_dialog")
	game._show_hint()
	_pick(true)
	await _wait(0.6)
	await _shot("r_correct")
	game._next_item()
	_pick(false)
	await _wait(0.6)
	await _shot("r_wrong")
	var guard := 0
	while game.art.mode == "planet" and game._w.has("options") and guard < 20:
		guard += 1
		game._next_item()
		await _wait(0.1)
		if game._w.has("options") and is_instance_valid(game._w.options):
			_pick(true)
	await _wait(0.6)
	await _shot("r_result")
	print("RESULT credits=%d stars=%s learned=%d" % [game.credits, game.stars, game.learned_list().size()])
	game.show_encounter(game.encounters[2], func(): game.show_map())
	await _wait(0.8)
	await _shot("r_pirate")
	game.credits = 200
	game.show_hangar()
	await _wait(0.5)
	await _shot("r_hangar")
	game.show_journal()
	await _wait(0.5)
	await _shot("r_journal")
	game.ui_lang = "ru"
	game.lang = "es"
	game.show_planet(1)
	await _wait(0.8)
	await _shot("r_dialog_es_ru")
	game.show_encounter(game.encounters[0], func(): pass)
	await _wait(0.5)
	await _shot("r_trader")
	get_tree().quit()
