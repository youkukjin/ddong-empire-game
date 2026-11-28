extends Button
## 레벨업 카드: 진짜 입체 스킬북 (2026-11-28 사용자: "스킬북은 3D 디자인으로").
## 카드마다 작은 3D 무대에 펼친 책 한 권을 놓아요: 가죽 표지, 두툼한 종이 묶음, 금속 모서리, 책갈피 끈.
## 왼쪽 쪽에는 스킬 그림, 오른쪽 쪽에는 이름, 레벨, 설명. 책이 살짝 숨 쉬듯 흔들리고, 누르면 들려요.
## 그림은 그림 파일 없이 도형으로 그려요 (아래 draw_icon).

const FONT := preload("res://assets/fonts/Jua-Regular.ttf")
const Kit := preload("res://scripts/view3d/kit3d.gd")
const INK := Color(0.16, 0.08, 0.06)
const PAGE_INK := Color(0.24, 0.14, 0.1)

var card: Dictionary = {}       # {kind, id, title, desc}
var level := 0                  # 고르면 몇 레벨이 되는지
var max_level := 5
var _t := 0.0
var _book: Node3D
var _icon: IconCanvas
var _glow: MeshInstance3D


## 스킬 그림을 그리는 2D 캔버스 (책 왼쪽 쪽에 붙는 그림)
class IconCanvas extends Node2D:
	var id := ""
	var t := 0.0
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		var script: GDScript = load("res://scenes/survivor/skill_card.gd")
		script.set("mute", 0.2)
		script.call("draw_icon", self, id, Vector2(128, 136), 92.0, t)
		script.set("mute", 0.0)


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
	var box := SubViewportContainer.new()
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	_build_scene(vp)


func _kind_color() -> Color:
	match card.kind:
		"evolve":
			return Color(0.78, 0.56, 0.16)    # 겨자 금
		"weapon":
			return Color(0.55, 0.2, 0.15)     # 벽돌 가죽
		"passive":
			return Color(0.2, 0.4, 0.43)      # 탁한 청록 가죽
		"trait":
			return Color(0.42, 0.26, 0.5)     # 자주 가죽
	return Color(0.4, 0.46, 0.24)             # 올리브


func _build_scene(vp: SubViewport) -> void:
	var root := Node3D.new()
	vp.add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.7, 0.65)
	env.environment.ambient_light_energy = 0.4
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	root.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 26.0
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.position = Vector3(0, 5.5, 4.0)
	root.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0, 0.12), Vector3.UP)

	var kc := _kind_color()
	_book = Node3D.new()
	root.add_child(_book)
	# 진화 카드는 책 밑에서 금빛이 새어 나와요
	if card.kind == "evolve":
		_glow = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(2.95, 1.2)
		_glow.mesh = pm
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		g.gradient = Gradient.new()
		g.gradient.set_color(0, Color(1, 0.8, 0.3, 0.7))
		g.gradient.set_color(1, Color(1, 0.8, 0.3, 0.0))
		gm.albedo_texture = g
		_glow.material_override = gm
		_glow.position.y = -0.1
		_book.add_child(_glow)
	for side in [-1.0, 1.0]:
		var half := Node3D.new()
		half.rotation.z = side * -0.07          # 책이 가운데로 살짝 접혀 V자
		_book.add_child(half)
		var x: float = side * 0.68
		# 가죽 표지 (종이보다 조금 커요)
		Kit.box(half, Vector3(1.38, 0.05, 1.1), kc, Vector3(x, -0.03, 0))
		# 금속 모서리
		for cz in [-1.0, 1.0]:
			Kit.box(half, Vector3(0.14, 0.06, 0.14), Color(0.72, 0.6, 0.35), Vector3(x + side * 0.63, -0.02, cz * 0.49), 0.2)
		# 종이 묶음 (두툼하게, 옆면에 종이 결)
		Kit.box(half, Vector3(1.28, 0.1, 1.0), Color(0.86, 0.78, 0.62), Vector3(x, 0.05, 0))
		for k in 3:
			Kit.box(half, Vector3(1.29, 0.006, 1.01), Color(0.8, 0.73, 0.6), Vector3(x, 0.02 + k * 0.025, 0), 0.0, false)
		# 위쪽 쪽 (바로 이 면에 그림과 글자를 올려요)
		var page := Node3D.new()
		page.position = Vector3(x, 0.102, 0)
		half.add_child(page)
		if side < 0.0:
			_left_page(page, kc)
		else:
			_right_page(page, kc)
	# 가운데 책등 홈
	Kit.box(_book, Vector3(0.05, 0.06, 1.0), Color(0.7, 0.62, 0.5), Vector3(0, 0.08, 0), 0.0, false)
	# 책갈피 끈
	Kit.box(_book, Vector3(0.07, 0.015, 0.45), kc.lightened(0.15), Vector3(0.12, 0.11, 0.6), 0.0, false)
	Kit.box(_book, Vector3(0.07, 0.015, 0.06), kc.lightened(0.15), Vector3(0.12, 0.1, 0.84), 0.0, false).rotation.z = 0.3


func _flat_label(parent: Node3D, txt: String, pos: Vector3, fs: int, col: Color, width_px := 0.0, outline := 0) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.font = FONT
	l.font_size = fs
	l.pixel_size = 0.0032
	l.modulate = col
	l.outline_size = outline
	l.outline_modulate = Color(0.98, 0.94, 0.84)
	l.shaded = false
	l.double_sided = false
	l.position = pos
	l.rotation.x = -PI / 2
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if width_px > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = width_px
	parent.add_child(l)
	return l


func _left_page(page: Node3D, kc: Color) -> void:
	# 둥근 그림 칸 (가죽색 테 + 안쪽 바탕) 위에 스킬 그림
	var frame := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.37
	cm.bottom_radius = 0.37
	cm.height = 0.03
	frame.mesh = cm
	frame.material_override = Kit.mat(kc.darkened(0.1), 0.0, 0.6, false, false)
	frame.position = Vector3(0.02, 0.012, -0.08)
	page.add_child(frame)
	var inner := MeshInstance3D.new()
	var cm2 := CylinderMesh.new()
	cm2.top_radius = 0.32
	cm2.bottom_radius = 0.32
	cm2.height = 0.032
	inner.mesh = cm2
	inner.material_override = Kit.mat(Color(0.9, 0.84, 0.7), 0.0, 0.9, false, false)
	inner.position = Vector3(0.02, 0.014, -0.08)
	page.add_child(inner)
	var ivp := SubViewport.new()
	ivp.size = Vector2i(256, 256)
	ivp.transparent_bg = true
	ivp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(ivp)
	_icon = IconCanvas.new()
	_icon.id = String(card.id)
	ivp.add_child(_icon)
	var q := MeshInstance3D.new()
	var qm := PlaneMesh.new()
	qm.size = Vector2(0.68, 0.68)
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = ivp.get_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material_override = m
	q.position = Vector3(0.02, 0.035, -0.08)
	page.add_child(q)
	# 종류 글씨 (그림 아래 가운데)
	var tag: String = {"evolve": "진화", "weapon": "새 무기" if level <= 1 else "무기 강화", "passive": "능력치", "trait": "똥 특성", "coins": "보너스"}.get(card.kind, "")
	var tl := _flat_label(page, tag, Vector3(0.02, 0.04, 0.33), 40, kc.darkened(0.2))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _right_page(page: Node3D, kc: Color) -> void:
	var left := -0.56
	var title_text := String(card.get("name", card.title))
	_flat_label(page, title_text, Vector3(left, 0.01, -0.44), 76 if title_text.length() <= 6 else 62, PAGE_INK, 0.0, 6)
	# 레벨 보석 (가진 칸은 색 보석, 빈 칸은 움푹)
	if card.kind == "weapon" or card.kind == "passive":
		for i in max_level:
			var gem := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.055
			sm.height = 0.06 if i < level else 0.02
			gem.mesh = sm
			var col := kc.lightened(0.1) if i < level else Color(0.7, 0.62, 0.5)
			gem.material_override = Kit.mat(col, 0.6 if i == level - 1 else 0.0, 0.3, false, false)
			gem.position = Vector3(left + 0.07 + i * 0.15, 0.02, -0.08)
			gem.scale = Vector3(1, 1, 1)
			page.add_child(gem)
			if i == level - 1:
				gem.set_meta("pulse", true)
	elif card.kind == "evolve" or card.kind == "trait":
		_flat_label(page, "★ ★ ★", Vector3(left, 0.01, -0.15), 44, kc.darkened(0.1))
	# 줄
	Kit.box(page, Vector3(1.1, 0.002, 0.008), Color(0.75, 0.66, 0.52), Vector3(0.0, 0.003, 0.03), 0.0, false)
	_flat_label(page, String(card.desc), Vector3(left, 0.01, 0.08), 38, PAGE_INK.lightened(0.15), 1.12 / 0.0032)


func _process(delta: float) -> void:
	_t += delta
	if _book == null:
		return
	var lift := 0.0
	if button_pressed:
		lift = 1.0
	elif is_hovered():
		lift = 0.5
	_book.position.y = lerpf(_book.position.y, lift * 0.18, minf(delta * 12.0, 1.0))
	_book.rotation.x = sin(_t * 1.3 + float(get_index())) * 0.03 - lift * 0.06
	_book.rotation.y = sin(_t * 0.9 + float(get_index()) * 2.0) * 0.025
	if _glow:
		(_glow.mesh as PlaneMesh).size = Vector2(3.0, 1.45) * (1.0 + sin(_t * 4.0) * 0.04)


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
