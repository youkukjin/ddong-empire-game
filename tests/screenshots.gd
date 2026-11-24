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
		await _frames(90)
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
	# 6장 드래곤 싸움
	var s6 := await _open("res://scenes/chapter6/dragon_battle.tscn", 5)
	s6.skip_intro()
	await _frames(40)
	await _save("6장-드래곤")
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
