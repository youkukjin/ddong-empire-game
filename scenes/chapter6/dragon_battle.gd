extends "res://scripts/battle/battle_stage.gd"
## 6장 '재도전' 2부: 7일째, 똥 드래곤과 다시 싸워요 (2차 보스).
## 일주일 동안 키운 능력치·무기·작전 회의 비밀이 그대로 싸움에 들어가요.
## 드래곤 체력 1,500, 보라색 광선 40, 세 단계 (6장 설계 문서의 제안 값).
## 근육 주먹: 때리면 +5%, 아슬아슬하게 피하면 +10%. 다 차면 버튼을 눌러 힘 × 10!

const Growth := preload("res://scenes/chapter6/growth_rules.gd")
const PREP_SCENE := "res://scenes/chapter6/stage6.tscn"

var growth: RefCounted


func _init() -> void:
	chapter = 6
	backdrop_kind = "lair"
	gauge_mode = "fist"


func _make_battle() -> Battle:
	growth = Growth.load_or_new()
	var b := Battle.new(growth.battle_stats())
	for s in growth.secrets:
		b.secrets[s] = true
	b.hero_x = 260.0
	b.walk_target = 260.0
	return b


func _battle_setup() -> void:
	prince.arm_level = growth.arm_level()
	prince.sword_level = growth.sword_lv


func _intro_pages() -> Array:
	var tips := "• 발톱 할퀴기: 뒤로 굴러요\n• 보라색 광선: 땅의 빨간 띠에서 굴러 나가요\n• 체력 1,000 아래: 날아올랐다가 꼬리로 내리쳐요. 내려온 뒤 3초가 기회!\n• 체력 450 아래: 가슴 비늘이 빛나요. 사슬 무기가 1.5배!"
	return [
		"7일째, 똥 왕자는 드래곤의 본거지로 돌아왔어요.\n\"이번에는 꼭 이길 거야!\"",
		"드래곤 공격\n\n%s\n\n근육 주먹 게이지가 다 차면 오른쪽 아래 버튼을 눌러요!" % tips,
	]


func _on_play_started() -> void:
	battle.spawn("dragon", 1000.0)


func _info_text() -> String:
	var b := battle.boss()
	if b.is_empty():
		return ""
	return "드래곤 %d단계" % int(b.phase)


func _on_enemies_cleared() -> void:
	phase = Phase.OUTRO
	_refresh_pause_button()
	float_text(Vector2(380, 230), "마지막 근육 주먹!", Color(1, 0.8, 0.3), 56)
	shake(18)
	var hits := 0
	for k in battle.hits_taken:
		hits += int(battle.hits_taken[k])
	var stars := 1
	if hits <= 2 and battle.elapsed <= 150.0:
		stars = 3
	elif hits <= 5:
		stars = 2
	# 7장에서 쓸 능력치를 남겨요
	Save.set_value("hero_stats", growth.battle_stats(), "chapter6")
	Save.set_value("hero_arm", growth.arm_level(), "chapter6")
	growth.save()
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.finished.connect(func() -> void:
		finish_win(stars, "드래곤을 쓰러뜨렸어요!", "걸린 시간 %s · 맞은 횟수 %d · 아슬아슬하게 피한 공격 %d번\nLv %d · 검 +%d · 사슬 무기 +%d" % [
			time_text(battle.elapsed), hits, battle.dodges, growth.level, growth.sword_lv, growth.chain_lv]))


func _on_hero_down() -> void:
	growth.losses += 1
	growth.save()
	var summary := battle.hit_summary()
	Session.chapter_checkpoint[6] = "lost:" + summary
	var body := "드래곤에게 졌어요.\n주로 맞은 공격: %s\n레벨·재료·강화는 그대로예요." % summary
	if growth.losses >= 3 and not growth.help_mode:
		body += "\n준비 화면에서 \"도움 모드\"(체력 +50%)를 켤 수 있어요."
	finish_fail(body, "경고가 끝나는 순간 구르면 안 다치고 근육 주먹 게이지도 많이 차요.", [["준비 화면으로", func() -> void: change_scene(PREP_SCENE)]])


func _before_restart() -> void:
	Session.chapter_checkpoint.erase(6)


func _outro_pages() -> Array:
	return [
		"큰 근육 주먹에 맞은 똥 드래곤이 쓰러졌어요!\n똥 제국 백성들이 환호했어요.",
		"그런데… 쓰러졌던 드래곤이 다시 몸을 일으켰어요.\n(제안: 7장으로 이어지는 장면이에요)\n\n7장 '각성과 결말'로 이어져요.",
	]
