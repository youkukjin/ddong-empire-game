extends RefCounted
## 화면을 바꿔도 남아 있어야 하는 정보예요.
## 중간 저장(1장 중간 저장, 5장 보스 앞, 6장 재도전 메모)은 persist()로 기기에도 남겨서 앱을 껐다 켜도 이어져요.

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
	persist()


const _Save := preload("res://scripts/save_data.gd")
static var _restored := false


## 중간 저장을 기기에 남겨요.
static func persist() -> void:
	_Save.set_value("checkpoint", {
		"has": has_checkpoint,
		"time_left": checkpoint_time_left,
		"score": checkpoint_score,
		"chapters": chapter_checkpoint.duplicate(),
	}, "session")


## 앱을 켰을 때 한 번: 기기에 남은 중간 저장을 불러와요.
static func restore() -> void:
	if _restored:
		return
	_restored = true
	var d = _Save.get_value("checkpoint", {}, "session")
	if not (d is Dictionary) or d.is_empty():
		return
	has_checkpoint = bool(d.get("has", false))
	checkpoint_time_left = float(d.get("time_left", 0.0))
	checkpoint_score = int(d.get("score", 0))
	var ch = d.get("chapters", {})
	if ch is Dictionary:
		chapter_checkpoint = {}
		for k in ch:
			chapter_checkpoint[int(k)] = ch[k]
