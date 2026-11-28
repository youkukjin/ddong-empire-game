extends "res://scripts/battle/battle_stage.gd"
## 7장 '각성과 결말' 스테이지예요.
## 다시 일어난 똥 드래곤과 마지막으로 싸워요. 각성 게이지를 채워 똥의 신으로 각성하고, 드래곤을 완전히 물리쳐요.
## 원작: "드래곤을 완전히 물리치고, 똥 왕자가 똥의 신으로 각성".
## 싸우는 도중에 각성해서 마지막 일격을 하는 흐름, 각성 효과와 숫자는 (제안)이에요.
##
## - 조작은 5·6장과 같아요 (톡 = 검/걷기, 꾹 눌렀다 떼기 = 사슬 무기, 옆으로 쓸기 = 구르기)
## - 때리면 +5%, 아슬아슬하게 피하면 +10%. 드래곤 체력이 300 아래이고 게이지가 다 차면 "각성!" 버튼
## - 똥의 신: 12초 동안 안 다치고, 공격 3배, 언제든 때릴 수 있고, 사슬 무기를 바로 써요
## - 드래곤 체력이 바닥나도 각성하지 않으면 버텨요

const Growth := preload("res://scenes/chapter6/growth_rules.gd")
const Kit3D := preload("res://scripts/view3d/kit3d.gd")
const GOD_TIME := 12.0
const AWAKEN_HP := 300            # 드래곤 체력이 300 아래로 내려가야 각성할 수 있어요 (제안)

var awakened_once := false


func _init() -> void:
	chapter = 7
	backdrop_kind = "lair"
	gauge_mode = "awaken"


func _make_battle() -> Battle:
	var b := Battle.new(hero_stats())
	b.hero_x = 260.0
	b.walk_target = 260.0
	return b


## 6장에서 키운 능력치를 가져와요. 없으면 6장 설계의 균형형 능력치를 써요.
static func hero_stats() -> Dictionary:
	var saved = Save.get_value("hero_stats", {}, "chapter6")
	if saved is Dictionary and not saved.is_empty():
		return saved
	return {"max_hp": 130, "sword": 29, "chain": 58, "str": 19, "roll_invuln": 0.46, "charge_time": 1.52, "fist": false}


func _battle_setup() -> void:
	prince.arm_level = int(Save.get_value("hero_arm", 0, "chapter6"))
	battle.stats.fist = false


func _intro_pages() -> Array:
	return [
		"쓰러졌던 똥 드래곤이 다시 일어났어요.\n가슴 비늘이 더 밝게 빛났어요.\n\"이번이 진짜 마지막이야!\"",
		"어떻게 할까요?\n\n조작은 지난 싸움과 같아요.\n드래곤을 때리거나 아슬아슬하게 피하면 각성 게이지가 차요.\n드래곤 체력이 %d 아래로 내려가고 게이지가 다 차면\n오른쪽 아래 \"각성!\" 버튼을 눌러요.\n\n드래곤은 각성한 힘으로만 완전히 물리칠 수 있어요." % AWAKEN_HP,
	]


func _on_play_started() -> void:
	battle.spawn("dragon_final", 1000.0)


func _gauge_ready() -> bool:
	var b := battle.boss()
	return not b.is_empty() and int(b.hp) <= AWAKEN_HP


func _on_gauge_used() -> void:
	if not battle.awaken(GOD_TIME):
		return
	awakened_once = true
	prince.god = true
	float_text(Vector2(380, 230), "똥의 신으로 각성!", Color(1, 0.9, 0.4), 56)
	impact(Vector2(battle.hero_x, GROUND_Y - 200), "번쩍!!", Color(1, 0.85, 0.2), 2.4)


func _on_battle_event(e: Dictionary) -> void:
	if e.type == "strike" and battle.god_left <= 0.0:
		var b := battle.boss()
		if not b.is_empty() and b.hp <= 1:
			float_text(Vector2(420, 300), "드래곤이 버텨요! 각성해야 해요!", Color(1, 0.8, 0.6), 34)


func _info_text() -> String:
	if battle.god_left > 0.0:
		return "똥의 신! 남은 시간 %d초 · 언제든 때릴 수 있어요" % int(ceil(battle.god_left))
	if not _gauge_ready():
		return "드래곤 체력을 %d 아래로! 각성 게이지도 채워요 (때리기 +5%%, 아슬아슬 피하기 +10%%)" % AWAKEN_HP
	return "이제 각성할 수 있어요! 게이지가 다 차면 \"각성!\""


func _on_enemies_cleared() -> void:
	phase = Phase.OUTRO
	_refresh_pause_button()
	float_text(Vector2(360, 230), "똥 드래곤을 완전히 물리쳤어요!", Color(1, 0.95, 0.6), 50)
	impact(Vector2(800, 300), "콰과광!!", Color(1, 0.75, 0.2), 2.6)
	var hits := 0
	for k in battle.hits_taken:
		hits += int(battle.hits_taken[k])
	var stars := 3 if hits <= 2 else (2 if hits <= 5 else 1)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_callback(transform_to_god)
	tw.tween_interval(TRANSFORM_TIME + 1.2)
	tw.finished.connect(func() -> void:
		finish_win(stars, "똥의 신이 되었어요!", "걸린 시간 %s · 맞은 횟수 %d · 아슬아슬하게 피한 공격 %d번" % [
			time_text(battle.elapsed), hits, battle.dodges]))


## 원작대로 마지막에 똥 왕자가 똥의 신으로 변신해요 (변신 연출과 신의 모습은 제안).
## 1) 하늘에서 금빛 기둥이 내려오고 왕자가 빙글 돌며 떠올라요
## 2) 번쩍! 왕관이 벗겨져 떨어지고, 검붉은 몸·빨간 초승달 뿔·보라 망토·금빛 후광의 똥의 신이 나타나요
const TRANSFORM_TIME := 3.2
var transformed := false


func transform_to_god() -> void:
	prince.god = true
	prince.play_pose(Prince.Pose.CHEER, 99.0)
	var base: Vector2 = Vector2(clampf(prince.position.x, 380.0, 700.0), prince.position.y)
	hud_root.visible = false
	Sound.play("power", 0.7, 2.0)
	if view3d:
		view3d.flash(Color(0, 0, 0), 0.55)
		_light_pillar(base)
	float_text(Vector2(430, 140), "똥 왕자의 몸이 빛나요...!", Color(1, 0.9, 0.5), 40)
	var tw := create_tween()
	# 떠오르며 빙글빙글 (점점 빨리)
	tw.tween_property(prince, "position", base + Vector2(0, -110), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_method(func(v: float) -> void: prince.facing = 1.0 if sin(v) >= 0.0 else -1.0, 0.0, 18.0 * PI, 1.6).set_ease(Tween.EASE_IN)
	tw.parallel().tween_callback(func() -> void: Sound.play("power", 1.0, 3.0)).set_delay(0.8)
	tw.tween_callback(func() -> void:
		transformed = true
		prince.facing = 1.0
		prince.god = false
		prince.deity = true
		if view3d and view3d.prince3d:
			view3d.prince3d.deity = true
			view3d.prince3d.drop_crown()
		Sound.play("flash", 0.9, 3.0)
		Sound.play("roar", 0.6, 0.0)
		impact(prince.position + Vector2(0, -120), "번쩍!!!", Color(1, 0.9, 0.3), 3.0)
		if view3d:
			view3d.flash(Color(1, 0.95, 0.7), 0.8)
		shake(18))
	# 커지며 내려앉아요 (쿵!)
	tw.tween_property(prince, "scale", Vector2.ONE * 1.6, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(prince, "position:y", base.y, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		impact(base + Vector2(0, -20), "쿠웅!!", Color(1, 0.5, 0.2), 2.2)
		Sound.play("win", 0.8, -2.0)
		if view3d:
			view3d.comic(Vector2(640, 150), "똥의 신 탄생!!", Color(1, 0.85, 0.25), 2.2)
		else:
			float_text(Vector2(400, 120), "똥의 신 탄생!!", Color(1, 0.85, 0.25), 64))


func _light_pillar(at2d: Vector2) -> void:
	var v = view3d
	var foot: Vector3 = v.at(Vector2(at2d.x, GROUND_Y))
	var pillar := Kit3D.cylinder(v, 0.9, 0.9, 14.0, Color(1, 0.85, 0.3, 0.35), foot + Vector3(0, 7.0, 0), 2.5)
	var core := Kit3D.cylinder(v, 0.25, 0.25, 14.0, Color(1, 0.97, 0.8), foot + Vector3(0, 7.0, 0), 4.0, false)
	var ring := Kit3D.torus(v, 1.0, 1.25, Color(1, 0.8, 0.2), foot + Vector3(0, 0.05, 0), 3.0, false)
	var l := Kit3D.light(v, foot + Vector3(0, 2.0, 1.5), Color(1, 0.8, 0.4), 0.0, 8.0)
	pillar.scale = Vector3(0.05, 1, 0.05)
	core.scale = Vector3(0.05, 1, 0.05)
	# 기둥: 0.5초에 내려와서 변신 순간(1.6초)에 확 퍼지며 사라져요
	var tp := v.create_tween()
	tp.tween_property(pillar, "scale", Vector3.ONE, 0.5).set_ease(Tween.EASE_OUT)
	tp.parallel().tween_property(core, "scale", Vector3.ONE, 0.4).set_ease(Tween.EASE_OUT)
	tp.parallel().tween_property(l, "light_energy", 6.0, 1.6)
	tp.tween_interval(1.1)
	tp.tween_property(pillar, "scale", Vector3(3.0, 1, 3.0), 0.15)
	tp.parallel().tween_property(core, "scale", Vector3(3.0, 1, 3.0), 0.15)
	tp.tween_callback(func() -> void:
		pillar.queue_free()
		core.queue_free()
		l.light_energy = 2.0)
	# 바닥 고리: 계속 넓어지며 돌다가 사라져요
	var tr := v.create_tween().set_parallel()
	tr.tween_property(ring, "scale", Vector3.ONE * 3.0, TRANSFORM_TIME)
	tr.tween_property(ring, "rotation:y", 12.0, TRANSFORM_TIME)
	tr.chain().tween_callback(ring.queue_free)


func _on_hero_down() -> void:
	finish_fail("똥 왕자가 쓰러졌어요.\n주로 맞은 공격: %s" % battle.hit_summary(), "연속 광선은 세 번 구르기! 경고 끝에 맞춰 구르면 각성 게이지가 빨리 차요.")


func _outro_pages() -> Array:
	return [
		"똥 드래곤이 완전히 쓰러졌어요.\n빛나던 가슴 비늘도 조용해졌어요.",
		"하늘에서 금빛 기둥이 내려오고, 왕관이 툭 떨어졌어요.\n빨간 초승달 뿔과 보라 망토, 금빛 후광!\n똥 왕자는 똥의 신이 되었어요!\n(제안: 신의 모습과 글은 작가 확인 전이에요)",
		"8장 '평화'로 이어져요.",
	]
