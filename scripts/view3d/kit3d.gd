extends RefCounted
## 3D 모양 만들기 도우미예요 (제안: 3D 화면).
## 그림 파일 없이 공·상자·원기둥 같은 기본 도형과 색으로 인물과 장소를 만들어요.
## 나중에 3D 모델(.glb)이 생기면 그 모델로 바꾸면 돼요.
##
## 박력 있는 그림체 (제안, 원작 크레용 그림 느낌):
## - 굵은 검은 외곽선: 모든 인물·물건에 화면 기준 같은 굵기로 그려요
## - 크레용 결: 비스듬한 크레용 줄무늬와 종이 알갱이가 색 위에 얹혀요
## - 툰 그림자: 빛과 그림자가 딱 나뉘어서 만화처럼 또렷해요
## 굵기와 결의 세기는 아래 숫자만 바꾸면 게임 전체가 같이 바뀌어요.

const INK := Color(0.07, 0.035, 0.05)    # 외곽선 색 (진한 크레용 검정)
const OUTLINE_PX := 4.0                  # 외곽선 굵기 (720줄 화면 기준 픽셀)
const GRAIN := 0.32                      # 크레용 결 세기 (0이면 매끈해요)

static var _mats := {}
static var _toon_shader: Shader
static var _outline_shader: Shader
static var _outline_mat: ShaderMaterial

const TOON_CODE := """
shader_type spatial;
render_mode diffuse_toon, specular_toon;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float emission_energy = 0.0;
uniform float grain = 0.3;
uniform float rim_amount = 0.3;

float h21(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 크레용 결은 물건(세상)에 붙어 있어요. 화면에 붙어 있으면 움직일 때 어지러워요.
	// (2026-11-28 사용자: 바닥 무늬가 고정이라 어지럽다)
	vec2 s = vec2(wp.x + wp.z * 0.55, wp.y - wp.z * 0.8) * 80.0;
	float stroke = h21(vec2(floor((s.x * 0.8 + s.y * 0.6) / 2.6), floor((s.y * 0.8 - s.x * 0.6) / 30.0)));
	float stroke2 = h21(vec2(floor((s.x * 0.5 - s.y * 0.86) / 3.4), floor((s.y * 0.5 + s.x * 0.86) / 22.0)) + 7.0);
	float paper = h21(floor(s / 1.6));
	float g = (stroke * 0.5 + stroke2 * 0.2 + paper * 0.3) - 0.5;
	ALBEDO = albedo.rgb * (1.0 + g * grain);
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	RIM = rim_amount;
	RIM_TINT = 0.4;
	EMISSION = albedo.rgb * emission_energy;
}
"""

const OUTLINE_CODE := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform vec4 ink : source_color = vec4(0.07, 0.035, 0.05, 1.0);
uniform float width_px = 3.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 vn = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 off = (PROJECTION_MATRIX * vec4(vn, 0.0)).xy;
	float l = length(off);
	if (l > 0.00001) {
		off /= l;
	}
	clip.xy += off * width_px * 2.0 / VIEWPORT_SIZE * clip.w * (min(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y) / 720.0);
	POSITION = clip;
}

void fragment() {
	ALBEDO = ink.rgb;
}
"""


static func _toon() -> Shader:
	if not _toon_shader:
		_toon_shader = Shader.new()
		_toon_shader.code = TOON_CODE
	return _toon_shader


## 굵은 검은 외곽선 재질 (다른 재질의 next_pass로 붙여요)
static func outline_mat() -> ShaderMaterial:
	if not _outline_mat:
		_outline_shader = Shader.new()
		_outline_shader.code = OUTLINE_CODE
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = _outline_shader
		_outline_mat.set_shader_parameter("ink", INK)
		_outline_mat.set_shader_parameter("width_px", OUTLINE_PX)
	return _outline_mat


## 크레용 툰 재질. emission > 0 이면 스스로 빛나요.
## ink: 외곽선을 그릴지 (빛나는 것, 반투명한 것, 아주 작은 것은 보통 안 그려요)
static func mat(color: Color, emission := 0.0, rough := 0.55, unshaded := false, ink := true) -> Material:
	var key := "%s|%.2f|%.2f|%s|%s" % [color.to_html(), emission, rough, unshaded, ink]
	if _mats.has(key):
		return _mats[key]
	var m: Material
	if color.a < 1.0 or unshaded:
		# 반투명·빛 덩어리는 크레용 결 없이 그려요
		var sm := StandardMaterial3D.new()
		sm.albedo_color = color
		sm.roughness = rough
		if color.a < 1.0:
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if emission > 0.0:
			sm.emission_enabled = true
			sm.emission = color
			sm.emission_energy_multiplier = emission
		if unshaded:
			sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m = sm
	else:
		var tm := ShaderMaterial.new()
		tm.shader = _toon()
		tm.set_shader_parameter("albedo", color)
		tm.set_shader_parameter("emission_energy", emission)
		tm.set_shader_parameter("grain", GRAIN if emission < 1.0 else GRAIN * 0.4)
		tm.set_shader_parameter("rim_amount", 0.3 if emission == 0.0 else 0.0)
		if ink and emission < 1.0:
			tm.next_pass = outline_mat()
		m = tm
	_mats[key] = m
	return m


## 땅·언덕처럼 넓은 면: 외곽선 없는 크레용 재질
static func matte(color: Color) -> Material:
	return mat(color, 0.0, 1.0, false, false)


## 금속 칼날: 크레용 결 대신 반짝이고, 외곽선은 그려요
static func metal(color: Color) -> Material:
	var key := "metal|" + color.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.8
	m.roughness = 0.15
	m.next_pass = outline_mat()
	_mats[key] = m
	return m


static func ground_sphere(parent: Node3D, r: float, color: Color, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := sphere(parent, r, color, pos, scl)
	mi.material_override = matte(color)
	return mi


static func _add(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scl := Vector3.ONE, emission := 0.0, ink := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color, emission, 0.55, false, ink)
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func sphere(parent: Node3D, r: float, color: Color, pos := Vector3.ZERO, scl := Vector3.ONE, emission := 0.0, ink := true) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 32
	m.rings = 16
	return _add(parent, m, color, pos, scl, emission, ink)


static func box(parent: Node3D, size: Vector3, color: Color, pos := Vector3.ZERO, emission := 0.0, ink := true) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(parent, m, color, pos, Vector3.ONE, emission, ink)


static func cylinder(parent: Node3D, r_top: float, r_bottom: float, h: float, color: Color, pos := Vector3.ZERO, emission := 0.0, ink := true) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = h
	m.radial_segments = 24
	return _add(parent, m, color, pos, Vector3.ONE, emission, ink)


static func capsule(parent: Node3D, r: float, h: float, color: Color, pos := Vector3.ZERO, ink := true) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	return _add(parent, m, color, pos, Vector3.ONE, 0.0, ink)


static func torus(parent: Node3D, inner: float, outer: float, color: Color, pos := Vector3.ZERO, emission := 0.0, ink := true) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 32
	m.ring_segments = 12
	return _add(parent, m, color, pos, Vector3.ONE, emission, ink)


static func prism(parent: Node3D, size: Vector3, color: Color, pos := Vector3.ZERO, ink := true) -> MeshInstance3D:
	var m := PrismMesh.new()
	m.size = size
	return _add(parent, m, color, pos, Vector3.ONE, 0.0, ink)


## 뾰족한 가시·뿔·이빨 (원뿔). 끝이 dir 쪽을 봐요.
static func spike(parent: Node3D, base_r: float, length: float, color: Color, pos: Vector3, dir: Vector3, ink := true) -> MeshInstance3D:
	var c := cylinder(parent, 0.0, base_r, length, color, Vector3.ZERO, 0.0, ink)
	c.basis = basis_along(dir)
	c.position = pos + dir.normalized() * length * 0.5
	return c


static func basis_along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.BACK)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	return Basis(x, y, x.cross(y).normalized())


## 원기둥을 a에서 b까지 늘여 놓아요 (줄기, 칼날, 팔).
static func stretch_between(mi: Node3D, a: Vector3, b: Vector3) -> void:
	var mid := (a + b) * 0.5
	var dir := b - a
	var length := dir.length()
	if length < 0.0001:
		mi.visible = false
		return
	mi.visible = true
	var y := dir / length
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y * length, z), mid)


## 똘망한 눈 하나: 흰자, 큰 눈동자, 반짝이. 앞(+z)을 봐요.
static func eye(parent: Node3D, pos: Vector3, r: float) -> Node3D:
	var e := Node3D.new()
	e.position = pos
	parent.add_child(e)
	sphere(e, r, Color.WHITE, Vector3.ZERO, Vector3(1, 1, 0.6))
	sphere(e, r * 0.62, Color(0.1, 0.05, 0.04), Vector3(0, -r * 0.05, r * 0.32), Vector3(1, 1, 0.6), 0.0, false)
	sphere(e, r * 0.22, Color.WHITE, Vector3(-r * 0.22, r * 0.22, r * 0.62), Vector3.ONE, 0.6, false)
	return e


## 굳센 눈썹 (박력 있는 표정). tilt > 0 이면 안쪽이 내려가서 화난 눈이 돼요.
static func brow(parent: Node3D, pos: Vector3, w: float, tilt: float, color := INK) -> MeshInstance3D:
	var b := box(parent, Vector3(w, w * 0.28, w * 0.25), color, pos, 0.0, false)
	b.rotation.z = tilt
	return b


## 무서운 눈 하나: 노란 눈에 세로로 찢어진 빨간 눈동자 (드래곤·대마왕).
static func fierce_eye(parent: Node3D, pos: Vector3, r: float, iris := Color(1, 0.85, 0.15), pupil := Color(0.75, 0.05, 0.05)) -> Node3D:
	var e := Node3D.new()
	e.position = pos
	parent.add_child(e)
	sphere(e, r, iris, Vector3.ZERO, Vector3(1.25, 0.8, 0.5), 0.8)
	sphere(e, r * 0.75, pupil, Vector3(0, 0, r * 0.3), Vector3(0.28, 1.0, 0.4), 0.3, false)
	return e


static func blush(parent: Node3D, pos: Vector3, r: float) -> MeshInstance3D:
	return sphere(parent, r, Color(1, 0.45, 0.5), pos, Vector3(1, 0.6, 0.3), 0.0, false)


## 바닥 그림자 (둥근 반투명 판)
static func shadow(parent: Node3D, r: float, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = 0.01
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(Color(0.02, 0.0, 0.03, 0.45), 0.0, 1.0, true)
	mi.position = pos + Vector3(0, 0.01, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func light(parent: Node3D, pos: Vector3, color: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	parent.add_child(l)
	return l


## 불타는 횃불 (기둥 + 불꽃 + 주황 빛)
static func torch(parent: Node3D, pos: Vector3, s := 1.0) -> Node3D:
	var t := Node3D.new()
	t.position = pos
	parent.add_child(t)
	cylinder(t, 0.07 * s, 0.09 * s, 1.4 * s, Color(0.3, 0.18, 0.1), Vector3(0, 0.7 * s, 0))
	cylinder(t, 0.16 * s, 0.1 * s, 0.2 * s, Color(0.25, 0.22, 0.25), Vector3(0, 1.45 * s, 0))
	sphere(t, 0.2 * s, Color(1, 0.4, 0.08), Vector3(0, 1.65 * s, 0), Vector3(1, 1.4, 1), 2.5)
	sphere(t, 0.11 * s, Color(1, 0.85, 0.3), Vector3(0, 1.62 * s, 0.05 * s), Vector3(1, 1.3, 1), 3.0)
	light(t, Vector3(0, 1.8 * s, 0.3 * s), Color(1, 0.55, 0.2), 1.6, 5.0 * s)
	return t


static func label(parent: Node3D, text: String, pos: Vector3, size := 64, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.outline_size = 18
	l.modulate = color
	l.outline_modulate = INK
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.01
	parent.add_child(l)
	return l
