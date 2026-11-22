extends Control
## 화면 위 표시용 작은 그림들이에요. kind에 따라 다르게 그려요.
## - MOON: 남은 시간이 동그란 달 모양으로 줄어들어요 (기획안).
## - HEARTS: 하트 개수
## - STARS: 결과 화면의 별 개수

enum Kind { MOON, HEARTS, STARS }

var kind := Kind.MOON
var ratio := 1.0:          # MOON: 남은 시간 비율 0~1
	set(v):
		ratio = v
		queue_redraw()
var value := 0:            # HEARTS / STARS: 채운 개수
	set(v):
		value = v
		queue_redraw()
var max_value := 3:
	set(v):
		max_value = v
		queue_redraw()


func _init(p_kind := Kind.MOON) -> void:
	kind = p_kind
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	match kind:
		Kind.MOON:
			_draw_moon()
		Kind.HEARTS:
			for i in max_value:
				_draw_heart(Vector2(26 + i * 58, size.y / 2.0), 22.0, i < value)
		Kind.STARS:
			for i in max_value:
				_draw_star(Vector2(size.x / 2.0 + (i - 1) * 110, size.y / 2.0), 46.0, i < value)


func _draw_moon() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 4.0
	draw_circle(c, r, Color(0.2, 0.2, 0.35))
	if ratio > 0.0:
		var pts := PackedVector2Array([c])
		var steps := 40
		for i in steps + 1:
			var a := -PI / 2.0 + TAU * ratio * i / steps
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		var col := Color(1, 0.95, 0.6) if ratio > 0.25 else Color(1, 0.6, 0.4)
		draw_colored_polygon(pts, col)
	draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.8), 3.0)


func _draw_heart(c: Vector2, s: float, filled: bool) -> void:
	var col := Color(0.95, 0.3, 0.4) if filled else Color(0.4, 0.35, 0.45)
	draw_circle(c + Vector2(-s * 0.45, -s * 0.2), s * 0.52, col)
	draw_circle(c + Vector2(s * 0.45, -s * 0.2), s * 0.52, col)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.95, -s * 0.05), c + Vector2(s * 0.95, -s * 0.05), c + Vector2(0, s * 0.9)]), col)


func _draw_star(c: Vector2, r: float, filled: bool) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, Color(1, 0.82, 0.2) if filled else Color(0.75, 0.7, 0.62))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.4, 0.24, 0.11), 3.0)
