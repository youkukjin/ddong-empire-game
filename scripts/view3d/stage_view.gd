extends Node3D
## 3D 무대예요 (제안: 3D 화면): 카메라, 빛, 하늘을 만들고,
## 게임 규칙이 쓰는 화면 좌표(1280x720)를 3D 위치로 바꿔 줘요.
##
## 규칙과 터치는 지금까지처럼 화면 좌표로 계산하고, 3D 모양은 같은 자리에 보이도록 놓아요.
## 그래서 3D로 바뀌어도 조작과 자동 확인은 그대로예요.

const SCREEN := Vector2(1280, 720)

var cam_height := 9.0
var cam_z := 13.0
var pitch_deg := 36.0
var fov_deg := 40.0

var camera: Camera3D
var env: Environment
var sun: DirectionalLight3D
var _shake_left := 0.0
var _shake_power := 0.0
var _shake_time := 0.2

const Kit3D := preload("res://scripts/view3d/kit3d.gd")
const FONT := preload("res://assets/fonts/Jua-Regular.ttf")

## 박력 연출 (제안): 번쩍임, 큰 의성어 글자, 파편, 테두리 어둡게
var fx_layer: CanvasLayer
var _flash_rect: ColorRect
var _debris: Array = []      # {"node", "v", "life"}


## 무대를 만들어요. sky_top/sky_bottom: 하늘 색, ambient: 주변 빛 색
func setup(sky_top: Color, sky_bottom: Color, ambient: Color, sun_color := Color(1, 0.96, 0.9), sun_energy := 1.0) -> void:
	camera = Camera3D.new()
	camera.fov = fov_deg
	camera.near = 0.1
	camera.far = 200.0
	camera.transform = _cam_transform()
	add_child(camera)
	camera.current = true

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = sky_top
	sky_mat.sky_horizon_color = sky_bottom
	sky_mat.ground_horizon_color = sky_bottom
	sky_mat.ground_bottom_color = sky_bottom.darkened(0.3)
	sky_mat.sun_angle_max = 0.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.0
	env.glow_bloom = 0.05
	# 박력 (제안): 색을 진하게, 대비를 세게 (크레용처럼 꾹꾹 눌러 칠한 느낌)
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.25
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 60.0
	sun.rotation_degrees = Vector3(-55, -35, 0)
	add_child(sun)
	_build_fx_layer()


# ------------------------------------------------------------------ 박력 연출 (제안)

func _build_fx_layer() -> void:
	fx_layer = CanvasLayer.new()
	fx_layer.layer = 0
	add_child(fx_layer)
	# 화면 테두리를 어둡게 (무대 조명처럼 가운데로 눈이 가요)
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.55;
void fragment() {
	vec2 d = (UV - vec2(0.5)) * vec2(1.25, 1.0);
	float v = smoothstep(0.38, 0.85, length(d));
	COLOR = vec4(0.04, 0.0, 0.05, v * strength);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vig.material = sm
	fx_layer.add_child(vig)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	fx_layer.add_child(_flash_rect)


## 화면 점 p 근처의 3D 점 (파편이 튀는 곳). 장마다 바꿔요.
func point_at(p: Vector2) -> Vector3:
	return ground(p)


## 한 방! 화면 흔들기 + 번쩍임 + 큰 의성어 + 파편.
## power: 0.5 작은 타격 ~ 2.0 필살기
func impact(p: Vector2, text := "", color := Color(1, 0.85, 0.2), power := 1.0) -> void:
	shake(0.07 * power, 0.12 + 0.1 * power)
	flash(Color(1, 0.95, 0.8) if power < 1.5 else color.lightened(0.4), 0.12 + 0.12 * power)
	if text != "":
		comic(p, text, color, power)
	burst(point_at(p), color, int(6 + 6 * power), 0.6 + 0.4 * power)
	if power >= 1.4:
		hit_stop(0.05 + 0.03 * power)


func flash(color: Color, alpha := 0.35) -> void:
	if not _flash_rect:
		return
	_flash_rect.color = Color(color, clampf(alpha, 0.0, 0.8))
	var tw := _flash_rect.create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, 0.25)


## 만화 의성어 글자 (콰앙! 쾅! 콰지직!): 크게 튀어나왔다가 사라져요.
func comic(p: Vector2, text: String, color: Color, power := 1.0) -> void:
	if not fx_layer:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	var fs := int(54 + 34 * power)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Kit3D.INK)
	l.add_theme_constant_override("outline_size", int(fs * 0.28))
	l.add_theme_color_override("font_shadow_color", Color(0.75, 0.1, 0.05, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 6)
	l.add_theme_constant_override("shadow_offset_y", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(l)
	var sz := l.get_minimum_size()
	l.size = sz
	l.pivot_offset = sz * 0.5
	l.position = Vector2(clampf(p.x - sz.x * 0.5, 10, SCREEN.x - sz.x - 10), clampf(p.y - sz.y * 0.5 - 40, 100, SCREEN.y - sz.y - 10))
	l.rotation = randf_range(-0.22, 0.22)
	l.scale = Vector2.ONE * 2.2
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(l, "position:y", l.position.y - 30, 0.3)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


## 파편이 사방으로 튀어요.
func burst(at: Vector3, color: Color, count := 10, size := 1.0) -> void:
	for i in count:
		var d := Kit3D.sphere(self, randf_range(0.06, 0.16) * size, color if i % 3 else color.darkened(0.4), at, Vector3.ONE, 1.2 if i % 2 else 0.0)
		var v := Vector3(randf_range(-1, 1), randf_range(0.4, 1.4), randf_range(-0.3, 0.8)).normalized() * randf_range(3.0, 7.0) * size
		_debris.append({"node": d, "v": v, "life": randf_range(0.35, 0.6)})


## 잠깐 멈칫 (때리는 손맛)
func hit_stop(t := 0.06) -> void:
	if Engine.time_scale < 0.99:
		return
	Engine.time_scale = 0.05
	get_tree().create_timer(t, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


func _exit_tree() -> void:
	if Engine.time_scale < 0.99 and Engine.time_scale > 0.04:
		Engine.time_scale = 1.0


func _step_debris(delta: float) -> void:
	for d in _debris.duplicate():
		d.life -= delta
		var n: Node3D = d.node
		if d.life <= 0.0:
			n.queue_free()
			_debris.erase(d)
			continue
		d.v.y -= 14.0 * delta
		n.position += d.v * delta
		n.scale = Vector3.ONE * clampf(d.life / 0.3, 0.0, 1.0)


func _cam_transform() -> Transform3D:
	var p := deg_to_rad(pitch_deg)
	var f := Vector3(0, -sin(p), -cos(p))
	var u := Vector3(0, cos(p), -sin(p))
	return Transform3D(Basis(Vector3.RIGHT, u, -f), Vector3(0, cam_height, cam_z))


## 화면 점 p에서 나가는 빛줄기 방향 (카메라 계산을 직접 해서 창 크기와 상관없이 같아요)
func ray_dir(p: Vector2) -> Vector3:
	var t := tan(deg_to_rad(fov_deg) * 0.5)
	var nx := (p.x / SCREEN.x * 2.0 - 1.0) * t * (SCREEN.x / SCREEN.y)
	var ny := (1.0 - p.y / SCREEN.y * 2.0) * t
	var b := _cam_transform().basis
	return (-b.z + b.x * nx + b.y * ny).normalized()


func cam_pos() -> Vector3:
	return Vector3(0, cam_height, cam_z)


## 화면 점 → 땅(높이 h) 위의 3D 점
func ground(p: Vector2, h := 0.0) -> Vector3:
	var d := ray_dir(p)
	var o := cam_pos()
	if absf(d.y) < 0.0001:
		return o + d * 100.0
	var t := (h - o.y) / d.y
	if t < 0.0:
		t = 100.0
	return o + d * t


## 화면 점 → 카메라 앞에 세운 벽(z = 값) 위의 3D 점. 하늘에 있는 것(드래곤 머리, 달)에 써요.
func on_wall(p: Vector2, z: float) -> Vector3:
	var d := ray_dir(p)
	var o := cam_pos()
	var t := (z - o.z) / d.z
	return o + d * t


## 땅에서 화면 1픽셀이 몇 3D 단위인지 (그 자리에서 가로로 잰 값)
func px_on_ground(p: Vector2) -> float:
	return ground(p).distance_to(ground(p + Vector2(10, 0))) / 10.0


func px_on_wall(z: float) -> float:
	return on_wall(Vector2(600, 300), z).distance_to(on_wall(Vector2(610, 300), z)) / 10.0


## 화면 없이 돌리는 자동 확인(헤드리스)에서는 3D를 만들지 않아요.
## (가짜 그리기 장치가 기본 도형마다 오류 글을 찍어서 확인 결과를 읽기 어려워요.
##  3D 모습은 tests/screenshots.gd 로 창을 띄워 확인해요.)
static func can_show() -> bool:
	return DisplayServer.get_name() != "headless"


func shake(power := 0.15, time := 0.2) -> void:
	if _shake_left > 0.0 and _shake_power > power:
		return
	_shake_power = power
	_shake_left = time
	_shake_time = time


func _process(delta: float) -> void:
	if not camera:
		return
	_step_debris(delta)
	if _shake_left > 0.0:
		_shake_left -= delta
		var k := clampf(_shake_left / maxf(_shake_time, 0.01), 0.0, 1.0)
		camera.h_offset = randf_range(-_shake_power, _shake_power) * k
		camera.v_offset = randf_range(-_shake_power, _shake_power) * k
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
