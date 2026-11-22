extends Node2D
## 밤 배경: 밤하늘, 초승달, 별, 차선이 그려진 검은 도로, 둥근 돔 대피소 (원작 밤 장면).
## 그림이 나오면 이 노드를 Sprite2D로 바꾸면 돼요.

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
	# 밤하늘
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.07, 0.08, 0.2))
	draw_rect(Rect2(0, 220, SIZE.x, ROAD_TOP - 220), Color(0.12, 0.12, 0.28))
	for s in _stars:
		draw_circle(s, 2.0, Color(1, 1, 0.85, 0.8))
	# 초승달
	draw_circle(Vector2(1060, 170), 44, Color(1, 0.95, 0.6))
	draw_circle(Vector2(1080, 156), 40, Color(0.07, 0.08, 0.2))
	# 마을 집들 실루엣 (제안: 임시 배경)
	for i in 7:
		var x := 380.0 + i * 120.0
		var hgt := 60.0 + (i % 3) * 22.0
		draw_rect(Rect2(x, ROAD_TOP - hgt, 80, hgt), Color(0.18, 0.15, 0.28))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 8, ROAD_TOP - hgt), Vector2(x + 40, ROAD_TOP - hgt - 34),
			Vector2(x + 88, ROAD_TOP - hgt)]), Color(0.22, 0.18, 0.32))
	# 도로
	draw_rect(Rect2(0, ROAD_TOP, SIZE.x, ROAD_BOTTOM - ROAD_TOP), Color(0.13, 0.13, 0.15))
	draw_rect(Rect2(0, ROAD_BOTTOM, SIZE.x, SIZE.y - ROAD_BOTTOM), Color(0.2, 0.17, 0.14))
	var mid := (ROAD_TOP + ROAD_BOTTOM) / 2.0
	var x2 := 0.0
	while x2 < SIZE.x:
		draw_rect(Rect2(x2, mid - 4, 50, 8), Color(1, 0.85, 0.3))
		x2 += 100.0
	# 돔 대피소
	var glow := Color(1, 0.9, 0.55, 0.25)
	draw_circle(DOME_CENTER, DOME_RADIUS + 18, glow)
	_draw_half_disc(DOME_CENTER, DOME_RADIUS, Color(0.85, 0.82, 0.95))
	_draw_half_disc(DOME_CENTER, DOME_RADIUS - 14, Color(0.6, 0.58, 0.78))
	draw_rect(Rect2(DOME_CENTER.x - 30, DOME_CENTER.y - 60, 60, 60), Color(1, 0.85, 0.4))
	# 돔 안의 백성 머리
	for i in rescued:
		var row := i / 5
		var col := i % 5
		var p := DOME_CENTER + Vector2(-80 + col * 40, -18 - row * 30)
		draw_circle(p, 11, Color(0.55, 0.35, 0.18))
	var font := ThemeDB.fallback_font
	draw_string(font, DOME_CENTER + Vector2(-60, -DOME_RADIUS - 26), "대피소", \
		HORIZONTAL_ALIGNMENT_CENTER, 120, 30, Color(1, 0.95, 0.75))


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
