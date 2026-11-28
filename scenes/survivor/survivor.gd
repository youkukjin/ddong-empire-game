extends "res://scripts/stage_base.gd"
## 똥제국 서바이버 (제안: 원작에 없는 놀이 방식, 장르만 따르고 특정 게임을 베끼지 않아요).
## 첫 무대: 5장 성 안 마당. 위에서 내려다보며 10분 버티고 똥 대마왕을 물리쳐요.
##
## 조작: 화면 아무 데나 손가락을 대고 끌면 그쪽으로 걸어요 (컴퓨터에서는 WASD나 화살표).
## 공격은 알아서 해요. 레벨업하면 카드 3장 중 하나를 골라요.
##
## 화면 좌표: 왕자가 늘 화면 CENTER에 있어요. 화면 점 = 마당 점 - 왕자 + CENTER.

const Rules := preload("res://scenes/survivor/survivor_rules.gd")
const View := preload("res://scenes/survivor/view3d_survivor.gd")
const SELECT_SCENE := "res://scenes/title/chapter_select.tscn"
const CENTER := Vector2(360, 640)    # 세로 화면 가운데
const JOY_R := 90.0

var rules
var move := Vector2.ZERO
var _touching := false
var _origin := Vector2.ZERO
var _finger := Vector2.ZERO
var _hit_sound_cd := 0.0
var _shown_level := 1

var joy: Control
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var time_label: Label
var info_label: Label
var god_button: Button
var boss_bar: ProgressBar
var boss_label: Label


func _init() -> void:
	portrait_layout = true


func _setup() -> void:
	rules = Rules.new()
	add_view3d(View)
	_build_hud()


func _intro_pages() -> Array:
	return [
		"똥제국 서바이버 (제안 놀이)\n\n성 안 마당에 똥 무사들이 끝없이 몰려와요!\n10분을 버티면 똥 대마왕이 나타나요.",
		"어떻게 할까요?\n\n• 손가락으로 화면을 끌면 그쪽으로 걸어요\n• 공격은 똥 왕자가 알아서 해요\n• 적이 떨어뜨린 똥 구슬을 모으면 레벨 업!\n  카드 3장 중 하나를 골라 강해져요\n• 게이지가 차면 '각성!' 버튼: 10초 동안 똥의 신",
	]


# ------------------------------------------------------------------ 화면 위 표시

func _build_hud() -> void:
	xp_bar = _bar(Vector2(0, 0), Vector2(720, 16), Color(1, 0.8, 0.2))
	hud_bar(Vector2(14, 26), Vector2(330, 84))
	hp_bar = _bar(Vector2(28, 40), Vector2(300, 24), Color(0.95, 0.3, 0.3))
	info_label = hud_label(Vector2(28, 66), 26)
	time_label = hud_label(Vector2(380, 30), 54)
	time_label.size = Vector2(220, 64)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label = hud_label(Vector2(40, 122), 26, Color(1, 0.75, 0.75))
	boss_label.size = Vector2(640, 30)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = _bar(Vector2(40, 156), Vector2(640, 22), Color(0.7, 0.2, 0.85))
	boss_label.visible = false
	boss_bar.visible = false
	god_button = make_button("각성!", Vector2(180, 110), 40, Color(1, 0.78, 0.2))
	god_button.name = "Btn_각성"
	god_button.position = Vector2(520, 1150)
	god_button.pressed.connect(_on_awaken)
	hud_root.add_child(god_button)
	joy = Joystick.new()
	joy.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(joy)
	_refresh_hud()


func _bar(pos: Vector2, size: Vector2, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.size = size
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.05, 0.08, 0.75)
	bg.set_corner_radius_all(int(size.y / 2))
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(int(size.y / 2))
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	hud_root.add_child(b)
	return b


func _refresh_hud() -> void:
	hp_bar.max_value = rules.max_hp
	hp_bar.value = maxf(rules.hp, 0.0)
	xp_bar.max_value = rules.xp_needed()
	xp_bar.value = rules.xp
	var left: float = maxf(Rules.BOSS_TIME - rules.time, 0.0)
	time_label.text = time_text(left) if not rules.boss_spawned else "보스!"
	info_label.text = "Lv %d   물리친 적 %d" % [rules.level, rules.kills]
	var ready: bool = rules.god_gauge >= 1.0 and rules.god_left <= 0.0
	god_button.visible = phase == Phase.PLAY
	god_button.disabled = not ready
	if rules.god_left > 0.0:
		god_button.text = "신 %d" % int(ceil(rules.god_left))
	elif ready:
		god_button.text = "각성!"
	else:
		god_button.text = "%d%%" % int(rules.god_gauge * 100.0)
	var b: Dictionary = _big_enemy()
	boss_label.visible = not b.is_empty()
	boss_bar.visible = boss_label.visible
	if not b.is_empty():
		boss_label.text = "똥 대마왕" if b.kind == "demon" else "똥 무사 대장"
		boss_bar.max_value = b.max_hp
		boss_bar.value = maxf(b.hp, 0.0)


func _big_enemy() -> Dictionary:
	var best: Dictionary = {}
	for e in rules.enemies:
		if e.boss and (best.is_empty() or e.kind == "demon"):
			best = e
	return best


# ------------------------------------------------------------------ 좌표

func world_to_screen(w: Vector2) -> Vector2:
	if view3d:
		return view3d.screen_of(w)
	return w - rules.hero + CENTER


func screen_to_world(p: Vector2) -> Vector2:
	return p - CENTER + rules.hero


# ------------------------------------------------------------------ 플레이

func _on_play_started() -> void:
	Sound.play("power", 1.0, -2.0)
	if view3d:
		view3d.comic(CENTER + Vector2(0, -120), "버텨라!", Color(1, 0.85, 0.2), 1.2)


func _play_process(delta: float) -> void:
	_hit_sound_cd -= delta
	var keys := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	var dir: Vector2 = move if keys == Vector2.ZERO else keys.normalized()
	var events: Array = rules.tick(delta, dir)
	for ev in events:
		_on_event(ev)
	if view3d:
		view3d.sync(rules, delta)
	_refresh_hud()
	joy.set_state(_touching, _origin, _finger)
	match rules.outcome():
		Rules.Outcome.WIN:
			_finish(true)
		Rules.Outcome.LOSE:
			_finish(false)
	if phase == Phase.PLAY and not rules.choices.is_empty() and not overlay_root.has_node("Cards"):
		_show_cards()


func _on_event(ev: Dictionary) -> void:
	match ev.type:
		"hit":
			if _hit_sound_cd <= 0.0:
				_hit_sound_cd = 0.09
				Sound.play("hit", randf_range(0.9, 1.2), -9.0)
			if ev.boss and view3d:
				view3d.hit_boss(ev.enemy)
		"kill":
			if view3d:
				view3d.on_kill(ev.enemy)
			if ev.enemy.boss:
				impact(world_to_screen(ev.enemy.pos), "콰앙!!", Color(1, 0.6, 0.2), 2.0)
		"swing":
			Sound.play("swing", randf_range(0.95, 1.1), -8.0)
			if view3d:
				view3d.on_swing(ev.dirs, ev.reach)
		"slam":
			impact(CENTER, "쾅!", Color(1, 0.8, 0.25), 0.9)
			if view3d:
				view3d.on_slam(ev.radius)
		"boom":
			Sound.play("boom", randf_range(0.9, 1.15), -6.0)
			if view3d:
				view3d.on_boom(ev.pos, ev.radius)
		"gem":
			Sound.play("coin", randf_range(1.0, 1.3), -14.0)
		"hurt":
			Sound.play("hurt", 1.0, -4.0)
			shake(5.0)
			if view3d:
				view3d.flash(Color(1, 0.2, 0.2), 0.25)
		"levelup":
			Sound.play("power", 1.2, -3.0)
		"boss":
			Sound.play("roar", 1.0, 0.0)
			impact(CENTER + Vector2(0, -260), ev.text, Color(1, 0.35, 0.35), 1.6)


func _play_input(event: InputEvent) -> void:
	if not rules.choices.is_empty():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touching = true
			_origin = event.position
			_finger = event.position
			move = Vector2.ZERO
		else:
			_touching = false
			move = Vector2.ZERO
	elif event is InputEventScreenDrag and _touching:
		_finger = event.position
		var d: Vector2 = _finger - _origin
		# 손가락이 너무 멀리 가면 받침이 따라와요
		if d.length() > JOY_R:
			_origin = _finger - d.normalized() * JOY_R
			d = _finger - _origin
		move = d / JOY_R if d.length() > 8.0 else Vector2.ZERO


func _on_paused() -> void:
	_touching = false
	move = Vector2.ZERO


func _can_pause() -> bool:
	return rules == null or rules.choices.is_empty()


func _on_awaken() -> void:
	if rules.awaken():
		impact(CENTER + Vector2(0, -140), "똥의 신 각성!!", Color(1, 0.85, 0.2), 1.8)
		Sound.play("flash", 1.0, 0.0)


# ------------------------------------------------------------------ 레벨업 카드

func _show_cards() -> void:
	_touching = false
	move = Vector2.ZERO
	_refresh_pause_button()
	clear_overlay()
	var dim := ColorRect.new()
	dim.name = "Cards"
	dim.color = Cute.DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_root.add_child(dim)
	var t := Label.new()
	t.text = "레벨 업! (Lv %d) 하나 골라요" % rules.level
	t.position = Vector2(0, 150)
	t.size = Vector2(720, 70)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Cute.style_label(t, 52, Color(1, 0.85, 0.25), Cute.COCOA, 12)
	dim.add_child(t)
	var row := VBoxContainer.new()
	row.position = Vector2(50, 260)
	row.size = Vector2(620, 820)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	dim.add_child(row)
	var colors := [Cute.MINT, Cute.PEACH, Cute.SKY]
	for i in rules.choices.size():
		var c: Dictionary = rules.choices[i]
		var tag := ""
		if c.kind == "weapon":
			tag = "\n\n(%s)" % Rules.WEAPONS[c.id].origin
		var b := make_button("%s\n%s%s" % [c.title, c.desc, tag.replace("\n\n", "  ")], Vector2(620, 240), 34, colors[i % 3])
		b.name = "Card%d" % i
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(choose_card.bind(i))
		row.add_child(b)


func choose_card(i: int) -> void:
	if rules.choices.is_empty():
		return
	var c: Dictionary = rules.choices[i]
	rules.choose(i)
	clear_overlay()
	Sound.play("build", 1.1, -3.0)
	if view3d:
		view3d.comic(CENTER + Vector2(0, -130), c.title + "!", Color(0.6, 1, 0.5), 0.8)
	_refresh_pause_button()
	if not rules.choices.is_empty():
		_show_cards()


# ------------------------------------------------------------------ 끝

func _finish(win: bool) -> void:
	phase = Phase.RESULT
	_touching = false
	_refresh_pause_button()
	god_button.visible = false
	var earned: int = rules.earned_coins()
	var best: bool = Save.record_survivor(earned, rules.time, win)
	Sound.jingle(win)
	if view3d:
		view3d.sync(rules, 0.0)
	var lines := "버틴 시간 %s   레벨 %d   물리친 적 %d\n똥전 +%d (모은 똥전 %d)" % [time_text(rules.time), rules.level, rules.kills, earned, Save.survivor_coins()]
	if best:
		lines += "\n새 기록!"
	var weapons: Array = []
	for id in rules.weapons:
		weapons.append("%s Lv%d" % [Rules.WEAPONS[id].name, rules.weapons[id]])
	lines += "\n무기: " + ", ".join(weapons)
	var title := "똥 대마왕을 물리쳤어요!" if win else "쓰러졌어요!"
	if not win:
		lines += "\n\n팁: 멈추지 말고 빙글빙글 돌면서 구슬을 모아요"
	show_panel(title, lines, [
		["다시 하기", restart],
		["장 고르기", go_select],
		["처음으로", go_title],
	])


func go_select() -> void:
	change_scene(SELECT_SCENE)


## 끌기 받침 (손가락을 댄 곳에 동그라미가 생겨요)
class Joystick extends Control:
	var on := false
	var origin := Vector2.ZERO
	var finger := Vector2.ZERO

	func set_state(o: bool, a: Vector2, b: Vector2) -> void:
		if o != on or a != origin or b != finger:
			on = o
			origin = a
			finger = b
			queue_redraw()

	func _draw() -> void:
		if not on:
			return
		draw_circle(origin, 90.0, Color(1, 1, 1, 0.14))
		draw_arc(origin, 90.0, 0, TAU, 48, Color(1, 1, 1, 0.5), 4.0)
		draw_circle(finger, 38.0, Color(1, 0.85, 0.4, 0.55))
