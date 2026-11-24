extends Node2D
## 똥 제국 백성: 동그란 머리의 막대 사람이에요 (원작 그림). 그림이 나오면 바꿀 임시 모양이에요.

const TOUCH_RADIUS := 56.0
const HIT_RADIUS := 30.0
const CENTER := Vector2(0, -30)   # 몸 가운데 (발이 position에 있어요)
const Cute := preload("res://scripts/art/cute.gd")
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
	var w := 6.0
	var line := Color(0.55, 0.35, 0.18)
	# 다리 (동글동글 끝)
	for leg in [Vector2(-9, 0), Vector2(9, 0)]:
		draw_line(o + Vector2(0, -22), o + leg, line, w + 3)
		draw_line(o + Vector2(0, -22), o + leg, BODY_COLOR, w)
		draw_circle(o + leg, w * 0.6, line)
	# 몸
	draw_line(o + Vector2(0, -42), o + Vector2(0, -22), line, w + 7)
	draw_line(o + Vector2(0, -42), o + Vector2(0, -22), BODY_COLOR, w + 4)
	# 팔 (끌려가면 만세)
	var arm_y := -60.0 if dragging else -32.0
	for side in [-1.0, 1.0]:
		var hand := o + Vector2(14 * side, arm_y)
		draw_line(o + Vector2(0, -38), hand, line, w + 3)
		draw_line(o + Vector2(0, -38), hand, BODY_COLOR, w)
		draw_circle(hand, 4.0, BODY_COLOR)
	# 머리 (커다랗고 동그랗게, 제안)
	var hc := o + Vector2(0, -58)
	draw_circle(hc, 17.0, line.darkened(0.25))
	draw_circle(hc, 15.0, HEAD_COLOR.lightened(0.12))
	draw_circle(hc + Vector2(-6, -7), 4.0, Color(1, 1, 1, 0.35))
	if dizzy > 0.0:
		Cute.happy_eye(self, hc + Vector2(-6, -1), 4.5, Color.WHITE)
		Cute.happy_eye(self, hc + Vector2(6, -1), 4.5, Color.WHITE)
	else:
		Cute.eye(self, hc + Vector2(-6, -1), 4.6)
		Cute.eye(self, hc + Vector2(6, -1), 4.6)
	Cute.blush(self, hc + Vector2(-10, 6), 3.5)
	Cute.blush(self, hc + Vector2(10, 6), 3.5)
	Cute.smile(self, hc + Vector2(0, 5), 3.5, Cute.INK, dragging)
	if dragging:
		draw_arc(o + Vector2(0, -30), 34.0, 0, TAU, 32, Color(1, 1, 0.6, 0.7), 3.0)
	if dizzy > 0.0:
		for i in 3:
			var a := _bob * 1.5 + i * TAU / 3.0
			draw_circle(o + Vector2(0, -78) + Vector2(cos(a) * 14, sin(a) * 5), 3.5, Color(1, 0.9, 0.3))
