extends Control
## 화면 위 표시용 작은 그림들이에요. kind에 따라 다르게 그려요.
## - MOON: 남은 시간이 동그란 달 모양으로 줄어들어요 (기획안).
## - HEARTS: 하트 개수
## - STARS: 결과 화면의 별 개수

const Cute := preload("res://scripts/art/cute.gd")

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
	draw_circle(c, r, Color(0.45, 0.4, 0.62))
	if ratio > 0.0:
		var pts := PackedVector2Array([c])
		var steps := 40
		for i in steps + 1:
			var a := -PI / 2.0 + TAU * ratio * i / steps
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		var col := Color(1, 0.95, 0.6) if ratio > 0.25 else Color(1, 0.6, 0.4)
		draw_colored_polygon(pts, col)
	draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.9), 4.0)
	# 달님 얼굴 (제안)
	Cute.happy_eye(self, c + Vector2(-r * 0.3, -r * 0.1), r * 0.16, Cute.COCOA)
	Cute.happy_eye(self, c + Vector2(r * 0.3, -r * 0.1), r * 0.16, Cute.COCOA)
	Cute.blush(self, c + Vector2(-r * 0.5, r * 0.22), r * 0.14)
	Cute.blush(self, c + Vector2(r * 0.5, r * 0.22), r * 0.14)
	Cute.smile(self, c + Vector2(0, r * 0.12), r * 0.15, Cute.COCOA)


func _draw_heart(c: Vector2, s: float, filled: bool) -> void:
	Cute.heart(self, c + Vector2(2, 3), s * 1.08, Color(0.36, 0.16, 0.26, 0.5), false)
	Cute.heart(self, c, s, Cute.PINK.darkened(0.05) if filled else Color(0.75, 0.7, 0.8), filled)


func _draw_star(c: Vector2, r: float, filled: bool) -> void:
	Cute.star(self, c, r, filled)
