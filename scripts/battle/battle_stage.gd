extends "res://scripts/stage_base.gd"
## 5~7장 싸움 화면의 공통 부분이에요: 터치 조작, 인물 그리기, 체력 막대, 경고 표시.
## 규칙 계산은 battle_rules.gd가 하고, 각 장은 웨이브·이야기·결과만 채워요.

const Battle := preload("res://scripts/battle/battle_rules.gd")
const Prince := preload("res://scripts/art/prince.gd")
const Backdrop := preload("res://scripts/art/backdrop.gd")
const Gesture := preload("res://scripts/gesture.gd")
const View3D := preload("res://scripts/battle/view3d_battle.gd")

const GROUND_Y := 600.0
const PURPLE := Color(0.62, 0.42, 0.86)       # 귀여운 디자인 (제안): 연보라
const PURPLE_DARK := Color(0.42, 0.25, 0.64)

var battle: Battle
var prince: Node2D
var gesture := Gesture.new()
var gauge_mode := "none"          # "none" / "fist" (6장 근육 주먹) / "awaken" (7장 각성)
var backdrop_kind := "arena"

var _draw_node: Node2D
var _hp_label: Label
var _boss_label: Label
var _info_label: Label
var _gauge_button: Button
var _hp_bar: Panel
var _hp_fill: Panel
var _boss_bar: Panel
var _boss_fill: Panel
var _gauge_fill: Panel
var _gauge_bar: Panel
var _flash := {}                  # 적 id -> 맞아서 하얗게 빛나는 시간


func _setup() -> void:
	battle = _make_battle()
	add_view3d(View3D, backdrop_kind)
	world.add_child(Backdrop.new(backdrop_kind))
	_draw_node = Node2D.new()
	_draw_node.draw.connect(_draw_battle)
	world.add_child(_draw_node)
	prince = Prince.new()
	prince.position = Vector2(battle.hero_x, GROUND_Y)
	world.add_child(prince)
	var fx := Node2D.new()
	fx.name = "FX"
	fx.z_index = 5
	fx.draw.connect(_draw_warnings.bind(fx))
	world.add_child(fx)
	hud_bar(Vector2(0, 0), Vector2(1280, 96))
	_hp_bar = _bar(Vector2(24, 52), Vector2(300, 26), Color(0.3, 0.16, 0.24))
	_hp_fill = _bar(Vector2(24, 52), Vector2(300, 26), Cute.MINT)
	_hp_label = hud_label(Vector2(24, 8), 30)
	_boss_bar = _bar(Vector2(400, 52), Vector2(460, 26), Color(0.2, 0.1, 0.2))
	_boss_fill = _bar(Vector2(400, 52), Vector2(460, 26), Cute.PINK)
	_boss_label = hud_label(Vector2(400, 8), 30)
	_info_label = hud_label(Vector2(24, 104), 24)
	if gauge_mode != "none":
		_gauge_bar = _bar(Vector2(900, 60), Vector2(260, 20), Color(0.2, 0.15, 0.1))
		_gauge_fill = _bar(Vector2(900, 60), Vector2(0, 20), Cute.LEMON)
		hud_label(Vector2(900, 14), 26).text = "근육 주먹" if gauge_mode == "fist" else "각성 게이지"
		_gauge_button = make_button("근육 주먹!" if gauge_mode == "fist" else "각성!", Vector2(240, 110), 40, Cute.LEMON.darkened(0.1))
		_gauge_button.name = "GaugeButton"
		_gauge_button.position = Vector2(1010, 560)
		_gauge_button.visible = false
		_gauge_button.pressed.connect(use_gauge)
		hud_root.add_child(_gauge_button)
	_battle_setup()
	_update_hud()


# ------------------------------------------------------------------ 장마다 채우는 곳

func _make_battle() -> Battle:
	return Battle.new()


func _battle_setup() -> void:
	pass


func _on_battle_event(_e: Dictionary) -> void:
	pass


## 적을 모두 물리쳤어요 (웨이브가 남았으면 다음 웨이브를 내보내요)
func _on_enemies_cleared() -> void:
	pass


func _on_hero_down() -> void:
	pass


func _on_gauge_used() -> void:
	pass


## 게이지 버튼을 지금 쓸 수 있는지 (7장: 드래곤이 충분히 약해져야 각성)
func _gauge_ready() -> bool:
	return true


# ------------------------------------------------------------------ 진행

func _on_paused() -> void:
	gesture.reset()
	prince.charge = 0.0


func _play_process(delta: float) -> void:
	gesture.tick(delta)
	for e in battle.tick(delta):
		_show_event(e)
		_on_battle_event(e)
	if gesture.is_holding():
		prince.charge = battle.charge_ratio(gesture.held)
		prince.pose = Prince.Pose.CHARGE
	elif prince.pose == Prince.Pose.CHARGE:
		prince.pose = Prince.Pose.IDLE
		prince.charge = 0.0
	prince.position.x = battle.hero_x
	prince.facing = battle.facing
	prince.god = battle.god_left > 0.0
	if battle.is_rolling() and prince.pose != Prince.Pose.ROLL:
		prince.play_pose(Prince.Pose.ROLL, float(battle.stats.roll_invuln))
	for k in _flash.keys():
		_flash[k] -= delta
		if _flash[k] <= 0.0:
			_flash.erase(k)
	_update_hud()
	_draw_node.queue_redraw()
	world.get_node("FX").queue_redraw()
	if phase != Phase.PLAY:
		return
	match battle.outcome():
		Battle.Outcome.FAIL:
			_on_hero_down()
		Battle.Outcome.WIN:
			_on_enemies_cleared()


func _show_event(e: Dictionary) -> void:
	if view3d:
		view3d.on_event(e)
	match e.type:
		"hurt":
			prince.play_pose(Prince.Pose.HURT, 0.4)
			prince.blink = Battle.HURT_INVULN
			float_text(Vector2(battle.hero_x - 30, GROUND_Y - 230), "-%d" % int(e.dmg), Color(1, 0.5, 0.5), 38)
			impact(Vector2(battle.hero_x, GROUND_Y - 90), "으윽!", Color(1, 0.35, 0.3), 1.1)
		"dodge":
			float_text(Vector2(battle.hero_x - 60, GROUND_Y - 230), "아슬아슬!", Color(0.7, 1, 1), 32)
		"summon":
			float_text(Vector2(e.enemy.x - 100, 300), "무사들아, 나와라!", Color(1, 0.7, 0.7), 34)
		"land":
			shake(12)
		"phase":
			_on_phase(e)


func _on_phase(e: Dictionary) -> void:
	match e.phase:
		2:
			if e.enemy.kind == "demon":
				float_text(Vector2(480, 260), "대마왕이 화가 났어요!", Color(1, 0.6, 0.5), 40)
			else:
				float_text(Vector2(480, 260), "드래곤이 날아올라요!", Color(0.9, 0.7, 1), 40)
		3:
			float_text(Vector2(420, 260), "가슴 비늘이 빛나요! 사슬 무기로!", Color(1, 0.9, 0.5), 40)


func _play_input(event: InputEvent) -> void:
	var g := gesture.feed(event)
	if g.is_empty():
		return
	match g.type:
		"tap":
			tap_at(g.pos)
		"swipe":
			if absf(g.dir.x) >= absf(g.dir.y) * 0.8:
				do_roll(g.dir.x)
		"hold":
			release_chain(g.pos, g.held)


## 톡: 적 가까이를 눌렀고 검이 닿으면 치고, 아니면 그쪽으로 걸어가요.
func tap_at(p: Vector2) -> void:
	var target := battle.sword_target()
	if not target.is_empty() and absf(p.x - target.x) <= float(target.radius) + 140.0:
		do_sword()
		return
	for e in battle.alive_enemies():
		if absf(p.x - e.x) <= float(e.radius) + 60.0:
			battle.walk_to(e.x - signf(e.x - battle.hero_x) * (float(e.radius) + 70.0))
			return
	battle.walk_to(p.x)


func do_sword() -> bool:
	var e := battle.sword()
	if e.is_empty():
		return false
	prince.play_pose(Prince.Pose.SWING, 0.18)
	if e.blocked:
		float_text(Vector2(e.x - 60, GROUND_Y - 260), "팅! 틈을 노려요", Color(0.8, 0.8, 0.9), 26)
		return true
	_flash[e.id] = 0.12
	float_text(Vector2(e.x - 20, GROUND_Y - 260), str(int(round(float(battle.stats.sword) * battle.damage_mult()))), Color(1, 1, 0.8), 30)
	impact(Vector2(e.x, GROUND_Y - 100), ["퍽!", "챙!", "슉!"][randi() % 3], Color(1, 0.95, 0.5), 0.7 if not e.boss else 0.9)
	if e.state == "dead":
		_on_enemy_defeated(e)
	return true


func do_roll(dir: float) -> void:
	if battle.roll(dir):
		prince.play_pose(Prince.Pose.ROLL, float(battle.stats.roll_invuln))


func release_chain(p: Vector2, held: float) -> void:
	prince.charge = 0.0
	if battle.charge_ratio(held) < 1.0:
		float_text(Vector2(battle.hero_x - 90, GROUND_Y - 250), "힘을 더 모아요", Color(1, 0.9, 0.7), 28)
		return
	if absf(p.x - battle.hero_x) > 30.0:
		battle.facing = signf(p.x - battle.hero_x)
	var r := battle.chain()
	prince.play_pose(Prince.Pose.SWING, 0.3)
	_chain_fx = {"t": 0.0, "kind": battle.stats.chain_kind, "dir": battle.facing}
	if r.blocked:
		float_text(Vector2(battle.hero_x - 70, GROUND_Y - 260), "꼬리를 막았어요!", Color(0.6, 1, 0.6), 32)
	for e in r.hit:
		if e.blocked:
			float_text(Vector2(e.x - 60, GROUND_Y - 300), "팅! 틈을 노려요", Color(0.8, 0.8, 0.9), 28)
			continue
		_flash[e.id] = 0.15
		impact(Vector2(e.x, GROUND_Y - 130), "콰지직!", Color(0.45, 1, 0.4), 1.4)
		if e.state == "dead":
			_on_enemy_defeated(e)
	if not r.hit.is_empty():
		shake(6)


var _chain_fx := {}


func use_gauge() -> void:
	if phase != Phase.PLAY or paused or not _gauge_ready():
		return
	if gauge_mode == "fist":
		var e := battle.fist()
		if e.is_empty():
			return
		_flash[e.id] = 0.3
		prince.play_pose(Prince.Pose.SWING, 0.5)
		float_text(Vector2(e.x - 120, 200), "-%d" % (int(battle.stats.str) * 10), Color(1, 0.8, 0.3), 48)
		impact(Vector2(e.x, GROUND_Y - 200), "근육 주먹!!", Color(1, 0.6, 0.15), 2.2)
		if e.state == "dead":
			_on_enemy_defeated(e)
	_on_gauge_used()


func _on_enemy_defeated(e: Dictionary) -> void:
	float_text(Vector2(e.x - 50, GROUND_Y - 200), "쓰러졌어요!", Color(1, 0.95, 0.6), 30)
	impact(Vector2(e.x, GROUND_Y - 150), "쾅!!" if e.boss else "퍽!", Color(1, 0.8, 0.2), 1.8 if e.boss else 1.0)


# ------------------------------------------------------------------ 화면 위 표시

## 둥근 막대 (귀여운 디자인 제안)
func _bar(pos: Vector2, size: Vector2, color: Color) -> Panel:
	var r := Panel.new()
	var dark := color.get_luminance() < 0.3
	r.add_theme_stylebox_override("panel", Cute.round_box(color, int(size.y / 2), Color.WHITE, 3 if dark else 0))
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(r)
	return r


func _update_hud() -> void:
	if not _hp_label:
		return
	var max_hp := int(battle.stats.max_hp)
	_hp_label.text = "똥 왕자 %d / %d" % [battle.hero_hp, max_hp]
	_hp_fill.size.x = 300.0 * battle.hero_hp / max_hp
	var b := battle.boss()
	_boss_bar.visible = not b.is_empty()
	_boss_fill.visible = not b.is_empty()
	if b.is_empty():
		var n := battle.alive_enemies().size()
		_boss_label.text = "남은 무사 %d" % n if n > 0 else ""
	else:
		_boss_label.text = "%s %d / %d" % [b.name, b.hp, b.max_hp]
		_boss_fill.size.x = 460.0 * b.hp / b.max_hp
	if _gauge_fill:
		_gauge_fill.size.x = 260.0 * battle.gauge
		_gauge_button.visible = battle.gauge >= 1.0 and phase == Phase.PLAY and _gauge_ready()
	_info_label.text = _info_text()


func _info_text() -> String:
	return ""


# ------------------------------------------------------------------ 그리기

func _draw_battle() -> void:
	var n := _draw_node
	for e in battle.enemies:
		if e.state == "dead":
			continue
		var flash: bool = _flash.has(e.id)
		if not view3d:      # 3D 화면에서는 3D가 적을 그려요
			_draw_enemy(n, e, flash)
		# 적 체력 (무사만 머리 위에)
		if not e.boss:
			var w := 76.0
			var y := GROUND_Y - 156
			n.draw_line(Vector2(e.x - w / 2, y), Vector2(e.x + w / 2, y), Color(0.36, 0.16, 0.26), 14)
			if e.hp > 0:
				n.draw_line(Vector2(e.x - w / 2, y), Vector2(e.x - w / 2 + w * e.hp / e.max_hp, y), Cute.PINK, 8)
			Cute.heart(n, Vector2(e.x - w / 2 - 6, y), 9, Cute.PINK)
	if view3d:
		for e in battle.enemies:
			if e.kind.begins_with("dragon") and e.state == "recover" and not battle.is_guarded(e):
				n.draw_string(ThemeDB.fallback_font, Vector2(e.x - 60, GROUND_Y - 330), "지금이야!", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 0.5))


func _draw_enemy(n: Node2D, e: Dictionary, flash: bool) -> void:
	match e.kind:
		"warrior":
			_draw_warrior(n, e, flash)
		"demon":
			_draw_demon(n, e, flash)
		_:
			_draw_dragon(n, e, flash)


func _draw_warnings(n: Node2D) -> void:
	var font := ThemeDB.fallback_font
	for e in battle.enemies:
		if e.state != "windup":
			continue
		var atk: Dictionary = e.attack
		var k: float = clampf(e.t / battle.warn_time(atk), 0.0, 1.0)
		var red := Color(1, 0.15, 0.1, 0.25 + 0.35 * k)
		match atk.type:
			"melee":
				var x0: float = e.x + e.facing * e.radius
				n.draw_rect(Rect2(minf(x0, x0 + e.facing * atk.range), GROUND_Y - 10, absf(atk.range), 24), red)
			"slam_self":
				n.draw_rect(Rect2(e.x - atk.range, GROUND_Y - 10, atk.range * 2, 24), red)
			"beam", "fly_tail":
				n.draw_rect(Rect2(e.target_x - atk.range, GROUND_Y - 10, atk.range * 2, 24), red)
				if atk.type == "beam":
					n.draw_line(Vector2(e.target_x, 120), Vector2(e.target_x, GROUND_Y), Color(0.8, 0.3, 1, 0.15 + 0.3 * k), 6 + 30 * k)
			"charge":
				var lo: float = minf(e.x, e.target_x)
				n.draw_rect(Rect2(lo, GROUND_Y - 10, absf(e.target_x - e.x), 24), red)
		var top_y := GROUND_Y - (420.0 if e.kind.begins_with("dragon") else (260.0 if e.kind == "demon" else 170.0))
		var hx: float = e.target_x if e.airborne else e.x
		n.draw_string(font, Vector2(hx - 16, top_y), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(1, 0.25, 0.2))
		n.draw_string(font, Vector2(hx - 70, top_y + 34), atk.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.9, 0.85))
	# 사슬 무기 효과
	if not _chain_fx.is_empty():
		_chain_fx.t += get_process_delta_time()
		var t: float = _chain_fx.t
		var hx := battle.hero_x
		if _chain_fx.kind == "spin":
			n.draw_arc(Vector2(hx, GROUND_Y - 60), Battle.SPIN_RANGE, t * 20, t * 20 + 5.5, 40, Color(0.3, 1, 0.4, 1.0 - t * 2), 10)
		else:
			var reach := Battle.PIERCE_RANGE if _chain_fx.kind == "pierce" else Battle.CHAIN_RANGE
			var x: float = hx + _chain_fx.dir * reach * clampf(t / 0.25, 0, 1)
			for i in 3:
				n.draw_arc(Vector2(x, GROUND_Y - 60), 22 + i * 12, t * 20 + i, t * 20 + i + 4.5, 16, Color(0.3, 0.95, 0.4, 1.0 - t * 2), 7)
		if t > 0.5:
			_chain_fx = {}


func _body_color(base: Color, flash: bool) -> Color:
	return base.lerp(Color.WHITE, 0.7) if flash else base


func _draw_warrior(n: Node2D, e: Dictionary, flash: bool) -> void:
	var x: float = e.x
	var f: float = e.facing
	var col := _body_color(Color(0.62, 0.42, 0.26), flash)
	var dark := _body_color(Color(0.42, 0.27, 0.15), flash)
	_ellipse(n, Vector2(x, GROUND_Y - 24), Vector2(45, 27), dark)
	_ellipse(n, Vector2(x, GROUND_Y - 26), Vector2(42, 24), col)
	_ellipse(n, Vector2(x, GROUND_Y - 58), Vector2(35, 22), dark)
	_ellipse(n, Vector2(x, GROUND_Y - 60), Vector2(32, 19), col.lightened(0.06))
	_ellipse(n, Vector2(x, GROUND_Y - 86), Vector2(23, 16), dark)
	_ellipse(n, Vector2(x, GROUND_Y - 88), Vector2(20, 13), col.lightened(0.12))
	_ellipse(n, Vector2(x - 16, GROUND_Y - 36), Vector2(9, 5), Color(1, 1, 1, 0.3))
	# 투구 (제안: 무사 모습은 원작 그림을 보고 임시로)
	var helm := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		helm.append(Vector2(x, GROUND_Y - 100) + Vector2(cos(a) * 28, sin(a) * 18))
	n.draw_colored_polygon(helm, Color(0.66, 0.68, 0.8))
	n.draw_rect(Rect2(x - 30, GROUND_Y - 104, 60, 8), Color(0.5, 0.52, 0.66))
	n.draw_circle(Vector2(x, GROUND_Y - 124), 8, Cute.PINK)
	# 똘망한 눈 (조금 심술 난 눈썹)
	for s in [-1.0, 1.0]:
		var ec := Vector2(x + 8 * f + s * 11, GROUND_Y - 64)
		Cute.eye(n, ec, 7.5, Vector2(f, 0))
		n.draw_line(ec + Vector2(-7, -12 + s * f * 3), ec + Vector2(7, -12 - s * f * 3), Cute.INK, 3)
	Cute.blush(n, Vector2(x + 8 * f - 22, GROUND_Y - 50), 5)
	Cute.blush(n, Vector2(x + 8 * f + 22, GROUND_Y - 50), 5)
	var raised: bool = e.state == "windup"
	var hand := Vector2(x + 34 * f, GROUND_Y - 60)
	var tip := hand + (Vector2(10 * f, -70) if raised else Vector2(60 * f, -20))
	n.draw_line(hand, tip, Color(0.5, 0.5, 0.62), 10)
	n.draw_line(hand, tip, Color(0.92, 0.94, 1.0), 6)
	n.draw_circle(hand, 7, Color(0.62, 0.42, 0.26))


func _draw_demon(n: Node2D, e: Dictionary, flash: bool) -> void:
	var x: float = e.x
	var f: float = e.facing
	var col := _body_color(Color(0.48, 0.3, 0.22), flash)
	if e.state == "windup":
		col = col.lerp(Color(0.9, 0.3, 0.3), 0.3)
	var dark := col.darkened(0.35)
	_ellipse(n, Vector2(x, GROUND_Y - 38), Vector2(86, 46), dark)
	_ellipse(n, Vector2(x, GROUND_Y - 40), Vector2(82, 42), col)
	_ellipse(n, Vector2(x, GROUND_Y - 98), Vector2(66, 38), dark)
	_ellipse(n, Vector2(x, GROUND_Y - 100), Vector2(62, 34), col.lightened(0.06))
	_ellipse(n, Vector2(x, GROUND_Y - 148), Vector2(46, 30), dark)
	_ellipse(n, Vector2(x, GROUND_Y - 150), Vector2(42, 26), col.lightened(0.12))
	_ellipse(n, Vector2(x - 34, GROUND_Y - 56), Vector2(16, 8), Color(1, 1, 1, 0.25))
	# 망토 깃 (제안)
	n.draw_colored_polygon(PackedVector2Array([Vector2(x - 60, GROUND_Y - 120), Vector2(x - 80, GROUND_Y - 150), Vector2(x - 40, GROUND_Y - 128)]), Color(0.75, 0.3, 0.45))
	n.draw_colored_polygon(PackedVector2Array([Vector2(x + 60, GROUND_Y - 120), Vector2(x + 80, GROUND_Y - 150), Vector2(x + 40, GROUND_Y - 128)]), Color(0.75, 0.3, 0.45))
	# 뿔 (원작 그림: 뿔 달린 대마왕)
	for s in [-1.0, 1.0]:
		n.draw_colored_polygon(PackedVector2Array([
			Vector2(x + s * 18, GROUND_Y - 168), Vector2(x + s * 36, GROUND_Y - 166), Vector2(x + s * 52, GROUND_Y - 222)]), Color(0.92, 0.88, 0.78))
	for s in [-16.0, 16.0]:
		var ec := Vector2(x + s + 10 * f, GROUND_Y - 110)
		n.draw_circle(ec, 13, Color(1, 0.9, 0.5))
		n.draw_circle(ec + Vector2(2 * f, 1), 8, Color(0.85, 0.2, 0.25))
		n.draw_circle(ec + Vector2(2 * f - 3, -3), 3, Color.WHITE)
		n.draw_line(ec + Vector2(-12, -16 - s * 0.25), ec + Vector2(12, -16 + s * 0.25), Cute.INK, 5)
	# 심술 입과 작은 송곳니
	n.draw_arc(Vector2(x + 10 * f, GROUND_Y - 76), 16, PI + 0.5, TAU - 0.5, 10, Cute.INK, 4)
	n.draw_colored_polygon(PackedVector2Array([Vector2(x + 10 * f - 12, GROUND_Y - 84), Vector2(x + 10 * f - 4, GROUND_Y - 84), Vector2(x + 10 * f - 8, GROUND_Y - 74)]), Color.WHITE)
	n.draw_colored_polygon(PackedVector2Array([Vector2(x + 10 * f + 4, GROUND_Y - 84), Vector2(x + 10 * f + 12, GROUND_Y - 84), Vector2(x + 10 * f + 8, GROUND_Y - 74)]), Color.WHITE)


func _draw_dragon(n: Node2D, e: Dictionary, flash: bool) -> void:
	var x: float = e.target_x if e.airborne else e.x
	var lift := 0.0
	if e.airborne:
		lift = 260.0
	elif e.state == "down":
		lift = -40.0
	var f: float = e.facing
	var base := Vector2(x, GROUND_Y - lift)
	var body := _body_color(PURPLE, flash)
	var dark := _body_color(PURPLE_DARK, flash)
	# 꼬리
	n.draw_line(base + Vector2(-f * 90, -50), base + Vector2(-f * 200, -10), dark, 30)
	n.draw_circle(base + Vector2(-f * 200, -10), 15, dark)
	# 몸통
	_ellipse(n, base + Vector2(0, -90), Vector2(120, 80), dark)
	_ellipse(n, base + Vector2(0, -92), Vector2(112, 72), body)
	# 가슴 비늘 (3단계에서 빛나요)
	var glowing: bool = e.kind == "dragon_final" or e.phase == 3
	_ellipse(n, base + Vector2(f * 40, -80), Vector2(36, 44), Color(1, 0.85, 0.3, 0.9) if glowing else Color(0.62, 0.42, 0.8))
	# 날개
	if e.airborne or e.phase >= 2:
		n.draw_colored_polygon(PackedVector2Array([base + Vector2(-20, -140), base + Vector2(-140, -260), base + Vector2(-60, -130)]), dark)
	# 긴 목과 가시 머리 (원작 그림)
	var head := base + Vector2(f * 120, -250)
	if e.state == "windup" and e.attack.get("type", "") == "beam":
		head = base + Vector2(f * 150, -230)
	n.draw_line(base + Vector2(f * 50, -140), head, dark, 50)
	n.draw_line(base + Vector2(f * 50, -140), head, body, 38)
	for i in 5:
		var a := -2.6 + i * 0.32
		var dir := Vector2(cos(a) * -f, sin(a))
		n.draw_colored_polygon(PackedVector2Array([head + dir * 40 + dir.orthogonal() * 10, head + dir * 80, head + dir * 40 - dir.orthogonal() * 10]), dark)
	n.draw_circle(head, 52, dark)
	n.draw_circle(head, 48, body)
	n.draw_circle(head + Vector2(-f * 18, -22), 10, Color(1, 1, 1, 0.25))
	n.draw_circle(head + Vector2(f * 8, -14), 16, Color(1, 0.93, 0.45))
	Cute.eye(n, head + Vector2(f * 11, -14), 9, Vector2(f, 0), false)
	Cute.blush(n, head + Vector2(-f * 14, 12), 9)
	var open: bool = e.state == "windup"
	var mc := head + Vector2(f * 14, 18)
	var mouth := PackedVector2Array()
	for i in 13:
		var t := PI * i / 12.0
		mouth.append(mc + Vector2(cos(t) * 26, sin(t) * (26.0 if open else 9.0)))
	n.draw_colored_polygon(mouth, Color(0.45, 0.1, 0.22))
	n.draw_colored_polygon(PackedVector2Array([mc + Vector2(-16, 0), mc + Vector2(-6, 0), mc + Vector2(-11, 10)]), Color.WHITE)
	n.draw_colored_polygon(PackedVector2Array([mc + Vector2(6, 0), mc + Vector2(16, 0), mc + Vector2(11, 10)]), Color.WHITE)
	if e.state == "down":
		n.draw_string(ThemeDB.fallback_font, head + Vector2(-30, -70), "@_@", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)
	elif e.state == "recover" and not battle.is_guarded(e):
		n.draw_string(ThemeDB.fallback_font, base + Vector2(-60, -200), "지금이야!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 1, 0.5))


func _ellipse(n: Node2D, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	n.draw_colored_polygon(pts, col)
