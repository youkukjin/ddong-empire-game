extends Node2D
## 밤 배경: 밤하늘, 초승달, 별, 차선이 그려진 검은 도로, 둥근 돔 대피소 (원작 밤 장면).
## 그림이 나오면 이 노드를 Sprite2D로 바꾸면 돼요.

const Cute := preload("res://scripts/art/cute.gd")
const SIZE := Vector2(1280, 720)
const ROAD_TOP := 380.0
const ROAD_BOTTOM := 660.0
const DOME_CENTER := Vector2(1130, 640)
const DOME_RADIUS := 140.0

var rescued := 0:
	set(v):
		rescued = v
		queue_redraw()

var _stars: Array[Vector2] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		_stars.append(Vector2(rng.randf_range(420, 1260), rng.randf_range(20, 340)))


func _draw() -> void:
	# 밤하늘 (귀여운 디자인 제안: 보랏빛 파스텔 밤)
	var top := Color(0.2, 0.2, 0.45)
	var low := Color(0.42, 0.33, 0.6)
	for k in 8:
		draw_rect(Rect2(0, k * ROAD_TOP / 8.0, SIZE.x, ROAD_TOP / 8.0 + 1), top.lerp(low, k / 7.0))
	for idx in _stars.size():
		var s: Vector2 = _stars[idx]
		if idx % 4 == 0:
			Cute.sparkle(self, s, 7.0, Color(1, 1, 0.8, 0.9))
		else:
			draw_circle(s, 2.4, Color(1, 1, 0.85, 0.85))
	# 초승달
	draw_circle(Vector2(1060, 170), 50, Color(1, 0.95, 0.6, 0.25))
	draw_circle(Vector2(1060, 170), 44, Color(1, 0.95, 0.6))
	draw_circle(Vector2(1080, 156), 40, top.lerp(low, 0.4))
	Cute.happy_eye(self, Vector2(1034, 176), 6, Cute.COCOA)
	Cute.blush(self, Vector2(1040, 192), 6)
	# 몽글 구름
	Cute.cloud(self, Vector2(820, 120), 40, Color(0.42, 0.38, 0.64))
	Cute.cloud(self, Vector2(560, 210), 30, Color(0.5, 0.42, 0.68))
	# 마을 집들 (제안: 임시 배경, 창문에 불빛)
	var walls := [Color(0.56, 0.45, 0.7), Color(0.62, 0.48, 0.66), Color(0.5, 0.47, 0.72)]
	var roofs := [Color(0.85, 0.5, 0.62), Color(0.6, 0.5, 0.85), Color(0.9, 0.62, 0.5)]
	for i in 7:
		var x := 380.0 + i * 120.0
		var hgt := 60.0 + (i % 3) * 22.0
		draw_rect(Rect2(x, ROAD_TOP - hgt, 80, hgt), walls[i % 3])
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 10, ROAD_TOP - hgt + 2), Vector2(x + 40, ROAD_TOP - hgt - 36),
			Vector2(x + 90, ROAD_TOP - hgt + 2)]), roofs[i % 3])
		draw_rect(Rect2(x + 28, ROAD_TOP - hgt + 16, 24, 22), Color(1, 0.9, 0.55))
		draw_line(Vector2(x + 40, ROAD_TOP - hgt + 16), Vector2(x + 40, ROAD_TOP - hgt + 38), walls[i % 3], 3)
	# 도로
	draw_rect(Rect2(0, ROAD_TOP, SIZE.x, ROAD_BOTTOM - ROAD_TOP), Color(0.33, 0.3, 0.42))
	draw_rect(Rect2(0, ROAD_TOP, SIZE.x, 10), Color(0.45, 0.4, 0.55))
	draw_rect(Rect2(0, ROAD_BOTTOM, SIZE.x, SIZE.y - ROAD_BOTTOM), Color(0.45, 0.62, 0.45))
	var mid := (ROAD_TOP + ROAD_BOTTOM) / 2.0
	var x2 := 0.0
	while x2 < SIZE.x:
		draw_circle(Vector2(x2 + 6, mid), 6, Color(1, 0.85, 0.4))
		draw_circle(Vector2(x2 + 44, mid), 6, Color(1, 0.85, 0.4))
		draw_rect(Rect2(x2 + 6, mid - 6, 38, 12), Color(1, 0.85, 0.4))
		x2 += 100.0
	# 돔 대피소
	var glow := Color(1, 0.9, 0.55, 0.3)
	draw_circle(DOME_CENTER, DOME_RADIUS + 18, glow)
	_draw_half_disc(DOME_CENTER, DOME_RADIUS, Color(1, 0.86, 0.92))
	_draw_half_disc(DOME_CENTER, DOME_RADIUS - 14, Color(0.78, 0.7, 0.95))
	draw_circle(DOME_CENTER + Vector2(-60, -90), 14, Color(1, 1, 1, 0.4))
	draw_rect(Rect2(DOME_CENTER.x - 30, DOME_CENTER.y - 60, 60, 60), Color(1, 0.85, 0.4))
	draw_circle(DOME_CENTER + Vector2(0, -60), 30, Color(1, 0.85, 0.4))
	# 돔 안의 백성 머리 (동글 얼굴)
	for i in rescued:
		var row := i / 5
		var col := i % 5
		var p := DOME_CENTER + Vector2(-80 + col * 40, -18 - row * 30)
		draw_circle(p, 12, Color(0.45, 0.28, 0.15))
		draw_circle(p, 10.5, Color(0.68, 0.45, 0.26))
		Cute.happy_eye(self, p + Vector2(-4, -1), 2.5, Color.WHITE)
		Cute.happy_eye(self, p + Vector2(4, -1), 2.5, Color.WHITE)
	var font := ThemeDB.fallback_font
	draw_string_outline(font, DOME_CENTER + Vector2(-60, -DOME_RADIUS - 26), "대피소", \
		HORIZONTAL_ALIGNMENT_CENTER, 120, 32, 10, Color(0.36, 0.16, 0.26))
	draw_string(font, DOME_CENTER + Vector2(-60, -DOME_RADIUS - 26), "대피소", \
		HORIZONTAL_ALIGNMENT_CENTER, 120, 32, Color(1, 0.95, 0.75))


func _draw_half_disc(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := PI + PI * i / 32.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, color)


static func is_in_dome(p: Vector2) -> bool:
	return p.distance_to(DOME_CENTER) < DOME_RADIUS + 20.0


static func random_road_point(rng: RandomNumberGenerator, max_x := 920.0) -> Vector2:
	return Vector2(rng.randf_range(400, max_x), rng.randf_range(ROAD_TOP + 50, ROAD_BOTTOM - 10))


static func clamp_to_road(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 380, 960), clampf(p.y, ROAD_TOP + 50, ROAD_BOTTOM - 10))
