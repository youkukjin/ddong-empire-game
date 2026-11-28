extends "res://tests/test_base.gd"
## 서바이버 화면 자동 확인이에요: 장 고르기에서 들어가서 끌어 움직이고, 카드를 고르고, 끝까지 가요.
## 실행: godot --headless --path . -s tests/survivor_test.gd
const Ads := preload("res://scripts/ads.gd")


func _run() -> void:
	var sel = await open_scene("res://scenes/title/chapter_select.tscn")
	var btn: Button = sel.find_child("Btn_서바이버", true, false)
	check(btn != null and not btn.disabled, "장 고르기에 서바이버 버튼이 열려 있어요")
	btn.pressed.emit()
	await frames(3)
	var s = current_scene
	check(s.scene_file_path.ends_with("survivor.tscn"), "버튼을 누르면 서바이버로 가요")
	check(Save.last_chapter() == 0, "서바이버는 이어하기 장 기록을 건드리지 않아요")
	s.skip_intro()
	await frames(2)
	check(s.phase == s.Phase.PLAY, "설명을 넘기면 바로 시작해요")

	# 끌어서 움직이기
	touch(s, Vector2(400, 400), true)
	drag(s, Vector2(500, 400))
	await frames(20)
	check(s.rules.hero.x > 20.0, "손가락을 오른쪽으로 끌면 오른쪽으로 걸어요")
	touch(s, Vector2(500, 400), false)
	var x: float = s.rules.hero.x
	await frames(10)
	check(absf(s.rules.hero.x - x) < 1.0, "손을 떼면 멈춰요")

	# 레벨업 카드
	s.rules.gems.append({"pos": s.rules.hero, "value": 30})
	await frames(4)
	var card: Button = s.overlay_root.find_child("Card0", true, false)
	check(card != null, "레벨업하면 카드 3장이 나와요")
	check(not s._can_pause(), "카드를 고르는 동안은 멈춤 버튼이 숨어요")
	var t0: float = s.rules.time
	await frames(10)
	check(s.rules.time == t0, "카드를 고르는 동안 적도 멈춰요")
	var guard := 0
	while not s.rules.choices.is_empty() and guard < 10:
		var c: Button = s.overlay_root.find_child("Card0", true, false)
		c.pressed.emit()
		await frames(2)
		guard += 1
	check(s.rules.choices.is_empty() and s.overlay_root.get_child_count() == 0, "카드를 고르면 다시 놀아요")

	# 각성 버튼
	s.rules.god_gauge = 1.0
	await frames(2)
	check(not s.god_button.disabled and s.god_button.text == "각성!", "게이지가 차면 각성 버튼이 켜져요")
	s.god_button.pressed.emit()
	await frames(2)
	check(s.rules.god_left > 9.0, "각성 버튼을 누르면 10초 동안 똥의 신")

	# 멈춤
	s.toggle_pause()
	check(paused and s.find_overlay_button("계속") != null, "멈춤 창이 떠요")
	s.toggle_pause()
	check(not paused, "계속하면 다시 놀아요")

	# 대마왕을 물리치면 이겨요
	s.rules.time = 600.5
	s.rules.boss_spawned = true
	var boss: Dictionary = s.rules.spawn_enemy("demon", s.rules.hero + Vector2(70, 0))
	boss.hp = 1.0
	s.rules.hp = 9999.0
	s.rules.max_hp = 9999.0
	for i in 60:
		await create_timer(0.05).timeout
		while not s.rules.choices.is_empty():
			s.choose_card(0)
		if s.rules.endless:
			break
	check(s.rules.endless and s.phase == s.Phase.PLAY, "대마왕을 물리치면 무한 모드로 계속해요")
	await frames(3)
	check(s.time_label.text.begins_with("∞"), "무한 모드 시간이 보여요")
	s.rules.hp = 0.0
	await frames(3)
	check(s.find_overlay_button("광고 보고 이어하기") != null, "쓰러지면 광고 보고 이어하기를 물어봐요")
	s.find_overlay_button("광고 보고 이어하기").pressed.emit()
	await create_timer(Ads.PRACTICE_SECONDS + 0.6).timeout
	check(s.phase == s.Phase.PLAY and s.rules.hp > 0.0 and s.rules.revived, "광고를 다 보면 다시 일어나요")
	s.rules.hp = 0.0
	await frames(3)
	check(s.phase == s.Phase.RESULT and s.find_overlay_button("다시 하기") != null, "이어하기는 한 번뿐, 다시 쓰러지면 결과 창")
	check(s.find_overlay_button("광고 보고 똥전 2배") != null, "결과 창에 광고 보고 똥전 2배")
	check(Save.survivor_coins() > 0 and Save.survivor_best() > 600.0 and Save.survivor_ranks().size() == 1, "똥전과 기록, 순위가 남아요")

	# 다시 하기 → 지면 결과 창
	s.find_overlay_button("다시 하기").pressed.emit()
	await frames(3)
	s = current_scene
	s.skip_intro()
	await frames(2)
	s.rules.hp = 0.5
	s.rules.spawn_enemy("brute", s.rules.hero)
	await create_timer(0.3).timeout
	if s.find_overlay_button("그만하기"):
		s.find_overlay_button("그만하기").pressed.emit()
		await frames(2)
	check(s.phase == s.Phase.RESULT and s.find_overlay_button("장 고르기") != null, "쓰러지면 결과 창과 장 고르기 버튼")
	sel = await open_scene("res://scenes/title/chapter_select.tscn")
	btn = sel.find_child("Btn_서바이버", true, false)
	check(btn.text.contains("똥전"), "장 고르기에 똥전과 최고 기록이 보여요")
