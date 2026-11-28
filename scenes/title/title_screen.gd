extends Control
## 타이틀 화면: 게임 제목과 시작 버튼을 보여줘요.
## 시작하기를 누르면 1장 '등장' 스테이지로 가요.
## 1장을 별 3개로 깨면 "어려움 모드" 버튼이 나타나요.
## "장 고르기"를 누르면 열린 장을 골라서 할 수 있어요.
## 배경은 3D 무대예요 (제안): 불타는 밤 마을, 거대한 보라색 가시 드래곤, 검을 치켜든 3D 똥 왕자.

const Sound := preload("res://scripts/audio/sound.gd")
const STAGE_SCENE := "res://scenes/chapter1/stage1.tscn"
const SELECT_SCENE := "res://scenes/title/chapter_select.tscn"
const SURVIVOR_LOBBY := "res://scenes/title/chapter_select.tscn"
const SurvivorRules := preload("res://scenes/survivor/survivor_rules.gd")
const Session := preload("res://scripts/game_session.gd")
const Save := preload("res://scripts/save_data.gd")
const Chapters := preload("res://scripts/chapters.gd")
const Cute := preload("res://scripts/art/cute.gd")
const StageView := preload("res://scripts/view3d/stage_view.gd")
const Prince3D := preload("res://scripts/view3d/prince_3d.gd")
const Kit := preload("res://scripts/view3d/kit3d.gd")
const Dragon3D := preload("res://scripts/view3d/dragon_3d.gd")
const ScreenMode := preload("res://scripts/screen_mode.gd")

@onready var start_button: Button = %StartButton
@onready var hard_button: Button = %HardButton
@onready var select_button: Button = %SelectButton
@onready var title_label: Label = %TitleLabel


func _ready() -> void:
	ScreenMode.portrait(get_tree())
	Sound.ensure()
	if StageView.can_show():
		$Background.visible = false
		_build_3d()
	Session.restore()
	_add_mode_buttons()
	Cute.style_button(start_button, Cute.CARAMEL, 32)
	Cute.style_button(hard_button, Cute.LILAC, 32)
	Cute.style_button(select_button, Cute.MINT, 32)
	for b in [start_button, hard_button, select_button]:
		b.custom_minimum_size = Vector2(320, 76)
	start_button.text = "처음부터"
	start_button.visible = Save.has_progress()
	start_button.pressed.connect(_on_start_pressed.bind(false))
	hard_button.pressed.connect(_on_start_pressed.bind(true))
	hard_button.visible = Save.hard_unlocked()
	select_button.text = "장 고르기"
	select_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(SELECT_SCENE))
	_play_title_bounce()


var story_button: Button = null
var survivor_button: Button = null


## 처음 화면에서 바로 고르는 두 모드 (2026-11-28 사용자: "여기서 바로 스토리 모드와 서바이버 모드").
## 스토리 모드는 이어할 장부터, 서바이버 모드는 무대·캐릭터를 고르는 곳으로 가요.
func _add_mode_buttons() -> void:
	var parent := start_button.get_parent()
	var n := Save.continue_chapter(Chapters.COUNT) if Save.has_progress() else 1
	var sub := "%d장부터 이어하기" % n if Save.has_progress() else "1장부터 시작"
	story_button = Cute.button("스토리 모드\n" + sub, Vector2(540, 160), 42, Cute.PINK)
	story_button.name = "StoryButton"
	story_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(story_button)
	parent.move_child(story_button, start_button.get_index())
	story_button.pressed.connect(_on_story_pressed.bind(n))
	survivor_button = Cute.button("서바이버 모드\n" + SurvivorRules.STAGES[Save.survivor_stage()].name, Vector2(540, 160), 42, Color(1, 0.72, 0.25))
	survivor_button.name = "SurvivorButton"
	survivor_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(survivor_button)
	parent.move_child(survivor_button, start_button.get_index())
	survivor_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(SURVIVOR_LOBBY))


func _on_story_pressed(n: int) -> void:
	story_button.disabled = true
	if not Save.has_progress():
		_on_start_pressed(false)
		return
	Session.hard_mode = false
	# 1장은 중간 저장이 있으면 거기서부터 (5·6장 중간 저장은 그 장이 알아서 불러요)
	Session.resume_checkpoint = n == 1 and Session.has_checkpoint
	get_tree().change_scene_to_file(Chapters.scene(n))


func _on_start_pressed(hard: bool) -> void:
	start_button.disabled = true
	hard_button.disabled = true
	Session.hard_mode = hard
	Session.clear_checkpoint()
	get_tree().change_scene_to_file(STAGE_SCENE)


## 제목이 살짝 통통 튀는 효과예요. 보기 좋게 천천히 움직여요.
func _play_title_bounce() -> void:
	title_label.pivot_offset = title_label.size / 2.0
	var tween := create_tween().set_loops()
	tween.tween_property(title_label, "scale", Vector2(1.05, 1.05), 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title_label, "scale", Vector2.ONE, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


var _t := 0.0


func _build_3d() -> void:
	# 박력 있는 타이틀 (제안): 원작 표지처럼 밤 마을에 보라색 가시 드래곤이 나타나고,
	# 똥 왕자가 검을 치켜들고 맞서요.
	var view := StageView.new()
	view.name = "View3D"
	view.cam_height = 3.2
	view.cam_z = 10.0
	view.pitch_deg = 6.0
	view.fov_deg = 44.0
	add_child(view)
	move_child(view, 0)
	view.setup(Color(0.02, 0.01, 0.08), Color(0.45, 0.08, 0.15), Color(0.45, 0.4, 0.7), Color(0.75, 0.75, 1.0), 0.8)
	# 땅과 검은 도로 (원작 표지: 차선 있는 도로)
	Kit.box(view, Vector3(80, 1, 60), Color(0.14, 0.16, 0.16), Vector3(0, -0.5, -20)).material_override = Kit.matte(Color(0.14, 0.16, 0.16))
	Kit.box(view, Vector3(80, 0.04, 3.0), Color(0.06, 0.05, 0.08), Vector3(0, 0.02, 1.0)).material_override = Kit.matte(Color(0.06, 0.05, 0.08))
	var x := -20.0
	while x < 20.0:
		Kit.box(view, Vector3(1.1, 0.05, 0.18), Color(1, 0.85, 0.3), Vector3(x, 0.05, 1.0), 0.3, false)
		x += 2.2
	# 붉은 달과 별
	Kit.sphere(view, 2.2, Color(0.9, 0.15, 0.1), Vector3(-9, 9.5, -30), Vector3.ONE, 1.2, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 50:
		Kit.sphere(view, rng.randf_range(0.04, 0.1), Color(1, 1, 0.85), Vector3(rng.randf_range(-30, 30), rng.randf_range(4, 16), -31), Vector3.ONE, 2.0, false)
	# 불타는 마을 (원작 그림: 드래곤이 마을에 불을 냄)
	for i in 7:
		var hx := -11.0 + i * 3.6
		var hz := -7.0 - (i % 2) * 1.6
		Kit.box(view, Vector3(1.6, 1.4, 1.3), Color(0.35, 0.3, 0.42), Vector3(hx, 0.7, hz))
		Kit.prism(view, Vector3(1.9, 1.0, 1.5), Color(0.5, 0.12, 0.15), Vector3(hx, 1.9, hz))
		Kit.box(view, Vector3(0.4, 0.4, 0.05), Color(1, 0.7, 0.3), Vector3(hx + 0.35, 0.8, hz + 0.67), 2.0, false)
		if i % 2 == 0:
			var fire := Node3D.new()
			fire.position = Vector3(hx - 0.3, 2.3, hz)
			view.add_child(fire)
			for j in 3:
				Kit.spike(fire, 0.4 - j * 0.08, 1.3 - j * 0.3, Color(1, 0.3 + j * 0.2, 0.05), Vector3((j - 1) * 0.3, -0.3, j * 0.1), Vector3((j - 1) * 0.2, 1, 0), false).material_override = Kit.mat(Color(1, 0.3 + j * 0.2, 0.05), 2.5)
			Kit.light(fire, Vector3(0, 0.5, 1.0), Color(1, 0.5, 0.15), 2.5, 6.0)
			_flames.append(fire)
	# 거대한 똥 드래곤 (원작: 보라색, 가시 머리, 날카로운 이빨)
	var dragon := Dragon3D.new()
	dragon.position = Vector3(7.8, 0.0, -4.0)
	dragon.scale = Vector3.ONE * 2.0
	view.add_child(dragon)
	dragon.facing = -1.0
	dragon.mouth_open = 0.9
	dragon.angry = 0.3
	dragon.wings_up = true
	dragon.head_target = Vector3(1.7, 2.6, 0)
	_dragon = dragon
	# 검을 치켜든 똥 왕자
	var prince := Prince3D.new()
	prince.position = Vector3(-4.3, 0.1, 1.6)
	prince.scale = Vector3.ONE * 1.15
	prince.cheer = true
	view.add_child(prince)
	prince.facing = 1.0
	_view = view
	# 제목 글자도 박력 있게: 주황빛 글자에 굵은 검은 테두리
	var ls: LabelSettings = title_label.label_settings.duplicate()
	ls.font_color = Color(1, 0.72, 0.15)
	ls.outline_color = Kit.INK
	ls.outline_size = 28
	ls.shadow_color = Color(0.8, 0.08, 0.05, 0.95)
	ls.shadow_size = 4
	ls.shadow_offset = Vector2(6, 10)
	title_label.label_settings = ls


var _flames: Array[Node3D] = []
var _dragon: Node3D
var _view: Node3D
var _roar := 3.0


func _process(delta: float) -> void:
	_t += delta
	for i in _flames.size():
		_flames[i].scale = Vector3(1, 1.0 + sin(_t * 9.0 + i) * 0.12, 1)
	# 가끔 드래곤이 크게 울부짖어요 (화면이 흔들려요)
	if _dragon:
		_roar -= delta
		_dragon.mouth_open = 0.6 + 0.4 * absf(sin(_t * 1.5))
		if _roar <= 0.0:
			_roar = 4.0
			_view.shake(0.08, 0.4)
