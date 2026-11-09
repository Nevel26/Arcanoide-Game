extends Node
## Lingua Rangers: fly around a star system and learn a language by talking to locals.
## Screens: menu → star map → (encounter on the way) → planet dialog → result.

const Content := preload("res://scripts/content.gd")
const I18n := preload("res://scripts/i18n.gd")
const ArtScript := preload("res://scripts/art.gd")
const HeroineScript := preload("res://scripts/heroine.gd")
const SfxScript := preload("res://scripts/sfx.gd")

const SAVE_PATH := "user://rangers.cfg"
const GREEN := Color("#39ff6a")
const RED := Color("#ff4f6a")
const GOLD := Color("#ffd23f")
const PANEL_RECT := Rect2(560, 80, 690, 610)
const UPGRADES := {"translator": 60, "shield": 80, "engine": 40}
const LANG_NAMES := {"en": "English", "es": "Español"}

var ui_lang := "uk"
var lang := "en"
var credits := 0
var stars := {}      # lang -> {planet_id: best stars}
var learned := {}    # lang -> [item ids]
var upgrades: Array = []
var system_done_shown := {}

var planets: Array
var encounters: Array
var art: Node2D
var heroine: Node2D
var heroine_holder: Node2D
var sfx: Node
var root: Control
var theme_ui: Theme

# dialog state
var _queue: Array = []
var _item: Dictionary = {}
var _total := 0
var _done := 0
var _mistakes := 0
var _shield_used := false
var _earned := 0
var _new_phrases := 0
var _on_dialog_done: Callable
var _requeued := {}
var _flying := false

# dialog widgets
var _w := {}


func _ready() -> void:
	randomize()
	planets = Content.planets()
	encounters = Content.encounters()
	load_game()

	art = ArtScript.new()
	art.planets = planets
	add_child(art)
	heroine_holder = Node2D.new()
	add_child(heroine_holder)
	heroine = HeroineScript.new()
	heroine_holder.add_child(heroine)
	heroine.set_theme({"key": "space"})
	heroine.idle()
	sfx = SfxScript.new()
	add_child(sfx)

	var layer := CanvasLayer.new()
	add_child(layer)
	root = Control.new()
	root.size = Vector2(1280, 720)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	theme_ui = _make_theme()
	root.theme = theme_ui
	show_menu()


func tr_ui(key: String):
	return I18n.t(key, ui_lang)


# ---------------- save ----------------
func load_game() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	ui_lang = cf.get_value("settings", "ui_lang", "uk")
	lang = cf.get_value("settings", "lang", "en")
	credits = cf.get_value("progress", "credits", 0)
	stars = cf.get_value("progress", "stars", {})
	learned = cf.get_value("progress", "learned", {})
	upgrades = cf.get_value("progress", "upgrades", [])
	system_done_shown = cf.get_value("progress", "system_done_shown", {})


func save_game() -> void:
	var cf := ConfigFile.new()
	cf.set_value("settings", "ui_lang", ui_lang)
	cf.set_value("settings", "lang", lang)
	cf.set_value("progress", "credits", credits)
	cf.set_value("progress", "stars", stars)
	cf.set_value("progress", "learned", learned)
	cf.set_value("progress", "upgrades", upgrades)
	cf.set_value("progress", "system_done_shown", system_done_shown)
	cf.save(SAVE_PATH)


func stars_for(planet_id: String) -> int:
	return stars.get(lang, {}).get(planet_id, 0)


func learned_list() -> Array:
	if not learned.has(lang):
		learned[lang] = []
	return learned[lang]


# ---------------- speech ----------------
func speak(text: String) -> void:
	art.talking = clampf(text.length() * 0.07, 0.8, 3.0)
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	var voices := DisplayServer.tts_get_voices_for_language(lang)
	var voice: String = voices[0] if voices.size() > 0 else ""
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, voice, 80, 1.0, 0.9)


# ---------------- UI helpers ----------------
func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	var normal := _box(Color("#1c2340"), GREEN, 14, 2)
	var hover := _box(Color("#26305a"), GREEN, 14, 2)
	var pressed := _box(GREEN.darkened(0.4), GREEN, 14, 2)
	var disabled := _box(Color("#151a2c"), Color("#3a4260"), 14, 2)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.75))
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.04, 0.05, 0.13, 0.9), Color(GREEN, 0.6), 18, 2))
	t.set_color("font_color", "Label", Color.WHITE)
	return t


func _box(bg: Color, border: Color, radius: int, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.anti_aliasing = true
	return sb


func _clear_ui() -> void:
	for c in root.get_children():
		c.queue_free()
	_w.clear()


func _label(text: String, size := 24, color := Color.WHITE, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String, cb: Callable, size := 24) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func():
		sfx.play("paddle")
		cb.call())
	return b


func _panel(rect: Rect2) -> VBoxContainer:
	var p := PanelContainer.new()
	p.position = rect.position
	p.size = rect.size
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	return v


func _mark_selected(b: Button, on: bool) -> void:
	if on:
		var sb := _box(GREEN.darkened(0.35), GREEN, 14, 3)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
	else:
		b.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))


func _place_heroine(pos: Vector2, s: float, visible := true) -> void:
	heroine_holder.visible = visible
	heroine_holder.position = pos
	heroine_holder.scale = Vector2(s, s)


func _stars_text(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(3 - n)


# ---------------- menu ----------------
func show_menu() -> void:
	_clear_ui()
	art.mode = "menu"
	_place_heroine(Vector2(0, 0), 1, false)
	var title := _label("LINGUA RANGERS", 72, GOLD)
	title.position = Vector2(80, 60)
	root.add_child(title)
	var sub := _label(tr_ui("subtitle") + " · NevelskyiArt", 26, Color("#c8f4ff"))
	sub.position = Vector2(86, 150)
	root.add_child(sub)

	var v := _panel(Rect2(80, 230, 520, 400))
	v.add_child(_label(tr_ui("ui_lang"), 22, Color("#9fb4ff")))
	var h1 := HBoxContainer.new()
	h1.add_theme_constant_override("separation", 12)
	v.add_child(h1)
	for code in [["uk", "Українська"], ["ru", "Русский"]]:
		var b := _button(code[1], func():
			ui_lang = code[0]
			save_game()
			show_menu())
		_mark_selected(b, ui_lang == code[0])
		h1.add_child(b)
	v.add_child(_label(tr_ui("learn_lang"), 22, Color("#9fb4ff")))
	var h2 := HBoxContainer.new()
	h2.add_theme_constant_override("separation", 12)
	v.add_child(h2)
	for code in Content.TARGET_LANGS:
		var b := _button(LANG_NAMES[code], func():
			lang = code
			save_game()
			show_menu())
		_mark_selected(b, lang == code)
		h2.add_child(b)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	v.add_child(spacer)
	var start := _button(tr_ui("start") + "  ▸", show_map, 32)
	start.custom_minimum_size = Vector2(0, 70)
	v.add_child(start)


# ---------------- star map ----------------
func show_map(tip := "") -> void:
	_clear_ui()
	art.mode = "map"
	_place_heroine(Vector2(90, 620), 0.5)
	heroine.idle()

	var bar := HBoxContainer.new()
	bar.position = Vector2(20, 14)
	bar.size = Vector2(1240, 56)
	bar.add_theme_constant_override("separation", 14)
	root.add_child(bar)
	bar.add_child(_label("%s: %d" % [tr_ui("credits"), credits], 26, GOLD))
	var badge := _label("  " + LANG_NAMES[lang], 26, Color("#c8f4ff"))
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(badge)
	bar.add_child(_button(tr_ui("hangar"), show_hangar))
	bar.add_child(_button(tr_ui("journal"), show_journal))
	bar.add_child(_button(tr_ui("menu"), show_menu))

	for i in planets.size():
		var p: Dictionary = planets[i]
		var c: Vector2 = art.PLANET_POS[i]
		var r: float = art.PLANET_R[i]
		var hit := Button.new()
		hit.flat = true
		hit.position = c - Vector2(r + 20, r + 20)
		hit.size = Vector2(r * 2 + 40, r * 2 + 40)
		hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		hit.pressed.connect(func(): fly_to(i))
		root.add_child(hit)
		var name := _label("%s\n%s  %s" % [p.name[ui_lang], p.topic[ui_lang], _stars_text(stars_for(p.id))], 20, Color.WHITE)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.position = c + Vector2(-110, r + 10)
		name.size = Vector2(220, 60)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(name)

	var all_done := true
	for p in planets:
		if stars_for(p.id) == 0:
			all_done = false
	if tip == "":
		if all_done and not system_done_shown.get(lang, false):
			tip = tr_ui("system_done")
			system_done_shown[lang] = true
			save_game()
			heroine.victory()
		elif credits == 0 and learned_list().is_empty():
			tip = tr_ui("pilot_hi")
		else:
			var tips: Array = tr_ui("pilot_tips")
			tip = tips[randi() % tips.size()] + "  " + tr_ui("tap_planet")
	_pilot_tip(tip)


func _pilot_tip(text: String) -> void:
	var v := _panel(Rect2(180, 620, 640, 80))
	var l := _label(text, 20, Color("#e8f0ff"), true)
	v.add_child(l)
	_w.tip = l


func fly_to(index: int) -> void:
	if _flying:
		return
	_flying = true
	var dest: Vector2 = art.PLANET_POS[index] + Vector2(-art.PLANET_R[index] - 30, 30)
	var speed := 380.0 if upgrades.has("engine") else 240.0
	var encounter_on_way := randf() < 0.45
	if _w.has("tip"):
		_w.tip.text = tr_ui("flying")
	sfx.play("shield")
	var mid: Vector2 = art.ship_pos.lerp(dest, 0.5)
	_tween_ship(mid, speed, func():
		if encounter_on_way:
			var enc: Dictionary = encounters[randi() % encounters.size()]
			_flying = false
			show_encounter(enc, func():
				show_map()
				_flying = true
				_tween_ship(dest, speed, func():
					_flying = false
					show_planet(index)))
		else:
			_tween_ship(dest, speed, func():
				_flying = false
				show_planet(index)))


func _tween_ship(to: Vector2, speed: float, done: Callable) -> void:
	art.ship_moving = true
	art.ship_angle = (to - art.ship_pos).angle() + PI / 2
	var t := create_tween()
	t.tween_property(art, "ship_pos", to, maxf(art.ship_pos.distance_to(to) / speed, 0.2)).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func():
		art.ship_moving = false
		done.call())


# ---------------- dialogs (planets and encounters) ----------------
func show_planet(index: int) -> void:
	var p: Dictionary = planets[index]
	art.mode = "planet"
	art.planet = p
	_start_dialog(p.items, p.npc[ui_lang], p.name[ui_lang], func():
		var s := 3 if _mistakes == 0 else (2 if _mistakes <= 2 else 1)
		var bonus := 20 * s
		credits += bonus
		_earned += bonus
		if not stars.has(lang):
			stars[lang] = {}
		stars[lang][p.id] = maxi(stars_for(p.id), s)
		save_game()
		_show_result(s))


func show_encounter(enc: Dictionary, after: Callable) -> void:
	art.mode = "encounter"
	art.encounter = enc
	_start_dialog(enc.items, enc.name[ui_lang], tr_ui("incoming"), func():
		var msg: String
		if _mistakes == 0:
			credits += enc.reward
			_earned += enc.reward
			msg = "%s +%d" % [tr_ui("encounter_won"), enc.reward]
			heroine.victory()
			sfx.play("win")
		elif enc.has("penalty"):
			credits = maxi(credits - enc.penalty, 0)
			msg = "%s −%d" % [tr_ui("pirate_lost"), enc.penalty]
			heroine.sad()
			sfx.play("lose")
		else:
			credits += enc.reward / 2
			_earned += enc.reward / 2
			msg = "+%d" % (enc.reward / 2)
		save_game()
		_clear_ui()
		var v := _panel(Rect2(PANEL_RECT.position + Vector2(0, 150), Vector2(PANEL_RECT.size.x, 260)))
		var l := _label(msg, 34, GOLD, true)
		v.add_child(l)
		v.add_child(_label("%s: %d" % [tr_ui("credits"), credits], 24))
		var b := _button(tr_ui("next") + "  ▸", after, 28)
		v.add_child(b))


func _start_dialog(items: Array, speaker: String, place: String, on_done: Callable) -> void:
	_queue = items.duplicate()
	_total = items.size()
	_done = 0
	_mistakes = 0
	_shield_used = false
	_earned = 0
	_new_phrases = 0
	_requeued.clear()
	_on_dialog_done = on_done
	_clear_ui()
	_place_heroine(Vector2(90, 620), 0.5)
	heroine.idle()

	var head := _label(place, 22, Color("#9fb4ff"))
	head.position = Vector2(PANEL_RECT.position.x + 6, 26)
	root.add_child(head)
	_w.place = head
	var v := _panel(PANEL_RECT)
	_w.speaker = _label(speaker, 22, GOLD)
	v.add_child(_w.speaker)
	_w.line = _label("", 32, Color.WHITE, true)
	v.add_child(_w.line)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 12)
	v.add_child(tools)
	tools.add_child(_button(tr_ui("listen"), func(): speak(_item.npc[lang])))
	_w.hint_btn = _button("", _show_hint)
	tools.add_child(_w.hint_btn)
	_w.hint = _label("", 22, Color("#c8f4ff"), true)
	v.add_child(_w.hint)
	_w.options = VBoxContainer.new()
	_w.options.add_theme_constant_override("separation", 10)
	v.add_child(_w.options)
	_w.feedback = _label("", 22, Color.WHITE, true)
	v.add_child(_w.feedback)
	_w.next = _button(tr_ui("next") + "  ▸", _next_item, 26)
	v.add_child(_w.next)
	_next_item()


func _next_item() -> void:
	if _queue.is_empty():
		_on_dialog_done.call()
		return
	_item = _queue.pop_front()
	_w.speaker.text = "%s   %d/%d" % [_w.speaker.text.split("   ")[0], _done + 1, _total]
	_w.line.text = _item.npc[lang]
	_w.hint.text = ""
	_w.hint_btn.text = tr_ui("hint") if upgrades.has("translator") else tr_ui("hint_cost")
	_w.hint_btn.disabled = false
	_w.feedback.text = ""
	_w.next.visible = false
	for c in _w.options.get_children():
		_w.options.remove_child(c)
		c.queue_free()
	var opts: Array = _item.options.duplicate()
	var correct: Dictionary = opts[0]
	opts.shuffle()
	for o in opts:
		var b := _button(o[lang], func(): _answer(o == correct, correct), 24)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.set_meta("correct", o == correct)
		_w.options.add_child(b)
	speak(_item.npc[lang])


func _show_hint() -> void:
	if not upgrades.has("translator"):
		if credits < 5:
			_w.hint.text = tr_ui("not_enough")
			return
		credits -= 5
		save_game()
	_w.hint.text = _item.tr[ui_lang]
	_w.hint_btn.disabled = true


func _answer(ok: bool, correct: Dictionary) -> void:
	for b in _w.options.get_children():
		b.disabled = true
		if b.get_meta("correct"):
			b.add_theme_stylebox_override("disabled", _box(GREEN.darkened(0.5), GREEN, 14, 3))
	if ok:
		_done += 1
		credits += 10
		_earned += 10
		var ids := learned_list()
		if not ids.has(_item.id):
			ids.append(_item.id)
			_new_phrases += 1
		_w.feedback.text = "%s  %s\n(%s)" % [tr_ui("correct"), correct[lang], _item.ans_tr[ui_lang]]
		_w.feedback.add_theme_color_override("font_color", GREEN)
		heroine.cheer()
		sfx.play("bonus")
		var good: Array = tr_ui("pilot_good")
		_w.place.text = good[randi() % good.size()]
	else:
		if upgrades.has("shield") and not _shield_used:
			_shield_used = true
			_w.place.text = tr_ui("shield_saved")
		else:
			_mistakes += 1
			var bad: Array = tr_ui("pilot_bad")
			_w.place.text = bad[randi() % bad.size()]
		# a missed phrase comes back once at the end of the mission
		if not _requeued.has(_item.id):
			_requeued[_item.id] = true
			_queue.append(_item)
			_total += 1
		_done += 1
		_w.feedback.text = "%s %s %s\n(%s)\n%s" % [tr_ui("wrong"), tr_ui("right_answer"), correct[lang], _item.ans_tr[ui_lang], _item.explain[ui_lang]]
		_w.feedback.add_theme_color_override("font_color", Color("#ffb3c0"))
		heroine.sad()
		sfx.play("hit")
	speak(correct[lang])
	_w.next.visible = true
	save_game()


func _show_result(s: int) -> void:
	_clear_ui()
	if s == 3:
		heroine.victory()
	else:
		heroine.cheer()
	sfx.play("win")
	var v := _panel(Rect2(PANEL_RECT.position + Vector2(0, 60), Vector2(PANEL_RECT.size.x, 420)))
	v.add_child(_label(tr_ui("mission_done"), 40, GOLD))
	v.add_child(_label(_stars_text(s), 64, GOLD))
	v.add_child(_label("%s: %d" % [tr_ui("mistakes"), _mistakes], 24))
	v.add_child(_label("%s: +%d" % [tr_ui("earned"), _earned], 24, GREEN))
	v.add_child(_label("%s: %d" % [tr_ui("new_phrases"), _new_phrases], 24, Color("#c8f4ff")))
	v.add_child(_button(tr_ui("to_map") + "  ▸", func(): show_map(), 28))


# ---------------- hangar & journal ----------------
func show_hangar() -> void:
	_clear_ui()
	art.mode = "map"
	_place_heroine(Vector2(90, 620), 0.5)
	var v := _panel(Rect2(300, 70, 760, 560))
	v.add_child(_label("%s · %s: %d" % [tr_ui("hangar"), tr_ui("credits"), credits], 30, GOLD))
	for key in UPGRADES.keys():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		v.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_label(tr_ui("upg_" + key), 26, Color.WHITE))
		info.add_child(_label(tr_ui("upg_%s_d" % key), 20, Color("#9fb4ff"), true))
		row.add_child(info)
		if upgrades.has(key):
			row.add_child(_label(tr_ui("owned"), 22, GREEN))
		else:
			var b := _button("%s  %d" % [tr_ui("buy"), UPGRADES[key]], func():
				if credits >= UPGRADES[key]:
					credits -= UPGRADES[key]
					upgrades.append(key)
					save_game()
					sfx.play("shield")
					heroine.cheer()
				show_hangar())
			b.disabled = credits < UPGRADES[key]
			row.add_child(b)
	v.add_child(_button(tr_ui("to_map"), func(): show_map()))


func show_journal() -> void:
	_clear_ui()
	art.mode = "map"
	_place_heroine(Vector2(90, 620), 0.5)
	var v := _panel(Rect2(240, 60, 900, 620))
	v.add_child(_label("%s · %s" % [tr_ui("journal"), LANG_NAMES[lang]], 30, GOLD))
	var ids := learned_list()
	if ids.is_empty():
		v.add_child(_label(tr_ui("journal_empty"), 22, Color("#c8f4ff"), true))
	else:
		v.add_child(_label(tr_ui("journal_tip"), 18, Color("#9fb4ff")))
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 440)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		v.add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		for group in [planets, encounters]:
			for g in group:
				for it in g.items:
					if ids.has(it.id):
						var phrase: String = it.options[0][lang]
						var b := _button("%s   —   %s" % [phrase, it.ans_tr[ui_lang]], func(): speak(phrase), 20)
						b.alignment = HORIZONTAL_ALIGNMENT_LEFT
						list.add_child(b)
	v.add_child(_button(tr_ui("to_map"), func(): show_map()))
