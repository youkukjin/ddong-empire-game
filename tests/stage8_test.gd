extends "res://tests/test_base.gd"
## 8장 '평화' 자동 확인이에요.
## 실행: godot --headless --path . -s tests/stage8_test.gd

const Rules := preload("res://scenes/chapter8/stage8_rules.gd")


func _run() -> void:
	var r := Rules.new(4)
	check(r.progress() == 0.0 and not r.done(), "처음엔 할 일이 모두 남아 있어요")
	check(not r.bring_home(Rules.house_rect(r.houses[0]).get_center()), "고치지 않은 집에는 백성이 못 들어가요")
	for i in 3:
		r.fix_tap(r.houses[0])
	check(r.fixed_houses() == 1 and not r.fix_tap(r.houses[0]), "세 번 누르면 집이 고쳐져요")
	check(r.bring_home(Rules.house_rect(r.houses[0]).get_center()) and r.citizens_home == 1, "고친 집에는 백성이 들어가요")

	var stage = await open_scene("res://scenes/chapter8/stage8.tscn")
	check(stage.name == "Stage8", "8장 스테이지가 열려요")
	stage.use_seed(4)
	stage.skip_intro()
	check(stage.phase == stage.Phase.PLAY and stage.pause_button.visible, "시작해요")
	# 집 고치기
	for h in stage.rules.houses:
		for i in 3:
			tap(stage, Rules.house_rect(h).get_center())
	check(stage.rules.fixed_houses() == Rules.HOUSES, "톡톡톡으로 집 다섯 채를 고쳐요")
	check(stage.backdrop.tint > 0.0, "고칠수록 하늘이 밝아져요")
	# 불씨 끄기: 불씨마다 쓱
	for e in stage.rules.embers:
		touch(stage, e.pos + Vector2(-80, 0), true)
		drag(stage, e.pos + Vector2(80, 0))
		touch(stage, e.pos + Vector2(80, 0), false)
	check(stage.rules.embers_out() == Rules.EMBERS, "쓸어서 불씨를 모두 꺼요")
	# 백성 데려오기
	for i in Rules.CITIZENS:
		var home: Vector2 = Rules.house_rect(stage.rules.houses[i % Rules.HOUSES]).get_center()
		touch(stage, Rules.DOME_CENTER, true)
		drag(stage, home)
		touch(stage, home, false)
	check(stage.rules.citizens_home == Rules.CITIZENS, "돔의 백성을 모두 집으로 데려와요")
	check(stage.phase == stage.Phase.OUTRO, "모두 마치면 해가 떠요")
	await create_timer(2.2).timeout
	check(stage.find_overlay_button("다음 이야기") != null and Save.best_stars(8) == 3 and Save.get_value("game_cleared", false), "결과 창, 게임 끝 기록")
	press_button(stage, "다음 이야기")
	await frames(1)
	check(stage._pages.size() == 3, "끝 이야기: 평화, 모은 별, 끝")
	for i in 3:
		stage.next_page()
	await frames(3)
	check(current_scene.name == "TitleScreen", "마지막 장 뒤에는 타이틀로 돌아가요")
