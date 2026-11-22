extends Control
## 게임 화면 자리예요. 1장 '등장' 스테이지가 만들어지면 이 화면을 바꿀 거예요.

const TITLE_SCENE := "res://scenes/title/title_screen.tscn"

@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(_go_back)


## 안드로이드 뒤로 가기 버튼을 눌러도 타이틀로 돌아가요.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
