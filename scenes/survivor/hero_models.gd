extends RefCounted
## 서바이버 캐릭터 3D 모습 (2026-11-28 사용자: "케릭터들도 만들고 초반에는 약한 똥들").
## 똥 왕자는 장에서 쓰던 Prince3D 그대로, 나머지는 크기·색·소품이 다른 똥들.
## 모두 pose, blink, god, turn_deg 를 가져서 서바이버 화면이 똑같이 다룰 수 있어요.

const Kit := preload("res://scripts/view3d/kit3d.gd")
const Prince3D := preload("res://scripts/view3d/prince_3d.gd")


static func make(id: String) -> Node3D:
	if id == "prince":
		var p := Prince3D.new()
		p.turn_deg = 0.0
		return p
	var h := HeroPoop.new()
	h.id = id
	return h


## 고른 장비가 몸에 보여요 (2026-11-28 사용자: "갑옷 착용하면 이미지도 갑옷 입은 이미지로").
## gear: {"armor": 단계, "cape": 단계, "crown": 단계, "thorns": 단계}. 바뀔 때만 다시 만들어요.
static func apply_gear(hero: Node3D, gear: Dictionary) -> void:
	var key := str(gear)
	if hero.get_meta("gear_key", "") == key:
		return
	hero.set_meta("gear_key", key)
	var holder: Node3D = hero.get("_body") if hero.get("_body") != null else hero
	var old := holder.get_node_or_null("Gear")
	if old:
		old.free()
	var g := Node3D.new()
	g.name = "Gear"
	holder.add_child(g)
	var is_prince := hero is Prince3D
	var h := 1.75 if is_prince else 1.35
	var w := 0.9 if is_prince else 0.72
	var steel := Color(0.75, 0.78, 0.84)
	var gold := Color(0.9, 0.68, 0.2)
	var armor := int(gear.get("armor", 0))
	if armor > 0:
		# 가슴 갑옷 + 어깨 보호대 (3단계부터 금테, 5단계는 투구 깃)
		Kit.sphere(g, w * 0.78, steel, Vector3(0, h * 0.42, 0.06), Vector3(1.0, 0.62, 0.9))
		Kit.box(g, Vector3(w * 0.08, h * 0.3, 0.06), gold if armor >= 3 else steel.darkened(0.2), Vector3(0, h * 0.42, w * 0.72))
		for sx in [-1.0, 1.0]:
			Kit.sphere(g, w * 0.26, steel.darkened(0.08), Vector3(sx * w * 0.72, h * 0.6, 0), Vector3(1, 0.7, 1))
			if armor >= 3:
				Kit.torus(g, w * 0.2, w * 0.27, gold, Vector3(sx * w * 0.72, h * 0.6, 0))
		if armor >= 5:
			Kit.spike(g, 0.08, 0.35, Color(0.85, 0.15, 0.2), Vector3(0, h * 1.02, -0.05), Vector3(0, 1, -0.4))
	var cape := int(gear.get("cape", 0))
	if cape > 0:
		var c := Kit.prism(g, Vector3(w * 1.5, h * 0.75, 0.08), Color(0.7, 0.14, 0.2), Vector3(0, h * 0.4, -w * 0.75))
		c.rotation.x = 0.2
		c.rotation.y = PI
		Kit.torus(g, w * 0.3, w * 0.42, gold, Vector3(0, h * 0.72, -w * 0.3)).rotation.x = 0.3
	var crown := int(gear.get("crown", 0))
	if crown > 0 and not is_prince:
		Kit.cylinder(g, 0.24, 0.22, 0.14, gold, Vector3(0, h * 1.02, 0), 0.2)
		for i in 5:
			var a := TAU * i / 5.0
			Kit.cylinder(g, 0.0, 0.07, 0.22, gold, Vector3(cos(a) * 0.2, h * 1.02 + 0.16, sin(a) * 0.2), 0.2)
	elif crown > 0:
		Kit.sphere(g, 0.1, Color(0.2, 0.5, 0.95), Vector3(0, 1.82, 0.33), Vector3.ONE, 1.0, false)
	var thorns := int(gear.get("thorns", 0))
	if thorns > 0:
		for i in 10:
			var a := TAU * i / 10.0
			var d := Vector3(cos(a), 0.25, sin(a)).normalized()
			Kit.spike(g, 0.06, 0.28, Color(0.88, 0.86, 0.75), Vector3(cos(a) * w * 0.85, h * 0.28, sin(a) * w * 0.8), d)


## 약한 똥 캐릭터 (몸통 세 겹 + 얼굴 + 캐릭터마다 다른 소품)
class HeroPoop extends Node3D:
	var id := "kid"
	var turn_deg := 0.0
	var pose := 0           # Prince3D.Pose 와 같은 숫자 (0 쉬기, 1 휘두르기, 4 아야)
	var blink := 0.0
	var god := false
	var _body: Node3D
	var _tiers: Array[MeshInstance3D] = []
	var _glow: MeshInstance3D
	var _t := 0.0
	var _col := Color(0.62, 0.4, 0.2)

	func _ready() -> void:
		Kit.shadow(self, 0.8)
		_body = Node3D.new()
		add_child(_body)
		var s := 0.8
		match id:
			"kid":
				_col = Color(0.72, 0.5, 0.26)
				s = 0.72
			"runny":
				_col = Color(0.8, 0.62, 0.25)
				s = 0.78
			"gassy":
				_col = Color(0.5, 0.48, 0.22)
			"icy":
				_col = Color(0.62, 0.82, 0.95)
			"rock":
				_col = Color(0.52, 0.5, 0.52)
				s = 0.95
		var stack := [[0.0, 0.85, 0.58], [0.56, 0.66, 0.62], [1.0, 0.45, 0.66]]
		if id == "runny":
			stack = [[0.0, 0.95, 0.4], [0.42, 0.7, 0.5], [0.78, 0.45, 0.6]]
		for t in stack:
			_tiers.append(Kit.sphere(_body, t[1] * s, _col, Vector3(0, (0.42 + t[0]) * s, 0), Vector3(1, t[2], 0.92)))
		var top: float = (0.42 + float(stack[2][0])) * s + 0.3 * s
		_tiers.append(Kit.sphere(_body, 0.18 * s, _col, Vector3(0.05, top, 0), Vector3(1, 1.1, 1)))
		var face_y: float = (0.42 + float(stack[1][0])) * s + 0.05
		var er := 0.15 * s if id != "kid" else 0.19 * s
		Kit.eye(_body, Vector3(-0.2 * s, face_y, 0.55 * s), er)
		Kit.eye(_body, Vector3(0.2 * s, face_y, 0.55 * s), er)
		match id:
			"kid":
				# 동그란 큰 눈, 머리에 새싹
				Kit.blush(_body, Vector3(-0.38 * s, face_y - 0.15, 0.5 * s), 0.08)
				Kit.blush(_body, Vector3(0.38 * s, face_y - 0.15, 0.5 * s), 0.08)
				Kit.cylinder(_body, 0.03, 0.03, 0.25, Color(0.3, 0.6, 0.25), Vector3(0, top + 0.2, 0))
				for sx in [-1.0, 1.0]:
					var leaf := Kit.sphere(_body, 0.12, Color(0.4, 0.75, 0.3), Vector3(sx * 0.12, top + 0.33, 0), Vector3(1.4, 0.4, 0.8))
					leaf.rotation.z = sx * 0.4
			"runny":
				# 땀방울과 꽉 쥔 입, 흘러내린 자국
				Kit.sphere(_body, 0.08, Color(0.6, 0.85, 1.0), Vector3(0.45 * s, face_y + 0.2, 0.35), Vector3(0.8, 1.3, 0.8), 0.3)
				Kit.box(_body, Vector3(0.22, 0.05, 0.05), Color(0.2, 0.05, 0.04), Vector3(0, face_y - 0.2, 0.6 * s), 0.0, false)
				for k in 3:
					Kit.sphere(_body, 0.12, _col, Vector3(-0.5 + k * 0.5, 0.05, 0.6) * s, Vector3(1, 0.4, 1.6))
			"gassy":
				# 둘레에 초록 방귀 뭉치, 볼 빵빵
				for k in 3:
					Kit.sphere(_body, 0.18, Color(0.55, 0.75, 0.3), Vector3(-0.5 + k * 0.25, 0.25 + k * 0.12, -0.55))
				Kit.sphere(_body, 0.12, _col.darkened(0.15), Vector3(0, face_y - 0.2, 0.55 * s), Vector3(1.3, 0.8, 0.6))
			"icy":
				# 얼음 왕관 가시와 파란 볼
				for k in 5:
					var a := TAU * k / 5.0
					Kit.spike(_body, 0.06, 0.28, Color(0.85, 0.97, 1.0), Vector3(cos(a) * 0.2, top, sin(a) * 0.2), Vector3(cos(a) * 0.3, 1, sin(a) * 0.3))
				Kit.box(_body, Vector3(0.2, 0.05, 0.05), Color(0.15, 0.2, 0.4), Vector3(0, face_y - 0.2, 0.55 * s), 0.0, false)
			"rock":
				# 바위 조각, 굵은 눈썹, 이끼
				for k in 6:
					var a := k * 1.1
					Kit.box(_body, Vector3(0.22, 0.18, 0.22), _col.darkened(0.25), Vector3(cos(a) * 0.65, 0.35 + (k % 3) * 0.35, sin(a) * 0.6) * s).rotation = Vector3(a, a * 0.5, 0)
				Kit.brow(_body, Vector3(-0.2 * s, face_y + 0.2, 0.6 * s), 0.25, -0.3)
				Kit.brow(_body, Vector3(0.2 * s, face_y + 0.2, 0.6 * s), 0.25, 0.3)
				Kit.sphere(_body, 0.3, Color(0.35, 0.5, 0.22), Vector3(0.1, top, 0), Vector3(1.2, 0.35, 1.0))
		_glow = Kit.sphere(self, 1.2, Color(1, 0.85, 0.3, 0.3), Vector3(0, 0.8, 0), Vector3.ONE, 2.0, false)
		_glow.material_override = Kit.mat(Color(1, 0.85, 0.3, 0.28), 2.0, 0.5, true, false)
		_glow.visible = false

	func _process(delta: float) -> void:
		_t += delta
		var hop := absf(sin(_t * (12.0 if id == "runny" else 8.0))) * 0.08
		_body.position.y = hop
		_body.scale = Vector3(1.0 + hop * 0.5, 1.0 - hop * 0.6, 1.0 + hop * 0.5)
		if pose == 1:
			_body.rotation.x = -0.25
		elif pose == 4:
			_body.rotation.x = 0.35
		else:
			_body.rotation.x = lerpf(_body.rotation.x, 0.0, minf(delta * 10.0, 1.0))
		visible = blink <= 0.0 or int(_t * 16.0) % 2 == 0
		_glow.visible = god
		if god:
			_glow.scale = Vector3.ONE * (1.0 + sin(_t * 6.0) * 0.08)
