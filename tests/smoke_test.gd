extends SceneTree
## 간단한 자동 확인: 타이틀 → 시작 버튼 → 게임 화면 → 처음으로 버튼 → 타이틀
## 실행: godot --headless --path . -s tests/smoke_test.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/title/title_screen.tscn")
	await process_frame
	await process_frame
	_check(current_scene.name == "TitleScreen", "타이틀 화면이 열려요")
	var start: Button = current_scene.get_node("%StartButton")
	_check(start.text == "시작하기", "시작 버튼이 있어요")
	start.pressed.emit()
	await process_frame
	await process_frame
	_check(current_scene.name == "GamePlaceholder", "시작 버튼으로 게임 화면에 가요")
	var back: Button = current_scene.get_node("%BackButton")
	back.pressed.emit()
	await process_frame
	await process_frame
	_check(current_scene.name == "TitleScreen", "처음으로 버튼으로 타이틀에 돌아와요")
	print("모든 확인 통과")
	quit(0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("✓ ", what)
	else:
		push_error("✗ " + what)
		quit(1)
