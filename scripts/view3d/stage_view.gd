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
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_hdr_threshold = 1.1
	env.glow_bloom = 0.0
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
	_shake_power = power
	_shake_left = time


func _process(delta: float) -> void:
	if not camera:
		return
	if _shake_left > 0.0:
		_shake_left -= delta
		camera.h_offset = randf_range(-_shake_power, _shake_power)
		camera.v_offset = randf_range(-_shake_power, _shake_power)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
