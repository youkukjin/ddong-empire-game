extends "res://scripts/view3d/stage_view.gd"
## 옆에서 보는 3D 무대예요 (제안: 3D 화면, 2~8장).
## 인물이 서는 판(z = 0)을 화면 좌표와 맞춰 두어서, 2D 규칙이 계산한 자리에 3D 인물을 그대로 놓아요.
## 화면 y = 600 (땅 줄)이 3D 높이 0이 되도록 카메라를 맞춰요.
##
## 장소 종류 (원작 그림의 장소는 따르고, 꾸밈은 제안이에요):
## yard(훈련장) · tunnel(굴) · wall(성벽 앞 밤) · arena(성벽 안) · lair(드래곤 본거지)

const Kit := preload("res://scripts/view3d/kit3d.gd")
const Prince3D := preload("res://scripts/view3d/prince_3d.gd")
const GROUND_Y := 600.0
const PRINCE_PX := 130.0       # 2D 왕자 키 (픽셀)

var stage: Node2D
var kind := "yard"
var k := 0.012                 # 판 위에서 화면 1픽셀 = 3D 몇 단위
var prince3d: Node3D
var scroll_root: Node3D        # 굴처럼 옆으로 흘러가는 배경
var scroll_span := 40.0
var _scroll_copies: Array[Node3D] = []
var _flicker: Array[OmniLight3D] = []


func _init() -> void:
	pitch_deg = 7.0
	cam_z = 12.0
	cam_height = 3.0
	fov_deg = 40.0
	# 땅 줄이 높이 0이 되게 카메라 높이를 맞춰요
	var floor_y := on_wall(Vector2(640, GROUND_Y), 0.0).y
	cam_height -= floor_y


func _ready() -> void:
	k = px_on_wall(0.0)
	match kind:
		"yard":
			setup(Color(0.45, 0.1, 0.2), Color(1.0, 0.55, 0.25), Color(0.65, 0.6, 0.7), Color(1, 0.88, 0.75), 1.0)
			sun.rotation_degrees = Vector3(-25, -60, 0)
		"tunnel":
			setup(Color(0.05, 0.03, 0.04), Color(0.12, 0.06, 0.05), Color(0.6, 0.5, 0.45), Color(1, 0.85, 0.65), 0.8)
		"wall":
			setup(Color(0.03, 0.02, 0.1), Color(0.35, 0.08, 0.15), Color(0.45, 0.35, 0.65), Color(0.75, 0.7, 1.0), 0.8)
		"arena":
			setup(Color(0.08, 0.03, 0.1), Color(0.4, 0.1, 0.12), Color(0.5, 0.45, 0.6), Color(1, 0.92, 0.85), 0.9)
		"lair":
			setup(Color(0.04, 0.01, 0.06), Color(0.45, 0.08, 0.1), Color(0.45, 0.4, 0.65), Color(0.85, 0.8, 1.0), 0.85)
		_:
			setup(Color(0.2, 0.2, 0.4), Color(0.5, 0.4, 0.6), Color(0.6, 0.6, 0.7))
	_build_place()
	prince3d = Prince3D.new()
	prince3d.turn_deg = 55.0
	prince3d.scale = Vector3.ONE * (PRINCE_PX * k / 1.75)
	add_child(prince3d)
	_build_extra()


## 화면 점 → 인물이 서는 판 위 3D 점
func at(p: Vector2, z := 0.0) -> Vector3:
	return on_wall(p, z)


func point_at(p: Vector2) -> Vector3:
	return at(p, 0.6)


## 장마다 더 만들 것 (적, 물건)
func _build_extra() -> void:
	pass


## 장마다 매 프레임 맞출 것
func _sync(_delta: float) -> void:
	pass


func _process(delta: float) -> void:
	super._process(delta)
	for l in _flicker:
		l.light_energy = 1.5 + sin(Time.get_ticks_msec() * 0.013 + l.position.x) * 0.25 + randf() * 0.2
	if stage and prince3d and stage.get("prince"):
		var p: Node2D = stage.prince
		prince3d.sync_from(p)
		prince3d.position = at(p.position)
		prince3d.scale = Vector3.ONE * (PRINCE_PX * k / 1.75) * p.scale.x
	_sync(delta)


## 굴 배경을 옆으로 흘려요 (3D 단위)
func scroll_to(x: float) -> void:
	if not scroll_root:
		return
	var off := fposmod(x, scroll_span)
	for i in _scroll_copies.size():
		_scroll_copies[i].position.x = -off + (i - 1) * scroll_span


# ------------------------------------------------------------------ 장소

func _floor(color: Color, edge: Color) -> void:
	var f := Kit.box(self, Vector3(120, 2, 60), color, Vector3(0, -1.0, -24))
	f.material_override = Kit.matte(color)
	var e := Kit.box(self, Vector3(120, 0.08, 0.25), edge, Vector3(0, 0.04, 2.6))
	e.material_override = Kit.matte(edge)


func _build_place() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	match kind:
		"yard":
			_floor(Color(0.25, 0.33, 0.14), Color(0.18, 0.24, 0.1))
			# 해 지는 하늘의 큰 해 (제안: 결전을 앞둔 붉은 노을)
			Kit.sphere(self, 3.0, Color(1, 0.55, 0.15), Vector3(9, 5.5, -40), Vector3.ONE, 2.2, false)
			# 검은 산 실루엣
			for i in 7:
				var x := -30.0 + i * 10.0 + rng.randf_range(-2, 2)
				Kit.spike(self, rng.randf_range(5, 8), rng.randf_range(7, 12), Color(0.18, 0.08, 0.14), Vector3(x, -1, -30 - rng.randf_range(0, 5)), Vector3.UP, false)
			# 나무 울타리
			var wood := Color(0.45, 0.25, 0.1)
			for i in 16:
				var x := -15.0 + i * 2.0
				Kit.box(self, Vector3(0.22, 1.3, 0.22), wood, Vector3(x, 0.65, -2.5))
			Kit.box(self, Vector3(34, 0.16, 0.12), wood, Vector3(0, 1.0, -2.4))
			Kit.box(self, Vector3(34, 0.16, 0.12), wood, Vector3(0, 0.55, -2.4))
			# 짚 허수아비 (제안: 훈련장)
			for x in [-6.0, 7.5]:
				var d := Node3D.new()
				d.position = Vector3(x, 0, -5)
				add_child(d)
				Kit.cylinder(d, 0.08, 0.1, 2.2, Color(0.4, 0.22, 0.1), Vector3(0, 1.1, 0))
				Kit.box(d, Vector3(1.6, 0.14, 0.14), Color(0.4, 0.22, 0.1), Vector3(0, 1.6, 0))
				Kit.sphere(d, 0.5, Color(0.55, 0.4, 0.18), Vector3(0, 1.4, 0), Vector3(1, 1.3, 1))
				Kit.sphere(d, 0.32, Color(0.6, 0.45, 0.2), Vector3(0, 2.3, 0))
			for x in [-11.0, 3.0, 13.0]:
				Kit.torch(self, Vector3(x, 0, -3.5), 1.1)
		"tunnel":
			_floor(Color(0.24, 0.14, 0.09), Color(0.16, 0.09, 0.06))
			scroll_root = Node3D.new()
			add_child(scroll_root)
			scroll_span = 24.0
			var ceil_y := at(Vector2(640, 96)).y
			for c in 3:
				var copy := Node3D.new()
				scroll_root.add_child(copy)
				_scroll_copies.append(copy)
				var r2 := RandomNumberGenerator.new()
				r2.seed = 5
				# 뒤 벽 바위
				for i in 12:
					var x := i * 2.0 + r2.randf_range(-0.5, 0.5)
					Kit.ground_sphere(copy, r2.randf_range(1.5, 2.6), Color(0.36, 0.24, 0.16).lerp(Color(0.24, 0.16, 0.11), r2.randf()), Vector3(x, r2.randf_range(0.5, 5.0), -4.5 - r2.randf_range(0, 1.5)))
				# 천장 바위와 종유석
				Kit.box(copy, Vector3(scroll_span + 0.5, 3, 10), Color(0.16, 0.09, 0.06), Vector3(scroll_span * 0.5, ceil_y + 1.5, -2)).material_override = Kit.matte(Color(0.16, 0.09, 0.06))
				for i in 9:
					var x := i * 2.7 + r2.randf_range(0, 1)
					Kit.spike(copy, r2.randf_range(0.2, 0.4), r2.randf_range(0.6, 1.4), Color(0.3, 0.18, 0.12), Vector3(x, ceil_y + 0.1, -1.5 - r2.randf_range(0, 2)), Vector3.DOWN)
				# 바닥 돌멩이
				for i in 8:
					Kit.sphere(copy, r2.randf_range(0.12, 0.3), Color(0.38, 0.24, 0.15), Vector3(i * 3.1 + r2.randf(), 0.08, r2.randf_range(-2.5, 1.5)), Vector3(1, 0.5, 1))
				# 횃불 (제안)
				for i in 2:
					var t := Kit.torch(copy, Vector3(4 + i * 12.0, 0, -3.2), 1.0)
					_flicker.append(t.get_child(t.get_child_count() - 1))
				# 보라색 드래곤 자국 (빛나는 얼룩)
				Kit.sphere(copy, 0.25, Color(0.7, 0.2, 1), Vector3(9.0, 2.5, -3.0), Vector3(1, 0.4, 0.2), 1.8, false)
			_ambient_dark(0.5)
		"wall":
			_floor(Color(0.2, 0.15, 0.18), Color(0.12, 0.08, 0.1))
			# 붉은 달 (제안) 과 별
			Kit.sphere(self, 2.4, Color(1, 0.35, 0.2), Vector3(-10, 9, -38), Vector3.ONE, 2.0, false)
			for i in 40:
				Kit.sphere(self, rng.randf_range(0.05, 0.12), Color(1, 1, 0.85), Vector3(rng.randf_range(-35, 35), rng.randf_range(4, 18), -39), Vector3.ONE, 2.0, false)
			# 멀리 본거지 바위산
			for i in 5:
				Kit.spike(self, rng.randf_range(4, 7), rng.randf_range(8, 13), Color(0.12, 0.06, 0.14), Vector3(-24 + i * 12, -1, -32), Vector3.UP, false)
			for x in [-9.5, 9.5]:
				_flicker.append(Kit.torch(self, Vector3(x, 0, 1.0), 1.1).get_child(4))
		"arena":
			_floor(Color(0.26, 0.22, 0.24), Color(0.16, 0.13, 0.15))
			# 돌바닥 줄
			for i in 6:
				Kit.box(self, Vector3(60, 0.02, 0.05), Color(0.18, 0.13, 0.15), Vector3(0, 0.01, 1.5 - i * 1.6), 0.0, false)
			# 어두운 기둥과 붉은 깃발 (제안)
			for i in 8:
				var x := -14.0 + i * 4.0
				Kit.cylinder(self, 0.6, 0.7, 9, Color(0.28, 0.24, 0.3), Vector3(x, 4.5, -5))
				Kit.box(self, Vector3(1.7, 0.4, 1.7), Color(0.2, 0.17, 0.22), Vector3(x, 0.2, -5))
				if i % 2 == 0:
					Kit.box(self, Vector3(1.3, 3.0, 0.06), Color(0.7, 0.05, 0.1), Vector3(x + 2.0, 5.5, -5.5))
					Kit.spike(self, 0.65, 0.6, Color(0.7, 0.05, 0.1), Vector3(x + 2.0, 4.0, -5.5), Vector3.DOWN)
				_flicker.append(Kit.torch(self, Vector3(x + 0.9, 1.0, -4.2), 0.9).get_child(4))
			Kit.box(self, Vector3(80, 20, 1), Color(0.14, 0.08, 0.14), Vector3(0, 8, -8)).material_override = Kit.matte(Color(0.14, 0.08, 0.14))
		"lair":
			_floor(Color(0.16, 0.08, 0.12), Color(0.1, 0.04, 0.08))
			# 용암 틈 (빛나는 주황 줄)
			for i in 9:
				var lava := Kit.box(self, Vector3(rng.randf_range(1.5, 4.0), 0.03, 0.12), Color(1, 0.35, 0.05), Vector3(rng.randf_range(-14, 14), 0.02, rng.randf_range(-6, 2)), 3.0, false)
				lava.rotation.y = rng.randf_range(-0.6, 0.6)
			Kit.light(self, Vector3(-6, 0.5, -1), Color(1, 0.4, 0.15), 0.9, 7.0)
			Kit.light(self, Vector3(7, 0.5, -2), Color(1, 0.4, 0.15), 0.9, 7.0)
			# 뒤 벽 바위와 보라 수정 (제안)
			for i in 16:
				Kit.ground_sphere(self, rng.randf_range(2.0, 3.5), Color(0.14, 0.06, 0.12).lerp(Color(0.22, 0.1, 0.18), rng.randf()), Vector3(-20 + i * 2.7, rng.randf_range(0.5, 7), -9 - rng.randf_range(0, 2)))
			for i in 7:
				var x := -13.0 + i * 4.3 + rng.randf()
				var cr := Node3D.new()
				cr.position = Vector3(x, 0, -6.5 + rng.randf())
				add_child(cr)
				for j in 3:
					Kit.spike(cr, 0.25 - j * 0.05, 1.6 - j * 0.4, Color(0.75, 0.35, 1.0), Vector3((j - 1) * 0.3, 0, 0), Vector3((j - 1) * 0.4, 1, 0), false).material_override = Kit.mat(Color(0.75, 0.35, 1.0), 1.4)
				Kit.light(cr, Vector3(0, 1, 0.5), Color(0.7, 0.3, 1), 0.8, 3.5)
			# 천장 종유석
			var top_y := at(Vector2(640, 40), -3).y
			for i in 12:
				Kit.spike(self, rng.randf_range(0.4, 0.8), rng.randf_range(1.5, 3.0), Color(0.2, 0.08, 0.16), Vector3(-15 + i * 2.7, top_y + 1.0, -3 - rng.randf_range(0, 3)), Vector3.DOWN)
			# 뼈 (제안: 무서운 본거지)
			for x in [-8.0, 4.0, 11.0]:
				Kit.capsule(self, 0.08, 0.9, Color(0.92, 0.88, 0.78), Vector3(x, 0.08, 1.2)).rotation = Vector3(PI / 2, rng.randf(), PI / 2)


func _ambient_dark(e: float) -> void:
	env.ambient_light_energy = e
