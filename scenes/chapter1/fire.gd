extends Node2D
## 불길: 줄기가 지나간 자리에 붙어요. 7초 동안 안 끄면 옆으로 번져요. 쓸면 꺼져요.

signal spread_requested(fire: Node2D)

const RADIUS := 34.0
const Rules := preload("res://scenes/chapter1/stage1_rules.gd")

var age := 0.0
var out := false
var _flicker := randf() * TAU


func _process(delta: float) -> void:
	if out:
		return
	_flicker += delta * 9.0
	age += delta
	if age >= Rules.FIRE_SPREAD_TIME:
		age = 0.0
		spread_requested.emit(self)
	queue_redraw()


func blocks(p: Vector2) -> bool:
	return not out and p.distance_to(global_position) < RADIUS + 18.0


func extinguish() -> void:
	if out:
		return
	out = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.1, 0.1), 0.2)
	tw.tween_callback(queue_free)


func _draw() -> void:
	var f := sin(_flicker) * 4.0
	# 곧 번지려 하면 빨갛게 커져요
	var warn := clampf((age - 3.5) / 1.5, 0.0, 1.0)
	var outer := Color(1.0, 0.45 - warn * 0.25, 0.1)
	draw_circle(Vector2(0, 0), RADIUS * 0.75 + warn * 6.0, Color(outer, 0.35))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-RADIUS * 0.8, 6), Vector2(-RADIUS * 0.4, -RADIUS * 0.9 - f),
		Vector2(0, -RADIUS * 0.5), Vector2(RADIUS * 0.35, -RADIUS * 1.25 + f),
		Vector2(RADIUS * 0.8, 6),
	]), outer)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-RADIUS * 0.4, 6), Vector2(-RADIUS * 0.1, -RADIUS * 0.6 + f),
		Vector2(RADIUS * 0.4, 6),
	]), Color(1.0, 0.85, 0.3))
	# 심술 난 불꽃 얼굴 (제안)
	var ink := Color(0.45, 0.1, 0.05)
	draw_circle(Vector2(-RADIUS * 0.22, -RADIUS * 0.1), 3.2, ink)
	draw_circle(Vector2(RADIUS * 0.22, -RADIUS * 0.1), 3.2, ink)
	draw_arc(Vector2(0, RADIUS * 0.12), 4.0, PI + 0.5, TAU - 0.5, 6, ink, 2.0)
