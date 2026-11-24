extends Control
## 타이틀 화면: 게임 제목과 시작 버튼을 보여줘요.
## 시작하기를 누르면 1장 '등장' 스테이지로 가요.
## 1장을 별 3개로 깨면 "어려움 모드" 버튼이 나타나요.
## "장 고르기"를 누르면 열린 장을 골라서 할 수 있어요.
## 배경은 3D 무대예요 (제안): 언덕, 구름, 똥 마을, 손 흔드는 3D 똥 왕자.

const STAGE_SCENE := "res://scenes/chapter1/stage1.tscn"
const SELECT_SCENE := "res://scenes/title/chapter_select.tscn"
const Session := preload("res://scripts/game_session.gd")
const Save := preload("res://scripts/save_data.gd")
const Cute := preload("res://scripts/art/cute.gd")
const StageView := preload("res://scripts/view3d/stage_view.gd")
const Prince3D := preload("res://scripts/view3d/prince_3d.gd")
const Kit := preload("res://scripts/view3d/kit3d.gd")

@onready var start_button: Button = %StartButton
@onready var hard_button: Button = %HardButton
@onready var select_button: Button = %SelectButton
@onready var title_label: Label = %TitleLabel


func _ready() -> void:
	if StageView.can_show():
		$Background.visible = false
		_build_3d()
	Cute.style_button(start_button, Cute.PINK)
	Cute.style_button(hard_button, Cute.LILAC)
	Cute.style_button(select_button, Cute.MINT)
	start_button.pressed.connect(_on_start_pressed.bind(false))
	hard_button.pressed.connect(_on_start_pressed.bind(true))
	hard_button.visible = Save.hard_unlocked()
	select_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(SELECT_SCENE))
	start_button.grab_focus()
	_play_title_bounce()


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


var _clouds: Array[Node3D] = []
var _t := 0.0


func _build_3d() -> void:
	var view := StageView.new()
	view.name = "View3D"
	view.cam_height = 3.2
	view.cam_z = 10.0
	view.pitch_deg = 8.0
	view.fov_deg = 42.0
	add_child(view)
	move_child(view, 0)
	view.setup(Color(0.45, 0.7, 1.0), Color(0.85, 0.92, 1.0), Color(0.7, 0.72, 0.85), Color(1, 0.95, 0.85), 0.95)
	# 언덕 (크게 눌린 공)
	Kit.ground_sphere(view, 30.0, Color(0.5, 0.8, 0.5), Vector3(0, -29.6, -4), Vector3(1.6, 1, 1))
	Kit.ground_sphere(view, 9.0, Color(0.45, 0.74, 0.52), Vector3(-12, -6.5, -12))
	Kit.ground_sphere(view, 11.0, Color(0.55, 0.8, 0.55), Vector3(13, -8.0, -14))
	# 멀리 똥 마을 (제안)
	var roofs := [Color(1, 0.6, 0.68), Color(0.65, 0.55, 0.95), Color(1, 0.72, 0.45)]
	for i in 5:
		var x := -7.0 + i * 3.6
		var z := -9.0 - (i % 2) * 1.5
		Kit.box(view, Vector3(1.4, 1.2, 1.2), Color(1, 0.93, 0.82), Vector3(x, 0.5, z))
		var roof := Kit.prism(view, Vector3(1.7, 0.9, 1.4), roofs[i % 3], Vector3(x, 1.55, z))
		roof.rotation.y = 0.0
		Kit.box(view, Vector3(0.36, 0.36, 0.05), Color(1, 0.85, 0.45), Vector3(x + 0.3, 0.7, z + 0.62), 0.6)
	# 꽃
	for i in 14:
		var p := Vector3(-8.0 + i * 1.25, 0.25, 2.0 - (i % 3) * 1.1)
		var col: Color = [Color(1, 0.55, 0.68), Color(1, 0.85, 0.35), Color.WHITE][i % 3]
		Kit.cylinder(view, 0.02, 0.02, 0.3, Color(0.35, 0.65, 0.35), p + Vector3(0, -0.12, 0))
		Kit.sphere(view, 0.11, col, p + Vector3(0, 0.05, 0), Vector3(1, 0.5, 1))
		Kit.sphere(view, 0.05, Color(1, 0.7, 0.4), p + Vector3(0, 0.1, 0))
	# 구름
	for c in [Vector3(-7, 5.5, -10), Vector3(6.5, 6.2, -12), Vector3(0.5, 7.2, -16)]:
		var cloud := Node3D.new()
		cloud.position = c
		view.add_child(cloud)
		for k in [Vector3(-0.9, 0, 0), Vector3(0, 0.35, 0), Vector3(0.9, 0.05, 0), Vector3(0.4, -0.1, 0.4)]:
			Kit.sphere(cloud, 0.85, Color(1, 1, 1), k, Vector3(1, 0.8, 0.8))
		_clouds.append(cloud)
	# 손 흔드는 똥 왕자
	var prince := Prince3D.new()
	prince.position = Vector3(-4.6, 0.3, 0.6)
	prince.scale = Vector3.ONE * 0.95
	prince.cheer = true
	view.add_child(prince)
	prince.facing = 1.0


func _process(delta: float) -> void:
	_t += delta
	for i in _clouds.size():
		_clouds[i].position.x += sin(_t * 0.3 + i) * delta * 0.3
