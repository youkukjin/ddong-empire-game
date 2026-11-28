extends "res://tests/test_base.gd"
## 이어하기 자동 확인이에요: 앱을 껐다 켜도 열린 장과 중간 저장이 남는지 봐요.
## 실행: godot --headless --path . -s tests/continue_test.gd



func _run() -> void:
	check(not Save.has_progress(), "처음 켜면 이어할 기록이 없어요")
	var title = await open_scene("res://scenes/title/title_screen.tscn")
	check(title.continue_button == null and title.start_button.text == "시작하기", "기록이 없으면 '시작하기'만 있어요")

	Save.record_chapter1_win(2, false)
	Save.record_chapter_win(2, 3)
	Save.record_chapter_win(3, 1)
	check(Save.has_progress() and Save.continue_chapter(8) == 4, "3장까지 깨면 이어하기는 4장")

	# 5장 보스 앞 중간 저장을 남기고 '앱을 껐다 켠' 것처럼 메모리를 지워요
	Session.chapter_checkpoint[5] = "boss"
	Session.has_checkpoint = true
	Session.checkpoint_time_left = 77.0
	Session.persist()
	Session.chapter_checkpoint = {}
	Session.has_checkpoint = false
	Session.checkpoint_time_left = 0.0
	Session._restored = false
	Session.restore()
	check(Session.chapter_checkpoint.get(5, "") == "boss" and Session.has_checkpoint and Session.checkpoint_time_left == 77.0, "중간 저장이 기기에 남아서 다시 켜도 불러와요")

	title = await open_scene("res://scenes/title/title_screen.tscn")
	check(title.continue_button != null and title.continue_button.text.contains("4장") and title.start_button.text == "처음부터", "기록이 있으면 '이어하기 (4장)' 버튼이 나와요")
	title.continue_button.pressed.emit()
	await frames(3)
	check(current_scene.name == "Stage4", "이어하기를 누르면 4장이 열려요")
	check(Save.last_chapter() == 4, "하던 장이 기록돼요")
