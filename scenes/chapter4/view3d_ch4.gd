extends "res://scripts/view3d/side_view.gd"
## 4장 '성벽 돌파'의 3D 화면이에요 (제안: 3D 화면).
## 붉은 달이 뜬 밤, 드래곤 본거지 아래 단단한 벽돌 성벽(원작 그림)을 3D로 쌓아요.
## 벽돌은 맞을수록 금이 가고, 부서지면 와르르 파편이 튀어요. 성벽 위 대포와 대포알도 3D예요.
## 빨간 그림자 경고와 초록 소용돌이는 stage4.gd가 2D로 위에 그려요.

const Rules := preload("res://scenes/chapter4/stage4_rules.gd")
const WALL_Z := -0.7
const BRICK_LOW := Color(0.62, 0.2, 0.12)
const BRICK_HIGH := Color(0.5, 0.15, 0.12)

var _bricks := {}        # Vector2i -> MeshInstance3D
var _shown_hp := {}
var _cannons := {}       # 열 -> Node3D
var _cannon_alive := {}
var _balls := {}
var _kw := 0.012


func _build_extra() -> void:
	_kw = px_on_wall(WALL_Z)
	# 성벽 뒤 어둠과 위쪽 성
	var tl := at(Vector2(Rules.WALL_LEFT, Rules.WALL_TOP), WALL_Z - 0.6)
	var br := at(Vector2(Rules.WALL_LEFT + Rules.COLS * Rules.BRICK_W, GROUND_Y), WALL_Z - 0.6)
	Kit.box(self, Vector3(br.x - tl.x, tl.y - br.y, 0.3), Color(0.05, 0.0, 0.05), Vector3((tl.x + br.x) * 0.5, (tl.y + br.y) * 0.5, WALL_Z - 0.6), 0.0, false)
	Kit.box(self, Vector3(br.x - tl.x + 1.0, 0.35, 1.2), Color(0.3, 0.24, 0.28), Vector3((tl.x + br.x) * 0.5, tl.y + 0.15, WALL_Z - 0.2))
	# 성벽 양옆 탑 (제안)
	for x in [tl.x - 0.7, br.x + 0.7]:
		Kit.cylinder(self, 0.9, 1.0, tl.y + 2.0, Color(0.38, 0.14, 0.12), Vector3(x, (tl.y + 2.0) * 0.5, WALL_Z - 0.4))
		Kit.spike(self, 1.15, 1.6, Color(0.2, 0.05, 0.15), Vector3(x, tl.y + 2.0, WALL_Z - 0.4), Vector3.UP)
		Kit.box(self, Vector3(0.35, 0.6, 0.1), Color(1, 0.6, 0.2), Vector3(x, tl.y, WALL_Z + 0.55), 2.5, false)
	for c in Rules.COLS:
		for r in Rules.ROWS:
			var rect := Rules.brick_rect(c, r).grow(-3)
			var col := BRICK_LOW if r >= Rules.ROWS - Rules.SWORD_ROWS else BRICK_HIGH
			col = col.lerp(Color(0.4, 0.1, 0.1), ((c * 7 + r * 3) % 5) * 0.06)
			var b := Kit.box(self, Vector3(rect.size.x * _kw, rect.size.y * _kw, 0.7), col, at(rect.get_center(), WALL_Z))
			_bricks[Vector2i(c, r)] = b
			_shown_hp[Vector2i(c, r)] = Rules.BRICK_HP
	for c in Rules.CANNON_COLS:
		var cn := Node3D.new()
		cn.position = at(Vector2(Rules.col_center_x(c), Rules.WALL_TOP - 4), WALL_Z)
		cn.scale = Vector3.ONE * (60.0 * _kw)
		add_child(cn)
		Kit.box(cn, Vector3(1.4, 0.5, 1.0), Color(0.35, 0.22, 0.14), Vector3(0, 0.25, 0))
		for sx in [-0.55, 0.55]:
			var wheel := Kit.cylinder(cn, 0.32, 0.32, 0.12, Color(0.25, 0.15, 0.1), Vector3(sx, 0.3, 0.55))
			wheel.rotation.x = PI / 2
		var barrel := Kit.cylinder(cn, 0.28, 0.38, 1.4, Color(0.18, 0.18, 0.24), Vector3(0.15, 0.95, 0.2))
		barrel.rotation.z = -0.35
		barrel.rotation.x = 0.5
		Kit.torus(cn, 0.22, 0.34, Color(0.1, 0.1, 0.14), Vector3(0.38, 1.6, 0.55))
		# 심술 난 눈 (제안)
		for sx in [-0.2, 0.2]:
			Kit.sphere(cn, 0.09, Color(1, 0.85, 0.2), Vector3(sx, 0.8, 0.55), Vector3.ONE, 2.0, false)
		_cannons[c] = cn
		_cannon_alive[c] = true


func _make_ball() -> Node3D:
	var b := Node3D.new()
	add_child(b)
	Kit.sphere(b, 0.5, Color(0.15, 0.15, 0.2))
	Kit.sphere(b, 0.12, Color(1, 0.6, 0.1), Vector3(0.2, 0.45, 0.15), Vector3.ONE, 3.0, false)
	b.scale = Vector3.ONE * (22.0 * k / 0.5) * 1.5
	return b


func _sync(_delta: float) -> void:
	var rules = stage.rules
	for key in _bricks:
		var hp: int = rules.bricks[key.x][key.y]
		if hp == _shown_hp[key]:
			continue
		_shown_hp[key] = hp
		var b: MeshInstance3D = _bricks[key]
		if hp <= 0:
			if b.visible:
				burst(b.position + Vector3(0, 0, 0.5), Color(0.7, 0.25, 0.15), 12, 1.0)
			b.visible = false
		else:
			# 금이 가요: 어두워지고 살짝 비뚤어져요
			var crack := float(Rules.BRICK_HP - hp) / Rules.BRICK_HP
			b.material_override = Kit.mat(BRICK_LOW.darkened(0.15 + crack * 0.45))
			b.rotation.z = (0.04 if (key.x + key.y) % 2 else -0.04) * crack * 2.0
			b.position.z = at(Rules.brick_rect(key.x, key.y).get_center(), WALL_Z).z + crack * 0.12
	for c in _cannons:
		var alive: bool = rules.cannons[c]
		if alive != _cannon_alive[c]:
			_cannon_alive[c] = alive
			if not alive:
				burst(_cannons[c].position + Vector3(0, 0.5, 0.5), Color(0.3, 0.3, 0.35), 16, 1.2)
				_cannons[c].rotation.z = 0.9
				_cannons[c].position.y -= 0.25
	var seen := {}
	for b in rules.balls:
		if not b.has("_vid"):
			b["_vid"] = randi()
		var id: int = b["_vid"]
		seen[id] = true
		if not _balls.has(id):
			_balls[id] = _make_ball()
		var kk: float = 1.0 - b.left / Rules.CANNON_WARN
		var from_x: float = Rules.col_center_x(b.from)
		var bp := Vector2(lerpf(from_x, b.x, kk), lerpf(Rules.WALL_TOP - 90, GROUND_Y - 20, kk * kk))
		_balls[id].position = at(bp, 0.3)
		_balls[id].rotation.z += 0.2
	for id in _balls.keys():
		if not seen.has(id):
			burst(_balls[id].position, Color(1, 0.55, 0.15), 14, 1.2)
			_balls[id].queue_free()
			_balls.erase(id)
