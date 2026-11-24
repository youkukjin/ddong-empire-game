extends RefCounted
## 귀여운 디자인 (제안) 한 곳 모음이에요.
## 색, 둥근 젤리 버튼, 창, 귀여운 눈·볼터치·구름 그리기를 여기서 가져다 써요.
## 색을 바꾸고 싶으면 이 파일의 숫자만 고치면 게임 전체가 같이 바뀌어요.
##
## 2차 (제안): 깔끔하게. 버튼·창은 테두리를 줄이고 그림자로 떠 있는 느낌을 줘요.
## 3D 화면에서도 버튼·창·글자는 이 파일의 2D 모양을 그대로 써요.
##
## 원작 인물 설정(똥 왕자의 왕관·검·사슬 무기, 보라색 가시 드래곤 등)은 그대로 두고
## 색감과 모양만 부드럽게 바꿨어요.

const FONT_PATH := "res://assets/fonts/Jua-Regular.ttf"   # 둥근 한글 글꼴 '주아' (OFL 무료 글꼴)

# ---------------------------------------------------------------- 색 (제안: 파스텔)
const CREAM := Color(1.0, 0.969, 0.91)        # 종이 바탕
const CREAM_DOT := Color(1.0, 0.89, 0.84)      # 바탕 물방울
const COCOA := Color(0.43, 0.26, 0.17)         # 글자, 테두리
const PINK := Color(1.0, 0.6, 0.69)
const PEACH := Color(1.0, 0.7, 0.47)
const MINT := Color(0.42, 0.82, 0.66)
const SKY := Color(0.47, 0.74, 0.98)
const LEMON := Color(1.0, 0.8, 0.3)
const LILAC := Color(0.7, 0.58, 0.95)
const CARAMEL := Color(0.9, 0.6, 0.33)         # 기본 버튼
const LOCKED := Color(0.78, 0.75, 0.72)
const BLUSH := Color(1.0, 0.42, 0.55, 0.5)
const INK := Color(0.2, 0.11, 0.08)            # 눈동자

## 장마다 버튼 색 (장 고르기 화면)
const CHAPTER_COLORS := [PEACH, PINK, CARAMEL, SKY, LILAC, MINT, LEMON, PINK]


# ---------------------------------------------------------------- 버튼과 창

## 통통한 젤리 버튼이에요. 아래쪽 두꺼운 테두리가 그림자처럼 보이고, 누르면 쏙 들어가요.
static func button(text: String, min_size: Vector2, font_size: int, color := CARAMEL) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.focus_mode = Control.FOCUS_NONE
	style_button(btn, color, font_size)
	return btn


static func style_button(btn: Button, color: Color, font_size := 0) -> void:
	if font_size > 0:
		btn.add_theme_font_size_override("font_size", font_size)
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		btn.add_theme_color_override(s, Color.WHITE)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	btn.add_theme_constant_override("outline_size", 0)
	btn.add_theme_color_override("font_shadow_color", Color(color.darkened(0.5), 0.55))
	btn.add_theme_constant_override("shadow_offset_x", 0)
	btn.add_theme_constant_override("shadow_offset_y", 2)
	var r := int(clampf(btn.custom_minimum_size.y * 0.5, 18, 48))
	btn.add_theme_stylebox_override("normal", _jelly(color, r, false))
	btn.add_theme_stylebox_override("hover", _jelly(color.lightened(0.08), r, false))
	btn.add_theme_stylebox_override("focus", _jelly(color.lightened(0.08), r, false))
	btn.add_theme_stylebox_override("pressed", _jelly(color.darkened(0.08), r, true))
	btn.add_theme_stylebox_override("disabled", _jelly(LOCKED, r, false))


static func _jelly(color: Color, radius: int, pressed: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = color.darkened(0.22)
	s.border_width_bottom = 3 if pressed else 8
	s.shadow_color = Color(0.2, 0.1, 0.15, 0.18 if pressed else 0.28)
	s.shadow_size = 4 if pressed else 10
	s.shadow_offset = Vector2(0, 3 if pressed else 8)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10 if pressed else 5
	s.content_margin_bottom = 3 if pressed else 8
	s.expand_margin_top = -2.0 if pressed else 0.0
	s.anti_aliasing = true
	return s


## 결과·멈춤 창 바탕이에요: 크림색에 분홍 테두리.
static func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = CREAM
	s.set_corner_radius_all(40)
	s.set_border_width_all(2)
	s.border_width_bottom = 8
	s.border_color = Color(0.93, 0.85, 0.8)
	s.set_content_margin_all(36)
	s.shadow_color = Color(0.2, 0.08, 0.15, 0.35)
	s.shadow_size = 30
	s.shadow_offset = Vector2(0, 16)
	return s


## 창 뒤를 살짝 어둡게 (검정 대신 포근한 자주색)
const DIM := Color(0.2, 0.12, 0.2, 0.45)


## 화면 위 표시줄 바탕: 아래가 둥근 반투명 띠.
static func hud_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.25, 0.15, 0.25, 0.42)
	s.corner_radius_bottom_left = 30
	s.corner_radius_bottom_right = 30
	s.shadow_color = Color(0, 0, 0, 0.12)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 4)
	return s


static func round_box(color: Color, radius := 24, border := Color(1, 1, 1, 0.0), border_w := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.set_border_width_all(border_w)
		s.border_color = border
	return s


static func style_label(l: Label, font_size: int, color := COCOA, outline := Color(1, 1, 1, 0), outline_size := 0) -> void:
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if outline_size > 0:
		l.add_theme_color_override("font_outline_color", outline)
		l.add_theme_constant_override("outline_size", outline_size)


# ---------------------------------------------------------------- 그리기 도우미

## 반짝이는 큰 눈이에요. look: 바라보는 쪽 (-1~1)
static func eye(ci: CanvasItem, c: Vector2, r: float, look := Vector2.ZERO, white := true) -> void:
	if white:
		ci.draw_circle(c, r, Color.WHITE)
	var p := c + look * r * 0.25
	var pr := r * (0.8 if white else 1.0)
	ci.draw_circle(p, pr, INK)
	ci.draw_circle(p + Vector2(-pr * 0.32, -pr * 0.36), pr * 0.36, Color.WHITE)
	ci.draw_circle(p + Vector2(pr * 0.35, pr * 0.3), pr * 0.16, Color(1, 1, 1, 0.9))


## 웃는 눈 (^ ^)
static func happy_eye(ci: CanvasItem, c: Vector2, r: float, color := INK) -> void:
	ci.draw_arc(c + Vector2(0, r * 0.4), r * 0.8, PI + 0.4, TAU - 0.4, 10, color, maxf(r * 0.35, 2.0))


static func blush(ci: CanvasItem, c: Vector2, r: float) -> void:
	_oval(ci, c, Vector2(r, r * 0.6), BLUSH)


## 작게 웃는 입 (w: 입 너비의 절반)
static func smile(ci: CanvasItem, c: Vector2, w: float, color := INK, open := false) -> void:
	if open:
		var pts := PackedVector2Array()
		for i in 13:
			var a := PI * i / 12.0
			pts.append(c + Vector2(cos(a) * w, sin(a) * w * 0.9))
		ci.draw_colored_polygon(pts, Color(0.55, 0.15, 0.2))
		ci.draw_circle(c + Vector2(0, w * 0.55), w * 0.4, Color(1, 0.5, 0.55))
	else:
		ci.draw_arc(c, w, 0.35, PI - 0.35, 10, color, maxf(w * 0.35, 2.5))


## 몽글몽글 구름
static func cloud(ci: CanvasItem, c: Vector2, s: float, color := Color(1, 1, 1, 0.9)) -> void:
	ci.draw_circle(c + Vector2(-s * 0.55, s * 0.1), s * 0.45, color)
	ci.draw_circle(c + Vector2(s * 0.55, s * 0.12), s * 0.42, color)
	ci.draw_circle(c + Vector2(-s * 0.1, -s * 0.2), s * 0.6, color)
	ci.draw_circle(c + Vector2(s * 0.3, -s * 0.05), s * 0.45, color)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.55, 0), Vector2(s * 1.1, s * 0.55)), color)


## 네 갈래 반짝이
static func sparkle(ci: CanvasItem, c: Vector2, r: float, color := Color(1, 1, 0.85)) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := i * PI / 4.0
		var rr := r if i % 2 == 0 else r * 0.28
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, color)


## 통통한 하트
static func heart(ci: CanvasItem, c: Vector2, s: float, color: Color, shine := true) -> void:
	ci.draw_circle(c + Vector2(-s * 0.45, -s * 0.2), s * 0.52, color)
	ci.draw_circle(c + Vector2(s * 0.45, -s * 0.2), s * 0.52, color)
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.93, 0.0), c + Vector2(s * 0.93, 0.0), c + Vector2(0, s * 0.92)]), color)
	if shine:
		ci.draw_circle(c + Vector2(-s * 0.5, -s * 0.32), s * 0.16, Color(1, 1, 1, 0.75))


## 둥근 별 (선 대신 통통한 모양)
static func star(ci: CanvasItem, c: Vector2, r: float, filled: bool) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.52
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, COCOA if filled else Color(0.6, 0.55, 0.5), 7.0, true)
	ci.draw_colored_polygon(pts, LEMON if filled else Color(0.88, 0.85, 0.8))
	if filled:
		ci.draw_circle(c + Vector2(-r * 0.22, -r * 0.18), r * 0.12, Color(1, 1, 1, 0.85))
		eye(ci, c + Vector2(-r * 0.18, r * 0.05), r * 0.09, Vector2.ZERO, false)
		eye(ci, c + Vector2(r * 0.18, r * 0.05), r * 0.09, Vector2.ZERO, false)


## 반투명 동그라미 물방울 무늬 (종이 바탕용)
static func dots(ci: CanvasItem, area: Vector2, color := CREAM_DOT, step := 90.0) -> void:
	var row := 0
	var y := 30.0
	while y < area.y + step:
		var x := 30.0 + (step * 0.5 if row % 2 == 1 else 0.0)
		while x < area.x + step:
			ci.draw_circle(Vector2(x, y), 9, color)
			x += step
		y += step * 0.8
		row += 1


static func _oval(ci: CanvasItem, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)


## 종이 바탕 (크림색 + 물방울)
class Paper extends Control:
	var color := CREAM

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), color)
		var step := 120.0
		var row := 0
		var y := 30.0
		while y < size.y + step:
			var x := 30.0 + (step * 0.5 if row % 2 == 1 else 0.0)
			while x < size.x + step:
				draw_circle(Vector2(x, y), 6, Color(CREAM_DOT, 0.55))
				x += step
			y += step * 0.8
			row += 1
