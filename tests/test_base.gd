extends SceneTree
## 자동 확인 파일들이 함께 쓰는 도우미예요.

const Save := preload("res://scripts/save_data.gd")
const Session := preload("res://scripts/game_session.gd")

var _failed := 0


func _initialize() -> void:
	Save.path = "user://test_save.cfg"
	DirAccess.remove_absolute(Save.path)
	_main.call_deferred()


func _main() -> void:
	await _run()
	DirAccess.remove_absolute(Save.path)
	if _failed == 0:
		print("모든 확인 통과")
		quit(0)
	else:
		print("실패한 확인: ", _failed)
		quit(1)


## 각 확인 파일이 채워요.
func _run() -> void:
	pass


func open_scene(path: String) -> Node:
	paused = false
	change_scene_to_file(path)
	await frames(3)
	return current_scene


func frames(n: int) -> void:
	for i in n:
		await process_frame


func check(ok: bool, what: String) -> void:
	if ok:
		print("✓ ", what)
	else:
		_failed += 1
		push_error("✗ " + what)


func touch(stage: Node, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = pressed
	stage._play_input(e)


func drag(stage: Node, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = pos
	stage._play_input(e)


## 탭: 누르고 바로 떼요.
func tap(stage: Node, pos: Vector2) -> void:
	touch(stage, pos, true)
	touch(stage, pos, false)


## 쓸기: 누르고 dir 쪽으로 120픽셀 옮긴 뒤 떼요.
func swipe(stage: Node, pos: Vector2, dir: Vector2) -> void:
	touch(stage, pos, true)
	drag(stage, pos + dir * 120.0)
	touch(stage, pos + dir * 120.0, false)


## 길게 누르기: 누르고 held초 동안 누른 채로 있다가 떼요.
func hold(stage: Node, pos: Vector2, held: float) -> void:
	touch(stage, pos, true)
	stage.gesture.tick(held)
	touch(stage, pos, false)


func press_button(stage: Node, text: String) -> bool:
	var b: Button = stage.find_overlay_button(text)
	if b == null:
		return false
	b.pressed.emit()
	return true


## 싸움 자동 플레이 한 걸음 (5~7장 확인용): 맞을 공격은 직전에 구르고, 닿으면 검, 아니면 다가가요.
## 사슬 무기는 쓰지 않아요 (가장 단순한 플레이로도 이길 수 있는지 봐요).
func bot_step(stage: Node, delta: float) -> void:
	var b = stage.battle
	var danger := false
	for e in b.enemies:
		if e.state != "windup":
			continue
		var left: float = b.warn_time(e.attack) - e.t
		if left < 0.12 and b.would_hit_hero(e) and not b.is_invulnerable():
			var away := -1.0 if e.x > b.hero_x else 1.0
			if e.attack.type == "charge":
				away = signf(e.target_x - e.x)  # 돌진은 구르면서 통과해요
			if b.hero_x < 200.0:
				away = 1.0
			elif b.hero_x > 1080.0:
				away = -1.0
			stage.do_roll(away)
			danger = true
		elif left < 0.6 and b.would_hit_hero(e):
			danger = true
	if not danger and b.pause_left <= 0.0:
		if not b.sword_target().is_empty():
			stage.do_sword()
		else:
			var near = null
			for e in b.enemies:
				if b.targetable(e) and (near == null or absf(e.x - b.hero_x) < absf(near.x - b.hero_x)):
					near = e
			if near != null:
				b.walk_to(near.x - signf(near.x - b.hero_x) * (near.radius + 60.0))
	stage._play_process(delta)


func bot_fight(stage: Node, max_seconds: float) -> void:
	var steps := int(max_seconds * 30.0)
	for i in steps:
		if stage.phase != stage.Phase.PLAY:
			return
		bot_step(stage, 1.0 / 30.0)
		if i % 60 == 0:
			await process_frame
