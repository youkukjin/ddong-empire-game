extends Control
## 똥 대장간 (2026-11-28 사용자: "똥전으로 뭘 구매를 할 수가 있어야 모으는 재미").
## 서바이버에서 모은 똥전으로 영구 강화를 사요. 산 강화는 다음 판부터 처음부터 적용돼요.
## 한 줄 = 그림 메달 + 이름 + 단계 보석 + 효과 + 사기 버튼. 먹빛 나무 선반 느낌.

const Sound := preload("res://scripts/audio/sound.gd")
const Save := preload("res://scripts/save_data.gd")
const Cute := preload("res://scripts/art/cute.gd")
const ScreenMode := preload("res://scripts/screen_mode.gd")
const Rules := preload("res://scenes/survivor/survivor_rules.gd")
const SkillCard := preload("res://scenes/survivor/skill_card.gd")
const Icon3D := preload("res://scenes/survivor/icon3d.gd")
const SURVIVOR_SCENE := "res://scenes/survivor/survivor.tscn"
const SELECT_SCENE := "res://scenes/title/chapter_select.tscn"
const FONT := preload("res://assets/fonts/Jua-Regular.ttf")

const BG := Color(0.17, 0.13, 0.15)
const SHELF := Color(0.3, 0.21, 0.16)
const CREAM := Color(0.95, 0.89, 0.76)
const GOLD := Color(0.85, 0.66, 0.25)

var coin_label: Label
var rows: Dictionary = {}     # id -> {button, row}


func _ready() -> void:
	ScreenMode.portrait(get_tree())
	Sound.ensure()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = "똥 대장간"
	title.position = Vector2(0, 26)
	title.size = Vector2(720, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Cute.style_label(title, 60, GOLD, Color(0.08, 0.05, 0.05), 12)
	add_child(title)
	var sub := Label.new()
	sub.text = "모은 똥전으로 똥 왕자를 영원히 강하게!"
	sub.position = Vector2(0, 96)
	sub.size = Vector2(720, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Cute.style_label(sub, 26, CREAM.darkened(0.15))
	add_child(sub)
	coin_label = Label.new()
	coin_label.position = Vector2(0, 138)
	coin_label.size = Vector2(720, 50)
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Cute.style_label(coin_label, 38, Color(1, 0.85, 0.35), Color(0.08, 0.05, 0.05), 8)
	add_child(coin_label)
	var y := 200.0
	for id in Rules.FORGE:
		_row(String(id), Vector2(20, y))
		y += 112.0
	var play := Cute.button("서바이버 시작!", Vector2(400, 96), 34, Color(1, 0.72, 0.25))
	play.name = "Btn_시작"
	play.position = Vector2(20, 1110)
	play.pressed.connect(func() -> void: get_tree().change_scene_to_file(SURVIVOR_SCENE))
	add_child(play)
	var back := Cute.button("장 고르기", Vector2(260, 96), 30, Cute.CARAMEL)
	back.name = "Btn_장고르기"
	back.position = Vector2(440, 1110)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(SELECT_SCENE))
	add_child(back)
	_refresh()


func _row(id: String, pos: Vector2) -> void:
	var row := ForgeRow.new()
	row.id = id
	row.position = pos
	row.size = Vector2(680, 100)
	add_child(row)
	var icon := Icon3D.make_view(id, Vector2(110, 110), 0.5)
	icon.position = Vector2(54, 50) - icon.size / 2.0
	row.add_child(icon)
	var b := Cute.button("", Vector2(170, 76), 26, GOLD)
	b.name = "Buy_" + id
	b.position = Vector2(500, 12)
	b.pressed.connect(_buy.bind(id))
	row.add_child(b)
	rows[id] = {"row": row, "button": b}


func _refresh() -> void:
	coin_label.text = "똥전 %d" % Save.survivor_coins()
	for id in rows:
		var lv := Save.forge_level(id)
		var mx := int(Rules.FORGE[id].max)
		var b: Button = rows[id].button
		var row: ForgeRow = rows[id].row
		row.level = lv
		row.queue_redraw()
		if lv >= mx:
			b.text = "다 샀어요"
			b.disabled = true
		else:
			var cost := Rules.forge_cost(id, lv)
			b.text = "%d 똥전" % cost
			b.disabled = Save.survivor_coins() < cost


func _buy(id: String) -> void:
	var lv := Save.forge_level(id)
	if lv >= int(Rules.FORGE[id].max):
		return
	if Save.buy_forge(id, Rules.forge_cost(id, lv)):
		Sound.play("build", 1.1, 0.0)
		Sound.play("coin", 0.9, -4.0)
		var row: ForgeRow = rows[id].row
		var tw := row.create_tween()
		row.pivot_offset = row.size / 2.0
		tw.tween_property(row, "scale", Vector2(1.04, 1.04), 0.07)
		tw.tween_property(row, "scale", Vector2.ONE, 0.12)
	else:
		Sound.play("hurt", 1.3, -6.0)
	_refresh()


## 대장간 한 줄 (나무 선반 + 메달 + 글자 + 단계 보석)
class ForgeRow extends Control:
	var id := ""
	var level := 0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = SHELF
		sb.set_corner_radius_all(14)
		sb.border_color = Color(0.45, 0.33, 0.24)
		sb.set_border_width_all(3)
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 4)
		draw_style_box(sb, r)
		# 나뭇결
		for k in 3:
			var yy := 22.0 + k * 28.0
			draw_line(Vector2(110, yy), Vector2(480, yy + 3), Color(0.24, 0.16, 0.12, 0.5), 2.0)
		# 메달
		var c := Vector2(54, 50)
		draw_circle(c + Vector2(2, 4), 40, Color(0, 0, 0, 0.35))
		draw_circle(c, 40, GOLD.darkened(0.3))
		draw_circle(c, 35, Color(0.9, 0.84, 0.7))
		var info: Dictionary = Rules.FORGE[id]
		draw_string_outline(FONT, Vector2(112, 40), String(info.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, 6, Color(0.08, 0.05, 0.05))
		draw_string(FONT, Vector2(112, 40), String(info.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, CREAM)
		draw_string(FONT, Vector2(112, 82), "단계마다 " + String(info.per), HORIZONTAL_ALIGNMENT_LEFT, 380, 22, CREAM.darkened(0.25))
		for i in int(info.max):
			var p := Vector2(330 + i * 30, 30)
			var dia := PackedVector2Array([p + Vector2(0, -11), p + Vector2(11, 0), p + Vector2(0, 11), p + Vector2(-11, 0)])
			draw_colored_polygon(dia, GOLD if i < level else Color(0.22, 0.15, 0.12))
			var closed := dia.duplicate()
			closed.append(dia[0])
			draw_polyline(closed, CREAM.darkened(0.35), 2.0, true)
