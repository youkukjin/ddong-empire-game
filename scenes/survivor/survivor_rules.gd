extends RefCounted
## 서바이버 모드 규칙 (제안: 원작에 없는 놀이 방식이에요).
## 똥 왕자는 알아서 공격하고, 플레이어는 움직이기만 해요. 몰려오는 적을 물리치면 똥 구슬이 떨어지고,
## 구슬을 모아 레벨업하면 카드 3장 중 1장을 골라 강해져요. 5분에 중간 보스, 10분에 무대 보스.
## 좌표: 넓은 마당 위 픽셀 단위 (왕자가 화면 가운데). 화면 그림과 3D는 이 숫자를 따라 그려요.
## 숫자는 처음 정한 값이라 해보고 고쳐요.

const ARENA := 4000.0                 # 마당 한 변 (가운데가 0,0). 둘레는 성벽이에요
const HERO_SPEED := 240.0
const HERO_HP := 100.0
const HERO_RADIUS := 26.0
const HURT_INVULN := 0.8
const REGEN := 0.3                    # 1초에 체력 회복
const MAGNET := 140.0                 # 구슬을 끌어오는 거리
const ENEMY_CAP := 150
const MID_BOSS_TIME := 240.0          # 두 번째 중간 보스 시간
const BOSS_TIME := 360.0
## 중간 보스 4마리 (2026-11-28 사용자: 중간 보스 3마리 더)
## 한 판 6분, 중간 보스는 2분마다 (2026-11-28 사용자: "전체 6분으로 하고 2분마다 중간 보스").
## 2분 박쥐 왕, 4분 골렘과 드래곤이 한꺼번에, 6분 대마왕은 무사 대장을 데리고 와요.
const MID_BOSSES := [
	[120.0, "bat", "똥 박쥐 왕: 킁킁, 냄새 맡고 왔다!"],
	[240.0, "golem", "바위 똥 골렘: 쿵... 나 변비야..."],
	[240.0, "wyrm", "보라 드래곤: 화장실 어디야!!"],
	[360.0, "captain", ""],
]
const BOSS_NAMES := {"bat": "똥 박쥐 왕", "captain": "똥 무사 대장", "golem": "바위 똥 골렘", "wyrm": "꼬마 보라 드래곤", "demon": "똥 대마왕"}
const ENDLESS_EVERY := 45.0           # 무한 모드에서 중간 보스가 다시 오는 간격
const GOD_TIME := 10.0
const GOD_KILLS := 300                # 각성 게이지가 차는 처치 수
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
	"power": {"name": "힘", "desc": "공격력 +12%", "max": 5},
	"swift": {"name": "민첩", "desc": "이동 속도 +10%", "max": 5},
	"heart": {"name": "체력", "desc": "최대 체력 +25, 바로 회복", "max": 5},
	"magnet": {"name": "자석", "desc": "구슬 줍는 거리 +30%", "max": 5},
	"dumbbell": {"name": "아령", "desc": "공격 속도 +8%", "max": 5},
	"cape": {"name": "왕 망토", "desc": "공격 범위 +12%", "max": 5},
	"crown": {"name": "금왕관", "desc": "던지고 쏘는 개수 +1", "max": 3},
	"armor": {"name": "갑옷", "desc": "방어력 +8%", "max": 5},
	"luck": {"name": "행운 네잎", "desc": "큰 구슬, 아이템 똥, 크리티컬이 더 자주", "max": 5},
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
var items: Array = []                # {kind: "heal"|"magnet", pos, age}
var vacuum := 0.0
var _ring_t := 0.0                    # 자석 똥을 먹으면 잠깐 모든 구슬이 날아와요
const ITEM_HEAL := 30.0
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
var endless := false                 # 대마왕을 물리치면 무한 모드: 적이 점점 세져요
var _mid_index := 0
var _endless_boss_t := 0.0
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

## 고를 수 있는 똥 캐릭터 (2026-11-28 사용자: "초반에는 약한 똥들, 똥 왕자는 똥전으로 해금, 왕자 능력이 제일 좋게").
## 캐릭터마다 체력, 이동 속도, 시작 무기, 특기가 달라요. cost 0이면 처음부터 열려 있어요.
const HEROES := {
	"kid": {"name": "꼬마 똥", "hp": 70.0, "speed": 1.0, "weapon": "bomb", "cost": 0,
		"skill": "무럭무럭: 경험치 +15%", "desc": "작고 약하지만 쑥쑥 자라요"},
	"runny": {"name": "설사 똥", "hp": 55.0, "speed": 1.3, "weapon": "flies", "cost": 0,
		"skill": "후다닥: 이동 속도 +30%", "desc": "제일 빠르지만 몸이 약해요"},
	"gassy": {"name": "방귀 똥", "hp": 80.0, "speed": 0.95, "weapon": "cloud", "cost": 300,
		"skill": "뿡뿡: 공격 범위 +20%", "desc": "둘레를 지독한 방귀로 감싸요"},
	"icy": {"name": "얼음 똥", "hp": 75.0, "speed": 1.0, "weapon": "ice", "cost": 500,
		"skill": "꽁꽁: 공격 속도 +10%", "desc": "얼음 조각으로 적을 얼려요"},
	"rock": {"name": "돌 똥", "hp": 130.0, "speed": 0.85, "weapon": "fist", "cost": 800,
		"skill": "단단: 방어력 +15%", "desc": "느리지만 엄청 튼튼해요"},
	"prince": {"name": "똥 왕자", "hp": 120.0, "speed": 1.1, "weapon": "sword", "cost": 2000,
		"skill": "왕의 힘: 공격력+25%, 크리티컬+8%, 각성 2배", "desc": "철퇴도 들고 시작! 똥 제국에서 가장 강해요"},
}
var hero_id := "prince"
var crit_bonus := 0.0
var god_rate := 1.0


func set_hero(id: String) -> void:
	if not HEROES.has(id):
		return
	hero_id = id
	var h: Dictionary = HEROES[id]
	max_hp = float(h.hp)
	hp = max_hp
	bonus.speed = float(h.speed)
	weapons = {String(h.weapon): 1}
	match id:
		"kid":
			bonus.xp += 0.15
		"gassy":
			bonus.area += 0.2
		"icy":
			bonus.cool -= 0.1
		"rock":
			bonus.armor += 0.15
		"prince":
			bonus.dmg += 0.25
			crit_bonus = 0.08
			god_rate = 2.0
			weapons["chain"] = 1


## 광고 보고 이어하기 (한 판에 한 번): 체력 절반으로 일어나 주변 적을 밀어내요
var revived := false


func can_revive() -> bool:
	return hp <= 0.0 and not revived


func revive() -> void:
	revived = true
	hp = max_hp * 0.5
	invuln = 3.0
	for e in enemies:
		var to: Vector2 = e.pos - hero
		if to.length() < 420.0:
			if e.boss:
				e.pos = hero + to.normalized() * 420.0
			else:
				e.hp = 0.0
	vacuum = 2.0


func outcome() -> int:
	if hp <= 0.0:
		return Outcome.LOSE
	return Outcome.ONGOING


## 무한 모드에서 적이 얼마나 센지 (1분마다 +35%)
func power_mult() -> float:
	# 6분이 지나면 1분마다 +60%, 갈수록 더 가파르게 (2026-11-28 사용자: "6분 이후에는 더 어려워졌으면")
	var over := maxf(time - BOSS_TIME, 0.0) / 60.0
	return 1.0 + over * 0.6 + over * over * 0.15


func xp_needed() -> int:
	return 5 + (level - 1) * 4 + int(pow(level - 1, 1.4))


func minute() -> int:
	return int(time / 60.0)


## 난이도 시계: 10단계 흐름을 6분에 담아요 (1분 = 난이도 1.67)
func pace() -> float:
	if time <= BOSS_TIME:
		return time / BOSS_TIME * 10.0
	return 10.0 + (time - BOSS_TIME) / 60.0 * 2.5    # 6분 뒤엔 더 빨리 늘어요


func damage_mult() -> float:
	return bonus.dmg * (GOD_DMG if god_left > 0.0 else 1.0)


## 똥의 신 각성 (10초): 공격 3배, 무기 2배 빨리, 이동 1.4배, 무적,
## 시작할 때 큰 충격파로 주변 적을 날리고 모든 구슬을 끌어와요.
const GOD_DMG := 3.0
const GOD_COOL := 0.5
const GOD_SPEED := 1.4
const GOD_WAVE_R := 460.0
var _god_wave := false


func awaken() -> bool:
	if god_gauge < 1.0 or god_left > 0.0:
		return false
	god_gauge = 0.0
	god_left = GOD_TIME
	vacuum = 2.5
	_god_wave = true
	return true


func _god_burst(ev: Array) -> void:
	_god_wave = false
	for e in enemies:
		var d: float = e.pos.distance_to(hero)
		if d < GOD_WAVE_R:
			damage(e, (200.0 if e.boss else 80.0) * damage_mult() / GOD_DMG, ev, 0.0 if e.boss else 260.0)
	ev.append({"type": "god_wave", "r": GOD_WAVE_R})


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
		"coins":
			coins += 20
		"trait":
			_apply_trait(c.id)
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
		hero += m * HERO_SPEED * bonus.speed * (GOD_SPEED if god_left > 0.0 else 1.0) * delta
		facing = m.normalized()
		var half := ARENA / 2.0 - 40.0
		hero = hero.clamp(Vector2(-half, -half), Vector2(half, half))
		hero = push_out(hero, HERO_RADIUS)
	if _god_wave:
		_god_burst(ev)
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
	var m := int(pace())
	var e := {"id": _next_id, "kind": kind, "pos": pos, "boss": false, "hit_cd": {}, "flash": 0.0}
	_next_id += 1
	match kind:
		"warrior":
			e.hp = 12.0 + m * 6.0 + m * m * 0.4
			e.speed = 74.0 + m * 6.5
			e.dmg = 5.0 + m * 0.7
			e.radius = 22.0
		"runner":
			e.hp = 8.0 + m * 5.0 + m * m * 0.3
			e.speed = 130.0 + m * 6.5
			e.dmg = 4.0 + m * 0.5
			e.radius = 18.0
		"brute":
			e.hp = 60.0 + m * 24.0 + m * m * 2.0
			e.speed = 58.0 + m * 3.5
			e.dmg = 10.0 + m * 1.0
			e.radius = 34.0
		"bat":
			e.hp = 700.0
			e.speed = 125.0
			e.dmg = 9.0
			e.radius = 42.0
			e.boss = true
		"captain":
			e.hp = 1300.0
			e.speed = 80.0
			e.dmg = 12.0
			e.radius = 48.0
			e.boss = true
		"golem":
			e.hp = 2400.0
			e.speed = 50.0
			e.dmg = 18.0
			e.radius = 62.0
			e.boss = true
		"wyrm":
			e.hp = 1800.0
			e.speed = 85.0
			e.dmg = 14.0
			e.radius = 52.0
			e.boss = true
			e.dash = 3.0
		"demon":
			e.hp = 5500.0
			e.speed = 75.0
			e.dmg = 16.0
			e.radius = 64.0
			e.boss = true
	var pm := power_mult() * stage_mult()
	e.hp *= pm
	e.dmg *= sqrt(pm)
	if not e.boss:
		e.speed *= minf(1.0 + (pm - 1.0) * 0.25, 1.6)
	e.max_hp = e.hp
	enemies.append(e)
	return e


func boss() -> Dictionary:
	for e in enemies:
		if e.kind == "demon":
			return e
	return {}


func _spawn(delta: float, ev: Array) -> void:
	while _mid_index < MID_BOSSES.size() and time >= MID_BOSSES[_mid_index][0]:
		var mb: Array = MID_BOSSES[_mid_index]
		_mid_index += 1
		mid_spawned = true
		var c := spawn_enemy(mb[1], _edge_point())
		ev.append({"type": "boss", "enemy": c, "text": mb[2]})
	if not boss_spawned and time >= BOSS_TIME:
		boss_spawned = true
		var d := spawn_enemy("demon", _edge_point())
		ev.append({"type": "boss", "enemy": d, "text": String(STAGES[stage].boss_line)})
	if endless:
		_endless_boss_t += delta
		if _endless_boss_t >= ENDLESS_EVERY:
			_endless_boss_t = 0.0
			var mb2: Array = MID_BOSSES[rng.randi() % MID_BOSSES.size()]
			var c2 := spawn_enemy(mb2[1], _edge_point())
			ev.append({"type": "boss", "enemy": c2, "text": "더 센 " + mb2[2]})
	# 포위 공격: 1분 30초부터 1분마다 똥 무사들이 빙 둘러싸요 (도망만 다니면 갇혀요)
	_ring_t += delta
	if time >= 60.0 and _ring_t >= 45.0:
		_ring_t = 0.0
		var cnt := mini(18 + int(pace()) * 3, 48)
		for i in cnt:
			if enemies.size() >= ENEMY_CAP:
				break
			var kind := "brute" if (i % 6 == 0 and pace() > 4.0) else "warrior"
			spawn_enemy(kind, hero + Vector2.from_angle(TAU * i / cnt) * 620.0)
		ev.append({"type": "surround"})
	# 1분마다 더 많이 (처음 1초에 1.3마리 → 9분에 약 8마리)
	var rate := 1.3 + pace() * 0.75
	if boss_spawned and not endless:
		rate *= 0.6    # 대마왕과 싸우는 동안은 조금 덜
	_spawn_acc += rate * delta
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		if enemies.size() >= ENEMY_CAP:
			_spawn_acc = 0.0
			break
		var kind := "warrior"
		var r := rng.randf()
		if time > 30.0 and r < 0.28:
			kind = "runner"
		elif time > 75.0 and r > (0.9 if time < BOSS_TIME else 0.8):
			kind = "brute"
		spawn_enemy(kind, _edge_point())


## 서바이버 무대 (2026-11-28 사용자: "서바이버 챕터도 늘려주고", "챕터마다 배경음악도 다르게").
## 앞 무대에서 대마왕을 물리치면 다음 무대가 열려요. mult: 적 체력·공격·똥전 배수.
const STAGES := [
	{"name": "성 안 마당", "mult": 1.0, "ground": Color(0.3, 0.26, 0.29), "wall": Color(0.4, 0.36, 0.4), "fog": Color(0.14, 0.07, 0.12),
		"tint": Color(1, 1, 1), "props": "yard", "bricks": 1.0, "music": "happy", "boss_line": "똥 대마왕: 내 황금 변기를 지켜라!"},
	{"name": "방귀 숲", "mult": 1.35, "ground": Color(0.27, 0.34, 0.17), "wall": Color(0.33, 0.22, 0.13), "fog": Color(0.07, 0.12, 0.05),
		"tint": Color(0.75, 1.05, 0.7), "props": "forest", "bricks": 0.0, "music": "forest", "boss_line": "똥 대마왕: 숲속 화장실은 내 거다!"},
	{"name": "꽁꽁 얼음 동굴", "mult": 1.7, "ground": Color(0.45, 0.58, 0.7), "wall": Color(0.55, 0.68, 0.78), "fog": Color(0.1, 0.14, 0.22),
		"tint": Color(0.8, 0.92, 1.2), "props": "ice", "bricks": 0.5, "music": "icecave", "boss_line": "똥 대마왕: 에취! 엉덩이가 꽁꽁 얼었다!"},
	{"name": "부글부글 똥 화산", "mult": 2.1, "ground": Color(0.22, 0.13, 0.11), "wall": Color(0.24, 0.14, 0.12), "fog": Color(0.22, 0.07, 0.03),
		"tint": Color(1.2, 0.82, 0.7), "props": "lava", "bricks": 0.0, "music": "volcano", "boss_line": "똥 대마왕: 앗 뜨거! 내 엉덩이 불났다!"},
]
static var current_stage := 0
var stage := 0


func set_stage(i: int) -> void:
	stage = clampi(i, 0, STAGES.size() - 1)
	current_stage = stage


func stage_mult() -> float:
	return float(STAGES[stage].mult)


## 마당 장애물: 나무통, 깃대, 돌기둥, 우물. 왕자도 적도 지나가지 못해요 (2026-11-28 사용자: "우물 안 걸리고 통과").
## 3D 화면(view3d_survivor)도 이 목록을 보고 같은 자리에 그려요. kind: 0 나무통, 1 깃대, 2 돌기둥, 3 우물
const OBSTACLE_R := [40.0, 10.0, 52.0, 92.0]
static var _obstacles_by_stage := {}


static func obstacles() -> Array:
	if _obstacles_by_stage.has(current_stage):
		return _obstacles_by_stage[current_stage]
	var _obstacles: Array = []
	_obstacles_by_stage[current_stage] = _obstacles
	var r := RandomNumberGenerator.new()
	r.seed = 55 + current_stage * 101
	var half := ARENA / 2.0 - 150.0
	for i in 46:
		var p := Vector2(r.randf_range(-half, half), r.randf_range(-half, half))
		if p.length() < 300.0:
			continue
		var o := {"kind": i % 4, "pos": p, "r": OBSTACLE_R[i % 4], "red": i % 8 == 1, "rot": 0.0}
		if i % 4 == 1:
			o.rot = r.randf() * TAU
		_obstacles.append(o)
	return _obstacles


## 장애물 안에 들어갔으면 밖으로 밀어내요
static func push_out(pos: Vector2, radius: float) -> Vector2:
	for o in obstacles():
		var d: Vector2 = pos - o.pos
		var minimum: float = o.r + radius
		var l := d.length()
		if l < minimum:
			pos = o.pos + (d / l if l > 0.01 else Vector2.RIGHT) * minimum
	return pos


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
		# 꼬마 드래곤: 가끔 확 돌진해요
		if e.has("dash"):
			e.dash -= delta
			if e.dash < 0.0:
				spd *= 3.2
				if e.dash < -0.6:
					e.dash = 3.0
					ev.append({"type": "dash", "enemy": e})
		elif e.kind == "bat":
			to = to.rotated(sin(time * 3.0 + e.id) * 0.9)
		if d > 1.0:
			e.pos += to / d * spd * delta
			# 장애물에 막히면 옆으로 미끄러져 돌아가요
			for o in obstacles():
				var od: Vector2 = e.pos - o.pos
				var mn: float = o.r + e.radius * 0.8
				if od.length_squared() < mn * mn:
					var l := od.length()
					var n := od / l if l > 0.01 else Vector2.RIGHT
					e.pos = o.pos + n * mn + n.orthogonal() * signf(n.orthogonal().dot(to)) * spd * delta
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
	# 크리티컬: 가끔 2.5배로 아프게! (행운, 매운 똥 특성이면 더 자주)
	var crit := rng.randf() < crit_chance()
	if crit:
		dmg *= CRIT_MULT
		knock = maxf(knock, 30.0)
	e.hp -= dmg
	e.flash = 0.12
	if knock > 0.0 and not e.boss:
		var dir: Vector2 = (e.pos - hero).normalized()
		e.pos += dir * knock
	ev.append({"type": "hit", "enemy": e, "dmg": dmg, "boss": e.boss, "crit": crit})


const CRIT_MULT := 2.5


func crit_chance() -> float:
	return 0.08 + crit_bonus + (bonus.luck - 1.0) * 0.1 + int(traits.get("trait_atk", 0)) * 0.05


func _on_kill(e: Dictionary, ev: Array) -> void:
	enemies.erase(e)
	kills += 1
	if god_left <= 0.0:    # 각성 중에 물리친 적은 게이지에 안 쳐요
		god_gauge = minf(god_gauge + (8.0 if e.boss else 1.0) * god_rate / GOD_KILLS, 1.0)
	var value := 1
	match e.kind:
		"brute":
			value = 5
		"captain", "bat", "golem", "wyrm":
			value = 40
		"demon":
			value = 0
	if value > 0:
		gems.append({"pos": e.pos, "value": value})
	if not e.boss and value == 1 and rng.randf() < 0.03 * (bonus.luck - 1.0):
		gems[gems.size() - 1].value = 5
	# 가끔 아이템 똥이 떨어져요: 생명력 똥(체력 30), 자석 똥(구슬을 몽땅 끌어와요)
	if e.boss or rng.randf() < 0.005 * bonus.luck:
		drop_item("heal", e.pos + Vector2(18, 0))
	if (e.boss and e.kind != "bat") or rng.randf() < 0.0015 * bonus.luck:
		drop_item("magnet", e.pos + Vector2(-18, 0))
	if e.boss:
		coins += 200 if e.kind == "demon" else 50
		if e.kind != "demon":
			pending_traits += 1
	if e.kind == "demon" and not boss_defeated:
		boss_defeated = true
		endless = true
		ev.append({"type": "endless"})
	ev.append({"type": "kill", "enemy": e})


# ------------------------------------------------------------------ 무기

func _cool(base: float) -> float:
	return base * bonus.cool * (GOD_COOL if god_left > 0.0 else 1.0)


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
			var hits: Array = []
			for e in enemies:
				var to: Vector2 = e.pos - hero
				var along := to.dot(dir)
				if along > -10.0 and along < length and absf(to.cross(dir)) < width + e.radius:
					damage(e, (15.0 + lv * 8.0) * (1.4 if evo else 1.0), ev, 26.0)
					hits.append(e.pos)
			ev.append({"type": "beam", "from": hero, "dir": dir, "length": length, "width": width, "evolved": evo, "hits": hits})
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
					ev.append({"type": "ice_hit", "pos": e.pos, "evo": evolved.has("ice")})
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

## 똥 특성 (중간 보스를 물리치면 둘 중 하나): 체력형 "튼튼한 똥", 공격형 "매운 똥". 겹쳐서 쌓여요.
const TRAITS := {
	"trait_hp": {"name": "튼튼한 똥", "desc": "최대 체력 +40, 방어력 +6%, 체력 회복 UP"},
	"trait_atk": {"name": "매운 똥", "desc": "공격력 +25%, 크리티컬 +5%, 공격 속도 +8%"},
}
var traits := {}
var pending_traits := 0


func trait_choices() -> Array:
	var out: Array = []
	for id in TRAITS:
		var n := int(traits.get(id, 0)) + 1
		out.append({"kind": "trait", "id": id, "name": TRAITS[id].name, "level": n,
			"title": TRAITS[id].name + ("" if n == 1 else " ×%d" % n), "desc": TRAITS[id].desc})
	return out


func _apply_trait(id: String) -> void:
	traits[id] = int(traits.get(id, 0)) + 1
	if id == "trait_hp":
		max_hp += 40.0
		hp += 40.0
		bonus.armor += 0.06
		bonus.regen += 0.3
	else:
		bonus.dmg += 0.25
		bonus.cool = maxf(bonus.cool - 0.08, 0.45)
		bonus.area += 0.08


## 똥 대장간 영구 강화 (똥전으로 사요, 판이 시작할 때 적용)
const FORGE := {
	"heart": {"name": "튼튼 심장", "per": "최대 체력 +12", "max": 5, "cost": 60},
	"power": {"name": "단단한 주먹", "per": "공격력 +6%", "max": 5, "cost": 80},
	"armor": {"name": "똥 갑옷", "per": "방어력 +4%", "max": 5, "cost": 80},
	"swift": {"name": "빠른 신발", "per": "이동 속도 +5%", "max": 5, "cost": 60},
	"magnet": {"name": "자석 반지", "per": "줍는 거리 +15%", "max": 5, "cost": 40},
	"luck": {"name": "행운 네잎", "per": "행운 +10% (아이템·크리티컬)", "max": 5, "cost": 90},
	"book": {"name": "공부 책", "per": "경험치 +6%", "max": 5, "cost": 70},
	"dumbbell": {"name": "아령 연습", "per": "공격 속도 +4%", "max": 5, "cost": 100},
}


static func forge_cost(id: String, lv: int) -> int:
	return int(FORGE[id].cost) * (lv + 1)


func apply_forge(levels: Dictionary) -> void:
	for id in levels:
		var n := int(levels[id])
		match id:
			"heart":
				max_hp += 12.0 * n
				hp = max_hp
			"power":
				bonus.dmg += 0.06 * n
			"armor":
				bonus.armor += 0.04 * n
			"swift":
				bonus.speed += 0.05 * n
			"magnet":
				bonus.magnet += 0.15 * n
			"luck":
				bonus.luck += 0.10 * n
			"book":
				bonus.xp += 0.06 * n
			"dumbbell":
				bonus.cool = maxf(bonus.cool - 0.04 * n, 0.5)


## 아이템 똥: "heal"(생명력 똥) 또는 "magnet"(자석 똥). 땅에 떨어져 있다가 주우면 효과가 나요.
func drop_item(kind: String, pos: Vector2) -> void:
	if items.size() < 12:
		items.append({"kind": kind, "pos": pos, "age": 0.0})


func _collect(delta: float, ev: Array) -> void:
	vacuum = maxf(vacuum - delta, 0.0)
	var mag: float = MAGNET * bonus.magnet
	for it in items.duplicate():
		it.age += delta
		if hero.distance_to(it.pos) < HERO_RADIUS + 26.0:
			items.erase(it)
			if it.kind == "heal":
				var amount := minf(ITEM_HEAL, max_hp - hp)
				hp += amount
				ev.append({"type": "heal", "amount": ITEM_HEAL})
			else:
				vacuum = 2.5
				ev.append({"type": "magnet"})
	for g in gems.duplicate():
		var to: Vector2 = hero - g.pos
		var d := to.length()
		if vacuum > 0.0:
			g.pos += to.normalized() * minf(d, maxf(900.0, d * 2.5) * delta)
		elif d < mag:
			g.pos += to.normalized() * minf(d, 520.0 * delta)
		if d < HERO_RADIUS + 10.0:
			gems.erase(g)
			xp_frac += float(g.value) * bonus.xp
			xp += int(xp_frac)
			xp_frac -= int(xp_frac)
			ev.append({"type": "gem"})
	if pending_traits > 0 and choices.is_empty():
		pending_traits -= 1
		choices = trait_choices()
		ev.append({"type": "trait"})
	elif xp >= xp_needed() and choices.is_empty():
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
			out.append({"kind": "evolve", "id": id, "name": WEAPONS[id].evo, "level": 0, "title": "진화! " + WEAPONS[id].evo, "desc": WEAPONS[id].evo_desc})
	var pool: Array = []
	for id in WEAPONS:
		var lv := int(weapons.get(id, 0))
		if lv == 0 and weapons.size() < MAX_WEAPONS:
			pool.append({"kind": "weapon", "id": id, "name": WEAPONS[id].name, "level": 1, "title": "새 무기: " + WEAPONS[id].name, "desc": WEAPONS[id].desc})
		elif lv > 0 and lv < MAX_LEVEL:
			pool.append({"kind": "weapon", "id": id, "name": WEAPONS[id].name, "level": lv + 1, "title": "%s Lv%d" % [WEAPONS[id].name, lv + 1], "desc": WEAPONS[id].desc})
			pool.append(pool[pool.size() - 1])   # 가진 무기 강화가 조금 더 자주 나와요
	for id in PASSIVES:
		var pl := int(passives.get(id, 0))
		if pl < int(PASSIVES[id].max) and (pl > 0 or passives.size() < MAX_PASSIVES):
			var t: String = PASSIVES[id].name if pl == 0 else "%s Lv%d" % [PASSIVES[id].name, pl + 1]
			pool.append({"kind": "passive", "id": id, "name": PASSIVES[id].name, "level": pl + 1, "max": int(PASSIVES[id].max), "title": t, "desc": PASSIVES[id].desc})
	while out.size() < 3 and not pool.is_empty():
		var c: Dictionary = pool.pop_at(rng.randi() % pool.size())
		if out.any(func(o): return o.kind == c.kind and o.id == c.id):
			continue
		out.append(c)
	while out.size() < 3:
		out.append({"kind": "coins", "id": "coins", "name": "똥전 주머니", "level": 0, "title": "똥전 주머니", "desc": "똥전 +20"})
	return out


func _apply_passive(id: String) -> void:
	match id:
		"power":
			bonus.dmg += 0.12
		"swift":
			bonus.speed += 0.10
		"heart":
			max_hp += 25.0
			hp += 25.0
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
	return int((coins + kills / 4 + minute() * 5) * stage_mult())
