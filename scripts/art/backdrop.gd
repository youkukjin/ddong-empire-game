extends Node2D
## 장마다 쓰는 임시 배경이에요. kind에 따라 다르게 그려요. 그림이 나오면 Sprite2D로 바꾸면 돼요.
## 배경 장소는 원작 그림(밤 마을, 구멍, 벽돌 성벽)을 따르고, 나머지는 (제안)이에요.

const SIZE := Vector2(1280, 720)
const GROUND_Y := 600.0

var kind := "yard"
var tint := 0.0:          # 8장: 밤 → 낮으로 밝아지는 정도 0~1
	set(v):
		tint = v
		queue_redraw()


func _init(p_kind := "yard") -> void:
	kind = p_kind


func _draw() -> void:
	match kind:
		"yard":
			_sky(Color(0.62, 0.82, 0.95), Color(0.85, 0.93, 0.98))
			draw_rect(Rect2(0, GROUND_Y, SIZE.x, SIZE.y - GROUND_Y), Color(0.55, 0.75, 0.38))
			for i in 14:
				var x := 40.0 + i * 92.0
				draw_rect(Rect2(x, GROUND_Y - 70, 12, 70), Color(0.62, 0.45, 0.28))
			draw_rect(Rect2(0, GROUND_Y - 60, SIZE.x, 10), Color(0.62, 0.45, 0.28))
			draw_rect(Rect2(0, GROUND_Y - 30, SIZE.x, 10), Color(0.62, 0.45, 0.28))
			draw_circle(Vector2(1120, 110), 56, Color(1, 0.92, 0.5))
		"tunnel":
			draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.2, 0.14, 0.1))
			draw_rect(Rect2(0, 0, SIZE.x, 120), Color(0.12, 0.08, 0.06))
			draw_rect(Rect2(0, GROUND_Y, SIZE.x, SIZE.y - GROUND_Y), Color(0.32, 0.22, 0.14))
		"wall":
			_sky(Color(0.16, 0.14, 0.3), Color(0.32, 0.22, 0.38))
			draw_rect(Rect2(0, GROUND_Y, SIZE.x, SIZE.y - GROUND_Y), Color(0.3, 0.24, 0.2))
		"arena":
			_sky(Color(0.2, 0.12, 0.22), Color(0.36, 0.2, 0.3))
			for i in 9:
				var x := i * 160.0
				draw_rect(Rect2(x, 140, 60, GROUND_Y - 140), Color(0.28, 0.18, 0.26))
			draw_rect(Rect2(0, GROUND_Y, SIZE.x, SIZE.y - GROUND_Y), Color(0.34, 0.24, 0.22))
		"lair":
			_sky(Color(0.12, 0.05, 0.18), Color(0.3, 0.12, 0.35))
			for i in 7:
				var x := 90.0 + i * 190.0
				draw_colored_polygon(PackedVector2Array([Vector2(x - 50, 0), Vector2(x + 50, 0), Vector2(x, 90 + (i % 3) * 30)]), Color(0.2, 0.08, 0.24))
			draw_rect(Rect2(0, GROUND_Y, SIZE.x, SIZE.y - GROUND_Y), Color(0.26, 0.16, 0.24))
		"town":
			var night := Color(0.07, 0.08, 0.2)
			var day := Color(0.62, 0.82, 0.95)
			_sky(night.lerp(day, tint), night.lerp(Color(0.95, 0.85, 0.7), tint))
			draw_rect(Rect2(0, 470, SIZE.x, SIZE.y - 470), Color(0.16, 0.16, 0.2).lerp(Color(0.45, 0.42, 0.4), tint))
			for i in 8:
				draw_rect(Rect2(40 + i * 160, 585, 80, 10), Color(1, 0.95, 0.6, 0.7))
			if tint < 0.5:
				draw_circle(Vector2(1060, 120), 44, Color(1, 0.95, 0.6))
				draw_circle(Vector2(1080, 106), 40, night.lerp(day, tint))
			else:
				draw_circle(Vector2(1100, 110), 56, Color(1, 0.92, 0.5, (tint - 0.5) * 2.0))


func _sky(top: Color, bottom: Color) -> void:
	var bands := 8
	for i in bands:
		draw_rect(Rect2(0, i * GROUND_Y / bands, SIZE.x, GROUND_Y / bands + 1), top.lerp(bottom, float(i) / (bands - 1)))
