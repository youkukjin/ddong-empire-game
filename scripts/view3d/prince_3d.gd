extends Node3D
## 3D 똥 왕자 (제안: 3D 화면).
## 원작대로 갈색 똥 모양 몸에 왕관을 쓰고 검을 들었고, 다른 팔에는 사슬 무기가 있어요.
## 기본 도형으로 만든 임시 모델이에요. 발밑이 position이고 앞은 +z(카메라 쪽)예요.

const Kit := preload("res://scripts/view3d/kit3d.gd")

const BODY := Color(0.72, 0.46, 0.26)
const BODY_DARK := Color(0.5, 0.3, 0.16)
const GOLD := Color(1, 0.8, 0.25)

var facing := 1.0:          # 1 = 오른쪽, -1 = 왼쪽
	set(v):
		facing = v
		if _turn:
			_turn.rotation.y = deg_to_rad(25.0 * v)
var cheer := false
var god := false:
	set(v):
		god = v
		_apply_god()

var _t := randf() * 10.0
var _turn: Node3D
var _body: Node3D
var _sword_arm: Node3D
var _chain_arm: Node3D
var _tiers: Array[MeshInstance3D] = []
var _aura: MeshInstance3D


func _ready() -> void:
	Kit.shadow(self, 0.95)
	_turn = Node3D.new()
	add_child(_turn)
	_body = Node3D.new()
	_turn.add_child(_body)
	# 똥 몸: 세 겹 + 끝
	_tiers.append(Kit.sphere(_body, 0.85, BODY, Vector3(0, 0.42, 0), Vector3(1, 0.58, 0.9)))
	_tiers.append(Kit.sphere(_body, 0.66, BODY, Vector3(0, 0.98, 0), Vector3(1, 0.62, 0.92)))
	_tiers.append(Kit.sphere(_body, 0.45, BODY, Vector3(0, 1.42, 0), Vector3(1, 0.66, 0.95)))
	_tiers.append(Kit.sphere(_body, 0.2, BODY, Vector3(0.05, 1.7, 0), Vector3(1, 1.1, 1)))
	# 얼굴 (가운데 겹)
	Kit.eye(_body, Vector3(-0.22, 1.04, 0.55), 0.17)
	Kit.eye(_body, Vector3(0.22, 1.04, 0.55), 0.17)
	Kit.blush(_body, Vector3(-0.42, 0.88, 0.48), 0.1)
	Kit.blush(_body, Vector3(0.42, 0.88, 0.48), 0.1)
	var mouth := Kit.torus(_body, 0.06, 0.1, Color(0.3, 0.12, 0.1), Vector3(0, 0.84, 0.6))
	mouth.rotation_degrees = Vector3(90, 0, 0)
	mouth.scale = Vector3(1, 1, 0.5)
	# 왕관
	var crown := Node3D.new()
	crown.position = Vector3(0, 1.78, 0)
	_body.add_child(crown)
	Kit.cylinder(crown, 0.3, 0.3, 0.16, GOLD, Vector3.ZERO, 0.15)
	for i in 5:
		var a := TAU * i / 5.0
		var spike := Kit.cylinder(crown, 0.0, 0.08, 0.24, GOLD, Vector3(cos(a) * 0.26, 0.18, sin(a) * 0.26), 0.15)
		spike.rotation.z = 0.0
		Kit.sphere(crown, 0.045, GOLD, Vector3(cos(a) * 0.26, 0.31, sin(a) * 0.26), Vector3.ONE, 0.3)
	Kit.sphere(crown, 0.07, Color(1, 0.45, 0.6), Vector3(0, 0.02, 0.3), Vector3.ONE, 0.4)
	# 검 팔 (오른쪽)
	_sword_arm = Node3D.new()
	_sword_arm.position = Vector3(0.62, 1.0, 0.1)
	_body.add_child(_sword_arm)
	Kit.capsule(_sword_arm, 0.11, 0.42, BODY, Vector3(0.18, -0.05, 0)).rotation_degrees = Vector3(0, 0, 70)
	var hand := Vector3(0.38, -0.1, 0.05)
	Kit.box(_sword_arm, Vector3(0.36, 0.07, 0.1), Color(0.55, 0.34, 0.2), hand)
	Kit.box(_sword_arm, Vector3(0.09, 1.0, 0.04), Color(0.88, 0.92, 1.0), hand + Vector3(0, 0.55, 0)).material_override = _blade_mat()
	Kit.box(_sword_arm, Vector3(0.07, 0.22, 0.07), Color(0.45, 0.28, 0.16), hand + Vector3(0, -0.12, 0))
	# 사슬 팔 (왼쪽)
	_chain_arm = Node3D.new()
	_chain_arm.position = Vector3(-0.62, 0.95, 0.1)
	_body.add_child(_chain_arm)
	Kit.capsule(_chain_arm, 0.11, 0.42, BODY, Vector3(-0.16, -0.08, 0)).rotation_degrees = Vector3(0, 0, -70)
	for i in 4:
		Kit.sphere(_chain_arm, 0.045, Color(0.7, 0.72, 0.78), Vector3(-0.36 - i * 0.04, -0.22 - i * 0.12, 0.05))
	var ball := Kit.sphere(_chain_arm, 0.2, Color(0.42, 0.75, 0.42), Vector3(-0.5, -0.78, 0.05))
	for i in 8:
		var a := TAU * i / 8.0
		var sp := Kit.cylinder(ball, 0.0, 0.05, 0.14, Color(0.3, 0.55, 0.32), Vector3(cos(a) * 0.2, sin(a) * 0.2, 0))
		sp.rotation.z = a - PI / 2.0
	facing = facing


func _blade_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.94, 1.0)
	m.metallic = 0.8
	m.roughness = 0.15
	return m


func _apply_god() -> void:
	if not _body:
		return
	for t in _tiers:
		t.material_override = Kit.mat(Color(1, 0.8, 0.35) if god else BODY, 0.35 if god else 0.0)
	if god and not _aura:
		_aura = Kit.sphere(self, 1.6, Color(1, 0.9, 0.4, 0.18), Vector3(0, 1.0, 0), Vector3.ONE, 1.0)
	if _aura:
		_aura.visible = god


func _process(delta: float) -> void:
	_t += delta
	if not _body:
		return
	var bob := sin(_t * 4.0)
	_body.scale = Vector3(1.0 + bob * 0.03, 1.0 - bob * 0.04, 1.0 + bob * 0.03)
	_body.position.y = absf(bob) * 0.04
	if cheer:
		_sword_arm.rotation.z = 0.9 + sin(_t * 6.0) * 0.25
		_chain_arm.rotation.z = -0.3
	else:
		_sword_arm.rotation.z = sin(_t * 2.0) * 0.08
		_chain_arm.rotation.z = sin(_t * 2.0 + 1.0) * 0.08
	if _aura:
		_aura.scale = Vector3.ONE * (1.0 + sin(_t * 5.0) * 0.06)
