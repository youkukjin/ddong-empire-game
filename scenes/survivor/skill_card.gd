extends Button
## 레벨업 카드: 스킬북 한 쪽 (2026-11-28 사용자: "둔탁한 색감과 세련되게", "그림체를 3D로").
## 스킬 그림은 게임 속 인물처럼 3D 모형(icon3d.gd)이 메달 안에서 살짝 돌아요.
## 먹빛 바탕 + 크레용 빗금 + 삐뚤빼뚤 크레용 테두리, 탁한 색 메달 안에 스킬 그림, 크림색 글자.
## 그림은 그림 파일 없이 도형으로 그려요.

const FONT := preload("res://assets/fonts/Jua-Regular.ttf")
const INK := Color(0.16, 0.08, 0.06)
const Icon3D := preload("res://scenes/survivor/icon3d.gd")

var card: Dictionary = {}       # {kind, id, title, desc}
var level := 0                  # 고르면 몇 레벨이 되는지
var max_level := 5
var _t := 0.0
var _icon_view: SubViewportContainer
var _medal_c := Vector2(150, 125)
var _medal_r := 76.0


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


func _ready() -> void:
	_icon_view = Icon3D.make_view(String(card.id), Vector2(180, 180))
	add_child(_icon_view)


func _process(delta: float) -> void:
	_t += delta
	if _icon_view:
		var side := _medal_r * 2.3
		_icon_view.size = Vector2(side, side)
		_icon_view.position = _medal_c - _icon_view.size / 2.0
	if card.kind == "evolve" or button_pressed or is_hovered():
		queue_redraw()


func _kind_color() -> Color:
	match card.kind:
		"evolve":
			return Color(0.85, 0.62, 0.18)    # 겨자
		"weapon":
			return Color(0.72, 0.27, 0.2)     # 벽돌 빨강
		"passive":
			return Color(0.27, 0.5, 0.52)     # 탁한 청록
		"trait":
			return Color(0.5, 0.32, 0.58)     # 탁한 자주
	return Color(0.5, 0.58, 0.3)              # 올리브


const CARD_BG := Color(0.17, 0.13, 0.17)       # 먹빛 자주
const CREAM := Color(0.95, 0.89, 0.76)


## 크레용으로 그은 듯 살짝 삐뚤빼뚤한 네모 (같은 카드는 늘 같은 모양)
func _rough_rect(r: Rect2, wob: float, seed_i: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var steps := 10
		for i in steps:
			var p := a.lerp(b, float(i) / steps)
			var h := sin((i + k * 13 + seed_i) * 12.9898) * 43758.5453
			p += (b - a).orthogonal().normalized() * (h - floor(h) - 0.5) * wob
			pts.append(p)
	return pts


func _stroke(pts: PackedVector2Array, col: Color, w: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, col, w, true)


func _draw() -> void:
	var sz := size
	var press := 4.0 if button_pressed else 0.0
	var r := Rect2(Vector2(6, press + 2), sz - Vector2(12, 12))
	var kc := _kind_color()
	var seed_i := String(card.id).hash() % 97
	# 그림자
	draw_colored_polygon(_rough_rect(Rect2(r.position + Vector2(5, 9), r.size), 3.0, seed_i), Color(0, 0, 0, 0.45))
	# 진화 카드는 겨자빛이 은은하게 숨 쉬어요
	if card.kind == "evolve":
		var glow := 0.5 + 0.5 * sin(_t * 4.0)
		_round(r.grow(5 + glow * 5), 18, Color(kc.r, kc.g, kc.b, 0.18 + glow * 0.2))
	# 바탕: 먹빛 종이 + 크레용 빗금
	var body := _rough_rect(r, 3.0, seed_i)
	draw_colored_polygon(body, CARD_BG)
	var hatch := Color(kc.r, kc.g, kc.b, 0.1)
	var x := -r.size.y
	while x < r.size.x:
		var a := r.position + Vector2(x, r.size.y)
		var b := r.position + Vector2(x + r.size.y, 0)
		draw_line(a.clamp(r.position, r.end), b.clamp(r.position, r.end), hatch, 2.0)
		x += 9.0
	# 왼쪽 색 띠 (크레용 굵게 한 번 문지른 느낌)
	var band := Rect2(r.position + Vector2(10, 12), Vector2(10, r.size.y - 24))
	draw_colored_polygon(_rough_rect(band, 2.0, seed_i + 3), kc.darkened(0.1))
	# 그림 메달
	var mc := r.position + Vector2(40 + r.size.y * 0.32, r.size.y * 0.5)
	var mr := r.size.y * 0.32
	draw_circle(mc + Vector2(3, 5), mr + 4, Color(0, 0, 0, 0.4))
	draw_circle(mc, mr + 4, kc.darkened(0.2))
	draw_circle(mc, mr, kc.darkened(0.55))
	draw_circle(mc + Vector2(-mr * 0.25, -mr * 0.3), mr * 0.55, Color(1, 1, 1, 0.07))
	draw_arc(mc, mr + 4, 0, TAU, 48, CREAM.darkened(0.15), 2.5, true)
	draw_arc(mc, mr - 6, 0.3, TAU - 0.3, 40, Color(CREAM.r, CREAM.g, CREAM.b, 0.25), 1.5, true)
	_medal_c = mc
	_medal_r = mr
	# 글자
	var tx := mc.x + mr + 26
	var right := r.end.x - 20
	var tag: String = {"evolve": "진화", "weapon": "새 무기" if level <= 1 else "무기 강화", "passive": "능력치", "trait": "똥 특성", "coins": "보너스"}.get(card.kind, "")
	draw_string(FONT, Vector2(tx, r.position.y + 46), "◆ " + tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, kc.lightened(0.25))
	var title_text := String(card.get("name", card.title))
	draw_string_outline(FONT, Vector2(tx, r.position.y + 94), title_text, HORIZONTAL_ALIGNMENT_LEFT, right - tx, 40, 8, Color(0.08, 0.05, 0.07))
	draw_string(FONT, Vector2(tx, r.position.y + 94), title_text, HORIZONTAL_ALIGNMENT_LEFT, right - tx, 40, CREAM)
	# 레벨 칸: 마름모
	if card.kind == "weapon" or card.kind == "passive":
		for i in max_level:
			var c := Vector2(tx + 10 + i * 30, r.position.y + 122)
			var dia := PackedVector2Array([c + Vector2(0, -10), c + Vector2(10, 0), c + Vector2(0, 10), c + Vector2(-10, 0)])
			if i < level:
				draw_colored_polygon(dia, kc.lightened(0.1) if i == level - 1 else kc.darkened(0.15))
				if i == level - 1:
					draw_circle(c, 3, Color(1, 1, 1, 0.5 + 0.4 * sin(_t * 6.0)))
			_stroke(dia, CREAM.darkened(0.25), 2.0)
	elif card.kind == "evolve" or card.kind == "trait":
		draw_string(FONT, Vector2(tx, r.position.y + 132), "★ ★ ★", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, kc)
	# 가는 구분선
	draw_line(Vector2(tx, r.position.y + 146), Vector2(right, r.position.y + 147), Color(CREAM.r, CREAM.g, CREAM.b, 0.18), 2.0)
	# 설명 (두 줄까지)
	var lines := _wrap(String(card.desc), right - tx, 24)
	for i in mini(lines.size(), 2):
		draw_string(FONT, Vector2(tx, r.position.y + 180 + i * 30), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(CREAM.r, CREAM.g, CREAM.b, 0.78))
	# 테두리: 크림색 크레용 두 번 그은 선
	_stroke(body, CREAM.darkened(0.3), 3.0)
	_stroke(_rough_rect(r.grow(-6), 2.5, seed_i + 7), Color(kc.r, kc.g, kc.b, 0.55), 2.0)
	if button_pressed or is_hovered():
		_stroke(body, Color(CREAM.r, CREAM.g, CREAM.b, 0.9), 5.0)


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

## 0이면 원래 색, 1에 가까울수록 회색빛으로 탁해져요 (카드 위 그림은 0.35)
static var mute := 0.0


static func _m(col: Color) -> Color:
	if mute <= 0.0:
		return col
	var g := col.get_luminance()
	return col.lerp(Color(g, g * 0.95, g * 0.9, col.a), mute).darkened(mute * 0.25)

static func _poop(ci: CanvasItem, c: Vector2, s: float, col := Color(0.56, 0.33, 0.15)) -> void:
	for t in [[0.0, 0.62, 1.0], [-0.55, 0.48, 0.8], [-0.95, 0.32, 0.62]]:
		ci.draw_circle(c + Vector2(0, t[0] * s), t[1] * s + 3, INK)
	for t in [[0.0, 0.62, 1.0], [-0.55, 0.48, 0.8], [-0.95, 0.32, 0.62]]:
		ci.draw_circle(c + Vector2(0, t[0] * s), t[1] * s, _m(col))


static func _line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(a, b, INK, w + 6, true)
	ci.draw_line(a, b, _m(col), w, true)
	ci.draw_circle(a, w * 0.5 + 3, INK)
	ci.draw_circle(b, w * 0.5 + 3, INK)
	ci.draw_circle(a, w * 0.5, _m(col))
	ci.draw_circle(b, w * 0.5, _m(col))


static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_colored_polygon(pts, _m(col))
	ci.draw_polyline(closed, INK, 4.0, true)


static func _dot(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r + 3, INK)
	ci.draw_circle(c, r, _m(col))


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
		"trait_hp":
			# 튼튼한 똥: 갑옷 두른 똥 + 하트
			_poop(ci, c + Vector2(0, 0.35) * s, s * 0.62, Color(0.56, 0.33, 0.15))
			_poly(ci, PackedVector2Array([c + Vector2(-0.55, 0.15) * s, c + Vector2(0.55, 0.15) * s, c + Vector2(0.45, 0.7) * s, c + Vector2(-0.45, 0.7) * s]), Color(0.7, 0.72, 0.78))
			var hc := c + Vector2(0.5, -0.55) * s
			_dot(ci, hc + Vector2(-0.12, 0) * s, s * 0.16, Color(0.9, 0.25, 0.3))
			_dot(ci, hc + Vector2(0.12, 0) * s, s * 0.16, Color(0.9, 0.25, 0.3))
			_poly(ci, PackedVector2Array([hc + Vector2(-0.27, 0.05) * s, hc + Vector2(0.27, 0.05) * s, hc + Vector2(0, 0.38) * s]), Color(0.9, 0.25, 0.3))
		"trait_atk":
			# 매운 똥: 불꽃을 뿜는 빨간 똥
			_poly(ci, PackedVector2Array([c + Vector2(-0.5, -0.1) * s, c + Vector2(-0.3, -0.95) * s, c + Vector2(0, -0.45) * s, c + Vector2(0.25, -1.0) * s, c + Vector2(0.5, -0.1) * s]), Color(1, 0.55, 0.15))
			_poop(ci, c + Vector2(0, 0.4) * s, s * 0.62, Color(0.75, 0.25, 0.15))
		"coins":
			for k in 3:
				_dot(ci, c + Vector2(-0.35 + k * 0.35, 0.3 - k * 0.25) * s, s * 0.3, Color(0.95, 0.75, 0.25))
		_:
			_poop(ci, c + Vector2(0, 0.3) * s, s * 0.7, Color(0.75, 0.5, 0.25))


static func Cute_spark(ci: CanvasItem, c: Vector2, r: float, t: float) -> void:
	var k := 1.0 + 0.2 * sin(t * 8.0)
	for i in 4:
		var d := Vector2.from_angle(i * PI / 2) * r * k
		ci.draw_line(c - d, c + d, Color(1, 0.85, 0.2), 5, true)
	ci.draw_circle(c, r * 0.35, Color(1, 1, 0.8))
