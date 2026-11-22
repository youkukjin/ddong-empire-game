extends RefCounted
## 6장 '재도전'의 일주일 준비 규칙이에요: 레벨업, 능력치, 검·사슬 무기 강화, 재료.
## 숫자는 모두 6장 설계 문서(https://claude.ai/artifact/NEH9eW3guKY5meedYomZ5t)의 (제안) 값이에요.
## 원작: "일주일 동안 레벨업과 무기 강화를 하고, 드래곤과 다시 싸움".
## 과금, 뽑기, 확률 강화는 없어요. 강화는 재료만 있으면 항상 성공해요.

enum Action { TRAIN, ADVENTURE, HELP, FORGE, MEETING }

const DAYS := 6
const SLOTS := 3                        # 하루 아침·낮·저녁
const SLOT_NAMES := ["아침", "낮", "저녁"]
const ACTION_NAMES := ["훈련장", "모험", "백성 돕기", "대장간", "작전 회의"]
const START_LEVEL := 5
const MAX_LEVEL := 15
const START_STAT := 10
const POINTS_PER_LEVEL := 3
const MAX_MULT := 1.5                   # 미니게임을 잘하면 보상 최대 1.5배

const TRAIN_XP := 120
const ADVENTURE_XP := 60
const ADVENTURE_STONES := 4
const HELP_XP := 40
const HELP_ORBS := 1
const FORGE_MAX := 2                    # 대장간 한 번에 최대 2단계

## 강화 단계별 [반짝 돌, 황금 똥구슬, 보너스]  (인덱스 0 = +1)
const SWORD_TABLE := [[2, 0, 3], [3, 0, 6], [4, 0, 10], [4, 1, 14], [5, 2, 20]]
const CHAIN_TABLE := [[2, 0, 6], [3, 0, 12], [0, 1, 20], [3, 2, 28], [4, 2, 40]]
const BRANCH_LEVEL := 3

## 드래곤 공격 4가지 (작전 회의로 하나씩 알아내요)
const DRAGON_ATTACKS := ["발톱 할퀴기", "보라색 광선", "꼬리치기", "연속 광선"]

var day := 1
var slot := 0
var level := START_LEVEL
var xp := 0
var points := 0
var str_ := START_STAT
var vit := START_STAT
var agi := START_STAT
var sword_lv := 0
var chain_lv := 0
var sword_branch := ""          # "fast" 빠른 검 / "heavy" 무거운 검
var chain_branch := ""          # "spin" 빙글 사슬 / "pierce" 꿰뚫는 사슬
var stones := 0
var orbs := 0
var secrets: Array = []
var losses := 0
var help_mode := false
var branch_switch_used := false
var action_log: Array = []      # 고른 행동 기록


static func xp_to_next(lv: int) -> int:
	return 100 + 20 * (lv - START_LEVEL)


static func mult_from(performance: float) -> float:
	return 1.0 + (MAX_MULT - 1.0) * clampf(performance, 0.0, 1.0)


func actions_left() -> int:
	if day > DAYS:
		return 0
	return (DAYS - day) * SLOTS + (SLOTS - slot)


func week_over() -> bool:
	return day > DAYS


func time_name() -> String:
	if week_over():
		return "7일째"
	return "%d일째 %s" % [day, SLOT_NAMES[slot]]


func days_left() -> int:
	return DAYS + 1 - day


func _advance() -> void:
	slot += 1
	if slot >= SLOTS:
		slot = 0
		day += 1


## 경험치를 더하고, 오른 레벨 수를 돌려줘요.
func add_xp(amount: int) -> int:
	var ups := 0
	if level >= MAX_LEVEL:
		return 0
	xp += amount
	while level < MAX_LEVEL and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		points += POINTS_PER_LEVEL
		ups += 1
	if level >= MAX_LEVEL:
		xp = 0
	return ups


## 행동 하나를 해요 (대장간·작전 회의는 따로). 결과를 돌려줘요.
## performance: 미니게임 성적 0~1 (빠르게 하기는 0 → 보통 보상)
func do_action(action: Action, performance := 0.0) -> Dictionary:
	if week_over():
		return {}
	var m := mult_from(performance)
	var result := {"action": action, "xp": 0, "stones": 0, "orbs": 0, "levels": 0}
	match action:
		Action.TRAIN:
			result.xp = int(TRAIN_XP * m)
		Action.ADVENTURE:
			result.xp = int(ADVENTURE_XP * m)
			result.stones = int(ADVENTURE_STONES * m)
		Action.HELP:
			result.xp = int(HELP_XP * m)
			result.orbs = HELP_ORBS + (1 if performance >= 0.99 else 0)
		_:
			return {}
	stones += result.stones
	orbs += result.orbs
	result.levels = add_xp(result.xp)
	action_log.append(action)
	_advance()
	return result


## 작전 회의: 드래곤 공격 하나의 비밀을 알아내요 (그 공격 경고가 0.3초 일찍).
func do_meeting(attack: String) -> bool:
	if week_over() or secrets.has(attack) or not DRAGON_ATTACKS.has(attack):
		return false
	secrets.append(attack)
	action_log.append(Action.MEETING)
	_advance()
	return true


## 대장간: 강화 목록(["sword", "chain"] 같은)을 최대 2개까지 한 번에 해요. 행동 하나를 써요.
func do_forge(plan: Array) -> bool:
	if week_over() or plan.is_empty() or plan.size() > FORGE_MAX:
		return false
	# 미리 계산해서 모두 할 수 있을 때만 해요
	var s := stones
	var o := orbs
	var sl := sword_lv
	var cl := chain_lv
	for w in plan:
		var table: Array = SWORD_TABLE if w == "sword" else CHAIN_TABLE
		var lv := sl if w == "sword" else cl
		if lv >= table.size():
			return false
		var cost: Array = table[lv]
		s -= int(cost[0])
		o -= int(cost[1])
		if s < 0 or o < 0:
			return false
		if w == "sword":
			sl += 1
		else:
			cl += 1
	stones = s
	orbs = o
	sword_lv = sl
	chain_lv = cl
	action_log.append(Action.FORGE)
	_advance()
	return true


func can_upgrade(weapon: String, extra_sword := 0, extra_chain := 0, spent_stones := 0, spent_orbs := 0) -> bool:
	var table: Array = SWORD_TABLE if weapon == "sword" else CHAIN_TABLE
	var lv := (sword_lv + extra_sword) if weapon == "sword" else (chain_lv + extra_chain)
	if lv >= table.size():
		return false
	var cost: Array = table[lv]
	return stones - spent_stones >= int(cost[0]) and orbs - spent_orbs >= int(cost[1])


static func upgrade_cost(weapon: String, lv: int) -> Array:
	var table: Array = SWORD_TABLE if weapon == "sword" else CHAIN_TABLE
	return table[lv] if lv < table.size() else []


func sword_bonus() -> int:
	return 0 if sword_lv == 0 else int(SWORD_TABLE[sword_lv - 1][2])


func chain_bonus() -> int:
	return 0 if chain_lv == 0 else int(CHAIN_TABLE[chain_lv - 1][2])


func needs_branch() -> Array:
	var list: Array = []
	if sword_lv >= BRANCH_LEVEL and sword_branch == "":
		list.append("sword")
	if chain_lv >= BRANCH_LEVEL and chain_branch == "":
		list.append("chain")
	return list


func add_point(stat: String) -> bool:
	if points <= 0:
		return false
	match stat:
		"str":
			str_ += 1
		"vit":
			vit += 1
		"agi":
			agi += 1
		_:
			return false
	points -= 1
	return true


## 능력치 다시 나누기 (7일째 출발 전, 드래곤에게 진 뒤에 무료)
func respec() -> void:
	points += (str_ - START_STAT) + (vit - START_STAT) + (agi - START_STAT)
	str_ = START_STAT
	vit = START_STAT
	agi = START_STAT


## 싸움에 쓸 능력치 (battle_rules.gd 형식)
func battle_stats() -> Dictionary:
	var sword := float(str_ + sword_bonus())
	if sword_branch == "heavy":
		sword *= 1.3
	var max_hp := 50 + vit * 5
	if help_mode:
		max_hp = int(max_hp * 1.5)
	return {
		"max_hp": max_hp,
		"sword": int(round(sword)),
		"chain": str_ * 2 + chain_bonus(),
		"str": str_,
		"roll_invuln": 0.3 + agi * 0.01,
		"charge_time": maxf(0.8, 2.0 - agi * 0.03),
		"sword_cd": 0.35 / 1.3 if sword_branch == "fast" else 0.35,
		"sword_pause": 0.2 if sword_branch == "heavy" else 0.0,
		"chain_kind": chain_branch if chain_branch != "" else "normal",
		"fist": true,
	}


## 근육 팔 단계: 힘 20·30·40을 넘을 때마다 굵어져요
func arm_level() -> int:
	return int(str_ >= 20) + int(str_ >= 30) + int(str_ >= 40)


func leftover_warning() -> String:
	if day < DAYS or week_over():
		return ""
	var parts: Array = []
	if stones > 0:
		parts.append("반짝 돌 %d개" % stones)
	if orbs > 0:
		parts.append("황금 똥구슬 %d개" % orbs)
	if parts.is_empty():
		return ""
	return "남는 재료: %s (재료는 6장에서만 써요. 대장간에 가 보세요)" % ", ".join(parts)


func to_dict() -> Dictionary:
	return {
		"day": day, "slot": slot, "level": level, "xp": xp, "points": points,
		"str": str_, "vit": vit, "agi": agi, "sword_lv": sword_lv, "chain_lv": chain_lv,
		"sword_branch": sword_branch, "chain_branch": chain_branch, "stones": stones, "orbs": orbs,
		"secrets": secrets, "losses": losses, "help_mode": help_mode, "branch_switch_used": branch_switch_used,
		"action_log": action_log,
	}


static func from_dict(d: Dictionary) -> RefCounted:
	var g = load("res://scenes/chapter6/growth_rules.gd").new()
	g.day = int(d.get("day", 1))
	g.slot = int(d.get("slot", 0))
	g.level = int(d.get("level", START_LEVEL))
	g.xp = int(d.get("xp", 0))
	g.points = int(d.get("points", 0))
	g.str_ = int(d.get("str", START_STAT))
	g.vit = int(d.get("vit", START_STAT))
	g.agi = int(d.get("agi", START_STAT))
	g.sword_lv = int(d.get("sword_lv", 0))
	g.chain_lv = int(d.get("chain_lv", 0))
	g.sword_branch = String(d.get("sword_branch", ""))
	g.chain_branch = String(d.get("chain_branch", ""))
	g.stones = int(d.get("stones", 0))
	g.orbs = int(d.get("orbs", 0))
	g.secrets = Array(d.get("secrets", []))
	g.losses = int(d.get("losses", 0))
	g.help_mode = bool(d.get("help_mode", false))
	g.branch_switch_used = bool(d.get("branch_switch_used", false))
	g.action_log = Array(d.get("action_log", []))
	return g


# ------------------------------------------------------------------ 저장

const Save := preload("res://scripts/save_data.gd")


func save() -> void:
	Save.set_value("week", to_dict(), "chapter6")


static func load_or_new() -> RefCounted:
	var d = Save.get_value("week", {}, "chapter6")
	if d is Dictionary and not d.is_empty():
		return from_dict(d)
	return load("res://scenes/chapter6/growth_rules.gd").new()


static func clear_saved() -> void:
	Save.set_value("week", {}, "chapter6")
