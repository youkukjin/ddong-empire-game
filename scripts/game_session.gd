extends RefCounted
## 화면을 바꿔도 남아 있어야 하는 이번 실행 동안의 정보예요. (앱을 끄면 사라져요)

static var hard_mode := false      # 어려움 모드로 시작할지
static var assist := false         # "도움 켜기" (경고 점선이 1.5초 전에 나와요)
static var resume_checkpoint := false
static var checkpoint_time_left := 0.0
static var checkpoint_score := 0
static var has_checkpoint := false
static var fail_streak := 0        # 연속 실패 횟수
static var chapter_checkpoint := {} # 2장부터: 장 번호 -> 중간부터 시작할 곳 (예: 5장 "boss")


## 새 판을 처음부터 할 때 불러요.
static func clear_checkpoint() -> void:
	resume_checkpoint = false
	has_checkpoint = false
	checkpoint_time_left = 0.0
	checkpoint_score = 0
