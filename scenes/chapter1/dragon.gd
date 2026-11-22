extends Node2D
## 똥 드래곤: 보라색 몸, 가시가 솟은 머리, 이빨이 가득한 큰 입, 긴 목 (원작 그림).
## 왼쪽 위에서 긴 목을 내밀어요. 임시 도형이라 그림이 나오면 바꿔요.
##
## 큰 입: 고개를 내리고 입을 벌려요. 코가 빛나는 동안(1.5초) 코를 톡 누르면 "에취!" 하고 물러나요.

signal nose_pressed
signal nose_missed

enum State { IDLE, MOUTH_OPEN, SNEEZE, LEAVING }

const NECK_BASE := Vector2(-60, -40)
const HEAD_IDLE := Vector2(250, 190)
const HEAD_LOW := Vector2(330, 300)
const HEAD_BACK := Vector2(190, 140)
const HEAD_RADIUS := 62.0
const NOSE_OFFSET := Vector2(66, 6)
const NOSE_TOUCH_RADIUS := 70.0
const PURPLE := Color(0.5, 0.25, 0.72)
const PURPLE_DARK := Color(0.33, 0.14, 0.5)

var state := State.IDLE
var head := HEAD_IDLE
var window_left := 0.0
var _t := 0.0
var _sneeze_left := 0.0
var _move: Tween


func _process(delta: float) -> void:
	_t += delta
	match state:
		State.MOUTH_OPEN:
			window_left -= delta
			if window_left <= 0.0:
				state = State.IDLE
				_move_head(HEAD_IDLE, 0.35)
				nose_missed.emit()
		State.SNEEZE:
			_sneeze_left -= delta
			if _sneeze_left <= 0.0:
				state = State.IDLE
				_move_head(HEAD_IDLE, 0.6)
	queue_redraw()


func is_busy() -> bool:
	return state != State.IDLE


func mouth_global() -> Vector2:
	return to_global(head + Vector2(40, 34))


func nose_global() -> Vector2:
	return to_global(head + NOSE_OFFSET)


## 고개를 내리고 입을 벌려요.
func open_mouth(window: float) -> void:
	if state != State.IDLE:
		return
	state = State.MOUTH_OPEN
	window_left = window
	_move_head(HEAD_LOW, 0.25)


## 화면의 점 p를 눌렀을 때 코를 누른 것인지 봐요.
func try_press_nose(p: Vector2) -> bool:
	if state != State.MOUTH_OPEN:
		return false
	if p.distance_to(nose_global()) > NOSE_TOUCH_RADIUS:
		return false
	state = State.SNEEZE
	_sneeze_left = 1.2
	_move_head(HEAD_BACK, 0.2)
	nose_pressed.emit()
	return true


## 1장 끝: 드래곤이 날아가요 (제안: 원작에서 어떻게 떠나는지는 확실하지 않아요).
func fly_away(duration := 1.6) -> Tween:
	state = State.LEAVING
	var tw := create_tween()
	tw.tween_property(self, "position", position + Vector2(-500, -500), duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	return tw


func _move_head(to: Vector2, time: float) -> void:
	if _move:
		_move.kill()
	_move = create_tween()
	_move.tween_property(self, "head", to, time).set_trans(Tween.TRANS_SINE)


func _draw() -> void:
	var sway := Vector2(sin(_t * 1.3) * 6.0, cos(_t * 1.1) * 4.0) if state == State.IDLE else Vector2.ZERO
	var h := head + sway
	# 긴 목: 굵은 곡선
	var ctrl := Vector2(h.x * 0.25, h.y + 80)
	var pts := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		pts.append(NECK_BASE.lerp(ctrl, t).lerp(ctrl.lerp(h, t), t))
	draw_polyline(pts, PURPLE_DARK, 78.0)
	draw_polyline(pts, PURPLE, 62.0)
	# 목 비늘 점
	for i in range(3, 15, 3):
		draw_circle(pts[i] + Vector2(0, -18), 6.0, PURPLE_DARK)
	# 가시 머리
	for i in 5:
		var a := -2.6 + i * 0.32
		var base := h + Vector2(cos(a), sin(a)) * (HEAD_RADIUS - 6)
		var tip := h + Vector2(cos(a), sin(a)) * (HEAD_RADIUS + 34)
		var side := Vector2(cos(a + 1.57), sin(a + 1.57)) * 12.0
		draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), PURPLE_DARK)
	draw_circle(h, HEAD_RADIUS, PURPLE)
	# 눈
	draw_circle(h + Vector2(8, -22), 13.0, Color(1, 0.95, 0.4))
	draw_circle(h + Vector2(12, -22), 6.0, Color(0.1, 0.05, 0.1))
	# 입
	var open := state == State.MOUTH_OPEN
	var mouth_h := 46.0 if open else 12.0
	var m := h + Vector2(34, 28)
	draw_rect(Rect2(m - Vector2(44, 0), Vector2(78, mouth_h)), Color(0.25, 0.05, 0.12))
	for i in 6:
		var x := m.x - 40 + i * 13
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, m.y), Vector2(x + 12, m.y), Vector2(x + 6, m.y + 12)]), Color.WHITE)
		if open:
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, m.y + mouth_h), Vector2(x + 12, m.y + mouth_h),
				Vector2(x + 6, m.y + mouth_h - 12)]), Color.WHITE)
	# 코
	var nose := h + NOSE_OFFSET
	draw_circle(nose, 14.0, PURPLE_DARK)
	if open:
		var pulse := 0.5 + 0.5 * sin(_t * 18.0)
		draw_circle(nose, 18.0 + pulse * 8.0, Color(1, 1, 0.4, 0.35))
		draw_circle(nose, 12.0, Color(1, 0.95, 0.3))
		# 남은 시간 링
		var ratio := clampf(window_left / 1.5, 0.0, 1.0)
		draw_arc(nose, 34.0, -PI / 2, -PI / 2 + TAU * ratio, 32, Color(1, 1, 0.5), 5.0)
	var font := ThemeDB.fallback_font
	if state == State.SNEEZE:
		draw_string(font, h + Vector2(70, -70), "에취!", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)
	elif open:
		draw_string(font, nose + Vector2(-20, -44), "톡!", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 1, 0.6))
