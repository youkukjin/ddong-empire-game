extends "res://scripts/view3d/side_view.gd"
## 3장 '구멍 탐험'의 3D 화면이에요 (제안: 3D 화면).
## 횃불이 흔들리는 어두운 굴을 달려요. 바위, 구덩이, 낮은 천장, 반짝이는 돌, 갈림길, 본거지 입구를 3D로 보여줘요.
## 굴 속 꾸밈(횃불, 종유석)은 제안이에요.

const Rules := preload("res://scenes/chapter3/stage3_rules.gd")
const PURPLE := Color(0.7, 0.2, 1.0)

var _items := {}          # 물건 번호 -> Node3D
var _forks := {}
var _end: Node3D
var _px := 0.0            # 굴 1픽셀 = 3D 단위


func _build_extra() -> void:
	_px = k
	_end = Node3D.new()
	add_child(_end)
	# 본거지 입구: 보라빛이 새어 나오는 큰 굴 (제안)
	var rock := Color(0.2, 0.08, 0.2)
	Kit.box(_end, Vector3(8, 7.5, 2), rock, Vector3(4, 3.5, -1.2))
	Kit.sphere(_end, 1.8, Color(0.08, 0.0, 0.1), Vector3(1.6, 1.6, -0.15), Vector3(1, 1.1, 0.2), 0.0, false)
	Kit.sphere(_end, 1.5, PURPLE, Vector3(1.6, 1.6, -0.2), Vector3(1, 1.1, 0.1), 1.6, false)
	Kit.light(_end, Vector3(1.6, 1.6, 1.0), PURPLE, 3.0, 8.0)
	for i in 5:
		var a := PI * (0.1 + i * 0.2)
		Kit.spike(_end, 0.25, 0.7, Color(0.95, 0.92, 0.85), Vector3(1.6 + cos(a) * 1.7, 1.6 + sin(a) * 1.9, 0.2), Vector3(-cos(a), -sin(a), 0))
	var l := Kit.label(_end, "본거지", Vector3(1.6, 4.2, 0.5), 90, Color(1, 0.8, 1))
	l.no_depth_test = false


func _make_item(kind: int) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	match kind:
		Rules.Kind.ROCK:
			Kit.sphere(n, 0.45, Color(0.42, 0.38, 0.4), Vector3(0, 0.38, 0), Vector3(1.1, 0.85, 1))
			Kit.sphere(n, 0.25, Color(0.5, 0.46, 0.48), Vector3(0.25, 0.65, 0.1))
			Kit.sphere(n, 0.2, Color(0.35, 0.32, 0.34), Vector3(-0.32, 0.2, 0.2))
			n.scale = Vector3.ONE * (43.0 * _px / 0.45)
		Rules.Kind.PIT:
			Kit.box(n, Vector3(110 * _px, 0.02, 6.0), Color(0.02, 0.0, 0.02), Vector3(0, 0.015, -0.5), 0.0, false)
			Kit.box(n, Vector3(110 * _px, 0.5, 6.0), Color(0.02, 0.0, 0.02), Vector3(0, -0.24, -0.5), 0.0, false)
			for sx in [-1.0, 1.0]:
				Kit.box(n, Vector3(0.12, 0.14, 6.0), Color(0.35, 0.2, 0.12), Vector3(sx * 55 * _px, 0.05, -0.5))
		Rules.Kind.LOW:
			var top := at(Vector2(0, 96)).y
			var bottom := at(Vector2(0, 480)).y
			Kit.box(n, Vector3(140 * _px, top - bottom + 1.0, 3.0), Color(0.3, 0.18, 0.12), Vector3(0, (top + bottom) * 0.5 + 0.5, -0.3))
			for i in 4:
				Kit.spike(n, 0.22, 0.45, Color(0.35, 0.22, 0.15), Vector3((-52 + i * 35) * _px, bottom, 0.6), Vector3.DOWN)
		_:
			var gem := Node3D.new()
			gem.name = "Gem"
			n.add_child(gem)
			for d in [1.0, -1.0]:
				var m := CylinderMesh.new()
				m.top_radius = 0.0
				m.bottom_radius = 0.25
				m.height = 0.35
				m.radial_segments = 4
				var mi := MeshInstance3D.new()
				mi.mesh = m
				mi.material_override = Kit.mat(Color(0.35, 0.95, 1.0), 1.8)
				mi.position = Vector3(0, d * 0.175, 0)
				mi.rotation.z = 0.0 if d > 0 else PI
				gem.add_child(mi)
			Kit.light(n, Vector3(0, 0, 0.4), Color(0.4, 0.9, 1), 1.2, 2.0)
	return n


func _make_fork() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var rock := Color(0.32, 0.2, 0.13)
	var y := func(py: float) -> float: return at(Vector2(0, py)).y
	var x0 := -20.0 * _px
	var x1 := 380.0 * _px
	var w := x1 - x0
	var cx := (x0 + x1) * 0.5
	# 바위벽 (구멍 둘 자리를 비워서 쌓아요)
	var top: float = y.call(96.0)
	var up_t: float = y.call(170.0)
	var up_b: float = y.call(320.0)
	var dn_t: float = y.call(420.0)
	Kit.box(n, Vector3(w, top - up_t, 2.5), rock, Vector3(cx, (top + up_t) * 0.5, -1.0))
	Kit.box(n, Vector3(w, up_b - dn_t, 2.5), rock, Vector3(cx, (up_b + dn_t) * 0.5, -1.0))
	# 구멍 두 개 (어두운 굴)
	for key in ["Up", "Down"]:
		var t: float = up_t if key == "Up" else dn_t
		var b: float = up_b if key == "Up" else 0.0
		var hole := Node3D.new()
		hole.name = key
		n.add_child(hole)
		var hx := (-10.0 + 110.0) * _px
		Kit.box(hole, Vector3(220 * _px, t - b, 0.2), Color(0.03, 0.01, 0.03), Vector3(hx, (t + b) * 0.5, -2.1), 0.0, false)
		Kit.box(hole, Vector3(w - 220 * _px, t - b, 2.5), rock, Vector3(hx + 110 * _px + (w - 220 * _px) * 0.5 - 10 * _px, (t + b) * 0.5, -1.0))
		var marks := Node3D.new()
		marks.name = "Marks"
		hole.add_child(marks)
		for kk in 4:
			Kit.sphere(marks, 0.16, PURPLE, Vector3((30 + kk * 50) * _px - 10 * _px, b + 0.25 + (kk % 2) * 0.2, 0.3), Vector3(1, 0.6, 0.3), 2.2, false)
		Kit.light(marks, Vector3(hx, (t + b) * 0.5, 1.0), PURPLE, 2.0, 4.0)
		var pick := Kit.torus(hole, 1.0, 1.12, Color(1, 1, 0.5), Vector3(hx, (t + b) * 0.5, 0.4), 2.5, false)
		pick.name = "Pick"
		pick.rotation.x = PI / 2
		pick.scale = Vector3(120 * _px, 1, (t - b) * 0.55)
	return n


func _sync(_delta: float) -> void:
	var s: Node2D = stage
	var rules = s.rules
	scroll_to(rules.distance * _px)
	var seen := {}
	for i in rules.items.size():
		var it: Dictionary = rules.items[i]
		var x: float = s._sx(it.x)
		if x < -200 or x > 1500:
			continue
		var is_gem: bool = it.kind == Rules.Kind.GEM or it.kind == Rules.Kind.GEM_HIGH
		if is_gem and it.done:
			continue
		seen[i] = true
		if not _items.has(i):
			_items[i] = _make_item(it.kind)
		var m: Node3D = _items[i]
		var y := GROUND_Y
		if is_gem:
			y = GROUND_Y - 50.0 if it.kind == Rules.Kind.GEM else GROUND_Y - 200.0
			m.get_node("Gem").rotation.y += 0.05
			m.scale = Vector3.ONE * (60.0 * _px / 0.5)
		m.position = at(Vector2(x, y), 0.0)
		if it.kind == Rules.Kind.LOW:
			m.position.y = 0.0
	for i in _items.keys():
		if not seen.has(i):
			var it: Dictionary = rules.items[i]
			if it.kind == Rules.Kind.GEM or it.kind == Rules.Kind.GEM_HIGH:
				if it.done:
					burst(_items[i].position, Color(0.4, 0.95, 1), 10, 0.7)
			_items[i].queue_free()
			_items.erase(i)
	# 갈림길
	seen = {}
	for i in rules.forks.size():
		var f: Dictionary = rules.forks[i]
		var x: float = s._sx(f.x)
		if x < -500 or x > 1700:
			continue
		seen[i] = true
		if not _forks.has(i):
			_forks[i] = _make_fork()
		var m: Node3D = _forks[i]
		m.position = Vector3(at(Vector2(x, GROUND_Y)).x, 0, 0)
		for key in ["Up", "Down"]:
			var side: int = Rules.Side.UP if key == "Up" else Rules.Side.DOWN
			var hole: Node3D = m.get_node(key)
			hole.get_node("Marks").visible = f.correct == side
			hole.get_node("Pick").visible = f.chosen == side and not f.resolved
	for i in _forks.keys():
		if not seen.has(i):
			_forks[i].queue_free()
			_forks.erase(i)
	var end_x: float = s._sx(rules.total_length())
	_end.visible = end_x < 1600
	_end.position = Vector3(at(Vector2(end_x, GROUND_Y)).x, 0, 0)
