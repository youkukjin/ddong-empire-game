extends SceneTree
## 1장 '등장' 스테이지 자동 확인이에요.
## 실행: godot --headless --path . -s tests/stage1_test.gd
## 1) 규칙 계산(시간, 하트, 승리·실패, 별, 중간 저장, 난이도)
## 2) 실제 스테이지에서 터치로 끌기·쓸기·코 누르기

const Rules := preload("res://scenes/chapter1/stage1_rules.gd")
const Session := preload("res://scripts/game_session.gd")
const Save := preload("res://scripts/save_data.gd")
const WorldBG := preload("res://scenes/chapter1/world_background.gd")

var _failed := 0


func _initialize() -> void:
	Save.path = "user://test_save.cfg"
	DirAccess.remove_absolute(Save.path)
	_run.call_deferred()


func _run() -> void:
	_test_rules()
	await _test_stage_controls()
	await _test_win_flow()
	await _test_fail_and_checkpoint()
	DirAccess.remove_absolute(Save.path)
	if _failed == 0:
		print("모든 확인 통과")
		quit(0)
	else:
		print("실패한 확인: ", _failed)
		quit(1)


# ---------------------------------------------------------------- 규칙

func _test_rules() -> void:
	var r := Rules.new()
	_check(r.time_left == 180.0 and r.hearts == 3, "보통 모드: 3분, 하트 3개")
	_check(r.is_practice() and r.beam_interval() == 0.0 and r.max_fires() == 2, "처음 20초는 연습: 줄기 없음, 불 2개")
	r.tick(21.0)
	_check(r.beam_interval() == 4.0 and r.warning_time() == 1.0 and r.max_fires() == 3, "초반: 4초마다 줄기, 1초 전 점선, 불 3개")
	for i in 7:
		r.on_spawned()
		_check(not r.on_rescued(), "", true)
	r.on_spawned()
	_check(r.on_rescued(), "8명을 구한 순간 중간 저장돼요")
	_check(r.beam_interval() == 3.0 and r.warning_time() == 0.7 and r.max_fires() == 5 and r.sweep_beams_allowed(), "후반: 3초마다, 0.7초 전 점선, 불 5개, 훑는 줄기")
	_check(r.outcome() == Rules.Outcome.ONGOING, "아직 진행 중")
	for i in 7:
		r.on_spawned()
		r.on_rescued()
	_check(r.outcome() == Rules.Outcome.WIN and r.star_rating() == 3, "15명 모두 + 무피해 = 승리, 별 3개")
	_check(r.star_title(3) == "완벽한 구조!", "별 3개 칭호")

	var r2 := Rules.new()
	r2.tick(21.0)
	for i in 14:
		r2.on_rescued()
	r2.lose_heart(Rules.HeartReason.BEAM)
	r2.on_citizen_fled()
	_check(r2.outcome() == Rules.Outcome.WIN and r2.star_rating() == 2, "14명 = 별 2개")

	var r3 := Rules.new()
	for i in 12:
		r3.on_rescued()
	r3.tick(200.0)
	_check(r3.outcome() == Rules.Outcome.WIN and r3.star_rating() == 1, "시간 끝 + 12명 = 승리, 별 1개")

	var r4 := Rules.new()
	for i in 11:
		r4.on_rescued()
	r4.tick(200.0)
	_check(r4.outcome() == Rules.Outcome.FAIL and r4.fail_reason() == Rules.FailReason.TIME, "시간 끝 + 11명 = 실패")

	var r5 := Rules.new()
	for i in 3:
		r5.lose_heart(Rules.HeartReason.NOSE)
	_check(r5.outcome() == Rules.Outcome.FAIL and r5.fail_reason() == Rules.FailReason.HEARTS, "하트 0개 = 실패")
	_check(r5.fail_tip().contains("코"), "코를 놓쳐 졌으면 코 팁을 보여줘요")

	var r6 := Rules.new()
	for i in 4:
		r6.on_citizen_fled()
	_check(r6.outcome() == Rules.Outcome.FAIL, "4명이 도망가면 12명을 못 채워서 바로 실패")

	var r7 := Rules.new()
	r7.start_from_checkpoint(30.0, 9)
	_check(r7.rescued == 8 and r7.hearts == 3 and r7.time_left == 60.0 and not r7.is_practice(), "중간부터: 8명, 하트 3개, 최소 1분")
	for i in 7:
		r7.on_rescued()
	_check(r7.star_rating() == 2, "중간부터 다시 한 판은 별 3개가 안 돼요")

	var hard := Rules.new(true)
	_check(hard.time_left == 150.0 and hard.hearts == 1, "어려움 모드: 2분 30초, 하트 1개")
	var assist := Rules.new(false, true)
	assist.tick(21.0)
	_check(assist.warning_time() == 1.5, "도움 켜기: 점선이 1.5초 전에 나와요")

	var r8 := Rules.new()
	_check(r8.on_sweep_finished(3) and r8.score == 1, "불 3개를 한 번에 쓸면 콤보 별 +1")
	_check(not r8.on_sweep_finished(2) and r8.score == 1, "2개는 콤보가 아니에요")


# ---------------------------------------------------------------- 실제 스테이지

func _open_stage(hard := false) -> Node:
	Session.hard_mode = hard
	Session.assist = false
	Session.clear_checkpoint()
	change_scene_to_file("res://scenes/chapter1/stage1.tscn")
	await _frames(2)
	var stage = current_scene
	stage.skip_intro()
	await _frames(1)
	# 자동 확인 중에는 드래곤 공격과 새 백성을 멈춰 둬요
	stage._beam_timer = 999.0
	stage._mouth_timer = 999.0
	stage._spawn_timer = 999.0
	for f in stage.fires_root.get_children():
		f.queue_free()
	await _frames(1)
	return stage


func _test_stage_controls() -> void:
	var stage = await _open_stage()
	_check(stage.phase == stage.Phase.PLAY, "스테이지가 시작돼요")

	# 끌기: 백성을 눌러 돔까지
	var c = stage._spawn_citizen()
	c.position = Vector2(600, 520)
	await _frames(1)
	var grab: Vector2 = c.center_global()
	await _drag(grab, WorldBG.DOME_CENTER + Vector2(0, -40))
	await _frames(1)
	_check(stage.rules.rescued == 1 and stage.background.rescued == 1, "백성을 끌어서 돔에 넣으면 구한 백성 1명")

	# 불 위로는 끌 수 없어요
	var c2 = stage._spawn_citizen()
	c2.position = Vector2(450, 520)
	var fire = stage._spawn_fire(Vector2(600, 520))
	await _frames(1)
	await _drag(c2.center_global(), Vector2(800, 490))
	_check(c2.position.x < 600.0 and stage.rules.rescued == 1, "불이 막고 있으면 지나갈 수 없어요")

	# 쓸기: 불 3개를 한 번에
	for f in stage.fires_root.get_children():
		f.queue_free()
	c2.position = Vector2(450, 620)
	await _frames(1)
	for x in [500.0, 640.0, 780.0]:
		stage.rules.elapsed = 30.0   # 불 3개를 둘 수 있게 연습 구간을 넘겨요
		stage._spawn_fire(Vector2(x, 450))
	await _frames(1)
	_check(stage._fire_count() == 3, "불 3개가 있어요")
	var score_before: int = stage.rules.score
	await _drag(Vector2(430, 430), Vector2(860, 430))
	await _frames(1)
	_check(stage._fire_count() == 0, "쓱 쓸면 지나간 불이 모두 꺼져요")
	_check(stage.rules.score == score_before + 1, "한 번에 3개를 끄면 콤보 별 +1")

	# 코 누르기
	stage.dragon.open_mouth(1.5)
	await _frames(15)
	_tap(stage.dragon.nose_global())
	await _frames(1)
	_check(stage.dragon.state == stage.dragon.State.SNEEZE and stage.rules.hearts == 3, "입을 벌린 드래곤 코를 톡 누르면 '에취!' 하고 물러나요")

	# 코를 놓치면 하트 -1, 백성 1명 도망
	await _wait(1.5)
	stage.dragon.open_mouth(1.5)
	await _wait(1.7)
	_check(stage.rules.hearts == 2 and stage.rules.lost == 1, "코를 놓치면 하트가 줄고 백성 1명이 도망가요")

	# 줄기에 맞으면 하트 -1
	var c3 = stage._spawn_citizen()
	c3.position = Vector2(700, 520)
	stage.rules.elapsed = 30.0
	stage._fire_beam()
	var beam = stage.beams_root.get_child(stage.beams_root.get_child_count() - 1)
	beam.from_target = c3.position
	beam.sweep = false
	await _wait(1.6)
	_check(stage.rules.hearts == 1, "보라색 줄기에 맞으면 하트가 줄어요")


func _test_win_flow() -> void:
	var stage = await _open_stage()
	for i in 12:
		var c = stage._spawn_citizen()
		stage.rescue_citizen(c)
	stage.rules.tick(999.0)
	await _wait(2.4)
	_check(stage.phase == stage.Phase.RESULT, "시간이 끝나고 12명 이상이면 드래곤이 날아가고 결과 화면")
	_check(stage.find_overlay_button("다음 이야기") != null, "결과 화면에 다음 이야기 버튼")
	_check(bool(Save.get_value("chapter2_unlocked", false)), "2장이 열린 것으로 저장돼요")
	_check(not Save.hard_unlocked(), "별 1개로는 어려움 모드가 안 열려요")

	stage = await _open_stage()
	for i in 15:
		var c = stage._spawn_citizen()
		stage.rescue_citizen(c)
	await _wait(2.4)
	_check(Save.hard_unlocked() and int(Save.get_value("chapter1_best_stars", 0)) == 3, "별 3개로 깨면 어려움 모드가 열려요")
	stage.find_overlay_button("처음으로").pressed.emit()
	await _frames(2)
	_check(current_scene.get_node("%HardButton").visible, "타이틀에 어려움 모드 버튼이 보여요")


func _test_fail_and_checkpoint() -> void:
	var stage = await _open_stage()
	for i in 8:
		var c = stage._spawn_citizen()
		stage.rescue_citizen(c)
	_check(Session.has_checkpoint, "8명을 구하면 중간 저장")
	for i in 3:
		stage.rules.lose_heart(Rules.HeartReason.BEAM)
	await _frames(2)
	_check(stage.phase == stage.Phase.RESULT, "하트 0개면 실패 화면")
	var mid: Button = stage.find_overlay_button("중간부터")
	_check(mid != null, "실패 화면에 중간부터 버튼")
	mid.pressed.emit()
	await _frames(3)
	stage = current_scene
	_check(stage.rules.rescued == 8 and stage.rules.hearts == 3, "중간부터: 8명, 하트 3개로 다시 시작")
	stage.skip_intro()
	# 3번 연속 실패하면 도움 켜기를 권해요
	Session.fail_streak = 2
	for i in 3:
		stage.rules.lose_heart(Rules.HeartReason.BEAM)
	await _frames(2)
	_check(stage.find_overlay_button("도움 켜기") != null, "3번 연속 실패하면 도움 켜기 버튼")


# ---------------------------------------------------------------- 터치 흉내
# push_input은 창 좌표를 받아요. 게임 화면(1280x720) 좌표를 창 좌표로 바꿔서 넣어요.

func _to_window(p: Vector2) -> Vector2:
	return root.get_final_transform() * p

func _touch(p: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = _to_window(p)
	ev.pressed = pressed
	root.push_input(ev)


func _tap(p: Vector2) -> void:
	_touch(p, true)
	_touch(p, false)


func _drag(a: Vector2, b: Vector2) -> void:
	_touch(a, true)
	for i in range(1, 21):
		var ev := InputEventScreenDrag.new()
		ev.index = 0
		ev.position = _to_window(a.lerp(b, i / 20.0))
		root.push_input(ev)
		await process_frame
	_touch(b, false)
	await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _check(ok: bool, what: String, quiet := false) -> void:
	if ok:
		if not quiet:
			print("✓ ", what)
	else:
		_failed += 1
		push_error("✗ " + what)
