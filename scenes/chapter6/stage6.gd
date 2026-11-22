extends "res://scripts/stage_base.gd"
## 6장 '재도전' 1부: 일주일 준비 화면이에요.
## 1~6일, 하루 아침·낮·저녁에 할 일을 하나씩 골라 레벨·능력치·검·사슬 무기를 키워요 (모두 18번).
## 7일째에는 드래곤과 다시 싸우러 가요 (dragon_battle.tscn).
## 행동 종류, 미니게임, 숫자는 6장 설계 문서의 (제안)이에요. 규칙은 growth_rules.gd에 있어요.
## 준비 상태는 기기에 저장돼서, 중간에 꺼도 이어서 할 수 있어요.

const Growth := preload("res://scenes/chapter6/growth_rules.gd")
const Prince := preload("res://scripts/art/prince.gd")
const Backdrop := preload("res://scripts/art/backdrop.gd")
const BATTLE_SCENE := "res://scenes/chapter6/dragon_battle.tscn"

const ACTION_INFO := [
	"아령 들기 (리듬 톡)\n경험치 120",
	"구멍 속 똥 벌레 사냥\n경험치 60 · 반짝 돌 4",
	"무너진 집 고치기\n경험치 40 · 황금 똥구슬 1",
	"모은 재료로 강화\n한 번에 최대 2단계",
	"드래곤 공격 하나의 비밀\n그 공격 경고 0.3초 일찍",
]
const MINI_TIME := {"train": 9.5, "adventure": 15.0, "help": 14.0}

var growth: RefCounted
var mode := "hub"              # hub / mini / modal
var _ui: Control
var prince: Node2D
var _draw_node: Node2D
var _mini := {}
var _forge_plan: Array = []
var _lost_summary := ""


func _init() -> void:
	chapter = 6


func _setup() -> void:
	growth = Growth.load_or_new()
	var note: String = Session.chapter_checkpoint.get(6, "")
	Session.chapter_checkpoint.erase(6)
	if note.begins_with("lost:"):
		_lost_summary = note.substr(5)
	world.add_child(Backdrop.new("yard"))
	_draw_node = Node2D.new()
	_draw_node.draw.connect(_draw_mini)
	world.add_child(_draw_node)
	prince = Prince.new()
	prince.position = Vector2(1160, 600)
	prince.facing = -1.0
	world.add_child(prince)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(_ui)
	hud_root.move_child(_ui, 0)


func _intro_pages() -> Array:
	if _lost_summary != "":
		return []
	if growth.day > 1 or growth.slot > 0 or growth.week_over():
		return ["%s, 준비를 이어서 해요." % growth.time_name()]
	return [
		"드래곤에게 밀려난 똥 왕자는 마음먹었어요.\n\"일주일 동안 더 강해져서 다시 싸울 거야!\"",
		"어떻게 할까요?\n\n1~6일 동안 하루에 세 번(아침·낮·저녁) 할 일을 골라요. 모두 18번이에요.\n• 훈련장: 경험치 → 레벨업하면 능력치 3점을 직접 나눠요\n• 모험: 반짝 돌 (강화 재료)\n• 백성 돕기: 황금 똥구슬 (높은 단계 강화 재료)\n• 대장간: 검과 사슬 무기 강화 (항상 성공)\n• 작전 회의: 드래곤 공격의 비밀\n\n18번으로는 모두 키울 수 없어요. 어떻게 준비할지 골라요!\n7일째에 드래곤과 다시 싸워요.",
	]


func _on_play_started() -> void:
	if growth.week_over():
		show_prefight()
	else:
		show_hub()


func _can_pause() -> bool:
	return mode != "modal"


func _on_paused() -> void:
	pass


# ------------------------------------------------------------------ 준비 화면

func _clear_ui() -> void:
	for c in _ui.get_children():
		_ui.remove_child(c)
		c.queue_free()


func show_hub() -> void:
	mode = "hub"
	_refresh_pause_button()
	clear_overlay()
	_clear_ui()
	growth.save()
	prince.arm_level = growth.arm_level()
	prince.sword_level = growth.sword_lv
	var top := _label(Vector2(24, 12), "6장 재도전 · %s · 드래곤까지 D-%d · 남은 행동 %d" % [growth.time_name(), growth.days_left(), growth.actions_left()], 32)
	top.name = "TopLabel"
	_build_status_panel()
	var x0 := 520.0
	for i in Growth.ACTION_NAMES.size():
		var b := make_button("%s\n%s" % [Growth.ACTION_NAMES[i], ACTION_INFO[i]], Vector2(360, 96), 22)
		b.name = "Action%d" % i
		b.position = Vector2(x0 + (i % 2) * 380, 110 + (i / 2) * 112)
		b.pressed.connect(_on_action.bind(i))
		_ui.add_child(b)
	var warn: String = growth.leftover_warning()
	if warn != "":
		var l := _label(Vector2(520, 460), warn, 22, Color(1, 0.85, 0.5))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size = Vector2(740, 60)


func _build_status_panel() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.position = Vector2(16, 100)
	bg.size = Vector2(480, 420)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(bg)
	var s: Dictionary = growth.battle_stats()
	var xp_text := "최고 레벨" if growth.level >= Growth.MAX_LEVEL else "경험치 %d / %d" % [growth.xp, Growth.xp_to_next(growth.level)]
	_label(Vector2(32, 108), "Lv %d · %s" % [growth.level, xp_text], 28)
	var y := 150.0
	for row in [["str", "힘", growth.str_], ["vit", "체력", growth.vit], ["agi", "민첩", growth.agi]]:
		_label(Vector2(32, y), "%s %d" % [row[1], row[2]], 28)
		if growth.points > 0:
			var plus := make_button("+", Vector2(56, 44), 28, Color(0.3, 0.6, 0.3))
			plus.name = "Plus_" + row[0]
			plus.position = Vector2(180, y - 2)
			plus.pressed.connect(func() -> void:
				growth.add_point(row[0])
				show_hub())
			_ui.add_child(plus)
		y += 50
	if growth.points > 0:
		_label(Vector2(250, 160), "나눌 점수 %d" % growth.points, 26, Color(1, 0.9, 0.4))
	var sword_name: String = {"fast": " 빠른 검", "heavy": " 무거운 검"}.get(growth.sword_branch, "")
	var chain_name: String = {"spin": " 빙글 사슬", "pierce": " 꿰뚫는 사슬"}.get(growth.chain_branch, "")
	_label(Vector2(32, y + 4), "검 +%d%s · 피해 %d" % [growth.sword_lv, sword_name, s.sword], 24)
	_label(Vector2(32, y + 38), "사슬 무기 +%d%s · 피해 %d" % [growth.chain_lv, chain_name, s.chain], 24)
	_label(Vector2(32, y + 72), "체력 %d · 구르기 무적 %.2f초 · 모으기 %.1f초" % [s.max_hp, s.roll_invuln, s.charge_time], 22)
	_label(Vector2(32, y + 106), "반짝 돌 %d · 황금 똥구슬 %d" % [growth.stones, growth.orbs], 24, Color(0.7, 0.95, 1))
	var known := "없음" if growth.secrets.is_empty() else ", ".join(growth.secrets)
	_label(Vector2(32, y + 140), "알아낸 비밀: %s" % known, 22)
	_label(Vector2(32, y + 170), "근육 주먹 피해: 힘 × 10 = %d" % (growth.str_ * 10), 22, Color(1, 0.8, 0.5))


func _label(pos: Vector2, text: String, size: int, color := Color(1, 0.97, 0.88)) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.05))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(l)
	return l


func _modal(title: String, body: String, buttons: Array) -> void:
	mode = "modal"
	_refresh_pause_button()
	show_panel(title, body, buttons)


func _on_action(i: int) -> void:
	match i:
		Growth.Action.TRAIN:
			_ask_mini("train", "훈련장: 아령 들기", "고리가 가운데 원에 맞을 때 톡! 잘할수록 경험치가 최대 1.5배예요.")
		Growth.Action.ADVENTURE:
			_ask_mini("adventure", "모험: 똥 벌레 사냥", "구멍 속을 기어 다니는 똥 벌레를 톡톡! 많이 잡을수록 반짝 돌이 최대 1.5배예요.")
		Growth.Action.HELP:
			_ask_mini("help", "백성 돕기: 집 고치기", "무너진 집의 금을 1번부터 차례로 톡! 모두 고치면 황금 똥구슬을 하나 더 받아요.")
		Growth.Action.FORGE:
			_forge_plan = []
			show_forge()
		Growth.Action.MEETING:
			show_meeting()


func _ask_mini(kind: String, title: String, body: String) -> void:
	_modal(title, body + "\n\n빠르게 하기를 고르면 미니게임 없이 보통 보상을 받아요.", [
		["미니게임", start_mini.bind(kind)],
		["빠르게", finish_mini_quick.bind(kind)],
		["취소", show_hub],
	])


# ------------------------------------------------------------------ 대장간

func show_forge() -> void:
	var spent_s := 0
	var spent_o := 0
	var extra_s := 0
	var extra_c := 0
	for w in _forge_plan:
		var lv: int = growth.sword_lv + extra_s if w == "sword" else growth.chain_lv + extra_c
		var cost: Array = Growth.upgrade_cost(w, lv)
		spent_s += int(cost[0])
		spent_o += int(cost[1])
		if w == "sword":
			extra_s += 1
		else:
			extra_c += 1
	var lines := "반짝 돌 %d · 황금 똥구슬 %d (남는 것)\n\n" % [growth.stones - spent_s, growth.orbs - spent_o]
	var buttons: Array = []
	for w in ["sword", "chain"]:
		var lv: int = growth.sword_lv + extra_s if w == "sword" else growth.chain_lv + extra_c
		var wname := "검" if w == "sword" else "사슬 무기"
		var cost: Array = Growth.upgrade_cost(w, lv)
		if cost.is_empty():
			lines += "%s +%d (최고 단계)\n" % [wname, lv]
			continue
		var cur := _bonus_at(w, lv)
		lines += "%s +%d → +%d: 반짝 돌 %d, 황금 똥구슬 %d · 보너스 %d → %d\n" % [wname, lv, lv + 1, cost[0], cost[1], cur, cost[2]]
		if _forge_plan.size() < Growth.FORGE_MAX and growth.can_upgrade(w, extra_s, extra_c, spent_s, spent_o):
			buttons.append(["%s 강화" % wname, func() -> void:
				_forge_plan.append(w)
				show_forge()])
	if not _forge_plan.is_empty():
		lines += "\n고른 강화: %s" % ", ".join(_forge_plan.map(func(w): return "검" if w == "sword" else "사슬"))
		buttons.append(["뚝딱! 강화", _apply_forge])
	buttons.append(["취소", show_hub])
	_modal("대장간", lines, buttons)


func _bonus_at(w: String, lv: int) -> int:
	if lv <= 0:
		return 0
	var table: Array = Growth.SWORD_TABLE if w == "sword" else Growth.CHAIN_TABLE
	return int(table[lv - 1][2])


func _apply_forge() -> void:
	if not growth.do_forge(_forge_plan):
		show_hub()
		return
	_forge_plan = []
	float_text(Vector2(560, 560), "뚝딱뚝딱! 강화 성공!", Color(1, 0.9, 0.5), 40)
	_after_action()


## +3이 되면 갈림길을 골라요.
func _ask_branch() -> bool:
	var need: Array = growth.needs_branch()
	if need.is_empty():
		return false
	if need[0] == "sword":
		_modal("검 +3 갈림길", "하나를 골라요. (7일째 출발 전에 한 번 바꿀 수 있어요)\n\n빠른 검: 휘두르는 속도 +30%\n무거운 검: 피해 +30%, 대신 휘두른 뒤 0.2초 멈춰요", [
			["빠른 검", _set_branch.bind("sword", "fast")],
			["무거운 검", _set_branch.bind("sword", "heavy")],
		])
	else:
		_modal("사슬 무기 +3 갈림길", "하나를 골라요. (7일째 출발 전에 한 번 바꿀 수 있어요)\n\n빙글 사슬: 주변을 한 바퀴 훑어요. 꼬리치기를 막아요\n꿰뚫는 사슬: 멀리 나가고, 빛나는 가슴 비늘에 2배", [
			["빙글 사슬", _set_branch.bind("chain", "spin")],
			["꿰뚫는 사슬", _set_branch.bind("chain", "pierce")],
		])
	return true


func _set_branch(weapon: String, kind: String) -> void:
	if weapon == "sword":
		growth.sword_branch = kind
	else:
		growth.chain_branch = kind
	growth.save()
	if not _ask_branch():
		_continue_after_action()


# ------------------------------------------------------------------ 작전 회의

func show_meeting() -> void:
	var buttons: Array = []
	for a in Growth.DRAGON_ATTACKS:
		if not growth.secrets.has(a):
			buttons.append([a, func() -> void:
				growth.do_meeting(a)
				float_text(Vector2(560, 560), "%s의 비밀을 알아냈어요!" % a, Color(0.8, 0.9, 1), 36)
				_after_action()])
	if buttons.is_empty():
		_modal("작전 회의", "드래곤 공격 네 가지를 모두 알아냈어요.", [["돌아가기", show_hub]])
		return
	buttons.append(["취소", show_hub])
	_modal("작전 회의", "드래곤 그림을 조사해요. 어떤 공격의 비밀을 알아낼까요?\n알아낸 공격은 경고 표시가 0.3초 일찍 떠요.", buttons)


# ------------------------------------------------------------------ 행동 끝

func _after_action(result: Dictionary = {}) -> void:
	growth.save()
	if not result.is_empty():
		var parts: Array = ["경험치 +%d" % result.xp]
		if result.stones > 0:
			parts.append("반짝 돌 +%d" % result.stones)
		if result.orbs > 0:
			parts.append("황금 똥구슬 +%d" % result.orbs)
		var body := ", ".join(parts)
		if result.levels > 0:
			body += "\n\n레벨 업! Lv %d (능력치 점수 +%d)\n준비 화면 왼쪽 + 버튼으로 나눠요." % [growth.level, result.levels * Growth.POINTS_PER_LEVEL]
			prince.play_pose(Prince.Pose.CHEER, 0.8)
		_modal("결과", body, [["좋아요", _continue_after_action]])
		return
	_continue_after_action()


func _continue_after_action() -> void:
	if _ask_branch():
		return
	if growth.week_over():
		show_pages(["일주일이 지났어요.\n7일째, 똥 왕자는 드래곤의 본거지로 다시 떠나요."], show_prefight)
	else:
		show_hub()


# ------------------------------------------------------------------ 7일째: 출발 전

func show_prefight() -> void:
	mode = "hub"
	_clear_ui()
	growth.save()
	prince.arm_level = growth.arm_level()
	_label(Vector2(24, 12), "6장 재도전 · 7일째 · 드래곤과 다시 싸워요" + (" · 진 횟수 %d" % growth.losses if growth.losses > 0 else ""), 32)
	_build_status_panel()
	var x := 520.0
	var y := 110.0
	if _lost_summary != "":
		var l := _label(Vector2(x, y), "아쉬워요! 주로 맞은 공격: %s\n레벨·재료·강화는 그대로예요. 능력치를 다시 나눠 볼까요?" % _lost_summary, 24, Color(1, 0.8, 0.7))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size = Vector2(740, 90)
		y += 100
	var go := make_button("드래곤에게 출발!", Vector2(360, 100), 34, Color(0.75, 0.3, 0.35))
	go.name = "GoButton"
	go.position = Vector2(x, y)
	go.pressed.connect(go_battle)
	_ui.add_child(go)
	var respec := make_button("능력치 다시 나누기", Vector2(360, 70), 26)
	respec.name = "RespecButton"
	respec.position = Vector2(x, y + 120)
	respec.pressed.connect(func() -> void:
		growth.respec()
		show_prefight())
	_ui.add_child(respec)
	if not growth.branch_switch_used and (growth.sword_branch != "" or growth.chain_branch != ""):
		var sw := make_button("갈림길 바꾸기 (한 번)", Vector2(360, 70), 26)
		sw.name = "SwitchButton"
		sw.position = Vector2(x + 380, y + 120)
		sw.pressed.connect(_switch_branches)
		_ui.add_child(sw)
	if growth.losses >= 3:
		var hm := make_button("도움 모드 %s (체력 +50%%)" % ("끄기" if growth.help_mode else "켜기"), Vector2(360, 70), 24)
		hm.name = "HelpButton"
		hm.position = Vector2(x, y + 210)
		hm.pressed.connect(func() -> void:
			growth.help_mode = not growth.help_mode
			show_prefight())
		_ui.add_child(hm)
	var reset := make_button("일주일 처음부터", Vector2(360, 70), 24, Color(0.55, 0.5, 0.45))
	reset.name = "ResetButton"
	reset.position = Vector2(x + 380, y + 210)
	reset.pressed.connect(func() -> void:
		Growth.clear_saved()
		restart())
	_ui.add_child(reset)


func _switch_branches() -> void:
	growth.branch_switch_used = true
	if growth.sword_branch != "":
		growth.sword_branch = "heavy" if growth.sword_branch == "fast" else "fast"
	if growth.chain_branch != "":
		growth.chain_branch = "pierce" if growth.chain_branch == "spin" else "spin"
	show_prefight()


func go_battle() -> void:
	growth.save()
	change_scene(BATTLE_SCENE)


func _before_restart() -> void:
	pass


# ------------------------------------------------------------------ 미니게임

func start_mini(kind: String) -> void:
	clear_overlay()
	_clear_ui()
	mode = "mini"
	_refresh_pause_button()
	_mini = {"kind": kind, "t": 0.0, "score": 0, "max": 1, "items": []}
	match kind:
		"train":
			for i in 8:
				_mini.items.append({"time": 1.2 + i * 1.0, "judged": false})
			_mini.max = 16
		"adventure":
			_mini.max = 12
			_mini.spawn = 0.2
		"help":
			var spots: Array = []
			for i in 6:
				var p := Vector2(rng.randf_range(560, 1180), rng.randf_range(200, 560))
				for k in 20:
					var ok := true
					for q in spots:
						if q.distance_to(p) < 130:
							ok = false
					if ok:
						break
					p = Vector2(rng.randf_range(560, 1180), rng.randf_range(200, 560))
				spots.append(p)
				_mini.items.append({"pos": p, "n": i + 1, "done": false})
			_mini.max = 6
			_mini.next = 1
	_label(Vector2(24, 12), {"train": "아령 들기", "adventure": "똥 벌레 사냥", "help": "집 고치기"}[kind], 32).name = "MiniTitle"
	_label(Vector2(24, 54), "", 26).name = "MiniStatus"


func finish_mini_quick(kind: String) -> void:
	_apply_mini(kind, 0.0)


func _apply_mini(kind: String, perf: float) -> void:
	var action: int = {"train": Growth.Action.TRAIN, "adventure": Growth.Action.ADVENTURE, "help": Growth.Action.HELP}[kind]
	var result: Dictionary = growth.do_action(action, perf)
	_mini = {}
	_draw_node.queue_redraw()
	_after_action(result)


func _end_mini() -> void:
	var perf := clampf(float(_mini.score) / float(_mini.max), 0.0, 1.0)
	_apply_mini(_mini.kind, perf)


func _play_process(delta: float) -> void:
	if mode != "mini" or _mini.is_empty():
		return
	_mini.t += delta
	match _mini.kind:
		"train":
			for n in _mini.items:
				if not n.judged and _mini.t > n.time + 0.25:
					n.judged = true
		"adventure":
			_mini.spawn -= delta
			if _mini.spawn <= 0.0 and _mini.items.size() < 4 and _mini.t < MINI_TIME.adventure - 0.5:
				_mini.spawn = 0.8
				var from_left := rng.randf() < 0.5
				_mini.items.append({"pos": Vector2(500 if from_left else 1280, rng.randf_range(260, 620)), "v": Vector2(rng.randf_range(160, 260) * (1 if from_left else -1), rng.randf_range(-40, 40))})
			for b in _mini.items.duplicate():
				b.pos += b.v * delta
				if b.pos.x < 480 or b.pos.x > 1300:
					_mini.items.erase(b)
	var status := _ui.get_node_or_null("MiniStatus")
	if status:
		status.text = "점수 %d · 남은 시간 %s" % [_mini.score, time_text(MINI_TIME[_mini.kind] - _mini.t)]
	_draw_node.queue_redraw()
	var done: bool = _mini.t >= MINI_TIME[_mini.kind]
	if _mini.kind == "help" and _mini.next > 6:
		done = true
	if done:
		_end_mini()


func _play_input(event: InputEvent) -> void:
	if mode != "mini" or _mini.is_empty():
		return
	if event is InputEventScreenTouch and event.pressed:
		mini_tap(event.position)


func mini_tap(p: Vector2) -> void:
	match _mini.kind:
		"train":
			var best = null
			for n in _mini.items:
				if not n.judged and absf(_mini.t - n.time) <= 0.4 and (best == null or absf(_mini.t - n.time) < absf(_mini.t - best.time)):
					best = n
			if best == null:
				return
			best.judged = true
			var off := absf(_mini.t - best.time)
			var pts := 2 if off <= 0.12 else (1 if off <= 0.25 else 0)
			_mini.score += pts
			prince.play_pose(Prince.Pose.CHEER, 0.25)
			float_text(Vector2(700, 200), ["놓쳤어요", "좋아요", "딱 좋아요!"][pts], Color(1, 0.9, 0.4), 34)
		"adventure":
			for b in _mini.items:
				if b.pos.distance_to(p) < 60:
					_mini.items.erase(b)
					_mini.score += 1
					float_text(b.pos + Vector2(-20, -60), "잡았다!", Color(1, 1, 0.7), 26)
					return
		"help":
			for c in _mini.items:
				if c.done or c.pos.distance_to(p) > 55:
					continue
				if c.n == _mini.next:
					c.done = true
					_mini.score += 1
					_mini.next += 1
				else:
					_mini.t += 1.0
					float_text(c.pos + Vector2(-40, -60), "순서대로!", Color(1, 0.7, 0.6), 26)
				return


func _draw_mini() -> void:
	if _mini.is_empty():
		return
	var n := _draw_node
	var font := ThemeDB.fallback_font
	match _mini.kind:
		"train":
			var c := Vector2(760, 380)
			n.draw_circle(c, 60, Color(1, 0.9, 0.5, 0.35))
			n.draw_arc(c, 60, 0, TAU, 48, Color(0.5, 0.3, 0.1), 6)
			for note in _mini.items:
				var left: float = note.time - _mini.t
				if note.judged or left > 1.2 or left < -0.25:
					continue
				n.draw_arc(c, 60 + 160 * maxf(left, 0.0) / 1.2, 0, TAU, 64, Color(0.95, 0.45, 0.2), 8)
		"adventure":
			n.draw_rect(Rect2(480, 220, 800, 440), Color(0.25, 0.17, 0.1, 0.8))
			for b in _mini.items:
				for k in 3:
					n.draw_circle(b.pos + Vector2(-signf(b.v.x) * k * 18, 0), 20 - k * 3, Color(0.45, 0.3, 0.12))
				n.draw_circle(b.pos + Vector2(signf(b.v.x) * 10, -6), 5, Color.WHITE)
		"help":
			n.draw_rect(Rect2(520, 160, 720, 460), Color(0.85, 0.7, 0.5))
			n.draw_colored_polygon(PackedVector2Array([Vector2(500, 160), Vector2(880, 100), Vector2(1260, 160)]), Color(0.6, 0.3, 0.2))
			for c in _mini.items:
				if c.done:
					n.draw_circle(c.pos, 34, Color(0.6, 0.85, 0.5))
					continue
				n.draw_line(c.pos + Vector2(-30, -20), c.pos + Vector2(30, 20), Color(0.3, 0.2, 0.1), 6)
				n.draw_circle(c.pos, 34, Color(1, 1, 1, 0.5))
				n.draw_string(font, c.pos + Vector2(-10, 12), str(c.n), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.3, 0.15, 0.05))
