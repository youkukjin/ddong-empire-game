extends Control
## 장 고르기: 열린 장을 골라서 바로 할 수 있어요. 깬 장에는 최고 별이 보여요.

const Sound := preload("res://scripts/audio/sound.gd")
const Save := preload("res://scripts/save_data.gd")
const Session := preload("res://scripts/game_session.gd")
const Chapters := preload("res://scripts/chapters.gd")
const TITLE_SCENE := "res://scenes/title/title_screen.tscn"
const SURVIVOR_SCENE := "res://scenes/survivor/survivor.tscn"
const Cute := preload("res://scripts/art/cute.gd")


func _ready() -> void:
	Sound.ensure()
	add_child(Cute.Paper.new())
	var title := Label.new()
	title.text = "장 고르기"
	title.position = Vector2(0, 30)
	title.size = Vector2(1280, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Cute.style_label(title, 58, Cute.PINK.darkened(0.15), Color.WHITE, 12)
	add_child(title)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(70, 130)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	add_child(grid)
	for n in range(1, Chapters.COUNT + 1):
		grid.add_child(_chapter_button(n))
	var back := Cute.button("← 처음으로", Vector2(260, 76), 30, Cute.CARAMEL)
	back.name = "Btn_처음으로"
	back.position = Vector2(70, 610)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))
	add_child(back)
	# 서바이버 모드 (제안): 처음부터 열려 있어요
	var coins := Save.survivor_coins()
	var best := Save.survivor_best()
	var label := "똥제국 서바이버!"
	if coins > 0 or best > 0.0:
		label += "  (최고 %d:%02d, 똥전 %d)" % [int(best) / 60, int(best) % 60, coins]
	var surv := Cute.button(label, Vector2(800, 76), 30, Color(1, 0.72, 0.25))
	surv.name = "Btn_서바이버"
	surv.position = Vector2(410, 610)
	surv.pressed.connect(func() -> void: get_tree().change_scene_to_file(SURVIVOR_SCENE))
	add_child(surv)


func _chapter_button(n: int) -> Button:
	var open := Save.is_unlocked(n) and Chapters.is_built(n)
	var stars := Save.best_stars(n)
	var text := "%d장\n%s\n" % [n, Chapters.title(n)]
	if not Chapters.is_built(n):
		text += "만드는 중"
	elif not Save.is_unlocked(n):
		text += "잠김"
	else:
		text += "★".repeat(stars) + "☆".repeat(3 - stars)
	var b := Cute.button(text, Vector2(270, 200), 30, Cute.CHAPTER_COLORS[n - 1] if open else Cute.LOCKED)
	b.name = "Chapter%d" % n
	b.disabled = not open
	b.pressed.connect(_open.bind(n))
	return b


func _open(n: int) -> void:
	Session.hard_mode = false
	Session.clear_checkpoint()
	get_tree().change_scene_to_file(Chapters.scene(n))

