extends "res://scripts/stage_base.gd"
## 똥제국 서바이버 (제안: 원작에 없는 놀이 방식, 장르만 따르고 특정 게임을 베끼지 않아요).
## 첫 무대: 5장 성 안 마당. 위에서 내려다보며 6분 버티고 똥 대마왕을 물리쳐요.
##
## 조작: 화면 아무 데나 손가락을 대고 끌면 그쪽으로 걸어요 (컴퓨터에서는 WASD나 화살표).
## 공격은 알아서 해요. 레벨업하면 카드 3장 중 하나를 골라요.
##
## 화면 좌표: 왕자가 늘 화면 CENTER에 있어요. 화면 점 = 마당 점 - 왕자 + CENTER.

const Rules := preload("res://scenes/survivor/survivor_rules.gd")
const View := preload("res://scenes/survivor/view3d_survivor.gd")
const SkillCard := preload("res://scenes/survivor/skill_card.gd")
const Ads := preload("res://scripts/ads.gd")
const SELECT_SCENE := "res://scenes/title/chapter_select.tscn"
const FORGE_SCENE := "res://scenes/survivor/forge.tscn"
const CENTER := Vector2(360, 640)    # 세로 화면 가운데
const JOY_R := 90.0

var rules
var move := Vector2.ZERO
var _touching := false
var _origin := Vector2.ZERO
var _finger := Vector2.ZERO
var _hit_sound_cd := 0.0
var _gag_cd := 0.0
var _fart_t := 8.0
const KILL_GAGS := ["뽀직!", "으악 냄새!", "엄마~!", "꾸에엑", "내 똥꼬!", "퐁!", "변기로 돌아갈래!", "물 내려줘~", "뿌직!"]
const HURT_GAGS := ["아야 내 엉덩이!", "똥꼬 아파!", "으앙!", "냄새나!", "반칙이야!"]
const LOSE_GAGS := ["똥꼬에 힘이 빠졌어요...", "변기로 휘리릭~", "잠깐 화장실 다녀올게요!", "으앙, 물 내려가요~"]
var _crit_cd := 0.0
var _shown_level := 1

var joy: Control
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var time_label: Label
var info_label: Label
var god_button: Button
var god_info: Label
var boss_bar: ProgressBar
var boss_label: Label
var boss_labels: Array = []
var boss_bars: Array = []
var skills_label: Label
var hp_text: Label


func _init() -> void:
	portrait_layout = true


func _setup() -> void:
	rules = Rules.new()
	rules.set_stage(mini(Save.survivor_stage(), Save.survivor_stages_open() - 1))
	Sound.survivor_music = String(Rules.STAGES[rules.stage].music)
	var hid := Save.survivor_hero()
	if not Save.hero_unlocked(hid, int(Rules.HEROES.get(hid, {"cost": 0}).cost)):
		hid = "kid"
	rules.set_hero(hid)
	var forge := {}
	for id in Rules.FORGE:
		forge[id] = Save.forge_level(id)
	rules.apply_forge(forge)
	add_view3d(View)
	_build_hud()


func _intro_pages() -> Array:
	return [
		"똥제국 서바이버\n\n성 안 마당에 똥 무사들이 끝없이 몰려와요!\n2분마다 중간 보스, 6분을 버티면 똥 대마왕이 나타나요.",
		"어떻게 할까요?\n\n• 손가락으로 화면을 끌면 그쪽으로 걸어요\n• 공격은 똥 왕자가 알아서 해요\n• 적이 떨어뜨린 똥 구슬을 모으면 레벨 업!\n  카드 3장 중 하나를 골라 강해져요\n• 빨간 생명력 똥은 체력, 파란 자석 똥은 구슬을 몽땅 끌어와요\n• 게이지가 차면 '각성!' 버튼: 10초 동안 똥의 신\n  공격력 3배, 공격 속도 2배, 이동 속도 UP, 안 아파요!",
	]


# ------------------------------------------------------------------ 화면 위 표시

func _build_hud() -> void:
	xp_bar = _bar(Vector2(0, 0), Vector2(720, 16), Color(1, 0.8, 0.2))
	hud_bar(Vector2(14, 26), Vector2(330, 84))
	hp_bar = _bar(Vector2(28, 40), Vector2(300, 24), Color(0.95, 0.3, 0.3))
	info_label = hud_label(Vector2(28, 66), 26)
	hp_text = hud_label(Vector2(28, 36), 22)
	hp_text.size = Vector2(300, 30)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label = hud_label(Vector2(380, 30), 54)
	time_label.size = Vector2(220, 64)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label = hud_label(Vector2(40, 122), 26, Color(1, 0.75, 0.75))
	boss_label.size = Vector2(640, 30)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = _bar(Vector2(40, 156), Vector2(640, 22), Color(0.7, 0.2, 0.85))
	boss_label.visible = false
	boss_bar.visible = false
	boss_labels = [boss_label]
	boss_bars = [boss_bar]
	# 보스가 여럿이면 체력바도 여러 줄 (2026-11-28 사용자: "두 마리의 체력바가 안 나와")
	for i in range(1, 3):
		var l := hud_label(Vector2(40, 122 + i * 62), 26, Color(1, 0.75, 0.75))
		l.size = Vector2(640, 30)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.visible = false
		var bb := _bar(Vector2(40, 156 + i * 62), Vector2(640, 22), Color(0.7, 0.2, 0.85))
		bb.visible = false
		boss_labels.append(l)
		boss_bars.append(bb)
	god_button = make_button("각성!", Vector2(180, 110), 40, Color(1, 0.78, 0.2))
	god_button.name = "Btn_각성"
	god_button.position = Vector2(520, 1150)
	god_button.pressed.connect(_on_awaken)
	hud_root.add_child(god_button)
	# 각성 중에 무엇이 좋아졌는지 크게 보여줘요
	god_info = hud_label(Vector2(20, 196), 30, Color(1, 0.88, 0.3))
	god_info.size = Vector2(680, 90)
	god_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	god_info.text = "★ 똥의 신 10초 ★\n공격력 3배, 공격 속도 2배, 이동 속도 UP, 안 아파요!"
	god_info.visible = false
	skills_label = hud_label(Vector2(20, 1150), 22)
	skills_label.size = Vector2(480, 110)
	skills_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skills_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
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
	hp_text.text = "%d / %d" % [int(ceil(maxf(rules.hp, 0.0))), int(rules.max_hp)]
	xp_bar.max_value = rules.xp_needed()
	xp_bar.value = rules.xp
	var left: float = maxf(Rules.BOSS_TIME - rules.time, 0.0)
	if rules.endless:
		time_label.text = "∞ " + time_text(rules.time)
	else:
		time_label.text = time_text(left) if not rules.boss_spawned else "보스!"
	info_label.text = "Lv %d   물리친 적 %d" % [rules.level, rules.kills]
	var parts: Array = []
	for id in rules.weapons:
		parts.append((Rules.WEAPONS[id].evo + "★") if rules.evolved.has(id) else "%s%d" % [Rules.WEAPONS[id].name, rules.weapons[id]])
	for id in rules.passives:
		parts.append("%s%d" % [Rules.PASSIVES[id].name, rules.passives[id]])
	for id in rules.traits:
		parts.append("%s×%d" % [Rules.TRAITS[id].name, rules.traits[id]])
	skills_label.text = "  ".join(parts)
	var ready: bool = rules.god_gauge >= 1.0 and rules.god_left <= 0.0
	god_button.visible = phase == Phase.PLAY
	god_button.disabled = not ready
	god_info.visible = rules.god_left > 0.0 and phase == Phase.PLAY
	if god_info.visible:
		god_info.modulate.a = 0.75 + sin(Time.get_ticks_msec() * 0.008) * 0.25
	if rules.god_left > 0.0:
		god_button.text = "신 %d" % int(ceil(rules.god_left))
	elif ready:
		god_button.text = "각성!"
	else:
		god_button.text = "%d%%" % int(rules.god_gauge * 100.0)
	var bosses: Array = _bosses()
	for i in boss_bars.size():
		var on := i < bosses.size()
		boss_labels[i].visible = on
		boss_bars[i].visible = on
		if on:
			var b: Dictionary = bosses[i]
			boss_labels[i].text = Rules.BOSS_NAMES.get(b.kind, "보스")
			boss_bars[i].max_value = b.max_hp
			boss_bars[i].value = maxf(b.hp, 0.0)
	god_info.position.y = 196 + maxi(bosses.size() - 1, 0) * 62


## 화면에 있는 보스들 (대마왕이 맨 위)
func _bosses() -> Array:
	var out: Array = []
	for e in rules.enemies:
		if e.boss:
			out.append(e)
	out.sort_custom(func(a, b): return a.kind == "demon" and b.kind != "demon")
	return out.slice(0, 3)


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
	_gag_cd -= delta
	# 개그: 오래 걸으면 가끔 뿡! (방귀 똥은 더 자주)
	if move.length() > 0.1 or Input.is_anything_pressed():
		_fart_t -= delta
		if _fart_t <= 0.0:
			_fart_t = randf_range(6.0, 12.0) * (0.5 if rules.hero_id == "gassy" else 1.0)
			if rules.tummy > 0.0:
				_fart_t = randf_range(0.8, 1.6)    # 썩은 빵 배탈: 방귀가 마구 나와요
			Sound.play("fart", randf_range(0.85, 1.25), -5.0)
			for fev in rules.fart_blast():
				_on_event(fev)
			if view3d:
				view3d.fart_puff()
				view3d.comic(CENTER + Vector2(-80, -40), ["뿡!", "뿌웅~", "뽀옹!", "푸쉬익"].pick_random(), Color(0.7, 0.9, 0.4), 0.5)
	_crit_cd -= delta
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
		Rules.Outcome.LOSE:
			if rules.can_revive():
				_offer_revive()
			else:
				_finish(rules.boss_defeated)
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
			if ev.crit and _crit_cd <= 0.0 and view3d:
				_crit_cd = 0.12
				Sound.play("boom", randf_range(1.5, 1.8), -6.0)
				view3d.on_crit(ev.enemy.pos, float(ev.dmg))
		"kill":
			if view3d:
				view3d.on_kill(ev.enemy)
				# 개그: 가끔 쓰러지며 한마디
				if not ev.enemy.boss and _gag_cd <= 0.0 and randf() < 0.08:
					_gag_cd = 0.7
					view3d.comic(world_to_screen(ev.enemy.pos) + Vector2(0, -50), KILL_GAGS.pick_random(), Color(1, 0.9, 0.6), 0.55)
			if ev.enemy.boss:
				impact(world_to_screen(ev.enemy.pos), "콰앙!!", Color(1, 0.6, 0.2), 2.0)
		"swing":
			Sound.play("swing", randf_range(0.95, 1.1), -8.0)
			if view3d:
				view3d.on_swing(ev.dirs, ev.reach)
		"god_fart":
			Sound.play("fart", randf_range(0.6, 0.8), 0.0)
			if view3d:
				view3d.on_god_wave(ev.r)
				view3d.fart_puff()
				view3d.comic(CENTER + Vector2(randf_range(-120, 120), -60), ["뿌우우웅!!", "뿡뿡뿡!", "푸와앙!"].pick_random(), Color(0.7, 0.9, 0.4), 0.7)
		"god_freeze":
			if view3d:
				view3d.on_ice_hit(rules.hero, true)
		"god_wave":
			Sound.play("boom", 0.7, 0.0)
			if view3d:
				view3d.on_god_wave(ev.r)
		"bread":
			Sound.play("fart", 0.7, 0.0)
			_fart_t = 0.5
			impact(CENTER + Vector2(0, -150), "썩은 빵! 배가 꾸르륵~", Color(0.7, 0.9, 0.4), 1.0)
		"magnet":
			Sound.play("power", 0.8, -4.0)
			if view3d:
				view3d.comic(CENTER + Vector2(0, -120), "자석 똥! 구슬이 몽땅 와요", Color(0.5, 0.75, 1.0), 0.7)
		"slam":
			impact(CENTER, "쾅!", Color(1, 0.8, 0.25), 0.9)
			if view3d:
				view3d.on_slam(ev.radius)
		"boom":
			Sound.play("boom", randf_range(0.9, 1.15), -6.0)
			if view3d:
				view3d.on_boom(ev.pos, ev.radius)
		"beam":
			Sound.play("laser", randf_range(0.92, 1.08), -10.0)
			if view3d:
				view3d.on_beam(ev.from, ev.dir, ev.length, ev.width, ev.evolved, ev.hits)
		"bolt":
			Sound.play("boom", randf_range(1.3, 1.6), -10.0)
			if view3d:
				view3d.on_bolt(ev.pos, ev.radius)
		"thorns":
			Sound.play("clang", 1.0, -6.0)
			if view3d:
				view3d.on_thorns(ev.radius)
		"ice":
			Sound.play("swing", 1.6, -12.0)
		"ice_hit":
			if _hit_sound_cd <= 0.0:
				_hit_sound_cd = 0.07
				Sound.play("coin", randf_range(1.7, 2.0), -8.0)
			if view3d:
				view3d.on_ice_hit(ev.pos, ev.evo)
		"bhit":
			if _hit_sound_cd <= 0.0:
				_hit_sound_cd = 0.07
				Sound.play("clang" if ev.evolved else "hit", randf_range(0.6, 0.8), -5.0)
			if view3d:
				view3d.on_bhit(ev.pos, ev.evolved)
		"endless":
			Sound.play("roar", 0.8, 0.0)
			impact(CENTER + Vector2(0, -240), "무한 모드!", Color(1, 0.4, 0.35), 2.0)
			if Save.clear_survivor_stage(rules.stage, Rules.STAGES.size()) and view3d:
				view3d.comic(CENTER + Vector2(0, 60), "새 무대 열림: " + String(Rules.STAGES[rules.stage + 1].name), Color(0.6, 1, 0.6), 0.9)
			if view3d:
				view3d.comic(CENTER + Vector2(0, -100), "적이 점점 세져요!", Color(1, 0.85, 0.4), 0.7)
		"surround":
			Sound.play("roar", 1.2, -4.0)
			impact(CENTER + Vector2(0, -260), "포위됐어요! 뚫고 나가요!", Color(1, 0.55, 0.35), 1.3)
		"dash":
			Sound.play("roar", 1.4, -8.0)
		"heal":
			Sound.play("power", 1.4, -6.0)
			_hurt_number(float(ev.amount), Color(0.45, 1, 0.45))
			if view3d:
				view3d.comic(CENTER + Vector2(0, -120), "생명력 똥!", Color(1, 0.5, 0.55), 0.6)
		"gem":
			Sound.play("coin", randf_range(1.0, 1.3), -14.0)
		"hurt":
			Sound.play("hurt", 1.0, -4.0)
			_hurt_number(-float(ev.dmg), Color(1, 0.3, 0.25))
			if view3d and _gag_cd <= 0.0 and randf() < 0.3:
				_gag_cd = 1.2
				view3d.comic(CENTER + Vector2(60, -170), HURT_GAGS.pick_random(), Color(1, 0.7, 0.7), 0.6)
			shake(5.0)
			if view3d:
				view3d.flash(Color(1, 0.2, 0.2), 0.25)
		"levelup":
			Sound.play("power", 1.2, -3.0)
			if randf() < 0.5:
				Sound.play("fart", 1.3, -6.0)
		"boss":
			Sound.play("roar", 1.0, 0.0)
			if ev.text != "":
				impact(CENTER + Vector2(0, -260), ev.text, Color(1, 0.35, 0.35), 1.6)


## 왕자 머리 위에 -2, +25 같은 숫자가 톡 튀어 올라요
func _hurt_number(v: float, color: Color) -> void:
	var l := Label.new()
	l.text = ("%+d" % int(round(v))) if absf(v) >= 1.0 else ("%+.1f" % v)
	l.add_theme_font_size_override("font_size", 44)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.07, 0.035, 0.05))
	l.add_theme_constant_override("outline_size", 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(l)
	var p := world_to_screen(rules.hero) + Vector2(randf_range(-30, 10), -130)
	l.position = p
	l.pivot_offset = l.get_minimum_size() * 0.5
	l.scale = Vector2.ONE * 1.6
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", p.y - 70.0, 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tw.tween_callback(l.queue_free)


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
		var gi: Dictionary = rules.god_info_of()
		god_info.text = "★ %s 10초 ★\n%s, 안 아파요!" % [String(gi.name).trim_suffix("!"), gi.desc]
		impact(CENTER + Vector2(0, -140), String(gi.name), Color(1, 0.85, 0.2), 1.8)
		god_info.visible = true
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
	if String(rules.choices[0].kind) == "trait":
		t.text = "보스를 물리쳤어요! 똥 특성을 골라요"
		Sound.play("power", 0.8, 0.0)
	t.position = Vector2(0, 150)
	t.size = Vector2(720, 70)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Cute.style_label(t, 52, Color(1, 0.85, 0.25), Cute.COCOA, 12)
	dim.add_child(t)
	var row := VBoxContainer.new()
	row.position = Vector2(40, 250)
	row.size = Vector2(640, 840)
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	dim.add_child(row)
	for i in rules.choices.size():
		var c: Dictionary = rules.choices[i]
		var b := SkillCard.new(c, int(c.get("level", 0)), int(c.get("max", Rules.MAX_LEVEL)))
		b.name = "Card%d" % i
		b.pressed.connect(choose_card.bind(i))
		row.add_child(b)
		# 한 장씩 톡톡 튀어나와요
		b.modulate.a = 0.0
		var tw := b.create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(b, "modulate:a", 1.0, 0.15)


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

## 쓰러지면 한 번: 광고 보고 이어하기
func _offer_revive() -> void:
	phase = Phase.OUTRO
	_touching = false
	move = Vector2.ZERO
	_refresh_pause_button()
	god_button.visible = false
	Sound.play("hurt", 0.7, 0.0)
	show_panel("쓰러졌어요!", "광고를 보면 이 자리에서 한 번 더 일어날 수 있어요.\n(체력 절반, 주변 적을 날려 버려요)", [
		["광고 보고 이어하기", _watch_revive_ad],
		["그만하기", func() -> void: _finish(rules.boss_defeated)],
	])


func _watch_revive_ad() -> void:
	clear_overlay()
	Ads.show_rewarded(self, "revive", func(ok: bool) -> void:
		if not ok:
			_finish(rules.boss_defeated)
			return
		rules.revive()
		phase = Phase.PLAY
		_refresh_pause_button()
		Sound.play("power", 0.9, 0.0)
		impact(CENTER + Vector2(0, -160), "다시 일어났다!", Color(1, 0.85, 0.3), 1.6)
		if view3d:
			view3d.on_god_wave(420.0))


## 끝난 뒤 광고 보고 똥전 2배
func _watch_double_ad(earned: int) -> void:
	clear_overlay()
	Ads.show_rewarded(self, "double_coins", func(ok: bool) -> void:
		if ok:
			Save.record_survivor(earned, 0.0, false)
			_doubled = true
		_show_result())

var _result := {}
var _doubled := false


func _finish(win: bool) -> void:
	phase = Phase.RESULT
	_touching = false
	_refresh_pause_button()
	god_button.visible = false
	var earned: int = rules.earned_coins()
	var best: bool = Save.record_survivor(earned, rules.time, win)
	var place: int = Save.add_survivor_rank({"time": rules.time, "level": rules.level, "kills": rules.kills, "cleared": win,
		"date": Time.get_date_string_from_system()})
	Sound.jingle(win or place == 1)
	if view3d:
		view3d.sync(rules, 0.0)
	_result = {"win": win, "earned": earned, "best": best, "place": place}
	_show_result()


func _show_result() -> void:
	var win: bool = _result.win
	var earned: int = _result.earned
	var best: bool = _result.best
	var place: int = _result.place
	var got := earned * (2 if _doubled else 1)
	var lines := "버틴 시간 %s   레벨 %d   물리친 적 %d\n똥전 +%d%s (모은 똥전 %d)" % [time_text(rules.time), rules.level, rules.kills, got, " (2배!)" if _doubled else "", Save.survivor_coins()]
	if place > 0:
		lines += "\n순위 %d위!%s" % [place, " 새 기록!" if best else ""]
	lines += "\n\n" + rank_text(place)
	var title := "무한 모드에서 쓰러졌어요!" if win else "쓰러졌어요!"
	lines = LOSE_GAGS.pick_random() + "\n" + lines
	if not win:
		lines += "\n팁: 멈추지 말고 빙글빙글 돌면서 구슬을 모아요"
	var buttons: Array = []
	if earned > 0 and not _doubled:
		buttons.append(["광고 보고 똥전 2배", _watch_double_ad.bind(earned)])
	show_panel(title, lines, buttons + [
		["다시 하기", restart],
		["똥 대장간", func() -> void: get_tree().change_scene_to_file(FORGE_SCENE)],
		["장 고르기", go_select],
		["처음으로", go_title],
	])


## 순위표 (5위까지, 이번 판은 ▶ 표시)
static func rank_text(place: int) -> String:
	var out: Array = ["순위표"]
	var ranks: Array = Save.survivor_ranks()
	for i in mini(ranks.size(), 5):
		var r: Dictionary = ranks[i]
		out.append("%s%d위  %s  Lv%d%s" % ["▶ " if i + 1 == place else "", i + 1, time_text(float(r.time)), int(r.level), "  (대마왕 ★)" if r.get("cleared", false) else ""])
	return "\n".join(out)


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
