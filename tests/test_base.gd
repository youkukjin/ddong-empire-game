extends SceneTree
## 자동 확인 파일들이 함께 쓰는 도우미예요.

const Save := preload("res://scripts/save_data.gd")
const Session := preload("res://scripts/game_session.gd")

var _failed := 0


func _initialize() -> void:
	Save.path = "user://test_save.cfg"
	DirAccess.remove_absolute(Save.path)
	_main.call_deferred()


func _main() -> void:
	await _run()
	DirAccess.remove_absolute(Save.path)
	if _failed == 0:
		print("모든 확인 통과")
		quit(0)
	else:
		print("실패한 확인: ", _failed)
		quit(1)


## 각 확인 파일이 채워요.
func _run() -> void:
	pass


func open_scene(path: String) -> Node:
	paused = false
	change_scene_to_file(path)
	await frames(3)
	return current_scene


func frames(n: int) -> void:
	for i in n:
		await process_frame


func check(ok: bool, what: String) -> void:
	if ok:
		print("✓ ", what)
	else:
		_failed += 1
		push_error("✗ " + what)


func touch(stage: Node, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = pressed
	stage._play_input(e)


func drag(stage: Node, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = pos
	stage._play_input(e)


## 탭: 누르고 바로 떼요.
func tap(stage: Node, pos: Vector2) -> void:
	touch(stage, pos, true)
	touch(stage, pos, false)


## 쓸기: 누르고 dir 쪽으로 120픽셀 옮긴 뒤 떼요.
func swipe(stage: Node, pos: Vector2, dir: Vector2) -> void:
	touch(stage, pos, true)
	drag(stage, pos + dir * 120.0)
	touch(stage, pos + dir * 120.0, false)


## 길게 누르기: 누르고 held초 동안 누른 채로 있다가 떼요.
func hold(stage: Node, pos: Vector2, held: float) -> void:
	touch(stage, pos, true)
	stage.gesture.tick(held)
	touch(stage, pos, false)


func press_button(stage: Node, text: String) -> bool:
	var b: Button = stage.find_overlay_button(text)
	if b == null:
		return false
	b.pressed.emit()
	return true
