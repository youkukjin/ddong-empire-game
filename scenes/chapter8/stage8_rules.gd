extends RefCounted
## 8장 '평화' 규칙이에요. 원작: "똥 제국이 다시 평화를 찾음".
## 쉬어 가는 장이라 시간 제한과 실패가 없어요. 할 일 세 가지를 마치면 밤이 걷히고 해가 떠요.
## 할 일 종류와 숫자는 모두 (제안)이에요. 1장의 돔 대피소, 불, 마을을 다시 써서 이야기를 마무리해요.
##
## 1) 무너진 집 고치기: 집을 톡톡톡 (세 번)
## 2) 남은 불씨 끄기: 손가락으로 쓱 (1장과 같은 쓸기)
## 3) 백성 데려오기: 돔 대피소의 백성을 고친 집까지 끌기

const HOUSES := 5
const HOUSE_TAPS := 3
const CITIZENS := 8
const EMBERS := 6
const HOUSE_Y := 470.0
const HOUSE_W := 130.0
const HOUSE_H := 120.0
const DOME_CENTER := Vector2(1150, 640)
const DOME_RADIUS := 120.0

var houses: Array = []        # {"x", "hp"} hp 0 = 다 고침
var embers: Array = []        # {"pos", "out"}
var citizens_home := 0
var citizens_left := CITIZENS
var elapsed := 0.0


func _init(seed_value := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else randi()
	for i in HOUSES:
		houses.append({"x": 110.0 + i * 190.0, "hp": HOUSE_TAPS})
	for i in EMBERS:
		embers.append({"pos": Vector2(rng.randf_range(80, 960), rng.randf_range(540, 690)), "out": false})


static func house_rect(h: Dictionary) -> Rect2:
	return Rect2(h.x - HOUSE_W / 2.0, HOUSE_Y - HOUSE_H, HOUSE_W, HOUSE_H)


func house_at(p: Vector2) -> Dictionary:
	for h in houses:
		if house_rect(h).grow(20).has_point(p):
			return h
	return {}


func fix_tap(h: Dictionary) -> bool:
	if h.is_empty() or h.hp <= 0:
		return false
	h.hp -= 1
	return true


func fixed_houses() -> int:
	var n := 0
	for h in houses:
		if h.hp <= 0:
			n += 1
	return n


## 손가락이 a에서 b로 지나갔을 때 그 길의 불씨를 꺼요. 끈 개수를 돌려줘요.
func sweep(a: Vector2, b: Vector2) -> int:
	var n := 0
	for e in embers:
		if e.out:
			continue
		var c := Geometry2D.get_closest_point_to_segment(e.pos, a, b)
		if c.distance_to(e.pos) < 50.0:
			e.out = true
			n += 1
	return n


func embers_out() -> int:
	var n := 0
	for e in embers:
		if e.out:
			n += 1
	return n


## 백성을 p에 놓았어요. 고친 집이면 집으로 들어가요.
func bring_home(p: Vector2) -> bool:
	if citizens_left <= 0:
		return false
	var h := house_at(p)
	if h.is_empty() or h.hp > 0:
		return false
	citizens_left -= 1
	citizens_home += 1
	return true


func total_tasks() -> int:
	return HOUSES + EMBERS + CITIZENS


func progress() -> float:
	return float(fixed_houses() + embers_out() + citizens_home) / float(total_tasks())


func done() -> bool:
	return fixed_houses() == HOUSES and embers_out() == EMBERS and citizens_home == CITIZENS
