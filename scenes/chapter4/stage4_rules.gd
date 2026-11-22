extends RefCounted
## 4장 '성벽 돌파' 규칙과 숫자예요. 화면과 상관없는 계산만 해서 tests/stage4_test.gd로 검사해요.
## 원작: "본거지 아래 단단한 성벽을 부숨". 원작 그림에는 벽돌 성벽과 대포가 있고,
## 팔에 사슬로 이어진 무기가 초록 소용돌이를 쏘며 성벽을 부숴요("콰지직").
## 대포가 누구 편인지는 그림만으로는 확실하지 않아서, 성벽 위에서 왕자에게 쏘는 것으로 정했어요 (제안).
## 벽돌 칸 수, 체력, 대포 간격, 별 기준 같은 숫자는 모두 (제안)이에요.

enum Outcome { ONGOING, WIN, FAIL }
enum FailReason { NONE, HEARTS, TIME }

const COLS := 10
const ROWS := 5
const WALL_LEFT := 80.0
const WALL_TOP := 200.0
const BRICK_W := 112.0
const BRICK_H := 60.0
const BRICK_HP := 3
const SWORD_ROWS := 2               # 검은 아래 두 줄까지만 닿아요
const SWORD_REACH := 140.0          # 왕자와 벽돌 가운데가 이만큼 가까워야 검이 닿아요
const VORTEX_POWER := 5             # 소용돌이 힘 5: 아래 벽돌부터 차례로 깎고, 남은 힘은 위 벽돌로 넘어가요
const CHARGE_TIME := 1.7            # 사슬 모으기 (6장 설계 시작값)
const WALK_SPEED := 420.0
const ROLL_DISTANCE := 170.0
const ROLL_INVULN := 0.4
const MIN_X := 60.0
const MAX_X := 1220.0
const CANNON_COLS := [1, 5, 8]
const CANNON_WARN := 1.2            # 땅에 빨간 그림자가 1.2초 먼저 보여요
const CANNON_GAP := 2.2             # 대포알 간격 (남은 시간이 45초 아래면 1.6초)
const CANNON_GAP_LATE := 1.6
const BALL_RADIUS := 70.0
const HURT_INVULN := 1.0
const TIME_LIMIT := 90.0
const HEARTS := 3

var bricks: Array = []              # bricks[col][row] = 남은 체력 (row 0이 맨 위)
var cannons := {}                   # 열 -> 살아 있는지
var balls: Array = []               # {"x", "left"}  left: 떨어지기까지 남은 시간
var prince_x := 640.0
var walk_target := 640.0
var roll_left := 0.0
var roll_dir := 0.0
var invuln := 0.0
var time_left := TIME_LIMIT
var hearts := HEARTS
var hearts_lost := 0
var bricks_broken := 0
var cannons_broken := 0
var _cannon_timer := 2.0
var _cannon_turn := 0
var rng := RandomNumberGenerator.new()


func _init(seed_value := 0) -> void:
	rng.seed = seed_value if seed_value != 0 else randi()
	for c in COLS:
		var col: Array = []
		for r in ROWS:
			col.append(BRICK_HP)
		bricks.append(col)
	for c in CANNON_COLS:
		cannons[c] = true


static func col_center_x(c: int) -> float:
	return WALL_LEFT + (c + 0.5) * BRICK_W


static func brick_rect(c: int, r: int) -> Rect2:
	return Rect2(WALL_LEFT + c * BRICK_W, WALL_TOP + r * BRICK_H, BRICK_W, BRICK_H)


## 화면의 점이 어느 벽돌인지. 없으면 Vector2i(-1, -1)
static func brick_at(p: Vector2) -> Vector2i:
	var c := int(floor((p.x - WALL_LEFT) / BRICK_W))
	var r := int(floor((p.y - WALL_TOP) / BRICK_H))
	if c < 0 or c >= COLS or r < 0 or r >= ROWS:
		return Vector2i(-1, -1)
	return Vector2i(c, r)


## 왕자가 서 있는 열
func prince_col() -> int:
	return clampi(int(floor((prince_x - WALL_LEFT) / BRICK_W)), 0, COLS - 1)


func is_rolling() -> bool:
	return roll_left > 0.0


static func charge_ratio(held: float) -> float:
	return clampf(held / CHARGE_TIME, 0.0, 1.0)


func walk_to(x: float) -> void:
	walk_target = clampf(x, MIN_X, MAX_X)


func roll(dir: float) -> bool:
	if roll_left > 0.0:
		return false
	roll_dir = signf(dir)
	roll_left = ROLL_INVULN
	walk_target = clampf(prince_x + roll_dir * ROLL_DISTANCE, MIN_X, MAX_X)
	return true


## 검으로 벽돌 치기. 맞았으면 true (닿지 않으면 false)
func sword_hit(c: int, r: int) -> bool:
	if r < ROWS - SWORD_ROWS or bricks[c][r] <= 0:
		return false
	if absf(col_center_x(c) - prince_x) > SWORD_REACH:
		return false
	_damage(c, r, 1)
	return true


## 사슬 무기 초록 소용돌이: 왕자 열의 가장 아래 남은 벽돌부터 위로 힘 5만큼 깎아요.
## 벽돌을 다 부수고 힘이 남으면 성벽 위 대포까지 닿아 부숴요.
## 돌려주는 값: {"col", "bricks": 부순 벽돌 수, "cannon": 대포를 부쉈는지, "hit": 맞은 벽돌 수}
func vortex() -> Dictionary:
	var c := prince_col()
	var result := {"col": c, "bricks": 0, "cannon": false, "hit": 0}
	var power := VORTEX_POWER
	for r in range(ROWS - 1, -1, -1):
		if power <= 0:
			return result
		var hp: int = bricks[c][r]
		if hp <= 0:
			continue
		var before: int = bricks_broken
		var dmg := mini(hp, power)
		_damage(c, r, dmg)
		power -= dmg
		result.hit += 1
		result.bricks += bricks_broken - before
	if power > 0 and cannons.get(c, false):
		cannons[c] = false
		cannons_broken += 1
		result.cannon = true
	return result


func _damage(c: int, r: int, amount: int) -> void:
	var was: int = bricks[c][r]
	bricks[c][r] = maxi(was - amount, 0)
	if was > 0 and bricks[c][r] == 0:
		bricks_broken += 1


func column_clear(c: int) -> bool:
	for r in ROWS:
		if bricks[c][r] > 0:
			return false
	return true


## 구멍: 나란한 두 열이 위에서 아래까지 모두 부서졌어요
func has_hole() -> bool:
	for c in COLS - 1:
		if column_clear(c) and column_clear(c + 1):
			return true
	return false


func live_cannons() -> Array:
	var list: Array = []
	for c in CANNON_COLS:
		if cannons[c]:
			list.append(c)
	return list


## 시간을 흘려요. 이번에 일어난 일: [{"type": "shot"|"land"|"hurt", "x"}]
func tick(delta: float) -> Array:
	var events: Array = []
	time_left = maxf(time_left - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	roll_left = maxf(roll_left - delta, 0.0)
	var speed := WALK_SPEED * (1.6 if roll_left > 0.0 else 1.0)
	prince_x = move_toward(prince_x, walk_target, speed * delta)
	# 대포
	var live := live_cannons()
	if not live.is_empty():
		_cannon_timer -= delta
		if _cannon_timer <= 0.0:
			_cannon_timer = CANNON_GAP if time_left > 45.0 else CANNON_GAP_LATE
			var c: int = live[_cannon_turn % live.size()]
			_cannon_turn += 1
			var x := clampf(prince_x + rng.randf_range(-90.0, 90.0), MIN_X, MAX_X)
			balls.append({"x": x, "left": CANNON_WARN, "from": c})
			events.append({"type": "shot", "x": x, "col": c})
	for b in balls.duplicate():
		b.left -= delta
		if b.left <= 0.0:
			balls.erase(b)
			events.append({"type": "land", "x": b.x})
			if absf(b.x - prince_x) < BALL_RADIUS and invuln <= 0.0 and roll_left <= 0.0:
				hearts = maxi(hearts - 1, 0)
				hearts_lost += 1
				invuln = HURT_INVULN
				events.append({"type": "hurt", "x": prince_x})
	return events


func outcome() -> Outcome:
	if has_hole():
		return Outcome.WIN
	if hearts <= 0 or time_left <= 0.0:
		return Outcome.FAIL
	return Outcome.ONGOING


func fail_reason() -> FailReason:
	if hearts <= 0:
		return FailReason.HEARTS
	if time_left <= 0.0:
		return FailReason.TIME
	return FailReason.NONE


## 별 3개: 하트 그대로 + 30초 이상 남김 · 별 2개: 하트 2개 이상 · 별 1개: 구멍을 뚫음
func star_rating() -> int:
	if hearts_lost == 0 and time_left >= 30.0:
		return 3
	if hearts >= 2:
		return 2
	return 1
