extends "res://tests/test_base.gd"
## 7장 '각성과 결말' 자동 확인이에요.
## 실행: godot --headless --path . -s tests/stage7_test.gd


func _run() -> void:
	var stage = await open_scene("res://scenes/chapter7/stage7.tscn")
	check(stage.name == "Stage7", "7장 스테이지가 열려요")
	check(stage.battle.stats.sword == 29, "6장 기록이 없으면 균형형 능력치로 싸워요")
	stage.skip_intro()
	var d: Dictionary = stage.battle.boss()
	check(d.kind == "dragon_final" and d.hp == 900, "다시 일어난 드래곤 (체력 900)")
	d.state = "recover"
	d.wait = 99.0
	d.hp = 10
	stage.battle.hero_x = d.x - 150.0
	stage.battle.walk_target = stage.battle.hero_x
	stage.do_sword()
	check(d.hp == 1 and d.state != "dead", "각성하지 않으면 드래곤이 체력 1로 버텨요")
	check(not stage._gauge_button.visible, "게이지가 덜 차면 각성 버튼이 없어요")
	stage.battle.gauge = 1.0
	d.hp = 500
	stage._update_hud()
	check(not stage._gauge_button.visible, "드래곤 체력이 300보다 많으면 아직 각성 못 해요")
	d.hp = 1
	stage._update_hud()
	check(stage._gauge_button.visible, "드래곤이 약해지고 게이지가 다 차면 각성 버튼이 나와요")
	stage._gauge_button.pressed.emit()
	check(stage.battle.god_left > 0.0 and stage.prince.god, "각성! 똥의 신이 돼요")
	d.state = "windup"
	stage.battle.sword_cd = 0.0
	stage.do_sword()
	check(d.state == "dead", "똥의 신은 언제든 때려서 드래곤을 완전히 물리쳐요")
	stage._play_process(0.01)
	check(stage.phase == stage.Phase.OUTRO, "끝 연출이 나와요")
	await create_timer(2.0).timeout
	check(stage.find_overlay_button("다음 이야기") != null and Save.is_unlocked(8), "결과 창, 8장이 열려요")

	# 처음부터 자동 플레이 (게이지가 차면 각성)
	Save.set_value("hero_stats", {"max_hp": 130, "sword": 29, "chain": 58, "str": 19, "roll_invuln": 0.46, "charge_time": 1.52, "fist": true}, "chapter6")
	stage = await open_scene("res://scenes/chapter7/stage7.tscn")
	check(stage.battle.stats.max_hp == 130 and stage.battle.stats.fist == false, "6장 능력치를 가져오고, 7장에서는 근육 주먹 대신 각성을 써요")
	stage.skip_intro()
	await bot_fight(stage, 400.0)
	check(stage.awakened_once and stage.phase != stage.Phase.PLAY, "자동 플레이: 각성해서 이겨요 (걸린 시간 %d초, 맞은 것: %s)" % [int(stage.battle.elapsed), stage.battle.hit_summary()])
