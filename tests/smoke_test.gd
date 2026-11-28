extends SceneTree
## 간단한 자동 확인: 타이틀 → 시작하기 → 1장 스테이지 → 멈춤 → 처음으로 → 타이틀
## 실행: godot --headless --path . -s tests/smoke_test.gd

const Save := preload("res://scripts/save_data.gd")


func _initialize() -> void:
	Save.path = "user://test_save.cfg"
	DirAccess.remove_absolute(Save.path)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/title/title_screen.tscn")
	await _frames(2)
	_check(current_scene.name == "TitleScreen", "타이틀 화면이 열려요")
	var start: Button = current_scene.get_node("%StartButton")
	_check(start.text == "시작하기", "시작 버튼이 있어요")
	_check(not current_scene.get_node("%HardButton").visible, "처음에는 어려움 모드 버튼이 숨어 있어요")
	var select: Button = current_scene.get_node("%SelectButton")
	_check(select.visible, "장 고르기 버튼이 있어요")
	select.pressed.emit()
	await _frames(2)
	_check(current_scene.name == "ChapterSelect", "장 고르기 화면이 열려요")
	var story: Button = current_scene.find_child("Btn_이야기", true, false)
	_check(story != null and story.text.contains("1장") and story.text.contains("0/8"), "이야기 한 칸에 1장과 진행(0/8)이 보여요")
	current_scene.find_child("Btn_처음으로", true, false).pressed.emit()
	await _frames(2)
	_check(current_scene.name == "TitleScreen", "장 고르기에서 처음으로 돌아와요")
	start = current_scene.get_node("%StartButton")
	start.pressed.emit()
	await _frames(2)
	_check(current_scene.name == "Stage1", "시작하기로 1장 '등장' 스테이지에 가요")
	var stage = current_scene
	stage.skip_intro()
	await _frames(2)
	_check(stage.phase == stage.Phase.PLAY, "이야기 장면을 넘기면 플레이가 시작돼요")
	stage._toggle_pause()
	await _frames(1)
	_check(paused, "멈춤 버튼으로 게임이 멈춰요")
	var home: Button = stage.find_overlay_button("처음으로")
	_check(home != null, "멈춤 창에 처음으로 버튼이 있어요")
	home.pressed.emit()
	await _frames(2)
	_check(current_scene.name == "TitleScreen" and not paused, "처음으로 버튼으로 타이틀에 돌아와요")
	print("모든 확인 통과")
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		print("✓ ", what)
	else:
		push_error("✗ " + what)
		quit(1)
