extends "res://tests/test_base.gd"
## 2장 '준비' 자동 확인이에요.
## 실행: godot --headless --path . -s tests/stage2_test.gd

const Rules := preload("res://scenes/chapter2/stage2_rules.gd")


func _run() -> void:
	_test_rules()
	await _test_stage()


func _test_rules() -> void:
	check(Rules.judge_tap(0.05) == Rules.Judge.PERFECT and Rules.judge_tap(-0.2) == Rules.Judge.GOOD and Rules.judge_tap(0.35) == Rules.Judge.MISS, "아령: ±0.15초 딱 좋아요, ±0.3초 좋아요, 그 밖은 놓침")
	check(Rules.drill_stars(Rules.Drill.DUMBBELL, 9) == 0 and Rules.drill_stars(Rules.Drill.DUMBBELL, 10) == 1 and Rules.drill_stars(Rules.Drill.DUMBBELL, 24) == 3, "아령: 10점 통과, 20점 이상 별 3개")
	check(Rules.roll_dodged(1.0, 1.4) and not Rules.roll_dodged(1.0, 1.6) and not Rules.roll_dodged(-1.0, 1.0), "구르기: 무적 0.5초 안에 닿으면 피해요")
	check(is_equal_approx(Rules.charge_ratio(0.85), 0.5) and Rules.charge_ratio(3.0) == 1.0, "사슬: 1.7초 누르면 다 차요")
	var r := Rules.new()
	check(r.finish_drill(24) and r.stars[Rules.Drill.DUMBBELL] == 3, "통과하면 별을 기록해요")
	r.finish_drill(13)
	check(r.stars[Rules.Drill.DUMBBELL] == 3, "다시 연습해서 낮게 나와도 좋은 기록이 남아요")
	check(not r.finish_drill(3), "통과 점수보다 낮으면 통과 못 해요")
	for d in [Rules.Drill.SWORD, Rules.Drill.CHAIN, Rules.Drill.ROLL]:
		r.next_drill()
		r.finish_drill(Rules.THRESHOLDS[d][0])
	check(r.all_done() and r.total_stars() == 6 and r.chapter_stars() == 1, "모두 겨우 통과하면 별 6개 → 장 별 1개")


func _test_stage() -> void:
	var stage = await open_scene("res://scenes/chapter2/stage2.tscn")
	check(stage.name == "Stage2", "2장 스테이지가 열려요")
	stage.skip_intro()
	await frames(1)
	check(stage.phase == stage.Phase.PLAY and press_button(stage, "시작"), "이야기 뒤에 첫 연습 안내와 시작 버튼이 나와요")
	check(stage.drill_active and stage.pause_button.visible, "연습 중에는 멈춤 버튼이 보여요")

	# 1) 아령: 모든 고리를 딱 맞게 톡
	for n in stage._notes:
		stage.set_drill_time(n.time + 0.02)
		touch(stage, Vector2(700, 400), true)
		touch(stage, Vector2(700, 400), false)
	check(stage.rules.stars.get(Rules.Drill.DUMBBELL, 0) == 3, "아령: 모두 딱 맞추면 별 3개")
	check(press_button(stage, "다음 연습") and press_button(stage, "시작"), "다음 연습으로 넘어가요")

	# 2) 검: 나오는 표적을 모두 톡 (단단한 표적은 두 번)
	check(stage.rules.drill == Rules.Drill.SWORD, "두 번째는 검 연습")
	var guard := 0
	while stage.drill_active and guard < 400:
		guard += 1
		stage._play_process(0.1)
		for t in stage._targets.duplicate():
			tap(stage, t.pos)
			if t.hp > 0:
				tap(stage, t.pos)
	check(stage.rules.stars.has(Rules.Drill.SWORD), "검: 표적을 맞혀서 통과 (%d개)" % stage.rules.scores.get(Rules.Drill.SWORD, 0))
	check(press_button(stage, "다음 연습") and press_button(stage, "시작"), "사슬 연습으로 넘어가요")

	# 3) 사슬: 짧게 누르면 안 나가고, 다 모아서 표적이 줄에 올 때 떼면 맞아요
	hold(stage, Vector2(640, 400), 0.5)
	check(stage._count == 0, "사슬: 힘이 덜 모이면 안 던져져요")
	var lane_phase := asin((stage.LANE_Y - 400.0) / 190.0)
	for k in Rules.CHAIN_THROWS:
		var t0: float = (lane_phase + TAU * (k + 1)) / 1.6 - stage.VORTEX_TIME
		stage.set_drill_time(t0)
		hold(stage, Vector2(640, 400), 1.8)
		stage._play_process(stage.VORTEX_TIME + 0.01)
	check(stage.rules.stars.get(Rules.Drill.CHAIN, 0) == 3, "사슬: 6번 다 맞히면 별 3개")
	check(press_button(stage, "다음 연습") and press_button(stage, "시작"), "구르기 연습으로 넘어가요")

	# 4) 구르기: 첫 공은 일부러 너무 일찍 굴러서 맞고, 나머지는 딱 맞게 피해요
	var balls: Array = stage._balls
	stage.set_drill_time(balls[0].hit_time - 0.8)
	swipe(stage, Vector2(640, 400), Vector2.LEFT)
	stage._play_process(0.85)
	check(stage.drill_score() == 0, "구르기: 너무 일찍 구르면 맞아요")
	for i in range(1, balls.size()):
		stage.set_drill_time(balls[i].hit_time - 0.2)
		swipe(stage, Vector2(640, 400), Vector2.LEFT)
		stage._play_process(0.25)
	check(stage.rules.stars.get(Rules.Drill.ROLL, 0) == 2, "구르기: 10개 중 9개 피하면 별 2개")
	await frames(1)
	check(stage.phase == stage.Phase.RESULT and stage.find_overlay_button("다음 이야기") != null, "네 가지를 마치면 결과 창이 나와요")
	check(Save.best_stars(2) == 3 and Save.is_unlocked(3), "2장 별 3개가 저장되고 3장이 열려요")

	# 다시 하기와 실패
	press_button(stage, "다시 하기")
	await frames(3)
	stage = current_scene
	stage.skip_intro()
	press_button(stage, "시작")
	stage.set_drill_time(100.0)
	stage._play_process(0.01)
	check(stage.find_overlay_button("다시 연습") != null and not stage.rules.stars.has(Rules.Drill.DUMBBELL), "고리를 다 놓치면 통과 못 하고 다시 연습 버튼이 나와요")
	check(press_button(stage, "다시 연습") and stage.drill_active, "다시 연습으로 같은 연습을 다시 해요")
	stage.toggle_pause()
	check(paused, "멈춤 버튼으로 멈춰요")
	press_button(stage, "처음으로")
	await frames(3)
	check(current_scene.name == "TitleScreen" and not paused, "처음으로 돌아가요")
