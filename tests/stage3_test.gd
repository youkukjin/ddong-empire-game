extends "res://tests/test_base.gd"
## 3장 '구멍 탐험' 자동 확인이에요.
## 실행: godot --headless --path . -s tests/stage3_test.gd

const Rules := preload("res://scenes/chapter3/stage3_rules.gd")


func _run() -> void:
	_test_rules()
	await _test_stage()


## 자동으로 완벽하게 달려요: 장애물 앞에서 뛰거나 숙이고, 갈림길은 맞게 골라요.
func _autoplay(r: Rules, perfect_forks := true) -> void:
	var guard := 0
	while r.outcome() == Rules.Outcome.ONGOING and guard < 20000:
		guard += 1
		for it in r.items:
			if it.done or it.x < r.distance:
				continue
			var ahead: float = it.x - r.distance
			if ahead > 200.0:
				break
			if (it.kind == Rules.Kind.ROCK or it.kind == Rules.Kind.PIT or it.kind == Rules.Kind.GEM_HIGH) and ahead < r.speed() * Rules.JUMP_TIME * 0.5:
				r.jump()
			elif it.kind == Rules.Kind.LOW and ahead < 80.0:
				r.duck()
			break
		var f := r.upcoming_fork()
		if not f.is_empty() and f.chosen == Rules.Side.NONE:
			var wrong: int = Rules.Side.DOWN if f.correct == Rules.Side.UP else Rules.Side.UP
			r.choose(f.correct if perfect_forks else wrong)
		r.tick(1.0 / 60.0)


func _test_rules() -> void:
	var r := Rules.new(7)
	check(r.forks.size() == 3 and r.gem_total > 10, "굴은 4구간, 갈림길 3개, 반짝이는 돌 %d개" % r.gem_total)
	check(r.speed() == 300.0, "처음 속도는 300")
	# 아무것도 안 하면 첫 장애물에 부딪혀요
	var r0 := Rules.new(7)
	var first_x: float = 0.0
	for it in r0.items:
		if it.kind != Rules.Kind.GEM and it.kind != Rules.Kind.GEM_HIGH:
			first_x = it.x
			break
	while r0.distance < first_x + 70.0:
		r0.tick(1.0 / 60.0)
	check(r0.hearts == 2 and r0.hearts_lost == 1, "피하지 않으면 장애물에 부딪혀 하트 1개를 잃어요")
	check(r0.invuln > 0.0, "부딪힌 뒤 잠깐은 다시 안 다쳐요")
	check(r0.jump() and not r0.duck(), "뛰는 중에는 숙일 수 없어요")

	_autoplay(r)
	check(r.outcome() == Rules.Outcome.WIN, "잘 피하고 갈림길을 맞히면 본거지에 도착해요")
	check(r.hearts == 3 and r.wrong_forks == 0, "완벽한 달리기: 하트 그대로, 갈림길 모두 맞힘")
	check(r.star_rating() == 3 and r.time_left > 15.0, "별 3개, 남은 시간 %s초" % int(r.time_left))

	var r2 := Rules.new(7)
	_autoplay(r2, false)
	check(r2.wrong_forks == 3 and r2.outcome() == Rules.Outcome.FAIL and r2.fail_reason() == Rules.FailReason.TIME, "갈림길을 다 틀리면 시간이 모자라서 실패해요")

	var r3 := Rules.new(7)
	for i in 3:
		r3._lose_heart()
	check(r3.outcome() == Rules.Outcome.FAIL and r3.fail_reason() == Rules.FailReason.HEARTS, "하트 0개면 실패")


func _test_stage() -> void:
	var stage = await open_scene("res://scenes/chapter3/stage3.tscn")
	check(stage.name == "Stage3", "3장 스테이지가 열려요")
	stage.use_seed(7)
	stage.skip_intro()
	check(stage.phase == stage.Phase.PLAY, "이야기를 넘기면 달리기가 시작돼요")
	tap(stage, Vector2(640, 400))
	check(stage.rules.is_airborne(), "톡 하면 뛰어요")
	stage.rules.jump_left = 0.0
	swipe(stage, Vector2(640, 300), Vector2.DOWN)
	check(stage.rules.is_ducking(), "아래로 쓸면 숙여요")
	# 첫 갈림길 앞까지 옮겨서 위/아래 고르기
	var f: Dictionary = stage.rules.forks[0]
	stage.rules.distance = f.x - 300.0
	for it in stage.rules.items:
		if it.x < f.x:
			it.done = true
	swipe(stage, Vector2(640, 400), Vector2.UP if f.correct == Rules.Side.UP else Vector2.DOWN)
	check(f.chosen == f.correct, "갈림길에서 쓸어서 굴을 골라요")
	for i in 60:
		stage._play_process(1.0 / 60.0)
	check(f.resolved and stage.rules.wrong_forks == 0, "맞는 굴로 들어가요")
	# 나머지는 자동으로 완벽하게
	_autoplay(stage.rules)
	stage._play_process(0.01)
	check(stage.phase == stage.Phase.OUTRO, "끝까지 가면 본거지 입구 연출이 나와요")
	await create_timer(1.5).timeout
	check(stage.phase == stage.Phase.RESULT and stage.find_overlay_button("다음 이야기") != null, "결과 창이 나와요")
	check(Save.best_stars(3) >= 1 and Save.is_unlocked(4), "3장 기록이 저장되고 4장이 열려요")

	press_button(stage, "다시 하기")
	await frames(3)
	stage = current_scene
	stage.skip_intro()
	for i in 3:
		stage.rules._lose_heart()
	stage._play_process(0.01)
	check(stage.find_overlay_button("다시 하기") != null and stage.phase == stage.Phase.RESULT, "하트를 다 잃으면 아쉬워요 창이 나와요")
