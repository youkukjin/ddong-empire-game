extends "res://scripts/stage_base.gd"
## 3장 '구멍 탐험' 스테이지예요.
## 일주일 동안 준비를 마친 똥 왕자가 수상한 구멍으로 들어가 드래곤의 본거지를 찾아요.
##
## 조작 (제안):
## - 톡 (또는 위로 쓸기): 뛰어오르기 (바위, 구덩이, 높이 있는 반짝이는 돌)
## - 아래로 쓸기: 숙이기 (낮은 천장)
## - 갈림길에서 위/아래로 쓸기: 보라색 자국이 있는 굴 고르기
## 규칙 숫자는 stage3_rules.gd에 모여 있어요.

const Rules := preload("res://scenes/chapter3/stage3_rules.gd")
const Prince := preload("res://scripts/art/prince.gd")
const Backdrop := preload("res://scripts/art/backdrop.gd")
const Gesture := preload("res://scripts/gesture.gd")
const View3D := preload("res://scenes/chapter3/view3d_ch3.gd")

const PRINCE_X := 260.0
const GROUND_Y := 600.0
const PURPLE := Color(0.55, 0.28, 0.78)

var rules: Rules
var prince: Node2D
var gesture := Gesture.new()
var course_seed := 0          # 0이면 판마다 다른 굴 (자동 확인은 숫자를 넣어요)

var _draw_node: Node2D
var _hearts_label: Label
var _time_label: Label
var _info_label: Label
var _hint_label: Label


func _init() -> void:
	chapter = 3


func _setup() -> void:
	rules = Rules.new(course_seed)
	add_view3d(View3D, "tunnel")
	world.add_child(Backdrop.new("tunnel"))
	_draw_node = Node2D.new()
	_draw_node.draw.connect(_draw_course)
	world.add_child(_draw_node)
	prince = Prince.new()
	prince.position = Vector2(PRINCE_X, GROUND_Y)
	prince.show_chain = false
	world.add_child(prince)
	hud_bar(Vector2(0, 0), Vector2(1280, 96))
	_time_label = hud_label(Vector2(24, 12), 34)
	_hearts_label = hud_label(Vector2(220, 12), 34, Color(1, 0.55, 0.6))
	_info_label = hud_label(Vector2(24, 54), 26)
	_hint_label = hud_label(Vector2(330, 120), 34, Color(1, 0.9, 0.5))
	_update_hud()


## 자동 확인용: 굴 모양을 정해서 다시 만들어요.
func use_seed(s: int) -> void:
	course_seed = s
	rules = Rules.new(s)
	_update_hud()


func _intro_pages() -> Array:
	return [
		"일주일 뒤, 준비를 마친 똥 왕자는\n검을 들고 수상한 구멍 앞에 섰어요.",
		"구멍 안은 어둡고 구불구불했어요.\n이 굴 어딘가에 드래곤의 본거지가 있을 거예요.",
		"어떻게 할까요?\n\n왕자는 저절로 달려요.\n• 화면을 톡: 뛰어서 바위와 구덩이를 넘어요\n• 아래로 쓱: 숙여서 낮은 천장 밑을 지나요\n• 갈림길: 보라색 자국이 있는 굴 쪽으로 위나 아래로 쓱\n  (틀리면 막다른 길이라 %d초를 잃어요)\n\n하트 %d개, %s 안에 본거지 입구까지 가면 성공이에요." % [int(Rules.WRONG_PATH_PENALTY), Rules.HEARTS, time_text(Rules.TIME_LIMIT)],
	]


func _on_paused() -> void:
	gesture.reset()


# ------------------------------------------------------------------ 진행

func _play_process(delta: float) -> void:
	gesture.tick(delta)
	for e in rules.tick(delta):
		match e.type:
			"gem":
				float_text(Vector2(PRINCE_X - 10, GROUND_Y - 220), "반짝!", Color(1, 0.95, 0.5), 28)
			"hit":
				prince.play_pose(Prince.Pose.HURT, 0.4)
				prince.blink = Rules.HURT_INVULN
				impact(Vector2(PRINCE_X + 30, GROUND_Y - 80), "쾅!" if e.kind != Rules.Kind.PIT else "으악!", Color(1, 0.45, 0.3), 1.0)
			"fork_ok":
				float_text(Vector2(PRINCE_X + 60, 300), "맞는 길이에요!", Color(0.8, 0.6, 1), 40)
			"fork_wrong":
				float_text(Vector2(PRINCE_X + 60, 300), "막다른 길! 돌아와요 (-%d초)" % int(Rules.WRONG_PATH_PENALTY), Color(1, 0.7, 0.5), 36)
				impact(Vector2(PRINCE_X + 120, 400), "쿵!", Color(1, 0.6, 0.4), 0.8)
	prince.position.y = GROUND_Y - rules.jump_height()
	if rules.is_ducking():
		prince.pose = Prince.Pose.ROLL
	elif prince.pose == Prince.Pose.ROLL:
		prince.pose = Prince.Pose.IDLE
	_update_hud()
	_draw_node.queue_redraw()
	match rules.outcome():
		Rules.Outcome.WIN:
			_win()
		Rules.Outcome.FAIL:
			_fail()


func _play_input(event: InputEvent) -> void:
	var g := gesture.feed(event)
	if g.is_empty():
		return
	match g.type:
		"tap", "hold":
			do_jump()
		"swipe":
			var dir: Vector2 = g.dir
			if absf(dir.y) < absf(dir.x):
				return
			if not rules.upcoming_fork().is_empty():
				choose(Rules.Side.UP if dir.y < 0 else Rules.Side.DOWN)
			elif dir.y > 0:
				do_duck()
			else:
				do_jump()


func do_jump() -> void:
	if rules.jump():
		Sound.play("jump")


func do_duck() -> void:
	if rules.duck():
		Sound.play("duck")


func choose(side: int) -> void:
	if rules.choose(side):
		float_text(Vector2(PRINCE_X + 80, 200 if side == Rules.Side.UP else 420), "이쪽!", Color(1, 1, 0.7))


func _win() -> void:
	phase = Phase.OUTRO
	_refresh_pause_button()
	_hint_label.text = ""
	float_text(Vector2(420, 260), "본거지 입구를 찾았어요!", Color(1, 0.9, 0.6), 44)
	var tw := create_tween()
	tw.tween_property(prince, "position:x", 1100.0, 1.2)
	tw.finished.connect(func() -> void:
		var lines := "남은 하트 %d · 반짝이는 돌 %d / %d개\n맞힌 갈림길 %d / %d · 남은 시간 %s" % [
			rules.hearts, rules.gems, rules.gem_total, rules.forks.size() - rules.wrong_forks, rules.forks.size(), time_text(rules.time_left)]
		finish_win(rules.star_rating(), "찾았어요!", lines))


func _fail() -> void:
	_hint_label.text = ""
	if rules.fail_reason() == Rules.FailReason.HEARTS:
		finish_fail("하트를 모두 잃었어요.", "바위와 구덩이는 톡, 낮은 천장은 아래로 쓱! 장애물이 왕자 바로 앞에 왔을 때 해요.")
	else:
		finish_fail("시간 안에 본거지를 찾지 못했어요.", "갈림길에서는 보라색 자국이 있는 굴을 골라요. 틀리면 %d초를 잃어요." % int(Rules.WRONG_PATH_PENALTY))


func _outro_pages() -> Array:
	return [
		"굴 끝에서 드래곤의 본거지가 보였어요.\n그런데 그 아래를 단단한 성벽이 막고 있었어요.\n\n4장 '성벽 돌파'로 이어져요.",
	]


# ------------------------------------------------------------------ 그리기

func _sx(world_x: float) -> float:
	return PRINCE_X + (world_x - rules.distance)


func _draw_course() -> void:
	var n := _draw_node
	if view3d:
		return      # 3D가 굴과 장애물을 그려요
	# 굴 벽 무늬가 지나가요
	var off := fmod(rules.distance, 160.0)
	for i in 10:
		var x := i * 160.0 - off
		n.draw_circle(Vector2(x + 40, 180 + (i % 3) * 40), 18, Color(0.58, 0.43, 0.34))
		n.draw_circle(Vector2(x + 110, 640 + (i % 2) * 30), 14, Color(0.76, 0.6, 0.46))
		if i % 3 == 1:
			n.draw_circle(Vector2(x + 90, 330), 8, Color(1, 0.9, 0.6, 0.35))
	for it in rules.items:
		var x := _sx(it.x)
		if x < -100 or x > 1400:
			continue
		match it.kind:
			Rules.Kind.ROCK:
				n.draw_circle(Vector2(x, GROUND_Y - 30), 43, Color(0.5, 0.48, 0.55))
				n.draw_circle(Vector2(x, GROUND_Y - 30), 40, Color(0.72, 0.7, 0.78))
				n.draw_circle(Vector2(x - 14, GROUND_Y - 46), 10, Color(1, 1, 1, 0.5))
				n.draw_circle(Vector2(x - 10, GROUND_Y - 28), 3.5, Cute.INK)
				n.draw_circle(Vector2(x + 10, GROUND_Y - 28), 3.5, Cute.INK)
				n.draw_arc(Vector2(x, GROUND_Y - 18), 5, PI + 0.4, TAU - 0.4, 6, Cute.INK, 2)
			Rules.Kind.PIT:
				n.draw_rect(Rect2(x - 55, GROUND_Y, 110, 120), Color(0.2, 0.12, 0.14))
				n.draw_rect(Rect2(x - 55, GROUND_Y, 110, 8), Color(0.5, 0.35, 0.3))
			Rules.Kind.LOW:
				n.draw_rect(Rect2(x - 70, 96, 140, 384), Color(0.6, 0.44, 0.34))
				for k in 4:
					n.draw_circle(Vector2(x - 52 + k * 35, 480), 18, Color(0.6, 0.44, 0.34))
			Rules.Kind.GEM, Rules.Kind.GEM_HIGH:
				if it.done:
					continue
				var y := GROUND_Y - 50.0 if it.kind == Rules.Kind.GEM else GROUND_Y - 200.0
				n.draw_circle(Vector2(x, y), 30, Color(0.7, 0.95, 1, 0.3))
				n.draw_colored_polygon(PackedVector2Array([Vector2(x, y - 22), Vector2(x + 16, y), Vector2(x, y + 22), Vector2(x - 16, y)]), Color(0.6, 0.95, 1))
				n.draw_colored_polygon(PackedVector2Array([Vector2(x, y - 22), Vector2(x + 16, y), Vector2(x, y)]), Color(0.85, 1, 1))
				Cute.sparkle(n, Vector2(x + 18, y - 20), 7, Color(1, 1, 1, 0.9))
	for f in rules.forks:
		var x := _sx(f.x)
		if x < -300 or x > 1500:
			continue
		# 갈림길: 바위벽에 굴 두 개 (위, 아래)
		n.draw_rect(Rect2(x - 20, 96, 400, GROUND_Y - 96), Color(0.56, 0.4, 0.31))
		var up := Rect2(x - 10, 170, 220, 150)
		var down := Rect2(x - 10, 420, 220, 180)
		n.draw_rect(up, Color(0.22, 0.14, 0.16))
		n.draw_rect(down, Color(0.22, 0.14, 0.16))
		var good: Rect2 = up if f.correct == Rules.Side.UP else down
		# 보라색 자국 (제안: 드래곤이 지나간 흔적)
		for k in 4:
			n.draw_circle(good.position + Vector2(30 + k * 50, good.size.y - 20 - (k % 2) * 16), 12, PURPLE)
		n.draw_rect(good.grow(6), Color(PURPLE, 0.5), false, 6)
		if f.chosen != Rules.Side.NONE and not f.resolved:
			var pick: Rect2 = up if f.chosen == Rules.Side.UP else down
			n.draw_rect(pick.grow(12), Color(1, 1, 0.6), false, 6)
	# 끝: 본거지 입구
	var end_x := _sx(rules.total_length())
	if end_x < 1500:
		n.draw_rect(Rect2(end_x, 96, 600, GROUND_Y - 96), Color(0.4, 0.26, 0.5))
		n.draw_circle(Vector2(end_x + 120, 380), 150, Color(0.58, 0.38, 0.7))
		n.draw_string(ThemeDB.fallback_font, Vector2(end_x + 30, 250), "본거지", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(1, 0.85, 1))


func _update_hud() -> void:
	if not _time_label:
		return
	_time_label.text = "남은 시간 " + time_text(rules.time_left)
	_hearts_label.text = "♥".repeat(rules.hearts) + "♡".repeat(Rules.HEARTS - rules.hearts)
	var pct := int(100.0 * rules.distance / rules.total_length())
	_info_label.text = "3장 구멍 탐험 · 간 거리 %d%% · 반짝이는 돌 %d" % [pct, rules.gems]
	var f := rules.upcoming_fork()
	if not f.is_empty() and phase == Phase.PLAY:
		_hint_label.text = "갈림길! 보라색 자국 쪽으로 ↑ 또는 ↓ 쓸어요"
	else:
		_hint_label.text = ""
