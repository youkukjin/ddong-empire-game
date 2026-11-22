extends RefCounted
## 기기에 남는 기록이에요: 장마다 최고 별, 다음 장 열림, 어려움 모드 열림.
## 키 이름: chapterN_best_stars, chapterN_unlocked (1장은 처음부터 열려 있어요)

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
