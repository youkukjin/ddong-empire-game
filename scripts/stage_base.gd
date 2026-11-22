extends Node2D
## 2장부터 모든 장이 함께 쓰는 스테이지 뼈대예요.
## 이야기 장면, 화면 위 표시, 멈추기, 결과 창, 다음 장으로 가기를 맡아요.
## 각 장은 이 파일을 extends 하고 아래 "장마다 채우는 곳" 함수만 채우면 돼요.
##
## 흐름: 이야기 장면(INTRO) → 플레이(PLAY) → 끝 연출(OUTRO) → 결과(RESULT)

const Session := preload("res://scripts/game_session.gd")
const Save := preload("res://scripts/save_data.gd")
const Chapters := preload("res://scripts/chapters.gd")
const TITLE_SCENE := "res://scenes/title/title_screen.tscn"

const CREAM := Color(0.996, 0.949, 0.851)
const BROWN := Color(0.4, 0.239, 0.11)
const BUTTON_BROWN := Color(0.71, 0.482, 0.278)

enum Phase { INTRO, PLAY, OUTRO, RESULT }

var chapter := 0                 # 몇 장인지 (각 장의 _init에서 정해요)
var phase := Phase.INTRO
var paused := false
var rng := RandomNumberGenerator.new()

var world: Node2D
var hud_root: Control
var overlay_root: Control
var pause_button: Button

var _pages: Array = []
var _page_index := 0
var _pages_done: Callable


func _ready() -> void:
	rng.randomize()
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	hud_root = _full_control()
	hud.add_child(hud_root)
	var overlay := CanvasLayer.new()
	overlay.name = "Overlay"
	overlay.layer = 2
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	overlay_root = _full_control()
	overlay.add_child(overlay_root)
	_setup()
	pause_button = make_button("II", Vector2(84, 76), 36)
	pause_button.position = Vector2(1186, 10)
	pause_button.pressed.connect(toggle_pause)
	hud_root.add_child(pause_button)
	_refresh_pause_button()
	show_pages(_intro_pages(), start_play)


# ------------------------------------------------------------------ 장마다 채우는 곳

## 처음 한 번: 배경, 인물, 화면 위 표시를 만들어요.
func _setup() -> void:
	pass


## 시작 전 이야기 장면 글이에요. 마지막 장은 보통 "어떻게 할까요?" 설명이에요.
func _intro_pages() -> Array:
	return []


## 플레이가 시작되는 순간이에요.
func _on_play_started() -> void:
	pass


## 플레이 중 매 프레임 (멈춤 중에는 불리지 않아요).
func _play_process(_delta: float) -> void:
	pass


## 플레이 중 터치 입력이에요.
func _play_input(_event: InputEvent) -> void:
	pass


## 이긴 뒤 "다음 이야기"를 누르면 보여줄 장면 글이에요.
func _outro_pages() -> Array:
	return []


## 다시 하기 직전에 부르는 곳 (필요한 장만 채워요).
func _before_restart() -> void:
	pass


# ------------------------------------------------------------------ 진행

func start_play() -> void:
	phase = Phase.PLAY
	clear_overlay()
	_refresh_pause_button()
	_on_play_started()


func _process(delta: float) -> void:
	if phase == Phase.PLAY and not paused:
		_play_process(delta)


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.PLAY and not paused:
		_play_input(event)


## 이겼어요: 기록을 남기고 결과 창을 보여줘요.
## lines: 결과 창에 보여줄 줄 (예: "걸린 시간 1:20")
func finish_win(stars: int, title: String, lines: String) -> void:
	phase = Phase.RESULT
	_refresh_pause_button()
	var unlocked: Dictionary = Save.record_chapter_win(chapter, stars)
	Session.fail_streak = 0
	var body := lines
	if unlocked.get("next_new", false) and chapter < Chapters.COUNT:
		body += "\n\n%d장 '%s'이(가) 열렸어요!" % [chapter + 1, Chapters.title(chapter + 1)]
	var star_widget: Control = null
	if stars > 0:
		star_widget = StarRow.new()
		star_widget.custom_minimum_size = Vector2(360, 110)
		star_widget.stars = stars
	show_panel(title, body, [
		["다음 이야기", show_outro],
		["다시 하기", restart],
		["처음으로", go_title],
	], star_widget)


## 졌어요: 이유와 팁을 보여주고 다시 하게 해요.
func finish_fail(reason: String, tip: String, extra_buttons: Array = []) -> void:
	phase = Phase.RESULT
	_refresh_pause_button()
	Session.fail_streak += 1
	var buttons: Array = [["다시 하기", restart]]
	buttons.append_array(extra_buttons)
	buttons.append(["처음으로", go_title])
	show_panel("아쉬워요!", "%s\n\n팁: %s" % [reason, tip], buttons)


func show_outro() -> void:
	var pages := _outro_pages()
	if pages.is_empty():
		go_next_chapter()
	else:
		show_pages(pages, go_next_chapter)


func go_next_chapter() -> void:
	if chapter >= Chapters.COUNT or not Chapters.is_built(chapter + 1):
		go_title()
	else:
		change_scene(Chapters.scene(chapter + 1))


func restart() -> void:
	_before_restart()
	change_scene(scene_file_path)


func go_title() -> void:
	change_scene(TITLE_SCENE)


func change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


## 이야기 장면을 모두 건너뛰고 바로 시작해요 (자동 확인용).
func skip_intro() -> void:
	if phase == Phase.INTRO and not _pages.is_empty():
		_page_index = _pages.size() - 1
		next_page()


# ------------------------------------------------------------------ 멈추기

func toggle_pause() -> void:
	if phase != Phase.PLAY or (not paused and not _can_pause()):
		return
	paused = not paused
	get_tree().paused = paused
	if paused:
		_on_paused()
		show_panel("멈춤", "잠깐 쉬어요.", [
			["계속", toggle_pause],
			["다시 하기", restart],
			["처음으로", go_title],
		])
	else:
		clear_overlay()


## 지금 멈출 수 있는지 (연습 사이 안내 창이 떠 있을 때처럼 멈추면 안 되는 때는 false)
func _can_pause() -> bool:
	return true


## 멈출 때 끌던 것들을 놓게 하는 곳이에요.
func _on_paused() -> void:
	pass


## 안드로이드 뒤로 가기: 플레이 중이면 멈추고, 아니면 타이틀로 가요.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if phase == Phase.PLAY:
			toggle_pause()
		else:
			go_title()


func _refresh_pause_button() -> void:
	if pause_button:
		pause_button.visible = phase == Phase.PLAY and _can_pause()


# ------------------------------------------------------------------ 화면 위 표시 도우미

func hud_label(pos: Vector2, font_size: int, color := Color(1, 0.97, 0.88)) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.05))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(l)
	return l


func hud_bar(pos: Vector2, size: Vector2) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color(0, 0, 0, 0.35)
	bar.position = pos
	bar.size = size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bar)
	return bar


func float_text(p: Vector2, text: String, color: Color, font_size := 34) -> void:
	var l := Label.new()
	l.text = text
	l.position = p
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.2))
	l.add_theme_constant_override("outline_size", 8)
	world.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", p.y - 50.0, 1.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


func shake(strength := 8.0) -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(world, "position", Vector2(rng.randf_range(-strength, strength), rng.randf_range(-strength, strength) * 0.75), 0.04)
	tw.tween_property(world, "position", Vector2.ZERO, 0.04)


static func time_text(sec: float) -> String:
	var s := int(ceil(maxf(sec, 0.0)))
	return "%d:%02d" % [s / 60, s % 60]


# ------------------------------------------------------------------ 이야기 장면과 창

## 이야기 장면: 화면을 톡 누르면 다음 장면으로 넘어가요. 다 보면 done을 불러요.
func show_pages(pages: Array, done: Callable) -> void:
	_pages = pages
	_page_index = 0
	_pages_done = done
	if _pages.is_empty():
		done.call()
	else:
		_show_page()


func _show_page() -> void:
	clear_overlay()
	var page := Button.new()
	page.name = "StoryPage"
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.focus_mode = Control.FOCUS_NONE
	page.pressed.connect(next_page)
	var bg := StyleBoxFlat.new()
	bg.bg_color = CREAM
	for s in ["normal", "hover", "pressed", "focus"]:
		page.add_theme_stylebox_override(s, bg)
	overlay_root.add_child(page)

	var body: String = _pages[_page_index]
	var text := Label.new()
	text.text = body
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 110
	text.offset_right = -110
	text.offset_bottom = -90
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 30 if body.length() > 80 else 42)
	text.add_theme_color_override("font_color", BROWN)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(text)

	var hint := Label.new()
	var last := _page_index == _pages.size() - 1
	hint.text = "화면을 톡 누르면 %s (%d/%d)" % ["시작해요" if last and phase == Phase.INTRO else "넘어가요", _page_index + 1, _pages.size()]
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -80
	hint.offset_bottom = -30
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", Color(BROWN, 0.7))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(hint)


func next_page() -> void:
	_page_index += 1
	if _page_index >= _pages.size():
		_pages = []
		clear_overlay()
		_pages_done.call()
	else:
		_show_page()


func show_panel(title: String, body: String, buttons: Array, extra: Control = null) -> void:
	clear_overlay()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_root.add_child(dim)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.set_corner_radius_all(36)
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(820, 0)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 48)
	t.add_theme_color_override("font_color", BROWN)
	box.add_child(t)
	if extra:
		extra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(extra)
	if body != "":
		var b := Label.new()
		b.text = body
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(756, 0)
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_color_override("font_color", BROWN)
		box.add_child(b)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for entry in buttons:
		var btn := make_button(entry[0], Vector2(170, 72), 26)
		btn.name = "Btn_" + String(entry[0]).replace(" ", "_")
		btn.pressed.connect(entry[1])
		row.add_child(btn)


func clear_overlay() -> void:
	for c in overlay_root.get_children():
		overlay_root.remove_child(c)
		c.queue_free()


## 지금 떠 있는 창의 버튼을 이름으로 찾아요 (자동 확인용).
func find_overlay_button(text: String) -> Button:
	return overlay_root.find_child("Btn_" + text.replace(" ", "_"), true, false) as Button


func make_button(text: String, min_size: Vector2, font_size: int, color := BUTTON_BROWN) -> Button:
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
	normal.set_content_margin_all(8)
	var pressed := normal.duplicate()
	pressed.bg_color = color.darkened(0.2)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.6, 0.56, 0.5)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	return btn


func _full_control() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## 결과 창의 별 줄이에요.
class StarRow extends Control:
	var stars := 0

	func _draw() -> void:
		for i in 3:
			var c := Vector2(size.x / 2.0 + (i - 1) * 110, size.y / 2.0)
			var pts := PackedVector2Array()
			for k in 10:
				var a := -PI / 2.0 + k * PI / 5.0
				var rr := 46.0 if k % 2 == 0 else 46.0 * 0.45
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, Color(1, 0.82, 0.2) if i < stars else Color(0.75, 0.7, 0.62))
			pts.append(pts[0])
			draw_polyline(pts, Color(0.4, 0.24, 0.11), 3.0)
