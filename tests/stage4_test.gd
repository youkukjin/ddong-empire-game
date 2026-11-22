extends "res://tests/test_base.gd"
## 4장 '성벽 돌파' 자동 확인이에요.
## 실행: godot --headless --path . -s tests/stage4_test.gd

const Rules := preload("res://scenes/chapter4/stage4_rules.gd")


func _run() -> void:
	_test_rules()
	await _test_stage()


func _test_rules() -> void:
	var r := Rules.new(3)
	r.prince_x = Rules.col_center_x(2)
	check(not r.sword_hit(2, 0), "검은 위쪽 벽돌에 안 닿아요")
	check(not r.sword_hit(6, 4), "멀리 있는 벽돌에는 검이 안 닿아요")
	check(r.sword_hit(2, 4) and r.bricks[2][4] == 2, "가까운 아래 벽돌은 검으로 1씩 깎여요")
	var v := r.vortex()
	check(v.col == 2 and r.bricks[2][4] == 0 and r.bricks[2][3] == 0 and r.bricks[2][2] == 3, "소용돌이: 아래 벽돌부터 힘 5만큼 깎아요")
	r.vortex()
	r.vortex()
	check(r.column_clear(2), "소용돌이를 여러 번 쏘면 한 줄이 위까지 뚫려요")
	check(not r.has_hole(), "한 줄만으로는 구멍이 아니에요")
	r.prince_x = Rules.col_center_x(1)
	var before := r.live_cannons().size()
	for i in 6:
		r.vortex()
	check(r.column_clear(1) and r.has_hole(), "나란한 두 줄이 뚫리면 구멍이에요")
	check(r.live_cannons().size() == before - 1 and r.cannons_broken == 1, "빈 줄에서 쏘면 그 위 대포가 부서져요")
	check(r.outcome() == Rules.Outcome.WIN and r.star_rating() == 3, "구멍 = 성공, 무피해에 시간 넉넉하면 별 3개")

	# 대포알: 가만히 있으면 맞고, 구르면 피해요
	var r2 := Rules.new(3)
	var hurt := false
	for i in 300:
		for e in r2.tick(1.0 / 60.0):
			if e.type == "hurt":
				hurt = true
	check(hurt and r2.hearts < Rules.HEARTS, "가만히 있으면 대포알에 맞아요")
	var r3 := Rules.new(3)
	var hits := 0
	for i in 1200:
		for b in r3.balls:
			if b.left < 0.2 and absf(b.x - r3.prince_x) < Rules.BALL_RADIUS and not r3.is_rolling():
				r3.roll(-1.0 if r3.prince_x > 640 else 1.0)
		for e in r3.tick(1.0 / 60.0):
			if e.type == "hurt":
				hits += 1
	check(hits == 0, "떨어지기 직전에 구르면 대포알을 피해요")
	r3.time_left = 0.0
	check(r3.outcome() == Rules.Outcome.FAIL and r3.fail_reason() == Rules.FailReason.TIME, "시간이 끝나면 실패")


func _test_stage() -> void:
	var stage = await open_scene("res://scenes/chapter4/stage4.tscn")
	check(stage.name == "Stage4", "4장 스테이지가 열려요")
	stage.use_seed(3)
	stage.skip_intro()
	check(stage.phase == stage.Phase.PLAY, "이야기를 넘기면 시작해요")
	tap(stage, Vector2(Rules.col_center_x(1), 650))
	check(is_equal_approx(stage.rules.walk_target, Rules.col_center_x(1)), "땅을 톡 하면 그쪽으로 걸어가요")
	stage.rules.prince_x = Rules.col_center_x(1)
	var brick_pos: Vector2 = Rules.brick_rect(1, 4).get_center()
	tap(stage, brick_pos)
	check(stage.rules.bricks[1][4] == 2, "아래 벽돌을 톡 하면 검으로 쳐요")
	tap(stage, Rules.brick_rect(1, 0).get_center())
	check(stage.rules.bricks[1][0] == 3, "위쪽 벽돌은 톡 해도 안 깨져요")
	hold(stage, Vector2(640, 650), 0.6)
	check(stage.rules.bricks[1][3] == 3, "힘이 덜 모이면 소용돌이가 안 나가요")
	for i in 3:
		hold(stage, Vector2(640, 650), 1.8)
	check(stage.rules.column_clear(1), "꾹 눌렀다 떼면 소용돌이로 한 줄을 뚫어요")
	swipe(stage, Vector2(640, 650), Vector2.RIGHT)
	check(stage.rules.is_rolling(), "옆으로 쓸면 굴러요")
	stage.rules.prince_x = Rules.col_center_x(2)
	stage.rules.walk_target = stage.rules.prince_x
	stage.rules.roll_left = 0.0
	for i in 3:
		hold(stage, Vector2(640, 650), 1.8)
	stage._play_process(0.01)
	check(stage.phase == stage.Phase.OUTRO, "두 줄을 뚫으면 성공 연출이 나와요")
	await create_timer(1.5).timeout
	check(stage.phase == stage.Phase.RESULT and stage.find_overlay_button("다음 이야기") != null, "결과 창이 나와요")
	check(Save.best_stars(4) >= 1 and Save.is_unlocked(5), "4장 기록이 저장되고 5장이 열려요")
