extends Node2D
## 똥 왕자: 갈색 똥 모양 몸에 왕관을 쓰고 검을 들었어요 (원작 그림).
## 팔에는 사슬로 이어진 무기가 있어요 (원작 성벽·무사 장면). 임시 도형이라 그림이 나오면 바꿔요.
## position은 발 밑이에요.

const Cute := preload("res://scripts/art/cute.gd")

enum Pose { IDLE, SWING, CHARGE, ROLL, HURT, CHEER }

const BROWN := Color(0.71, 0.45, 0.25)       # 귀여운 디자인 (제안): 밀크초코색
const BROWN_DARK := Color(0.45, 0.27, 0.15)
const GOLD := Color(1, 0.82, 0.25)
const HEIGHT := 130.0

var facing := 1.0            # 1 = 오른쪽, -1 = 왼쪽
var pose := Pose.IDLE
var arm_level := 0           # 근육 팔 단계 0~3 (6장: 힘 20·30·40)
var sword_level := 0         # 검 강화 0~5 (모습만)
var charge := 0.0            # 사슬 모으기 0~1
var god := false             # 7장 똥의 신 각성
var deity := false           # 7장 끝: 똥의 신으로 완전히 변신 (제안 모습)
var blink := 0.0             # 맞은 뒤 깜빡임 시간
var show_chain := true
var _t := 0.0
var _pose_left := 0.0


func _process(delta: float) -> void:
	_t += delta
	blink = maxf(blink - delta, 0.0)
	if _pose_left > 0.0:
		_pose_left -= delta
		if _pose_left <= 0.0 and pose != Pose.CHARGE:
			pose = Pose.IDLE
	queue_redraw()


## 잠깐 동안 자세를 바꿔요 (휘두르기, 구르기, 맞기).
func play_pose(p: Pose, time := 0.25) -> void:
	pose = p
	_pose_left = time


func body_center() -> Vector2:
	return global_position + Vector2(0, -HEIGHT * 0.45)


func _draw() -> void:
	if blink > 0.0 and int(blink * 14.0) % 2 == 0:
		return
	var f := facing
	var bob := sin(_t * 4.0) * 3.0 if pose == Pose.IDLE else 0.0
	var squash := 0.75 if pose == Pose.ROLL else 1.0
	var body := BROWN if not god else Color(0.95, 0.72, 0.25)
	var dark := BROWN_DARK if not god else Color(0.75, 0.5, 0.1)
	if deity:
		body = Color(0.62, 0.1, 0.1)
		dark = Color(0.4, 0.05, 0.06)
		# 빨간 초승달 뿔 (2D 화면용)
		for sx in [-1.0, 1.0]:
			draw_arc(Vector2(sx * 40, -120), 34, PI if sx < 0 else -PI * 0.5, (PI * 1.5) if sx < 0 else 0.0, 12, Color(0.95, 0.12, 0.1), 12)
	if god:
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		draw_circle(Vector2(0, -70), 110 + pulse * 14, Color(1, 0.9, 0.4, 0.25))
		for i in 12:
			var a := TAU * i / 12.0 + _t
			draw_line(Vector2(0, -70) + Vector2(cos(a), sin(a)) * 90, Vector2(0, -70) + Vector2(cos(a), sin(a)) * 140, Color(1, 0.95, 0.5, 0.5), 4)
	# 똥 몸: 세 겹
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(1, squash))
	_ellipse(Vector2(0, -26), Vector2(56, 28), dark)
	_ellipse(Vector2(0, -30), Vector2(52, 26), body)
	_ellipse(Vector2(0, -66), Vector2(42, 22), dark)
	_ellipse(Vector2(0, -70), Vector2(38, 20), body)
	_ellipse(Vector2(0, -100), Vector2(26, 16), dark)
	_ellipse(Vector2(0, -103), Vector2(23, 14), body)
	# 몸 반짝임 (제안)
	var shine := Color(1, 1, 1, 0.35)
	_ellipse(Vector2(-26, -40), Vector2(12, 6), shine)
	_ellipse(Vector2(-18, -78), Vector2(9, 5), shine)
	_ellipse(Vector2(-10, -108), Vector2(6, 4), shine)
	# 눈: 반짝이는 큰 눈 (제안)
	var eye_y := -72.0
	for ex in [-15.0, 15.0]:
		if pose == Pose.CHEER:
			Cute.happy_eye(self, Vector2(ex + 5 * f, eye_y), 11)
		elif pose == Pose.HURT:
			draw_line(Vector2(ex + 5 * f - 8, eye_y - 6), Vector2(ex + 5 * f + 8, eye_y + 6), Cute.INK, 4)
			draw_line(Vector2(ex + 5 * f - 8, eye_y + 6), Vector2(ex + 5 * f + 8, eye_y - 6), Cute.INK, 4)
		else:
			Cute.eye(self, Vector2(ex + 5 * f, eye_y), 12, Vector2(f, 0))
	Cute.blush(self, Vector2(-26 + 5 * f, -56), 8)
	Cute.blush(self, Vector2(26 + 5 * f, -56), 8)
	if pose == Pose.HURT:
		draw_arc(Vector2(5 * f, -46), 7, PI + 0.4, TAU - 0.4, 8, Cute.INK, 3)
	else:
		Cute.smile(self, Vector2(5 * f, -56), 7, Cute.INK, pose == Pose.SWING or pose == Pose.CHEER)
	# 왕관
	var crown_y := -118.0
	var crown := PackedVector2Array([
		Vector2(-20, crown_y), Vector2(-24, crown_y - 22), Vector2(-10, crown_y - 10),
		Vector2(0, crown_y - 26), Vector2(10, crown_y - 10), Vector2(24, crown_y - 22), Vector2(20, crown_y)])
	var crown_line := crown.duplicate()
	crown_line.append(crown[0])
	draw_polyline(crown_line, Color(0.85, 0.55, 0.1), 5, true)
	draw_colored_polygon(crown, GOLD)
	draw_circle(Vector2(0, crown_y - 27), 5, Cute.PINK)
	draw_circle(Vector2(-24, crown_y - 22), 3.5, Cute.SKY)
	draw_circle(Vector2(24, crown_y - 22), 3.5, Cute.SKY)
	# 팔 (근육 단계에 따라 굵어져요)
	var arm_w := 9.0 + arm_level * 6.0
	var shoulder := Vector2(30 * f, -64)
	var hand := shoulder + Vector2(26 * f, 10)
	match pose:
		Pose.SWING:
			hand = shoulder + Vector2(40 * f, -6)
		Pose.CHARGE:
			hand = shoulder + Vector2(-10 * f, -26)
		Pose.CHEER:
			hand = shoulder + Vector2(6 * f, -44)
	draw_line(shoulder, hand, dark, arm_w + 4)
	draw_line(shoulder, hand, body, arm_w)
	if arm_level > 0:
		draw_circle(shoulder.lerp(hand, 0.45) + Vector2(0, -arm_w * 0.4), arm_w * 0.7, body)
	# 검
	var blade_dir := Vector2(0.5 * f, -1).normalized()
	if pose == Pose.SWING:
		blade_dir = Vector2(f, 0.15).normalized()
	var blade_col := Color(0.85, 0.9, 0.95) if sword_level < 5 else GOLD
	draw_line(hand, hand + blade_dir * 70, Color(0.45, 0.5, 0.62), 12)
	draw_circle(hand + blade_dir * 70, 6, Color(0.45, 0.5, 0.62))
	draw_line(hand, hand + blade_dir * 70, blade_col, 8)
	draw_circle(hand + blade_dir * 70, 4, blade_col)
	draw_line(hand - blade_dir.orthogonal() * 12, hand + blade_dir.orthogonal() * 12, dark, 6)
	if sword_level >= 1:
		draw_circle(hand + blade_dir * 70, 5, Color(1, 1, 0.8, 0.8))
	if pose == Pose.SWING:
		draw_arc(hand, 74, -1.0 if f > 0 else PI - 0.6, 0.6 if f > 0 else PI + 1.0, 12, Color(1, 1, 1, 0.6), 6)
	# 사슬 무기 (반대 팔)
	if show_chain:
		var other := Vector2(-28 * f, -60)
		var ball := other + Vector2(-20 * f, 34)
		if pose == Pose.CHARGE:
			ball = other + Vector2(cos(_t * 16) * 40, sin(_t * 16) * 40 - 30)
		var steps := 5
		for i in steps:
			draw_circle(other.lerp(ball, float(i) / steps), 3.5, Color(0.55, 0.55, 0.6))
		draw_circle(ball, 13, Color(0.35, 0.6, 0.3))
		for i in 6:
			var a := TAU * i / 6.0
			draw_line(ball + Vector2(cos(a), sin(a)) * 11, ball + Vector2(cos(a), sin(a)) * 19, Color(0.3, 0.45, 0.25), 3)
		if charge > 0.0:
			draw_arc(Vector2(0, -150), 22, -PI / 2, -PI / 2 + TAU * charge, 24, Color(0.4, 1, 0.5) if charge >= 1.0 else Color(0.8, 1, 0.8), 6)
	draw_set_transform(Vector2.ZERO)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)
