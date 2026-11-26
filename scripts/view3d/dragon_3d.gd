extends Node3D
## 3D 똥 드래곤 (제안: 3D 화면, 박력 있는 그림체).
## 원작 그림대로: 보라색 몸, 가시 머리, 날카로운 이빨의 큰 입, 긴 목.
## 6·7장 드래곤 머리 가시는 원작 6장 그림처럼 파란색이에요 (blue_spikes).
## 기본 도형으로 만든 임시 모델이에요. 발밑 가운데가 position, 1 단위 = 화면 100픽셀 크기로 만들어요.
## 앞(머리 쪽)은 +x 예요. facing = -1 이면 왼쪽을 봐요.

const Kit := preload("res://scripts/view3d/kit3d.gd")

const PURPLE := Color(0.5, 0.2, 0.78)
const PURPLE_DARK := Color(0.3, 0.1, 0.5)
const BELLY := Color(0.72, 0.5, 0.92)
const SPIKE_BLUE := Color(0.15, 0.3, 0.95)

var facing := 1.0
var blue_spikes := false
var mouth_open := 0.0          # 0~1
var chest_glow := false
var wings_up := false
var dizzy := false
var flash := 0.0               # 맞아서 하얗게 (초)
var angry := 0.0               # 공격 준비 중 0~1 (몸이 빨갛게 달아올라요)
var head_target := Vector3(1.3, 2.5, 0)   # 머리 자리 (몸 기준, +x 쪽)

var _t := 0.0
var _root: Node3D
var _body_parts: Array[MeshInstance3D] = []
var _neck: Array[MeshInstance3D] = []
var _head: Dictionary
var _chest: MeshInstance3D
var _chest_light: OmniLight3D
var _wings: Array[Node3D] = []
var _tail: Array[MeshInstance3D] = []
var _stars: Node3D


func _ready() -> void:
	_root = Node3D.new()
	add_child(_root)
	Kit.shadow(self, 1.5)
	# 몸통 (큰 배)
	_body_parts.append(Kit.sphere(_root, 1.0, PURPLE, Vector3(0, 1.0, 0), Vector3(1.25, 0.85, 0.85)))
	_chest = Kit.sphere(_root, 0.55, BELLY, Vector3(0.55, 0.95, 0.35), Vector3(0.8, 1.1, 0.7))
	_chest_light = Kit.light(_root, Vector3(1.1, 1.0, 1.0), Color(1, 0.8, 0.3), 0.0, 4.0)
	# 다리와 발톱
	for p in [Vector3(0.6, 0.35, 0.5), Vector3(-0.6, 0.35, 0.5), Vector3(0.6, 0.35, -0.5), Vector3(-0.6, 0.35, -0.5)]:
		_body_parts.append(Kit.sphere(_root, 0.36, PURPLE_DARK if p.z < 0 else PURPLE, p, Vector3(1, 1.1, 1)))
		for k in 3:
			Kit.spike(_root, 0.06, 0.22, Color(0.95, 0.92, 0.85), p + Vector3(0.22, -0.3, (k - 1) * 0.14), Vector3(1, -0.4, 0))
	# 등 가시
	for i in 6:
		var x := 0.7 - i * 0.32
		var y := 1.75 - absf(i - 1.5) * 0.08
		Kit.spike(_root, 0.14, 0.45 - i * 0.03, PURPLE_DARK, Vector3(x, y - 0.1, 0), Vector3(-0.3, 1, 0))
	# 꼬리 (가늘어지는 공 줄 + 끝 가시)
	for i in 8:
		var t := i / 7.0
		var s := Kit.sphere(_root, lerpf(0.42, 0.14, t), PURPLE if i % 2 == 0 else PURPLE_DARK)
		_tail.append(s)
	# 날개 (어두운 막)
	for side in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(-0.1, 1.6, side * 0.45)
		_root.add_child(w)
		for k in 3:
			var bone := Kit.cylinder(w, 0.03, 0.05, 1.6 - k * 0.3, PURPLE_DARK)
			bone.rotation.z = 0.5 + k * 0.45
			bone.position = Vector3(-sin(0.5 + k * 0.45) * (0.8 - k * 0.15), cos(0.5 + k * 0.45) * (0.8 - k * 0.15), 0)
		var mem := Kit.prism(w, Vector3(1.7, 1.3, 0.04), Color(0.35, 0.12, 0.45))
		mem.position = Vector3(-0.6, 0.55, 0)
		mem.rotation.z = 0.5
		w.scale = Vector3(1, 1, 1)
		_wings.append(w)
	# 목
	for i in 9:
		_neck.append(Kit.sphere(_root, 0.36 - i * 0.012, PURPLE if i % 3 else PURPLE_DARK))
	# 머리
	_head = build_head(_root, 0.62, PURPLE, PURPLE_DARK, SPIKE_BLUE if blue_spikes else PURPLE_DARK)
	# 어질어질 별 (쓰러졌을 때)
	_stars = Node3D.new()
	_root.add_child(_stars)
	for i in 4:
		var a := TAU * i / 4.0
		Kit.spike(_stars, 0.1, 0.2, Color(1, 0.9, 0.2), Vector3(cos(a) * 0.6, 0, sin(a) * 0.6), Vector3.UP)
	_stars.visible = false


## 무서운 드래곤 머리를 만들어요. 주둥이는 +x 쪽, 눈은 양쪽(±z)에 있어요.
## 돌려받는 것: root(머리), jaw(아래턱: rotation.z로 입을 벌려요), nose(코끝 자리), mouth(입속), eyes
static func build_head(parent: Node3D, r: float, col: Color, dark: Color, spike_col: Color) -> Dictionary:
	var head := Node3D.new()
	parent.add_child(head)
	Kit.sphere(head, r, col, Vector3.ZERO, Vector3(1.15, 0.95, 0.95))
	# 주둥이 (위턱)
	Kit.sphere(head, r * 0.75, col, Vector3(r * 0.95, -r * 0.12, 0), Vector3(1.25, 0.55, 0.75))
	# 위 이빨: 날카롭게 아래로
	for i in 5:
		var x := r * (0.35 + i * 0.3)
		for zs in [-1.0, 1.0]:
			Kit.spike(head, r * 0.09, r * 0.32, Color(1, 0.98, 0.9), Vector3(x, -r * 0.38, zs * r * 0.34 * (1.0 - i * 0.12)), Vector3.DOWN)
	# 콧구멍
	for zs in [-1.0, 1.0]:
		Kit.sphere(head, r * 0.09, Color(0.12, 0.02, 0.1), Vector3(r * 1.75, -r * 0.02, zs * r * 0.2), Vector3.ONE, 0.0, false)
	var nose := Node3D.new()
	nose.position = Vector3(r * 1.85, -r * 0.05, 0)
	head.add_child(nose)
	# 입속 (벌리면 보여요)
	var mouth := Kit.sphere(head, r * 0.6, Color(0.6, 0.05, 0.12), Vector3(r * 0.85, -r * 0.45, 0), Vector3(1.4, 0.5, 0.7), 0.6, false)
	# 아래턱
	var jaw := Node3D.new()
	jaw.position = Vector3(-r * 0.1, -r * 0.4, 0)
	head.add_child(jaw)
	Kit.sphere(jaw, r * 0.7, dark, Vector3(r * 0.95, -r * 0.12, 0), Vector3(1.3, 0.38, 0.68))
	for i in 4:
		var x := r * (0.55 + i * 0.3)
		for zs in [-1.0, 1.0]:
			Kit.spike(jaw, r * 0.08, r * 0.28, Color(1, 0.98, 0.9), Vector3(x, r * 0.08, zs * r * 0.3 * (1.0 - i * 0.12)), Vector3.UP)
	# 무서운 눈과 화난 눈썹 (양쪽)
	var eyes: Array = []
	for zs in [-1.0, 1.0]:
		var e := Kit.fierce_eye(head, Vector3(r * 0.45, r * 0.32, zs * r * 0.72), r * 0.26)
		e.rotation.y = -zs * 0.5
		eyes.append(e)
		var b := Kit.brow(head, Vector3(r * 0.45, r * 0.62, zs * r * 0.7), r * 0.7, -0.45, dark.darkened(0.5))
		b.rotation.y = -zs * 0.4
	# 가시 머리 (원작 그림): 뒤로 뻗은 큰 가시
	for i in 7:
		var a := 0.25 + i * 0.32
		var dir := Vector3(-sin(a) * 1.0, cos(a) * 0.9 + 0.3, 0).normalized()
		var len := r * (0.95 if i % 2 == 0 else 0.7)
		Kit.spike(head, r * 0.2, len, spike_col, dir * r * 0.75, dir)
	for zs in [-1.0, 1.0]:
		Kit.spike(head, r * 0.16, r * 0.8, spike_col, Vector3(-r * 0.3, r * 0.2, zs * r * 0.55), Vector3(-0.7, 0.5, zs * 0.6))
	return {"root": head, "jaw": jaw, "nose": nose, "mouth": mouth, "eyes": eyes}


func set_spike_color(blue: bool) -> void:
	blue_spikes = blue


func _process(delta: float) -> void:
	_t += delta
	if not _root:
		return
	flash = maxf(flash - delta, 0.0)
	_root.rotation.y = 0.0 if facing > 0.0 else PI
	var breathe := sin(_t * 2.2)
	_root.scale = Vector3(1.0 + breathe * 0.02, 1.0 - breathe * 0.02, 1.0)
	# 몸 색: 맞으면 하얗게, 공격 준비면 붉게
	var body_col := PURPLE.lerp(Color(0.9, 0.15, 0.25), angry * 0.55)
	if flash > 0.0:
		body_col = Color(1, 1, 1)
	for p in _body_parts:
		p.material_override = Kit.mat(body_col)
	for i in _neck.size():
		_neck[i].material_override = Kit.mat(body_col if i % 3 else PURPLE_DARK)
	_chest.material_override = Kit.mat(Color(1, 0.8, 0.25), 1.6 + sin(_t * 8.0) * 0.4) if chest_glow else Kit.mat(BELLY)
	_chest_light.light_energy = 2.5 if chest_glow else 0.0
	# 목과 머리
	var hb := Vector3(0.75, 1.45, 0)
	var ht := head_target + Vector3(sin(_t * 1.6) * 0.05, sin(_t * 2.0) * 0.08, 0)
	if dizzy:
		ht = Vector3(1.6, 0.7, 0)
	var ctrl := Vector3(hb.x + 0.1, (hb.y + ht.y) * 0.5 + 0.5, 0)
	for i in _neck.size():
		var t := (i + 1) / float(_neck.size() + 1)
		_neck[i].position = hb.lerp(ctrl, t).lerp(ctrl.lerp(ht, t), t)
	var head: Node3D = _head.root
	head.position = ht
	head.rotation.z = -0.15 + (0.25 if mouth_open > 0.3 else 0.0) - (0.5 if dizzy else 0.0)
	var jaw: Node3D = _head.jaw
	jaw.rotation.z = -0.75 * mouth_open
	(_head.mouth as Node3D).visible = mouth_open > 0.1
	# 꼬리 흔들기
	var tb := Vector3(-1.1, 0.9, 0)
	for i in _tail.size():
		var t := i / float(_tail.size() - 1)
		_tail[i].position = tb + Vector3(-t * 1.9, -t * 0.55 + sin(_t * 3.0 - t * 3.0) * 0.18 * t + t * t * 0.6, 0)
	# 날개
	for i in _wings.size():
		var w: Node3D = _wings[i]
		var flap := sin(_t * (9.0 if wings_up else 2.0)) * (0.35 if wings_up else 0.08)
		w.rotation.x = (1.0 if i == 0 else -1.0) * (0.35 + flap)
		w.rotation.z = -0.2 if wings_up else 0.25
		w.scale = Vector3.ONE * (1.25 if wings_up else 0.8)
	_stars.visible = dizzy
	if dizzy:
		_stars.position = ht + Vector3(0, 0.9, 0)
		_stars.rotation.y = _t * 5.0


func nose_global() -> Vector3:
	return (_head.nose as Node3D).global_position
