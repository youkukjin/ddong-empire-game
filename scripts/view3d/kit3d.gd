extends RefCounted
## 3D 모양 만들기 도우미예요 (제안: 3D 화면).
## 그림 파일 없이 공·상자·원기둥 같은 기본 도형과 색으로 인물과 장소를 만들어요.
## 나중에 3D 모델(.glb)이 생기면 그 모델로 바꾸면 돼요.

static var _mats := {}


## 부드럽고 깔끔한 재질. emission > 0 이면 스스로 빛나요.
static func mat(color: Color, emission := 0.0, rough := 0.55, unshaded := false) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s" % [color.to_html(), emission, rough, unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic_specular = 0.6
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.rim_enabled = not unshaded and emission == 0.0
	m.rim = 0.25
	m.rim_tint = 0.6
	_mats[key] = m
	return m


## 땅·언덕처럼 넓은 면: 반짝임 없는 무광 재질
static func matte(color: Color) -> StandardMaterial3D:
	var key := "matte|" + color.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic_specular = 0.0
	_mats[key] = m
	return m


static func ground_sphere(parent: Node3D, r: float, color: Color, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := sphere(parent, r, color, pos, scl)
	mi.material_override = matte(color)
	return mi


static func _add(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scl := Vector3.ONE, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color, emission)
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func sphere(parent: Node3D, r: float, color: Color, pos := Vector3.ZERO, scl := Vector3.ONE, emission := 0.0) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 32
	m.rings = 16
	return _add(parent, m, color, pos, scl, emission)


static func box(parent: Node3D, size: Vector3, color: Color, pos := Vector3.ZERO, emission := 0.0) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(parent, m, color, pos, Vector3.ONE, emission)


static func cylinder(parent: Node3D, r_top: float, r_bottom: float, h: float, color: Color, pos := Vector3.ZERO, emission := 0.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = h
	m.radial_segments = 24
	return _add(parent, m, color, pos, Vector3.ONE, emission)


static func capsule(parent: Node3D, r: float, h: float, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	return _add(parent, m, color, pos)


static func torus(parent: Node3D, inner: float, outer: float, color: Color, pos := Vector3.ZERO, emission := 0.0) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 32
	m.ring_segments = 12
	return _add(parent, m, color, pos, Vector3.ONE, emission)


static func prism(parent: Node3D, size: Vector3, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := PrismMesh.new()
	m.size = size
	return _add(parent, m, color, pos)


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


## 귀여운 눈 하나: 흰자, 큰 눈동자, 반짝이 두 개. 앞(+z)을 봐요.
static func eye(parent: Node3D, pos: Vector3, r: float) -> Node3D:
	var e := Node3D.new()
	e.position = pos
	parent.add_child(e)
	sphere(e, r, Color.WHITE, Vector3.ZERO, Vector3(1, 1, 0.6))
	sphere(e, r * 0.72, Color(0.12, 0.07, 0.06), Vector3(0, -r * 0.05, r * 0.3), Vector3(1, 1, 0.6))
	sphere(e, r * 0.26, Color.WHITE, Vector3(-r * 0.25, r * 0.25, r * 0.62), Vector3.ONE, 0.6)
	sphere(e, r * 0.12, Color.WHITE, Vector3(r * 0.25, -r * 0.25, r * 0.62), Vector3.ONE, 0.6)
	return e


static func blush(parent: Node3D, pos: Vector3, r: float) -> MeshInstance3D:
	return sphere(parent, r, Color(1, 0.55, 0.62), pos, Vector3(1, 0.6, 0.3))


## 바닥 그림자 (둥근 반투명 판)
static func shadow(parent: Node3D, r: float, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = 0.01
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(Color(0.05, 0.02, 0.1, 0.3), 0.0, 1.0, true)
	mi.position = pos + Vector3(0, 0.01, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func label(parent: Node3D, text: String, pos: Vector3, size := 64, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.outline_size = 14
	l.modulate = color
	l.outline_modulate = Color(0.3, 0.14, 0.24)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.01
	parent.add_child(l)
	return l
