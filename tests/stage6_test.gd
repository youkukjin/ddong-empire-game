extends "res://tests/test_base.gd"
## 6장 '재도전' 자동 확인이에요: 일주일 준비 규칙, 준비 화면, 드래곤 2차전.
## 실행: godot --headless --path . -s tests/stage6_test.gd

const Growth := preload("res://scenes/chapter6/growth_rules.gd")


func _run() -> void:
	_test_growth()
	await _test_prep_screen()
	await _test_battle()


## 설계 문서의 균형형: 훈련 7, 모험 5, 돕기 3, 대장간 3 → Lv 12, 검 +3 / 사슬 +3
func balanced() -> RefCounted:
	var g = Growth.new()
	for i in 7:
		g.do_action(Growth.Action.TRAIN)
	for i in 5:
		g.do_action(Growth.Action.ADVENTURE)
	for i in 3:
		g.do_action(Growth.Action.HELP)
	g.do_forge(["sword", "chain"])
	g.do_forge(["sword", "chain"])
	g.do_forge(["sword", "chain"])
	return g


func _test_growth() -> void:
	var g = Growth.new()
	check(g.level == 5 and g.str_ == 10 and g.actions_left() == 18, "Lv 5, 능력치 10, 행동 18번에서 시작")
	check(Growth.xp_to_next(5) == 100 and Growth.xp_to_next(14) == 280, "레벨 곡선: 5→6은 100, 14→15는 280")
	var r: Dictionary = g.do_action(Growth.Action.TRAIN)
	check(r.xp == 120 and g.level == 6 and g.points == 3 and g.xp == 20, "훈련 한 번: 경험치 120 → Lv 6, 점수 3")
	var r2: Dictionary = g.do_action(Growth.Action.ADVENTURE, 1.0)
	check(r2.xp == 90 and r2.stones == 6, "미니게임을 완벽하게 하면 보상 1.5배 (반짝 돌 6)")
	check(g.time_name() == "1일째 저녁", "행동마다 아침 → 낮 → 저녁")
	check(not g.do_forge(["sword", "sword", "chain"]), "대장간은 한 번에 2단계까지")
	check(g.do_forge(["sword", "sword"]) and g.sword_lv == 2 and g.stones == 1 and g.sword_bonus() == 6, "검 +2: 반짝 돌 5개, 보너스 +6")
	check(not g.do_forge(["chain"]), "재료가 모자라면 강화할 수 없어요")

	var b = balanced()
	check(b.week_over() and b.actions_left() == 0, "18번 하면 일주일이 끝나요")
	check(b.level == 12 and b.sword_lv == 3 and b.chain_lv == 3, "균형형: Lv 12, 검 +3, 사슬 +3 (설계 문서와 같아요)")
	check(b.needs_branch() == ["sword", "chain"], "+3이 되면 갈림길을 골라야 해요")
	for i in 9:
		b.add_point("str")
	for i in 6:
		b.add_point("vit")
	for i in 6:
		b.add_point("agi")
	var s: Dictionary = b.battle_stats()
	check(b.str_ == 19 and s.sword == 29 and s.chain == 58 and s.max_hp == 130, "균형형 능력치: 검 29, 사슬 58, 체력 130 (설계 문서와 같아요)")
	check(is_equal_approx(s.roll_invuln, 0.46) and is_equal_approx(s.charge_time, 1.52), "민첩 16: 무적 0.46초, 모으기 1.52초")
	b.sword_branch = "heavy"
	check(b.battle_stats().sword == 38 and b.battle_stats().sword_pause == 0.2, "무거운 검: 피해 1.3배, 0.2초 멈춤")
	b.respec()
	check(b.str_ == 10 and b.points == 21, "능력치 다시 나누기: 모두 10으로, 점수 21 돌려받아요")
	b.help_mode = true
	check(b.battle_stats().max_hp == 150, "도움 모드: 체력 1.5배")

	var g2 = Growth.new()
	for i in 15:
		g2.do_action(Growth.Action.ADVENTURE)
	check(g2.leftover_warning().contains("반짝 돌"), "6일째에 재료가 남으면 경고해요")
	check(g2.do_meeting("꼬리치기") and not g2.do_meeting("꼬리치기"), "작전 회의: 같은 비밀은 한 번만")
	var copy = Growth.from_dict(g2.to_dict())
	check(copy.stones == g2.stones and copy.secrets == ["꼬리치기"] and copy.day == g2.day, "준비 상태를 저장하고 그대로 불러와요")


func _test_prep_screen() -> void:
	Growth.clear_saved()
	var stage = await open_scene("res://scenes/chapter6/stage6.tscn")
	check(stage.name == "Stage6", "6장 준비 화면이 열려요")
	stage.skip_intro()
	await frames(1)
	var train: Button = stage._ui.find_child("Action0", true, false)
	check(train != null, "행동 다섯 개 버튼이 있어요")
	train.pressed.emit()
	check(press_button(stage, "빠르게") and press_button(stage, "좋아요"), "훈련장 → 빠르게 → 결과")
	await frames(1)
	check(stage.growth.level == 6 and stage.growth.points == 3, "레벨이 오르고 점수 3을 받아요")
	var plus: Button = stage._ui.find_child("Plus_str", true, false)
	check(plus != null, "+ 버튼으로 능력치를 나눠요")
	plus.pressed.emit()
	await frames(1)
	check(stage.growth.str_ == 11 and stage.growth.points == 2, "힘 +1")
	# 미니게임: 아령을 모두 딱 맞게
	stage._ui.find_child("Action0", true, false).pressed.emit()
	press_button(stage, "미니게임")
	check(stage.mode == "mini", "미니게임이 시작돼요")
	for n in stage._mini.items:
		stage._mini.t = n.time
		stage.mini_tap(Vector2(700, 400))
	stage._mini.t = 20.0
	stage._play_process(0.01)
	check(stage.growth.xp == 20 + 180 - 120 and stage.growth.level == 7, "미니게임 완벽: 경험치 180 (1.5배)")
	press_button(stage, "좋아요")
	# 모험 미니게임 (벌레 잡기)
	stage._ui.find_child("Action1", true, false).pressed.emit()
	press_button(stage, "미니게임")
	for i in 400:
		stage._play_process(0.05)
		if stage._mini.is_empty():
			break
		for bug in stage._mini.items.duplicate():
			stage.mini_tap(bug.pos)
	check(stage.growth.stones >= 4, "똥 벌레를 잡으면 반짝 돌을 받아요 (%d개)" % stage.growth.stones)
	press_button(stage, "좋아요")
	# 집 고치기: 순서대로
	stage._ui.find_child("Action2", true, false).pressed.emit()
	press_button(stage, "미니게임")
	var items: Array = stage._mini.items.duplicate()
	stage.mini_tap(items[1].pos)
	check(stage._mini.next == 1, "순서가 틀리면 안 고쳐져요")
	for c in items:
		stage.mini_tap(c.pos)
	stage._play_process(0.01)
	check(stage.growth.orbs == 2, "모두 고치면 황금 똥구슬 2개")
	press_button(stage, "좋아요")
	# 대장간
	stage._ui.find_child("Action3", true, false).pressed.emit()
	check(press_button(stage, "검 강화") and press_button(stage, "뚝딱!_강화"), "대장간에서 검을 강화해요")
	press_button(stage, "좋아요")
	check(stage.growth.sword_lv == 1, "검 +1")
	# 작전 회의
	stage._ui.find_child("Action4", true, false).pressed.emit()
	check(press_button(stage, "보라색 광선"), "작전 회의에서 공격을 골라요")
	check(stage.growth.secrets == ["보라색 광선"], "비밀을 알아내요")
	# 저장 확인: 다시 열면 이어서
	var day: int = stage.growth.day
	var slot: int = stage.growth.slot
	stage = await open_scene("res://scenes/chapter6/stage6.tscn")
	check(stage.growth.day == day and stage.growth.slot == slot and stage.growth.sword_lv == 1, "껐다 켜도 준비를 이어서 해요")


func _test_battle() -> void:
	var g = balanced()
	g.sword_branch = "fast"
	g.chain_branch = "pierce"
	for i in 9:
		g.add_point("str")
	for i in 6:
		g.add_point("vit")
	for i in 6:
		g.add_point("agi")
	g.save()
	var stage = await open_scene("res://scenes/chapter6/stage6.tscn")
	stage.skip_intro()
	await frames(1)
	var go: Button = stage._ui.find_child("GoButton", true, false)
	check(go != null and stage._ui.find_child("SwitchButton", true, false) != null, "7일째: 출발 버튼과 갈림길 바꾸기 버튼")
	go.pressed.emit()
	await frames(3)
	stage = current_scene
	check(stage.name == "DragonBattle", "드래곤 2차전으로 가요")
	check(stage.battle.stats.sword == 29 and stage.battle.stats.max_hp == 130, "준비한 능력치가 싸움에 들어가요")
	stage.skip_intro()
	check(stage.battle.boss().get("hp", 0) == 1500, "드래곤 체력 1,500")
	# 지는 길
	stage.battle.hero_hp = 0
	stage._play_process(0.01)
	check(press_button(stage, "준비_화면으로"), "지면 '준비 화면으로' 버튼")
	await frames(3)
	stage = current_scene
	check(stage.name == "Stage6" and stage.growth.losses == 1 and stage._lost_summary != "", "준비 화면으로 돌아오고 진 횟수가 남아요")
	stage.skip_intro()
	await frames(1)
	check(stage._ui.find_child("RespecButton", true, false) != null, "진 뒤에 능력치 다시 나누기를 할 수 있어요")
	stage._ui.find_child("GoButton", true, false).pressed.emit()
	await frames(3)
	stage = current_scene
	stage.skip_intro()
	await bot_fight(stage, 400.0)
	var b: Dictionary = stage.battle.boss()
	check(stage.phase != stage.Phase.PLAY, "자동 플레이로 싸움이 끝나요 (드래곤 체력 %d, 걸린 시간 %d초, 맞은 것: %s)" % [b.get("hp", 0), int(stage.battle.elapsed), stage.battle.hit_summary()])
	await create_timer(2.0).timeout
	check(stage.find_overlay_button("다음 이야기") != null, "균형형 준비 + 잘 피하면 드래곤을 이겨요")
	check(Save.is_unlocked(7) and Save.get_value("hero_stats", {}, "chapter6").get("sword", 0) == 29, "7장이 열리고 능력치가 남아요")
