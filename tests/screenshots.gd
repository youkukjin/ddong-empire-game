extends SceneTree
## 화면 캡처 도우미예요 (헤드리스가 아닌 창 모드에서 돌려요).
## godot --path . -s tests/screenshots.gd -- <저장할 폴더>
## 타이틀, 장 고르기, 이야기 장면, 1~8장 플레이 화면, 결과 창을 PNG로 저장해요.

const Save := preload("res://scripts/save_data.gd")
const Chapters := preload("res://scripts/chapters.gd")

var out := "user://shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	Save.path = "user://shot_save.cfg"
	DirAccess.remove_absolute(Save.path)
	for n in range(1, Chapters.COUNT + 1):
		Save.record_chapter_win(n, 3 if n < 5 else 2)
	_main.call_deferred()


func _main() -> void:
	await _shot("res://scenes/title/title_screen.tscn", "00-타이틀", 40)
	await _shot("res://scenes/title/chapter_select.tscn", "01-장고르기", 10)
	await _open("res://scenes/chapter2/stage2.tscn", 10)
	await _save("02-이야기장면")
	for n in range(1, Chapters.COUNT + 1):
		var stage := await _open(Chapters.scene(n), 5)
		if stage.has_method("skip_intro"):
			stage.skip_intro()
		if n == 2:
			# 2장: 검 연습 표적이 튀어나온 순간
			stage.rules.drill = stage.Rules.Drill.SWORD
			stage.begin_drill()
		await _frames(30 if n == 3 or n == 4 else 90)
		await _save("%d장-플레이" % n)
	# 1장: 드래곤이 입을 벌리고 줄기를 쏘는 순간
	var s1 := await _open(Chapters.scene(1), 5)
	s1.skip_intro()
	await _frames(60)
	s1._beam_timer = 999.0
	s1._mouth_timer = 999.0
	for b in s1.beams_root.get_children():
		b.queue_free()
	s1.dragon.state = s1.dragon.State.IDLE
	await _frames(30)
	Engine.time_scale = 0.01
	s1.dragon.open_mouth(1.5)
	s1._fire_beam()
	await _frames(6)
	await _save("1장-경고")
	for bm in s1.beams_root.get_children():
		bm.warning_left = 0.0
	await _frames(4)
	await _save("1장-줄기")
	Engine.time_scale = 1.0
	# 5장 대마왕
	var s5 := await _open(Chapters.scene(5), 5)
	s5.skip_intro()
	await _frames(5)
	for e in s5.battle.enemies:
		e.state = "dead"
	s5.battle.spawn("demon", 1000.0)
	await _frames(40)
	await _save("5장-대마왕")
	# 박력 연출: 사슬 무기가 맞는 순간 (제안)
	s5.impact(Vector2(s5.battle.boss().x, 470), "콰지직!", Color(0.45, 1, 0.4), 1.4)
	await _frames(3)
	await _save("5장-타격")
	# 6장 드래곤 싸움
	var s6 := await _open("res://scenes/chapter6/dragon_battle.tscn", 5)
	s6.skip_intro()
	await _frames(40)
	await _save("6장-드래곤")
	# 보라색 광선 "콰앙"
	if s6.view3d:
		var dr: Dictionary = s6.battle.boss()
		dr.target_x = s6.battle.hero_x
		s6.view3d.on_event({"type": "strike", "enemy": dr, "attack": {"type": "beam"}})
		Engine.time_scale = 0.05
		await _frames(3)
		await _save("6장-광선")
		Engine.time_scale = 1.0
	# 7장: 똥의 신으로 각성
	var s7 := await _open(Chapters.scene(7), 5)
	s7.skip_intro()
	await _frames(5)
	s7.battle.god_left = 12.0
	s7.prince.god = true
	s7.battle.hero_x = 500.0
	await _frames(20)
	s7.impact(Vector2(500, 400), "번쩍!!", Color(1, 0.85, 0.2), 2.4)
	await _frames(2)
	await _save("7장-각성")
	# 7장 끝: 드래곤을 물리치면 똥의 신으로 변신
	s7 = await _open(Chapters.scene(7), 5)
	s7.skip_intro()
	await _frames(5)
	s7.battle.hero_x = 420.0
	await _frames(5)
	var boss: Dictionary = s7.battle.boss()
	boss.hp = 0
	boss.state = "dead"
	await create_timer(2.4).timeout
	await _save("7장-변신1-금빛기둥")
	await create_timer(0.75).timeout
	await _save("7장-변신2-번쩍")
	await create_timer(1.5).timeout
	await _save("7장-변신3-똥의신")
	# 결과 창
	var st := current_scene
	if st.has_method("finish_win"):
		st.finish_win(3, "잘했어요!", "걸린 시간 1:20")
		await _frames(10)
		await _save("99-결과창")
	DirAccess.remove_absolute(Save.path)
	quit(0)


func _open(path: String, wait: int) -> Node:
	paused = false
	change_scene_to_file(path)
	await _frames(wait)
	return current_scene


func _shot(path: String, name: String, wait: int) -> void:
	await _open(path, wait)
	await _save(name)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
