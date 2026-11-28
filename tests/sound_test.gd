extends "res://tests/test_base.gd"
## 소리 자동 확인이에요: 효과음과 배경음이 잘 만들어지는지 봐요 (소리를 내지는 않아요).
## 실행: godot --headless --path . -s tests/sound_test.gd

const Sound := preload("res://scripts/audio/sound.gd")


func _run() -> void:
	check(not Sound.enabled() and Sound.ensure() == null, "화면이 없으면 소리를 내지 않아요")
	for n in Sound.SFX_NAMES:
		var b := Sound._build_sfx(n)
		var peak := 0.0
		for x in b:
			peak = maxf(peak, absf(x))
		check(b.size() > 100 and peak > 0.05 and peak < 3.0, "효과음 '%s' (%.2f초, 크기 %.2f)" % [n, b.size() / float(Sound.RATE), peak])
		check(Sound.sfx_stream(n) != null, "효과음 '%s' 재생용으로 바꿔요" % n)
	for kind in Sound.MUSIC:
		var t0 := Time.get_ticks_msec()
		var s := Sound.music_stream(kind)
		var ms := Time.get_ticks_msec() - t0
		var b := Sound.build_music(kind)
		var rms := 0.0
		var clip := 0
		for x in b:
			rms += x * x
			if absf(x) > 1.0:
				clip += 1
		rms = sqrt(rms / b.size())
		check(s != null and s.loop_mode == AudioStreamWAV.LOOP_FORWARD and rms > 0.03 and clip < b.size() / 50, "배경음 '%s' %.1f초, 만드는 데 %dms, 크기 %.2f, 넘침 %d" % [kind, b.size() / float(Sound.MRATE), ms, rms, clip])
	check(Sound.music_for_scene("res://scenes/chapter6/stage6.tscn") == "dragon" and Sound.music_for_scene("res://scenes/title/title_screen.tscn") == "happy", "장마다 배경음이 달라요")
