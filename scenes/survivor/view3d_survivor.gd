extends "res://scripts/view3d/stage_view.gd"
## 서바이버 3D 무대 (제안): 5장 성 안 마당을 위에서 비스듬히 내려다봐요.
## 카메라가 왕자를 따라가요. 마당 1픽셀 = 3D K 단위.
## 적은 많아서 MultiMesh로 한꺼번에 그려요 (휴대폰에서도 가볍게).

const Kit := preload("res://scripts/view3d/kit3d.gd")
const Prince3D := preload("res://scripts/view3d/prince_3d.gd")
const Rules := preload("res://scenes/survivor/survivor_rules.gd")

const K := 0.01
const CAM_DIST := 11.2
const POOP := Color(0.56, 0.33, 0.15)
const STEEL := Color(0.62, 0.66, 0.74)
const STONE := Color(0.4, 0.36, 0.4)
const CAPE := Color(0.42, 0.12, 0.62)
const HORN_RED := Color(0.95, 0.12, 0.1)
const MAX_INST := 160

var stage: Node2D
var prince3d: Node3D
var hero3 := Vector3.ZERO

# 적 그리기: 이름 -> MultiMeshInstance3D
var _mm := {}
var _bosses := {}               # 적 id -> Node3D
var _gems: MultiMeshInstance3D
var _balls: Array[Node3D] = []
var _flies: Array[Node3D] = []
var _bombs: Array[Node3D] = []
var _shots: MultiMeshInstance3D
var _boomers: MultiMeshInstance3D
var _trail_acc := 0.0
var _puddles: Array[MeshInstance3D] = []
var _cloud: MeshInstance3D
var _fx: Array = []             # {"node", "life", "max", "kind"}
var _swing_left := 0.0
var _ground: MeshInstance3D
var _t := 0.0


func _init() -> void:
	pitch_deg = 54.0   # 너무 위에서 보면 얼굴이 안 보여요 (2026-11-28 사용자)
	fov_deg = 40.0


func _ready() -> void:
	setup(Color(0.08, 0.03, 0.1), Color(0.4, 0.1, 0.12), Color(0.6, 0.55, 0.7), Color(1, 0.92, 0.85), 1.0)
	sun.rotation_degrees = Vector3(-60, -30, 0)
	sun.directional_shadow_max_distance = 30.0
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.06, 0.1)
	# 멀리 위쪽은 어둑한 안개로 (적이 갑자기 나타나 보이지 않게)
	env.fog_enabled = true
	env.fog_light_color = Color(0.14, 0.07, 0.12)
	env.fog_density = 0.045
	env.fog_sky_affect = 0.0
	_build_yard()
	prince3d = Prince3D.new()
	prince3d.turn_deg = 0.0
	prince3d.scale = Vector3.ONE * 0.62
	add_child(prince3d)
	_build_enemy_meshes()
	_gems = _multimesh(SphereMesh.new(), _vertex_color_mat(true), false)
	_shots = _multimesh(SphereMesh.new(), _vertex_color_mat(true), false)
	_boomers = _multimesh(_boomerang_mesh(), _vertex_color_mat(), true)
	# 방귀 구름 (반투명 초록 공)
	_cloud = MeshInstance3D.new()
	_cloud.mesh = SphereMesh.new()
	_cloud.material_override = Kit.mat(Color(0.55, 0.8, 0.3, 0.22), 0.0, 0.5, true, false)
	_cloud.visible = false
	add_child(_cloud)
	for i in 3:
		var b := Node3D.new()
		Kit.sphere(b, 0.26, Color(0.25, 0.7, 0.25))
		for d in [Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			Kit.spike(b, 0.07, 0.2, Color(0.85, 0.9, 1.0), d * 0.22, d)
		b.visible = false
		add_child(b)
		_balls.append(b)
	for i in 10:
		var f := Node3D.new()
		Kit.sphere(f, 0.09, Color(0.15, 0.2, 0.12), Vector3.ZERO, Vector3.ONE, 0.0, false)
		Kit.sphere(f, 0.07, Color(0.8, 0.9, 1.0, 0.6), Vector3(0.07, 0.07, 0), Vector3(1, 0.3, 0.6), 0.0, false)
		Kit.sphere(f, 0.07, Color(0.8, 0.9, 1.0, 0.6), Vector3(-0.07, 0.07, 0), Vector3(1, 0.3, 0.6), 0.0, false)
		Kit.sphere(f, 0.035, Color(1, 0.2, 0.1), Vector3(0, 0.02, 0.08), Vector3.ONE, 1.5, false)
		f.visible = false
		add_child(f)
		_flies.append(f)
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	_place_camera()


# ------------------------------------------------------------------ 좌표

func to3(w: Vector2, h := 0.0) -> Vector3:
	return Vector3(w.x * K, h, w.y * K)


func screen_of(w: Vector2) -> Vector2:
	if not camera:
		return Vector2(360, 640)
	return camera.unproject_position(to3(w, 0.6))


func point_at(p: Vector2) -> Vector3:
	if stage:
		return to3(stage.screen_to_world(p), 0.6)
	return hero3


func _place_camera() -> void:
	var p := deg_to_rad(pitch_deg)
	var b := _cam_transform().basis
	camera.transform = Transform3D(b, hero3 + Vector3(0, sin(p), cos(p)) * CAM_DIST + Vector3(0, 0.5, 0))
	if _ground:
		# 땅은 카메라와 함께 움직이고, 무늬는 마당 좌표에 붙어 있어요
		_ground.position = Vector3(hero3.x, 0, hero3.z)
	sun.position = hero3


# ------------------------------------------------------------------ 마당 만들기 (제안 꾸밈)

func _build_yard() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	_ground = MeshInstance3D.new()
	_ground.mesh = plane
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_toon;
uniform vec3 stone : source_color = vec3(0.3, 0.26, 0.29);
varying vec3 wp;
float h21(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz * 0.9;
	vec2 row = vec2(p.x + step(1.0, mod(floor(p.y), 2.0)) * 0.5, p.y);
	vec2 cell = floor(row);
	vec2 f = fract(row);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float tone = 0.8 + h21(cell) * 0.35;
	vec2 s = wp.xz * 90.0;
	float grain = h21(vec2(floor((s.x * 0.8 + s.y * 0.6) / 2.6), floor((s.y * 0.8 - s.x * 0.6) / 30.0))) - 0.5;
	vec3 c = stone * tone * (1.0 + grain * 0.25);
	c = mix(vec3(0.12, 0.08, 0.1), c, smoothstep(0.02, 0.07, edge));
	float half_arena = %.1f;
	float outside = step(half_arena, max(abs(wp.x), abs(wp.z)));
	c = mix(c, vec3(0.16, 0.1, 0.13), outside);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
""" % (Rules.ARENA / 2.0 * K)
	var m := ShaderMaterial.new()
	m.shader = sh
	_ground.material_override = m
	add_child(_ground)
	# 성벽 (마당 둘레)
	var half := Rules.ARENA / 2.0 * K
	for side in 4:
		var horizontal := side < 2
		var sgn := -1.0 if side % 2 == 0 else 1.0
		var pos := Vector3(0, 0.9, sgn * (half + 0.6)) if horizontal else Vector3(sgn * (half + 0.6), 0.9, 0)
		var size := Vector3(half * 2.0 + 2.4, 1.8, 1.2) if horizontal else Vector3(1.2, 1.8, half * 2.0 + 2.4)
		Kit.box(self, size, STONE.darkened(0.15), pos)
		var count := int(half * 2.0 / 1.4)
		for i in count:
			var t := -half + 0.7 + i * 1.4
			var mp := Vector3(t, 2.05, pos.z) if horizontal else Vector3(pos.x, 2.05, t)
			Kit.box(self, Vector3(0.7, 0.5, 1.2) if horizontal else Vector3(1.2, 0.5, 0.7), STONE.darkened(0.1), mp)
		for i in range(-2, 3):
			var tp := Vector3(i * half * 0.45, 2.2, pos.z + sgn * -0.7) if horizontal else Vector3(pos.x + sgn * -0.7, 2.2, i * half * 0.45)
			Kit.torch(self, tp, 1.3)
	# 마당 꾸밈: 나무통, 깃발, 우물, 돌기둥 (부딪히지는 않아요)
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for i in 46:
		var p := Vector3(rng.randf_range(-half + 1.5, half - 1.5), 0, rng.randf_range(-half + 1.5, half - 1.5))
		if p.length() < 3.0:
			continue
		match i % 4:
			0:
				Kit.cylinder(self, 0.32, 0.36, 0.8, Color(0.32, 0.2, 0.12), p + Vector3(0, 0.4, 0))
				Kit.torus(self, 0.32, 0.4, Color(0.3, 0.3, 0.32), p + Vector3(0, 0.6, 0))
			1:
				Kit.cylinder(self, 0.05, 0.05, 2.6, Color(0.35, 0.22, 0.12), p + Vector3(0, 1.3, 0))
				var flag := Kit.box(self, Vector3(0.9, 0.55, 0.04), Color(0.85, 0.12, 0.12) if i % 8 == 1 else CAPE, p + Vector3(0.47, 2.25, 0))
				flag.rotation.y = rng.randf() * TAU
			2:
				Kit.cylinder(self, 0.4, 0.5, 1.6, STONE, p + Vector3(0, 0.8, 0))
				Kit.box(self, Vector3(1.1, 0.25, 1.1), STONE.darkened(0.2), p + Vector3(0, 1.7, 0))
			_:
				# 우물: 돌 테두리와 파란 물
				Kit.torus(self, 0.6, 0.9, STONE.darkened(0.1), p + Vector3(0, 0.3, 0))
				Kit.cylinder(self, 0.66, 0.66, 0.05, Color(0.15, 0.3, 0.6), p + Vector3(0, 0.12, 0), 0.0, false)
				Kit.cylinder(self, 0.04, 0.04, 1.4, Color(0.35, 0.22, 0.12), p + Vector3(-0.75, 0.7, 0))
				Kit.cylinder(self, 0.04, 0.04, 1.4, Color(0.35, 0.22, 0.12), p + Vector3(0.75, 0.7, 0))
				Kit.prism(self, Vector3(1.4, 0.35, 0.7), Color(0.5, 0.18, 0.14), p + Vector3(0, 1.5, 0))


# ------------------------------------------------------------------ 적 (MultiMesh)

## 색을 칸마다 바꿀 수 있는 크레용 툰 재질 (외곽선 포함)
func _vertex_color_mat(unshaded := false) -> Material:
	if unshaded:
		var sm := StandardMaterial3D.new()
		sm.vertex_color_use_as_albedo = true
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return sm
	var sh := Shader.new()
	sh.code = Kit.TOON_CODE.replace("ALBEDO = albedo.rgb", "ALBEDO = albedo.rgb * COLOR.rgb")
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("albedo", Color.WHITE)
	m.set_shader_parameter("emission_energy", 0.0)
	m.set_shader_parameter("grain", Kit.GRAIN)
	m.set_shader_parameter("rim_amount", 0.3)
	m.next_pass = Kit.outline_mat()
	return m


func _multimesh(mesh: Mesh, material: Material, shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = MAX_INST * 3
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-100, -10, -100), Vector3(200, 20, 200))
	add_child(mi)
	return mi


func _build_enemy_meshes() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	var mat := _vertex_color_mat()
	_mm.body = _multimesh(sphere, mat)
	_mm.helmet = _multimesh(sphere, mat)
	var eye_mat := _vertex_color_mat(true)
	var small := SphereMesh.new()
	small.radius = 1.0
	small.height = 2.0
	small.radial_segments = 8
	small.rings = 4
	_mm.eye = _multimesh(small, eye_mat, false)
	_mm.pupil = _multimesh(small, eye_mat, false)
	var plume := CylinderMesh.new()
	plume.top_radius = 0.0
	plume.bottom_radius = 1.0
	plume.height = 2.0
	plume.radial_segments = 6
	_mm.plume = _multimesh(plume, mat, false)


const TIERS := [[0.62, 0.32, 0.55], [0.48, 0.78, 0.6], [0.34, 1.12, 0.65]]


func _put(mm: MultiMesh, i: int, basis: Basis, origin: Vector3, color: Color) -> void:
	mm.set_instance_transform(i, Transform3D(basis, origin))
	mm.set_instance_color(i, color)


func _sync_enemies(rules) -> void:
	var body: MultiMesh = _mm.body.multimesh
	var helmet: MultiMesh = _mm.helmet.multimesh
	var eye: MultiMesh = _mm.eye.multimesh
	var pupil: MultiMesh = _mm.pupil.multimesh
	var plume: MultiMesh = _mm.plume.multimesh
	var n := 0
	var seen := {}
	for e in rules.enemies:
		if e.boss:
			seen[e.id] = true
			_sync_boss(e)
			continue
		if n >= MAX_INST:
			break
		var p := to3(e.pos)
		var to: Vector3 = hero3 - p
		var yaw := atan2(to.x, to.z)
		var s: float = e.radius * 3.2 * K / 1.4
		var bob := absf(sin(_t * 9.0 + e.id)) * 0.08
		var rot := Basis(Vector3.UP, yaw)
		var col := POOP
		var hcol := STEEL
		match e.kind:
			"runner":
				col = Color(0.72, 0.45, 0.18)
				hcol = Color(0.85, 0.3, 0.2)
			"brute":
				col = Color(0.4, 0.22, 0.1)
				hcol = Color(0.35, 0.35, 0.4)
		if e.flash > 0.0:
			col = Color(1, 1, 1)
			hcol = Color(1, 1, 1)
		var base := p + Vector3(0, bob, 0) * s
		for ti in 3:
			var t: Array = TIERS[ti]
			_put(body, n * 3 + ti, rot * Basis.from_scale(Vector3(t[0], t[0] * t[2], t[0] * 0.9) * s), base + Vector3(0, t[1], 0) * s, col)
		_put(helmet, n, rot * Basis.from_scale(Vector3(0.36, 0.2, 0.36) * s), base + Vector3(0, 1.32, 0) * s, hcol)
		_put(plume, n, rot * Basis.from_scale(Vector3(0.1, 0.2, 0.1) * s), base + Vector3(0, 1.6, 0) * s, Color(0.85, 0.05, 0.1))
		for k2 in 2:
			var sx := -0.17 if k2 == 0 else 0.17
			_put(eye, n * 2 + k2, Basis.from_scale(Vector3.ONE * 0.13 * s), base + rot * (Vector3(sx, 1.0, 0.38) * s), Color(1, 0.95, 0.8))
			_put(pupil, n * 2 + k2, Basis.from_scale(Vector3.ONE * 0.07 * s), base + rot * (Vector3(sx, 1.02, 0.49) * s), Color(0.1, 0.02, 0.02))
		n += 1
	body.visible_instance_count = n * 3
	helmet.visible_instance_count = n
	plume.visible_instance_count = n
	eye.visible_instance_count = n * 2
	pupil.visible_instance_count = n * 2
	for id in _bosses.keys():
		if not seen.has(id):
			var node: Node3D = _bosses[id]
			burst(node.position + Vector3(0, 1, 0), Color(0.55, 0.3, 0.12), 26, 2.0)
			node.queue_free()
			_bosses.erase(id)


# ------------------------------------------------------------------ 보스

func _sync_boss(e: Dictionary) -> void:
	if not _bosses.has(e.id):
		_bosses[e.id] = _make_demon() if e.kind == "demon" else _make_captain()
	var n: Node3D = _bosses[e.id]
	var p := to3(e.pos)
	n.position = p
	var to: Vector3 = hero3 - p
	n.rotation.y = atan2(to.x, to.z)
	var s: float = e.radius * 3.0 * K / 2.0
	var squash := 1.0 + sin(_t * 6.0) * 0.04
	n.scale = Vector3(s, s * squash, s)
	var body: Node3D = n.get_node("Body")
	var white: bool = e.flash > 0.0
	for part in n.get_meta("parts"):
		var mi: MeshInstance3D = part
		mi.material_override = Kit.mat(Color(1, 1, 1) if white else POOP)
	body.position.y = absf(sin(_t * 5.0)) * 0.08


func hit_boss(_e: Dictionary) -> void:
	pass


func _make_captain() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	Kit.shadow(n, 0.9)
	var body := Node3D.new()
	body.name = "Body"
	n.add_child(body)
	var parts: Array = []
	for t in TIERS:
		parts.append(Kit.sphere(body, t[0] * 1.25, POOP, Vector3(0, t[1] * 1.25, 0), Vector3(1, t[2], 0.9)))
	# 금 투구와 빨간 망토 (제안)
	Kit.sphere(body, 0.5, Color(1, 0.78, 0.12), Vector3(0, 1.62, 0), Vector3(1, 0.6, 1))
	Kit.spike(body, 0.14, 0.6, Color(0.85, 0.05, 0.1), Vector3(0, 1.85, 0), Vector3(0, 1, -0.3))
	var cape := Kit.prism(body, Vector3(1.6, 1.6, 0.12), Color(0.8, 0.1, 0.12), Vector3(0, 0.9, -0.6))
	cape.rotation.x = -0.15
	for sx in [-0.2, 0.2]:
		Kit.fierce_eye(body, Vector3(sx, 1.05, 0.6), 0.13, Color(1, 0.95, 0.8), Color(0.1, 0.02, 0.02))
		Kit.brow(body, Vector3(sx, 1.22, 0.66), 0.26, 0.45 if sx > 0 else -0.45)
	var blade := Kit.box(body, Vector3(0.12, 1.6, 0.05), Color(0.85, 0.9, 1.0), Vector3(0.85, 1.2, 0.3))
	blade.material_override = Kit.metal(Color(0.85, 0.9, 1.0))
	n.set_meta("parts", parts)
	return n


func _make_demon() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	Kit.shadow(n, 1.1)
	var body := Node3D.new()
	body.name = "Body"
	n.add_child(body)
	# 보라 망토와 박쥐 날개, 빨간 초승달 뿔 (원작 그림)
	var cape := Kit.prism(body, Vector3(2.0, 2.2, 0.15), CAPE, Vector3(0, 1.1, -0.55))
	cape.rotation.x = -0.1
	for sx in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(sx * 0.6, 1.7, -0.5)
		w.rotation.z = sx * -0.5
		body.add_child(w)
		for i in 3:
			Kit.spike(w, 0.05, 1.5 - i * 0.25, Color(0.2, 0.05, 0.2), Vector3.ZERO, Vector3(sx * (0.5 + i * 0.5), 1.0 - i * 0.3, 0))
		var mem := Kit.prism(w, Vector3(1.6, 1.2, 0.04), Color(0.35, 0.05, 0.25), Vector3(sx * 0.7, 0.4, 0))
		mem.rotation.z = sx * -0.6
	var parts: Array = []
	for t in [[0.95, 0.5, 0.55], [0.75, 1.2, 0.6], [0.55, 1.75, 0.66]]:
		parts.append(Kit.sphere(body, t[0], POOP, Vector3(0, t[1], 0), Vector3(1, t[2], 0.9)))
	for sx in [-1.0, 1.0]:
		var horn := Node3D.new()
		horn.position = Vector3(sx * 0.35, 2.05, 0)
		body.add_child(horn)
		for i in 5:
			var t := i / 4.0
			var a := t * 1.6
			Kit.sphere(horn, 0.17 * (1.0 - t * 0.75), HORN_RED, Vector3(sx * (sin(a) * 0.45), (1.0 - cos(a)) * 0.15 + t * 0.55, 0))
	for sx in [-0.25, 0.25]:
		Kit.fierce_eye(body, Vector3(sx, 1.35, 0.68), 0.14)
		Kit.brow(body, Vector3(sx, 1.55, 0.74), 0.3, 0.5 if sx > 0 else -0.5)
	Kit.light(body, Vector3(0, 1.4, 1.0), Color(1, 0.2, 0.3), 1.5, 4.0)
	n.set_meta("parts", parts)
	return n


# ------------------------------------------------------------------ 무기 연출

var _crescent: ArrayMesh


## 반달 모양 칼자국 (앞이 +z)
func _crescent_mesh() -> ArrayMesh:
	if _crescent:
		return _crescent
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 20
	for i in seg:
		var a0 := lerpf(-1.25, 1.25, float(i) / seg)
		var a1 := lerpf(-1.25, 1.25, float(i + 1) / seg)
		# 가운데가 두껍고 양 끝이 뾰족해요
		var w0 := 0.45 * sin(PI * float(i) / seg)
		var w1 := 0.45 * sin(PI * float(i + 1) / seg)
		var o0 := Vector3(sin(a0), 0, cos(a0))
		var o1 := Vector3(sin(a1), 0, cos(a1))
		var p0 := o0 * 1.0
		var p1 := o1 * 1.0
		var q0 := o0 * (1.0 - w0)
		var q1 := o1 * (1.0 - w1)
		for v in [p0, p1, q0, q0, p1, q1]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	_crescent = st.commit()
	return _crescent


func on_swing(dirs: Array, reach: float) -> void:
	prince3d.pose = Prince3D.Pose.SWING
	_swing_left = 0.25
	for d in dirs:
		var dir: Vector2 = d
		var arc := MeshInstance3D.new()
		arc.mesh = _crescent_mesh()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(1, 0.97, 0.7, 0.9)
		arc.material_override = m
		var r := reach * K
		add_child(arc)
		_fx.append({"node": arc, "life": 0.2, "max": 0.2, "kind": "swing", "dir": dir, "r": r, "mat": m})


func on_slam(radius: float) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	ring.mesh = tm
	ring.material_override = Kit.mat(Color(1, 0.8, 0.3, 0.8), 2.0, 0.5, true, false)
	ring.position = hero3 + Vector3(0, 0.1, 0)
	add_child(ring)
	_fx.append({"node": ring, "life": 0.35, "max": 0.35, "kind": "ring", "r": radius * K})
	burst(hero3 + Vector3(0, 0.3, 0), Color(0.6, 0.5, 0.45), 10, 1.0)


func on_boom(pos: Vector2, radius: float) -> void:
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	ball.mesh = sm
	ball.material_override = Kit.mat(Color(1, 0.6, 0.15, 0.75), 2.5, 0.5, true, false)
	ball.position = to3(pos, 0.3)
	add_child(ball)
	_fx.append({"node": ball, "life": 0.3, "max": 0.3, "kind": "boom", "r": radius * K})
	burst(to3(pos, 0.4), Color(0.5, 0.28, 0.1), 8, 1.0)
	if randf() < 0.4:
		comic(screen_of(pos), "펑!", Color(1, 0.6, 0.2), 0.6)


## 부메랑 모양 (ㄱ자로 꺾인 두꺼운 날개, 크기 1)
func _boomerang_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for arm in [-1.0, 1.0]:
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 0.22, 0.32)
		st.append_from(bm, 0, Transform3D(Basis(Vector3.UP, arm * 0.6), Vector3(0, 0, 0)).translated_local(Vector3(0.45, 0, 0)))
	st.generate_normals()
	return st.commit()


## 부메랑이 적을 맞혔어요: 퍽!
func on_bhit(pos: Vector2, evo: bool) -> void:
	if _debris.size() < 90:
		burst(to3(pos, 0.5), Color(1, 0.8, 0.3) if evo else Color(0.7, 0.45, 0.2), 5, 0.9)
	if randf() < 0.18:
		comic(screen_of(pos), "퍽!", Color(1, 0.75, 0.25), 0.55)
	shake(0.03, 0.08)


## 보라 광선 (진화하면 무지개): 손끝이 번쩍 → 굵은 빛줄기(하얀 심 + 보라 빛) → 맞은 곳마다 불꽃
func on_beam(from: Vector2, dir: Vector2, length: float, width: float, evo: bool, hits: Array = []) -> void:
	var col := Color(0.72, 0.3, 1.0)
	if evo:
		col = Color.from_hsv(fmod(_t * 0.7 + randf(), 1.0), 0.75, 1.0)
	var a := to3(from, 0.6)
	var c := to3(from + dir * length, 0.6)
	var yaw := atan2(dir.x, dir.y)
	for layer in 2:
		var b := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 1.0
		cm.radial_segments = 12
		b.mesh = cm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if layer == 0 else BaseMaterial3D.BLEND_MODE_MIX
		m.albedo_color = Color(col.lightened(0.1), 0.75) if layer == 0 else Color(1, 0.95, 1.0, 0.95)
		b.material_override = m
		b.position = (a + c) * 0.5
		b.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2)
		var w := width * K * (1.6 if layer == 0 else 0.5)
		add_child(b)
		_fx.append({"node": b, "life": 0.35, "max": 0.35, "kind": "beam", "mat": m, "w": w, "len": length * K, "yaw": yaw, "a0": m.albedo_color.a})
	# 손끝 번쩍
	var muzzle := MeshInstance3D.new()
	muzzle.mesh = SphereMesh.new()
	muzzle.material_override = Kit.mat(Color(col.lightened(0.4), 0.9), 3.0, 0.5, true, false)
	muzzle.position = a
	add_child(muzzle)
	_fx.append({"node": muzzle, "life": 0.22, "max": 0.22, "kind": "boom", "r": width * K * 2.2})
	# 맞은 곳마다 보라 불꽃
	for i in mini(hits.size(), 6):
		burst(to3(hits[i], 0.6), col.lightened(0.3), 4, 0.8)
	flash(col.lightened(0.5), 0.14)
	shake(0.06, 0.15)
	if hits.size() > 0 and randf() < 0.45:
		comic(screen_of(from + dir * minf(length * 0.45, 260.0)), "콰앙!", col.lightened(0.35), 0.8)


## 번개 (하늘에서 쾅)
func on_bolt(pos: Vector2, radius: float) -> void:
	var p := to3(pos)
	var bolt := Node3D.new()
	add_child(bolt)
	var y := 0.0
	var x := 0.0
	for i in 6:
		var seg := Kit.box(bolt, Vector3(0.12, 1.1, 0.12), Color(1, 0.95, 0.4), Vector3(x, y + 0.55, 0), 3.0, false)
		seg.rotation.z = randf_range(-0.5, 0.5)
		y += 1.0
		x += randf_range(-0.3, 0.3)
	bolt.position = p
	_fx.append({"node": bolt, "life": 0.18, "max": 0.18, "kind": "bolt"})
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.8
	tm.outer_radius = 1.0
	ring.mesh = tm
	ring.material_override = Kit.mat(Color(1, 0.95, 0.4, 0.8), 2.0, 0.5, true, false)
	ring.position = p + Vector3(0, 0.1, 0)
	add_child(ring)
	_fx.append({"node": ring, "life": 0.25, "max": 0.25, "kind": "ring_at", "r": radius * K})


## 가시가 사방으로
func on_thorns(radius: float) -> void:
	for i in 12:
		var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 12.0)
		var sp := Kit.spike(self, 0.06, 0.5, Color(0.75, 0.75, 0.85), hero3 + Vector3(0, 0.5, 0), d)
		_fx.append({"node": sp, "life": 0.3, "max": 0.3, "kind": "thorn", "dir": d, "r": radius * K})


func on_kill(e: Dictionary) -> void:
	if _debris.size() < 70:
		burst(to3(e.pos, 0.4), Color(0.55, 0.3, 0.12), 4, 0.7)


func _step_fx(delta: float) -> void:
	for f in _fx.duplicate():
		f.life -= delta
		var node: Node3D = f.node
		if f.life <= 0.0:
			node.queue_free()
			_fx.erase(f)
			continue
		var k: float = 1.0 - f.life / f.max
		match f.kind:
			"swing":
				var dir: Vector2 = f.dir
				node.position = hero3 + Vector3(0, 0.45, 0)
				node.rotation.y = atan2(dir.x, dir.y) + lerpf(-0.5, 0.5, k)
				node.scale = Vector3.ONE * f.r * (0.75 + k * 0.3)
				f.mat.albedo_color.a = 0.9 * (1.0 - k)
				continue
			"ring":
				var r: float = f.r * (0.2 + k * 0.9)
				node.scale = Vector3(r, 0.4, r)
				node.position = hero3 + Vector3(0, 0.1, 0)
			"boom":
				var r2: float = f.r * (0.3 + k * 0.8)
				node.scale = Vector3.ONE * r2
			"beam":
				# 확 굵어졌다가 가늘어지며 사라져요
				var grow: float = minf(k / 0.15, 1.0)
				var wv: float = f.w * grow * (1.0 - maxf(k - 0.4, 0.0) * 1.5)
				node.scale = Vector3(maxf(wv, 0.001), f.len, maxf(wv, 0.001) * 0.6)
				f.mat.albedo_color.a = f.a0 * (1.0 - maxf(k - 0.5, 0.0) * 2.0)
				continue
			"bolt":
				continue
			"puff":
				node.scale = Vector3.ONE * f.s * (1.0 - k * 0.7)
			"ring_at":
				var r3: float = f.r * (0.3 + k)
				node.scale = Vector3(r3, 0.4, r3)
			"thorn":
				node.position = hero3 + Vector3(0, 0.5, 0) + f.dir * f.r * k
				continue
		var gi := node as GeometryInstance3D
		if gi:
			gi.transparency = k


# ------------------------------------------------------------------ 매 프레임

func sync(rules, delta: float) -> void:
	_t += delta
	hero3 = to3(rules.hero)
	prince3d.position = hero3
	var f: Vector2 = rules.facing
	prince3d.rotation.y = lerp_angle(prince3d.rotation.y, atan2(f.x, f.y), clampf(delta * 14.0, 0.0, 1.0))
	if _swing_left > 0.0:
		_swing_left -= delta
		if _swing_left <= 0.0:
			prince3d.pose = Prince3D.Pose.IDLE
	prince3d.blink = rules.invuln
	prince3d.god = rules.god_left > 0.0
	if rules.hp <= 0.0:
		prince3d.pose = Prince3D.Pose.HURT
	_place_camera()
	_sync_enemies(rules)
	# 구슬
	var gm: MultiMesh = _gems.multimesh
	var gn := mini(rules.gems.size(), gm.instance_count)
	for i in gn:
		var g: Dictionary = rules.gems[i]
		var big: bool = g.value >= 5
		var r := 0.2 if big else 0.13
		_put(gm, i, Basis.from_scale(Vector3(r, r * 1.2, r)), to3(g.pos, 0.15 + sin(_t * 4.0 + i) * 0.04), Color(0.85, 0.55, 1.0) if big else Color(1, 0.85, 0.25))
	gm.visible_instance_count = gn
	# 사슬 철퇴
	var balls: Array = rules.chain_balls()
	for i in _balls.size():
		_balls[i].visible = i < balls.size()
		if i < balls.size():
			_balls[i].position = to3(balls[i], 0.5)
			_balls[i].rotation.y = _t * 6.0
	# 똥파리
	for i in _flies.size():
		_flies[i].visible = i < rules.flies.size()
		if i < rules.flies.size():
			_flies[i].position = to3(rules.flies[i].pos, 0.7 + sin(_t * 20.0 + i) * 0.05)
	# 부메랑과 얼음 조각
	var sm: MultiMesh = _shots.multimesh
	var sn := mini(rules.shots.size(), sm.instance_count)
	for i in sn:
		var sh: Dictionary = rules.shots[i]
		var r: float = sh.r * K
		if sh.kind == "boomerang":
			continue
		else:
			_put(sm, i, Basis.from_scale(Vector3.ONE * r * 0.8), to3(sh.pos, 0.5), Color(0.6, 0.95, 1.0))
	sm.visible_instance_count = sn
	# 부메랑: 빙글빙글 도는 ㄱ자 똥 부메랑 + 꼬리 바람
	var bmm: MultiMesh = _boomers.multimesh
	var bn := 0
	_trail_acc += delta
	var trail := _trail_acc > 0.04
	if trail:
		_trail_acc = 0.0
	for sh in rules.shots:
		if sh.kind != "boomerang" or bn >= bmm.instance_count:
			continue
		var br: float = sh.r * K * 1.7
		var evo: bool = rules.evolved.has("boomerang")
		var bp := to3(sh.pos, 0.55)
		_put(bmm, bn, Basis(Vector3.UP, _t * 22.0 + bn) * Basis(Vector3.RIGHT, 0.25) * Basis.from_scale(Vector3.ONE * br), bp, Color(0.95, 0.62, 0.1) if evo else Color(0.62, 0.36, 0.13))
		bn += 1
		if trail and _fx.size() < 120:
			var puff := MeshInstance3D.new()
			puff.mesh = SphereMesh.new()
			puff.material_override = Kit.mat(Color(1, 0.95, 0.7, 0.5) if evo else Color(1, 1, 1, 0.4), 0.0, 0.5, true, false)
			puff.position = bp
			puff.scale = Vector3.ONE * br * 0.35
			add_child(puff)
			_fx.append({"node": puff, "life": 0.25, "max": 0.25, "kind": "puff", "s": br * 0.35})
	bmm.visible_instance_count = bn
	# 똥 웅덩이
	while _puddles.size() < rules.puddles.size():
		var pm := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 0.04
		pm.mesh = cm
		pm.material_override = Kit.mat(Color(0.35, 0.45, 0.12, 0.7), 0.0, 0.5, true, false)
		add_child(pm)
		_puddles.append(pm)
	for i in _puddles.size():
		_puddles[i].visible = i < rules.puddles.size()
		if i < rules.puddles.size():
			var pd: Dictionary = rules.puddles[i]
			var pr: float = pd.r * K * (1.0 + sin(_t * 3.0 + i) * 0.03)
			_puddles[i].position = to3(pd.pos, 0.03)
			_puddles[i].scale = Vector3(pr, 1, pr)
	# 방귀 구름
	var cr: float = rules.cloud_radius() * K
	_cloud.visible = cr > 0.0
	if cr > 0.0:
		_cloud.position = hero3 + Vector3(0, 0.2, 0)
		_cloud.scale = Vector3(cr, cr * 0.35, cr) * (1.0 + sin(_t * 4.0) * 0.05)
	# 똥폭탄 (날아가는 중)
	while _bombs.size() < rules.bombs.size():
		var b := Node3D.new()
		Kit.sphere(b, 0.16, POOP)
		Kit.sphere(b, 0.05, Color(1, 0.6, 0.1), Vector3(0, 0.18, 0), Vector3.ONE, 2.0, false)
		add_child(b)
		_bombs.append(b)
	for i in _bombs.size():
		_bombs[i].visible = i < rules.bombs.size()
		if i < rules.bombs.size():
			var bb: Dictionary = rules.bombs[i]
			var k := 1.0 - clampf(bb.t / 0.5, 0.0, 1.0)
			var from: Vector2 = bb.from
			var w: Vector2 = from.lerp(bb.pos, k)
			_bombs[i].position = to3(w, 0.3 + sin(k * PI) * 1.6)
	_step_fx(delta)
