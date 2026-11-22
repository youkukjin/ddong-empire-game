extends "res://tests/test_base.gd"
## 5~7장이 함께 쓰는 싸움 규칙 자동 확인이에요.
## 실행: godot --headless --path . -s tests/battle_test.gd

const Battle := preload("res://scripts/battle/battle_rules.gd")


func _run() -> void:
	var b := Battle.new({}, 5)
	check(b.hero_hp == 100 and b.stats.sword == 10 and b.stats.chain == 20, "기본 능력치: 체력 100, 검 10, 사슬 20 (6장 설계 Lv5)")
	var w := b.spawn("warrior", 500.0)
	b.hero_x = 300.0
	b.walk_target = 300.0
	var wound := false
	for i in 200:
		for e in b.tick(0.05):
			if e.type == "windup":
				wound = true
		if wound:
			break
	check(wound and w.state == "windup", "무사가 다가와서 칼을 들어요 (경고)")
	b.tick(0.95)
	check(b.hero_hp == 88 and b.hits_taken.get("칼 휘두르기", 0) == 1, "경고 뒤에 안 피하면 맞아요 (-12)")
	# 다음 공격은 직전에 굴러서 피해요
	while w.state != "windup":
		b.tick(0.05)
	b.tick(0.8)
	b.roll(1.0)
	var dodged := false
	for e in b.tick(0.15):
		if e.type == "dodge":
			dodged = true
	check(dodged and b.hero_hp == 88 and b.gauge > 0.0, "경고 끝에 구르면 안 다치고 게이지가 차요")
	b.roll_left = 0.0
	b.hero_x = w.x - 100.0
	b.sword_cd = 0.0
	check(not b.sword().is_empty() and w.hp == 30, "검이 닿으면 10 피해")
	b.sword_cd = 0.0
	b.facing = 1.0
	w.state = "windup"
	w.attack = {"name": "칼 휘두르기", "type": "melee", "dmg": 10, "warn": 0.9, "range": 70.0, "recover": 1.4}
	var old_x: float = w.x
	var r := b.chain()
	check(r.hit.size() == 1 and w.hp == 10 and w.x > old_x and w.state == "recover", "사슬 무기: 20 피해, 무사를 밀고 공격을 끊어요")

	var d := Battle.new({"chain_kind": "pierce", "fist": true, "str": 30}, 5)
	var dr := d.spawn("dragon", 1000.0)
	check(Battle.dragon_phase(1500) == 1 and Battle.dragon_phase(900) == 2 and Battle.dragon_phase(400) == 3, "드래곤 단계: 1,000과 450에서 바뀌어요")
	d.hero_x = 300.0
	d.facing = 1.0
	d.chain()
	check(dr.hp == 1500 and dr.blocked, "드래곤은 공격 틈이 아니면 막아요 (팅!)")
	dr.state = "recover"
	dr.wait = 99.0
	d.chain()
	check(dr.hp == 1480, "꿰뚫는 사슬은 멀리(900)까지 닿아요")
	dr.hp = 400
	d.tick(0.01)
	dr.state = "recover"
	check(dr.phase == 3, "체력 450 아래면 3단계")
	d.chain()
	check(dr.hp == 360, "3단계 가슴 비늘: 꿰뚫는 사슬 2배 (40)")
	d.gauge = 1.0
	var hit := d.fist()
	check(hit == dr and dr.hp == 60 and dr.state == "down", "근육 주먹: 힘 × 10 = 300, 드래곤이 3초 쓰러져요")
	check(d.gauge == 0.0 and d.fist().is_empty(), "게이지를 다 쓰면 다시 모아야 해요")

	var s := Battle.new({"chain_kind": "spin"}, 5)
	var sd := s.spawn("dragon", 600.0)
	sd.hp = 900
	sd.phase = 2
	sd.state = "windup"
	sd.airborne = true
	sd.target_x = 500.0
	sd.attack = {"name": "꼬리치기", "type": "fly_tail", "dmg": 25, "warn": 0.7, "range": 200.0, "recover": 3.0}
	s.hero_x = 500.0
	check(s.sword_target().is_empty(), "날아오른 드래곤은 검으로 못 쳐요")
	var sr := s.chain()
	check(sr.blocked and sd.state == "recover" and not sd.airborne, "빙글 사슬로 꼬리치기를 막으면 드래곤이 내려와요")

	var m := Battle.new({}, 5)
	m.secrets["보라색 광선"] = true
	check(is_equal_approx(m.warn_time({"name": "보라색 광선", "warn": 1.0}), 1.3), "작전 회의로 알아낸 공격은 경고가 0.3초 일찍")
	var dm := m.spawn("demon", 900.0)
	dm.hp = 240
	m.tick(0.01)
	check(dm.phase == 2, "대마왕은 체력 절반 아래면 화가 나요")
	var summoned := false
	for i in 400:
		for e in m.tick(0.05):
			if e.type == "summon":
				summoned = true
		m.hero_hp = 100
		if summoned:
			break
	check(summoned and m.alive_enemies().size() == 3, "화난 대마왕은 무사 둘을 불러요")
	m.awaken(5.0)
	check(m.god_left == 0.0, "게이지가 덜 차면 각성 못 해요")
	m.gauge = 1.0
	check(m.awaken(5.0) and m.is_invulnerable() and m.damage_mult() == 3.0 and m.charge_ratio(0.0) == 1.0, "각성: 안 다치고 공격 3배, 사슬을 바로 써요")
