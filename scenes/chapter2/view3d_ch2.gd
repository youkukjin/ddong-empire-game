extends "res://scripts/view3d/side_view.gd"
## 2장 '준비'의 3D 화면이에요 (제안: 3D 화면).
## 붉은 노을 훈련장에서 아령(원작 그림), 검 표적, 사슬 표적, 굴러오는 연습 공을 3D로 보여줘요.
## 고리·줄·경고 표시는 stage2.gd가 2D로 위에 그려요.

const Rules := preload("res://scenes/chapter2/stage2_rules.gd")

var _dumbbell: Node3D
var _targets := {}        # id -> Node3D
var _chain_target: Node3D
var _balls := {}
var _next_id := 1


func _build_extra() -> void:
	_dumbbell = Node3D.new()
	add_child(_dumbbell)
	var bar := Kit.cylinder(_dumbbell, 0.06, 0.06, 2.3, Color(0.3, 0.3, 0.35))
	bar.rotation.z = PI / 2
	for sx in [-1.0, 1.0]:
		for j in 2:
			var plate := Kit.cylinder(_dumbbell, 0.42 - j * 0.08, 0.42 - j * 0.08, 0.18, Color(0.12, 0.12, 0.15), Vector3(sx * (0.95 - j * 0.2), 0, 0))
			plate.rotation.z = PI / 2
	_chain_target = Node3D.new()
	add_child(_chain_target)
	Kit.box(_chain_target, Vector3(1.0, 1.45, 0.25), Color(0.55, 0.32, 0.15))
	for i in 3:
		Kit.box(_chain_target, Vector3(1.02, 0.05, 0.27), Color(0.35, 0.18, 0.08), Vector3(0, -0.45 + i * 0.45, 0), 0.0, false)
	var bull := Kit.cylinder(_chain_target, 0.32, 0.32, 0.06, Color(0.9, 0.1, 0.1), Vector3(0, 0, 0.15))
	bull.rotation.x = PI / 2
	var dot := Kit.cylinder(_chain_target, 0.12, 0.12, 0.08, Color(1, 0.95, 0.85), Vector3(0, 0, 0.17))
	dot.rotation.x = PI / 2


func _make_target(hard: bool) -> Node3D:
	var t := Node3D.new()
	add_child(t)
	for i in 3:
		var r := 0.62 - i * 0.2
		var c := Kit.cylinder(t, r, r, 0.12 + i * 0.03, [Color(0.95, 0.92, 0.85), Color(0.85, 0.08, 0.08), Color(0.95, 0.92, 0.85)][i], Vector3(0, 0, i * 0.03))
		c.rotation.x = PI / 2
	if hard:
		var rim := Kit.torus(t, 0.6, 0.75, Color(0.35, 0.35, 0.42), Vector3(0, 0, 0.05))
		rim.rotation.x = PI / 2
		rim.name = "Rim"
	Kit.cylinder(t, 0.05, 0.05, 1.0, Color(0.4, 0.22, 0.1), Vector3(0, -0.9, -0.1))
	return t


func _make_ball() -> Node3D:
	var b := Node3D.new()
	add_child(b)
	var core := Node3D.new()
	core.name = "Core"
	b.add_child(core)
	Kit.sphere(core, 0.45, Color(0.55, 0.3, 0.12))
	for i in 10:
		var a := TAU * i / 10.0
		var dir := Vector3(cos(a), sin(a), 0.4 * (1 if i % 2 else -1)).normalized()
		Kit.spike(core, 0.1, 0.28, Color(0.35, 0.18, 0.08), dir * 0.4, dir)
	return b


func _id(d: Dictionary) -> int:
	if not d.has("_vid"):
		d["_vid"] = _next_id
		_next_id += 1
	return d["_vid"]


func _sync(_delta: float) -> void:
	var s: Node2D = stage
	var active: bool = s.drill_active
	var drill: int = s.rules.drill
	# 아령: 왕자 머리 위로 번쩍!
	_dumbbell.visible = active and drill == Rules.Drill.DUMBBELL
	if _dumbbell.visible:
		var lift: float = 30.0 if s.prince.pose == 5 else 0.0
		_dumbbell.position = at(s.PRINCE_POS + Vector2(0, -150 - lift), 0.4)
		_dumbbell.scale = Vector3.ONE * (90.0 * k / 1.0)
	# 검 표적
	var seen := {}
	if active and drill == Rules.Drill.SWORD:
		for t in s._targets:
			var id := _id(t)
			seen[id] = true
			if not _targets.has(id):
				_targets[id] = _make_target(t.hard)
			var m: Node3D = _targets[id]
			m.position = at(t.pos, 0.3)
			var a := clampf(t.life / 0.3, 0.0, 1.0)
			m.scale = Vector3.ONE * (56.0 * k / 0.62) * a
			var rim := m.get_node_or_null("Rim")
			if rim:
				rim.visible = t.hp > 1
	for id in _targets.keys():
		if not seen.has(id):
			burst(_targets[id].position, Color(1, 0.85, 0.3), 10, 1.0)
			_targets[id].queue_free()
			_targets.erase(id)
	# 사슬 표적
	_chain_target.visible = active and drill == Rules.Drill.CHAIN
	if _chain_target.visible:
		_chain_target.position = at(Vector2(s.CHAIN_TARGET_X, s._chain_target_y), 0.0)
		_chain_target.scale = Vector3.ONE * (120.0 * k / 1.45)
	# 굴러오는 연습 공
	seen = {}
	if active and drill == Rules.Drill.ROLL:
		for b in s._balls:
			if b.done:
				continue
			var left: float = b.hit_time - s._t
			var x: float = s.PRINCE_POS.x + left * b.speed
			if x > 1400:
				continue
			var id := _id(b)
			seen[id] = true
			if not _balls.has(id):
				_balls[id] = _make_ball()
			var m: Node3D = _balls[id]
			m.position = at(Vector2(x, s.PRINCE_POS.y - 36), 0.0)
			m.scale = Vector3.ONE * (36.0 * k / 0.45)
			(m.get_node("Core") as Node3D).rotation.z = x * 0.02
	for id in _balls.keys():
		if not seen.has(id):
			burst(_balls[id].position, Color(0.6, 0.35, 0.15), 8, 0.8)
			_balls[id].queue_free()
			_balls.erase(id)
