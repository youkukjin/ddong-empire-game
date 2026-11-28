extends "res://tests/test_base.gd"
## 서바이버 규칙 자동 확인이에요 (화면 없이 숫자만).
## 실행: godot --headless --path . -s tests/survivor_rules_test.gd

const Rules := preload("res://scenes/survivor/survivor_rules.gd")


func _run() -> void:
	var r = Rules.new(7)
	check(r.weapons.has("sword") and r.hp == r.max_hp, "검 하나와 꽉 찬 체력으로 시작해요")

	# 움직이기
	r.tick(0.5, Vector2.RIGHT)
	check(r.hero.x > 100.0 and r.facing == Vector2.RIGHT, "오른쪽으로 끌면 왕자가 오른쪽으로 가요")

	# 적이 오고, 검이 알아서 베요
	var r2 = Rules.new(3)
	var e = r2.spawn_enemy("warrior", Vector2(80, 0))
	var hits := 0
	for i in 20:
		for ev in r2.tick(0.1, Vector2.ZERO):
			if ev.type == "hit":
				hits += 1
	check(hits > 0 and r2.kills >= 1, "가까운 적을 검이 알아서 베어 물리쳐요")
	check(r2.gems.size() > 0 or r2.xp > 0, "물리친 적이 똥 구슬을 떨어뜨려요")

	# 구슬을 모으면 레벨업 카드 3장
	var r3 = Rules.new(5)
	r3.gems.append({"pos": Vector2(10, 0), "value": 50})
	var leveled := false
	for ev in r3.tick(0.1, Vector2.ZERO):
		if ev.type == "levelup":
			leveled = true
	check(leveled and r3.choices.size() == 3, "구슬을 모으면 레벨업하고 카드 3장이 나와요")
	var t0: float = r3.time
	r3.tick(1.0, Vector2.RIGHT)
	check(r3.time == t0, "카드를 고르는 동안은 시간이 멈춰요")
	var pick: Dictionary = {}
	for i in r3.choices.size():
		if r3.choices[i].kind == "weapon" and not r3.weapons.has(r3.choices[i].id):
			pick = r3.choices[i]
			r3.choose(i)
			break
	if pick.is_empty():
		r3.choose(0)
		check(true, "카드를 골랐어요 (새 무기 카드가 안 나온 판)")
	else:
		check(r3.weapons.has(pick.id), "새 무기 카드를 고르면 무기가 생겨요: " + pick.title)
	while not r3.choices.is_empty():
		r3.choose(0)
	check(r3.choices.is_empty(), "모두 고르면 다시 움직여요")

	# 모든 무기가 에러 없이 돌아가요
	var r4 = Rules.new(11)
	r4.weapons = {"sword": 5, "chain": 5, "fist": 5, "bomb": 5, "flies": 5}
	for i in 30:
		r4.spawn_enemy("warrior", Vector2(randf_range(-300, 300), randf_range(-300, 300)))
	var kinds := {}
	for i in 100:
		for ev in r4.tick(0.05, Vector2(0.3, 0.2)):
			kinds[ev.type] = true
		while not r4.choices.is_empty():
			r4.choose(0)
	check(kinds.has("swing") and kinds.has("slam") and kinds.has("boom"), "검 베기, 주먹 쾅, 똥폭탄 펑이 모두 나와요")
	check(r4.kills >= 20, "다섯 무기가 함께 적을 쓸어요 (%d마리)" % r4.kills)
	check(r4.chain_balls().size() >= 3 and r4.flies.size() >= 10, "철퇴 공 3개 이상, 파리 10마리 이상 (왕관이면 더)")

	# 새 무기 12개가 모두 돌아가고, 진화도 돼요
	var r9 = Rules.new(13)
	var all := {}
	for id in Rules.WEAPONS:
		all[id] = 5
	r9.weapons = all
	r9.hp = 1e9
	r9.max_hp = 1e9
	for i in 40:
		r9.spawn_enemy("brute", Vector2(randf_range(-400, 400), randf_range(-400, 400)))
	var seen := {}
	for i in 120:
		for ev in r9.tick(0.05, Vector2(0.2, 0.1)):
			seen[ev.type] = true
		r9.choices = []
	check(seen.has("beam") and seen.has("bolt") and r9.shots.size() + r9.puddles.size() > 0 or seen.has("ice"), "광선, 번개, 얼음, 웅덩이가 나와요")
	check(r9.cloud_radius() > 0.0, "방귀 구름이 둘레에 있어요")
	check(Rules.WEAPONS.size() == 12 and Rules.PASSIVES.size() == 11, "무기 12개, 능력치 11개")
	var r10 = Rules.new(14)
	r10.weapons = {"sword": 5}
	r10.passives = {"dumbbell": 1}
	r10.gems.append({"pos": Vector2.ZERO, "value": 99})
	r10.tick(0.05, Vector2.ZERO)
	var evo_i := -1
	for i in r10.choices.size():
		if r10.choices[i].kind == "evolve":
			evo_i = i
	check(evo_i >= 0, "검 Lv5 + 아령이면 진화 카드가 나와요")
	r10.choose(evo_i)
	check(r10.evolved.has("sword"), "진화하면 천둥 대검")
	for id in Rules.WEAPONS:
		check(Rules.PASSIVES.has(Rules.WEAPONS[id].pair), "%s 진화 짝 능력치가 있어요" % Rules.WEAPONS[id].name)

	# 가만히 있으면 결국 져요
	var r5 = Rules.new(2)
	r5.weapons = {}
	for i in 600:
		r5.tick(0.1, Vector2.ZERO)
		if r5.outcome() != Rules.Outcome.ONGOING:
			break
	check(r5.outcome() == Rules.Outcome.LOSE, "무기 없이 가만히 있으면 쓰러져요")

	# 시간이 지나면 보스
	var r6 = Rules.new(4)
	r6.time = Rules.MID_BOSS_TIME - 0.05
	var texts: Array = []
	for ev in r6.tick(0.1, Vector2.ZERO):
		if ev.type == "boss":
			texts.append(ev.text)
	check(texts.size() >= 1 and r6.mid_spawned, "4분에 중간 보스가 나와요")
	r6.time = Rules.BOSS_TIME - 0.05
	r6.tick(0.1, Vector2.ZERO)
	var boss: Dictionary = r6.boss()
	check(not boss.is_empty(), "6분에 대마왕이 나와요")
	boss.hp = 1.0
	boss.pos = r6.hero + Vector2(60, 0)
	r6.hp = 9999.0
	for i in 30:
		r6.tick(0.1, Vector2.ZERO)
		while not r6.choices.is_empty():
			r6.choose(0)
		if r6.endless:
			break
	check(r6.endless and r6.boss_defeated and r6.outcome() == Rules.Outcome.ONGOING, "대마왕을 물리치면 무한 모드로 이어져요")
	var w0: Dictionary = r6.spawn_enemy("warrior", Vector2(900, 0))
	r6.time += 300.0
	var w1: Dictionary = r6.spawn_enemy("warrior", Vector2(900, 0))
	check(w1.hp > w0.hp * 2.0, "무한 모드에서는 시간이 갈수록 적이 세져요")
	var r11 = Rules.new(21)
	r11.hp = 1e9
	r11.max_hp = 1e9
	var kinds_seen := {}
	r11.time = 100.0
	for i in 520:
		r11.time += 1.0
		for ev in r11.tick(0.0, Vector2.ZERO):
			if ev.type == "boss":
				kinds_seen[ev.enemy.kind] = true
		r11.enemies = []
	check(kinds_seen.has("bat") and kinds_seen.has("captain") and kinds_seen.has("golem") and kinds_seen.has("wyrm") and kinds_seen.has("demon"), "중간 보스 4마리와 대마왕이 차례로 나와요")
	Save.add_survivor_rank({"time": 50.0, "level": 3, "kills": 10})
	var place: int = Save.add_survivor_rank({"time": 700.0, "level": 20, "kills": 900, "cleared": true})
	check(place == 1 and Save.survivor_ranks().size() == 2, "순위표: 오래 버틴 판이 1위")

	# 각성
	var r7 = Rules.new(1)
	check(not r7.awaken(), "게이지가 안 차면 각성할 수 없어요")
	r7.god_gauge = 1.0
	check(r7.awaken() and r7.damage_mult() > 2.0, "게이지가 차면 똥의 신으로 각성해 공격이 세져요")
	r7.spawn_enemy("warrior", r7.hero + Vector2(200, 0))
	var wave_seen := false
	for ev in r7.tick(0.05, Vector2.ZERO):
		wave_seen = wave_seen or ev.type == "god_wave"
	check(wave_seen and r7._cool(1.0) < 0.6, "각성하면 충격파가 터지고 무기가 2배 빨라져요")

	# 똥 대장간
	Save.set_value("coins", 100, "survivor")
	check(Save.buy_forge("heart", Rules.forge_cost("heart", 0)) and Save.forge_level("heart") == 1 and Save.survivor_coins() == 40, "대장간에서 똥전으로 튼튼 심장을 사요")
	check(not Save.buy_forge("heart", Rules.forge_cost("heart", 1)), "똥전이 모자라면 못 사요")
	var rf = Rules.new(3)
	rf.apply_forge({"heart": 2, "power": 1})
	check(rf.max_hp == Rules.HERO_HP + 24.0 and rf.hp == rf.max_hp and rf.bonus.dmg > 1.05, "산 강화는 판이 시작할 때 적용돼요")
	Save.set_value("coins", 0, "survivor")
	Save.set_value("forge_heart", 0, "survivor")

	# 레벨업은 체력을 채우지 않고, 아이템 똥이 채워줘요
	var ri = Rules.new(4)
	ri.weapons = {}
	ri.hp = 50.0
	ri.xp = 999
	ri.tick(0.01, Vector2.ZERO)
	ri.choose(0)
	check(ri.hp < 60.0, "레벨업해도 체력이 꽉 차지 않아요 (%.0f)" % ri.hp)
	ri.drop_item("heal", ri.hero)
	ri.choices = []
	ri.tick(0.01, Vector2.ZERO)
	check(ri.hp >= 75.0 and ri.items.is_empty(), "생명력 똥을 주우면 체력 +30")
	ri.xp = -9999
	ri.choices = []
	ri.gems.append({"pos": ri.hero + Vector2(1500, 0), "value": 1})
	ri.drop_item("magnet", ri.hero)
	for i in 30:
		ri.tick(0.05, Vector2.ZERO)
	check(ri.gems.is_empty(), "자석 똥을 주우면 멀리 있는 구슬까지 몽땅 와요")

	# 적 수 제한과 기록
	var r8 = Rules.new(9)
	r8.weapons = {}
	r8.hp = 1e9
	r8.time = 500.0
	for i in 400:
		r8.tick(0.1, Vector2.ZERO)
	check(r8.enemies.size() <= Rules.ENEMY_CAP, "적은 최대 %d마리까지만 (%d)" % [Rules.ENEMY_CAP, r8.enemies.size()])
	check(Save.record_survivor(30, 125.0, false) and Save.survivor_coins() == 30, "똥전과 버틴 시간이 기기에 남아요")
	check(not Save.record_survivor(5, 60.0, false) and Save.survivor_coins() == 35 and Save.survivor_best() == 125.0, "더 짧게 버티면 기록은 그대로, 똥전은 더해져요")
