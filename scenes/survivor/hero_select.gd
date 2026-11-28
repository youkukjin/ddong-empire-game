extends Control
## 캐릭터 고르기 (2026-11-28 사용자: "초반에는 약한 똥들, 똥 왕자는 똥전을 모아서 해금, 왕자 능력이 제일 좋게").
## 한 줄 = 3D 캐릭터 + 이름 + 체력·속도 + 시작 무기 + 특기 + 고르기/열기 버튼.

const Sound := preload("res://scripts/audio/sound.gd")
const Save := preload("res://scripts/save_data.gd")
const Cute := preload("res://scripts/art/cute.gd")
const ScreenMode := preload("res://scripts/screen_mode.gd")
const Rules := preload("res://scenes/survivor/survivor_rules.gd")
const HeroModels := preload("res://scenes/survivor/hero_models.gd")
const SURVIVOR_SCENE := "res://scenes/survivor/survivor.tscn"
const SELECT_SCENE := "res://scenes/title/chapter_select.tscn"
const FONT := preload("res://assets/fonts/Jua-Regular.ttf")

const BG := Color(0.17, 0.13, 0.15)
const SHELF := Color(0.3, 0.21, 0.16)
const CREAM := Color(0.95, 0.89, 0.76)
const GOLD := Color(0.85, 0.66, 0.25)

var coin_label: Label
var buttons: Dictionary = {}
var rows: Dictionary = {}


func _ready() -> void:
	ScreenMode.portrait(get_tree())
	Sound.ensure()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = "캐릭터 고르기"
	title.position = Vector2(0, 20)
	title.size = Vector2(720, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Cute.style_label(title, 56, GOLD, Color(0.08, 0.05, 0.05), 12)
	add_child(title)
	coin_label = Label.new()
	coin_label.position = Vector2(0, 88)
	coin_label.size = Vector2(720, 46)
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Cute.style_label(coin_label, 34, Color(1, 0.85, 0.35), Color(0.08, 0.05, 0.05), 8)
	add_child(coin_label)
	var y := 140.0
	for id in Rules.HEROES:
		_row(String(id), Vector2(16, y))
		y += 160.0
	var play := Cute.button("시작!", Vector2(400, 90), 36, Color(1, 0.72, 0.25))
	play.name = "Btn_시작"
	play.position = Vector2(16, 1110 + 60)
	play.position.y = 1110 + 50
	play.pressed.connect(func() -> void: get_tree().change_scene_to_file(SURVIVOR_SCENE))
	add_child(play)
	var back := Cute.button("뒤로", Vector2(270, 90), 32, Cute.CARAMEL)
	back.name = "Btn_뒤로"
	back.position = Vector2(434, 1160)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(SELECT_SCENE))
	add_child(back)
	_refresh()


func _row(id: String, pos: Vector2) -> void:
	var row := HeroRow.new()
	row.id = id
	row.position = pos
	row.size = Vector2(688, 150)
	add_child(row)
	row.add_child(_hero_view(id, Vector2(150, 150)))
	var b := Cute.button("", Vector2(150, 70), 24, GOLD)
	b.name = "Hero_" + id
	b.position = Vector2(528, 74)
	b.pressed.connect(_pick.bind(id))
	row.add_child(b)
	buttons[id] = b
	rows[id] = row


## 캐릭터 3D 미리보기 (살짝 좌우로 돌아요)
func _hero_view(id: String, size: Vector2) -> SubViewportContainer:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.size = size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.75, 0.7)
	env.environment.ambient_light_energy = 0.5
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 32.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.6, 4.4), Vector3(0, 0.85, 0), Vector3.UP)
	var hero := HeroModels.make(id)
	hero.set_meta("spin", true)
	vp.add_child(hero)
	var tw := hero.create_tween().set_loops()
	tw.tween_property(hero, "rotation:y", 0.6, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(hero, "rotation:y", -0.6, 1.4).set_trans(Tween.TRANS_SINE)
	return box


func _cost(id: String) -> int:
	return int(Rules.HEROES[id].cost)


func _refresh() -> void:
	coin_label.text = "똥전 %d" % Save.survivor_coins()
	var cur := Save.survivor_hero()
	for id in buttons:
		var b: Button = buttons[id]
		var row: HeroRow = rows[id]
		var open := Save.hero_unlocked(id, _cost(id))
		row.locked = not open
		row.chosen = id == cur
		row.queue_redraw()
		if not open:
			b.text = "%d 똥전" % _cost(id)
			b.disabled = Save.survivor_coins() < _cost(id)
		elif id == cur:
			b.text = "골랐어요"
			b.disabled = true
		else:
			b.text = "고르기"
			b.disabled = false


func _pick(id: String) -> void:
	if not Save.hero_unlocked(id, _cost(id)):
		if not Save.unlock_hero(id, _cost(id)):
			Sound.play("hurt", 1.3, -6.0)
			return
		Sound.play("win", 1.0, -2.0)
	Sound.play("fart", randf_range(0.9, 1.2), -4.0)
	Save.set_survivor_hero(id)
	_refresh()


class HeroRow extends Control:
	var id := ""
	var locked := false
	var chosen := false

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = SHELF if not chosen else SHELF.lerp(GOLD, 0.25)
		sb.set_corner_radius_all(16)
		sb.border_color = GOLD if chosen else Color(0.45, 0.33, 0.24)
		sb.set_border_width_all(4 if chosen else 3)
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 4)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var h: Dictionary = Rules.HEROES[id]
		var x := 158.0
		var name_col := CREAM if not locked else CREAM.darkened(0.4)
		draw_string_outline(FONT, Vector2(x, 42), String(h.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 6, Color(0.08, 0.05, 0.05))
		draw_string(FONT, Vector2(x, 42), String(h.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, name_col)
		var wname: String = Rules.WEAPONS[h.weapon].name
		draw_string(FONT, Vector2(x + 150, 40), "체력 %d   이동 %d%%" % [int(h.hp), int(float(h.speed) * 100.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, CREAM.darkened(0.2))
		draw_string(FONT, Vector2(x, 78), "시작 무기: " + wname, HORIZONTAL_ALIGNMENT_LEFT, 360, 22, Color(1, 0.8, 0.45))
		draw_string(FONT, Vector2(x, 110), String(h.skill), HORIZONTAL_ALIGNMENT_LEFT, 360, 21, Color(0.7, 0.9, 0.85))
		draw_string(FONT, Vector2(x, 138), String(h.desc), HORIZONTAL_ALIGNMENT_LEFT, 360, 20, CREAM.darkened(0.35))
		if locked:
			draw_string(FONT, Vector2(538, 50), "잠겨 있어요", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.6, 0.5))
