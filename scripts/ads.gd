extends RefCounted
## 광고는 모두 여기서만 불러요 (2026-11-28 사용자: 구글 플레이 출시 후 광고 수익).
## 아이들 게임이라 보상형 광고만 써요: 보고 나면 선물을 받아요 (이어하기, 똥전 2배).
## 구글 플레이 가족 정책: 인증된 광고(AdMob 어린이용 설정)만, 맞춤 광고는 꺼요.
##
## 지금은 진짜 광고 대신 연습용 화면(5초 세기)을 보여줘요.
## 나중에 AdMob 안드로이드 플러그인을 넣으면 show_rewarded 안에서 그쪽을 부르면 돼요.
##   Ads.show_rewarded(parent, "revive", func(ok: bool): ...)

const Cute := preload("res://scripts/art/cute.gd")
const PRACTICE_SECONDS := 5

## 광고 자리 이름 (AdMob 광고 단위와 짝지어요)
const PLACES := {"revive": "이어하기", "double_coins": "똥전 2배"}


static func available() -> bool:
	return true


## 보상형 광고를 보여주고, 끝까지 보면 done.call(true), 닫거나 실패하면 done.call(false)
static func show_rewarded(parent: Node, place: String, done: Callable) -> void:
	if Engine.has_singleton("GodotAdMob"):
		# 진짜 광고 (플러그인을 넣은 뒤에 연결해요)
		pass
	_practice(parent, place, done)


static func _practice(parent: Node, place: String, done: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.name = "AdPractice"
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.08, 0.12, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Cute.style_label(l, 44, Color(1, 0.95, 0.85), Cute.COCOA, 10)
	bg.add_child(l)
	var left := PRACTICE_SECONDS
	var tree := parent.get_tree()
	while left > 0 and is_instance_valid(layer):
		l.text = "광고 자리\n(%s)\n\n%d" % [PLACES.get(place, place), left]
		await tree.create_timer(1.0, true, false, true).timeout
		left -= 1
	if is_instance_valid(layer):
		layer.queue_free()
	done.call(true)
