extends "res://scripts/view3d/stage_view.gd"
## 1장 '등장'의 3D 화면이에요 (제안: 3D 화면).
## 규칙과 터치는 stage1.gd가 화면 좌표로 그대로 계산하고,
## 여기서는 매 프레임 그 자리에 맞춰 3D 모양(드래곤, 백성, 불, 줄기, 대피소)을 놓아요.
## 장소는 원작 밤 장면 그대로예요: 밤하늘, 초승달, 검은 도로, 둥근 돔 대피소, 보라색 가시 드래곤.

const Kit := preload("res://scripts/view3d/kit3d.gd")
const WorldBG := preload("res://scenes/chapter1/world_background.gd")
const Dragon3D := preload("res://scripts/view3d/dragon_3d.gd")

const PURPLE := Color(0.5, 0.2, 0.78)        # 박력 (제안): 원작 크레용처럼 진한 보라
const PURPLE_DARK := Color(0.3, 0.1, 0.5)
const CITIZEN_HEAD := Color(0.6, 0.36, 0.16)
const CITIZEN_BODY := Color(0.95, 0.9, 0.8)

var stage: Node2D

var _z_road_top := 0.0
var _z_dragon := 0.0
var _k_dragon := 0.01
var _citizens := {}
var _fires := {}
var _beams := {}
var _dome_heads: Node3D
var _shown_rescued := -1
var _t := 0.0

# 드래곤 부품
var _neck: Array[MeshInstance3D] = []
var _head: Node3D
var _nose: MeshInstance3D
var _nose_light: OmniLight3D
var _nose_ring: MeshInstance3D
var _jaw: Node3D
var _head_mouth: Node3D
var _say: Label3D


func _ready() -> void:
	setup(Color(0.02, 0.02, 0.1), Color(0.25, 0.08, 0.2), Color(0.45, 0.4, 0.75), Color(0.7, 0.75, 1.0), 0.7)
	_z_road_top = ground(Vector2(640, WorldBG.ROAD_TOP)).z
	_z_dragon = _z_road_top - 0.4
	_k_dragon = px_on_wall(_z_dragon)
	_build_town()
	_build_dome()
	_build_dragon()


# ------------------------------------------------------------------ 마을

func _build_town() -> void:
	var zt := _z_road_top
	var zb := ground(Vector2(640, WorldBG.ROAD_BOTTOM)).z
	var zfar := zt - 60.0
	# 땅 (풀밭)
	Kit.box(self, Vector3(200, 1, 200), Color(0.16, 0.22, 0.2), Vector3(0, -0.5, zt - 40)).material_override = Kit.matte(Color(0.16, 0.22, 0.2))
	# 도로 (원작: 검게 칠한 도로)
	Kit.box(self, Vector3(120, 0.04, zb - zt), Color(0.1, 0.09, 0.14), Vector3(0, 0.02, (zt + zb) * 0.5)).material_override = Kit.matte(Color(0.1, 0.09, 0.14))
	Kit.box(self, Vector3(120, 0.12, 0.5), Color(0.62, 0.58, 0.72), Vector3(0, 0.06, zt - 0.25))
	Kit.box(self, Vector3(120, 0.12, 0.5), Color(0.62, 0.58, 0.72), Vector3(0, 0.06, zb + 0.25))
	# 노란 차선
	var zm := ground(Vector2(640, (WorldBG.ROAD_TOP + WorldBG.ROAD_BOTTOM) * 0.5)).z
	var x := -30.0
	while x < 30.0:
		Kit.box(self, Vector3(1.1, 0.05, 0.22), Color(1, 0.85, 0.4), Vector3(x, 0.05, zm), 0.2)
		x += 2.2
	# 집들 (제안: 임시 배경, 창문에 불빛)
	var walls := [Color(0.42, 0.36, 0.5), Color(0.5, 0.38, 0.42), Color(0.38, 0.36, 0.52)]
	var roofs := [Color(0.65, 0.15, 0.18), Color(0.3, 0.2, 0.5), Color(0.75, 0.35, 0.12)]
	var px := px_on_ground(Vector2(640, WorldBG.ROAD_TOP))
	for i in 7:
		var cx := ground(Vector2(380.0 + i * 120.0 + 40.0, WorldBG.ROAD_TOP)).x
		var w := 80.0 * px * 1.25
		var h := (60.0 + (i % 3) * 22.0) * px * 1.3
		var z := zt - 1.3 - (i % 2) * 0.7
		var house := Node3D.new()
		house.position = Vector3(cx, 0, z)
		add_child(house)
		Kit.box(house, Vector3(w, h, w * 0.9), walls[i % 3], Vector3(0, h * 0.5, 0))
		var roof := Kit.prism(house, Vector3(w * 1.2, w * 0.55, w * 1.0), roofs[i % 3], Vector3(0, h + w * 0.27, 0))
		roof.rotation.y = 0.0
		Kit.box(house, Vector3(w * 0.32, w * 0.3, 0.04), Color(1, 0.86, 0.5), Vector3(-w * 0.18, h * 0.6, w * 0.46), 1.4)
		Kit.box(house, Vector3(w * 0.24, h * 0.42, 0.04), Color(0.55, 0.38, 0.3), Vector3(w * 0.22, h * 0.21, w * 0.46))
	# 가로등 불빛
	for i in 4:
		var lx := -9.0 + i * 6.0
		Kit.cylinder(self, 0.05, 0.06, 2.2, Color(0.45, 0.42, 0.55), Vector3(lx, 1.1, zt - 0.4))
		Kit.sphere(self, 0.16, Color(1, 0.9, 0.6), Vector3(lx, 2.25, zt - 0.4), Vector3.ONE, 1.2)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1, 0.85, 0.6)
		lamp.light_energy = 0.8
		lamp.omni_range = 4.0
		lamp.position = Vector3(lx, 2.0, zt - 0.2)
		add_child(lamp)
	# 하늘: 집 뒤에 세운 밤하늘 벽, 초승달과 별
	var zsky := zt - 7.0
	var top_c := on_wall(Vector2(640, -200), zsky)
	var bottom_c := on_wall(Vector2(640, WorldBG.ROAD_TOP), zsky)
	var sky_h := top_c.y - bottom_c.y
	for i in 6:
		var y0 := bottom_c.y + sky_h * i / 6.0
		var col := Color(0.3, 0.1, 0.22).lerp(Color(0.02, 0.02, 0.1), i / 5.0)
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(80, sky_h / 6.0 + 0.05, 0.1)
		band.mesh = bm
		band.material_override = Kit.mat(col, 0.0, 1.0, true)
		band.position = Vector3(0, y0 + sky_h / 12.0, zsky - 0.2)
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(band)
	var moon_pos := on_wall(Vector2(1090, 150), zsky)
	var ksky := px_on_wall(zsky)
	Kit.sphere(self, 44.0 * ksky, Color(1, 0.95, 0.65), moon_pos, Vector3.ONE, 1.6)
	# 초승달: 하늘과 같은 색 공으로 달을 살짝 가려요
	var band_i := clampi(int((moon_pos.y + 14 * ksky - bottom_c.y) / sky_h * 6.0), 0, 5)
	var mask_col := Color(0.3, 0.1, 0.22).lerp(Color(0.02, 0.02, 0.1), band_i / 5.0)
	Kit.sphere(self, 42.0 * ksky, mask_col, moon_pos + Vector3(20 * ksky, 14 * ksky, 30 * ksky)).material_override = Kit.mat(mask_col, 0.0, 1.0, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 46:
		var sp := Vector2(rng.randf_range(0, 1280), rng.randf_range(10, 300))
		Kit.sphere(self, rng.randf_range(1.6, 3.4) * ksky, Color(1, 1, 0.85), on_wall(sp, zsky) + Vector3(0, 0, 0.1), Vector3.ONE, 1.5)


func _build_dome() -> void:
	var c := ground(WorldBG.DOME_CENTER)
	var r := ground(WorldBG.DOME_CENTER + Vector2(WorldBG.DOME_RADIUS, 0)).x - c.x
	var dome := Node3D.new()
	dome.position = c
	add_child(dome)
	Kit.sphere(dome, r, Color(1.0, 0.78, 0.92, 0.62), Vector3.ZERO, Vector3(1, 0.85, 1))
	Kit.torus(dome, r * 0.97, r * 1.07, Color(1, 0.8, 0.9), Vector3(0, 0.05, 0))
	Kit.box(dome, Vector3(r * 0.4, r * 0.5, 0.1), Color(1, 0.85, 0.45), Vector3(0, r * 0.25, r * 0.86), 0.6)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.85, 0.6)
	light.light_energy = 1.4
	light.omni_range = r * 2.5
	light.position = Vector3(0, r * 0.6, 0)
	dome.add_child(light)
	_dome_heads = Node3D.new()
	dome.add_child(_dome_heads)
	var l := Kit.label(dome, "대피소", Vector3(0, r * 1.05, 0), 44, Color(1, 0.95, 0.75))
	l.no_depth_test = false


func _update_dome_heads() -> void:
	var n: int = stage.rules.rescued
	if n == _shown_rescued:
		return
	_shown_rescued = n
	for ch in _dome_heads.get_children():
		ch.queue_free()
	var r := 0.32
	for i in n:
		var row := i / 5
		var col := i % 5
		var p := Vector3(-1.1 + col * 0.55, 0.3 + row * 0.42, 0.4 - row * 0.4)
		Kit.sphere(_dome_heads, r * 0.55, CITIZEN_HEAD, p)


# ------------------------------------------------------------------ 드래곤

func _build_dragon() -> void:
	var k := _k_dragon
	for i in 17:
		var s := Kit.sphere(self, 33.0 * k, PURPLE if i % 3 != 0 else PURPLE_DARK)
		_neck.append(s)
	# 무서운 가시 머리 (원작 그림: 가시 머리, 날카로운 이빨의 큰 입). 코끝이 2D 코 자리에 와요.
	var parts := Dragon3D.build_head(self, 36.0 * k, PURPLE, PURPLE_DARK, PURPLE_DARK)
	_head = parts.root
	_jaw = parts.jaw
	_head_mouth = parts.mouth
	# 코 (입을 벌리면 빛나요)
	_nose = Kit.sphere(self, 15.0 * k, PURPLE_DARK)
	_nose_light = OmniLight3D.new()
	_nose_light.light_color = Color(1, 1, 0.5)
	_nose_light.omni_range = 3.0
	_nose_light.light_energy = 0.0
	add_child(_nose_light)
	_nose_ring = Kit.torus(self, 30.0 * k, 37.0 * k, Color(1, 1, 0.55), Vector3.ZERO, 2.0)
	_nose_ring.rotation_degrees.x = 90.0
	_say = Kit.label(self, "", Vector3.ZERO, 96, Color.WHITE)


func _basis_along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.BACK).normalized()
	if x.length() < 0.01:
		x = Vector3.RIGHT
	return Basis(x, y, x.cross(y))


func _wall(p: Vector2) -> Vector3:
	return on_wall(p, _z_dragon)


func _sync_dragon() -> void:
	var d: Node2D = stage.dragon
	var idle: bool = d.state == d.State.IDLE
	var sway := Vector2(sin(d._t * 1.3) * 6.0, cos(d._t * 1.1) * 4.0) if idle else Vector2.ZERO
	var h: Vector2 = d.head + sway
	var base: Vector2 = d.NECK_BASE
	var ctrl := Vector2(h.x * 0.25, h.y + 80)
	for i in _neck.size():
		var t := i / float(_neck.size() - 1)
		var p := base.lerp(ctrl, t).lerp(ctrl.lerp(h, t), t)
		_neck[i].position = _wall(d.to_global(p)) + Vector3(0, 0, -0.05 * (1.0 - t))
	_head.position = _wall(d.to_global(h)) + Vector3(0, 0, 0.1)
	_head.rotation.y = -0.45
	var open: bool = d.state == d.State.MOUTH_OPEN
	var k := _k_dragon
	_jaw.rotation.z = -0.8 if open else -0.12
	_head_mouth.visible = open
	var nose_p: Vector3 = _wall(d.nose_global()) + Vector3(0, 0, 0.35)
	_nose.position = nose_p
	_nose_light.position = nose_p + Vector3(0, 0, 0.4)
	if open:
		var pulse := 0.5 + 0.5 * sin(_t * 18.0)
		_nose.material_override = Kit.mat(Color(1, 0.95, 0.35), 2.0 + pulse * 2.0)
		_nose_light.light_energy = 2.0 + pulse
		_nose_ring.visible = true
		_nose_ring.position = nose_p
		var ratio := clampf(d.window_left / 1.5, 0.0, 1.0)
		_nose_ring.scale = Vector3.ONE * (0.6 + ratio * 0.6)
		_say.text = "톡!"
		_say.modulate = Color(1, 1, 0.6)
		_say.position = nose_p + Vector3(0, 70.0 * k, 0.3)
	else:
		_nose.material_override = Kit.mat(PURPLE_DARK)
		_nose_light.light_energy = 0.0
		_nose_ring.visible = false
		_say.text = "에취!" if d.state == d.State.SNEEZE else ""
		_say.modulate = Color.WHITE
		_say.position = _head.position + Vector3(80 * k, 80 * k, 0.5)


# ------------------------------------------------------------------ 백성

func _make_citizen() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	Kit.shadow(root, 0.32)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	Kit.capsule(body, 0.16, 0.5, CITIZEN_BODY, Vector3(0, 0.38, 0))
	for sx in [-0.09, 0.09]:
		Kit.sphere(body, 0.07, CITIZEN_HEAD, Vector3(sx, 0.08, 0.04), Vector3(1, 0.7, 1.3))
	var arms := Node3D.new()
	arms.name = "Arms"
	arms.position = Vector3(0, 0.5, 0)
	body.add_child(arms)
	for sx in [-1.0, 1.0]:
		Kit.sphere(arms, 0.065, CITIZEN_BODY, Vector3(sx * 0.2, -0.06, 0.02))
	var head := Node3D.new()
	head.position = Vector3(0, 0.86, 0)
	body.add_child(head)
	Kit.sphere(head, 0.24, CITIZEN_HEAD)
	Kit.eye(head, Vector3(-0.08, 0.02, 0.2), 0.065)
	Kit.eye(head, Vector3(0.08, 0.02, 0.2), 0.065)
	Kit.blush(head, Vector3(-0.15, -0.07, 0.18), 0.045)
	Kit.blush(head, Vector3(0.15, -0.07, 0.18), 0.045)
	var stars := Node3D.new()
	stars.name = "Dizzy"
	stars.position = Vector3(0, 1.2, 0)
	body.add_child(stars)
	for i in 3:
		var a := TAU * i / 3.0
		Kit.sphere(stars, 0.06, Color(1, 0.9, 0.3), Vector3(cos(a) * 0.25, 0, sin(a) * 0.25), Vector3.ONE, 1.5)
	return root


func _sync_citizens() -> void:
	var seen := {}
	for c in stage.citizens_root.get_children():
		var id: int = c.get_instance_id()
		seen[id] = true
		if not _citizens.has(id):
			_citizens[id] = _make_citizen()
		var m: Node3D = _citizens[id]
		var feet: Vector2 = c.position
		var px := px_on_ground(feet)
		m.position = ground(feet)
		var s: float = 72.0 * px * c.scale.x
		m.scale = Vector3.ONE * s
		var body: Node3D = m.get_node("Body")
		var hop := absf(sin(c._bob)) * (0.25 if c.dragging else 0.06)
		body.position.y = hop + (0.35 if c.dragging else 0.0)
		body.rotation.z = sin(c._bob) * (0.2 if c.dragging else 0.05)
		var arms: Node3D = body.get_node("Arms")
		arms.position.y = 0.72 if c.dragging else 0.5
		var dz: Node3D = body.get_node("Dizzy")
		dz.visible = c.dizzy > 0.0
		dz.rotation.y = _t * 6.0
		m.visible = c.modulate.a > 0.05
	for id in _citizens.keys():
		if not seen.has(id):
			_citizens[id].queue_free()
			_citizens.erase(id)


# ------------------------------------------------------------------ 불

func _make_fire() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	Kit.sphere(root, 0.5, Color(0.35, 0.22, 0.2), Vector3(0, 0.02, 0), Vector3(1, 0.2, 1))
	var flame := Node3D.new()
	flame.name = "Flame"
	root.add_child(flame)
	Kit.sphere(flame, 0.42, Color(1, 0.42, 0.15), Vector3(0, 0.36, 0), Vector3(1, 1.0, 1), 0.9)
	Kit.cylinder(flame, 0.0, 0.36, 0.7, Color(1, 0.42, 0.15), Vector3(0, 0.8, 0), 0.9)
	Kit.sphere(flame, 0.26, Color(1, 0.85, 0.35), Vector3(0, 0.34, 0.18), Vector3(1, 1.2, 1), 1.2)
	# 심술 난 불꽃 얼굴 (제안)
	for sx in [-0.1, 0.1]:
		Kit.sphere(flame, 0.05, Color(0.4, 0.1, 0.05), Vector3(sx, 0.42, 0.43))
	var l := OmniLight3D.new()
	l.name = "Light"
	l.light_color = Color(1, 0.55, 0.25)
	l.light_energy = 1.6
	l.omni_range = 2.6
	l.position = Vector3(0, 0.8, 0.3)
	root.add_child(l)
	return root


func _sync_fires() -> void:
	var seen := {}
	for f in stage.fires_root.get_children():
		var id: int = f.get_instance_id()
		seen[id] = true
		if not _fires.has(id):
			_fires[id] = _make_fire()
		var m: Node3D = _fires[id]
		m.position = ground(f.position)
		var px := px_on_ground(f.position)
		var warn: float = clampf((f.age - 3.5) / 1.5, 0.0, 1.0)
		var s: float = 68.0 * px * f.scale.x * (1.0 + warn * 0.25)
		m.scale = Vector3.ONE * s
		var flame: Node3D = m.get_node("Flame")
		flame.scale = Vector3(1.0, 1.0 + sin(f._flicker) * 0.08, 1.0)
		var light: OmniLight3D = m.get_node("Light")
		light.light_energy = 0.0 if f.out else 1.6 + sin(f._flicker * 1.3) * 0.3
		flame.visible = not f.out or f.scale.x > 0.15
	for id in _fires.keys():
		if not seen.has(id):
			_fires[id].queue_free()
			_fires.erase(id)


# ------------------------------------------------------------------ 줄기

func _make_beam() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var dots := Node3D.new()
	dots.name = "Dots"
	root.add_child(dots)
	for i in 14:
		Kit.sphere(dots, 0.09, Color(1, 0.45, 0.9), Vector3.ZERO, Vector3.ONE, 2.0)
	var ring := Kit.torus(root, 0.45, 0.6, Color(1, 0.45, 0.9), Vector3.ZERO, 2.0)
	ring.name = "Ring"
	var ring2 := Kit.torus(root, 0.45, 0.6, Color(1, 0.45, 0.9), Vector3.ZERO, 2.0)
	ring2.name = "Ring2"
	var glow := Kit.cylinder(root, 0.5, 0.5, 1.0, Color(0.62, 0.3, 0.95, 0.55), Vector3.ZERO, 0.8)
	glow.name = "Glow"
	var core := Kit.cylinder(root, 0.5, 0.5, 1.0, Color(0.88, 0.72, 1.0), Vector3.ZERO, 1.4)
	core.name = "Core"
	var splash := Kit.sphere(root, 0.5, Color(0.7, 0.4, 1.0), Vector3.ZERO, Vector3(1, 0.4, 1), 2.0)
	splash.name = "Splash"
	return root


func _sync_beams() -> void:
	var seen := {}
	var k := _k_dragon
	for b in stage.beams_root.get_children():
		var id: int = b.get_instance_id()
		seen[id] = true
		if not _beams.has(id):
			_beams[id] = _make_beam()
		var m: Node3D = _beams[id]
		var o: Vector3 = _wall(b.origin)
		var warn: bool = b.warning_left > 0.0
		var dots: Node3D = m.get_node("Dots")
		var ring: Node3D = m.get_node("Ring")
		var ring2: Node3D = m.get_node("Ring2")
		var glow: MeshInstance3D = m.get_node("Glow")
		var core: MeshInstance3D = m.get_node("Core")
		var splash: Node3D = m.get_node("Splash")
		dots.visible = warn
		ring.visible = warn
		ring2.visible = warn and b.sweep
		glow.visible = not warn
		core.visible = not warn
		splash.visible = not warn
		if warn:
			var blink := 0.75 + 0.25 * sin(_t * 16.0)
			var t1: Vector3 = ground(b.from_target)
			for i in dots.get_child_count():
				var dot: Node3D = dots.get_child(i)
				dot.position = o.lerp(t1, (i + 0.5) / dots.get_child_count())
				dot.scale = Vector3.ONE * blink
			ring.position = t1 + Vector3(0, 0.05, 0)
			ring.scale = Vector3.ONE * blink
			if b.sweep:
				ring2.position = ground(b.to_target) + Vector3(0, 0.05, 0)
				ring2.scale = Vector3.ONE * blink
		else:
			var end: Vector3 = ground(b.current_target())
			var w: float = b.WIDTH * px_on_ground(b.current_target())
			Kit.stretch_between(glow, o, end)
			_fatten(glow, w * 2.2)
			Kit.stretch_between(core, o, end)
			_fatten(core, w * 0.9)
			splash.position = end
			splash.scale = Vector3(w * 3.0, w * 1.2, w * 3.0) * (1.0 + 0.2 * sin(_t * 30.0))
	for id in _beams.keys():
		if not seen.has(id):
			_beams[id].queue_free()
			_beams.erase(id)


## 늘인 원기둥의 굵기만 바꿔요 (반지름 0.5짜리 원기둥 기준).
func _fatten(mi: Node3D, width: float) -> void:
	var b := mi.transform.basis
	mi.transform.basis = Basis(b.x.normalized() * width, b.y, b.z.normalized() * width)


# ------------------------------------------------------------------ 매 프레임

func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	if not stage:
		return
	_sync_dragon()
	_sync_citizens()
	_sync_fires()
	_sync_beams()
	_update_dome_heads()
