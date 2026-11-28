extends Control
## 장 고르기: 열린 장을 골라서 바로 할 수 있어요. 깬 장에는 최고 별이 보여요.

const Sound := preload("res://scripts/audio/sound.gd")
const Save := preload("res://scripts/save_data.gd")
const Session := preload("res://scripts/game_session.gd")
const Chapters := preload("res://scripts/chapters.gd")
const TITLE_SCENE := "res://scenes/title/title_screen.tscn"
const SURVIVOR_SCENE := "res://scenes/survivor/survivor.tscn"
const FORGE_SCENE := "res://scenes/survivor/forge.tscn"
const SurvivorRules := preload("res://scenes/survivor/survivor_rules.gd")
const HERO_SCENE := "res://scenes/survivor/hero_select.tscn"
const WARDROBE_SCENE := "res://scenes/survivor/wardrobe.tscn"
const Cute := preload("res://scripts/art/cute.gd")
const ScreenMode := preload("res://scripts/screen_mode.gd")


func _ready() -> void:
	ScreenMode.portrait(get_tree())
	Sound.ensure()
	add_child(Cute.Paper.new())
	var title := Label.new()
	title.text = "무엇을 할까요?"
	title.position = Vector2(0, 30)
	title.size = Vector2(720, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Cute.style_label(title, 58, Cute.PINK.darkened(0.15), Color.WHITE, 12)
	add_child(title)
	# 이야기: 1~8장을 한 칸으로 (2026-11-28 사용자: "1~8장까지 보이게 하지 말고 한 칸으로 진행 사항 알 수 있게")
	var cleared := 0
	var stars_total := 0
	for n in range(1, Chapters.COUNT + 1):
		if Save.best_stars(n) > 0:
			cleared += 1
		stars_total += Save.best_stars(n)
	var next := Save.continue_chapter(Chapters.COUNT)
	var dots := ""
	for n in range(1, Chapters.COUNT + 1):
		dots += "●" if Save.best_stars(n) > 0 else ("◎" if n == next else "○")
	var story_text := "이야기\n%d장 %s\n%s   %d/%d장  ★%d" % [next, Chapters.title(next), dots, cleared, Chapters.COUNT, stars_total]
	if cleared >= Chapters.COUNT:
		story_text = "이야기 (다 깼어요!)\n다시 보기: %d장 %s\n%s   ★%d" % [next, Chapters.title(next), dots, stars_total]
	var story := Cute.button(story_text, Vector2(660, 300), 34, Cute.PEACH)
	story.name = "Btn_이야기"
	story.position = Vector2(30, 140)
	story.pressed.connect(_open.bind(next))
	add_child(story)
	var back := Cute.button("← 처음으로", Vector2(260, 76), 30, Cute.CARAMEL)
	back.name = "Btn_처음으로"
	back.position = Vector2(230, 1160)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))
	add_child(back)
	# 서바이버 모드: 처음부터 열려 있어요
	var coins := Save.survivor_coins()
	var best := Save.survivor_best()
	var stage := mini(Save.survivor_stage(), Save.survivor_stages_open() - 1)
	var label := "똥제국 서바이버!\n무대 %d: %s" % [stage + 1, SurvivorRules.STAGES[stage].name]
	if coins > 0 or best > 0.0:
		label += "\n(최고 %d:%02d, 똥전 %d)" % [int(best) / 60, int(best) % 60, coins]
	var surv := Cute.button(label, Vector2(500, 230), 34, Color(1, 0.72, 0.25))
	surv.name = "Btn_서바이버"
	surv.position = Vector2(110, 480)
	surv.pressed.connect(func() -> void: get_tree().change_scene_to_file(SURVIVOR_SCENE))
	add_child(surv)
	# 무대 바꾸기 (열린 무대만)
	for side in [-1, 1]:
		var arrow := Cute.button("◀" if side < 0 else "▶", Vector2(70, 230), 36, Color(0.95, 0.6, 0.2))
		arrow.name = "Btn_무대" + ("앞" if side < 0 else "뒤")
		arrow.position = Vector2(30 if side < 0 else 620, 480)
		var target: int = stage + int(side)
		arrow.disabled = target < 0 or target >= Save.survivor_stages_open()
		arrow.pressed.connect(func() -> void:
			Save.set_survivor_stage(target)
			get_tree().reload_current_scene())
		add_child(arrow)
	var stage_info := Label.new()
	stage_info.text = "열린 무대 %d / %d  (대마왕을 물리치면 다음 무대)" % [Save.survivor_stages_open(), SurvivorRules.STAGES.size()]
	stage_info.position = Vector2(0, 712)
	stage_info.size = Vector2(720, 30)
	stage_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Cute.style_label(stage_info, 22, Cute.COCOA)
	add_child(stage_info)
	var heroes := Cute.button("캐릭터", Vector2(320, 150), 34, Cute.MINT)
	heroes.name = "Btn_캐릭터"
	heroes.position = Vector2(30, 760)
	heroes.pressed.connect(func() -> void: get_tree().change_scene_to_file(HERO_SCENE))
	add_child(heroes)
	var forge := Cute.button("똥 대장간", Vector2(320, 150), 34, Color(0.62, 0.5, 0.4))
	forge.name = "Btn_대장간"
	forge.position = Vector2(370, 760)
	forge.pressed.connect(func() -> void: get_tree().change_scene_to_file(FORGE_SCENE))
	add_child(forge)
	var wardrobe := Cute.button("똥 옷장 (모자·신발·장신구)", Vector2(660, 130), 34, Color(0.75, 0.55, 0.85))
	wardrobe.name = "Btn_옷장"
	wardrobe.position = Vector2(30, 940)
	wardrobe.pressed.connect(func() -> void: get_tree().change_scene_to_file(WARDROBE_SCENE))
	add_child(wardrobe)


func _open(n: int) -> void:
	Session.hard_mode = false
	Session.clear_checkpoint()
	get_tree().change_scene_to_file(Chapters.scene(n))

