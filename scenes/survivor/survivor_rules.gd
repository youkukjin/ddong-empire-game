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

const MAX_PASSIVES := 6

## 무기 12개. pair: 이 무기가 Lv5이고 짝 능력치를 가지면 진화 카드가 나와요.
const WEAPONS := {
	"sword": {"name": "검", "desc": "앞을 반달 모양으로 베어요", "pair": "dumbbell", "evo": "천둥 대검", "evo_desc": "사방을 크게 베고 번개가 쳐요"},
	"chain": {"name": "사슬 철퇴", "desc": "왕자 둘레를 빙글빙글 돌아요", "pair": "swift", "evo": "회오리 철퇴", "evo_desc": "철퇴 5개가 아주 빠르게 돌아요"},
	"fist": {"name": "근육 주먹", "desc": "가끔 땅을 쾅! 둘레를 밀어내요", "pair": "heart", "evo": "거인 주먹", "evo_desc": "더 넓게 쾅! 적이 잠깐 멈춰요"},
	"bomb": {"name": "똥폭탄", "desc": "가까운 적에게 던지면 펑!", "pair": "power", "evo": "똥화산", "evo_desc": "폭탄이 비처럼 쏟아져요"},
	"flies": {"name": "똥파리 떼", "desc": "알아서 적을 찾아가 물어요", "pair": "magnet", "evo": "말벌 군단", "evo_desc": "파리 16마리가 세게 쏘아요"},
	"beam": {"name": "보라 광선", "desc": "가까운 적 쪽으로 쭉 뻗어 꿰뚫어요", "pair": "crown", "evo": "무지개 광선", "evo_desc": "광선이 빙글 돌며 사방을 쏴요"},
	"boomerang": {"name": "똥 부메랑", "desc": "던지면 날아갔다 돌아와요", "pair": "luck", "evo": "황금 부메랑", "evo_desc": "커다란 부메랑 여러 개"},
	"cloud": {"name": "방귀 구름", "desc": "둘레의 적이 계속 아파하고 느려져요", "pair": "milk", "evo": "방귀 폭풍", "evo_desc": "구름이 훨씬 크고 독해져요"},
	"lightning": {"name": "번개 똥", "desc": "하늘에서 번개가 적에게 떨어져요", "pair": "book", "evo": "천둥 폭풍", "evo_desc": "번개가 한꺼번에 우르르"},
	"thorns": {"name": "가시 갑옷", "desc": "부딪힌 적을 찌르고, 맞으면 가시가 튀어요", "pair": "armor", "evo": "드래곤 비늘", "evo_desc": "가시가 두 배, 받는 피해 줄어요"},
	"puddle": {"name": "똥 웅덩이", "desc": "웅덩이에 들어온 적이 느려지고 아파요", "pair": "cape", "evo": "똥 늪", "evo_desc": "커다란 늪이 왕자를 따라와요"},
	"ice": {"name": "얼음 똥", "desc": "사방으로 얼음 조각을 쏴서 얼려요", "pair": "crown", "evo": "눈보라", "evo_desc": "얼음 조각이 많아지고 꽁꽁 얼려요"},
}
## 능력치 11개 (한 판에 6개까지)
const PASSIVES := {
	"power": {"name": "힘", "desc": "모든 공격 +12%", "max": 5},
	"swift": {"name": "민첩", "desc": "이동 속도 +10%", "max": 5},
	"heart": {"name": "체력", "desc": "최대 체력 +25, 바로 회복", "max": 5},
	"magnet": {"name": "자석", "desc": "구슬 줍는 거리 +30%", "max": 5},
	"dumbbell": {"name": "아령", "desc": "공격 간격 -8%", "max": 5},
	"cape": {"name": "왕 망토", "desc": "공격 범위 +12%", "max": 5},
	"crown": {"name": "금왕관", "desc": "던지고 쏘는 개수 +1", "max": 3},
	"armor": {"name": "갑옷", "desc": "받는 피해 -8%", "max": 5},
	"luck": {"name": "행운 네잎", "desc": "큰 구슬과 똥빵이 더 자주", "max": 5},
	"milk": {"name": "똥우유", "desc": "체력이 더 빨리 차요", "max": 5},
	"book": {"name": "지혜의 책", "desc": "구슬 경험치 +12%", "max": 5},
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
var shots: Array = []                # 날아가는 것 {kind, pos, vel, life, r, dmg, pierce, hit}
var puddles: Array = []              # {pos, r, life, dmg}
var evolved := {}                    # 진화한 무기 이름 -> true
var xp_frac := 0.0
var flies: Array = []                # {pos, target_id}
var choices: Array = []              # 레벨업 카드 (비어 있지 않으면 멈춰서 골라야 해요)
var god_left := 0.0
var god_gauge := 0.0
var boss_spawned := false
var mid_spawned := false
var boss_defeated := false
var chain_angle := 0.0
var bonus := {"dmg": 1.0, "speed": 1.0, "magnet": 1.0, "cool": 1.0, "area": 1.0, "amount": 0, "armor": 0.0, "luck": 1.0, "regen": 0.0, "xp": 1.0}

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
	return 5 + (level - 1) * 3 + int(pow(level - 1, 1.2))


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
		"evolve":
			evolved[c.id] = true
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
	hp = minf(max_hp, hp + (REGEN + bonus.regen) * delta)
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


## 화면 바로 밖: 왕자 둘레의 네모 테두리 (세로 화면 3D 카메라가 보는 곳보다 조금 넓어요.
## 카메라가 비스듬해서 위쪽이 더 멀리 보여요)
const SPAWN_MIN := Vector2(-760.0, -1500.0)
const SPAWN_MAX := Vector2(680.0, 640.0)

func _edge_point() -> Vector2:
	var t := rng.randf()
	var p: Vector2
	match rng.randi() % 4:
		0:
			p = Vector2(lerpf(SPAWN_MIN.x, SPAWN_MAX.x, t), SPAWN_MIN.y)
		1:
			p = Vector2(lerpf(SPAWN_MIN.x, SPAWN_MAX.x, t), SPAWN_MAX.y)
		2:
			p = Vector2(SPAWN_MIN.x, lerpf(SPAWN_MIN.y, SPAWN_MAX.y, t))
		_:
			p = Vector2(SPAWN_MAX.x, lerpf(SPAWN_MIN.y, SPAWN_MAX.y, t))
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
		var spd: float = e.speed
		if time < float(e.get("slow_until", 0.0)):
			spd *= float(e.get("slow", 1.0))
		if d > 1.0:
			e.pos += to / d * spd * delta
		# 너무 멀리 떨어진 적은 앞쪽으로 다시 데려와요
		if d > 1500.0 and not e.boss:
			e.pos = _edge_point()
		if d < e.radius + HERO_RADIUS and invuln <= 0.0 and god_left <= 0.0:
			var taken: float = e.dmg * maxf(0.4, 1.0 - bonus.armor - (0.15 if evolved.has("thorns") else 0.0))
			hp -= taken
			invuln = HURT_INVULN
			ev.append({"type": "hurt", "dmg": taken, "pos": hero})
			_thorn_burst(ev)
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
	if not e.boss and value == 1 and rng.randf() < 0.03 * (bonus.luck - 1.0):
		gems[gems.size() - 1].value = 5
	if not e.boss and rng.randf() < 0.012 * bonus.luck:
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
	_cd[id] = _cool(maxf(base, 0.15))
	return true


func lv_of(id: String) -> int:
	return int(weapons.get(id, 0))


func _slow(e: Dictionary, factor: float, t: float) -> void:
	if e.boss:
		factor = lerpf(factor, 1.0, 0.5)
	e.slow = factor
	e.slow_until = time + t


func _hit_once(e: Dictionary, key: String, gap: float) -> bool:
	var cd: float = e.hit_cd.get(key, 0.0)
	if time < cd:
		return false
	e.hit_cd[key] = time + gap
	return true


func _weapons(delta: float, ev: Array) -> void:
	var lv: int
	var area: float = bonus.area
	var amount: int = bonus.amount
	# 검: 앞을 반달 모양으로 베기 (3레벨부터 뒤도). 진화: 사방 + 번개
	lv = lv_of("sword")
	if lv > 0 and _ready_weapon("sword", (1.15 - lv * 0.07) * (0.75 if evolved.has("sword") else 1.0), delta):
		var evo := evolved.has("sword")
		var reach := (120.0 + lv * 12.0) * area * (1.4 if evo else 1.0)
		var dirs := [facing] if lv < 3 else [facing, -facing]
		if evo:
			dirs = [facing, -facing, facing.orthogonal(), -facing.orthogonal()]
		for dir in dirs:
			for e in enemies:
				var to: Vector2 = e.pos - hero
				if to.length() < reach + e.radius and (to.length() < 30.0 or to.normalized().dot(dir) > 0.1):
					damage(e, (10.0 + lv * 5.0) * (1.8 if evo else 1.0), ev, 18.0)
		ev.append({"type": "swing", "dirs": dirs, "reach": reach, "evolved": evo})
		if evo:
			var t := _nearest(500.0, rng.randi() % 4)
			if not t.is_empty():
				_strike(t.pos, 60.0, 30.0, ev)
	# 사슬 철퇴: 둘레를 도는 철퇴
	lv = lv_of("chain")
	if lv > 0:
		var evo := evolved.has("chain")
		chain_angle += delta * (2.6 + lv * 0.3) * (1.6 if evo else 1.0)
		for b in chain_balls():
			for e in enemies:
				if (e.pos - b).length() < e.radius + 26.0 * area and _hit_once(e, "chain", 0.45):
					damage(e, (7.0 + lv * 4.0) * (1.5 if evo else 1.0), ev, 12.0)
	# 근육 주먹: 땅을 쾅! 진화: 더 넓고 적이 멈춰요
	lv = lv_of("fist")
	if lv > 0 and _ready_weapon("fist", (4.2 - lv * 0.35) * (0.7 if evolved.has("fist") else 1.0), delta):
		var evo := evolved.has("fist")
		var r := (150.0 + lv * 18.0) * area * (1.5 if evo else 1.0)
		for e in enemies:
			if (e.pos - hero).length() < r + e.radius:
				damage(e, (20.0 + lv * 10.0) * (2.0 if evo else 1.0), ev, 70.0)
				if evo:
					_slow(e, 0.0, 1.0)
		ev.append({"type": "slam", "radius": r, "evolved": evo})
	# 똥폭탄: 가까운 적에게 던지면 0.5초 뒤 펑. 진화: 폭탄 비
	lv = lv_of("bomb")
	if lv > 0 and _ready_weapon("bomb", (2.1 - lv * 0.18) * (0.6 if evolved.has("bomb") else 1.0), delta):
		var count := (1 if lv < 4 else 2) + amount + (3 if evolved.has("bomb") else 0)
		for k in count:
			var t := _nearest(420.0, k)
			var at: Vector2 = t.pos if not t.is_empty() else hero + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(120, 300)
			if t.is_empty() and k > 0:
				continue
			if not t.is_empty() or evolved.has("bomb"):
				bombs.append({"from": hero, "pos": at + Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20)), "t": 0.5, "lv": lv})
	for b in bombs.duplicate():
		b.t -= delta
		if b.t <= 0.0:
			bombs.erase(b)
			var br: float = (80.0 + b.lv * 10.0) * area * (1.4 if evolved.has("bomb") else 1.0)
			for e in enemies:
				if (e.pos - b.pos).length() < br + e.radius:
					damage(e, (16.0 + b.lv * 7.0) * (1.5 if evolved.has("bomb") else 1.0), ev, 30.0)
			ev.append({"type": "boom", "pos": b.pos, "radius": br})
	# 똥파리 떼: 레벨만큼 파리가 날아가 물어요. 진화: 말벌 16마리
	lv = lv_of("flies")
	var fly_count := 0 if lv == 0 else (16 if evolved.has("flies") else lv * 2 + amount * 2)
	while flies.size() < fly_count:
		flies.append({"pos": hero, "target": -1, "bite": 0.0, "phase": flies.size() * 1.7})
	for f in flies:
		var target := _enemy_by_id(int(f.target))
		if target.is_empty():
			var near := _nearest(500.0, rng.randi() % 3)
			f.target = near.get("id", -1)
			target = near
		var goal: Vector2 = target.pos if not target.is_empty() else hero + Vector2(cos(time * 3.0 + f.phase), sin(time * 3.0 + f.phase)) * 60.0
		f.pos = (f.pos as Vector2).move_toward(goal, (330.0 if not evolved.has("flies") else 450.0) * delta)
		f.bite -= delta
		if not target.is_empty() and (f.pos - target.pos).length() < target.radius + 8.0 and f.bite <= 0.0:
			f.bite = 0.6
			damage(target, (4.0 + lv * 2.0) * (2.0 if evolved.has("flies") else 1.0), ev)
	# 보라 광선: 가까운 적 쪽으로 쭉, 줄 위의 적 모두. 진화: 빙글 도는 무지개 광선
	lv = lv_of("beam")
	if lv > 0 and _ready_weapon("beam", (3.0 - lv * 0.25) * (0.5 if evolved.has("beam") else 1.0), delta):
		var evo := evolved.has("beam")
		var length := (650.0 + lv * 30.0) * area
		var width := (26.0 + lv * 3.0) * area * (1.5 if evo else 1.0)
		var dirs: Array = []
		var n := 1 + amount + (1 if lv >= 4 else 0)
		if evo:
			for i in 6:
				dirs.append(Vector2.from_angle(time * 1.5 + TAU * i / 6.0))
		else:
			for k in n:
				var t := _nearest(length, k)
				if not t.is_empty():
					dirs.append((t.pos - hero).normalized())
		for dir in dirs:
			for e in enemies:
				var to: Vector2 = e.pos - hero
				var along := to.dot(dir)
				if along > -10.0 and along < length and absf(to.cross(dir)) < width + e.radius:
					damage(e, (15.0 + lv * 8.0) * (1.4 if evo else 1.0), ev, 10.0)
			ev.append({"type": "beam", "from": hero, "dir": dir, "length": length, "width": width, "evolved": evo})
	# 똥 부메랑: 앞으로 던지면 돌아와요
	lv = lv_of("boomerang")
	if lv > 0 and _ready_weapon("boomerang", 2.3 - lv * 0.15, delta):
		var evo := evolved.has("boomerang")
		var n := 1 + amount + (1 if lv >= 4 else 0) + (2 if evo else 0)
		for k in n:
			var dir := facing.rotated((k - (n - 1) / 2.0) * 0.45)
			_next_id += 1
			shots.append({"kind": "boomerang", "sid": _next_id, "dir": dir, "t": 0.0, "T": 1.4, "reach": (300.0 + lv * 25.0) * area,
				"pos": hero, "r": (44.0 if not evo else 70.0) * area, "dmg": (12.0 + lv * 6.0) * (1.6 if evo else 1.0), "pierce": 999, "hit": {}})
	# 방귀 구름: 둘레에 계속
	lv = lv_of("cloud")
	if lv > 0 and _ready_weapon("cloud", 0.5, delta):
		var evo := evolved.has("cloud")
		var r := cloud_radius()
		for e in enemies:
			if (e.pos - hero).length() < r + e.radius:
				damage(e, (3.0 + lv * 2.0) * (2.2 if evo else 1.0), ev)
				_slow(e, 0.7 if not evo else 0.45, 0.6)
	# 번개 똥: 아무 적에게나 번개
	lv = lv_of("lightning")
	if lv > 0 and _ready_weapon("lightning", 2.6 - lv * 0.2, delta):
		var evo := evolved.has("lightning")
		var n := 1 + lv / 2 + amount + (4 if evo else 0)
		var near: Array = []
		for e in enemies:
			if (e.pos - hero).length() < 650.0:
				near.append(e)
		for k in mini(n, near.size()):
			var e: Dictionary = near.pop_at(rng.randi() % near.size())
			_strike(e.pos, (50.0 if not evo else 90.0) * area, (25.0 + lv * 10.0) * (1.4 if evo else 1.0), ev)
	# 가시 갑옷: 부딪힌 적을 찔러요
	lv = lv_of("thorns")
	if lv > 0 and _ready_weapon("thorns", 0.8, delta):
		for e in enemies:
			if (e.pos - hero).length() < HERO_RADIUS + e.radius + 30.0 * area:
				damage(e, (4.0 + lv * 3.0) * (2.0 if evolved.has("thorns") else 1.0), ev, 25.0)
	# 똥 웅덩이: 근처에 웅덩이. 진화: 큰 늪이 따라와요
	lv = lv_of("puddle")
	if lv > 0 and _ready_weapon("puddle", 3.0 - lv * 0.2, delta):
		var evo := evolved.has("puddle")
		for k in (1 + amount / 2):
			var at := hero + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(60.0, 240.0)
			puddles.append({"pos": at, "r": (70.0 + lv * 8.0) * area, "life": 3.0 + lv * 0.4, "dmg": 4.0 + lv * 3.0, "follow": false})
		if evo and not puddles.any(func(pd): return pd.follow):
			puddles.append({"pos": hero, "r": 200.0 * area, "life": 9999.0, "dmg": 10.0 + lv * 3.0, "follow": true})
	for pd in puddles.duplicate():
		pd.life -= delta
		if pd.follow:
			pd.pos = (pd.pos as Vector2).move_toward(hero, 150.0 * delta)
			if not evolved.has("puddle"):
				pd.life = 0.0
		if pd.life <= 0.0:
			puddles.erase(pd)
			continue
		for e in enemies:
			if (e.pos - pd.pos).length() < pd.r + e.radius * 0.5:
				_slow(e, 0.5, 0.3)
				if _hit_once(e, "puddle", 0.4):
					damage(e, pd.dmg, ev)
	# 얼음 똥: 사방으로 얼음 조각
	lv = lv_of("ice")
	if lv > 0 and _ready_weapon("ice", 2.4 - lv * 0.15, delta):
		var evo := evolved.has("ice")
		var n := 4 + lv + amount * 2 + (6 if evo else 0)
		var off := rng.randf() * TAU
		for k in n:
			var dir := Vector2.from_angle(off + TAU * k / n)
			shots.append({"kind": "ice", "pos": hero, "vel": dir * 460.0, "life": 1.1 * area, "r": 18.0 * area,
				"dmg": (8.0 + lv * 4.0) * (1.5 if evo else 1.0), "pierce": 3 if evo else 1, "hit": {}, "freeze": 0.0 if evo else 0.35})
		ev.append({"type": "ice"})
	_move_shots(delta, ev)


## 날아가는 것들 (부메랑, 얼음 조각)
func _move_shots(delta: float, ev: Array) -> void:
	for sh in shots.duplicate():
		if sh.kind == "boomerang":
			sh.t += delta
			var k: float = sh.t / sh.T
			sh.pos = hero + sh.dir * sh.reach * 4.0 * k * (1.0 - k)
			if k >= 1.0:
				shots.erase(sh)
				continue
		else:
			sh.life -= delta
			sh.pos += sh.vel * delta
			if sh.life <= 0.0:
				shots.erase(sh)
				continue
		for e in enemies:
			if (e.pos - sh.pos).length() < e.radius + sh.r:
				if sh.kind == "boomerang":
					if not _hit_once(e, "b%d" % sh.sid, 0.4):
						continue
					damage(e, sh.dmg, ev, 45.0)
					ev.append({"type": "bhit", "pos": e.pos, "evolved": evolved.has("boomerang")})
				elif not sh.hit.has(e.id):
					sh.hit[e.id] = true
					damage(e, sh.dmg, ev)
					_slow(e, sh.freeze, 1.5)
					sh.pierce -= 1
					if sh.pierce <= 0:
						shots.erase(sh)
						break


func _strike(at: Vector2, r: float, dmg: float, ev: Array) -> void:
	for e in enemies:
		if (e.pos - at).length() < r + e.radius:
			damage(e, dmg, ev)
	ev.append({"type": "bolt", "pos": at, "radius": r})


## 가시 갑옷: 맞으면 가시가 사방으로 튀어요
func _thorn_burst(ev: Array) -> void:
	var lv := lv_of("thorns")
	if lv <= 0:
		return
	var r: float = 130.0 * bonus.area
	for e in enemies:
		if (e.pos - hero).length() < r + e.radius:
			damage(e, (20.0 + lv * 12.0) * (2.0 if evolved.has("thorns") else 1.0), ev, 80.0)
	ev.append({"type": "thorns", "radius": r})


func cloud_radius() -> float:
	var lv := lv_of("cloud")
	if lv <= 0:
		return 0.0
	return (90.0 + lv * 15.0) * bonus.area * (1.6 if evolved.has("cloud") else 1.0)


## 사슬 철퇴 공들의 자리
func chain_balls() -> Array:
	var lv := int(weapons.get("chain", 0))
	var out: Array = []
	if lv <= 0:
		return out
	var count := 1 + int(lv >= 2) + int(lv >= 4)
	if evolved.has("chain"):
		count = 5
	var r: float = (110.0 + lv * 8.0) * bonus.area
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
			xp_frac += float(g.value) * bonus.xp
			xp += int(xp_frac)
			xp_frac -= int(xp_frac)
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


## 레벨업 카드 3장: 진화, 새 무기, 무기 강화, 능력치 중에서 골라요.
func make_choices() -> Array:
	var out: Array = []
	# 진화할 수 있으면 진화 카드가 꼭 나와요
	for id in weapons:
		if int(weapons[id]) >= MAX_LEVEL and not evolved.has(id) and passives.has(WEAPONS[id].pair) and out.size() < 3:
			out.append({"kind": "evolve", "id": id, "title": "진화! " + WEAPONS[id].evo, "desc": WEAPONS[id].evo_desc})
	var pool: Array = []
	for id in WEAPONS:
		var lv := int(weapons.get(id, 0))
		if lv == 0 and weapons.size() < MAX_WEAPONS:
			pool.append({"kind": "weapon", "id": id, "title": "새 무기: " + WEAPONS[id].name, "desc": WEAPONS[id].desc})
		elif lv > 0 and lv < MAX_LEVEL:
			pool.append({"kind": "weapon", "id": id, "title": "%s Lv%d" % [WEAPONS[id].name, lv + 1], "desc": WEAPONS[id].desc})
			pool.append(pool[pool.size() - 1])   # 가진 무기 강화가 조금 더 자주 나와요
	for id in PASSIVES:
		var pl := int(passives.get(id, 0))
		if pl < int(PASSIVES[id].max) and (pl > 0 or passives.size() < MAX_PASSIVES):
			var t: String = PASSIVES[id].name if pl == 0 else "%s Lv%d" % [PASSIVES[id].name, pl + 1]
			pool.append({"kind": "passive", "id": id, "title": t, "desc": PASSIVES[id].desc})
	while out.size() < 3 and not pool.is_empty():
		var c: Dictionary = pool.pop_at(rng.randi() % pool.size())
		if out.any(func(o): return o.kind == c.kind and o.id == c.id):
			continue
		out.append(c)
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
		"cape":
			bonus.area += 0.12
		"crown":
			bonus.amount += 1
		"armor":
			bonus.armor += 0.08
		"luck":
			bonus.luck += 0.25
		"milk":
			bonus.regen += 0.5
		"book":
			bonus.xp += 0.12


## 이번 판에 받은 똥전 (판이 끝날 때 기기에 더해요)
func earned_coins() -> int:
	return coins + kills / 4 + minute() * 5
