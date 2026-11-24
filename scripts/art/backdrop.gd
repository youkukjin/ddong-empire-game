extends Node2D
## 장마다 쓰는 임시 배경이에요. kind에 따라 다르게 그려요. 그림이 나오면 Sprite2D로 바꾸면 돼요.
## 배경 장소는 원작 그림(밤 마을, 구멍, 벽돌 성벽)을 따르고, 나머지는 (제안)이에요.

const Cute := preload("res://scripts/art/cute.gd")
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
	# 귀여운 디자인 (제안): 장소는 그대로, 색만 파스텔로 밝게
	match kind:
		"yard":
			_sky(Color(0.62, 0.84, 1.0), Color(0.88, 0.95, 1.0))
			_sun(Vector2(1120, 110), 56)
			Cute.cloud(self, Vector2(260, 120), 60)
			Cute.cloud(self, Vector2(760, 80), 44)
			draw_rect(Rect2(0, GROUND_Y, SIZE.x, SIZE.y - GROUND_Y), Color(0.56, 0.84, 0.5))
			draw_rect(Rect2(0, GROUND_Y, SIZE.x, 10), Color(0.66, 0.9, 0.58))
			var wood := Color(0.86, 0.62, 0.42)
			draw_rect(Rect2(0, GROUND_Y - 60, SIZE.x, 12), wood)
			draw_rect(Rect2(0, GROUND_Y - 30, SIZE.x, 12), wood)
			for i in 14:
				var x := 40.0 + i * 92.0
				draw_rect(Rect2(x, GROUND_Y - 70, 16, 70), wood.lightened(0.1))
				draw_circle(Vector2(x + 8, GROUND_Y - 70), 8, wood.lightened(0.1))
			_flowers(GROUND_Y + 40)
		"tunnel":
			draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.5, 0.36, 0.28))
			draw_rect(Rect2(0, 0, SIZE.x, 120), Color(0.4, 0.28, 0.22))
			for i in 12:
				draw_circle(Vector2(i * 120 + 50, 120), 34, Color(0.4, 0.28, 0.22))
			draw_rect(Rect2(0, GROUND_Y, SIZE.x, SIZE.y - GROUND_Y), Color(0.66, 0.5, 0.38))
			draw_rect(Rect2(0, GROUND_Y, SIZE.x, 10), Color(0.74, 0.58, 0.44))
		"wall":
			_sky(Color(0.47, 0.42, 0.72), Color(0.96, 0.7, 0.72))
			_stars(Color(1, 1, 0.85, 0.7))
			draw_rect(Rect2(0, GROUND_Y, SIZE.x, SIZE.y - GROUND_Y), Color(0.62, 0.5, 0.48))
			draw_rect(Rect2(0, GROUND_Y, SIZE.x, 10), Color(0.72, 0.6, 0.56))
		"arena":
			_sky(Color(0.45, 0.33, 0.6), Color(0.86, 0.6, 0.72))
			for i in 9:
				var x := i * 160.0
				draw_rect(Rect2(x, 140, 60, GROUND_Y - 140), Color(0.58, 0.44, 0.68))
				draw_circle(Vector2(x + 30, 140), 30, Color(0.58, 0.44, 0.68))
				draw_rect(Rect2(x + 10, 150, 10, GROUND_Y - 170), Color(1, 1, 1, 0.12))
			draw_rect(Rect2(0, GROUND_Y, SIZE.x, SIZE.y - GROUND_Y), Color(0.62, 0.48, 0.52))
			draw_rect(Rect2(0, GROUND_Y, SIZE.x, 10), Color(0.72, 0.58, 0.62))
		"lair":
			_sky(Color(0.33, 0.23, 0.5), Color(0.66, 0.4, 0.66))
			for i in 7:
				var x := 90.0 + i * 190.0
				var tip := 90.0 + (i % 3) * 30
				draw_colored_polygon(PackedVector2Array([Vector2(x - 50, 0), Vector2(x + 50, 0), Vector2(x + 8, tip - 10), Vector2(x, tip), Vector2(x - 8, tip - 10)]), Color(0.45, 0.3, 0.6))
			for i in 8:
				Cute.sparkle(self, Vector2(70 + i * 160, 200 + (i % 3) * 90), 8, Color(0.9, 0.75, 1, 0.6))
			draw_rect(Rect2(0, GROUND_Y, SIZE.x, SIZE.y - GROUND_Y), Color(0.55, 0.4, 0.58))
			draw_rect(Rect2(0, GROUND_Y, SIZE.x, 10), Color(0.65, 0.5, 0.68))
		"town":
			var night := Color(0.22, 0.22, 0.48)
			var day := Color(0.62, 0.84, 1.0)
			_sky(night.lerp(day, tint), Color(0.5, 0.4, 0.68).lerp(Color(1.0, 0.9, 0.82), tint))
			if tint < 0.5:
				_stars(Color(1, 1, 0.85, 0.8 * (1.0 - tint * 2.0)))
			else:
				Cute.cloud(self, Vector2(300, 120), 54, Color(1, 1, 1, (tint - 0.5) * 1.8))
				Cute.cloud(self, Vector2(760, 90), 40, Color(1, 1, 1, (tint - 0.5) * 1.8))
			draw_rect(Rect2(0, 470, SIZE.x, SIZE.y - 470), Color(0.36, 0.33, 0.47).lerp(Color(0.66, 0.62, 0.66), tint))
			draw_rect(Rect2(0, 470, SIZE.x, 10), Color(0.48, 0.44, 0.6).lerp(Color(0.78, 0.74, 0.76), tint))
			for i in 8:
				var x := 40.0 + i * 160
				draw_rect(Rect2(x + 5, 585, 70, 10), Color(1, 0.88, 0.45, 0.85))
				draw_circle(Vector2(x + 5, 590), 5, Color(1, 0.88, 0.45, 0.85))
				draw_circle(Vector2(x + 75, 590), 5, Color(1, 0.88, 0.45, 0.85))
			if tint < 0.5:
				draw_circle(Vector2(1060, 120), 50, Color(1, 0.95, 0.6, 0.25))
				draw_circle(Vector2(1060, 120), 44, Color(1, 0.95, 0.6))
				draw_circle(Vector2(1080, 106), 40, night.lerp(day, tint).lerp(Color(0.5, 0.4, 0.68), 0.2))
				Cute.happy_eye(self, Vector2(1034, 126), 6, Cute.COCOA)
				Cute.blush(self, Vector2(1040, 142), 6)
			else:
				_sun(Vector2(1100, 110), 56, (tint - 0.5) * 2.0)


func _sky(top: Color, bottom: Color) -> void:
	var bands := 10
	for i in bands:
		draw_rect(Rect2(0, i * GROUND_Y / bands, SIZE.x, GROUND_Y / bands + 1), top.lerp(bottom, float(i) / (bands - 1)))


## 웃는 해님 (제안)
func _sun(c: Vector2, r: float, alpha := 1.0) -> void:
	draw_circle(c, r + 16, Color(1, 0.92, 0.5, 0.3 * alpha))
	draw_circle(c, r, Color(1, 0.86, 0.4, alpha))
	Cute.happy_eye(self, c + Vector2(-r * 0.32, -r * 0.08), r * 0.14, Color(Cute.COCOA, alpha))
	Cute.happy_eye(self, c + Vector2(r * 0.32, -r * 0.08), r * 0.14, Color(Cute.COCOA, alpha))
	draw_circle(c + Vector2(-r * 0.55, r * 0.25), r * 0.14, Color(1, 0.55, 0.55, 0.5 * alpha))
	draw_circle(c + Vector2(r * 0.55, r * 0.25), r * 0.14, Color(1, 0.55, 0.55, 0.5 * alpha))
	draw_arc(c + Vector2(0, r * 0.12), r * 0.16, 0.3, PI - 0.3, 8, Color(Cute.COCOA, alpha), 3)


func _stars(col: Color) -> void:
	for i in 26:
		var p := Vector2(fmod(i * 197.0, SIZE.x), 30 + fmod(i * 83.0, 300.0))
		if i % 5 == 0:
			Cute.sparkle(self, p, 7, col)
		else:
			draw_circle(p, 2.2, col)


func _flowers(y: float) -> void:
	for i in 10:
		var p := Vector2(60 + i * 130, y + (i % 3) * 20)
		for k in 5:
			var a := TAU * k / 5.0
			draw_circle(p + Vector2(cos(a), sin(a)) * 6, 5, [Cute.PINK, Color.WHITE, Cute.LEMON][i % 3])
		draw_circle(p, 4, Cute.PEACH)
