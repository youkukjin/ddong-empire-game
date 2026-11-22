extends Node2D
## 똥 제국 백성: 동그란 머리의 막대 사람이에요 (원작 그림). 그림이 나오면 바꿀 임시 모양이에요.

const TOUCH_RADIUS := 56.0
const HIT_RADIUS := 30.0
const CENTER := Vector2(0, -30)   # 몸 가운데 (발이 position에 있어요)
const HEAD_COLOR := Color(0.55, 0.35, 0.18)
const BODY_COLOR := Color(0.98, 0.93, 0.82)

var dragging := false
var dizzy := 0.0
var fleeing := false
var gone := false
var _bob := randf() * TAU
var _flee_dir := -1.0


func _process(delta: float) -> void:
	_bob += delta * (10.0 if dragging else 4.0)
	if dizzy > 0.0:
		dizzy = maxf(dizzy - delta, 0.0)
	if fleeing:
		position.x += _flee_dir * 420.0 * delta
		modulate.a = maxf(modulate.a - delta * 0.8, 0.0)
		if position.x < -80.0 or position.x > 1360.0 or modulate.a <= 0.0:
			queue_free()
	queue_redraw()


func center_global() -> Vector2:
	return global_position + CENTER


func is_touched(p: Vector2) -> bool:
	return not gone and p.distance_to(center_global()) <= TOUCH_RADIUS


func can_be_dragged() -> bool:
	return not gone and dizzy <= 0.0


## 보라색 줄기에 맞으면 1초 동안 어질어질해서 끌 수 없어요 (제안).
func get_hit() -> void:
	dragging = false
	dizzy = 1.0


## 겁을 먹고 마을 밖으로 도망가요. 다치는 모습은 없어요.
func flee() -> void:
	gone = true
	fleeing = true
	dragging = false
	_flee_dir = -1.0 if position.x < 640.0 else 1.0


## 돔으로 쏙 들어가요.
func enter_dome(dome_center: Vector2) -> void:
	gone = true
	dragging = false
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position", dome_center + Vector2(randf_range(-40, 40), 10), 0.25)
	tw.tween_property(self, "scale", Vector2(0.2, 0.2), 0.25)
	tw.chain().tween_callback(queue_free)


func _draw() -> void:
	var hop := absf(sin(_bob)) * (6.0 if dragging else 2.0)
	var o := Vector2(0, -hop)
	var w := 4.0
	# 다리
	draw_line(o + Vector2(0, -22), o + Vector2(-9, 0), BODY_COLOR, w)
	draw_line(o + Vector2(0, -22), o + Vector2(9, 0), BODY_COLOR, w)
	# 몸
	draw_line(o + Vector2(0, -44), o + Vector2(0, -22), BODY_COLOR, w)
	# 팔 (끌려가면 만세)
	var arm_y := -58.0 if dragging else -32.0
	draw_line(o + Vector2(0, -40), o + Vector2(-14, arm_y), BODY_COLOR, w)
	draw_line(o + Vector2(0, -40), o + Vector2(14, arm_y), BODY_COLOR, w)
	# 머리
	draw_circle(o + Vector2(0, -56), 14.0, HEAD_COLOR)
	draw_arc(o + Vector2(0, -56), 14.0, 0, TAU, 24, BODY_COLOR, 2.0)
	draw_circle(o + Vector2(-5, -58), 2.2, Color.WHITE)
	draw_circle(o + Vector2(5, -58), 2.2, Color.WHITE)
	if dragging:
		draw_arc(o + Vector2(0, -30), 34.0, 0, TAU, 32, Color(1, 1, 0.6, 0.7), 3.0)
	if dizzy > 0.0:
		for i in 3:
			var a := _bob * 1.5 + i * TAU / 3.0
			draw_circle(o + Vector2(0, -78) + Vector2(cos(a) * 14, sin(a) * 5), 3.5, Color(1, 0.9, 0.3))
