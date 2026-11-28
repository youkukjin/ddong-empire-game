extends "res://scripts/stage_base.gd"
## 8장 '평화' 스테이지예요 (마지막 장).
## 드래곤이 사라진 똥 제국을 다시 평화롭게 만들어요. 시간 제한과 실패가 없는 쉬어 가는 장이에요.
## 집을 고치고, 남은 불씨를 끄고, 돔 대피소의 백성을 고친 집으로 데려오면 해가 떠요.
## 할 일 종류는 (제안)이에요. 규칙은 stage8_rules.gd에 있어요.

const Rules := preload("res://scenes/chapter8/stage8_rules.gd")
const Prince := preload("res://scripts/art/prince.gd")
const Backdrop := preload("res://scripts/art/backdrop.gd")
const Gesture := preload("res://scripts/gesture.gd")
const View3D := preload("res://scenes/chapter8/view3d_ch8.gd")

var rules: Rules
var prince: Node2D
var backdrop: Node2D
var _draw_node: Node2D
var _status: Label
var _drag := {}               # {"kind": "citizen"|"sweep", "pos", "last", "trail"}


func _init() -> void:
	chapter = 8


func _setup() -> void:
	rules = Rules.new()
	backdrop = Backdrop.new("town")
	add_view3d(View3D)
	world.add_child(backdrop)
	_draw_node = Node2D.new()
	_draw_node.draw.connect(_draw_town)
	world.add_child(_draw_node)
	prince = Prince.new()
	prince.position = Vector2(1100, 470)
	prince.god = true
	prince.scale = Vector2(0.8, 0.8)
	world.add_child(prince)
	hud_bar(Vector2(0, 0), Vector2(1280, 96))
	hud_label(Vector2(24, 12), 34).text = "8장 평화"
	_status = hud_label(Vector2(24, 54), 26)
	_update_hud()


func use_seed(s: int) -> void:
	rules = Rules.new(s)
	_update_hud()


func _intro_pages() -> Array:
	return [
		"똥 드래곤이 사라졌어요.\n돔 대피소에 숨어 있던 백성들이\n조심조심 밖을 내다봤어요.",
		"어떻게 할까요? (시간 제한이 없어요)\n\n• 무너진 집을 톡톡톡! 세 번 누르면 고쳐져요\n• 남은 불씨는 손가락으로 쓱 쓸어서 꺼요\n• 돔 대피소의 백성을 꾹 눌러 고친 집까지 끌어요\n\n모두 마치면 밤이 걷히고 해가 떠요.",
	]


func _on_paused() -> void:
	_end_drag()


# ------------------------------------------------------------------ 터치

func _play_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			press(event.position)
		else:
			release(event.position)
	elif event is InputEventScreenDrag:
		move(event.position)


func press(p: Vector2) -> void:
	if not _drag.is_empty():
		return
	if rules.citizens_left > 0 and p.distance_to(Rules.DOME_CENTER) < Rules.DOME_RADIUS:
		_drag = {"kind": "citizen", "pos": p}
		return
	var h := rules.house_at(p)
	if not h.is_empty() and h.hp > 0:
		rules.fix_tap(h)
		if h.hp > 0:
			impact(Vector2(h.x, Rules.HOUSE_Y - 90), "뚝딱!", Color(1, 0.9, 0.5), 0.5)
		else:
			impact(Vector2(h.x, Rules.HOUSE_Y - 110), "짠!", Color(1, 0.85, 0.3), 0.9)
			float_text(Vector2(h.x - 60, Rules.HOUSE_Y - 200), "다 고쳤어요!", Color(1, 0.95, 0.6), 28)
		prince.play_pose(Prince.Pose.SWING, 0.2)
		_after_change()
		return
	var trail := Line2D.new()
	trail.width = 18.0
	trail.default_color = Color(0.6, 0.85, 1.0, 0.7)
	trail.add_point(p)
	world.add_child(trail)
	_drag = {"kind": "sweep", "last": p, "trail": trail}


func move(p: Vector2) -> void:
	if _drag.is_empty():
		return
	if _drag.kind == "citizen":
		_drag.pos = p
	else:
		var n := rules.sweep(_drag.last, p)
		if n > 0:
			float_text(p + Vector2(-30, -60), "치익", Color(0.8, 0.9, 1), 26)
			_after_change()
		_drag.last = p
		var trail: Line2D = _drag.trail
		trail.add_point(p)
		if trail.get_point_count() > 14:
			trail.remove_point(0)


func release(p: Vector2) -> void:
	if _drag.is_empty():
		return
	if _drag.kind == "citizen":
		if rules.bring_home(p):
			float_text(p + Vector2(-50, -90), "우리 집이다!", Color(1, 0.9, 0.7), 28)
			_after_change()
		elif not rules.house_at(p).is_empty():
			float_text(p + Vector2(-90, -90), "집을 먼저 고쳐요", Color(1, 0.8, 0.6), 26)
	_end_drag()


func _end_drag() -> void:
	if not _drag.is_empty() and _drag.kind == "sweep":
		var trail: Line2D = _drag.trail
		trail.queue_free()
	_drag = {}


func _after_change() -> void:
	_update_hud()
	backdrop.tint = rules.progress()
	_draw_node.queue_redraw()
	if rules.done() and phase == Phase.PLAY:
		_win()


func _play_process(delta: float) -> void:
	rules.elapsed += delta
	_draw_node.queue_redraw()


func _win() -> void:
	phase = Phase.OUTRO
	_refresh_pause_button()
	_end_drag()
	Save.set_value("game_cleared", true)
	float_text(Vector2(420, 250), "해가 떴어요!", Color(1, 0.95, 0.6), 56)
	impact(Vector2(1000, 200), "번쩍!", Color(1, 0.85, 0.3), 1.6)
	prince.play_pose(Prince.Pose.CHEER, 2.0)
	var tw := create_tween()
	tw.tween_property(backdrop, "tint", 1.0, 1.0)
	tw.tween_interval(0.8)
	tw.finished.connect(func() -> void:
		finish_win(3, "평화!", "고친 집 %d채 · 끈 불씨 %d개 · 집으로 돌아간 백성 %d명\n걸린 시간 %s" % [
			Rules.HOUSES, Rules.EMBERS, Rules.CITIZENS, time_text(rules.elapsed)]))


func _outro_pages() -> Array:
	var stars := ""
	var total := 0
	for n in range(1, Chapters.COUNT + 1):
		var s := Save.best_stars(n)
		total += s
		stars += "%d장 %s %s\n" % [n, Chapters.title(n), "★".repeat(s) + "☆".repeat(3 - s)]
	return [
		"똥 제국에 다시 아침이 왔어요.\n백성들은 집으로 돌아가고,\n똥 제국은 다시 평화를 찾았어요.",
		"지금까지 모은 별\n\n%s\n모두 %d / 24개" % [stars, total],
		"끝\n\n\"똥제국의 위기\"를 끝까지 해 줘서 고마워요!\n(장 고르기에서 언제든 다시 할 수 있어요)",
	]


# ------------------------------------------------------------------ 그리기

func _draw_town() -> void:
	var n := _draw_node
	var font := ThemeDB.fallback_font
	if view3d:
		# 3D가 마을을 그려요. 남은 톡 수만 2D로 보여줘요.
		for h in rules.houses:
			if h.hp > 0:
				var r := Rules.house_rect(h)
				n.draw_string_outline(font, r.position + Vector2(r.size.x / 2 - 30, -70), "톡 ×%d" % h.hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 8, Color(0.07, 0.035, 0.05))
				n.draw_string(font, r.position + Vector2(r.size.x / 2 - 30, -70), "톡 ×%d" % h.hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 1, 0.7))
		return
	for h in rules.houses:
		var r := Rules.house_rect(h)
		var fixed: bool = h.hp <= 0
		var wall := Color(1.0, 0.88, 0.74) if fixed else Color(0.66, 0.58, 0.62)
		n.draw_rect(r, wall)
		var tilt: float = 0.0 if fixed else 18.0 * h.hp
		n.draw_colored_polygon(PackedVector2Array([
			r.position + Vector2(-14, tilt * 0.3), Vector2(r.get_center().x, r.position.y - 60 + tilt), r.position + Vector2(r.size.x + 14, 0)]), Cute.PINK if fixed else Color(0.5, 0.42, 0.5))
		n.draw_rect(Rect2(r.get_center().x - 18, r.end.y - 40, 36, 40), Color(0.72, 0.48, 0.32))
		n.draw_circle(Vector2(r.get_center().x, r.end.y - 40), 18, Color(0.72, 0.48, 0.32))
		if fixed:
			n.draw_rect(Rect2(r.position.x + 14, r.position.y + 20, 30, 26), Color(1, 0.9, 0.5))
			Cute.heart(n, Vector2(r.end.x - 26, r.position.y + 32), 9, Cute.PINK)
		else:
			n.draw_line(r.position + Vector2(20, 20), r.position + Vector2(60, 70), Color(0.35, 0.25, 0.3), 4)
			n.draw_string_outline(font, r.position + Vector2(r.size.x / 2 - 30, -70), "톡 ×%d" % h.hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 8, Color(0.36, 0.16, 0.26))
			n.draw_string(font, r.position + Vector2(r.size.x / 2 - 30, -70), "톡 ×%d" % h.hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 1, 0.7))
	for e in rules.embers:
		if e.out:
			n.draw_circle(e.pos, 10, Color(0.3, 0.3, 0.3, 0.6))
		else:
			var flick: float = 0.8 + 0.2 * sin(rules.elapsed * 10.0 + e.pos.x)
			n.draw_circle(e.pos, 26 * flick, Color(1, 0.45, 0.1, 0.8))
			n.draw_circle(e.pos, 13 * flick, Color(1, 0.85, 0.3))
			n.draw_circle(e.pos + Vector2(-5, -2), 2.5, Color(0.45, 0.1, 0.05))
			n.draw_circle(e.pos + Vector2(5, -2), 2.5, Color(0.45, 0.1, 0.05))
	# 돔 대피소 (1장)
	n.draw_arc(Rules.DOME_CENTER, Rules.DOME_RADIUS, PI, TAU, 32, Color(1, 0.86, 0.92, 0.95), 10)
	for i in rules.citizens_left:
		var p := Rules.DOME_CENTER + Vector2(-80 + (i % 4) * 50, -20 - (i / 4) * 50)
		_draw_citizen(n, p)
	if not _drag.is_empty() and _drag.kind == "citizen":
		_draw_citizen(n, _drag.pos)


func _draw_citizen(n: Node2D, p: Vector2) -> void:
	var cream := Color(0.98, 0.93, 0.82)
	n.draw_line(p + Vector2(0, -24), p + Vector2(0, 4), cream, 8)
	n.draw_line(p + Vector2(0, 4), p + Vector2(-8, 18), cream, 6)
	n.draw_line(p + Vector2(0, 4), p + Vector2(8, 18), cream, 6)
	var hc := p + Vector2(0, -38)
	n.draw_circle(hc, 15, Color(0.45, 0.28, 0.15))
	n.draw_circle(hc, 13.5, Color(0.68, 0.45, 0.26))
	Cute.happy_eye(n, hc + Vector2(-5, -1), 3.5, Color.WHITE)
	Cute.happy_eye(n, hc + Vector2(5, -1), 3.5, Color.WHITE)
	Cute.blush(n, hc + Vector2(-9, 6), 3)
	Cute.blush(n, hc + Vector2(9, 6), 3)


func _update_hud() -> void:
	if not _status:
		return
	_status.text = "고친 집 %d / %d · 끈 불씨 %d / %d · 집으로 간 백성 %d / %d" % [
		rules.fixed_houses(), Rules.HOUSES, rules.embers_out(), Rules.EMBERS, rules.citizens_home, Rules.CITIZENS]
