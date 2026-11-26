extends "res://scripts/view3d/side_view.gd"
## 5~7장 싸움의 3D 화면이에요 (제안: 3D 화면, 박력 있는 그림체).
## battle_rules.gd가 계산한 자리(화면 x)에 3D 똥 무사, 똥 대마왕, 똥 드래곤을 세워요.
## - 똥 무사: 투구 쓴 갈색 똥, 칼 (원작 그림의 무사들)
## - 똥 대마왕: 원작 그림처럼 빨간 초승달 뿔, 보라색 망토, 박쥐 날개. 몸은 지금 게임처럼 갈색 똥 (작가 확인 전)
## - 똥 드래곤: 보라색 가시 드래곤. 6·7장은 원작 6장 그림처럼 머리 가시가 파래요
## 빨간 경고 띠와 "!"는 battle_stage.gd가 2D로 위에 그려요.

const Dragon3D := preload("res://scripts/view3d/dragon_3d.gd")

const POOP := Color(0.45, 0.25, 0.1)
const POOP_DARK := Color(0.3, 0.15, 0.06)
const STEEL := Color(0.55, 0.58, 0.68)
const CAPE := Color(0.42, 0.12, 0.6)
const HORN_RED := Color(0.9, 0.08, 0.08)

var _enemies := {}       # id -> Node3D
var _beams: Array = []   # {"node", "life"}


func _build_extra() -> void:
	pass


# ------------------------------------------------------------------ 적 모양

func _make_warrior() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	Kit.shadow(n, 0.7)
	var turn := Node3D.new()
	turn.name = "Turn"
	n.add_child(turn)
	var body := Node3D.new()
	body.name = "Body"
	turn.add_child(body)
	for t in [[0.62, 0.32, 0.55], [0.48, 0.78, 0.6], [0.34, 1.12, 0.65]]:
		Kit.sphere(body, t[0], POOP, Vector3(0, t[1], 0), Vector3(1, t[2], 0.9))
	# 투구와 빨간 깃 (제안: 원작 무사 그림을 보고 임시로)
	Kit.sphere(body, 0.4, STEEL, Vector3(0, 1.32, 0), Vector3(1, 0.6, 1))
	Kit.cylinder(body, 0.44, 0.44, 0.08, STEEL.darkened(0.2), Vector3(0, 1.22, 0))
	Kit.spike(body, 0.12, 0.45, Color(0.85, 0.05, 0.1), Vector3(0, 1.5, 0), Vector3(-0.3, 1, 0))
	Kit.box(body, Vector3(0.08, 0.3, 0.06), STEEL.darkened(0.3), Vector3(0.0, 1.05, 0.42))
	# 화난 눈
	for sx in [-0.17, 0.17]:
		Kit.fierce_eye(body, Vector3(sx, 0.82, 0.5), 0.1, Color(1, 0.95, 0.8), Color(0.1, 0.02, 0.02))
		Kit.brow(body, Vector3(sx, 0.96, 0.55), 0.2, 0.45 if sx > 0 else -0.45)
	# 칼 팔
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.position = Vector3(0.5, 0.75, 0.15)
	body.add_child(arm)
	Kit.capsule(arm, 0.1, 0.36, POOP, Vector3(0.12, 0, 0)).rotation.z = PI / 2
	var blade := Kit.box(arm, Vector3(0.09, 1.2, 0.03), Color(0.85, 0.9, 1.0), Vector3(0.3, 0.65, 0))
	blade.material_override = Kit.metal(Color(0.85, 0.9, 1.0))
	Kit.box(arm, Vector3(0.32, 0.07, 0.1), Color(0.6, 0.45, 0.1), Vector3(0.3, 0.05, 0))
	n.set_meta("parts", [body])
	return n


func _make_demon() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	Kit.shadow(n, 1.0)
	var turn := Node3D.new()
	turn.name = "Turn"
	n.add_child(turn)
	var body := Node3D.new()
	body.name = "Body"
	turn.add_child(body)
	# 보라색 망토와 박쥐 날개 (원작 그림)
	var cape := Kit.prism(body, Vector3(2.0, 2.2, 0.15), CAPE, Vector3(0, 1.1, -0.55))
	cape.rotation.x = -0.1
	for sx in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(sx * 0.6, 1.7, -0.5)
		w.rotation.z = sx * -0.5
		body.add_child(w)
		for i in 3:
			var finger := Kit.spike(w, 0.05, 1.5 - i * 0.25, Color(0.2, 0.05, 0.2), Vector3.ZERO, Vector3(sx * (0.5 + i * 0.5), 1.0 - i * 0.3, 0))
			finger.name = "F%d" % i
		var mem := Kit.prism(w, Vector3(1.6, 1.2, 0.04), Color(0.35, 0.05, 0.25), Vector3(sx * 0.7, 0.4, 0))
		mem.rotation.z = sx * -0.6
	var parts: Array = []
	for t in [[0.95, 0.5, 0.55], [0.75, 1.2, 0.6], [0.55, 1.75, 0.66]]:
		parts.append(Kit.sphere(body, t[0], POOP, Vector3(0, t[1], 0), Vector3(1, t[2], 0.9)))
	# 망토 깃
	for sx in [-1.0, 1.0]:
		Kit.spike(body, 0.2, 0.6, CAPE, Vector3(sx * 0.6, 1.55, 0.1), Vector3(sx * 0.6, 1, 0.2))
	# 빨간 초승달 뿔 (원작 그림)
	for sx in [-1.0, 1.0]:
		var horn := Node3D.new()
		horn.position = Vector3(sx * 0.35, 2.05, 0)
		body.add_child(horn)
		for i in 5:
			var t := i / 4.0
			var a := t * 1.6
			Kit.sphere(horn, 0.17 * (1.0 - t * 0.75), HORN_RED, Vector3(sx * (sin(a) * 0.45), (1.0 - cos(a)) * 0.15 + t * 0.55, 0))
		Kit.spike(horn, 0.06, 0.25, HORN_RED, Vector3(sx * 0.45, 0.72, 0), Vector3(-sx * 0.6, 1, 0))
	# 빛나는 무서운 눈, 송곳니
	for sx in [-0.25, 0.25]:
		Kit.fierce_eye(body, Vector3(sx, 1.35, 0.62), 0.16, Color(1, 0.9, 0.2), Color(0.8, 0.0, 0.0))
		Kit.brow(body, Vector3(sx, 1.55, 0.66), 0.32, 0.5 if sx > 0 else -0.5)
	Kit.box(body, Vector3(0.6, 0.12, 0.05), Color(0.2, 0.02, 0.02), Vector3(0, 0.95, 0.7), 0.0, false)
	for sx in [-0.18, 0.18]:
		Kit.spike(body, 0.06, 0.2, Color(1, 0.98, 0.9), Vector3(sx, 0.98, 0.72), Vector3.DOWN)
	n.set_meta("parts", parts)
	return n


func _make_dragon(final: bool) -> Node3D:
	var d := Dragon3D.new()
	d.blue_spikes = true      # 원작 6장 그림: 파란 큰 가시
	d.set_meta("final", final)
	add_child(d)
	return d


# ------------------------------------------------------------------ 매 프레임

func _sync(delta: float) -> void:
	var s: Node2D = stage
	var battle = s.battle
	var seen := {}
	for e in battle.enemies:
		if e.state == "dead":
			continue
		seen[e.id] = true
		if not _enemies.has(e.id):
			match e.kind:
				"warrior":
					_enemies[e.id] = _make_warrior()
				"demon":
					_enemies[e.id] = _make_demon()
				_:
					_enemies[e.id] = _make_dragon(e.kind == "dragon_final")
		var n: Node3D = _enemies[e.id]
		var flash: bool = s._flash.has(e.id)
		var windup: bool = e.state == "windup"
		match e.kind:
			"warrior", "demon":
				_sync_poop_enemy(n, e, flash, windup)
			_:
				_sync_dragon(n, e, flash, windup)
	for id in _enemies.keys():
		if not seen.has(id):
			var n: Node3D = _enemies[id]
			burst(n.position + Vector3(0, 1.0, 0.5), Color(0.55, 0.3, 0.12), 22, 1.6)
			flash(Color(1, 0.9, 0.6), 0.45)
			n.queue_free()
			_enemies.erase(id)
	for b in _beams.duplicate():
		b.life -= delta
		var node: Node3D = b.node
		if b.life <= 0.0:
			node.queue_free()
			_beams.erase(b)


func _sync_poop_enemy(n: Node3D, e: Dictionary, flash: bool, windup: bool) -> void:
	var size_px := 130.0 if e.kind == "warrior" else 230.0
	var model_h := 1.6 if e.kind == "warrior" else 2.3
	n.position = at(Vector2(e.x, GROUND_Y), 0.0)
	n.scale = Vector3.ONE * (size_px * k / model_h)
	var turn: Node3D = n.get_node("Turn")
	turn.rotation.y = deg_to_rad(50.0 * e.facing)
	var body: Node3D = turn.get_node("Body")
	var tt := Time.get_ticks_msec() * 0.001
	var col := POOP
	if windup:
		col = POOP.lerp(Color(0.85, 0.1, 0.1), 0.45 + 0.2 * sin(tt * 20.0))
	if flash:
		col = Color(1, 1, 1)
	for p in n.get_meta("parts"):
		if p is MeshInstance3D:
			p.material_override = Kit.mat(col)
		else:
			for c in p.get_children():
				if c is MeshInstance3D and c.mesh is SphereMesh and (c.mesh as SphereMesh).radius > 0.3 and c.position.y < 1.2:
					c.material_override = Kit.mat(col)
	body.position.y = absf(sin(tt * 4.0 + e.id)) * 0.05
	body.rotation.z = 0.0
	if windup:
		body.rotation.z = -0.12 * e.facing
		body.position.x = randf_range(-0.03, 0.03)
	if e.kind == "warrior":
		var arm: Node3D = body.get_node("Arm")
		arm.rotation.z = 1.6 if windup else (-0.6 if e.state == "recover" else 0.3)
	elif e.state == "windup" and e.attack.get("type", "") == "slam_self":
		body.position.y = 0.4 * clampf(e.t / 0.8, 0.0, 1.0)


func _sync_dragon(d: Node3D, e: Dictionary, flash: bool, windup: bool) -> void:
	var x: float = e.target_x if e.airborne else e.x
	var lift := 0.0
	if e.airborne:
		lift = 260.0
	elif e.state == "down":
		lift = -20.0
	d.position = at(Vector2(x, GROUND_Y - lift), -0.4)
	d.scale = Vector3.ONE * (100.0 * px_on_wall(-0.4))
	d.facing = e.facing
	var beam: bool = windup and e.attack.get("type", "") == "beam"
	d.mouth_open = 1.0 if beam else (0.6 if windup else 0.3)
	d.angry = 1.0 if windup else 0.0
	d.chest_glow = e.kind == "dragon_final" or e.phase == 3
	d.wings_up = e.airborne or e.phase >= 2
	d.dizzy = e.state == "down"
	d.head_target = Vector3(1.8, 2.4, 0) if beam else Vector3(1.5, 2.7, 0)
	if flash:
		d.flash = 0.08


## 적의 공격이 나가는 순간 (보라색 광선, 착지 등)
func on_event(e: Dictionary) -> void:
	match e.type:
		"strike":
			var atk: Dictionary = e.attack
			var en: Dictionary = e.enemy
			if atk.type == "beam" and _enemies.has(en.id):
				_fire_beam(_enemies[en.id], en.target_x)
			elif atk.type == "slam_self" or atk.type == "charge":
				shake(0.12, 0.25)
				burst(at(Vector2(en.x, GROUND_Y), 0.3), Color(0.5, 0.35, 0.25), 12, 1.2)
		"land":
			shake(0.18, 0.35)
			burst(at(Vector2(e.enemy.x, GROUND_Y), 0.3), Color(0.45, 0.3, 0.3), 18, 1.5)


## 보라색 광선 (원작 그림: 보라색 광선 "콰앙")
func _fire_beam(d: Node3D, target_x: float) -> void:
	var from: Vector3 = d.nose_global()
	var to := at(Vector2(target_x, GROUND_Y), 0.0)
	var root := Node3D.new()
	add_child(root)
	var glow := Kit.cylinder(root, 0.5, 0.5, 1.0, Color(0.6, 0.15, 1.0, 0.55), Vector3.ZERO, 2.0)
	var core := Kit.cylinder(root, 0.5, 0.5, 1.0, Color(0.95, 0.8, 1.0), Vector3.ZERO, 3.0, false)
	var holder := Node3D.new()
	root.add_child(holder)
	Kit.stretch_between(glow, from, to)
	Kit.stretch_between(core, from, to)
	var bw := glow.transform.basis
	glow.transform.basis = Basis(bw.x.normalized() * 0.9, bw.y, bw.z.normalized() * 0.9)
	var bc := core.transform.basis
	core.transform.basis = Basis(bc.x.normalized() * 0.35, bc.y, bc.z.normalized() * 0.35)
	Kit.sphere(root, 0.9, Color(0.7, 0.3, 1.0), to, Vector3(1.4, 0.5, 1.4), 2.5, false)
	Kit.light(root, to + Vector3(0, 1, 1), Color(0.7, 0.3, 1), 4.0, 6.0)
	_beams.append({"node": root, "life": 0.5})
	flash(Color(0.75, 0.4, 1.0), 0.4)
	shake(0.16, 0.3)
	comic(Vector2(target_x, 330), "콰앙!", Color(0.85, 0.5, 1.0), 1.4)
	burst(to, Color(0.75, 0.35, 1.0), 16, 1.3)
