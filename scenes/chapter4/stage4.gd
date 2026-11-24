extends "res://scripts/stage_base.gd"
## 4장 '성벽 돌파' 스테이지예요.
## 드래곤 본거지 아래를 막은 단단한 벽돌 성벽을 부숴요. 나란한 두 줄을 위에서 아래까지 뚫으면 성공이에요.
##
## 조작 (2장에서 익힌 조작):
## - 땅을 톡: 그곳으로 걸어가요
## - 벽돌을 톡: 아래 두 줄은 검으로 쳐요 (멀면 그 앞으로 걸어가요)
## - 꾹 눌렀다 떼기: 사슬 무기의 초록 소용돌이가 왕자 위쪽 벽돌을 "콰지직" 부숴요 (원작 그림)
## - 옆으로 쓸기: 구르기 (대포알 피하기)
## 규칙 숫자는 stage4_rules.gd에 모여 있어요.

const Rules := preload("res://scenes/chapter4/stage4_rules.gd")
const Prince := preload("res://scripts/art/prince.gd")
const Backdrop := preload("res://scripts/art/backdrop.gd")
const Gesture := preload("res://scripts/gesture.gd")

const GROUND_Y := 600.0

var rules: Rules
var prince: Node2D
var gesture := Gesture.new()
var _draw_node: Node2D
var _vortex_fx: Array = []      # {"x", "t"}
var _time_label: Label
var _hearts_label: Label
var _info_label: Label


func _init() -> void:
	chapter = 4


func _setup() -> void:
	rules = Rules.new()
	world.add_child(Backdrop.new("wall"))
	_draw_node = Node2D.new()
	_draw_node.draw.connect(_draw_wall)
	world.add_child(_draw_node)
	prince = Prince.new()
	prince.position = Vector2(rules.prince_x, GROUND_Y)
	world.add_child(prince)
	hud_bar(Vector2(0, 0), Vector2(1280, 96))
	_time_label = hud_label(Vector2(24, 12), 34)
	_hearts_label = hud_label(Vector2(220, 12), 34, Color(1, 0.55, 0.6))
	_info_label = hud_label(Vector2(24, 54), 26)
	_update_hud()


func use_seed(s: int) -> void:
	rules = Rules.new(s)
	prince.position.x = rules.prince_x


func _intro_pages() -> Array:
	return [
		"굴 끝에 드래곤의 본거지가 있었어요.\n그런데 그 아래를 단단한 벽돌 성벽이 막고 있었어요.\n성벽 위에는 대포가 있었어요.",
		"어떻게 할까요?\n\n• 땅을 톡: 그쪽으로 걸어가요\n• 아래 두 줄 벽돌을 톡: 검으로 쳐요\n• 꾹 눌렀다 떼기: 사슬 무기의 초록 소용돌이가 왕자 위 벽돌을 부숴요\n  (벽돌이 없는 줄에서 쏘면 성벽 위 대포도 부서져요)\n• 옆으로 쓱: 굴러서 대포알을 피해요 (땅의 빨간 그림자를 보세요)\n\n나란한 두 줄을 위부터 아래까지 뚫으면 성공! 하트 %d개, %s" % [Rules.HEARTS, time_text(Rules.TIME_LIMIT)],
	]


func _on_paused() -> void:
	gesture.reset()
	prince.charge = 0.0


# ------------------------------------------------------------------ 진행

func _play_process(delta: float) -> void:
	gesture.tick(delta)
	for e in rules.tick(delta):
		match e.type:
			"land":
				_float_small(Vector2(e.x - 40, GROUND_Y - 60), "쾅", Color(1, 0.8, 0.5))
			"hurt":
				prince.play_pose(Prince.Pose.HURT, 0.4)
				prince.blink = Rules.HURT_INVULN
				float_text(Vector2(rules.prince_x - 30, GROUND_Y - 220), "아야!", Color(1, 0.6, 0.6))
				shake()
	if gesture.is_holding():
		prince.charge = Rules.charge_ratio(gesture.held)
		prince.pose = Prince.Pose.CHARGE
	elif prince.pose == Prince.Pose.CHARGE:
		prince.pose = Prince.Pose.IDLE
		prince.charge = 0.0
	prince.position.x = rules.prince_x
	if rules.walk_target != rules.prince_x:
		prince.facing = signf(rules.walk_target - rules.prince_x)
	if rules.is_rolling() and prince.pose != Prince.Pose.ROLL:
		prince.play_pose(Prince.Pose.ROLL, Rules.ROLL_INVULN)
	for fx in _vortex_fx.duplicate():
		fx.t += delta
		if fx.t > 0.6:
			_vortex_fx.erase(fx)
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
		"tap":
			tap_at(g.pos)
		"swipe":
			if absf(g.dir.x) >= absf(g.dir.y):
				do_roll(g.dir.x)
		"hold":
			release_chain(g.held)


func tap_at(p: Vector2) -> void:
	var b := Rules.brick_at(p)
	if b.x >= 0 and rules.bricks[b.x][b.y] > 0:
		if rules.sword_hit(b.x, b.y):
			prince.facing = signf(Rules.col_center_x(b.x) - rules.prince_x) if Rules.col_center_x(b.x) != rules.prince_x else prince.facing
			prince.play_pose(Prince.Pose.SWING, 0.18)
			_float_small(p + Vector2(-20, -40), "탁!" if rules.bricks[b.x][b.y] > 0 else "와르르!", Color(1, 1, 0.8))
			return
		if b.y < Rules.ROWS - Rules.SWORD_ROWS:
			_float_small(p + Vector2(-60, -40), "검이 안 닿아요", Color(1, 0.85, 0.6))
		rules.walk_to(Rules.col_center_x(b.x))
		return
	rules.walk_to(p.x)


func do_roll(dir: float) -> void:
	if rules.roll(dir):
		prince.facing = signf(dir)
		prince.play_pose(Prince.Pose.ROLL, Rules.ROLL_INVULN)


func release_chain(held: float) -> void:
	prince.charge = 0.0
	if Rules.charge_ratio(held) < 1.0:
		float_text(Vector2(rules.prince_x - 90, GROUND_Y - 240), "힘을 더 모아요", Color(1, 0.9, 0.7), 28)
		return
	var r := rules.vortex()
	prince.play_pose(Prince.Pose.SWING, 0.3)
	_vortex_fx.append({"x": Rules.col_center_x(r.col), "t": 0.0})
	if r.cannon:
		float_text(Vector2(Rules.col_center_x(r.col) - 80, 60), "대포가 부서졌어요!", Color(0.6, 1, 0.6), 34)
	if r.hit > 0 or r.cannon:
		float_text(Vector2(Rules.col_center_x(r.col) - 70, 300), "콰지직!", Color(0.5, 1, 0.5), 46)
		shake(6)


func _win() -> void:
	phase = Phase.OUTRO
	_refresh_pause_button()
	float_text(Vector2(430, 300), "성벽에 구멍이 뚫렸어요!", Color(1, 0.95, 0.6), 44)
	rules.balls.clear()
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.finished.connect(func() -> void:
		var lines := "남은 하트 %d · 남은 시간 %s\n부순 벽돌 %d개 · 부순 대포 %d개" % [
			rules.hearts, time_text(rules.time_left), rules.bricks_broken, rules.cannons_broken]
		finish_win(rules.star_rating(), "성벽 돌파!", lines))


func _fail() -> void:
	if rules.fail_reason() == Rules.FailReason.HEARTS:
		finish_fail("대포알에 하트를 모두 잃었어요.", "땅에 빨간 그림자가 보이면 옆으로 쓱 굴러요. 대포를 먼저 부수는 것도 방법이에요.")
	else:
		finish_fail("시간 안에 구멍을 뚫지 못했어요.", "위쪽 벽돌은 검이 안 닿아요. 꾹 눌러 초록 소용돌이로 부수고, 한 곳에 나란히 두 줄을 집중해요.")


func _outro_pages() -> Array:
	return [
		"성벽에 구멍이 뚫렸어요!\n그런데 성벽 뒤에는 똥 무사들과\n뿔 달린 똥 대마왕이 기다리고 있었어요.\n\n5장 '무사들과 대마왕'으로 이어져요.",
	]


# ------------------------------------------------------------------ 그리기

var _brick_box := {}


## 둥근 벽돌 모양 (귀여운 디자인 제안)
func _brick_style(col: Color) -> StyleBoxFlat:
	var key := col.to_html()
	if not _brick_box.has(key):
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(3)
		sb.border_width_bottom = 6
		sb.border_color = col.darkened(0.3)
		_brick_box[key] = sb
	return _brick_box[key]


func _draw_wall() -> void:
	var n := _draw_node
	# 성벽 뒤 어둠
	n.draw_rect(Rect2(Rules.WALL_LEFT, Rules.WALL_TOP, Rules.COLS * Rules.BRICK_W, Rules.ROWS * Rules.BRICK_H), Color(0.3, 0.2, 0.36))
	for c in Rules.COLS:
		for r in Rules.ROWS:
			var hp: int = rules.bricks[c][r]
			if hp <= 0:
				continue
			var rect := Rules.brick_rect(c, r).grow(-3)
			var base := Color(0.95, 0.6, 0.5) if r >= Rules.ROWS - Rules.SWORD_ROWS else Color(0.86, 0.52, 0.46)
			n.draw_style_box(_brick_style(base), rect)
			n.draw_rect(Rect2(rect.position + Vector2(10, 8), Vector2(22, 6)), Color(1, 1, 1, 0.35))
			if hp < Rules.BRICK_HP:
				n.draw_line(rect.position + Vector2(20, 10), rect.get_center(), Color(0.2, 0.08, 0.05), 3)
			if hp == 1:
				n.draw_line(rect.get_center(), rect.end - Vector2(15, 8), Color(0.2, 0.08, 0.05), 3)
	# 성벽 위 대포
	for c in Rules.CANNON_COLS:
		var x := Rules.col_center_x(c)
		if rules.cannons[c]:
			n.draw_rect(Rect2(x - 40, Rules.WALL_TOP - 30, 80, 30), Color(0.7, 0.52, 0.42))
			n.draw_line(Vector2(x, Rules.WALL_TOP - 40), Vector2(x + 10, Rules.WALL_TOP - 90), Color(0.36, 0.34, 0.45), 24)
			n.draw_circle(Vector2(x + 10, Rules.WALL_TOP - 90), 12, Color(0.36, 0.34, 0.45))
			n.draw_circle(Vector2(x, Rules.WALL_TOP - 40), 28, Color(0.36, 0.34, 0.45))
			n.draw_circle(Vector2(x - 9, Rules.WALL_TOP - 50), 7, Color(1, 1, 1, 0.3))
			# 심술 난 대포 얼굴 (제안)
			n.draw_line(Vector2(x - 14, Rules.WALL_TOP - 46), Vector2(x - 4, Rules.WALL_TOP - 42), Color.WHITE, 3)
			n.draw_line(Vector2(x + 14, Rules.WALL_TOP - 46), Vector2(x + 4, Rules.WALL_TOP - 42), Color.WHITE, 3)
			n.draw_circle(Vector2(x - 8, Rules.WALL_TOP - 37), 3.5, Color.WHITE)
			n.draw_circle(Vector2(x + 8, Rules.WALL_TOP - 37), 3.5, Color.WHITE)
		else:
			n.draw_rect(Rect2(x - 40, Rules.WALL_TOP - 16, 80, 16), Color(0.6, 0.45, 0.38))
	# 대포알: 땅에 빨간 그림자, 위에서 떨어지는 알
	for b in rules.balls:
		var k: float = 1.0 - b.left / Rules.CANNON_WARN
		n.draw_circle(Vector2(b.x, GROUND_Y + 10), Rules.BALL_RADIUS * (0.4 + 0.6 * k), Color(1, 0.15, 0.1, 0.25 + 0.3 * k))
		n.draw_arc(Vector2(b.x, GROUND_Y + 10), Rules.BALL_RADIUS, 0, TAU, 32, Color(1, 0.3, 0.2, 0.7), 3)
		var from_x: float = Rules.col_center_x(b.from)
		var bp := Vector2(lerpf(from_x, b.x, k), lerpf(Rules.WALL_TOP - 90, GROUND_Y - 20, k * k))
		n.draw_circle(bp, 22, Color(0.36, 0.34, 0.45))
		n.draw_circle(bp + Vector2(-7, -7), 6, Color(1, 1, 1, 0.35))
	# 초록 소용돌이
	for fx in _vortex_fx:
		var y: float = lerpf(GROUND_Y - 120, Rules.WALL_TOP - 60, clampf(fx.t / 0.4, 0, 1))
		for i in 3:
			n.draw_arc(Vector2(fx.x, y), 24 + i * 14, fx.t * 20 + i, fx.t * 20 + i + 4.5, 16, Color(0.3, 0.95, 0.4, 1.0 - fx.t), 7)
	# 검이 닿는 범위 표시
	n.draw_line(Vector2(rules.prince_x - Rules.SWORD_REACH, GROUND_Y + 6), Vector2(rules.prince_x + Rules.SWORD_REACH, GROUND_Y + 6), Color(1, 1, 1, 0.25), 4)


func _float_small(p: Vector2, text: String, color: Color) -> void:
	float_text(p, text, color, 26)


func _update_hud() -> void:
	if not _time_label:
		return
	_time_label.text = "⏱ " + time_text(rules.time_left)
	_hearts_label.text = "♥".repeat(rules.hearts) + "♡".repeat(Rules.HEARTS - rules.hearts)
	_info_label.text = "4장 성벽 돌파 · 부순 벽돌 %d · 남은 대포 %d" % [rules.bricks_broken, rules.live_cannons().size()]
