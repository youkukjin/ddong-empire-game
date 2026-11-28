extends RefCounted
## 서바이버 모드 규칙 (제안: 원작에 없는 놀이 방식이에요).
## 똥 왕자는 알아서 공격하고, 플레이어는 움직이기만 해요. 몰려오는 적을 물리치면 똥 구슬이 떨어지고,
## 구슬을 모아 레벨업하면 카드 3장 중 1장을 골라 강해져요. 5분에 중간 보스, 10분에 무대 보스.
## 좌표: 넓은 마당 위 픽셀 단위 (왕자가 화면 가운데). 화면 그림과 3D는 이 숫자를 따라 그려요.
## 숫자는 처음 정한 값이라 해보고 고쳐요.

const ARENA := 4000.0                 # 마당 한 변 (가운데가 0,0). 둘레는 성벽이에요
const HERO_SPEED := 240.0
const HERO_HP := 120.0
const HERO_RADIUS := 26.0
const HURT_INVULN := 0.8
const REGEN := 0.6                    # 1초에 체력 회복
const MAGNET := 140.0                 # 구슬을 끌어오는 거리
const ENEMY_CAP := 150
const MID_BOSS_TIME := 300.0
const BOSS_TIME := 600.0
const GOD_TIME := 10.0
const GOD_KILLS := 120                # 각성 게이지가 차는 처치 수
const MAX_WEAPONS := 6
const MAX_LEVEL := 5

## 무기: 원작 무기(검, 사슬 철퇴, 근육 주먹)와 제안 무기(똥폭탄, 똥파리 떼)
const WEAPONS := {
	"sword": {"name": "검", "desc": "앞을 반달 모양으로 베어요", "origin": "원작"},
	"chain": {"name": "사슬 철퇴", "desc": "왕자 둘레를 빙글빙글 돌아요", "origin": "원작"},
	"fist": {"name": "근육 주먹", "desc": "가끔 땅을 쾅! 둘레를 밀어내요", "origin": "원작 6장"},
	"bomb": {"name": "똥폭탄", "desc": "가까운 적에게 던지면 펑!", "origin": "제안"},
	"flies": {"name": "똥파리 떼", "desc": "알아서 적을 찾아가 물어요", "origin": "제안"},
}
const PASSIVES := {
	"power": {"name": "힘", "desc": "모든 공격 +12%"},
	"swift": {"name": "민첩", "desc": "이동 속도 +10%"},
	"heart": {"name": "체력", "desc": "최대 체력 +25, 바로 회복"},
	"magnet": {"name": "자석", "desc": "구슬 줍는 거리 +30%"},
	"dumbbell": {"name": "아령", "desc": "공격 간격 -8%"},
}

enum Outcome { ONGOING, WIN, LOSE }

var rng := RandomNumberGenerator.new()
var time := 0.0
var hero := Vector2.ZERO
var facing := Vector2.RIGHT
var hp := HERO_HP
var max_hp := HERO_HP
var invuln := 0.0
var level := 1
var xp := 0
var kills := 0
var coins := 0
var weapons := {"sword": 1}          # 이름 -> 레벨
var passives := {}                   # 이름 -> 단계
var enemies: Array = []              # {id, kind, pos, hp, max_hp, speed, dmg, radius, boss, hit_cd: {}}
var gems: Array = []                 # {pos, value}
var bombs: Array = []                # {pos, target, t}
var flies: Array = []                # {pos, target_id}
var choices: Array = []              # 레벨업 카드 (비어 있지 않으면 멈춰서 골라야 해요)
var god_left := 0.0
var god_gauge := 0.0
var boss_spawned := false
var mid_spawned := false
var boss_defeated := false
var chain_angle := 0.0
var bonus := {"dmg": 1.0, "speed": 1.0, "magnet": 1.0, "cool": 1.0}

var _next_id := 1
var _spawn_acc := 0.0
var _cd := {}                        # 무기 이름 -> 남은 시간


func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


# ------------------------------------------------------------------ 밖에서 부르는 곳

func outcome() -> int:
	if hp <= 0.0:
		return Outcome.LOSE
	if boss_defeated:
		return Outcome.WIN
	return Outcome.ONGOING


func xp_needed() -> int:
	return 5 + (level - 1) * 4 + int(pow(level - 1, 1.35))


func minute() -> int:
	return int(time / 60.0)


func damage_mult() -> float:
	return bonus.dmg * (3.0 if god_left > 0.0 else 1.0)


func awaken() -> bool:
	if god_gauge < 1.0 or god_left > 0.0:
		return false
	god_gauge = 0.0
	god_left = GOD_TIME
	return true


## 레벨업 카드 하나를 골라요.
func choose(i: int) -> void:
	if i < 0 or i >= choices.size():
		return
	var c: Dictionary = choices[i]
	match c.kind:
		"weapon":
			weapons[c.id] = int(weapons.get(c.id, 0)) + 1
		"passive":
			passives[c.id] = int(passives.get(c.id, 0)) + 1
			_apply_passive(c.id)
		"heal":
			hp = minf(max_hp, hp + 40.0)
			coins += 10
	choices = []
	if xp >= xp_needed():
		_level_up()


## 시간을 흘려요. move: 움직일 방향 (길이 0~1). 일어난 일을 돌려줘요.
func tick(delta: float, move: Vector2) -> Array:
	var ev: Array = []
	if outcome() != Outcome.ONGOING or not choices.is_empty():
		return ev
	time += delta
	invuln = maxf(invuln - delta, 0.0)
	hp = minf(max_hp, hp + REGEN * delta)
	god_left = maxf(god_left - delta, 0.0)
	# 왕자 움직이기
	if move.length() > 0.05:
		var m := move.limit_length(1.0)
		hero += m * HERO_SPEED * bonus.speed * delta
		facing = m.normalized()
		var half := ARENA / 2.0 - 40.0
		hero = hero.clamp(Vector2(-half, -half), Vector2(half, half))
	_spawn(delta, ev)
	_move_enemies(delta, ev)
	_weapons(delta, ev)
	_collect(delta, ev)
	# 죽은 적 정리
	for e in enemies.duplicate():
		if e.hp <= 0.0:
			_on_kill(e, ev)
	return ev


# ------------------------------------------------------------------ 적

func spawn_enemy(kind: String, pos: Vector2) -> Dictionary:
	var m := minute()
	var e := {"id": _next_id, "kind": kind, "pos": pos, "boss": false, "hit_cd": {}, "flash": 0.0}
	_next_id += 1
	match kind:
		"warrior":
			e.hp = 9.0 + m * 3.5
			e.speed = 70.0 + m * 6.0
			e.dmg = 4.0 + m * 0.5
			e.radius = 22.0
		"runner":
			e.hp = 6.0 + m * 3.0
			e.speed = 125.0 + m * 6.0
			e.dmg = 3.0 + m * 0.4
			e.radius = 18.0
		"brute":
			e.hp = 45.0 + m * 14.0
			e.speed = 55.0 + m * 3.0
			e.dmg = 8.0 + m * 0.8
			e.radius = 34.0
		"captain":
			e.hp = 900.0
			e.speed = 80.0
			e.dmg = 12.0
			e.radius = 48.0
			e.boss = true
		"demon":
			e.hp = 4000.0
			e.speed = 75.0
			e.dmg = 16.0
			e.radius = 64.0
			e.boss = true
	e.max_hp = e.hp
	enemies.append(e)
	return e


func boss() -> Dictionary:
	for e in enemies:
		if e.kind == "demon":
			return e
	return {}


func _spawn(delta: float, ev: Array) -> void:
	if not mid_spawned and time >= MID_BOSS_TIME:
		mid_spawned = true
		var c := spawn_enemy("captain", _edge_point())
		ev.append({"type": "boss", "enemy": c, "text": "똥 무사 대장이 나타났어요!"})
	if not boss_spawned and time >= BOSS_TIME:
		boss_spawned = true
		var d := spawn_enemy("demon", _edge_point())
		ev.append({"type": "boss", "enemy": d, "text": "똥 대마왕이 나타났어요!"})
	if boss_spawned:
		return
	# 1분마다 조금씩 더 많이 (처음 1초에 1.2마리 → 9분에 약 6마리)
	var rate := 0.9 + time / 60.0 * 0.45
	_spawn_acc += rate * delta
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		if enemies.size() >= ENEMY_CAP:
			_spawn_acc = 0.0
			break
		var kind := "warrior"
		var r := rng.randf()
		if time > 60.0 and r < 0.25:
			kind = "runner"
		elif time > 150.0 and r > 0.92:
			kind = "brute"
		spawn_enemy(kind, _edge_point())


## 화면 바로 밖: 왕자 둘레의 큰 네모 테두리 (3D 카메라가 보는 곳보다 조금 넓어요)
const SPAWN_HALF := Vector2(920.0, 620.0)

func _edge_point() -> Vector2:
	var t := rng.randf_range(-1.0, 1.0)
	var p: Vector2
	match rng.randi() % 4:
		0:
			p = Vector2(t * SPAWN_HALF.x, -SPAWN_HALF.y)
		1:
			p = Vector2(t * SPAWN_HALF.x, SPAWN_HALF.y)
		2:
			p = Vector2(-SPAWN_HALF.x, t * SPAWN_HALF.y)
		_:
			p = Vector2(SPAWN_HALF.x, t * SPAWN_HALF.y)
	# 성벽 밖이면 반대쪽으로 (적이 벽을 뚫고 오지 않게)
	var half := ARENA / 2.0 - 60.0
	var q := hero + p
	if absf(q.x) > half:
		q.x = hero.x - p.x
	if absf(q.y) > half:
		q.y = hero.y - p.y
	return q.clamp(Vector2(-half, -half), Vector2(half, half))


func _move_enemies(delta: float, ev: Array) -> void:
	for e in enemies:
		e.flash = maxf(float(e.flash) - delta, 0.0)
		var to: Vector2 = hero - e.pos
		var d := to.length()
		if d > 1.0:
			e.pos += to / d * e.speed * delta
		# 너무 멀리 떨어진 적은 앞쪽으로 다시 데려와요
		if d > 1500.0 and not e.boss:
			e.pos = _edge_point()
		if d < e.radius + HERO_RADIUS and invuln <= 0.0 and god_left <= 0.0:
			hp -= e.dmg
			invuln = HURT_INVULN
			ev.append({"type": "hurt", "dmg": e.dmg, "pos": hero})
	# 적끼리 살짝 밀어내기 (겹쳐 뭉치지 않게, 가까운 몇 마리만)
	var n := enemies.size()
	for i in n:
		var a: Dictionary = enemies[i]
		for j in range(i + 1, mini(i + 6, n)):
			var b: Dictionary = enemies[j]
			var dv: Vector2 = a.pos - b.pos
			var dist := dv.length()
			var minimum: float = a.radius + b.radius
			if dist > 0.01 and dist < minimum:
				var push := dv / dist * (minimum - dist) * 0.5
				if not a.boss:
					a.pos += push
				if not b.boss:
					b.pos -= push


func damage(e: Dictionary, amount: float, ev: Array, knock := 0.0) -> void:
	if e.hp <= 0.0:
		return
	var dmg := amount * damage_mult()
	e.hp -= dmg
	e.flash = 0.12
	if knock > 0.0 and not e.boss:
		var dir: Vector2 = (e.pos - hero).normalized()
		e.pos += dir * knock
	ev.append({"type": "hit", "enemy": e, "dmg": dmg, "boss": e.boss})


func _on_kill(e: Dictionary, ev: Array) -> void:
	enemies.erase(e)
	kills += 1
	god_gauge = minf(god_gauge + 1.0 / GOD_KILLS, 1.0)
	var value := 1
	match e.kind:
		"brute":
			value = 5
		"captain":
			value = 40
		"demon":
			value = 0
	if value > 0:
		gems.append({"pos": e.pos, "value": value})
	# 가끔 똥빵이 떨어져요 (먹으면 체력 25)
	if not e.boss and rng.randf() < 0.012:
		gems.append({"pos": e.pos + Vector2(14, 0), "value": 0, "heal": 25.0})
	if e.boss:
		coins += 50 if e.kind == "captain" else 200
	if e.kind == "demon":
		boss_defeated = true
	ev.append({"type": "kill", "enemy": e})


# ------------------------------------------------------------------ 무기

func _cool(base: float) -> float:
	return base * bonus.cool


func _ready_weapon(id: String, base: float, delta: float) -> bool:
	_cd[id] = float(_cd.get(id, 0.0)) - delta
	if _cd[id] > 0.0:
		return false
	_cd[id] = _cool(base)
	return true


func _weapons(delta: float, ev: Array) -> void:
	var lv: int
	# 검: 앞을 반달 모양으로 베기 (3레벨부터 뒤도)
	lv = int(weapons.get("sword", 0))
	if lv > 0 and _ready_weapon("sword", 1.15 - lv * 0.07, delta):
		var reach := 120.0 + lv * 12.0
		var dirs := [facing] if lv < 3 else [facing, -facing]
		for dir in dirs:
			for e in enemies:
				var to: Vector2 = e.pos - hero
				if to.length() < reach + e.radius and (to.length() < 30.0 or to.normalized().dot(dir) > 0.1):
					damage(e, 10.0 + lv * 5.0, ev, 18.0)
		ev.append({"type": "swing", "dirs": dirs, "reach": reach})
	# 사슬 철퇴: 둘레를 도는 철퇴 (레벨마다 빨라지고 2·4레벨에 하나씩 늘어요)
	lv = int(weapons.get("chain", 0))
	if lv > 0:
		chain_angle += delta * (2.6 + lv * 0.3)
		for b in chain_balls():
			for e in enemies:
				if (e.pos - b).length() < e.radius + 26.0:
					var cd: float = e.hit_cd.get("chain", 0.0)
					if time >= cd:
						e.hit_cd["chain"] = time + 0.45
						damage(e, 7.0 + lv * 4.0, ev, 12.0)
	# 근육 주먹: 땅을 쾅! 둘레 모두
	lv = int(weapons.get("fist", 0))
	if lv > 0 and _ready_weapon("fist", 4.2 - lv * 0.35, delta):
		var r := 150.0 + lv * 18.0
		for e in enemies:
			if (e.pos - hero).length() < r + e.radius:
				damage(e, 20.0 + lv * 10.0, ev, 70.0)
		ev.append({"type": "slam", "radius": r})
	# 똥폭탄: 가까운 적에게 던지면 0.5초 뒤 펑
	lv = int(weapons.get("bomb", 0))
	if lv > 0 and _ready_weapon("bomb", 2.1 - lv * 0.18, delta):
		for k in (1 if lv < 4 else 2):
			var t := _nearest(380.0, k)
			if not t.is_empty():
				bombs.append({"from": hero, "pos": t.pos + Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20)), "t": 0.5, "lv": lv})
	for b in bombs.duplicate():
		b.t -= delta
		if b.t <= 0.0:
			bombs.erase(b)
			var br: float = 80.0 + b.lv * 10.0
			for e in enemies:
				if (e.pos - b.pos).length() < br + e.radius:
					damage(e, 16.0 + b.lv * 7.0, ev, 30.0)
			ev.append({"type": "boom", "pos": b.pos, "radius": br})
	# 똥파리 떼: 레벨만큼 파리가 날아가 물어요
	lv = int(weapons.get("flies", 0))
	while flies.size() < lv * 2:
		flies.append({"pos": hero, "target": -1, "bite": 0.0, "phase": flies.size() * 1.7})
	for f in flies:
		var target := _enemy_by_id(int(f.target))
		if target.is_empty():
			var near := _nearest(500.0, rng.randi() % 3)
			f.target = near.get("id", -1)
			target = near
		var goal: Vector2 = target.pos if not target.is_empty() else hero + Vector2(cos(time * 3.0 + f.phase), sin(time * 3.0 + f.phase)) * 60.0
		f.pos = (f.pos as Vector2).move_toward(goal, 330.0 * delta)
		f.bite -= delta
		if not target.is_empty() and (f.pos - target.pos).length() < target.radius + 8.0 and f.bite <= 0.0:
			f.bite = 0.6
			damage(target, 4.0 + lv * 2.0, ev)


## 사슬 철퇴 공들의 자리
func chain_balls() -> Array:
	var lv := int(weapons.get("chain", 0))
	var out: Array = []
	if lv <= 0:
		return out
	var count := 1 + int(lv >= 2) + int(lv >= 4)
	var r := 110.0 + lv * 8.0
	for i in count:
		var a := chain_angle + TAU * i / count
		out.append(hero + Vector2(cos(a), sin(a)) * r)
	return out


func _nearest(max_dist: float, skip := 0) -> Dictionary:
	var sorted: Array = []
	for e in enemies:
		var d: float = (e.pos - hero).length()
		if d < max_dist:
			sorted.append([d, e])
	if sorted.is_empty():
		return {}
	sorted.sort_custom(func(a, b): return a[0] < b[0])
	return sorted[mini(skip, sorted.size() - 1)][1]


func _enemy_by_id(id: int) -> Dictionary:
	if id < 0:
		return {}
	for e in enemies:
		if e.id == id:
			return e
	return {}


# ------------------------------------------------------------------ 구슬과 레벨업

func _collect(delta: float, ev: Array) -> void:
	var mag: float = MAGNET * bonus.magnet
	for g in gems.duplicate():
		var to: Vector2 = hero - g.pos
		var d := to.length()
		if d < mag:
			g.pos += to.normalized() * minf(d, 520.0 * delta)
		if d < HERO_RADIUS + 10.0:
			gems.erase(g)
			xp += int(g.value)
			if g.has("heal"):
				hp = minf(max_hp, hp + float(g.heal))
				ev.append({"type": "heal", "amount": g.heal})
			else:
				ev.append({"type": "gem"})
	if xp >= xp_needed() and choices.is_empty():
		_level_up()
		ev.append({"type": "levelup", "level": level})


func _level_up() -> void:
	xp -= xp_needed()
	level += 1
	choices = make_choices()


## 레벨업 카드 3장: 새 무기, 무기 강화, 능력치 중에서 골라요.
func make_choices() -> Array:
	var pool: Array = []
	for id in WEAPONS:
		var lv := int(weapons.get(id, 0))
		if lv == 0 and weapons.size() < MAX_WEAPONS:
			pool.append({"kind": "weapon", "id": id, "title": "새 무기: " + WEAPONS[id].name, "desc": WEAPONS[id].desc})
		elif lv > 0 and lv < MAX_LEVEL:
			pool.append({"kind": "weapon", "id": id, "title": "%s Lv%d" % [WEAPONS[id].name, lv + 1], "desc": "더 세고 빨라져요"})
	for id in PASSIVES:
		if int(passives.get(id, 0)) < MAX_LEVEL:
			pool.append({"kind": "passive", "id": id, "title": PASSIVES[id].name, "desc": PASSIVES[id].desc})
	var out: Array = []
	while out.size() < 3 and not pool.is_empty():
		out.append(pool.pop_at(rng.randi() % pool.size()))
	while out.size() < 3:
		out.append({"kind": "heal", "id": "heal", "title": "똥빵", "desc": "체력 40 회복, 똥전 +10"})
	return out


func _apply_passive(id: String) -> void:
	match id:
		"power":
			bonus.dmg += 0.12
		"swift":
			bonus.speed += 0.10
		"heart":
			max_hp += 25.0
			hp = max_hp
		"magnet":
			bonus.magnet += 0.30
		"dumbbell":
			bonus.cool = maxf(bonus.cool - 0.08, 0.5)


## 이번 판에 받은 똥전 (판이 끝날 때 기기에 더해요)
func earned_coins() -> int:
	return coins + kills / 4 + minute() * 5
