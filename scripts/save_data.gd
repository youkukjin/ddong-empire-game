extends RefCounted
## 기기에 남는 기록이에요: 1장 최고 별, 어려움 모드 열림, 2장 열림.

static var path := "user://save.cfg"


static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(path)  # 파일이 없으면 빈 상태로 시작해요
	return cfg


static func get_value(key: String, default_value: Variant) -> Variant:
	return _load().get_value("progress", key, default_value)


static func set_value(key: String, value: Variant) -> void:
	var cfg := _load()
	cfg.set_value("progress", key, value)
	cfg.save(path)


static func hard_unlocked() -> bool:
	return bool(get_value("hard_unlocked", false))


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
