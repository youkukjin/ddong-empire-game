extends RefCounted
## 스킬 그림을 3D 모형으로 (2026-11-28 사용자: "그림체를 3D로").
## 게임 속 인물과 같은 크레용 3D(테두리 선 있는 툰) 모형을 작은 화면에 띄워 빙글 돌려요.
##   var v := Icon3D.make_view("sword", Vector2(150, 150))   # SubViewportContainer
## 모형은 반지름 1 정도 안에 들어가게 만들어요.

const Kit := preload("res://scripts/view3d/kit3d.gd")

const POOP := Color(0.56, 0.33, 0.15)
const GOLD := Color(0.9, 0.68, 0.2)
const STEEL := Color(0.78, 0.8, 0.86)
const WOOD := Color(0.5, 0.32, 0.18)


## 3D 그림 한 칸 (투명 바탕). spin: 빙글 도는 빠르기
static func make_view(id: String, size: Vector2, spin := 0.6) -> SubViewportContainer:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.size = size
	box.custom_minimum_size = size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.75, 0.7)
	env.environment.ambient_light_energy = 0.5
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.0
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.1, 3.9), Vector3(0, 0, 0), Vector3.UP)
	var pivot := Spinner.new()
	pivot.speed = spin
	vp.add_child(pivot)
	build(pivot, id)
	return box


class Spinner extends Node3D:
	var speed := 0.6
	var t := 0.0
	func _process(delta: float) -> void:
		t += delta
		rotation.y = sin(t * speed) * 0.7
		position.y = sin(t * 2.0) * 0.05


static func _poop(p: Node3D, s: float, col: Color, pos := Vector3.ZERO) -> void:
	for t in [[0.0, 0.62, 0.62], [0.42, 0.46, 0.66], [0.75, 0.3, 0.72]]:
		Kit.sphere(p, t[1] * s, col, pos + Vector3(0, t[0] * s, 0), Vector3(1, t[2], 1))
	Kit.spike(p, 0.1 * s, 0.25 * s, col, pos + Vector3(0, 0.9 * s, 0), Vector3(0.4, 1, 0))


static func build(p: Node3D, id: String) -> void:
	match id:
		"sword":
			var n := Node3D.new()
			n.rotation.z = -0.75
			p.add_child(n)
			Kit.box(n, Vector3(0.2, 1.3, 0.06), STEEL, Vector3(0, 0.35, 0), 0.1)
			Kit.spike(n, 0.1, 0.25, STEEL, Vector3(0, 1.0, 0), Vector3.UP)
			Kit.box(n, Vector3(0.6, 0.1, 0.14), GOLD, Vector3(0, -0.32, 0))
			Kit.cylinder(n, 0.07, 0.07, 0.4, WOOD, Vector3(0, -0.57, 0))
			Kit.sphere(n, 0.1, GOLD, Vector3(0, -0.8, 0))
		"chain":
			Kit.sphere(p, 0.45, Color(0.45, 0.6, 0.4), Vector3(0.25, 0.25, 0))
			for i in 8:
				var d := Vector3(cos(i * 0.785), sin(i * 0.785), 0.3 * (i % 2 * 2 - 1)).normalized()
				Kit.spike(p, 0.08, 0.28, STEEL, Vector3(0.25, 0.25, 0) + d * 0.4, d)
			for i in 3:
				Kit.torus(p, 0.06, 0.12, STEEL, Vector3(-0.3 - i * 0.2, -0.25 - i * 0.18, 0)).rotation.x = PI / 2 * (i % 2)
			Kit.cylinder(p, 0.08, 0.08, 0.35, WOOD, Vector3(-0.95, -0.8, 0)).rotation.z = 0.7
		"fist":
			Kit.sphere(p, 0.55, Color(0.85, 0.3, 0.25), Vector3(0, 0.1, 0), Vector3(1.1, 0.95, 0.9))
			for i in 4:
				Kit.sphere(p, 0.17, Color(0.9, 0.35, 0.28), Vector3(-0.36 + i * 0.24, 0.5, 0.3))
			Kit.capsule(p, 0.14, 0.45, Color(0.9, 0.35, 0.28), Vector3(-0.55, 0.05, 0.3)).rotation.z = 0.5
			Kit.cylinder(p, 0.38, 0.42, 0.35, Color(0.95, 0.92, 0.85), Vector3(0, -0.6, 0))
		"bomb":
			_poop(p, 0.8, Color(0.3, 0.2, 0.12), Vector3(0, -0.5, 0))
			Kit.cylinder(p, 0.04, 0.04, 0.35, Color(0.85, 0.8, 0.6), Vector3(0.15, 0.45, 0)).rotation.z = -0.4
			Kit.sphere(p, 0.13, Color(1, 0.6, 0.15), Vector3(0.25, 0.68, 0), Vector3.ONE, 2.5, false)
		"flies":
			for k in 3:
				var c := Vector3(-0.5 + k * 0.5, 0.25 - (k % 2) * 0.45, 0)
				Kit.sphere(p, 0.2, Color(0.2, 0.32, 0.2), c, Vector3(1.3, 1, 1))
				Kit.sphere(p, 0.12, Color(0.75, 0.15, 0.1), c + Vector3(0.22, 0.04, 0.05))
				for sx in [-1.0, 1.0]:
					Kit.sphere(p, 0.18, Color(0.92, 0.96, 1.0), c + Vector3(-0.05, 0.2, sx * 0.12), Vector3(1.2, 0.3, 0.8), 0.3)
		"beam":
			Kit.cylinder(p, 0.06, 0.08, 1.2, WOOD, Vector3(-0.2, -0.35, 0)).rotation.z = 0.35
			Kit.spike(p, 0.26, 0.55, Color(0.6, 0.3, 0.9), Vector3(0.05, 0.35, 0), Vector3.UP)
			Kit.spike(p, 0.26, 0.3, Color(0.5, 0.22, 0.8), Vector3(0.05, 0.36, 0), Vector3.DOWN)
			Kit.sphere(p, 0.09, Color(1, 0.9, 1), Vector3(0.0, 0.5, 0.18), Vector3.ONE, 1.2, false)
			Kit.torus(p, 0.3, 0.38, GOLD, Vector3(0.05, 0.1, 0)).rotation.x = PI / 2
		"boomerang":
			for sx in [-1.0, 1.0]:
				var arm := Kit.box(p, Vector3(0.95, 0.22, 0.12), Color(0.65, 0.42, 0.2), Vector3(sx * 0.35, 0.1, 0))
				arm.rotation.z = sx * -0.55
				Kit.box(p, Vector3(0.5, 0.06, 0.13), Color(1, 0.82, 0.3), Vector3(sx * 0.45, 0.04, 0.01)).rotation.z = sx * -0.55
		"cloud":
			for t in [[0, 0, 0.45], [-0.5, -0.1, 0.33], [0.5, -0.1, 0.35], [-0.25, 0.32, 0.32], [0.3, 0.3, 0.3]]:
				Kit.sphere(p, t[2], Color(0.6, 0.76, 0.32), Vector3(t[0], t[1], 0))
		"lightning":
			for t in [[0.5, 0.45, 0.42], [0.0, -0.4, 0.28], [-0.5, 0.45, 0.25]]:
				Kit.sphere(p, t[2], Color(0.55, 0.55, 0.62), Vector3(t[0] * 0.7, 0.55, -0.1))
			var pts := [Vector3(0.15, 0.4, 0.2), Vector3(-0.3, -0.1, 0.2), Vector3(0.25, -0.2, 0.2), Vector3(-0.2, -0.95, 0.2)]
			for i in 3:
				var seg := Kit.box(p, Vector3(0.24, 0.24, 0.1), Color(1, 0.85, 0.2), Vector3.ZERO, 0.8)
				Kit.stretch_between(seg, pts[i], pts[i + 1])
		"thorns":
			_poop(p, 0.75, Color(0.45, 0.5, 0.35), Vector3(0, -0.5, 0))
			for i in 10:
				var d := Vector3(cos(i * 1.3), 0.3 + (i % 3) * 0.3, sin(i * 1.3)).normalized()
				Kit.spike(p, 0.07, 0.3, Color(0.85, 0.85, 0.75), Vector3(0, -0.1, 0) + d * 0.45, d)
		"puddle":
			Kit.cylinder(p, 0.85, 0.9, 0.1, Color(0.42, 0.26, 0.12), Vector3(0, -0.4, 0))
			for t in [[-0.3, 0.12], [0.25, 0.18], [0.05, 0.1]]:
				Kit.sphere(p, t[1], Color(0.6, 0.42, 0.2), Vector3(t[0], -0.25, 0.2))
			_poop(p, 0.45, POOP, Vector3(0, -0.3, -0.3))
		"ice":
			_poop(p, 0.75, Color(0.65, 0.88, 1.0), Vector3(0, -0.55, 0))
			for i in 5:
				var d := Vector3(cos(i * 1.26), 0.9, sin(i * 1.26)).normalized()
				Kit.spike(p, 0.09, 0.45, Color(0.85, 0.97, 1.0), Vector3(0, 0.0, 0) + d * 0.35, d)
		"power":
			Kit.sphere(p, 0.42, Color(0.85, 0.2, 0.2), Vector3(0, -0.3, 0), Vector3.ONE, 0.6)
			Kit.cylinder(p, 0.13, 0.16, 0.35, Color(0.9, 0.9, 0.95), Vector3(0, 0.2, 0))
			Kit.cylinder(p, 0.15, 0.15, 0.14, WOOD, Vector3(0, 0.43, 0))
		"swift":
			Kit.box(p, Vector3(0.8, 0.3, 0.4), Color(0.3, 0.55, 0.85), Vector3(0, -0.3, 0))
			Kit.sphere(p, 0.22, Color(0.3, 0.55, 0.85), Vector3(0.35, -0.25, 0), Vector3(1.2, 0.8, 1))
			Kit.box(p, Vector3(0.85, 0.08, 0.42), Color(0.95, 0.95, 0.9), Vector3(0, -0.48, 0))
			for k in 3:
				Kit.box(p, Vector3(0.5 - k * 0.1, 0.12, 0.04), Color(1, 1, 1), Vector3(-0.45, 0.05 + k * 0.16, 0.2)).rotation.z = 0.5
		"heart":
			for sx in [-1.0, 1.0]:
				Kit.sphere(p, 0.38, Color(0.9, 0.22, 0.3), Vector3(sx * 0.27, 0.2, 0))
			var tip := Kit.spike(p, 0.5, 0.75, Color(0.9, 0.22, 0.3), Vector3(0, 0.12, 0), Vector3.DOWN)
			tip.scale.z = 0.75
		"magnet":
			for sx in [-1.0, 1.0]:
				Kit.box(p, Vector3(0.28, 0.7, 0.28), Color(0.85, 0.2, 0.2), Vector3(sx * 0.35, 0.05, 0))
				Kit.box(p, Vector3(0.29, 0.22, 0.29), STEEL, Vector3(sx * 0.35, -0.42, 0))
			Kit.box(p, Vector3(0.98, 0.28, 0.28), Color(0.85, 0.2, 0.2), Vector3(0, 0.5, 0))
		"dumbbell":
			Kit.cylinder(p, 0.06, 0.06, 1.5, STEEL, Vector3.ZERO).rotation.z = PI / 2
			for sx in [-1.0, 1.0]:
				Kit.cylinder(p, 0.34, 0.34, 0.2, Color(0.25, 0.25, 0.3), Vector3(sx * 0.55, 0, 0)).rotation.z = PI / 2
		"cape":
			var cp := Kit.prism(p, Vector3(1.1, 1.2, 0.12), Color(0.75, 0.15, 0.2), Vector3(0, -0.15, 0))
			cp.rotation.x = 0.15
			Kit.torus(p, 0.15, 0.28, GOLD, Vector3(0, 0.5, 0.05))
		"crown":
			Kit.cylinder(p, 0.55, 0.5, 0.35, GOLD, Vector3(0, -0.2, 0))
			for i in 5:
				var a := i * TAU / 5.0
				Kit.spike(p, 0.12, 0.35, GOLD, Vector3(cos(a) * 0.48, 0.1, sin(a) * 0.48), Vector3.UP)
				Kit.sphere(p, 0.07, Color(0.85, 0.15, 0.25) if i % 2 else Color(0.2, 0.5, 0.9), Vector3(cos(a) * 0.53, -0.18, sin(a) * 0.53), Vector3.ONE, 0.6)
		"armor":
			Kit.sphere(p, 0.55, STEEL, Vector3(0, -0.1, 0), Vector3(1, 1.1, 0.6))
			for sx in [-1.0, 1.0]:
				Kit.sphere(p, 0.25, STEEL.darkened(0.1), Vector3(sx * 0.55, 0.35, 0))
			Kit.box(p, Vector3(0.08, 0.7, 0.08), GOLD, Vector3(0, -0.1, 0.32))
		"luck":
			for i in 4:
				var a := i * PI / 2 + PI / 4
				Kit.sphere(p, 0.3, Color(0.35, 0.65, 0.3), Vector3(cos(a) * 0.3, sin(a) * 0.3 + 0.15, 0), Vector3(1, 1, 0.4))
			Kit.cylinder(p, 0.04, 0.05, 0.6, Color(0.3, 0.5, 0.25), Vector3(0.1, -0.45, 0)).rotation.z = 0.3
		"milk":
			Kit.cylinder(p, 0.32, 0.36, 0.9, Color(0.97, 0.97, 0.94), Vector3(0, -0.2, 0))
			Kit.cylinder(p, 0.18, 0.3, 0.2, Color(0.97, 0.97, 0.94), Vector3(0, 0.35, 0))
			Kit.cylinder(p, 0.2, 0.2, 0.14, POOP, Vector3(0, 0.5, 0))
			Kit.cylinder(p, 0.37, 0.37, 0.22, POOP, Vector3(0, -0.2, 0))
		"book":
			Kit.box(p, Vector3(1.0, 0.18, 0.75), Color(0.45, 0.25, 0.15), Vector3(0, -0.12, 0))
			Kit.box(p, Vector3(0.92, 0.14, 0.7), Color(0.95, 0.9, 0.75), Vector3(0.02, 0.02, 0))
			Kit.sphere(p, 0.12, GOLD, Vector3(0, 0.3, 0), Vector3.ONE, 1.5)
			p.rotation.x = 0.4
		"trait_hp":
			_poop(p, 0.8, POOP, Vector3(0, -0.55, 0))
			Kit.box(p, Vector3(0.9, 0.35, 0.6), STEEL, Vector3(0, -0.35, 0.05))
			for sx in [-1.0, 1.0]:
				Kit.sphere(p, 0.13, Color(0.9, 0.22, 0.3), Vector3(0.45 + sx * 0.1, 0.65, 0.2))
		"trait_atk":
			_poop(p, 0.8, Color(0.75, 0.22, 0.12), Vector3(0, -0.55, 0))
			for i in 3:
				Kit.spike(p, 0.16, 0.5, Color(1, 0.55, 0.12), Vector3(-0.25 + i * 0.25, 0.25, 0), Vector3(-0.2 + i * 0.2, 1, 0))
			for sx in [-1.0, 1.0]:
				Kit.fierce_eye(p, Vector3(sx * 0.18, -0.05, 0.42), 0.1)
		"coins":
			for i in 4:
				Kit.cylinder(p, 0.4, 0.4, 0.12, GOLD, Vector3(i * 0.05, -0.5 + i * 0.14, 0), 0.3)
			Kit.cylinder(p, 0.4, 0.4, 0.12, GOLD, Vector3(0.5, 0.0, 0.1), 0.3).rotation.x = PI / 2
		_:
			_poop(p, 0.8, POOP, Vector3(0, -0.5, 0))
