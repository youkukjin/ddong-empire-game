extends "res://tests/test_base.gd"
## 5장 '무사들과 대마왕' 자동 확인이에요.
## 실행: godot --headless --path . -s tests/stage5_test.gd


func _run() -> void:
	var stage = await open_scene("res://scenes/chapter5/stage5.tscn")
	check(stage.name == "Stage5", "5장 스테이지가 열려요")
	stage.skip_intro()
	check(stage.phase == stage.Phase.PLAY and stage.battle.alive_enemies().size() == 2, "첫 무사 무리 2명이 나와요")
	# 조작 확인
	tap(stage, Vector2(450, 500))
	check(stage.battle.walk_target == 450.0, "빈 곳을 톡 하면 걸어가요")
	swipe(stage, Vector2(640, 500), Vector2.LEFT)
	check(stage.battle.is_rolling(), "옆으로 쓸면 굴러요")
	stage.battle.roll_left = 0.0
	hold(stage, Vector2(1000, 500), 0.5)
	check(stage.battle.hits_landed == 0, "힘이 덜 모이면 사슬이 안 나가요")
	stage.battle.hero_x = 700.0
	stage.battle.walk_target = 700.0
	hold(stage, Vector2(1000, 500), 1.8)
	check(stage.battle.hits_landed == 1, "꾹 눌렀다 떼면 누른 쪽으로 사슬 무기가 날아가요")
	# 자동 플레이로 끝까지
	await bot_fight(stage, 240.0)
	check(stage.wave == 2, "무사 두 무리를 물리치면 대마왕이 나와요")
	check(stage.phase != stage.Phase.PLAY, "자동 플레이로 싸움이 끝나요")
	await create_timer(1.8).timeout
	var won: bool = stage.find_overlay_button("다음 이야기") != null
	check(won, "단순한 플레이(검 + 구르기)로도 대마왕을 이겨요 (체력 %d, %s)" % [stage.battle.hero_hp, stage.battle.hit_summary()])
	check(Save.is_unlocked(6), "6장이 열려요")
	# 대마왕부터 다시 하기
	stage = await open_scene("res://scenes/chapter5/stage5.tscn")
	stage.skip_intro()
	stage.wave = 2
	stage.battle.enemies.clear()
	stage._spawn_wave()
	stage.battle.hero_hp = 0
	stage._play_process(0.01)
	check(stage.find_overlay_button("대마왕부터") != null, "대마왕에게 지면 '대마왕부터' 버튼이 나와요")
	press_button(stage, "대마왕부터")
	await frames(3)
	stage = current_scene
	check(stage.from_checkpoint and stage.wave == 2, "대마왕부터 다시 시작해요")
	stage.skip_intro()
	check(stage.battle.boss().get("kind", "") == "demon", "바로 대마왕이 나와요")
