extends RefCounted
## 5~7장이 함께 쓰는 옆에서 보는 싸움 규칙이에요. 화면과 상관없는 계산만 해요.
## 2장에서 익힌 조작을 그대로 써요:
## - 톡: 가까우면 검으로 치고, 멀면 그쪽으로 걸어가요
## - 꾹 눌렀다 떼기: 사슬 무기 (힘을 다 모아야 나가요)
## - 옆으로 쓸기: 구르기 (잠깐 안 다쳐요)
## 적은 공격하기 전에 꼭 경고(빨간 표시)를 보여줘요. 공격이 끝나면 잠깐 틈이 생겨요.
## 무사·대마왕·드래곤의 공격 종류와 숫자는 (제안)이고, 드래곤 숫자는 6장 설계 문서를 따랐어요.

enum Outcome { ONGOING, WIN, FAIL }

const GROUND_MIN := 60.0
const GROUND_MAX := 1220.0
const WALK_SPEED := 380.0
const ROLL_DISTANCE := 180.0
const SWORD_REACH := 110.0
const CHAIN_RANGE := 520.0
const PIERCE_RANGE := 900.0
const SPIN_RANGE := 220.0
const HURT_INVULN := 0.9
const FIST_PER_HIT := 0.05          # 6장: 때리면 +5%
const FIST_PER_DODGE := 0.10        # 6장: 아슬아슬하게 피하면 +10%
const FIST_DOWN_TIME := 3.0         # 근육 주먹에 맞으면 3초 쓰러져요

## 왕자 능력치 (6장 설계: Lv5, 힘·체력·민첩 10에서 시작)
static func base_stats() -> Dictionary:
	return {
		"max_hp": 100, "sword": 10, "chain": 20, "str": 10,
		"roll_invuln": 0.4, "charge_time": 1.7,
		"sword_cd": 0.35, "sword_pause": 0.0,
		"chain_kind": "normal", "fist": false,
	}


var stats: Dictionary
var hero_x := 300.0
var hero_hp := 100
var facing := 1.0
var walk_target := 300.0
var roll_left := 0.0
var hurt_left := 0.0
var sword_cd := 0.0
var pause_left := 0.0
var gauge := 0.0                    # 근육 주먹 / 각성 게이지 0~1
var god_left := 0.0                 # 7장 각성 남은 시간
var enemies: Array = []
var secrets := {}                   # 작전 회의로 알아낸 공격 이름 -> true (경고 0.3초 일찍)
var hits_taken := {}                # 공격 이름 -> 맞은 횟수 (졌을 때 보여줘요)
var hits_landed := 0
var dodges := 0
var elapsed := 0.0
var rng := RandomNumberGenerator.new()
var _next_id := 1


func _init(p_stats: Dictionary = {}, seed_value := 0) -> void:
	stats = base_stats()
	stats.merge(p_stats, true)
	hero_hp = int(stats.max_hp)
	rng.seed = seed_value if seed_value != 0 else randi()


# ------------------------------------------------------------------ 적

## 적의 기본 설정 (제안)
static func enemy_config(kind: String) -> Dictionary:
	match kind:
		"warrior":
			return {"name": "똥 무사", "hp": 32, "radius": 40.0, "speed": 120.0, "boss": false}
		"demon":
			return {"name": "똥 대마왕", "hp": 420, "radius": 70.0, "speed": 90.0, "boss": true}
		"dragon":
			return {"name": "똥 드래곤", "hp": 1500, "radius": 110.0, "speed": 60.0, "boss": true}
		"dragon_final":
			return {"name": "똥 드래곤", "hp": 900, "radius": 110.0, "speed": 70.0, "boss": true}
	return {"name": "?", "hp": 10, "radius": 40.0, "speed": 100.0, "boss": false}


func spawn(kind: String, x: float) -> Dictionary:
	var cfg := enemy_config(kind)
	var e := {
		"id": _next_id, "kind": kind, "name": cfg.name, "x": x,
		"hp": int(cfg.hp), "max_hp": int(cfg.hp), "radius": float(cfg.radius), "speed": float(cfg.speed), "boss": cfg.boss,
		"state": "approach", "t": 0.0, "wait": 1.0 + rng.randf() * 0.6, "attack": {},
		"target_x": x, "facing": -1.0, "airborne": false, "blocked": false, "phase": 1, "count": 0, "summon_cd": 6.0,
	}
	_next_id += 1
	enemies.append(e)
	return e


func alive_enemies() -> Array:
	var list: Array = []
	for e in enemies:
		if e.state != "dead":
			list.append(e)
	return list


func boss() -> Dictionary:
	for e in enemies:
		if e.boss and e.state != "dead":
			return e
	return {}


static func targetable(e: Dictionary) -> bool:
	return e.state != "dead" and not e.airborne


## 드래곤 단계: 1,500~1,000 = 1 · 1,000~450 = 2 · 450~0 = 3 (6장 설계)
static func dragon_phase(hp: int) -> int:
	if hp > 1000:
		return 1
	if hp > 450:
		return 2
	return 3


## 적이 고르는 공격 (제안). type: melee / beam / slam / charge / summon
func _choose_attack(e: Dictionary) -> Dictionary:
	match e.kind:
		"warrior":
			return {"name": "칼 휘두르기", "type": "melee", "dmg": 9, "warn": 1.1, "range": 70.0, "recover": 1.4}
		"demon":
			if e.phase >= 2 and e.summon_cd <= 0.0 and _count_kind("warrior") < 2:
				return {"name": "무사 부르기", "type": "summon", "dmg": 0, "warn": 0.8, "range": 0.0, "recover": 1.0}
			if absf(hero_x - e.x) > 260.0 or rng.randf() < 0.4:
				return {"name": "뿔 박치기", "type": "charge", "dmg": 18, "warn": 1.2, "range": 640.0, "recover": 1.6}
			return {"name": "내려찍기", "type": "slam_self", "dmg": 15, "warn": 1.2, "range": 230.0, "recover": 1.6}
		"dragon", "dragon_final":
			var ph: int = e.phase
			if e.kind == "dragon_final":
				ph = 3
			if ph == 3 and rng.randf() < 0.45:
				return {"name": "연속 광선", "type": "beam", "dmg": 30, "warn": 1.0, "range": 80.0, "recover": 2.0, "repeat": 3}
			if ph >= 2 and rng.randf() < 0.4:
				return {"name": "꼬리치기", "type": "fly_tail", "dmg": 18, "warn": 0.9, "range": 200.0, "recover": 3.0}
			if absf(hero_x - e.x) < e.radius + 220.0 and rng.randf() < 0.6:
				return {"name": "발톱 할퀴기", "type": "melee", "dmg": 11, "warn": 1.0, "range": 150.0, "recover": 2.0}
			return {"name": "보라색 광선", "type": "beam", "dmg": 30, "warn": 1.2, "range": 80.0, "recover": 2.0}
	return {}


func _count_kind(kind: String) -> int:
	var n := 0
	for e in enemies:
		if e.kind == kind and e.state != "dead":
			n += 1
	return n


func warn_time(atk: Dictionary) -> float:
	return float(atk.warn) + (0.3 if secrets.has(atk.name) else 0.0)


# ------------------------------------------------------------------ 왕자

func is_invulnerable() -> bool:
	return roll_left > 0.0 or hurt_left > 0.0 or god_left > 0.0


func is_rolling() -> bool:
	return roll_left > 0.0


func walk_to(x: float) -> void:
	walk_target = clampf(x, GROUND_MIN, GROUND_MAX)


func roll(dir: float) -> bool:
	if roll_left > 0.0 or pause_left > 0.0:
		return false
	facing = signf(dir) if dir != 0.0 else facing
	roll_left = float(stats.roll_invuln)
	walk_target = clampf(hero_x + signf(dir) * ROLL_DISTANCE, GROUND_MIN, GROUND_MAX)
	return true


func charge_ratio(held: float) -> float:
	if god_left > 0.0:
		return 1.0
	return clampf(held / float(stats.charge_time), 0.0, 1.0)


func damage_mult() -> float:
	return 3.0 if god_left > 0.0 else 1.0


## 검 닿는 거리 안에서 가장 가까운 적
func sword_target() -> Dictionary:
	var best := {}
	var best_d := INF
	for e in enemies:
		if not targetable(e):
			continue
		var d: float = absf(e.x - hero_x) - e.radius
		if d <= SWORD_REACH and d < best_d:
			best = e
			best_d = d
	return best


## 검으로 치기. 맞힌 적을 돌려줘요 (없으면 빈 Dictionary)
func sword() -> Dictionary:
	if sword_cd > 0.0 or pause_left > 0.0 or roll_left > 0.0:
		return {}
	var e := sword_target()
	if e.is_empty():
		return {}
	facing = signf(e.x - hero_x) if e.x != hero_x else facing
	sword_cd = float(stats.sword_cd)
	pause_left = float(stats.sword_pause)
	_hurt_enemy(e, int(round(float(stats.sword) * damage_mult())))
	if not e.blocked:
		_add_gauge(FIST_PER_HIT)
	return e


## 사슬 무기. 맞힌 적 목록과 막은 공격을 돌려줘요.
## normal: 바라보는 쪽 520 안의 첫 적 · pierce: 900까지 · spin: 주변 220 안 모두 (꼬리치기 막기)
func chain() -> Dictionary:
	var result := {"hit": [], "blocked": false}
	if pause_left > 0.0 or roll_left > 0.0:
		return result
	var kind: String = stats.chain_kind
	var targets: Array = []
	if kind == "spin":
		for e in enemies:
			if targetable(e) and absf(e.x - hero_x) - e.radius <= SPIN_RANGE:
				targets.append(e)
		for e in enemies:
			if e.state == "windup" and e.attack.get("type", "") == "fly_tail" and absf(e.target_x - hero_x) <= SPIN_RANGE:
				e.state = "recover"
				e.t = 0.0
				e.wait = float(e.attack.recover)
				e.airborne = false
				e.x = e.target_x
				result.blocked = true
	else:
		var reach := PIERCE_RANGE if kind == "pierce" else CHAIN_RANGE
		var near := {}
		var near_d := INF
		for e in enemies:
			if not targetable(e):
				continue
			var dx: float = (e.x - hero_x) * facing
			if dx + e.radius >= 0.0 and dx - e.radius <= reach and dx < near_d:
				near = e
				near_d = dx
		if not near.is_empty():
			targets.append(near)
	for e in targets:
		var dmg := float(stats.chain)
		# 드래곤 3단계: 빛나는 가슴 비늘에 사슬 무기 1.5배 (꿰뚫는 사슬 2배)
		if e.kind.begins_with("dragon") and (e.phase == 3 or e.kind == "dragon_final"):
			dmg *= 2.0 if kind == "pierce" else 1.5
		_hurt_enemy(e, int(round(dmg * damage_mult())))
		if e.blocked:
			continue
		_add_gauge(FIST_PER_HIT)
		# 무사는 뒤로 밀리고 하던 공격이 끊겨요
		if not e.boss and e.state != "dead":
			e.x = clampf(e.x + signf(e.x - hero_x) * 110.0, GROUND_MIN, GROUND_MAX)
			e.state = "recover"
			e.t = 0.0
			e.wait = 1.0
		result.hit.append(e)
	return result


## 근육 주먹 (6장): 게이지가 다 차면 힘 × 10. 보스는 3초 쓰러져요.
func fist() -> Dictionary:
	if gauge < 1.0 or not stats.fist:
		return {}
	var e := boss()
	if e.is_empty():
		var list := alive_enemies()
		if list.is_empty():
			return {}
		e = list[0]
	gauge = 0.0
	e.airborne = false
	_hurt_enemy(e, int(stats.str) * 10, true)
	if e.state != "dead":
		e.state = "down"
		e.t = 0.0
		e.wait = FIST_DOWN_TIME
		e.attack = {}
	return e


## 7장 각성: 게이지가 다 차면 똥의 신이 돼요 (시간 동안 안 다치고, 공격 3배, 사슬 모으기 없음)
func awaken(duration: float) -> bool:
	if gauge < 1.0:
		return false
	gauge = 0.0
	god_left = duration
	return true


func _add_gauge(v: float) -> void:
	if god_left <= 0.0:
		gauge = minf(gauge + v, 1.0)


## 드래곤은 공격이 끝난 틈(쉬는 중)이나 쓰러졌을 때만 다쳐요 (6장 설계: "공격 후 2초 동안 틈").
## 각성한 똥의 신은 언제든 때릴 수 있어요.
func is_guarded(e: Dictionary) -> bool:
	if not e.kind.begins_with("dragon") or god_left > 0.0:
		return false
	return e.state != "recover" and e.state != "down"


func _hurt_enemy(e: Dictionary, dmg: int, force := false) -> void:
	e.blocked = not force and is_guarded(e)
	if e.blocked:
		return
	e.hp = maxi(int(e.hp) - dmg, 0)
	# 7장: 마지막 드래곤은 각성한 똥의 신만 끝낼 수 있어요 (제안)
	if e.kind == "dragon_final" and e.hp <= 0 and god_left <= 0.0:
		e.hp = 1
	hits_landed += 1
	if e.hp <= 0:
		e.state = "dead"
		e.airborne = false


# ------------------------------------------------------------------ 시간

## 시간을 흘려요. 이번에 일어난 일을 돌려줘요.
## {"type": "windup"|"strike"|"hurt"|"dodge"|"summon"|"phase"|"land", "enemy", "attack", ...}
func tick(delta: float) -> Array:
	var events: Array = []
	elapsed += delta
	roll_left = maxf(roll_left - delta, 0.0)
	hurt_left = maxf(hurt_left - delta, 0.0)
	sword_cd = maxf(sword_cd - delta, 0.0)
	pause_left = maxf(pause_left - delta, 0.0)
	god_left = maxf(god_left - delta, 0.0)
	if pause_left <= 0.0:
		var speed := WALK_SPEED * (1.7 if roll_left > 0.0 else 1.0)
		hero_x = move_toward(hero_x, walk_target, speed * delta)
	for e in enemies.duplicate():
		if e.state != "dead":
			_enemy_step(e, delta, events)
	return events


func _enemy_step(e: Dictionary, delta: float, events: Array) -> void:
	e.t += delta
	e.summon_cd = maxf(e.summon_cd - delta, 0.0)
	if e.kind == "demon" and e.phase == 1 and e.hp <= e.max_hp / 2:
		e.phase = 2
		e.summon_cd = 0.0
		events.append({"type": "phase", "enemy": e, "phase": 2})
	if e.kind == "dragon":
		var ph := dragon_phase(e.hp)
		if ph != e.phase:
			e.phase = ph
			events.append({"type": "phase", "enemy": e, "phase": ph})
	if e.state != "windup":
		e.facing = signf(hero_x - e.x) if hero_x != e.x else e.facing
	match e.state:
		"approach":
			var gap: float = absf(hero_x - e.x) - e.radius
			var want := 70.0 if e.kind == "warrior" else 150.0
			if gap > want:
				e.x = move_toward(e.x, hero_x, e.speed * delta)
			e.wait -= delta
			if e.wait <= 0.0 and (gap <= want + 60.0 or e.boss):
				_start_attack(e, events)
		"windup":
			if e.t >= warn_time(e.attack):
				_strike(e, events)
		"recover", "down":
			if e.t >= e.wait:
				e.state = "approach"
				e.t = 0.0
				e.wait = (0.8 + rng.randf() * 0.6) if e.kind.begins_with("dragon") else (0.3 + rng.randf() * 0.5)


func _start_attack(e: Dictionary, events: Array) -> void:
	var atk := _choose_attack(e)
	e.attack = atk
	e.state = "windup"
	e.t = 0.0
	e.count = int(atk.get("repeat", 1))
	match atk.type:
		"beam":
			e.target_x = hero_x
		"fly_tail":
			e.airborne = true
			e.target_x = hero_x
		"charge":
			e.target_x = clampf(e.x + signf(hero_x - e.x) * float(atk.range), GROUND_MIN, GROUND_MAX)
		_:
			e.target_x = e.x
	events.append({"type": "windup", "enemy": e, "attack": atk})


## 지금 이 적의 공격이 나가면 왕자가 맞는 자리인지 (구르기·무적은 따로 봐요)
func would_hit_hero(e: Dictionary) -> bool:
	var atk: Dictionary = e.attack
	match atk.get("type", ""):
		"melee":
			return absf(hero_x - e.x) <= e.radius + float(atk.range)
		"slam_self":
			return absf(hero_x - e.x) <= float(atk.range)
		"beam", "fly_tail":
			return absf(hero_x - e.target_x) <= float(atk.range)
		"charge":
			var lo := minf(e.x, e.target_x) - 40.0
			var hi := maxf(e.x, e.target_x) + 40.0
			return hero_x >= lo and hero_x <= hi
	return false


func _strike(e: Dictionary, events: Array) -> void:
	var atk: Dictionary = e.attack
	var would_hit := would_hit_hero(e)
	match atk.type:
		"fly_tail":
			e.x = e.target_x
			e.airborne = false
			events.append({"type": "land", "enemy": e})
		"charge":
			e.x = e.target_x
		"summon":
			for i in 2:
				var side := -1.0 if i == 0 else 1.0
				spawn("warrior", clampf(hero_x + side * 520.0, GROUND_MIN, GROUND_MAX))
			e.summon_cd = 15.0
			events.append({"type": "summon", "enemy": e})
	events.append({"type": "strike", "enemy": e, "attack": atk})
	if would_hit:
		if is_invulnerable():
			if roll_left > 0.0:
				dodges += 1
				_add_gauge(FIST_PER_DODGE)
				events.append({"type": "dodge", "enemy": e, "attack": atk})
		else:
			hero_hp = maxi(hero_hp - int(atk.dmg), 0)
			hurt_left = HURT_INVULN
			hits_taken[atk.name] = int(hits_taken.get(atk.name, 0)) + 1
			events.append({"type": "hurt", "enemy": e, "attack": atk, "dmg": atk.dmg})
	e.count -= 1
	if e.count > 0 and e.state != "dead":
		# 연속 광선: 다시 조준해요
		e.state = "windup"
		e.t = 0.0
		e.target_x = hero_x
		events.append({"type": "windup", "enemy": e, "attack": atk})
		return
	e.state = "recover"
	e.t = 0.0
	e.wait = float(atk.recover)


func outcome() -> Outcome:
	if hero_hp <= 0:
		return Outcome.FAIL
	if alive_enemies().is_empty():
		return Outcome.WIN
	return Outcome.ONGOING


## 가장 많이 맞은 공격 (졌을 때 "주로 무엇에 맞았는지")
func hit_summary() -> String:
	var parts: Array = []
	for k in hits_taken:
		parts.append("%s %d번" % [k, hits_taken[k]])
	return ", ".join(parts) if not parts.is_empty() else "없음"
