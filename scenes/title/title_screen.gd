extends Control
## 타이틀 화면: 게임 제목과 시작 버튼을 보여줘요.
## 시작하기를 누르면 1장 '등장' 스테이지로 가요.
## 1장을 별 3개로 깨면 "어려움 모드" 버튼이 나타나요.

const STAGE_SCENE := "res://scenes/chapter1/stage1.tscn"
const Session := preload("res://scripts/game_session.gd")
const Save := preload("res://scripts/save_data.gd")

@onready var start_button: Button = %StartButton
@onready var hard_button: Button = %HardButton
@onready var title_label: Label = %TitleLabel


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed.bind(false))
	hard_button.pressed.connect(_on_start_pressed.bind(true))
	hard_button.visible = Save.hard_unlocked()
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
