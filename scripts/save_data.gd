extends RefCounted
## 기기에 남는 기록이에요: 장마다 최고 별, 다음 장 열림, 어려움 모드 열림.
## 키 이름: chapterN_best_stars, chapterN_unlocked (1장은 처음부터 열려 있어요),
## last_chapter (이어하기로 갈 장), [session] 중간 저장 (앱을 껐다 켜도 남아요)

static var path := "user://save.cfg"


static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(path)  # 파일이 없으면 빈 상태로 시작해요
	return cfg


static func get_value(key: String, default_value: Variant, section := "progress") -> Variant:
	return _load().get_value(section, key, default_value)


static func set_value(key: String, value: Variant, section := "progress") -> void:
	var cfg := _load()
	cfg.set_value(section, key, value)
	cfg.save(path)


static func hard_unlocked() -> bool:
	return bool(get_value("hard_unlocked", false))


static func is_unlocked(n: int) -> bool:
	return n == 1 or bool(get_value("chapter%d_unlocked" % n, false))


static func best_stars(n: int) -> int:
	return int(get_value("chapter%d_best_stars" % n, 0))


## 1장 결과를 저장하고, 이번에 새로 열린 것을 알려줘요.
static func record_chapter1_win(stars: int, hard: bool) -> Dictionary:
	var key := "chapter1_hard_best_stars" if hard else "chapter1_best_stars"
	var best := int(get_value(key, 0))
	var result := {
		"new_best": stars > best,
		"chapter2_new": not bool(get_value("chapter2_unlocked", false)),
		"hard_new": false,
	}
	if stars > best:
		set_value(key, stars)
	set_value("chapter2_unlocked", true)
	if stars >= 3 and not hard_unlocked():
		set_value("hard_unlocked", true)
		result["hard_new"] = true
	return result


## 2장부터: 장 결과를 저장하고, 다음 장이 이번에 처음 열렸는지 알려줘요.
static func record_chapter_win(n: int, stars: int) -> Dictionary:
	var best := best_stars(n)
	var next_key := "chapter%d_unlocked" % (n + 1)
	var result := {
		"new_best": stars > best,
		"next_new": not bool(get_value(next_key, false)),
	}
	if stars > best:
		set_value("chapter%d_best_stars" % n, stars)
	set_value(next_key, true)
	return result


## 이어하기: 마지막으로 하던 장 (없으면 0)
static func last_chapter() -> int:
	return int(get_value("last_chapter", 0))


static func set_last_chapter(n: int) -> void:
	if n != last_chapter():
		set_value("last_chapter", n)


## 이어할 기록이 있는지 (한 번이라도 장을 시작했거나 2장이 열렸으면)
static func has_progress() -> bool:
	return last_chapter() > 0 or is_unlocked(2)


## 이어하기로 갈 장: 열린 장 중 가장 뒤 장 (지금까지 간 곳)
static func continue_chapter(count: int) -> int:
	for i in range(count, 0, -1):
		if is_unlocked(i):
			return i
	return 1


# ------------------------------------------------------------------ 서바이버 (제안)

static func survivor_coins() -> int:
	return int(get_value("coins", 0, "survivor"))


static func survivor_best() -> float:
	return float(get_value("best_time", 0.0, "survivor"))


## 판이 끝나면 똥전을 더하고 가장 오래 버틴 시간을 남겨요. 새 기록이면 true.
static func record_survivor(coins: int, survived: float, cleared: bool) -> bool:
	set_value("coins", survivor_coins() + coins, "survivor")
	if cleared:
		set_value("clears", int(get_value("clears", 0, "survivor")) + 1, "survivor")
	if survived > survivor_best():
		set_value("best_time", survived, "survivor")
		return true
	return false


## 서바이버 무대: 고른 무대와 열린 무대 수 (처음엔 1곳)
static func survivor_stage() -> int:
	return int(get_value("stage", 0, "survivor"))


static func set_survivor_stage(i: int) -> void:
	set_value("stage", i, "survivor")


static func survivor_stages_open() -> int:
	return int(get_value("stages_open", 1, "survivor"))


## 이 무대에서 대마왕을 물리쳤으면 다음 무대를 열어요. 새로 열렸으면 true.
static func clear_survivor_stage(i: int, count: int) -> bool:
	if i + 2 > survivor_stages_open() and i + 1 < count:
		set_value("stages_open", i + 2, "survivor")
		return true
	return false


## 서바이버 캐릭터: 고른 캐릭터와 해금한 캐릭터 (처음엔 꼬마 똥)
static func survivor_hero() -> String:
	return String(get_value("hero", "kid", "survivor"))


static func set_survivor_hero(id: String) -> void:
	set_value("hero", id, "survivor")


static func hero_unlocked(id: String, cost: int) -> bool:
	return cost <= 0 or bool(get_value("hero_" + id, false, "survivor"))


## 똥전이 충분하면 빼고 캐릭터를 열어요. 열었으면 true.
static func unlock_hero(id: String, cost: int) -> bool:
	if hero_unlocked(id, cost):
		return true
	if survivor_coins() < cost:
		return false
	set_value("coins", survivor_coins() - cost, "survivor")
	set_value("hero_" + id, true, "survivor")
	return true


## 똥 대장간: 똥전으로 산 영구 강화 단계 (0부터)
static func forge_level(id: String) -> int:
	return int(get_value("forge_" + id, 0, "survivor"))


## 똥전이 충분하면 빼고 한 단계 올려요. 샀으면 true.
static func buy_forge(id: String, cost: int) -> bool:
	if survivor_coins() < cost:
		return false
	set_value("coins", survivor_coins() - cost, "survivor")
	set_value("forge_" + id, forge_level(id) + 1, "survivor")
	return true


## 똥 옷장 장비: 샀는지, 칸마다 무엇을 끼웠는지
static func equip_owned(id: String) -> bool:
	return bool(get_value("eq_own_" + id, false, "survivor"))


static func buy_equip(id: String, cost: int) -> bool:
	if equip_owned(id) or survivor_coins() < cost:
		return false
	set_value("coins", survivor_coins() - cost, "survivor")
	set_value("eq_own_" + id, true, "survivor")
	return true


static func equipped(slot: String) -> String:
	return String(get_value("eq_" + slot, "", "survivor"))


static func set_equipped(slot: String, id: String) -> void:
	set_value("eq_" + slot, id, "survivor")


## 버틴 시간 순위표 (위에서부터 오래 버틴 순, 10개까지). 각 칸: {time, level, kills, cleared, date}
static func survivor_ranks() -> Array:
	return get_value("ranks", [], "survivor")


## 순위표에 넣고 몇 위인지 돌려줘요 (1부터, 10위 밖이면 0)
static func add_survivor_rank(entry: Dictionary) -> int:
	var ranks: Array = survivor_ranks()
	ranks.append(entry)
	ranks.sort_custom(func(a, b): return float(a.time) > float(b.time))
	var place := ranks.find(entry) + 1
	if ranks.size() > 10:
		ranks.resize(10)
	set_value("ranks", ranks, "survivor")
	return place if place <= 10 else 0
