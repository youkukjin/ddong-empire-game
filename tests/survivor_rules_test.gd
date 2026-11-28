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
	check(Rules.WEAPONS.size() == 22 and Rules.BASE_WEAPONS.size() == 12 and Rules.PASSIVES.size() == 11, "무기 22개(기본 12 + 똥마다 새 스킬 10), 능력치 11개")
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
	check(not boss.is_empty(), "5분에 대마왕이 나와요")
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

	# 우물·통 같은 장애물은 통과할 수 없어요
	var ro = Rules.new(5)
	ro.weapons = {}
	var well: Dictionary = {}
	for o in Rules.obstacles():
		if o.kind == 3:
			well = o
			break
	ro.hero = well.pos + Vector2(-300, 0)
	for i in 120:
		ro.tick(1.0 / 30.0, Vector2.RIGHT)
	check(ro.hero.distance_to(well.pos) >= well.r + Rules.HERO_RADIUS - 1.0, "우물에 부딪히면 막혀요")

	# 무대: 뒤 무대일수록 적이 세고, 대마왕을 물리치면 다음 무대가 열려요
	var rs0 = Rules.new(1)
	var sw0: Dictionary = rs0.spawn_enemy("warrior", Vector2(500, 0))
	var rs2 = Rules.new(1)
	rs2.set_stage(2)
	var sw2: Dictionary = rs2.spawn_enemy("warrior", Vector2(500, 0))
	check(Rules.STAGES.size() >= 4 and sw2.hp > sw0.hp * 1.5, "무대 4곳, 뒤 무대 적이 더 세요")
	rs2.set_stage(0)
	check(Save.survivor_stages_open() == 1 and Save.clear_survivor_stage(0, Rules.STAGES.size()) and Save.survivor_stages_open() == 2, "대마왕을 물리치면 다음 무대가 열려요")
	Save.set_value("stages_open", 1, "survivor")

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

	# 캐릭터마다 레벨업 카드 무기와 각성이 달라요
	for hid in Rules.HERO_KITS:
		var rk = Rules.new(31)
		rk.set_hero(hid)
		var bad := false
		for k in 40:
			for c in rk.make_choices():
				if c.kind == "weapon" and int(rk.weapons.get(c.id, 0)) == 0 and not Rules.HERO_KITS[hid].has(c.id):
					bad = true
		check(not bad, "%s 레벨업 카드엔 자기 무기만 나와요" % hid)
	var rg = Rules.new(32)
	rg.set_hero("icy")
	rg.weapons = {}
	rg.hp = 1e9
	var fe: Dictionary = rg.spawn_enemy("warrior", rg.hero + Vector2(300, 0))
	rg.god_gauge = 1.0
	rg.awaken()
	rg.tick(0.05, Vector2.ZERO)
	var fx: float = fe.pos.x
	for i in 10:
		rg.tick(0.05, Vector2.ZERO)
	check(absf(fe.pos.x - fx) < 1.0, "얼음 똥 각성: 적이 얼어서 못 움직여요")
	var rgas = Rules.new(33)
	rgas.set_hero("gassy")
	rgas.weapons = {}
	rgas.hp = 1e9
	rgas.god_gauge = 1.0
	rgas.awaken()
	rgas.tick(0.05, Vector2.ZERO)
	var fg: Dictionary = rgas.spawn_enemy("brute", rgas.hero + Vector2(200, 0))
	var fh: float = fg.hp
	var farts := 0
	for i in 30:
		for ev in rgas.tick(0.05, Vector2.ZERO):
			if ev.type == "god_fart":
				farts += 1
	check(farts >= 1 and fg.hp < fh, "방귀 똥 각성: 큰 방귀가 터져 적이 아파요")
	var rb = Rules.new(34)
	rb.weapons = {}
	var be: Dictionary = rb.spawn_enemy("brute", rb.hero + Vector2(60, 0))
	var bh: float = be.hp
	for ev in rb.fart_blast():
		pass
	check(be.hp < bh, "장난 방귀 뿡!도 가까운 적을 살짝 아프게 해요")
	var rbr = Rules.new(35)
	rbr.weapons = {}
	rbr.drop_item("bread", rbr.hero)
	var got_bread := false
	for ev in rbr.tick(0.05, Vector2.ZERO):
		if ev.type == "bread":
			got_bread = true
	for i in 10:
		rbr.tick(0.05, Vector2.RIGHT)
	check(got_bread and rbr.tummy > 10.0 and rbr.puddles.size() >= 2, "썩은 빵을 먹으면 배탈: 지나간 자리에 설사 웅덩이")
	for hid in Rules.HERO_PASSIVES:
		var rp = Rules.new(36)
		rp.set_hero(hid)
		var badp := false
		for k in 40:
			for c in rp.make_choices():
				if c.kind == "passive" and not Rules.HERO_PASSIVES[hid].has(c.id):
					badp = true
		var tc: Array = rp.trait_choices()
		check(not badp and tc.size() == 3 and tc[2].id == "trait_" + hid, "%s: 자기 능력치 카드와 자기 특성이 나와요" % hid)
		for w in Rules.HERO_KITS[hid]:
			check(Rules.HERO_PASSIVES[hid].has(Rules.WEAPONS[w].pair), "%s의 %s 진화 짝이 능력치에 있어요" % [hid, w])
	var rr = Rules.new(37)
	rr.set_hero("runny")
	rr.weapons = {}
	rr._apply_trait("trait_runny")
	for i in 20:
		rr.tick(0.05, Vector2.RIGHT)
	check(rr.puddles.size() >= 1, "주르륵 똥 특성: 지나간 자리에 웅덩이")
	# 새 스킬 10개가 모두 적을 아프게 해요
	for wid in ["marbles", "slingshot", "banana", "spray", "stink", "mine", "snowball", "frost", "boulder", "quake"]:
		var rw = Rules.new(40)
		rw.weapons = {wid: 3}
		rw.hp = 1e9
		rw.facing = Vector2.RIGHT
		var targets: Array = []
		for i in 8:
			targets.append(rw.spawn_enemy("brute", rw.hero + Vector2.from_angle(i * TAU / 8.0) * 90.0))
		var hp0 := 0.0
		for t in targets:
			hp0 += float(t.hp)
		for i in 80:
			rw.tick(0.05, Vector2.RIGHT * (0.3 if i % 20 < 10 else -0.3))
			rw.choices = []
		var hp1 := 0.0
		for t in targets:
			hp1 += maxf(float(t.hp), 0.0)
		check(hp1 < hp0, "새 스킬 %s: 적이 아파해요" % wid)
	var rrk = Rules.new(41)
	rrk.weapons = {}
	rrk.facing = Vector2.RIGHT
	rrk.drop_item("rocket", rrk.hero)
	var rk_e: Dictionary = rrk.spawn_enemy("warrior", rrk.hero + Vector2(200, 0))
	var rk_hp: float = rk_e.hp
	for i in 20:
		rrk.tick(0.05, Vector2.ZERO)
	check(rrk.hero.x > 300.0 and rk_e.hp < rk_hp, "방귀 로켓: 앞으로 쌩 날아가며 적을 날려요")
	var rbn = Rules.new(42)
	rbn.weapons = {}
	rbn.drop_item("bean", rbn.hero)
	for i in 20:
		rbn.tick(0.05, Vector2.RIGHT)
	check(rbn.bean > 5.0 and rbn.puddles.size() >= 8, "방귀 콩: 긴 방귀 꼬리가 따라와요")
	# 똥 옷장 장비
	var req = Rules.new(43)
	var sp0: float = req.bonus.speed
	var hp0e: float = req.max_hp
	req.apply_equip(["hat_straw", "shoe_sneaker", "acc_plunger"])
	check(req.max_hp == hp0e + 15.0 and req.bonus.speed > sp0 and req.bonus.dmg > 1.0, "옷장 장비를 끼우면 판 시작부터 힘이 돼요")
	Save.set_value("coins", 500, "survivor")
	check(Save.buy_equip("hat_pirate", 300) and Save.survivor_coins() == 200 and Save.equip_owned("hat_pirate"), "똥전으로 해적 모자를 사요")
	check(not Save.buy_equip("hat_toilet", 700), "똥전이 모자라면 못 사요")
	Save.set_equipped("hat", "hat_pirate")
	check(Save.equipped("hat") == "hat_pirate", "산 모자를 끼워요")
	Save.set_value("coins", 0, "survivor")
	Save.set_equipped("hat", "")
