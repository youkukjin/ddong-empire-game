extends RefCounted
## 1장 '등장' 스테이지의 규칙과 숫자를 모아 둔 곳이에요.
## 화면과 상관없는 계산만 해서, 자동 확인(tests/stage1_test.gd)으로 바로 검사할 수 있어요.
## 숫자는 모두 1장 기획안의 (제안) 값이에요. 바꾸고 싶으면 여기만 고치면 돼요.

enum Outcome { ONGOING, WIN, FAIL }
enum FailReason { NONE, HEARTS, TIME, TOO_MANY_FLED }
enum HeartReason { BEAM, NOSE }

const TOTAL_CITIZENS := 15        # 모두 15명
const WIN_RESCUED := 12           # 12명 이상 대피하면 승리
const CHECKPOINT_RESCUED := 8     # 8명을 구한 순간 중간 저장
const MAX_ON_FIELD := 4           # 도로 위에는 한 번에 최대 4명
const TIME_NORMAL := 180.0        # 3분
const TIME_HARD := 150.0          # 어려움 모드 2분 30초
const HEARTS_NORMAL := 3
const HEARTS_HARD := 1
const PRACTICE_TIME := 20.0       # 처음 20초는 연습 (줄기 공격 없음)
const FIRST_MOUTH_TIME := 20.0    # (제안) 첫 큰 입은 연습이 끝날 때
const MOUTH_INTERVAL := 15.0      # 15초마다 큰 입
const NOSE_WINDOW := 1.5          # 코가 빛나는 1.5초
const FIRE_SPREAD_TIME := 5.0     # 5초 동안 안 끄면 번짐
const COMBO_MIN := 3              # 한 번에 3개 이상 쓸면 콤보
const CHECKPOINT_MIN_TIME := 60.0 # (제안) 중간부터 할 때 최소 1분은 남겨 줘요

var hard := false
var assist := false
var time_limit := TIME_NORMAL
var time_left := TIME_NORMAL
var hearts_max := HEARTS_NORMAL
var hearts := HEARTS_NORMAL
var elapsed := 0.0
var rescued := 0
var lost := 0
var spawned := 0
var score := 0
var hearts_lost := 0
var from_checkpoint := false
var checkpoint_reached := false
var checkpoint_time_left := 0.0
var checkpoint_score := 0
var last_heart_reason := HeartReason.BEAM


func _init(p_hard := false, p_assist := false) -> void:
	hard = p_hard
	assist = p_assist
	time_limit = TIME_HARD if hard else TIME_NORMAL
	hearts_max = HEARTS_HARD if hard else HEARTS_NORMAL
	start()


## 처음부터 시작해요.
func start() -> void:
	time_left = time_limit
	hearts = hearts_max
	elapsed = 0.0
	rescued = 0
	lost = 0
	spawned = 0
	score = 0
	hearts_lost = 0
	from_checkpoint = false
	checkpoint_reached = false


## 중간 지점(8명)부터 하트를 가득 채워 다시 시작해요.
func start_from_checkpoint(saved_time_left: float, saved_score: int) -> void:
	start()
	from_checkpoint = true
	checkpoint_reached = true
	rescued = CHECKPOINT_RESCUED
	spawned = CHECKPOINT_RESCUED
	score = saved_score
	checkpoint_time_left = saved_time_left
	checkpoint_score = saved_score
	time_left = maxf(saved_time_left, CHECKPOINT_MIN_TIME)
	elapsed = PRACTICE_TIME  # 연습 구간은 건너뛰어요


func tick(delta: float) -> void:
	elapsed += delta
	time_left = maxf(time_left - delta, 0.0)


# ---- 난이도 ----

func is_practice() -> bool:
	return elapsed < PRACTICE_TIME


func is_late() -> bool:
	return rescued >= CHECKPOINT_RESCUED


## 줄기 공격 간격(초). 연습 중에는 0 = 공격 없음.
func beam_interval() -> float:
	if is_practice():
		return 0.0
	return 3.0 if is_late() else 4.0


## 줄기 공격 전 경고 점선이 보이는 시간(초).
func warning_time() -> float:
	if assist:
		return 1.5
	return 0.7 if is_late() else 1.0


## 동시에 탈 수 있는 불의 수.
func max_fires() -> int:
	if is_practice():
		return 2
	return 5 if is_late() else 3


## 후반에는 한쪽에서 다른 쪽으로 훑고 지나가는 줄기가 섞여요.
func sweep_beams_allowed() -> bool:
	return is_late() and not is_practice()


# ---- 백성 ----

func can_spawn(on_field: int) -> bool:
	return spawned < TOTAL_CITIZENS and on_field < MAX_ON_FIELD


func on_spawned() -> void:
	spawned += 1


## 백성을 돔에 넣었어요. 이번에 중간 지점에 닿았으면 true를 돌려줘요.
func on_rescued() -> bool:
	rescued += 1
	score += 1
	if not checkpoint_reached and rescued >= CHECKPOINT_RESCUED:
		checkpoint_reached = true
		checkpoint_time_left = time_left
		checkpoint_score = score
		return true
	return false


func on_citizen_fled() -> void:
	lost += 1


func lose_heart(reason: int) -> void:
	if hearts <= 0:
		return
	hearts -= 1
	hearts_lost += 1
	last_heart_reason = reason


## 한 번 쓸 때 끈 불의 수를 받아요. 콤보 보너스를 받았으면 true.
func on_sweep_finished(fires_put_out: int) -> bool:
	if fires_put_out >= COMBO_MIN:
		score += 1
		return true
	return false


# ---- 결과 ----

func outcome() -> int:
	if hearts <= 0:
		return Outcome.FAIL
	if TOTAL_CITIZENS - lost < WIN_RESCUED:
		return Outcome.FAIL
	if rescued + lost >= TOTAL_CITIZENS or time_left <= 0.0:
		return Outcome.WIN if rescued >= WIN_RESCUED else Outcome.FAIL
	return Outcome.ONGOING


func fail_reason() -> int:
	if hearts <= 0:
		return FailReason.HEARTS
	if TOTAL_CITIZENS - lost < WIN_RESCUED:
		return FailReason.TOO_MANY_FLED
	if time_left <= 0.0 or rescued + lost >= TOTAL_CITIZENS:
		return FailReason.TIME
	return FailReason.NONE


## 별 개수(0~3). 중간부터 다시 한 판은 하트를 잃은 판으로 봐서 별 3개가 안 돼요 (제안).
func star_rating() -> int:
	if rescued < WIN_RESCUED:
		return 0
	if rescued >= TOTAL_CITIZENS and hearts_lost == 0 and not from_checkpoint:
		return 3
	if rescued >= 14:
		return 2
	return 1


func star_title(stars: int) -> String:
	match stars:
		3:
			return "완벽한 구조!"
		2:
			return "멋진 구조!"
		1:
			return "다음엔 더 많이!"
	return ""


## 실패 화면에 보여 줄 팁 한 줄이에요.
func fail_tip() -> String:
	match fail_reason():
		FailReason.HEARTS:
			if last_heart_reason == HeartReason.NOSE:
				return "드래곤 고개가 내려오면 빛나는 코를 먼저 톡 눌러 보세요."
			return "점선이 보이면 백성을 먼저 빼 보세요."
		FailReason.TOO_MANY_FLED:
			return "드래곤이 입을 벌리면 코를 눌러야 백성이 도망가지 않아요."
	return "불을 한 번에 쓸면 돔으로 가는 길이 빨리 열려요."
