extends RefCounted
## 3장 '구멍 탐험' 규칙과 숫자예요. 화면과 상관없는 계산만 해서 tests/stage3_test.gd로 검사해요.
## 원작: "일주일 후 준비를 마치고, 수상한 구멍으로 들어가 드래곤의 본거지를 찾음".
## 원작 그림에는 왕자가 검을 들고 구멍에 들어가는 장면이 있어요.
## 달리기 방식, 장애물, 갈림길의 보라색 자국, 숫자는 모두 (제안)이에요.
##
## 왕자는 굴 속을 저절로 달려요.
## - 톡: 뛰어올라 바위와 구덩이를 넘어요
## - 아래로 쓸기: 몸을 숙여 낮은 천장 밑을 지나가요
## - 갈림길: 보라색 자국이 있는 쪽으로 위/아래로 쓸어서 골라요

enum Kind { ROCK, PIT, LOW, GEM, GEM_HIGH }
enum Outcome { ONGOING, WIN, FAIL }
enum FailReason { NONE, HEARTS, TIME }
enum Side { NONE, UP, DOWN }

const SEGMENTS := 4                       # 굴 4구간. 앞 3구간 끝에 갈림길
const SEGMENT_LENGTH := 4800.0
const SPEEDS := [280.0, 310.0, 340.0, 370.0]   # 구간마다 조금씩 빨라져요 (쉽게: 조금 느리게)
const TIME_LIMIT := 95.0                # 끝까지 쉬지 않고 달리면 약 60초
const HEARTS := 4
const JUMP_TIME := 0.65
const JUMP_HEIGHT := 160.0
const DUCK_TIME := 0.7
const HURT_INVULN := 1.2
const WRONG_PATH_PENALTY := 6.0           # 막다른 길: 6초 잃어요
const FORK_NOTICE := 3.0                  # 갈림길 3초 전부터 보여요
const GEM_STARS_RATIO := 0.7              # 별 3개: 반짝이는 돌 70% 이상 + 하트 그대로

var items: Array = []        # {"kind", "x", "done", "hit"}
var forks: Array = []        # {"x", "correct": Side, "chosen": Side, "resolved"}
var distance := 0.0
var time_left := TIME_LIMIT
var hearts := HEARTS
var gems := 0
var gem_total := 0
var wrong_forks := 0
var hearts_lost := 0
var jump_left := 0.0
var duck_left := 0.0
var invuln := 0.0
var finished := false


func _init(seed_value := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else randi()
	_build_course(rng)


func _build_course(rng: RandomNumberGenerator) -> void:
	for s in SEGMENTS:
		var start := s * SEGMENT_LENGTH
		var end := start + SEGMENT_LENGTH
		var x := start + 900.0
		var safe_end := end - float(SPEEDS[s]) * FORK_NOTICE - 200.0  # 갈림길 앞에는 장애물이 없어요
		while x < safe_end:
			var r := rng.randf()
			var kind := Kind.ROCK
			if r < 0.38:
				kind = Kind.ROCK
			elif r < 0.66:
				kind = Kind.PIT
			else:
				kind = Kind.LOW
			items.append({"kind": kind, "x": x, "done": false, "hit": false})
			# 장애물 사이에 반짝이는 돌 (가끔 높이 있어서 뛰어야 먹어요)
			var gx := x + rng.randf_range(220.0, 300.0)
			var gem_kind := Kind.GEM_HIGH if rng.randf() < 0.35 else Kind.GEM
			items.append({"kind": gem_kind, "x": gx, "done": false, "hit": false})
			gem_total += 1
			x += rng.randf_range(560.0, 760.0) + s * 20.0
		if s < SEGMENTS - 1:
			forks.append({"x": end, "correct": Side.UP if rng.randf() < 0.5 else Side.DOWN, "chosen": Side.NONE, "resolved": false})
	items.sort_custom(func(a, b): return a.x < b.x)


func total_length() -> float:
	return SEGMENTS * SEGMENT_LENGTH


func segment() -> int:
	return mini(int(distance / SEGMENT_LENGTH), SEGMENTS - 1)


func speed() -> float:
	return SPEEDS[segment()]


func is_airborne() -> bool:
	return jump_left > 0.0


func is_ducking() -> bool:
	return duck_left > 0.0


## 점프 높이 (그리기용)
func jump_height() -> float:
	if jump_left <= 0.0:
		return 0.0
	var t := 1.0 - jump_left / JUMP_TIME
	return 4.0 * JUMP_HEIGHT * t * (1.0 - t)


func jump() -> bool:
	if jump_left > 0.0 or finished:
		return false
	duck_left = 0.0
	jump_left = JUMP_TIME
	return true


func duck() -> bool:
	if jump_left > 0.0 or finished:
		return false
	duck_left = DUCK_TIME
	return true


## 지금 보이는 (아직 안 정한) 갈림길. 없으면 빈 Dictionary
func upcoming_fork() -> Dictionary:
	for f in forks:
		if not f.resolved and f.x - distance <= speed() * FORK_NOTICE:
			return f
	return {}


func choose(side: int) -> bool:
	var f := upcoming_fork()
	if f.is_empty():
		return false
	f.chosen = side
	return true


## 시간을 흘려요. 이번에 일어난 일을 돌려줘요.
## [{"type": "hit"|"gem"|"fork_ok"|"fork_wrong", "x": float}]
func tick(delta: float) -> Array:
	var events: Array = []
	if finished:
		return events
	time_left = maxf(time_left - delta, 0.0)
	jump_left = maxf(jump_left - delta, 0.0)
	duck_left = maxf(duck_left - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	distance = minf(distance + speed() * delta, total_length())
	for it in items:
		if it.done:
			continue
		if it.x > distance + 60.0:
			break
		var dx: float = distance - it.x
		match it.kind:
			Kind.GEM:
				if absf(dx) < 50.0:
					it.done = true
					gems += 1
					events.append({"type": "gem", "x": it.x})
			Kind.GEM_HIGH:
				if absf(dx) < 50.0 and jump_height() > 70.0:
					it.done = true
					gems += 1
					events.append({"type": "gem", "x": it.x})
			_:
				var half := 30.0 if it.kind == Kind.ROCK else (45.0 if it.kind == Kind.PIT else 60.0)
				if absf(dx) <= half and not it.hit and invuln <= 0.0 and not _passes(it.kind):
					it.hit = true
					_lose_heart()
					events.append({"type": "hit", "x": it.x, "kind": it.kind})
		if dx > 60.0:
			it.done = true
	for f in forks:
		if not f.resolved and distance >= f.x:
			f.resolved = true
			if f.chosen == f.correct:
				events.append({"type": "fork_ok", "x": f.x})
			else:
				wrong_forks += 1
				time_left = maxf(time_left - WRONG_PATH_PENALTY, 0.0)
				events.append({"type": "fork_wrong", "x": f.x})
	if outcome() != Outcome.ONGOING:
		finished = true
	return events


func _passes(kind: Kind) -> bool:
	match kind:
		Kind.ROCK, Kind.PIT:
			return is_airborne()
		Kind.LOW:
			return is_ducking()
	return true


func _lose_heart() -> void:
	hearts = maxi(hearts - 1, 0)
	hearts_lost += 1
	invuln = HURT_INVULN


func outcome() -> Outcome:
	if hearts <= 0 or (time_left <= 0.0 and distance < total_length()):
		return Outcome.FAIL
	if distance >= total_length():
		return Outcome.WIN
	return Outcome.ONGOING


func fail_reason() -> FailReason:
	if hearts <= 0:
		return FailReason.HEARTS
	if time_left <= 0.0:
		return FailReason.TIME
	return FailReason.NONE


## 별 3개: 하트를 하나도 안 잃고, 갈림길을 모두 맞히고, 반짝이는 돌 70% 이상 · 별 2개: 하트 2개 이상 남음 · 별 1개: 도착
func star_rating() -> int:
	if hearts_lost == 0 and wrong_forks == 0 and gems >= ceili(gem_total * GEM_STARS_RATIO):
		return 3
	if hearts >= 2:
		return 2
	return 1
