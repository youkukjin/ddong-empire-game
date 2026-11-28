extends Button
## 레벨업 카드: 스킬북 한 쪽처럼 그려요 (2026-11-28 사용자: "스킬북처럼").
## 가죽 표지 테두리 + 종이 쪽 + 왼쪽 그림 칸(스킬 그림) + 이름, 레벨 칸, 설명.
## 그림은 그림 파일 없이 도형으로 그려요.

const FONT := preload("res://assets/fonts/Jua-Regular.ttf")
const INK := Color(0.16, 0.08, 0.06)

var card: Dictionary = {}       # {kind, id, title, desc}
var level := 0                  # 고르면 몇 레벨이 되는지
var max_level := 5
var _t := 0.0


func _init(c: Dictionary, lv: int, max_lv: int) -> void:
	card = c
	level = lv
	max_level = max_lv
	text = ""
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(640, 250)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())


func _process(delta: float) -> void:
	_t += delta
	if card.kind == "evolve" or button_pressed or is_hovered():
		queue_redraw()


func _kind_color() -> Color:
	match card.kind:
		"evolve":
			return Color(1, 0.72, 0.1)
		"weapon":
			return Color(0.85, 0.3, 0.25)
		"passive":
			return Color(0.25, 0.55, 0.85)
	return Color(0.4, 0.7, 0.35)


func _draw() -> void:
	var sz := size
	var press := 4.0 if button_pressed else 0.0
	var r := Rect2(Vector2(0, press), sz - Vector2(0, 6))
	var kc := _kind_color()
	# 그림자
	_round(Rect2(r.position + Vector2(0, 8), r.size), 22, Color(0, 0, 0, 0.35))
	# 진화 카드는 금빛이 반짝여요
	if card.kind == "evolve":
		var glow := 0.5 + 0.5 * sin(_t * 6.0)
		_round(r.grow(6 + glow * 4), 28, Color(1, 0.85, 0.2, 0.35 + glow * 0.3))
	# 가죽 표지
	var cover := Color(0.45, 0.22, 0.12) if card.kind != "evolve" else Color(0.6, 0.38, 0.05)
	_round(r, 22, cover)
	_round(r.grow(-5), 18, cover.lightened(0.12))
	# 책등 (왼쪽 굵은 띠와 금박 줄)
	_round(Rect2(r.position + Vector2(8, 8), Vector2(26, r.size.y - 16)), 8, cover.darkened(0.35))
	for yy in [0.2, 0.5, 0.8]:
		draw_rect(Rect2(r.position + Vector2(8, r.size.y * yy - 3), Vector2(26, 6)), Color(1, 0.8, 0.3))
	# 종이 쪽
	var page := Rect2(r.position + Vector2(42, 14), r.size - Vector2(56, 28))
	_round(page, 12, Color(1, 0.96, 0.85))
	draw_rect(Rect2(page.position + Vector2(page.size.x - 8, 6), Vector2(6, page.size.y - 12)), Color(0.9, 0.84, 0.7))
	# 그림 칸
	var box := Rect2(page.position + Vector2(14, 14), Vector2(page.size.y - 28, page.size.y - 28))
	_round(box, 14, kc.darkened(0.2))
	_round(box.grow(-5), 11, kc.lightened(0.25))
	draw_circle(box.get_center(), box.size.x * 0.36, Color(1, 1, 1, 0.35))
	draw_icon(self, String(card.id), box.get_center(), box.size.x * 0.34, _t)
	# 글자
	var tx := box.end.x + 18
	var tag: String = {"evolve": "진화!", "weapon": "새 무기" if level <= 1 else "무기 강화", "passive": "능력치", "heal": "회복"}.get(card.kind, "")
	var tag_w := FONT.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 20
	_round(Rect2(Vector2(tx, page.position.y + 12), Vector2(tag_w, 32)), 10, kc)
	draw_string(FONT, Vector2(tx + 10, page.position.y + 36), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	var title_text := String(card.get("name", card.title))
	draw_string_outline(FONT, Vector2(tx, page.position.y + 88), title_text, HORIZONTAL_ALIGNMENT_LEFT, page.end.x - tx - 12, 38, 6, Color.WHITE)
	draw_string(FONT, Vector2(tx, page.position.y + 88), title_text, HORIZONTAL_ALIGNMENT_LEFT, page.end.x - tx - 12, 38, INK)
	# 레벨 칸 (●○○○○)
	if card.kind == "weapon" or card.kind == "passive":
		for i in max_level:
			var c := Vector2(tx + 14 + i * 32, page.position.y + 116)
			draw_circle(c, 11, INK)
			draw_circle(c, 8, kc if i < level else Color(0.88, 0.82, 0.7))
			if i == level - 1:
				draw_circle(c, 4, Color(1, 1, 1, 0.8 + 0.2 * sin(_t * 8.0)))
	elif card.kind == "evolve":
		draw_string(FONT, Vector2(tx, page.position.y + 124), "★ ★ ★", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.85, 0.55, 0.05))
	# 설명 (두 줄까지)
	var lines := _wrap(String(card.desc), page.end.x - tx - 16, 24)
	for i in mini(lines.size(), 2):
		draw_string(FONT, Vector2(tx, page.position.y + 162 + i * 30), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, INK.lightened(0.25))


func _wrap(s: String, width: float, fs: int) -> Array:
	var out: Array = []
	var line := ""
	for word in s.split(" "):
		var t := word if line == "" else line + " " + word
		if FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = t
	if line != "":
		out.append(line)
	return out


func _round(r: Rect2, radius: int, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, r)


# ------------------------------------------------------------------ 스킬 그림

static func _poop(ci: CanvasItem, c: Vector2, s: float, col := Color(0.56, 0.33, 0.15)) -> void:
	for t in [[0.0, 0.62, 1.0], [-0.55, 0.48, 0.8], [-0.95, 0.32, 0.62]]:
		ci.draw_circle(c + Vector2(0, t[0] * s), t[1] * s + 3, INK)
	for t in [[0.0, 0.62, 1.0], [-0.55, 0.48, 0.8], [-0.95, 0.32, 0.62]]:
		ci.draw_circle(c + Vector2(0, t[0] * s), t[1] * s, col)


static func _line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(a, b, INK, w + 6, true)
	ci.draw_line(a, b, col, w, true)
	ci.draw_circle(a, w * 0.5 + 3, INK)
	ci.draw_circle(b, w * 0.5 + 3, INK)
	ci.draw_circle(a, w * 0.5, col)
	ci.draw_circle(b, w * 0.5, col)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_colored_polygon(pts, col)
	ci.draw_polyline(closed, INK, 4.0, true)


static func _dot(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r + 3, INK)
	ci.draw_circle(c, r, col)


static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float, t := 0.0) -> void:
	match id:
		"sword":
			_line(ci, c + Vector2(-0.7, 0.7) * s, c + Vector2(0.75, -0.75) * s, Color(0.85, 0.9, 1.0), 12)
			_line(ci, c + Vector2(-0.65, 0.25) * s, c + Vector2(-0.25, 0.65) * s, Color(0.95, 0.7, 0.15), 10)
			_dot(ci, c + Vector2(-0.8, 0.8) * s, 7, Color(0.95, 0.7, 0.15))
		"chain":
			for i in 4:
				var p := c + Vector2(-0.8 + i * 0.32, 0.7 - i * 0.32) * s
				ci.draw_arc(p, 7, 0, TAU, 12, INK, 4)
			_dot(ci, c + Vector2(0.35, -0.35) * s, s * 0.42, Color(0.3, 0.75, 0.3))
			for k in 6:
				var d := Vector2.from_angle(k * TAU / 6 + t)
				_line(ci, c + Vector2(0.35, -0.35) * s + d * s * 0.4, c + Vector2(0.35, -0.35) * s + d * s * 0.62, Color(0.9, 0.9, 1), 5)
		"fist":
			_dot(ci, c + Vector2(0, 0.1) * s, s * 0.6, Color(0.62, 0.38, 0.18))
			for i in 4:
				_dot(ci, c + Vector2(-0.42 + i * 0.28, -0.42) * s, s * 0.17, Color(0.68, 0.42, 0.2))
			_line(ci, c + Vector2(-0.95, 0.85) * s, c + Vector2(-0.6, 0.5) * s, Color(1, 0.85, 0.3), 6)
			_line(ci, c + Vector2(0.95, 0.85) * s, c + Vector2(0.6, 0.5) * s, Color(1, 0.85, 0.3), 6)
		"bomb":
			_poop(ci, c + Vector2(0, 0.35) * s, s * 0.6)
			_line(ci, c + Vector2(0.15, -0.35) * s, c + Vector2(0.45, -0.8) * s, Color(0.5, 0.4, 0.3), 5)
			Cute_spark(ci, c + Vector2(0.5, -0.85) * s, s * 0.25, t)
		"flies":
			for i in 3:
				var p := c + Vector2(cos(i * 2.1 + t * 2.0), sin(i * 2.1 + t * 2.0)) * s * 0.5
				ci.draw_circle(p + Vector2(-6, -8), 8, Color(0.85, 0.95, 1, 0.8))
				ci.draw_circle(p + Vector2(6, -8), 8, Color(0.85, 0.95, 1, 0.8))
				_dot(ci, p, 9, Color(0.15, 0.2, 0.12))
				ci.draw_circle(p + Vector2(3, -2), 3, Color(1, 0.2, 0.1))
		"beam":
			_line(ci, c + Vector2(-0.85, 0.5) * s, c + Vector2(0.9, -0.5) * s, Color(0.75, 0.35, 1), 22)
			ci.draw_line(c + Vector2(-0.85, 0.5) * s, c + Vector2(0.9, -0.5) * s, Color(1, 0.95, 1), 7, true)
			_dot(ci, c + Vector2(-0.85, 0.5) * s, 14, Color(0.9, 0.7, 1))
		"boomerang":
			var pts := PackedVector2Array([c + Vector2(-0.85, -0.2) * s, c + Vector2(0.0, -0.75) * s, c + Vector2(0.85, -0.2) * s,
				c + Vector2(0.6, 0.05) * s, c + Vector2(0.0, -0.35) * s, c + Vector2(-0.6, 0.05) * s])
			_poly(ci, pts, Color(0.62, 0.36, 0.13))
			for i in 3:
				ci.draw_arc(c + Vector2(0, 0.35) * s, s * (0.3 + i * 0.15), 0.3, 2.8, 12, Color(1, 1, 1, 0.7), 3)
		"cloud":
			for p in [Vector2(-0.4, 0.1), Vector2(0.0, -0.2), Vector2(0.4, 0.1), Vector2(0, 0.3)]:
				_dot(ci, c + p * s, s * 0.38, Color(0.6, 0.85, 0.35))
			for p in [Vector2(-0.3, 0.0), Vector2(0.3, 0.0)]:
				ci.draw_line(c + p * s + Vector2(-6, -4), c + p * s + Vector2(6, 4), INK, 4)
				ci.draw_line(c + p * s + Vector2(-6, 4), c + p * s + Vector2(6, -4), INK, 4)
		"lightning":
			_poly(ci, PackedVector2Array([c + Vector2(0.1, -0.95) * s, c + Vector2(-0.45, 0.1) * s, c + Vector2(0.0, 0.1) * s,
				c + Vector2(-0.2, 0.95) * s, c + Vector2(0.5, -0.2) * s, c + Vector2(0.05, -0.2) * s]), Color(1, 0.9, 0.2))
		"thorns":
			_poly(ci, PackedVector2Array([c + Vector2(-0.6, -0.65) * s, c + Vector2(0.6, -0.65) * s, c + Vector2(0.55, 0.2) * s, c + Vector2(0, 0.8) * s, c + Vector2(-0.55, 0.2) * s]), Color(0.6, 0.62, 0.72))
			for k in 8:
				var d := Vector2.from_angle(k * TAU / 8)
				_poly(ci, PackedVector2Array([c + d * s * 0.55 + d.orthogonal() * 7, c + d * s * 0.55 - d.orthogonal() * 7, c + d * s * 0.95]), Color(0.85, 0.85, 0.95))
		"puddle":
			ci.draw_set_transform(c + Vector2(0, 0.2) * s, 0, Vector2(1, 0.5))
			ci.draw_circle(Vector2.ZERO, s * 0.9 + 4, INK)
			ci.draw_circle(Vector2.ZERO, s * 0.9, Color(0.45, 0.5, 0.15))
			ci.draw_circle(Vector2(-0.2, -0.1) * s, s * 0.3, Color(0.6, 0.65, 0.25))
			ci.draw_set_transform(Vector2.ZERO)
			_dot(ci, c + Vector2(0.4, -0.35) * s, 6, Color(0.45, 0.5, 0.15))
		"ice":
			for k in 6:
				var d := Vector2.from_angle(k * TAU / 6 + 0.3)
				_line(ci, c, c + d * s * 0.85, Color(0.7, 0.95, 1), 8)
				_line(ci, c + d * s * 0.5, c + d * s * 0.5 + d.rotated(0.8) * s * 0.25, Color(0.7, 0.95, 1), 5)
		"power":
			_dot(ci, c + Vector2(0.15, -0.1) * s, s * 0.5, Color(0.62, 0.38, 0.18))
			_line(ci, c + Vector2(-0.75, 0.6) * s, c + Vector2(-0.1, 0.15) * s, Color(0.62, 0.38, 0.18), 22)
			ci.draw_arc(c + Vector2(0.15, -0.1) * s, s * 0.3, 3.6, 5.6, 10, INK, 4)
		"swift":
			for i in 3:
				_line(ci, c + Vector2(-0.9, -0.4 + i * 0.4) * s, c + Vector2(-0.2 + i * 0.15, -0.4 + i * 0.4) * s, Color(0.6, 0.85, 1), 6)
			_poly(ci, PackedVector2Array([c + Vector2(0.0, -0.6) * s, c + Vector2(0.9, 0.0) * s, c + Vector2(0.0, 0.6) * s, c + Vector2(0.2, 0) * s]), Color(1, 0.8, 0.2))
		"heart":
			ci.draw_circle(c + Vector2(-0.33, -0.2) * s, s * 0.42 + 3, INK)
			ci.draw_circle(c + Vector2(0.33, -0.2) * s, s * 0.42 + 3, INK)
			_poly(ci, PackedVector2Array([c + Vector2(-0.75, 0.0) * s, c + Vector2(0.75, 0.0) * s, c + Vector2(0, 0.85) * s]), Color(0.95, 0.25, 0.3))
			ci.draw_circle(c + Vector2(-0.33, -0.2) * s, s * 0.42, Color(0.95, 0.25, 0.3))
			ci.draw_circle(c + Vector2(0.33, -0.2) * s, s * 0.42, Color(0.95, 0.25, 0.3))
			ci.draw_circle(c + Vector2(-0.4, -0.3) * s, s * 0.12, Color(1, 1, 1, 0.7))
		"magnet":
			ci.draw_arc(c + Vector2(0, -0.05) * s, s * 0.55, PI, TAU, 16, INK, 30)
			ci.draw_arc(c + Vector2(0, -0.05) * s, s * 0.55, PI, TAU, 16, Color(0.9, 0.2, 0.2), 22)
			_line(ci, c + Vector2(-0.55, 0.0) * s, c + Vector2(-0.55, 0.7) * s, Color(0.85, 0.85, 0.9), 22)
			_line(ci, c + Vector2(0.55, 0.0) * s, c + Vector2(0.55, 0.7) * s, Color(0.85, 0.85, 0.9), 22)
		"dumbbell":
			_line(ci, c + Vector2(-0.6, 0) * s, c + Vector2(0.6, 0) * s, Color(0.7, 0.7, 0.75), 10)
			for sx in [-1.0, 1.0]:
				_poly(ci, PackedVector2Array([c + Vector2(sx * 0.55, -0.55) * s, c + Vector2(sx * 0.9, -0.55) * s, c + Vector2(sx * 0.9, 0.55) * s, c + Vector2(sx * 0.55, 0.55) * s]), Color(0.3, 0.3, 0.35))
		"cape":
			_poly(ci, PackedVector2Array([c + Vector2(-0.35, -0.75) * s, c + Vector2(0.35, -0.75) * s, c + Vector2(0.85, 0.8) * s, c + Vector2(0, 0.6) * s, c + Vector2(-0.85, 0.8) * s]), Color(0.45, 0.15, 0.65))
			_dot(ci, c + Vector2(0, -0.72) * s, 8, Color(1, 0.8, 0.2))
		"crown":
			_poly(ci, PackedVector2Array([c + Vector2(-0.8, 0.5) * s, c + Vector2(-0.8, -0.4) * s, c + Vector2(-0.4, 0.0) * s, c + Vector2(0, -0.7) * s,
				c + Vector2(0.4, 0.0) * s, c + Vector2(0.8, -0.4) * s, c + Vector2(0.8, 0.5) * s]), Color(1, 0.8, 0.15))
			_dot(ci, c + Vector2(0, 0.2) * s, 7, Color(0.9, 0.15, 0.2))
		"armor":
			_poly(ci, PackedVector2Array([c + Vector2(-0.7, -0.7) * s, c + Vector2(0.7, -0.7) * s, c + Vector2(0.6, 0.25) * s, c + Vector2(0, 0.85) * s, c + Vector2(-0.6, 0.25) * s]), Color(0.65, 0.7, 0.8))
			_line(ci, c + Vector2(0, -0.6) * s, c + Vector2(0, 0.6) * s, Color(1, 0.8, 0.2), 6)
		"luck":
			for k in 4:
				var d := Vector2.from_angle(k * TAU / 4 + PI / 4)
				_dot(ci, c + d * s * 0.36, s * 0.34, Color(0.3, 0.75, 0.3))
			_line(ci, c, c + Vector2(0.3, 0.9) * s, Color(0.3, 0.6, 0.25), 6)
		"milk":
			_poly(ci, PackedVector2Array([c + Vector2(-0.45, -0.4) * s, c + Vector2(0.45, -0.4) * s, c + Vector2(0.45, 0.85) * s, c + Vector2(-0.45, 0.85) * s]), Color(1, 1, 0.97))
			_poly(ci, PackedVector2Array([c + Vector2(-0.45, -0.4) * s, c + Vector2(0, -0.85) * s, c + Vector2(0.45, -0.4) * s]), Color(0.56, 0.33, 0.15))
			_dot(ci, c + Vector2(0, 0.25) * s, 10, Color(0.56, 0.33, 0.15))
		"book":
			_poly(ci, PackedVector2Array([c + Vector2(-0.85, -0.55) * s, c + Vector2(0, -0.4) * s, c + Vector2(0, 0.75) * s, c + Vector2(-0.85, 0.6) * s]), Color(0.95, 0.9, 0.75))
			_poly(ci, PackedVector2Array([c + Vector2(0.85, -0.55) * s, c + Vector2(0, -0.4) * s, c + Vector2(0, 0.75) * s, c + Vector2(0.85, 0.6) * s]), Color(0.95, 0.9, 0.75))
			Cute_spark(ci, c + Vector2(0, -0.75) * s, s * 0.22, t)
		_:
			_poop(ci, c + Vector2(0, 0.3) * s, s * 0.7, Color(0.75, 0.5, 0.25))


static func Cute_spark(ci: CanvasItem, c: Vector2, r: float, t: float) -> void:
	var k := 1.0 + 0.2 * sin(t * 8.0)
	for i in 4:
		var d := Vector2.from_angle(i * PI / 2) * r * k
		ci.draw_line(c - d, c + d, Color(1, 0.85, 0.2), 5, true)
	ci.draw_circle(c, r * 0.35, Color(1, 1, 0.8))
