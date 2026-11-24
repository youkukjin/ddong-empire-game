extends Control
## 타이틀 화면: 게임 제목과 시작 버튼을 보여줘요.
## 시작하기를 누르면 1장 '등장' 스테이지로 가요.
## 1장을 별 3개로 깨면 "어려움 모드" 버튼이 나타나요.
## "장 고르기"를 누르면 열린 장을 골라서 할 수 있어요.
## 배경의 구름·언덕·손 흔드는 똥 왕자는 귀여운 디자인 (제안)이에요.

const STAGE_SCENE := "res://scenes/chapter1/stage1.tscn"
const SELECT_SCENE := "res://scenes/title/chapter_select.tscn"
const Session := preload("res://scripts/game_session.gd")
const Save := preload("res://scripts/save_data.gd")
const Cute := preload("res://scripts/art/cute.gd")
const Prince := preload("res://scripts/art/prince.gd")

@onready var start_button: Button = %StartButton
@onready var hard_button: Button = %HardButton
@onready var select_button: Button = %SelectButton
@onready var title_label: Label = %TitleLabel


func _ready() -> void:
	var art := TitleArt.new()
	add_child(art)
	move_child(art, 1)
	var prince := Prince.new()
	prince.position = Vector2(215, 640)
	prince.scale = Vector2(1.5, 1.5)
	prince.show_chain = false
	prince.pose = Prince.Pose.CHEER
	art.add_child(prince)
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


## 하늘, 구름, 언덕, 떠다니는 하트와 반짝이를 그려요.
class TitleArt extends Control:
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var w := 1280.0
		for i in 12:
			draw_rect(Rect2(0, i * 60, w, 61), Color(0.75, 0.88, 1.0).lerp(Cute.CREAM, i / 11.0))
		for c in [[Vector2(180, 110), 70.0], [Vector2(1080, 150), 90.0], [Vector2(640, 60), 50.0]]:
			var drift := sin(_t * 0.5 + c[0].x) * 14.0
			Cute.cloud(self, c[0] + Vector2(drift, 0), c[1])
		# 언덕
		draw_circle(Vector2(160, 980), 420, Cute.MINT.lightened(0.25))
		draw_circle(Vector2(1120, 1000), 460, Cute.MINT.lightened(0.15))
		draw_circle(Vector2(640, 1120), 520, Cute.MINT.lightened(0.35))
		# 작은 꽃
		for i in 9:
			var p := Vector2(80 + i * 140, 690 - (i % 3) * 18)
			for k in 5:
				var a := TAU * k / 5.0
				draw_circle(p + Vector2(cos(a), sin(a)) * 7, 6, [Cute.PINK, Cute.LEMON, Color.WHITE][i % 3])
			draw_circle(p, 5, Cute.PEACH if i % 3 != 1 else Cute.PINK)
		# 떠다니는 하트와 반짝이
		for i in 6:
			var x := 980.0 + (i % 3) * 90.0
			var y := 640.0 - fmod(_t * 40.0 + i * 70.0, 420.0)
			Cute.heart(self, Vector2(x + sin(_t * 2 + i) * 10, y), 14.0, Color(Cute.PINK, 0.8))
		for i in 5:
			var p := Vector2(330 + i * 160, 200 + (i % 2) * 330)
			Cute.sparkle(self, p, 10 + 6 * absf(sin(_t * 2.5 + i)), Color(1, 0.95, 0.6))
