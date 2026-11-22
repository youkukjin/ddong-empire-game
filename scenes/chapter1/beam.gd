extends Node2D
## 드래곤의 보라색 줄기 공격이에요.
## 먼저 땅에 경고 점선이 보이고(warning), 그다음 줄기가 나가요(active).
## 훑는 줄기(sweep)는 끝점이 from_target에서 to_target으로 움직여요.

signal finished(beam: Node2D)

const ACTIVE_TIME := 0.45
const SWEEP_TIME := 1.0
const WIDTH := 26.0
const PURPLE := Color(0.62, 0.3, 0.9)

var origin := Vector2.ZERO
var from_target := Vector2.ZERO
var to_target := Vector2.ZERO
var sweep := false
var warning_left := 1.0
var active_left := 0.0
var hit_ids := {}          # 이번 줄기에 이미 맞은 백성
var _started_active := false


func setup(p_origin: Vector2, p_from: Vector2, p_to: Vector2, warning: float, p_sweep: bool) -> void:
	origin = p_origin
	from_target = p_from
	to_target = p_to
	sweep = p_sweep
	warning_left = warning
	active_left = SWEEP_TIME if sweep else ACTIVE_TIME


func is_active() -> bool:
	return warning_left <= 0.0 and active_left > 0.0


## 지금 줄기 끝점이에요.
func current_target() -> Vector2:
	if not sweep:
		return from_target
	var total := SWEEP_TIME
	var t := clampf(1.0 - active_left / total, 0.0, 1.0)
	return from_target.lerp(to_target, t)


## 점 p가 지금 줄기에 닿았는지 봐요.
func touches(p: Vector2) -> bool:
	if not is_active():
		return false
	var closest := Geometry2D.get_closest_point_to_segment(p, origin, current_target())
	return closest.distance_to(p) < WIDTH + 14.0


## 줄기가 지나간 자리 (불이 붙을 곳)
func fire_points() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	if sweep:
		for i in 3:
			pts.append(from_target.lerp(to_target, i / 2.0))
	else:
		pts.append(from_target)
	return pts


func _process(delta: float) -> void:
	if warning_left > 0.0:
		warning_left -= delta
	elif active_left > 0.0:
		active_left -= delta
		if active_left <= 0.0:
			finished.emit(self)
			queue_free()
	queue_redraw()


func _draw() -> void:
	if warning_left > 0.0:
		var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 60.0)
		var c := Color(1, 0.4, 0.9, 0.5 + 0.4 * blink)
		_draw_dashed(origin, from_target, c)
		if sweep:
			_draw_dashed(origin, to_target, c)
			_draw_dashed(from_target, to_target, c)
		draw_arc(from_target, 30, 0, TAU, 24, c, 4.0)
		if sweep:
			draw_arc(to_target, 30, 0, TAU, 24, c, 4.0)
	elif active_left > 0.0:
		var end := current_target()
		draw_line(origin, end, Color(PURPLE, 0.45), WIDTH * 2.0)
		draw_line(origin, end, PURPLE, WIDTH)
		draw_line(origin, end, Color(0.9, 0.75, 1.0), WIDTH * 0.35)
		draw_circle(end, WIDTH, PURPLE)


func _draw_dashed(a: Vector2, b: Vector2, c: Color) -> void:
	var dist := a.distance_to(b)
	var dir := (b - a) / maxf(dist, 0.001)
	var d := 0.0
	while d < dist:
		draw_line(a + dir * d, a + dir * minf(d + 18.0, dist), c, 5.0)
		d += 32.0
