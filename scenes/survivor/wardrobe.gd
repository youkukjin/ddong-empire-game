extends Control
## 똥 옷장 (2026-11-28 사용자: "똥전을 모아서 아이템도 착용할 수 있으면").
## 모자·신발·장신구를 똥전으로 사서 한 칸에 하나씩 끼워요. 위에 지금 고른 똥이 끼운 모습으로 보여요.

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
var buttons: Dictionary = {}     # id -> Button
var hero: Node3D


func _ready() -> void:
	ScreenMode.portrait(get_tree())
	Sound.ensure()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = "똥 옷장"
	title.position = Vector2(0, 20)
	title.size = Vector2(720, 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Cute.style_label(title, 56, GOLD, Color(0.08, 0.05, 0.05), 12)
	add_child(title)
	coin_label = Label.new()
	coin_label.position = Vector2(0, 84)
	coin_label.size = Vector2(720, 44)
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Cute.style_label(coin_label, 32, Color(1, 0.85, 0.35), Color(0.08, 0.05, 0.05), 8)
	add_child(coin_label)
	var view := _hero_view(Vector2(260, 260))
	view.position = Vector2(230, 124)
	add_child(view)
	var y := 392.0
	for slot in Rules.EQUIP_SLOTS:
		var head := Label.new()
		head.text = "— %s —" % Rules.EQUIP_SLOTS[slot]
		head.position = Vector2(0, y)
		head.size = Vector2(720, 34)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Cute.style_label(head, 26, CREAM.darkened(0.2))
		add_child(head)
		y += 38.0
		for id in Rules.EQUIP:
			if Rules.EQUIP[id].slot == slot:
				_row(String(id), Vector2(20, y))
				y += 60.0
	var play := Cute.button("서바이버 시작!", Vector2(400, 90), 32, Color(1, 0.72, 0.25))
	play.name = "Btn_시작"
	play.position = Vector2(20, 1170)
	play.pressed.connect(func() -> void: get_tree().change_scene_to_file(SURVIVOR_SCENE))
	add_child(play)
	var back := Cute.button("뒤로", Vector2(260, 90), 30, Cute.CARAMEL)
	back.name = "Btn_뒤로"
	back.position = Vector2(440, 1170)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(SELECT_SCENE))
	add_child(back)
	_refresh()


func _row(id: String, pos: Vector2) -> void:
	var row := EquipRow.new()
	row.id = id
	row.position = pos
	row.size = Vector2(680, 54)
	add_child(row)
	var b := Cute.button("", Vector2(170, 46), 22, GOLD)
	b.name = "Equip_" + id
	b.position = Vector2(504, 4)
	b.pressed.connect(_press.bind(id))
	row.add_child(b)
	buttons[id] = b


func _press(id: String) -> void:
	var e: Dictionary = Rules.EQUIP[id]
	var slot := String(e.slot)
	if not Save.equip_owned(id):
		if not Save.buy_equip(id, int(e.cost)):
			Sound.play("hurt", 1.2, -6.0)
			return
		Sound.play("coin", 1.0, -2.0)
		Save.set_equipped(slot, id)
	elif Save.equipped(slot) == id:
		Save.set_equipped(slot, "")      # 벗기
		Sound.play("swing", 1.2, -6.0)
	else:
		Save.set_equipped(slot, id)
		Sound.play("power", 1.3, -6.0)
	_refresh()


func current_equip() -> Array:
	var out: Array = []
	for slot in Rules.EQUIP_SLOTS:
		var eid := Save.equipped(slot)
		if eid != "" and Save.equip_owned(eid):
			out.append(eid)
	return out


func _refresh() -> void:
	coin_label.text = "똥전 %d" % Save.survivor_coins()
	for id in buttons:
		var b: Button = buttons[id]
		var e: Dictionary = Rules.EQUIP[id]
		var row: EquipRow = b.get_parent()
		row.owned = Save.equip_owned(id)
		row.worn = Save.equipped(String(e.slot)) == id and row.owned
		if row.worn:
			b.text = "끼는 중"
			Cute.style_button(b, Cute.MINT, 22)
		elif row.owned:
			b.text = "끼우기"
			Cute.style_button(b, GOLD, 22)
		else:
			b.text = "%d 똥전" % int(e.cost)
			Cute.style_button(b, GOLD if Save.survivor_coins() >= int(e.cost) else Color(0.5, 0.45, 0.42), 22)
		row.queue_redraw()
	if hero:
		HeroModels.apply_gear(hero, {"equip": current_equip()})


## 지금 고른 똥이 장비를 끼운 모습 (살짝 좌우로 돌아요)
func _hero_view(size: Vector2) -> SubViewportContainer:
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
	cam.fov = 34.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.8, 4.8), Vector3(0, 0.95, 0), Vector3.UP)
	var hid := Save.survivor_hero()
	if not Save.hero_unlocked(hid, int(Rules.HEROES.get(hid, {"cost": 0}).cost)):
		hid = "kid"
	hero = HeroModels.make(hid)
	vp.add_child(hero)
	var tw := hero.create_tween().set_loops()
	tw.tween_property(hero, "rotation:y", 0.7, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(hero, "rotation:y", -0.7, 1.6).set_trans(Tween.TRANS_SINE)
	return box


class EquipRow extends Control:
	var id := ""
	var owned := false
	var worn := false

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = SHELF if not worn else SHELF.lerp(Color(0.4, 0.75, 0.55), 0.3)
		sb.set_corner_radius_all(12)
		sb.border_color = Color(0.45, 0.33, 0.24) if not worn else Color(0.45, 0.85, 0.6)
		sb.set_border_width_all(3)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var e: Dictionary = Rules.EQUIP[id]
		draw_string_outline(FONT, Vector2(16, 36), String(e.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 5, Color(0.08, 0.05, 0.05))
		draw_string(FONT, Vector2(16, 36), String(e.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, CREAM)
		draw_string(FONT, Vector2(220, 35), String(e.desc), HORIZONTAL_ALIGNMENT_LEFT, 280, 20, Color(0.7, 0.9, 0.85))
