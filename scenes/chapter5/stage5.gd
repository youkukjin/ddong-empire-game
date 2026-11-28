extends "res://scripts/battle/battle_stage.gd"
## 5장 '무사들과 대마왕' 스테이지예요 (1차 보스).
## 성벽 뒤의 똥 무사들을 두 번에 걸쳐 물리치고, 뿔 달린 똥 대마왕과 싸워요.
##
## 조작 (2장에서 익힌 것):
## - 톡: 적 가까이면 검, 멀면 걸어가기
## - 꾹 눌렀다 떼기: 사슬 무기 (누른 쪽으로 날아가요. 무사는 뒤로 밀리고 하던 공격이 끊겨요)
## - 옆으로 쓸기: 구르기 (빨간 경고가 끝나는 순간 굴러요)
## 무사·대마왕의 공격과 숫자는 battle_rules.gd에 있어요 (제안).

const BOSS_HEAL := 20             # 웨이브 사이에 숨 고르기: 체력 +20 (제안)
const WAVES := [
	[["warrior", 900.0], ["warrior", 1120.0]],
	[["warrior", 950.0], ["warrior", 1150.0], ["warrior", 120.0]],
	[["demon", 1050.0]],
]

var wave := 0
var from_checkpoint := false


func _init() -> void:
	chapter = 5
	backdrop_kind = "arena"


func _make_battle() -> Battle:
	return Battle.new()


func _battle_setup() -> void:
	from_checkpoint = Session.chapter_checkpoint.get(5, "") == "boss"
	Session.chapter_checkpoint.erase(5)
	Session.persist()
	wave = 2 if from_checkpoint else 0


func _intro_pages() -> Array:
	if from_checkpoint:
		return ["대마왕 앞에서 다시 시작해요!\n체력을 가득 채웠어요."]
	return [
		"성벽에 뚫린 구멍으로 들어가자,\n똥 무사들이 길을 막았어요.\n그 뒤에는 뿔 달린 똥 대마왕이 있었어요.",
		"어떻게 할까요?\n\n• 톡: 적 가까이면 검으로 치고, 멀면 걸어가요\n• 꾹 눌렀다 떼기: 사슬 무기! 누른 쪽으로 날아가요\n  (무사는 뒤로 밀리고 하던 공격이 끊겨요)\n• 옆으로 쓱: 굴러요. 빨간 경고가 끝나는 순간 구르면 안 다쳐요\n\n무사들을 두 번 물리치면 대마왕이 나와요.",
	]


func _on_play_started() -> void:
	_spawn_wave()


func _spawn_wave() -> void:
	for s in WAVES[wave]:
		battle.spawn(s[0], s[1])
	if wave == 2:
		Session.chapter_checkpoint[5] = "boss_reached"
		Session.persist()
		float_text(Vector2(440, 250), "똥 대마왕이 나타났어요!", Color(1, 0.7, 0.6), 44)
	else:
		float_text(Vector2(500, 250), "똥 무사들 %d/2" % (wave + 1), Color(1, 0.9, 0.7), 40)


func _on_enemies_cleared() -> void:
	if wave < WAVES.size() - 1:
		wave += 1
		battle.hero_hp = mini(battle.hero_hp + BOSS_HEAL, int(battle.stats.max_hp))
		float_text(Vector2(battle.hero_x - 60, GROUND_Y - 280), "숨 고르기 +%d" % BOSS_HEAL, Color(0.6, 1, 0.6), 30)
		_spawn_wave()
		return
	_win()


func _info_text() -> String:
	if wave < 2:
		return "무사 무리 %d/2" % (wave + 1)
	return "대마왕: 빨간 땅을 피하고, 공격이 끝난 틈에 쳐요"


## 별 3개: 체력 70% 이상 + 처음부터 · 별 2개: 체력 35% 이상 · 별 1개: 이김
func star_rating() -> int:
	var ratio := float(battle.hero_hp) / float(battle.stats.max_hp)
	if ratio >= 0.7 and not from_checkpoint:
		return 3
	if ratio >= 0.35:
		return 2
	return 1


func _win() -> void:
	phase = Phase.OUTRO
	_refresh_pause_button()
	Session.chapter_checkpoint.erase(5)
	Session.persist()
	float_text(Vector2(420, 260), "똥 대마왕을 물리쳤어요!", Color(1, 0.95, 0.6), 46)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.finished.connect(func() -> void:
		finish_win(star_rating(), "대마왕을 물리쳤어요!", "남은 체력 %d / %d · 걸린 시간 %s\n아슬아슬하게 피한 공격 %d번" % [
			battle.hero_hp, int(battle.stats.max_hp), time_text(battle.elapsed), battle.dodges]))


func _on_hero_down() -> void:
	var extra: Array = []
	if Session.chapter_checkpoint.get(5, "") == "boss_reached":
		extra.append(["대마왕부터", _restart_boss])
	finish_fail("똥 왕자가 쓰러졌어요.\n주로 맞은 공격: %s" % battle.hit_summary(), "빨간 경고가 보이면 끝나기 직전에 옆으로 쓱! 대마왕은 공격이 끝난 뒤에 잠깐 멈춰요. 그때 쳐요.", extra)


func _restart_boss() -> void:
	Session.chapter_checkpoint[5] = "boss"
	Session.persist()
	change_scene(scene_file_path)


func _before_restart() -> void:
	Session.chapter_checkpoint.erase(5)
	Session.persist()


func _outro_pages() -> Array:
	return [
		"똥 무사들과 똥 대마왕이 쓰러졌어요.\n그때, 보라색 광선이 \"콰앙!\" 하고 쏟아졌어요.\n똥 드래곤이었어요!",
		"지친 똥 왕자는 드래곤을 이길 수 없었어요.\n\"일주일 뒤에 다시 올 거야. 더 강해져서!\"\n\n6장 '재도전'으로 이어져요.",
	]
