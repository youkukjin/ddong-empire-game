extends "res://scripts/stage_base.gd"
## 2장 '준비' 스테이지예요.
## 똥 왕자가 드래곤을 물리치려고 준비해요. 연습 네 가지를 차례로 통과하면 성공이에요.
##
## 1) 아령 들기: 줄어드는 고리가 가운데 원에 딱 맞을 때 톡 (리듬)
## 2) 검 연습: 튀어나온 표적을 톡톡 (단단한 표적은 두 번)
## 3) 사슬 무기 연습: 길게 눌러 힘을 모았다가, 움직이는 표적이 줄 위에 올 때 떼기
## 4) 구르기 연습: 굴러오는 공에 "!"가 뜨면 쓱 쓸어서 굴러 피하기
## 연습 종류와 숫자는 (제안)이에요. 숫자는 stage2_rules.gd에 모여 있어요.

const Rules := preload("res://scenes/chapter2/stage2_rules.gd")
const Prince := preload("res://scripts/art/prince.gd")
const Backdrop := preload("res://scripts/art/backdrop.gd")
const Gesture := preload("res://scripts/gesture.gd")

const PRINCE_POS := Vector2(300, 600)
const RING_CENTER := Vector2(760, 360)
const RING_TARGET := 60.0
const RING_START := 220.0
const LANE_Y := 520.0
const CHAIN_TARGET_X := 1060.0
const VORTEX_TIME := 0.45
const BALL_SPEED := 620.0

var rules: Rules
var prince: Node2D
var drill_active := false
var gesture := Gesture.new()

var _t := 0.0                 # 연습 시작부터 지난 시간
var _score := 0
var _count := 0               # 아령: 판정한 고리 / 사슬: 던진 수 / 구르기: 지나간 공
var _notes: Array = []        # 아령: {"time", "judged"}
var _targets: Array = []      # 검: {"pos", "life", "hp", "hard"}
var _spawn_left := 0.0
var _chain_target_y := 400.0
var _vortex := {}             # 사슬: {"t", "from", "to"}
var _balls: Array = []        # 구르기: {"x", "hit_time", "done"}
var _roll_start := -1.0
var _status: Label
var _drill_label: Label
var _draw_node: Node2D


func _init() -> void:
	chapter = 2


func _setup() -> void:
	rules = Rules.new()
	world.add_child(Backdrop.new("yard"))
	_draw_node = Node2D.new()
	_draw_node.draw.connect(_draw_drill)
	world.add_child(_draw_node)
	prince = Prince.new()
	prince.position = PRINCE_POS
	world.add_child(prince)
	hud_bar(Vector2(0, 0), Vector2(1280, 96))
	_drill_label = hud_label(Vector2(24, 12), 34)
	_status = hud_label(Vector2(24, 54), 26)
	_update_hud()


func _intro_pages() -> Array:
	return [
		"똥 드래곤이 다녀간 뒤,\n똥 왕자는 마음먹었어요.\n\"내가 드래곤을 물리칠 거야!\"",
		"그러려면 먼저 준비를 해야 해요.\n힘도 기르고, 검과 사슬 무기도 익히고,\n재빨리 피하는 법도 배워요.",
		"어떻게 할까요?\n\n연습 네 가지를 차례로 통과해요.\n• 아령 들기 • 검 연습 • 사슬 무기 연습 • 구르기 연습\n\n연습마다 별을 받고, 별을 많이 모을수록 좋아요.\n여기서 배운 조작은 뒤 장의 싸움에서 그대로 써요.",
	]


func _on_play_started() -> void:
	show_drill_intro()


func _can_pause() -> bool:
	return drill_active


# ------------------------------------------------------------------ 연습 안내

func show_drill_intro() -> void:
	drill_active = false
	_refresh_pause_button()
	_update_hud()
	var how := ""
	match rules.drill:
		Rules.Drill.DUMBBELL:
			how = "고리가 줄어들어 가운데 원에 딱 맞을 때 화면을 톡!\n딱 맞으면 2점, 조금 빗나가면 1점이에요. (고리 %d개)" % Rules.DUMBBELL_NOTES
		Rules.Drill.SWORD:
			how = "튀어나온 표적을 톡 눌러 검으로 쳐요.\n테두리가 두꺼운 단단한 표적은 두 번 쳐야 해요. (%d초)" % int(Rules.SWORD_TIME)
		Rules.Drill.CHAIN:
			how = "화면을 꾹 누르고 있으면 왕자 머리 위 고리가 차요.\n고리가 다 차면, 움직이는 표적이 초록 줄 위에 올 때 손을 떼요. (%d번)" % Rules.CHAIN_THROWS
		Rules.Drill.ROLL:
			how = "연습 공이 굴러와요. 공 위에 \"!\"가 뜨면 화면을 쓱 쓸어서 굴러요.\n너무 일찍 구르면 공에 맞아요. (공 %d개)" % Rules.ROLL_BALLS
	var t: Array = Rules.THRESHOLDS[rules.drill]
	how += "\n\n통과: %d점 · 별 2개: %d점 · 별 3개: %d점" % [t[0], t[1], t[2]]
	show_panel("%d/4 %s" % [int(rules.drill) + 1, Rules.DRILL_NAMES[rules.drill]], how, [["시작", begin_drill]])


func begin_drill() -> void:
	clear_overlay()
	drill_active = true
	_refresh_pause_button()
	gesture.reset()
	_t = 0.0
	_score = 0
	_count = 0
	_notes.clear()
	_targets.clear()
	_balls.clear()
	_vortex = {}
	_roll_start = -1.0
	_spawn_left = 0.3
	prince.charge = 0.0
	match rules.drill:
		Rules.Drill.DUMBBELL:
			for i in Rules.DUMBBELL_NOTES:
				_notes.append({"time": 1.5 + i * Rules.DUMBBELL_GAP, "judged": false})
		Rules.Drill.ROLL:
			for i in Rules.ROLL_BALLS:
				var gap := 2.2 if i < 5 else 1.6
				var at := 2.0 + (i * 2.2 if i < 5 else 5 * 2.2 + (i - 5) * gap)
				_balls.append({"hit_time": at, "done": false, "speed": BALL_SPEED if i < 5 else BALL_SPEED * 1.25})
	_update_hud()


func end_drill() -> void:
	drill_active = false
	prince.charge = 0.0
	_refresh_pause_button()
	var drill_name: String = Rules.DRILL_NAMES[rules.drill]
	if not rules.finish_drill(_score):
		var t: Array = Rules.THRESHOLDS[rules.drill]
		show_panel("조금 더!", "%s %d점이에요. %d점이면 통과해요.\n\n팁: %s" % [drill_name, _score, t[0], _drill_tip()], [
			["다시 연습", begin_drill],
			["처음으로", go_title],
		])
		return
	var s: int = rules.stars[rules.drill]
	var star_row := StarRow.new()
	star_row.custom_minimum_size = Vector2(360, 110)
	star_row.stars = s
	if rules.drill == Rules.Drill.ROLL:
		_win()
		return
	show_panel("%s 통과!" % drill_name, "%d점" % _score, [
		["다음 연습", _go_next_drill],
		["다시 연습", begin_drill],
	], star_row)


func _go_next_drill() -> void:
	rules.next_drill()
	show_drill_intro()


func _drill_tip() -> String:
	match rules.drill:
		Rules.Drill.DUMBBELL:
			return "고리를 보지 말고 박자를 세어 보세요. 고리는 1초마다 와요."
		Rules.Drill.SWORD:
			return "가운데쯤에 손가락을 두면 어느 표적이든 빨리 닿아요."
		Rules.Drill.CHAIN:
			return "고리가 다 찬 뒤에도 계속 누르고 있어도 돼요. 표적이 내려올 때를 기다려요."
	return "\"!\"가 뜨고 조금 있다가 구르면 딱 맞아요. 너무 일찍이면 무적 시간이 끝나요."


func _win() -> void:
	var lines := ""
	for d in Rules.Drill.values():
		lines += "%s: %s\n" % [Rules.DRILL_NAMES[d], "★".repeat(int(rules.stars.get(d, 0)))]
	lines += "모은 별 %d / 12개" % rules.total_stars()
	finish_win(rules.chapter_stars(), "준비 완료!", lines)


func _outro_pages() -> Array:
	return [
		"똥 왕자는 연습을 모두 마쳤어요.\n(제안: 연습 장면 글은 작가 확인 전이에요)",
		"일주일 동안 준비를 마친 똥 왕자는\n마을 근처의 수상한 구멍 앞에 섰어요.\n\n3장 '구멍 탐험'으로 이어져요.",
	]


func _before_restart() -> void:
	pass


# ------------------------------------------------------------------ 매 프레임

func _play_process(delta: float) -> void:
	if not drill_active:
		return
	_t += delta
	gesture.tick(delta)
	match rules.drill:
		Rules.Drill.DUMBBELL:
			_dumbbell_step()
		Rules.Drill.SWORD:
			_sword_step(delta)
		Rules.Drill.CHAIN:
			_chain_step()
		Rules.Drill.ROLL:
			_roll_step()
	_update_hud()
	_draw_node.queue_redraw()


func _dumbbell_step() -> void:
	for n in _notes:
		if not n.judged and _t > n.time + Rules.GOOD_WINDOW:
			n.judged = true
			_count += 1
			float_text(RING_CENTER + Vector2(-40, -120), "놓쳤어요", Color(1, 0.7, 0.6))
	if _count >= _notes.size():
		end_drill()


func _sword_step(delta: float) -> void:
	for t in _targets.duplicate():
		t.life -= delta
		if t.life <= 0.0:
			_targets.erase(t)
	_spawn_left -= delta
	if _spawn_left <= 0.0 and _t < Rules.SWORD_TIME - 0.5 and _targets.size() < 3:
		_spawn_left = Rules.SWORD_SPAWN_GAP
		var hard := rng.randf() < Rules.SWORD_HARD_CHANCE
		var pos := Vector2(rng.randf_range(560, 1180), rng.randf_range(200, 540))
		for i in 10:
			var ok := true
			for o in _targets:
				if o.pos.distance_to(pos) < 160:
					ok = false
			if ok:
				break
			pos = Vector2(rng.randf_range(560, 1180), rng.randf_range(200, 540))
		_targets.append({"pos": pos, "life": Rules.SWORD_TARGET_LIFE, "hp": 2 if hard else 1, "hard": hard})
	if _t >= Rules.SWORD_TIME:
		end_drill()


func _chain_step() -> void:
	_chain_target_y = 400.0 + sin(_t * 1.6) * 190.0
	prince.charge = Rules.charge_ratio(gesture.held) if gesture.is_holding() else 0.0
	prince.pose = Prince.Pose.CHARGE if gesture.is_holding() else (prince.pose if prince.pose != Prince.Pose.CHARGE else Prince.Pose.IDLE)
	if not _vortex.is_empty() and _t >= _vortex.t + VORTEX_TIME:
		var hit := absf(_chain_target_y - LANE_Y) < 70.0
		_vortex = {}
		if hit:
			_score += 1
			float_text(Vector2(CHAIN_TARGET_X - 80, _chain_target_y - 100), "콰지직!", Color(0.6, 1, 0.6), 40)
			shake(5)
		else:
			float_text(Vector2(CHAIN_TARGET_X - 80, LANE_Y - 100), "빗나갔어요", Color(1, 0.8, 0.6))
		if _count >= Rules.CHAIN_THROWS:
			end_drill()
	elif _vortex.is_empty() and _t >= Rules.CHAIN_TIME:
		end_drill()


func _roll_step() -> void:
	for b in _balls:
		if b.done or _t < b.hit_time:
			continue
		b.done = true
		_count += 1
		if Rules.roll_dodged(_roll_start, b.hit_time):
			_score += 1
			float_text(PRINCE_POS + Vector2(-40, -200), "피했어요!", Color(0.7, 1, 1))
		else:
			prince.play_pose(Prince.Pose.HURT, 0.4)
			prince.blink = 0.5
			float_text(PRINCE_POS + Vector2(-30, -200), "콩!", Color(1, 0.7, 0.6))
	if _count >= _balls.size():
		end_drill()


# ------------------------------------------------------------------ 터치

func _play_input(event: InputEvent) -> void:
	if not drill_active:
		return
	var g := gesture.feed(event)
	if g.is_empty():
		return
	match rules.drill:
		Rules.Drill.DUMBBELL:
			if g.type == "press":
				press_dumbbell()
		Rules.Drill.SWORD:
			if g.type == "press":
				press_sword(g.pos)
		Rules.Drill.CHAIN:
			if g.type == "hold" or g.type == "tap":
				release_chain(g.held)
		Rules.Drill.ROLL:
			if g.type == "swipe":
				do_roll()


func press_dumbbell() -> void:
	var best = null
	for n in _notes:
		if not n.judged and absf(_t - n.time) <= 0.4 and (best == null or absf(_t - n.time) < absf(_t - best.time)):
			best = n
	if best == null:
		return
	best.judged = true
	_count += 1
	var j := Rules.judge_tap(_t - best.time)
	_score += Rules.judge_points(j)
	match j:
		Rules.Judge.PERFECT:
			prince.play_pose(Prince.Pose.CHEER, 0.3)
			float_text(RING_CENTER + Vector2(-60, -120), "딱 좋아요!", Color(1, 0.9, 0.3), 40)
		Rules.Judge.GOOD:
			prince.play_pose(Prince.Pose.CHEER, 0.2)
			float_text(RING_CENTER + Vector2(-40, -120), "좋아요", Color(0.9, 1, 0.7))
		_:
			float_text(RING_CENTER + Vector2(-40, -120), "놓쳤어요", Color(1, 0.7, 0.6))
	if _count >= _notes.size():
		end_drill()


func press_sword(p: Vector2) -> void:
	for t in _targets:
		if t.pos.distance_to(p) <= 75.0:
			t.hp -= 1
			prince.play_pose(Prince.Pose.SWING, 0.18)
			if t.hp <= 0:
				_targets.erase(t)
				_score += 1
				float_text(t.pos + Vector2(-30, -80), "탁!", Color(1, 1, 0.7))
			else:
				t.life += 0.4
				float_text(t.pos + Vector2(-30, -80), "한 번 더!", Color(1, 0.85, 0.6), 28)
			return


func release_chain(held: float) -> void:
	prince.charge = 0.0
	if not _vortex.is_empty():
		return
	if Rules.charge_ratio(held) < 1.0:
		float_text(PRINCE_POS + Vector2(-90, -220), "힘을 더 모아요", Color(1, 0.9, 0.7), 28)
		return
	_count += 1
	prince.play_pose(Prince.Pose.SWING, 0.3)
	_vortex = {"t": _t}


func do_roll() -> void:
	if _roll_start >= 0.0 and _t < _roll_start + Rules.ROLL_INVULN + 0.15:
		return
	_roll_start = _t
	prince.play_pose(Prince.Pose.ROLL, Rules.ROLL_INVULN)


# ------------------------------------------------------------------ 그리기

func _draw_drill() -> void:
	if not drill_active:
		return
	var n := _draw_node
	var font := ThemeDB.fallback_font
	match rules.drill:
		Rules.Drill.DUMBBELL:
			# 아령 (원작 그림의 아령)
			var lift := 30.0 if prince.pose == Prince.Pose.CHEER else 0.0
			var bar_y := PRINCE_POS.y - 150 - lift
			n.draw_line(Vector2(PRINCE_POS.x - 90, bar_y), Vector2(PRINCE_POS.x + 90, bar_y), Color(0.3, 0.3, 0.35), 10)
			for sx in [-1, 1]:
				n.draw_rect(Rect2(PRINCE_POS.x + sx * 90 - 18, bar_y - 34, 36, 68), Color(0.25, 0.25, 0.3))
			n.draw_circle(RING_CENTER, RING_TARGET, Color(1, 0.9, 0.5, 0.35))
			n.draw_arc(RING_CENTER, RING_TARGET, 0, TAU, 48, Color(0.5, 0.3, 0.1), 6)
			for note in _notes:
				if note.judged:
					continue
				var left: float = note.time - _t
				if left > Rules.DUMBBELL_APPROACH or left < -Rules.GOOD_WINDOW:
					continue
				var r := RING_TARGET + (RING_START - RING_TARGET) * maxf(left, 0.0) / Rules.DUMBBELL_APPROACH
				n.draw_arc(RING_CENTER, r, 0, TAU, 64, Color(0.95, 0.45, 0.2), 8)
		Rules.Drill.SWORD:
			for t in _targets:
				var a := clampf(t.life / 0.3, 0.0, 1.0)
				n.draw_circle(t.pos, 56, Color(0.95, 0.95, 0.9, a))
				n.draw_circle(t.pos, 38, Color(0.9, 0.3, 0.3, a))
				n.draw_circle(t.pos, 18, Color(0.95, 0.95, 0.9, a))
				if t.hard:
					n.draw_arc(t.pos, 58, 0, TAU, 40, Color(0.35, 0.3, 0.3, a), 10 if t.hp > 1 else 4)
		Rules.Drill.CHAIN:
			n.draw_line(Vector2(PRINCE_POS.x + 60, LANE_Y), Vector2(1240, LANE_Y), Color(0.3, 0.9, 0.4, 0.6), 6)
			var tp := Vector2(CHAIN_TARGET_X, _chain_target_y)
			n.draw_rect(Rect2(tp - Vector2(40, 60), Vector2(80, 120)), Color(0.7, 0.5, 0.3))
			n.draw_circle(tp, 26, Color(0.9, 0.3, 0.3))
			if not _vortex.is_empty():
				var k := clampf((_t - _vortex.t) / VORTEX_TIME, 0.0, 1.0)
				var vp := Vector2(lerpf(PRINCE_POS.x + 60, CHAIN_TARGET_X, k), LANE_Y)
				for i in 3:
					n.draw_arc(vp, 20 + i * 12, _t * 12 + i, _t * 12 + i + 4.5, 16, Color(0.3, 0.9, 0.4), 6)
			n.draw_string(font, Vector2(820, 680), "남은 던지기 %d" % (Rules.CHAIN_THROWS - _count), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
		Rules.Drill.ROLL:
			for b in _balls:
				if b.done:
					continue
				var left: float = b.hit_time - _t
				var x: float = PRINCE_POS.x + left * b.speed
				if x > 1340:
					continue
				var bp := Vector2(x, PRINCE_POS.y - 36)
				n.draw_circle(bp, 36, Color(0.85, 0.5, 0.25))
				n.draw_arc(bp, 36, _t * 8, _t * 8 + 2, 12, Color(1, 0.8, 0.5), 5)
				if left <= Rules.ROLL_WARN:
					n.draw_string(font, bp + Vector2(-12, -60), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(1, 0.3, 0.2))


func _update_hud() -> void:
	if not _drill_label:
		return
	_drill_label.text = "2장 준비 · %d/4 %s" % [int(rules.drill) + 1, Rules.DRILL_NAMES[rules.drill]]
	if not drill_active:
		_status.text = "모은 별 %d개" % rules.total_stars()
		return
	match rules.drill:
		Rules.Drill.DUMBBELL:
			_status.text = "점수 %d · 고리 %d / %d" % [_score, _count, Rules.DUMBBELL_NOTES]
		Rules.Drill.SWORD:
			_status.text = "맞힌 표적 %d · 남은 시간 %s" % [_score, time_text(Rules.SWORD_TIME - _t)]
		Rules.Drill.CHAIN:
			_status.text = "맞힌 수 %d / %d · 남은 시간 %s" % [_score, Rules.CHAIN_THROWS, time_text(Rules.CHAIN_TIME - _t)]
		Rules.Drill.ROLL:
			_status.text = "피한 공 %d / %d" % [_score, Rules.ROLL_BALLS]


## 자동 확인용: 연습 시간을 직접 옮겨요.
func set_drill_time(t: float) -> void:
	_t = t


func drill_score() -> int:
	return _score


func chain_target_y() -> float:
	return _chain_target_y
