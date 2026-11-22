extends RefCounted
## 손가락 하나의 움직임을 탭 / 쓸기 / 길게 누르기로 나눠 주는 도우미예요.
## 여러 장에서 같은 조작을 쓰려고 한곳에 모았어요.
##
## - 탭: 짧게 톡 (0.3초보다 짧고, 거의 안 움직임)
## - 쓸기: 70픽셀 이상 쓱 (방향을 함께 알려줘요)
## - 길게 누르기: 0.3초 이상 누르고 있다가 뗌 (누른 시간을 알려줘요)

const SWIPE_MIN := 70.0
const HOLD_MIN := 0.3

var down := false
var index := -1
var start_pos := Vector2.ZERO
var last_pos := Vector2.ZERO
var held := 0.0
var swiped := false   # 누른 채로 이미 쓸기로 판정했는지


## InputEvent를 넣으면 무슨 일이 있었는지 돌려줘요. 아무 일도 없으면 빈 Dictionary.
## {"type": "press"|"tap"|"swipe"|"hold"|"hold_cancel", "pos": Vector2, "dir": Vector2, "held": float}
func feed(event: InputEvent) -> Dictionary:
	if event is InputEventScreenTouch:
		if event.pressed:
			if down:
				return {}
			down = true
			swiped = false
			index = event.index
			start_pos = event.position
			last_pos = event.position
			held = 0.0
			return {"type": "press", "pos": event.position}
		if not down or event.index != index:
			return {}
		down = false
		last_pos = event.position
		if swiped:
			return {}
		var move: Vector2 = event.position - start_pos
		if move.length() >= SWIPE_MIN:
			return {"type": "swipe", "pos": start_pos, "dir": move.normalized(), "held": held}
		if held >= HOLD_MIN:
			return {"type": "hold", "pos": event.position, "held": held}
		return {"type": "tap", "pos": event.position, "held": held}
	if event is InputEventScreenDrag and down and event.index == index:
		last_pos = event.position
		var move: Vector2 = event.position - start_pos
		# 길게 누르는 중이 아니면, 충분히 움직인 순간 바로 쓸기로 봐요 (구르기가 빨리 나가게)
		if not swiped and held < HOLD_MIN and move.length() >= SWIPE_MIN:
			swiped = true
			return {"type": "swipe", "pos": start_pos, "dir": move.normalized(), "held": held}
	return {}


## 매 프레임 불러서 누른 시간을 세요.
func tick(delta: float) -> void:
	if down and not swiped:
		held += delta


## 지금 길게 누르는 중인지 (사슬 모으기 표시용)
func is_holding() -> bool:
	return down and not swiped and held >= HOLD_MIN and (last_pos - start_pos).length() < SWIPE_MIN


func reset() -> void:
	down = false
	swiped = false
	held = 0.0
