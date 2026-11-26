extends Node3D
## 3D 똥 왕자 (제안: 3D 화면, 박력 있는 그림체).
## 원작대로 갈색 똥 모양 몸에 왕관을 쓰고 검을 들었고, 다른 팔에는 사슬 무기가 있어요.
## 기본 도형으로 만든 임시 모델이에요. 발밑이 position이고 앞은 +z(카메라 쪽)예요.
## 2D 왕자(scripts/art/prince.gd)의 자세를 sync_from()으로 그대로 따라 해요.

const Kit := preload("res://scripts/view3d/kit3d.gd")

enum Pose { IDLE, SWING, CHARGE, ROLL, HURT, CHEER }

const BODY := Color(0.56, 0.32, 0.14)
const BODY_DARK := Color(0.36, 0.19, 0.08)
const GOLD := Color(1, 0.78, 0.12)
const GOD_BODY := Color(1, 0.78, 0.2)

var turn_deg := 25.0         # 옆으로 얼마나 돌아볼지 (옆에서 보는 장은 더 크게)
var facing := 1.0:          # 1 = 오른쪽, -1 = 왼쪽
	set(v):
		facing = v
		if _turn:
			_turn.rotation.y = deg_to_rad(turn_deg * v)
var cheer := false
var pose := Pose.IDLE:
	set(v):
		if v != pose:
			_pose_t = 0.0
		pose = v
var charge := 0.0
var blink := 0.0
var arm_level := 0:
	set(v):
		arm_level = v
		_apply_arms()
var god := false:
	set(v):
		if v != god:
			god = v
			_apply_god()

var _t := randf() * 10.0
var _pose_t := 0.0
var _turn: Node3D
var _body: Node3D
var _sword_arm: Node3D
var _chain_arm: Node3D
var _arm_meshes: Array[MeshInstance3D] = []
var _tiers: Array[MeshInstance3D] = []
var _aura: MeshInstance3D
var _rays: Node3D
var _ball: MeshInstance3D
var _charge_ring: MeshInstance3D
var _slash: MeshInstance3D
var _hurt_tint := 0.0


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
	# 얼굴: 굳센 눈과 눈썹, 꽉 다문 입 (박력 있는 표정)
	Kit.eye(_body, Vector3(-0.22, 1.04, 0.55), 0.16)
	Kit.eye(_body, Vector3(0.22, 1.04, 0.55), 0.16)
	Kit.brow(_body, Vector3(-0.22, 1.24, 0.6), 0.26, -0.35)
	Kit.brow(_body, Vector3(0.22, 1.24, 0.6), 0.26, 0.35)
	var mouth := Kit.box(_body, Vector3(0.26, 0.06, 0.05), Color(0.2, 0.05, 0.04), Vector3(0, 0.84, 0.62), 0.0, false)
	mouth.rotation.z = 0.08
	# 왕관
	var crown := Node3D.new()
	crown.position = Vector3(0, 1.78, 0)
	_body.add_child(crown)
	Kit.cylinder(crown, 0.32, 0.3, 0.18, GOLD, Vector3.ZERO, 0.2)
	for i in 5:
		var a := TAU * i / 5.0
		Kit.cylinder(crown, 0.0, 0.09, 0.3, GOLD, Vector3(cos(a) * 0.27, 0.22, sin(a) * 0.27), 0.2)
	Kit.sphere(crown, 0.08, Color(0.95, 0.1, 0.2), Vector3(0, 0.02, 0.31), Vector3.ONE, 0.8, false)
	# 검 팔 (오른쪽)
	_sword_arm = Node3D.new()
	_sword_arm.position = Vector3(0.62, 1.0, 0.1)
	_body.add_child(_sword_arm)
	var a1 := Kit.capsule(_sword_arm, 0.12, 0.46, BODY, Vector3(0.18, -0.05, 0))
	a1.rotation_degrees = Vector3(0, 0, 70)
	_arm_meshes.append(a1)
	var hand := Vector3(0.38, -0.1, 0.05)
	Kit.box(_sword_arm, Vector3(0.4, 0.08, 0.12), Color(0.85, 0.65, 0.15), hand)
	var blade := Kit.box(_sword_arm, Vector3(0.11, 1.15, 0.04), Color(0.88, 0.92, 1.0), hand + Vector3(0, 0.62, 0))
	blade.material_override = Kit.metal(Color(0.85, 0.9, 1.0))
	Kit.box(_sword_arm, Vector3(0.08, 0.24, 0.08), Color(0.35, 0.2, 0.1), hand + Vector3(0, -0.13, 0))
	# 휘두를 때 칼바람 (반달 모양)
	_slash = Kit.torus(_sword_arm, 0.95, 1.12, Color(1, 1, 0.75), hand, 3.0, false)
	_slash.rotation_degrees = Vector3(90, 0, 0)
	_slash.visible = false
	# 사슬 팔 (왼쪽)
	_chain_arm = Node3D.new()
	_chain_arm.position = Vector3(-0.62, 0.95, 0.1)
	_body.add_child(_chain_arm)
	var a2 := Kit.capsule(_chain_arm, 0.12, 0.46, BODY, Vector3(-0.16, -0.08, 0))
	a2.rotation_degrees = Vector3(0, 0, -70)
	_arm_meshes.append(a2)
	for i in 4:
		Kit.sphere(_chain_arm, 0.05, Color(0.7, 0.72, 0.78), Vector3(-0.36 - i * 0.04, -0.22 - i * 0.12, 0.05), Vector3.ONE, 0.0, false)
	_ball = Kit.sphere(_chain_arm, 0.21, Color(0.25, 0.7, 0.25), Vector3(-0.5, -0.78, 0.05))
	for i in 8:
		var a := TAU * i / 8.0
		Kit.spike(_ball, 0.05, 0.16, Color(0.15, 0.45, 0.18), Vector3(cos(a) * 0.18, sin(a) * 0.18, 0), Vector3(cos(a), sin(a), 0))
	# 힘 모으기 고리 (사슬 무기)
	_charge_ring = Kit.torus(self, 0.9, 1.05, Color(0.3, 1, 0.4), Vector3(0, 0.08, 0), 2.5, false)
	_charge_ring.visible = false
	facing = facing
	_apply_arms()
	_apply_god()


## 2D 왕자의 상태를 그대로 따라 해요.
func sync_from(p: Node2D) -> void:
	facing = p.facing
	pose = int(p.pose)
	charge = p.charge
	blink = p.blink
	if arm_level != int(p.arm_level):
		arm_level = int(p.arm_level)
	god = p.god


func _apply_arms() -> void:
	var s := 1.0 + arm_level * 0.28
	for a in _arm_meshes:
		a.scale = Vector3(s, 1.0 + arm_level * 0.1, s)


func _apply_god() -> void:
	if not _body:
		return
	for t in _tiers:
		t.material_override = Kit.mat(GOD_BODY if god else BODY, 0.45 if god else 0.0)
	if god and not _aura:
		_aura = Kit.sphere(self, 1.7, Color(1, 0.85, 0.3, 0.22), Vector3(0, 1.0, 0), Vector3.ONE, 1.5)
		_rays = Node3D.new()
		_rays.position = Vector3(0, 1.0, -0.4)
		add_child(_rays)
		for i in 12:
			var a := TAU * i / 12.0
			var r := Kit.box(_rays, Vector3(0.08, 1.2, 0.02), Color(1, 0.9, 0.35), Vector3(cos(a) * 1.6, sin(a) * 1.6, 0), 2.5, false)
			r.rotation.z = a - PI / 2.0
	if _aura:
		_aura.visible = god
		_rays.visible = god


func _process(delta: float) -> void:
	_t += delta
	_pose_t += delta
	if not _body:
		return
	visible = not (blink > 0.0 and int(blink * 14.0) % 2 == 0)
	var bob := sin(_t * 4.0)
	_body.rotation = Vector3.ZERO
	_body.position = Vector3.ZERO
	_slash.visible = false
	_charge_ring.visible = false
	_ball.material_override = Kit.mat(Color(0.25, 0.7, 0.25))
	match pose:
		Pose.SWING:
			var k := clampf(_pose_t / 0.18, 0.0, 1.0)
			_sword_arm.rotation.z = lerpf(1.9, -1.5, k)
			_chain_arm.rotation.z = -0.3
			_body.rotation.y = lerpf(-0.3, 0.4, k)
			_slash.visible = k < 1.0 or _pose_t < 0.25
			_slash.scale = Vector3.ONE * (0.6 + k * 0.5)
		Pose.CHARGE:
			_sword_arm.rotation.z = 0.2
			_chain_arm.rotation.z = -1.2 - sin(_t * 30.0) * 0.1 * charge
			_body.scale = Vector3(1.0 + charge * 0.08, 1.0 - charge * 0.1, 1.0 + charge * 0.08)
			_charge_ring.visible = true
			_charge_ring.scale = Vector3.ONE * (0.6 + charge * 0.6)
			_charge_ring.rotation.y = _t * 8.0
			_ball.material_override = Kit.mat(Color(0.35, 1, 0.4), 0.5 + charge * 2.5)
			_body.position.x = randf_range(-0.02, 0.02) * charge
		Pose.ROLL:
			_body.rotation.z = -_pose_t * 18.0 * facing
			_body.position.y = 0.3
			_body.scale = Vector3(0.9, 0.75, 0.9)
		Pose.HURT:
			_body.rotation.z = 0.35 * facing
			_body.position.x = -0.15 * facing
			_sword_arm.rotation.z = 1.2
			_chain_arm.rotation.z = 0.8
		_:
			_body.scale = Vector3(1.0 + bob * 0.03, 1.0 - bob * 0.04, 1.0 + bob * 0.03)
			_body.position.y = absf(bob) * 0.04
			if cheer or pose == Pose.CHEER:
				_sword_arm.rotation.z = 1.4 + sin(_t * 6.0) * 0.25
				_chain_arm.rotation.z = -0.3
			else:
				_sword_arm.rotation.z = 0.5 + sin(_t * 2.0) * 0.08
				_chain_arm.rotation.z = sin(_t * 2.0 + 1.0) * 0.08
	if pose != Pose.CHARGE and pose != Pose.ROLL and pose != Pose.IDLE and pose != Pose.CHEER:
		_body.scale = Vector3.ONE
	if _aura:
		_aura.scale = Vector3.ONE * (1.0 + sin(_t * 5.0) * 0.06)
		_rays.rotation.z = _t * 0.8
