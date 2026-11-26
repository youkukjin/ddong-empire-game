extends "res://scripts/view3d/stage_view.gd"
## 8장 '평화'의 3D 화면이에요 (제안: 3D 화면).
## 1장의 밤 마을(원작: 밤, 초승달, 차선 있는 도로, 둥근 돔 대피소)이 다시 살아나요.
## 무너진 집은 기울고 연기가 나다가, 고치면 반듯해지고 창문에 불이 켜져요.
## 할 일을 마칠수록 밤하늘이 아침으로 밝아지고, 마지막에 해가 떠요.

const Kit := preload("res://scripts/view3d/kit3d.gd")
const Prince3D := preload("res://scripts/view3d/prince_3d.gd")
const Rules := preload("res://scenes/chapter8/stage8_rules.gd")

const NIGHT_TOP := Color(0.03, 0.03, 0.15)
const NIGHT_LOW := Color(0.3, 0.1, 0.25)
const DAY_TOP := Color(0.25, 0.55, 1.0)
const DAY_LOW := Color(1.0, 0.75, 0.45)

var stage: Node2D
var kind := "town"
var prince3d: Node3D
var _houses: Array = []      # {"node", "roof", "win", "smoke", "hp"}
var _embers: Array = []
var _sky_bands: Array[MeshInstance3D] = []
var _moon: Node3D
var _sun_ball: MeshInstance3D
var _stars: Node3D
var _dome_people: Node3D
var _drag_person: Node3D
var _shown_left := -1
var _tint := -1.0
var _t := 0.0


func _init() -> void:
	cam_height = 7.0
	cam_z = 12.0
	pitch_deg = 24.0
	fov_deg = 42.0


func _ready() -> void:
	setup(NIGHT_TOP, NIGHT_LOW, Color(0.5, 0.45, 0.75), Color(0.75, 0.75, 1.0), 0.7)
	var zh := ground(Vector2(640, Rules.HOUSE_Y)).z
	# 땅과 도로
	Kit.box(self, Vector3(200, 1, 200), Color(0.25, 0.3, 0.28), Vector3(0, -0.5, zh - 40)).material_override = Kit.matte(Color(0.25, 0.3, 0.28))
	var zr := ground(Vector2(640, 600)).z
	Kit.box(self, Vector3(120, 0.04, 3.2), Color(0.16, 0.14, 0.2), Vector3(0, 0.02, zr)).material_override = Kit.matte(Color(0.16, 0.14, 0.2))
	var x := -30.0
	while x < 30.0:
		Kit.box(self, Vector3(1.1, 0.05, 0.2), Color(1, 0.85, 0.3), Vector3(x, 0.05, zr), 0.4, false)
		x += 2.2
	# 하늘 벽 (밤 → 아침으로 색이 바뀌어요)
	var zsky := zh - 9.0
	var top_c := on_wall(Vector2(640, -300), zsky)
	var bottom_c := on_wall(Vector2(640, Rules.HOUSE_Y), zsky)
	var sky_h := top_c.y - bottom_c.y + 2.0
	for i in 6:
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(120, sky_h / 6.0 + 0.05, 0.1)
		band.mesh = bm
		band.position = Vector3(0, bottom_c.y - 1.0 + sky_h * (i + 0.5) / 6.0, zsky - 0.2)
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(band)
		_sky_bands.append(band)
	var ksky := px_on_wall(zsky)
	_stars = Node3D.new()
	add_child(_stars)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 40:
		Kit.sphere(_stars, rng.randf_range(1.5, 3.2) * ksky, Color(1, 1, 0.85), on_wall(Vector2(rng.randf_range(0, 1280), rng.randf_range(10, 260)), zsky + 0.1), Vector3.ONE, 2.0, false)
	_moon = Node3D.new()
	_moon.position = on_wall(Vector2(1060, 130), zsky + 0.2)
	add_child(_moon)
	Kit.sphere(_moon, 44 * ksky, Color(1, 0.95, 0.6), Vector3.ZERO, Vector3.ONE, 1.8, false)
	_sun_ball = Kit.sphere(self, 56 * ksky, Color(1, 0.7, 0.2), on_wall(Vector2(1100, 120), zsky + 0.3), Vector3.ONE, 2.5, false)
	# 집 다섯 채
	for h in stage.rules.houses:
		_houses.append(_make_house(h))
	# 돔 대피소 (1장)
	var c := ground(Rules.DOME_CENTER)
	var r := ground(Rules.DOME_CENTER + Vector2(Rules.DOME_RADIUS, 0)).x - c.x
	var dome := Node3D.new()
	dome.position = c
	add_child(dome)
	Kit.sphere(dome, r, Color(0.95, 0.75, 0.95, 0.5), Vector3.ZERO, Vector3(1, 0.8, 1))
	Kit.torus(dome, r * 0.97, r * 1.07, Color(0.85, 0.65, 0.9), Vector3(0, 0.05, 0))
	Kit.light(dome, Vector3(0, r * 0.5, 0), Color(1, 0.85, 0.6), 1.2, r * 2.5)
	_dome_people = Node3D.new()
	add_child(_dome_people)
	_drag_person = _make_person()
	_drag_person.visible = false
	# 똥의 신이 된 왕자
	prince3d = Prince3D.new()
	add_child(prince3d)
	prince3d.god = true
	_set_tint(0.0)


func _make_house(h: Dictionary) -> Dictionary:
	var rect := Rules.house_rect(h)
	var base := ground(Vector2(h.x, Rules.HOUSE_Y))
	var px := px_on_ground(Vector2(h.x, Rules.HOUSE_Y))
	var w := rect.size.x * px
	var ht := rect.size.y * px * 1.1
	var n := Node3D.new()
	n.position = base
	add_child(n)
	var walls := Kit.box(n, Vector3(w, ht, w * 0.8), Color(0.55, 0.45, 0.5), Vector3(0, ht * 0.5, 0))
	var roof := Kit.prism(n, Vector3(w * 1.25, w * 0.6, w * 0.95), Color(0.45, 0.2, 0.25), Vector3(0, ht + w * 0.3, 0))
	Kit.box(n, Vector3(w * 0.26, ht * 0.45, 0.05), Color(0.35, 0.2, 0.12), Vector3(0, ht * 0.22, w * 0.41))
	var win := Kit.box(n, Vector3(w * 0.26, w * 0.22, 0.05), Color(0.12, 0.1, 0.15), Vector3(-w * 0.28, ht * 0.65, w * 0.41))
	# 무너진 집: 판자를 덧댄 자국 (고치면 사라져요)
	var smoke := Node3D.new()
	n.add_child(smoke)
	for i in 2:
		var plank := Kit.box(smoke, Vector3(w * 0.55, w * 0.08, 0.04), Color(0.45, 0.3, 0.15), Vector3(w * 0.15, ht * (0.35 + i * 0.25), w * 0.42))
		plank.rotation.z = 0.5 - i
	return {"node": n, "walls": walls, "roof": roof, "win": win, "smoke": smoke, "hp": -1, "w": w, "ht": ht, "data": h}


func _make_person() -> Node3D:
	var p := Node3D.new()
	add_child(p)
	Kit.capsule(p, 0.12, 0.5, Color(0.98, 0.93, 0.84), Vector3(0, 0.3, 0))
	Kit.sphere(p, 0.2, Color(0.62, 0.38, 0.18), Vector3(0, 0.72, 0))
	for sx in [-0.07, 0.07]:
		Kit.sphere(p, 0.04, Color(0.1, 0.05, 0.05), Vector3(sx, 0.75, 0.18), Vector3.ONE, 0.0, false)
	return p


func _set_tint(t: float) -> void:
	if absf(t - _tint) < 0.001:
		return
	_tint = t
	for i in _sky_bands.size():
		var f := i / float(_sky_bands.size() - 1)
		var col := NIGHT_LOW.lerp(NIGHT_TOP, f).lerp(DAY_LOW.lerp(DAY_TOP, f), t)
		_sky_bands[i].material_override = Kit.mat(col, 0.0, 1.0, true)
	env.ambient_light_energy = lerpf(0.45, 0.9, t)
	env.ambient_light_color = Color(0.5, 0.45, 0.75).lerp(Color(1, 0.9, 0.8), t)
	sun.light_energy = lerpf(0.6, 1.4, t)
	sun.light_color = Color(0.7, 0.72, 1.0).lerp(Color(1, 0.85, 0.6), t)
	_stars.visible = t < 0.5
	_moon.visible = t < 0.5
	_sun_ball.visible = t >= 0.5
	_sun_ball.scale = Vector3.ONE * clampf((t - 0.5) * 2.0, 0.05, 1.0)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	if not stage:
		return
	var rules = stage.rules
	_set_tint(stage.backdrop.tint)
	for hd in _houses:
		var h: Dictionary = hd.data
		if hd.hp != h.hp:
			var was: int = hd.hp
			hd.hp = h.hp
			var fixed: bool = h.hp <= 0
			var dmg := float(h.hp) / Rules.HOUSE_TAPS
			hd.walls.material_override = Kit.mat(Color(1.0, 0.82, 0.6) if fixed else Color(0.55, 0.45, 0.5).lerp(Color(0.8, 0.65, 0.6), 1.0 - dmg))
			hd.roof.material_override = Kit.mat(Color(0.9, 0.2, 0.25) if fixed else Color(0.45, 0.2, 0.25))
			hd.roof.rotation.z = 0.0 if fixed else 0.18 * dmg
			hd.roof.position.x = 0.0 if fixed else hd.w * 0.12 * dmg
			hd.walls.rotation.z = 0.0 if fixed else -0.05 * dmg
			hd.win.material_override = Kit.mat(Color(1, 0.85, 0.4), 2.0) if fixed else Kit.mat(Color(0.12, 0.1, 0.15))
			hd.smoke.visible = not fixed
			if was >= 0:
				burst(hd.node.position + Vector3(0, hd.ht * 0.6, hd.w * 0.5), Color(1, 0.85, 0.4) if fixed else Color(0.7, 0.55, 0.4), 12 if fixed else 6, 0.7)
	# 불씨
	while _embers.size() < rules.embers.size():
		var e := Node3D.new()
		add_child(e)
		for j in 3:
			Kit.spike(e, 0.22 - j * 0.04, 0.7 - j * 0.15, Color(1, 0.3 + j * 0.25, 0.05), Vector3((j - 1) * 0.12, 0.0, j * 0.05), Vector3((j - 1) * 0.25, 1, 0), false).material_override = Kit.mat(Color(1, 0.3 + j * 0.25, 0.05), 2.5)
		Kit.light(e, Vector3(0, 0.6, 0.3), Color(1, 0.5, 0.2), 1.2, 2.0)
		var ash := Kit.sphere(e, 0.25, Color(0.2, 0.2, 0.2), Vector3(0, 0.03, 0), Vector3(1, 0.2, 1), 0.0, false)
		ash.name = "Ash"
		_embers.append({"node": e, "out": false})
	for i in rules.embers.size():
		var ed: Dictionary = rules.embers[i]
		var m: Dictionary = _embers[i]
		var node: Node3D = m.node
		node.position = ground(ed.pos)
		var s := 26.0 * px_on_ground(ed.pos) / 0.3 * (0.85 + 0.15 * sin(_t * 10.0 + ed.pos.x))
		node.scale = Vector3.ONE * s
		if ed.out != m.out:
			m.out = ed.out
			for c in node.get_children():
				c.visible = c.name == "Ash" if ed.out else true
			burst(node.position + Vector3(0, 0.3, 0), Color(0.6, 0.85, 1.0), 10, 0.6)
	# 돔 안 백성
	if rules.citizens_left != _shown_left:
		_shown_left = rules.citizens_left
		for c in _dome_people.get_children():
			c.queue_free()
		for i in rules.citizens_left:
			var p := Rules.DOME_CENTER + Vector2(-80 + (i % 4) * 50, -20 - (i / 4) * 50)
			var person := _make_person()
			remove_child(person)
			_dome_people.add_child(person)
			person.position = ground(p)
			person.scale = Vector3.ONE * (60.0 * px_on_ground(p) / 0.9)
	var drag: Dictionary = stage._drag
	_drag_person.visible = not drag.is_empty() and drag.kind == "citizen"
	if _drag_person.visible:
		_drag_person.position = ground(drag.pos) + Vector3(0, 0.3 + absf(sin(_t * 10.0)) * 0.15, 0)
		_drag_person.scale = Vector3.ONE * (60.0 * px_on_ground(drag.pos) / 0.9)
	# 왕자
	var pr: Node2D = stage.prince
	prince3d.sync_from(pr)
	prince3d.god = true
	prince3d.position = ground(pr.position)
	prince3d.scale = Vector3.ONE * (130.0 * 0.8 * px_on_ground(pr.position) / 1.75)
