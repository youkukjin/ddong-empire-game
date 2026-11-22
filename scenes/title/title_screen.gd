extends Control
## 타이틀 화면: 게임 제목과 시작 버튼을 보여줘요.
## 시작 버튼을 누르면 게임 화면(지금은 준비 중 화면)으로 넘어가요.

const GAME_SCENE := "res://scenes/game/game_placeholder.tscn"

@onready var start_button: Button = %StartButton
@onready var title_label: Label = %TitleLabel


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	start_button.grab_focus()
	_play_title_bounce()


func _on_start_pressed() -> void:
	start_button.disabled = true
	get_tree().change_scene_to_file(GAME_SCENE)


## 제목이 살짝 통통 튀는 효과예요. 어린이가 보기 좋게 천천히 움직여요.
func _play_title_bounce() -> void:
	title_label.pivot_offset = title_label.size / 2.0
	var tween := create_tween().set_loops()
	tween.tween_property(title_label, "scale", Vector2(1.05, 1.05), 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title_label, "scale", Vector2.ONE, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
