extends RefCounted
## 2장 '준비' 규칙과 숫자예요. 화면과 상관없는 계산만 해서 tests/stage2_test.gd로 바로 검사해요.
## 원작에는 "똥 왕자가 드래곤을 물리치려고 준비함"까지만 있어서, 연습 종류와 숫자는 모두 (제안)이에요.
## 연습 네 가지는 뒤 장에서 쓰는 조작(탭 = 검, 길게 눌렀다 떼기 = 사슬 무기, 쓸기 = 구르기)을 미리 익히게 짰어요.
## 아령은 원작 그림에 여러 번 나와서 첫 연습으로 넣었어요.

enum Drill { DUMBBELL, SWORD, CHAIN, ROLL }
enum Judge { PERFECT, GOOD, MISS }

const DRILL_NAMES := ["아령 들기", "검 연습", "사슬 무기 연습", "구르기 연습"]

# 아령 들기: 줄어드는 고리가 가운데 원에 딱 맞을 때 톡
const DUMBBELL_NOTES := 12
const DUMBBELL_APPROACH := 1.2      # 고리가 다 줄어드는 데 걸리는 시간
const DUMBBELL_GAP := 1.0           # 다음 고리까지 간격
const PERFECT_WINDOW := 0.15        # ±0.15초 = 딱 좋아요 (2점)
const GOOD_WINDOW := 0.3            # ±0.3초 = 좋아요 (1점)

# 검 연습: 튀어나온 표적을 톡톡
const SWORD_TIME := 25.0
const SWORD_TARGET_LIFE := 1.8
const SWORD_SPAWN_GAP := 0.7
const SWORD_HARD_CHANCE := 0.15     # 단단한 표적(두 번 쳐야 해요)이 나올 확률

# 사슬 무기 연습: 길게 눌러 힘을 모으고, 움직이는 표적이 줄 위에 올 때 떼기
const CHAIN_THROWS := 6
const CHAIN_CHARGE_TIME := 1.7      # 6장 설계: 민첩 10일 때 모으기 1.7초
const CHAIN_TIME := 60.0

# 구르기 연습: 굴러오는 연습 공을 쓸어서 굴러 피하기
const ROLL_BALLS := 10
const ROLL_INVULN := 0.5            # 연습이라 조금 넉넉하게 (6장 설계 민첩 10은 0.4초)
const ROLL_WARN := 1.1              # 공이 닿기 1.1초 전에 "!" 표시

# 연습마다 [통과 점수, 별 2개 점수, 별 3개 점수]
const THRESHOLDS := {
	Drill.DUMBBELL: [10, 15, 20],   # 24점 만점
	Drill.SWORD: [10, 16, 22],      # 맞힌 표적 수
	Drill.CHAIN: [3, 4, 6],         # 6번 중 맞힌 수
	Drill.ROLL: [5, 7, 10],         # 10개 중 피한 수
}

var drill := Drill.DUMBBELL
var scores := {}          # 끝낸 연습 -> 점수
var stars := {}           # 끝낸 연습 -> 별


static func judge_tap(time_off: float) -> Judge:
	var d := absf(time_off)
	if d <= PERFECT_WINDOW:
		return Judge.PERFECT
	if d <= GOOD_WINDOW:
		return Judge.GOOD
	return Judge.MISS


static func judge_points(j: Judge) -> int:
	match j:
		Judge.PERFECT:
			return 2
		Judge.GOOD:
			return 1
	return 0


static func drill_stars(d: Drill, score: int) -> int:
	var t: Array = THRESHOLDS[d]
	if score >= t[2]:
		return 3
	if score >= t[1]:
		return 2
	if score >= t[0]:
		return 1
	return 0


static func max_score(d: Drill) -> int:
	match d:
		Drill.DUMBBELL:
			return DUMBBELL_NOTES * 2
		Drill.SWORD:
			return int(THRESHOLDS[Drill.SWORD][2])
		Drill.CHAIN:
			return CHAIN_THROWS
	return ROLL_BALLS


## 구르기를 시작한 시간과 공이 닿은 시간으로 피했는지 봐요.
static func roll_dodged(roll_start: float, hit_time: float, invuln := ROLL_INVULN) -> bool:
	return roll_start >= 0.0 and hit_time >= roll_start and hit_time <= roll_start + invuln


## 사슬 모으기: 누른 시간 → 0~1
static func charge_ratio(held: float, charge_time := CHAIN_CHARGE_TIME) -> float:
	return clampf(held / charge_time, 0.0, 1.0)


## 연습 하나를 끝냈어요. 통과했으면 true.
func finish_drill(score: int) -> bool:
	var s := drill_stars(drill, score)
	if s == 0:
		return false
	# 다시 연습하면 더 좋은 기록만 남겨요
	if s >= int(stars.get(drill, 0)):
		stars[drill] = s
		scores[drill] = maxi(score, int(scores.get(drill, 0)))
	return true


func next_drill() -> bool:
	if drill == Drill.ROLL:
		return false
	drill = (drill + 1) as Drill
	return true


func all_done() -> bool:
	return stars.size() == Drill.size()


## 장 전체 별: 연습 별을 더해서 11개 이상이면 3개, 8개 이상이면 2개, 아니면 1개
func chapter_stars() -> int:
	var total := 0
	for k in stars:
		total += int(stars[k])
	if total >= 11:
		return 3
	if total >= 8:
		return 2
	return 1


func total_stars() -> int:
	var total := 0
	for k in stars:
		total += int(stars[k])
	return total
