extends Node2D
## 1장 '등장' 스테이지예요.
## 밤중에 나타난 똥 드래곤을 피해, 3분 안에 백성 15명 중 12명 이상을 둥근 돔 대피소로 대피시켜요.
##
## 조작 (기획안):
## - 끌기: 백성을 누른 채 돔까지 끌어요. 불 위로는 지나갈 수 없어요.
## - 쓸기: 빈 곳에서 손가락으로 쓱 쓸면 지나간 불이 꺼져요. 한 번에 3개 이상이면 콤보 보너스.
## - 톡: 드래곤이 입을 벌리면 빛나는 코를 1.5초 안에 눌러요.
## 규칙 숫자는 stage1_rules.gd에 모여 있어요.

const Rules := preload("res://scenes/chapter1/stage1_rules.gd")
const Session := preload("res://scripts/game_session.gd")
const Save := preload("res://scripts/save_data.gd")
const CitizenScript := preload("res://scenes/chapter1/citizen.gd")
const FireScript := preload("res://scenes/chapter1/fire.gd")
const BeamScript := preload("res://scenes/chapter1/beam.gd")
const WorldBG := preload("res://scenes/chapter1/world_background.gd")
const Widget := preload("res://scenes/chapter1/hud_widgets.gd")
const TITLE_SCENE := "res://scenes/title/title_screen.tscn"
const STAGE_SCENE := "res://scenes/chapter1/stage1.tscn"
const CHAPTER2_SCENE := "res://scenes/chapter2/stage2.tscn"

const SPAWN_GAP := 1.2
const CREAM := Color(0.996, 0.949, 0.851)
const BROWN := Color(0.4, 0.239, 0.11)
const BUTTON_BROWN := Color(0.71, 0.482, 0.278)

enum Phase { INTRO, PLAY, OUTRO, RESULT }

@onready var background: Node2D = $World/Background
@onready var fires_root: Node2D = $World/Fires
@onready var citizens_root: Node2D = $World/Citizens
@onready var dragon: Node2D = $World/Dragon
@onready var beams_root: Node2D = $World/Beams
@onready var effects_root: Node2D = $World/Effects
@onready var hud_root: Control = $HUD/Root
@onready var overlay_root: Control = $Overlay/Root

var rules: Rules
var phase := Phase.INTRO
var rng := RandomNumberGenerator.new()
var paused := false

var _spawn_timer := 0.5
var _beam_timer := 0.0
var _mouth_timer := Rules.FIRST_MOUTH_TIME
var _touches := {}            # 손가락 번호 -> 끌기/쓸기 정보
var _pages: Array[String] = []
var _page_index := 0

var _moon: Widget
var _hearts: Widget
var _time_label: Label
var _rescued_label: Label
var _score_label: Label
var _pause_button: Button


func _ready() -> void:
	rng.randomize()
	rules = Rules.new(Session.hard_mode, Session.assist)
	var resumed := Session.resume_checkpoint and Session.has_checkpoint
	if resumed:
		rules.start_from_checkpoint(Session.checkpoint_time_left, Session.checkpoint_score)
		_mouth_timer = 6.0
	Session.resume_checkpoint = false
	dragon.nose_pressed.connect(_on_nose_pressed)
	dragon.nose_missed.connect(_on_nose_missed)
	_build_hud()
	_update_hud()
	background.rescued = rules.rescued
	if resumed:
		_pages = ["중간부터 다시 해요!\n\n백성 %d명을 구한 곳부터, 하트를 가득 채워서 시작해요." % rules.rescued]
	else:
		_pages = _intro_pages()
	_page_index = 0
	_show_page()


func _intro_pages() -> Array[String]:
	var how := "어떻게 할까요?\n\n" \
		+ "• 백성을 꾹 눌러 둥근 돔 대피소까지 끌어요\n" \
		+ "• 불은 손가락으로 쓱 쓸어서 꺼요 (한 번에 3개면 보너스!)\n" \
		+ "• 드래곤이 입을 벌리면 빛나는 코를 톡!\n" \
		+ "• 땅에 점선이 보이면 보라색 줄기가 와요. 백성을 빼 주세요\n\n" \
		+ "%s 안에 백성 %d명 이상을 구하면 성공이에요." % [_time_text(rules.time_limit), Rules.WIN_RESCUED]
	if rules.hard:
		how += "\n어려움 모드: 하트 1개로 도전해요!"
	return [
		"똥 제국의 마을은 평화로웠어요.",
		"그런데 어느 밤,\n가시 머리의 보라색 똥 드래곤이 긴 목을 내밀었어요!\n마을 곳곳에 불이 붙었어요.",
		how,
	]


# ------------------------------------------------------------------ 진행

func _start_play() -> void:
	phase = Phase.PLAY
	_clear_overlay()
	if rules.from_checkpoint:
		_spawn_fire(WorldBG.random_road_point(rng))
	else:
		for i in 2:
			_spawn_fire(WorldBG.random_road_point(rng))
	_beam_timer = 2.0


func _process(delta: float) -> void:
	if phase != Phase.PLAY:
		return
	rules.tick(delta)
	_spawn_step(delta)
	_beam_step(delta)
	_mouth_step(delta)
	_check_beam_hits()
	_update_hud()
	_check_outcome()


func _spawn_step(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	if rules.can_spawn(_citizens_on_field().size()):
		_spawn_citizen()
		_spawn_timer = SPAWN_GAP


func _beam_step(delta: float) -> void:
	var interval := rules.beam_interval()
	if interval <= 0.0 or dragon.is_busy():
		return
	_beam_timer -= delta
	if _beam_timer <= 0.0:
		_fire_beam()
		_beam_timer = interval


func _mouth_step(delta: float) -> void:
	_mouth_timer -= delta
	if _mouth_timer <= 0.0 and not dragon.is_busy() and beams_root.get_child_count() == 0:
		dragon.open_mouth(Rules.NOSE_WINDOW)
		_mouth_timer = Rules.MOUTH_INTERVAL


func _check_outcome() -> void:
	match rules.outcome():
		Rules.Outcome.WIN:
			_win()
		Rules.Outcome.FAIL:
			_fail()


# ------------------------------------------------------------------ 백성

func _citizens_on_field() -> Array[Node2D]:
	var list: Array[Node2D] = []
	for c in citizens_root.get_children():
		if not c.gone:
			list.append(c)
	return list


func _spawn_citizen() -> Node2D:
	var pos := WorldBG.random_road_point(rng)
	for i in 20:
		pos = WorldBG.random_road_point(rng)
		if _is_free_spot(pos, 80.0):
			break
	var c: Node2D = CitizenScript.new()
	c.position = pos
	citizens_root.add_child(c)
	rules.on_spawned()
	return c


func _is_free_spot(p: Vector2, gap: float) -> bool:
	for f in fires_root.get_children():
		if not f.out and f.position.distance_to(p) < gap:
			return false
	for c in citizens_root.get_children():
		if not c.gone and c.position.distance_to(p) < gap:
			return false
	return true


## 백성을 돔에 넣어요.
func rescue_citizen(c: Node2D) -> void:
	if c.gone or phase != Phase.PLAY:
		return
	_release_touches_of(c)
	c.enter_dome(WorldBG.DOME_CENTER)
	var checkpoint_now := rules.on_rescued()
	background.rescued = rules.rescued
	_float_text(WorldBG.DOME_CENTER + Vector2(-40, -200), "+1", Color(1, 0.9, 0.4))
	if checkpoint_now:
		Session.has_checkpoint = true
		Session.checkpoint_time_left = rules.checkpoint_time_left
		Session.checkpoint_score = rules.checkpoint_score
		_float_text(Vector2(520, 300), "중간 저장! (%d명)" % rules.rescued, Color(0.6, 1, 0.7), 40)
	_update_hud()


## 끌던 백성을 (불을 피하면서) 목표 위치 쪽으로 옮겨요.
func move_dragged_citizen(c: Node2D, target: Vector2) -> void:
	target = Vector2(clampf(target.x, 20, 1260), clampf(target.y, 300, 710))
	var start: Vector2 = c.position
	var steps := maxi(1, int(start.distance_to(target) / 8.0))
	var last_free := start
	for i in range(1, steps + 1):
		var p := start.lerp(target, float(i) / steps)
		if _fire_blocks_move(start, p):
			break
		last_free = p
	c.position = last_free
	if WorldBG.is_in_dome(c.position):
		rescue_citizen(c)


func _fire_blocks_move(start: Vector2, p: Vector2) -> bool:
	for f in fires_root.get_children():
		# 이미 불 옆에 있었다면 빠져나가는 것은 막지 않아요
		if f.blocks(p + CitizenScript.CENTER) and not f.blocks(start + CitizenScript.CENTER):
			return true
	return false


# ------------------------------------------------------------------ 불

func _fire_count() -> int:
	var n := 0
	for f in fires_root.get_children():
		if not f.out:
			n += 1
	return n


func _spawn_fire(p: Vector2) -> Node2D:
	if _fire_count() >= rules.max_fires() or WorldBG.is_in_dome(p):
		return null
	for f in fires_root.get_children():
		if not f.out and f.position.distance_to(p) < FireScript.RADIUS * 1.6:
			return null
	var f: Node2D = FireScript.new()
	f.position = WorldBG.clamp_to_road(p)
	f.spread_requested.connect(_on_fire_spread)
	fires_root.add_child(f)
	return f


func _on_fire_spread(f: Node2D) -> void:
	var a := rng.randf() * TAU
	_spawn_fire(f.position + Vector2(cos(a), sin(a)) * 80.0)


## 손가락이 a에서 b로 지나갔을 때 그 길 위의 불을 꺼요. 끈 개수를 돌려줘요.
func sweep_segment(a: Vector2, b: Vector2) -> int:
	var n := 0
	for f in fires_root.get_children():
		if f.out:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(f.global_position, a, b)
		if closest.distance_to(f.global_position) < FireScript.RADIUS + 26.0:
			f.extinguish()
			n += 1
	return n


func finish_sweep(fires_put_out: int, at: Vector2) -> void:
	if rules.on_sweep_finished(fires_put_out):
		_float_text(at + Vector2(-60, -60), "콤보! 별 +1", Color(1, 0.85, 0.3), 40)
		_update_hud()


# ------------------------------------------------------------------ 드래곤

func _fire_beam() -> void:
	var targets := _citizens_on_field()
	var aim: Vector2
	if not targets.is_empty() and rng.randf() < 0.6:
		aim = WorldBG.clamp_to_road(targets[rng.randi() % targets.size()].position + Vector2(rng.randf_range(-40, 40), 0))
	else:
		aim = WorldBG.random_road_point(rng)
	var sweep := rules.sweep_beams_allowed() and rng.randf() < 0.4
	var b: Node2D = BeamScript.new()
	var to := aim
	if sweep:
		var left := Vector2(rng.randf_range(400, 520), rng.randf_range(WorldBG.ROAD_TOP + 50, WorldBG.ROAD_BOTTOM - 10))
		var right := Vector2(rng.randf_range(800, 920), rng.randf_range(WorldBG.ROAD_TOP + 50, WorldBG.ROAD_BOTTOM - 10))
		aim = left
		to = right
		if rng.randf() < 0.5:
			aim = right
			to = left
	b.setup(dragon.mouth_global(), aim, to, rules.warning_time(), sweep)
	b.finished.connect(_on_beam_finished)
	beams_root.add_child(b)


func _on_beam_finished(b: Node2D) -> void:
	if phase != Phase.PLAY:
		return
	for p in b.fire_points():
		_spawn_fire(p)


func _check_beam_hits() -> void:
	for b in beams_root.get_children():
		if not b.is_active():
			continue
		for c in _citizens_on_field():
			var id := c.get_instance_id()
			if b.hit_ids.has(id) or c.dizzy > 0.0:
				continue
			if b.touches(c.center_global()):
				b.hit_ids[id] = true
				_release_touches_of(c)
				c.get_hit()
				rules.lose_heart(Rules.HeartReason.BEAM)
				_float_text(c.position + Vector2(-30, -110), "앗!", Color(1, 0.6, 0.9))
				_shake()
				_update_hud()


func _on_nose_pressed() -> void:
	_beam_timer += 1.5
	_float_text(dragon.nose_global() + Vector2(20, -20), "물러나요!", Color(0.7, 1, 1))


func _on_nose_missed() -> void:
	if phase != Phase.PLAY:
		return
	rules.lose_heart(Rules.HeartReason.NOSE)
	var field := _citizens_on_field()
	if not field.is_empty():
		var c: Node2D = field[rng.randi() % field.size()]
		_release_touches_of(c)
		c.flee()
		rules.on_citizen_fled()
		_float_text(c.position + Vector2(-90, -110), "겁을 먹고 도망갔어요!", Color(1, 0.8, 0.6), 30)
	_shake()
	_update_hud()


# ------------------------------------------------------------------ 터치

func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.PLAY or paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index, event.position)
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position)


func _touch_down(index: int, p: Vector2) -> void:
	if dragon.try_press_nose(p):
		return
	var best: Node2D = null
	var best_d := INF
	for c in _citizens_on_field():
		if c.dragging or not c.can_be_dragged() or not c.is_touched(p):
			continue
		var d: float = p.distance_to(c.center_global())
		if d < best_d:
			best = c
			best_d = d
	if best:
		best.dragging = true
		_touches[index] = {"kind": "drag", "citizen": best, "offset": best.position - p}
		return
	var trail := Line2D.new()
	trail.width = 18.0
	trail.default_color = Color(0.6, 0.85, 1.0, 0.7)
	trail.add_point(p)
	effects_root.add_child(trail)
	_touches[index] = {"kind": "sweep", "last": p, "count": 0, "trail": trail}


func _touch_move(index: int, p: Vector2) -> void:
	if not _touches.has(index):
		return
	var t: Dictionary = _touches[index]
	if t.kind == "drag":
		var c: Node2D = t.citizen
		if is_instance_valid(c) and not c.gone and c.dragging:
			move_dragged_citizen(c, p + t.offset)
	else:
		t.count += sweep_segment(t.last, p)
		t.last = p
		var trail: Line2D = t.trail
		trail.add_point(p)
		if trail.get_point_count() > 14:
			trail.remove_point(0)


func _touch_up(index: int, p: Vector2) -> void:
	if not _touches.has(index):
		return
	var t: Dictionary = _touches[index]
	_touches.erase(index)
	if t.kind == "drag":
		var c: Node2D = t.citizen
		if is_instance_valid(c) and not c.gone:
			c.dragging = false
			if WorldBG.is_in_dome(c.position):
				rescue_citizen(c)
	else:
		finish_sweep(t.count, p)
		var trail: Line2D = t.trail
		var tw := trail.create_tween()
		tw.tween_property(trail, "modulate:a", 0.0, 0.25)
		tw.tween_callback(trail.queue_free)


func _release_touches_of(c: Node2D) -> void:
	for k in _touches.keys():
		if _touches[k].kind == "drag" and _touches[k].citizen == c:
			_touches.erase(k)
	c.dragging = false


# ------------------------------------------------------------------ 끝

func _win() -> void:
	phase = Phase.OUTRO
	_stop_field()
	var stars := rules.star_rating()
	var unlocked: Dictionary = Save.record_chapter1_win(stars, rules.hard)
	Session.fail_streak = 0
	Session.clear_checkpoint()
	_float_text(Vector2(480, 260), "드래곤이 날아가요!", Color(1, 0.95, 0.7), 48)
	var tw: Tween = dragon.fly_away()
	tw.finished.connect(func() -> void: _show_win_result(stars, unlocked))


func _fail() -> void:
	phase = Phase.RESULT
	_stop_field()
	Session.fail_streak += 1
	var reason := ""
	match rules.fail_reason():
		Rules.FailReason.HEARTS:
			reason = "하트를 모두 잃었어요."
		Rules.FailReason.TOO_MANY_FLED:
			reason = "도망간 백성이 너무 많아요."
		_:
			reason = "시간 안에 %d명을 구하지 못했어요." % Rules.WIN_RESCUED
	var body := "%s\n구한 백성 %d / %d명\n\n팁: %s" % [reason, rules.rescued, Rules.TOTAL_CITIZENS, rules.fail_tip()]
	var buttons := [["다시 하기", _restart_full]]
	if Session.has_checkpoint:
		buttons.append(["중간부터", _restart_checkpoint])
	if Session.fail_streak >= 3 and not Session.assist:
		body += "\n\n여러 번 어려웠죠? \"도움 켜기\"를 누르면 경고 점선이 더 일찍 나와요."
		buttons.append(["도움 켜기", _enable_assist_and_retry])
	buttons.append(["처음으로", _go_title])
	_show_panel("아쉬워요!", body, buttons)


func _show_win_result(stars: int, unlocked: Dictionary) -> void:
	phase = Phase.RESULT
	var lines := "%s\n구한 백성 %d / %d명 · 별 점수 %d" % [rules.star_title(stars), rules.rescued, Rules.TOTAL_CITIZENS, rules.score]
	if unlocked.get("chapter2_new", false):
		lines += "\n\n2장 '준비'가 열렸어요!"
	if unlocked.get("hard_new", false):
		lines += "\n어려움 모드가 열렸어요! (타이틀 화면에서 골라요)"
	var star_widget := Widget.new(Widget.Kind.STARS)
	star_widget.custom_minimum_size = Vector2(360, 110)
	star_widget.max_value = 3
	star_widget.value = stars
	_show_panel("성공!", lines, [
		["다음 이야기", _show_teaser],
		["다시 하기", _restart_full],
		["처음으로", _go_title],
	], star_widget)


## 다음 장 예고 (제안): 왕관을 쓴 똥 왕자가 칼을 들고 다짐해요.
func _show_teaser() -> void:
	_show_panel("다음 이야기", "왕관을 쓴 똥 왕자가 칼을 들고 다짐해요.\n\"똥 드래곤, 꼭 물리칠 거야!\"\n\n2장 '준비'로 이어져요.", [
		["2장으로", func() -> void: _change_scene(CHAPTER2_SCENE)],
		["처음으로", _go_title],
	])


func _stop_field() -> void:
	_touches.clear()
	for b in beams_root.get_children():
		b.queue_free()
	for c in citizens_root.get_children():
		c.dragging = false
	_update_hud()


func _restart_full() -> void:
	Session.clear_checkpoint()
	_change_scene(STAGE_SCENE)


func _restart_checkpoint() -> void:
	Session.resume_checkpoint = true
	_change_scene(STAGE_SCENE)


func _enable_assist_and_retry() -> void:
	Session.assist = true
	Session.fail_streak = 0
	if Session.has_checkpoint:
		_restart_checkpoint()
	else:
		_restart_full()


func _go_title() -> void:
	_change_scene(TITLE_SCENE)


func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


# ------------------------------------------------------------------ 멈추기

func _toggle_pause() -> void:
	if phase != Phase.PLAY:
		return
	paused = not paused
	get_tree().paused = paused
	if paused:
		_touches.clear()
		for c in citizens_root.get_children():
			c.dragging = false
		_show_panel("멈춤", "잠깐 쉬어요.", [
			["계속", _toggle_pause],
			["다시 하기", _restart_full],
			["처음으로", _go_title],
		])
	else:
		_clear_overlay()


## 안드로이드 뒤로 가기: 플레이 중이면 멈추고, 아니면 타이틀로 가요.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if phase == Phase.PLAY:
			_toggle_pause()
		else:
			_go_title()


# ------------------------------------------------------------------ 화면 위 표시

func _build_hud() -> void:
	var bar := ColorRect.new()
	bar.color = Color(0, 0, 0, 0.35)
	bar.position = Vector2(560, 0)
	bar.size = Vector2(720, 96)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bar)

	_moon = Widget.new(Widget.Kind.MOON)
	_moon.position = Vector2(576, 8)
	_moon.size = Vector2(80, 80)
	hud_root.add_child(_moon)
	_time_label = _hud_label(Vector2(664, 26), 34)

	_hearts = Widget.new(Widget.Kind.HEARTS)
	_hearts.position = Vector2(760, 26)
	_hearts.size = Vector2(180, 48)
	_hearts.max_value = rules.hearts_max
	hud_root.add_child(_hearts)

	_rescued_label = _hud_label(Vector2(940, 10), 30)
	_score_label = _hud_label(Vector2(940, 52), 24)

	_pause_button = _make_button("II", Vector2(84, 76), 36)
	_pause_button.position = Vector2(1186, 10)
	_pause_button.pressed.connect(_toggle_pause)
	hud_root.add_child(_pause_button)


func _hud_label(pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(l)
	return l


func _update_hud() -> void:
	if not _moon:
		return
	_moon.ratio = rules.time_left / rules.time_limit
	_time_label.text = _time_text(rules.time_left)
	_hearts.value = rules.hearts
	_rescued_label.text = "구한 백성 %d / %d" % [rules.rescued, Rules.TOTAL_CITIZENS]
	_score_label.text = "목표 %d명 · 별 점수 %d" % [Rules.WIN_RESCUED, rules.score]
	_pause_button.visible = phase == Phase.PLAY


func _time_text(sec: float) -> String:
	var s := int(ceil(sec))
	return "%d:%02d" % [s / 60, s % 60]


func _float_text(p: Vector2, text: String, color: Color, font_size := 34) -> void:
	var l := Label.new()
	l.text = text
	l.position = p
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.2))
	l.add_theme_constant_override("outline_size", 8)
	effects_root.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", p.y - 50.0, 1.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


func _shake() -> void:
	var world: Node2D = $World
	var tw := create_tween()
	for i in 4:
		tw.tween_property(world, "position", Vector2(rng.randf_range(-8, 8), rng.randf_range(-6, 6)), 0.04)
	tw.tween_property(world, "position", Vector2.ZERO, 0.04)


# ------------------------------------------------------------------ 이야기 장면과 창

## 이야기 장면: 화면을 톡 누르면 다음 장면으로 넘어가요.
func _show_page() -> void:
	_clear_overlay()
	var page := Button.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.focus_mode = Control.FOCUS_NONE
	page.pressed.connect(_next_page)
	var bg := StyleBoxFlat.new()
	bg.bg_color = CREAM
	for s in ["normal", "hover", "pressed", "focus"]:
		page.add_theme_stylebox_override(s, bg)
	overlay_root.add_child(page)

	var text := Label.new()
	text.text = _pages[_page_index]
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 120
	text.offset_right = -120
	text.offset_bottom = -90
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 34 if _pages[_page_index].length() > 80 else 44)
	text.add_theme_color_override("font_color", BROWN)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(text)

	var hint := Label.new()
	hint.text = "화면을 톡 누르면 %s (%d/%d)" % ["시작해요" if _page_index == _pages.size() - 1 else "넘어가요", _page_index + 1, _pages.size()]
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -80
	hint.offset_bottom = -30
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", Color(BROWN, 0.7))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(hint)


func _next_page() -> void:
	_page_index += 1
	if _page_index >= _pages.size():
		_start_play()
	else:
		_show_page()


## 이야기 장면을 모두 건너뛰고 바로 시작해요 (자동 확인용).
func skip_intro() -> void:
	if phase == Phase.INTRO:
		_page_index = _pages.size() - 1
		_next_page()


func _show_panel(title: String, body: String, buttons: Array, extra: Control = null) -> void:
	_clear_overlay()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_root.add_child(dim)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.set_corner_radius_all(36)
	style.set_content_margin_all(36)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(760, 0)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 52)
	t.add_theme_color_override("font_color", BROWN)
	box.add_child(t)
	if extra:
		extra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(extra)
	var b := Label.new()
	b.text = body
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(688, 0)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", BROWN)
	box.add_child(b)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	for entry in buttons:
		var btn := _make_button(entry[0], Vector2(170, 76), 28)
		btn.name = "Btn_" + String(entry[0]).replace(" ", "_")
		btn.pressed.connect(entry[1])
		row.add_child(btn)


func _clear_overlay() -> void:
	for c in overlay_root.get_children():
		overlay_root.remove_child(c)
		c.queue_free()


## 지금 떠 있는 창의 버튼을 이름으로 찾아요 (자동 확인용).
func find_overlay_button(text: String) -> Button:
	return overlay_root.find_child("Btn_" + text.replace(" ", "_"), true, false) as Button


func _make_button(text: String, min_size: Vector2, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", font_size)
	for s in ["font_color", "font_hover_color", "font_pressed_color"]:
		btn.add_theme_color_override(s, Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = BUTTON_BROWN
	normal.set_corner_radius_all(28)
	var pressed := normal.duplicate()
	pressed.bg_color = BUTTON_BROWN.darkened(0.2)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	return btn
