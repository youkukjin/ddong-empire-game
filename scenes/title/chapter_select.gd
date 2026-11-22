extends Control
## 장 고르기: 열린 장을 골라서 바로 할 수 있어요. 깬 장에는 최고 별이 보여요.

const Save := preload("res://scripts/save_data.gd")
const Session := preload("res://scripts/game_session.gd")
const Chapters := preload("res://scripts/chapters.gd")
const TITLE_SCENE := "res://scenes/title/title_screen.tscn"
const CREAM := Color(0.996, 0.949, 0.851)
const BROWN := Color(0.4, 0.239, 0.11)
const BUTTON_BROWN := Color(0.71, 0.482, 0.278)


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = "장 고르기"
	title.position = Vector2(0, 30)
	title.size = Vector2(1280, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", BROWN)
	add_child(title)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(70, 130)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	add_child(grid)
	for n in range(1, Chapters.COUNT + 1):
		grid.add_child(_chapter_button(n))
	var back := _button("← 처음으로", Vector2(260, 76), 30, BUTTON_BROWN)
	back.name = "Btn_처음으로"
	back.position = Vector2(510, 610)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))
	add_child(back)


func _chapter_button(n: int) -> Button:
	var open := Save.is_unlocked(n) and Chapters.is_built(n)
	var stars := Save.best_stars(n)
	var text := "%d장\n%s\n" % [n, Chapters.title(n)]
	if not Chapters.is_built(n):
		text += "만드는 중"
	elif not Save.is_unlocked(n):
		text += "잠김"
	else:
		text += "★".repeat(stars) + "☆".repeat(3 - stars)
	var b := _button(text, Vector2(270, 200), 30, BUTTON_BROWN if open else Color(0.62, 0.57, 0.5))
	b.name = "Chapter%d" % n
	b.disabled = not open
	b.pressed.connect(_open.bind(n))
	return b


func _open(n: int) -> void:
	Session.hard_mode = false
	Session.clear_checkpoint()
	get_tree().change_scene_to_file(Chapters.scene(n))


func _button(text: String, min_size: Vector2, font_size: int, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", font_size)
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		btn.add_theme_color_override(s, Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(26)
	var pressed := normal.duplicate()
	pressed.bg_color = color.darkened(0.2)
	for s in ["normal", "hover", "disabled"]:
		btn.add_theme_stylebox_override(s, normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	return btn
