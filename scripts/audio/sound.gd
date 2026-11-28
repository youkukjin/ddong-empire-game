extends Node
## 소리 (제안): 효과음과 장마다 배경음이에요.
## 소리 파일 없이 코드로 직접 만들어요 (사인파·네모파·톱니파·잡음을 섞어요).
## 박력 있는 그림에 맞게 쾅! 하는 타격음, 드래곤 울음, 북소리 배경음을 넣었어요.
##
## 쓰는 법: const Sound := preload("res://scripts/audio/sound.gd")
##   Sound.play("boom")         효과음
##   Sound.play("boom", 0.8)    낮은 소리 (pitch)
## 배경음은 지금 화면(장)을 보고 알아서 바꿔요. 버튼 소리도 알아서 나요.
## 화면이 없는 자동 확인(headless)에서는 소리를 내지 않아요.

const RATE := 22050          # 효과음
const MRATE := 16000         # 배경음 (가볍게)
const SFX_DB := -3.0
const MUSIC_DB := -11.0
const VOICES := 10

static var _inst: Node = null
static var _sfx_cache := {}
static var _music_cache := {}

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_kind := ""
var _last_scene: Node = null
var _pending: Array = []
var _rng := RandomNumberGenerator.new()


# ------------------------------------------------------------------ 밖에서 부르는 곳

static func enabled() -> bool:
	return DisplayServer.get_name() != "headless"


## 소리 담당을 한 번 만들어요 (화면이 바뀌어도 계속 있어요).
static func ensure() -> Node:
	if _inst != null and is_instance_valid(_inst):
		return _inst
	if not enabled():
		return null
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_inst = (load("res://scripts/audio/sound.gd") as GDScript).new()
	_inst.name = "Sound"
	tree.root.add_child.call_deferred(_inst)
	return _inst


static func play(sfx_name: String, pitch := 1.0, db := 0.0) -> void:
	var n := ensure()
	if n:
		n._play(sfx_name, pitch, db)


## 결과 창 소리: 배경음을 잠깐 줄이고 짧은 곡을 들려줘요.
static func jingle(win: bool) -> void:
	var n := ensure()
	if n:
		n._duck(2.4)
		n._play("win" if win else "fail", 1.0, 0.0)


## 한 방 연출(impact)의 의성어를 보고 어울리는 소리를 골라요.
static func for_impact(text: String, power: float) -> void:
	var snd := "boom"
	var pitch := clampf(1.25 - 0.22 * power, 0.65, 1.25)
	if _has(text, ["으윽", "아야", "으악", "앗"]):
		snd = "hurt"
		pitch = 1.0
	elif _has(text, ["번쩍"]):
		snd = "flash"
		pitch = 1.0
	elif _has(text, ["뚝딱"]):
		snd = "build"
		pitch = 1.0
	elif _has(text, ["짠"]):
		snd = "coin"
		pitch = 0.9
	elif _has(text, ["불끈"]):
		snd = "power"
		pitch = 1.1
	elif _has(text, ["탁", "챙", "퍽", "슉"]):
		snd = "hit"
		pitch = randf_range(0.9, 1.15) / maxf(power, 0.6)
	elif text == "" and power < 1.0:
		snd = "hit"
	play(snd, pitch, clampf((power - 1.0) * 3.0, -4.0, 4.0))


## 떠오르는 글씨를 보고 어울리는 소리를 골라요. 숫자(피해량) 같은 건 조용해요.
static func for_text(text: String, font_size: int) -> void:
	if text.begins_with("-") or text.is_valid_int():
		return
	if _has(text, ["팅"]):
		play("clang")
	elif _has(text, ["놓쳤", "빗나", "막다른", "힘을 더", "먼저"]):
		play("miss")
	elif _has(text, ["좋아요", "잡았다", "반짝", "피했", "아슬아슬", "맞는 길", "성공", "+", "막았", "고쳤", "우리 집", "이쪽", "중간 저장", "비밀"]):
		play("coin", 1.0 + randf_range(-0.03, 0.06))
	elif _has(text, ["나타났", "화가 났", "날아올라", "나와라"]):
		play("roar", 0.95)
	elif font_size >= 44:
		play("power", 1.0)


static func _has(text: String, words: Array) -> bool:
	for w in words:
		if text.contains(w):
			return true
	return false


# ------------------------------------------------------------------ 소리 담당 노드

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_DB
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	add_child(_music)
	get_tree().node_added.connect(_on_node_added)
	for b in get_tree().root.find_children("*", "BaseButton", true, false):
		_on_node_added(b)
	for p in _pending:
		_play(p[0], p[1], p[2])
	_pending.clear()


func _process(_delta: float) -> void:
	var cur := get_tree().current_scene
	if cur != _last_scene:
		_last_scene = cur
		if cur:
			_set_music(music_for_scene(cur.scene_file_path))


## 화면(장)마다 배경음 종류예요.
static func music_for_scene(path: String) -> String:
	if path.contains("survivor/"):
		return "happy"
	for i in range(8, 0, -1):
		if path.contains("chapter%d/" % i):
			return ["", "fire", "train", "cave", "siege", "battle", "dragon", "final", "peace"][i]
	return "happy"


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("snd"):
		n.set_meta("snd", true)
		(n as BaseButton).pressed.connect(func() -> void: _play("click", 1.0, -2.0))


func _play(sfx_name: String, pitch: float, db: float) -> void:
	if not is_inside_tree():
		_pending.append([sfx_name, pitch, db])
		return
	var s := sfx_stream(sfx_name)
	if s == null:
		return
	var p: AudioStreamPlayer = null
	for q in _players:
		if not q.playing:
			p = q
			break
	if p == null:
		p = _players[_rng.randi() % _players.size()]
	p.stream = s
	p.pitch_scale = clampf(pitch, 0.4, 2.5)
	p.volume_db = SFX_DB + db
	p.play()


func _set_music(kind: String) -> void:
	if kind == _music_kind:
		return
	_music_kind = kind
	var s := music_stream(kind)
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -40.0, 0.4)
	tw.tween_callback(func() -> void:
		_music.stream = s
		_music.volume_db = MUSIC_DB
		if s:
			_music.play()
		else:
			_music.stop())


func _duck(sec: float) -> void:
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", MUSIC_DB - 12.0, 0.15)
	tw.tween_interval(sec)
	tw.tween_property(_music, "volume_db", MUSIC_DB, 0.8)


# ------------------------------------------------------------------ 효과음 만들기

const SFX_NAMES := ["click", "page", "hit", "boom", "hurt", "coin", "miss", "power", "flash", "build",
	"swing", "jump", "duck", "warn", "fire", "roar", "clang", "win", "fail"]


static func sfx_stream(sfx_name: String) -> AudioStreamWAV:
	if _sfx_cache.has(sfx_name):
		return _sfx_cache[sfx_name]
	var b := _build_sfx(sfx_name)
	if b.is_empty():
		return null
	var s := to_wav(b, RATE, false)
	_sfx_cache[sfx_name] = s
	return s


static func _build_sfx(n: String) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	var r := RandomNumberGenerator.new()
	r.seed = hash(n)
	match n:
		"click":
			b = _buf(0.08, RATE)
			_tone(b, RATE, 0.0, 0.07, 900, 620, 1, 0.35, 0.002, 40)
		"page":
			b = _buf(0.2, RATE)
			_noise(b, RATE, r, 0.0, 0.2, 0.3, 0.25, 12, 0.04)
		"hit":
			b = _buf(0.22, RATE)
			_noise(b, RATE, r, 0.0, 0.12, 0.9, 0.5, 28, 0.0)
			_tone(b, RATE, 0.0, 0.18, 260, 90, 0, 0.9, 0.001, 18)
			_tone(b, RATE, 0.0, 0.05, 1400, 700, 1, 0.25, 0.0, 60)
		"boom":
			b = _buf(0.8, RATE)
			_tone(b, RATE, 0.0, 0.75, 140, 32, 0, 1.2, 0.002, 4.5)
			_noise(b, RATE, r, 0.0, 0.7, 1.0, 0.12, 6, 0.0)
			_noise(b, RATE, r, 0.0, 0.08, 0.7, 0.8, 40, 0.0)
		"hurt":
			b = _buf(0.35, RATE)
			_tone(b, RATE, 0.0, 0.3, 480, 140, 1, 0.45, 0.003, 7)
			_noise(b, RATE, r, 0.0, 0.1, 0.5, 0.4, 25, 0.0)
		"coin":
			b = _buf(0.32, RATE)
			_tone(b, RATE, 0.0, 0.08, 988, 988, 1, 0.22, 0.002, 10)
			_tone(b, RATE, 0.07, 0.25, 1319, 1319, 1, 0.24, 0.002, 9)
			_tone(b, RATE, 0.07, 0.25, 2638, 2638, 0, 0.12, 0.002, 12)
		"miss":
			b = _buf(0.3, RATE)
			_tone(b, RATE, 0.0, 0.28, 220, 150, 2, 0.32, 0.005, 6)
		"power":
			b = _buf(0.55, RATE)
			_tone(b, RATE, 0.0, 0.5, 180, 820, 2, 0.35, 0.01, 2.5)
			_tone(b, RATE, 0.0, 0.5, 360, 1640, 1, 0.12, 0.01, 3)
			_noise(b, RATE, r, 0.3, 0.25, 0.3, 0.6, 8, 0.0)
		"flash":
			b = _buf(1.2, RATE)
			_noise(b, RATE, r, 0.0, 1.0, 0.8, 0.9, 3.5, 0.0)
			for k in 4:
				var f: float = [523.25, 659.25, 783.99, 1046.5][k]
				_tone(b, RATE, k * 0.06, 1.0, f, f * 1.01, 2, 0.16, 0.01, 2.2)
			_tone(b, RATE, 0.0, 0.9, 110, 40, 0, 0.9, 0.003, 3)
		"build":
			b = _buf(0.3, RATE)
			for k in 2:
				_tone(b, RATE, k * 0.13, 0.12, 420 - k * 60, 300 - k * 60, 3, 0.6, 0.001, 30)
				_noise(b, RATE, r, k * 0.13, 0.04, 0.4, 0.5, 60, 0.0)
		"swing":
			b = _buf(0.22, RATE)
			_noise(b, RATE, r, 0.0, 0.2, 0.55, 0.35, 0, 0.09)
		"jump":
			b = _buf(0.2, RATE)
			_tone(b, RATE, 0.0, 0.18, 280, 760, 1, 0.22, 0.003, 8)
		"duck":
			b = _buf(0.18, RATE)
			_tone(b, RATE, 0.0, 0.16, 520, 220, 1, 0.2, 0.003, 8)
		"warn":
			b = _buf(0.4, RATE)
			for k in 2:
				_tone(b, RATE, k * 0.17, 0.12, 1050, 1050, 1, 0.2, 0.003, 6)
		"fire":
			b = _buf(0.9, RATE)
			_noise(b, RATE, r, 0.0, 0.85, 0.8, 0.18, 2.5, 0.15)
			for k in 14:
				_noise(b, RATE, r, r.randf() * 0.8, 0.02, 0.5, 0.9, 80, 0.0)
		"roar":
			b = _buf(1.3, RATE)
			_roar(b, RATE, r)
		"clang":
			b = _buf(0.5, RATE)
			for f in [1180.0, 1730.0, 2510.0]:
				_tone(b, RATE, 0.0, 0.45, f, f * 0.99, 0, 0.18, 0.001, 7)
			_noise(b, RATE, r, 0.0, 0.03, 0.5, 0.9, 80, 0.0)
		"win":
			b = _buf(1.8, RATE)
			var notes := [60, 64, 67, 72, 67, 72, 76]
			var at := [0.0, 0.11, 0.22, 0.33, 0.5, 0.6, 0.75]
			for k in notes.size():
				var f := midi_hz(notes[k])
				var dur := 0.95 if k == notes.size() - 1 else 0.16
				_tone(b, RATE, at[k], dur, f, f, 1, 0.22, 0.004, 3.0 if k == notes.size() - 1 else 8)
				_tone(b, RATE, at[k], dur, f * 2.0, f * 2.0, 0, 0.08, 0.004, 4)
			for f in [midi_hz(48), midi_hz(55), midi_hz(64)]:
				_tone(b, RATE, 0.75, 1.0, f, f, 2, 0.1, 0.01, 2.2)
			_kick(b, RATE, 0.0, 0.9)
			_kick(b, RATE, 0.75, 1.0)
			_noise(b, RATE, r, 0.75, 0.9, 0.35, 0.85, 3.5, 0.0)
		"fail":
			b = _buf(1.4, RATE)
			var fn := [67, 63, 60, 55]
			for k in fn.size():
				var f := midi_hz(fn[k])
				_tone(b, RATE, k * 0.24, 0.5 if k == 3 else 0.24, f, f * (0.94 if k == 3 else 1.0), 2, 0.22, 0.005, 3.0 if k == 3 else 6)
	return b


static func _roar(b: PackedFloat32Array, rate: int, r: RandomNumberGenerator) -> void:
	var n := b.size()
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var env := minf(t / 0.12, 1.0) * exp(-maxf(t - 0.35, 0.0) * 2.6)
		var f := 95.0 + 25.0 * sin(t * 3.0) + 9.0 * sin(t * 37.0)
		ph += f / rate
		var saw := fmod(ph, 1.0) * 2.0 - 1.0
		lp += 0.25 * (r.randf_range(-1.0, 1.0) - lp)
		var x := saw * 0.7 + lp * 0.9
		b[i] += clampf(x * 1.8, -1.0, 1.0) * env * 0.8


# ------------------------------------------------------------------ 배경음 만들기

## 배경음 설정: bpm, 으뜸음(midi), 음계, 4마디 화음, 북 박자(16칸), 멜로디 소리 모양
const MUSIC := {
	# 흥겹고 잔잔한 곡 (2026-11-28 사용자: "애들이 좋아하게 흥겹고 잔잔하게"). 처음 화면과 서바이버.
	# 멜로디를 손으로 써 둔 곡이라 tune: true (build_music이 _build_tune으로 만들어요)
	"happy": {"tune": true, "bpm": 116, "root": 48, "seed": 5},
	"title": {"bpm": 104, "root": 50, "scale": [0, 2, 3, 5, 7, 8, 10], "prog": [0, 5, 3, 4],
		"kick": "x...x...x...x.x.", "snare": "....x.......x...", "hat": "..x...x...x...x.",
		"bass": "x..x..x.x..x..x.", "lead": "x...x.x.x...x...", "wave": 2, "seed": 3, "boom": true},
	"fire": {"bpm": 138, "root": 45, "scale": [0, 2, 3, 5, 7, 8, 10], "prog": [0, 0, 5, 4],
		"kick": "x..x..x.x..x..x.", "snare": "....x.......x..x", "hat": "x.x.x.x.x.x.x.x.",
		"bass": "x.xxx.xxx.xxx.xx", "lead": "x..x..x.x.x.x...", "wave": 1, "seed": 11, "boom": false},
	"train": {"bpm": 126, "root": 48, "scale": [0, 2, 4, 5, 7, 9, 11], "prog": [0, 4, 5, 3],
		"kick": "x...x...x...x...", "snare": "....x.......x...", "hat": "x.xxx.xxx.xxx.xx",
		"bass": "x.x.x.x.x.x.x.x.", "lead": "x.x.x...x.x.xx..", "wave": 1, "seed": 5, "boom": false},
	"cave": {"bpm": 118, "root": 40, "scale": [0, 2, 3, 5, 7, 8, 10], "prog": [0, 5, 0, 6],
		"kick": "x.....x...x.....", "snare": "........x.......", "hat": "..x...x...x...x.",
		"bass": "x.....x...x.....", "lead": "x.....x...x...x.", "wave": 3, "seed": 21, "boom": false},
	"siege": {"bpm": 130, "root": 50, "scale": [0, 2, 3, 5, 7, 8, 10], "prog": [0, 6, 5, 4],
		"kick": "x...x...x...x...", "snare": "..x.x.xx..x.x.xx", "hat": "x...x...x...x...",
		"bass": "x..xx..xx..xx..x", "lead": "x...x.x.x...x.x.", "wave": 2, "seed": 8, "boom": true},
	"battle": {"bpm": 148, "root": 45, "scale": [0, 2, 3, 5, 7, 8, 10], "prog": [0, 5, 6, 4],
		"kick": "x.x...x.x.x...x.", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.x.",
		"bass": "xxx.xxx.xxx.xxx.", "lead": "x.x.x..xx.x.x...", "wave": 2, "seed": 13, "boom": false},
	"dragon": {"bpm": 152, "root": 43, "scale": [0, 1, 3, 5, 7, 8, 10], "prog": [0, 1, 0, 6],
		"kick": "x.x.x.x.x.x.x.x.", "snare": "....x.......x.x.", "hat": "xxxxxxxxxxxxxxxx",
		"bass": "x.xxx.xxx.xxx.xx", "lead": "x..x..x.x..x..x.", "wave": 2, "seed": 31, "boom": true},
	"final": {"bpm": 156, "root": 50, "scale": [0, 2, 3, 5, 7, 8, 11], "prog": [0, 5, 3, 4],
		"kick": "x.x.x.x.x.x.x.x.", "snare": "....x..x....x.xx", "hat": "xxxxxxxxxxxxxxxx",
		"bass": "xxxxxxxxxxxxxxxx", "lead": "x.x.x.xxx.x.x.x.", "wave": 2, "seed": 41, "boom": true},
	"peace": {"bpm": 92, "root": 53, "scale": [0, 2, 4, 5, 7, 9, 11], "prog": [0, 3, 4, 0],
		"kick": "x.......x.......", "snare": "", "hat": "....x.......x...",
		"bass": "x.......x...x...", "lead": "x...x.x.x.....x.", "wave": 3, "seed": 2, "boom": false},
}


static func music_stream(kind: String) -> AudioStreamWAV:
	if not MUSIC.has(kind):
		return null
	if _music_cache.has(kind):
		return _music_cache[kind]
	var s := to_wav(build_music(kind), MRATE, true)
	_music_cache[kind] = s
	return s


## 손으로 쓴 멜로디: 마디마다 [시작 칸, 길이 칸, 음(MIDI)]. 한 마디 16칸.
const TUNE_CHORDS := [0, 4, 5, 3, 0, 4, 3, 0]     # C G Am F | C G F C
const TUNE := [
	[[0, 2, 76], [2, 2, 79], [4, 2, 79], [6, 2, 76], [8, 4, 72], [12, 2, 74], [14, 2, 76]],
	[[0, 2, 74], [2, 2, 71], [4, 2, 74], [6, 2, 79], [8, 4, 77], [12, 2, 76], [14, 2, 74]],
	[[0, 2, 72], [2, 2, 76], [4, 4, 81], [8, 2, 79], [10, 2, 76], [12, 4, 72]],
	[[0, 4, 74], [4, 2, 77], [6, 2, 81], [8, 6, 79]],
	[[0, 2, 76], [2, 2, 79], [4, 4, 84], [8, 2, 83], [10, 2, 81], [12, 4, 79]],
	[[0, 2, 77], [2, 2, 76], [4, 4, 74], [8, 2, 79], [10, 2, 77], [12, 4, 74]],
	[[0, 2, 72], [2, 2, 74], [4, 2, 76], [6, 2, 77], [8, 4, 81], [12, 4, 79]],
	[[0, 4, 76], [4, 4, 74], [8, 8, 72]],
]


static func _build_tune(m: Dictionary) -> PackedFloat32Array:
	var step: float = 60.0 / float(m.bpm) / 4.0
	var bars := TUNE.size()
	var b := _buf(step * 16 * bars, MRATE)
	var r := RandomNumberGenerator.new()
	r.seed = m.seed
	var major := [0, 2, 4, 5, 7, 9, 11]
	for bar in bars:
		var t0: float = bar * 16 * step
		var chord: int = TUNE_CHORDS[bar]
		# 통통 튀는 북: 작은 북, 손뼉, 셰이커
		for i in 16:
			var t: float = t0 + i * step
			if i == 0 or i == 8 or (i == 10 and bar % 2 == 1):
				_tone(b, MRATE, t, 0.16, 120, 50, 0, 0.45, 0.001, 18)
			if i == 4 or i == 12:
				_noise(b, MRATE, r, t, 0.09, 0.16, 0.6, 30, 0.0)
			if i % 2 == 0:
				_noise(b, MRATE, r, t, 0.03, 0.05 if i % 4 else 0.07, 0.95, 80, 0.0)
		# 깡충 베이스 (근음, 5음 왔다 갔다)
		for i in [0, 3, 6, 8, 11, 14]:
			var up := 4 if i == 6 or i == 14 else 0
			var f: float = midi_hz(m.root - 12 + _note(major, chord + up))
			_tone(b, MRATE, t0 + i * step, step * 1.8, f, f, 3, 0.24, 0.004, 7)
		# 우쿨렐레처럼 뒷박에 짧게 긁는 화음
		for i in [2, 6, 10, 14]:
			for k in [0, 2, 4]:
				var f: float = midi_hz(m.root + 12 + _note(major, chord + k))
				_tone(b, MRATE, t0 + i * step + k * 0.012, step * 1.5, f, f, 3, 0.045, 0.003, 10)
		# 아주 옅게 깔리는 화음
		for k in [0, 2, 4]:
			var f: float = midi_hz(m.root + _note(major, chord + k))
			_tone(b, MRATE, t0, step * 16, f, f * 1.002, 0, 0.03, 0.2, 0.3)
		# 멜로디: 실로폰(사인 + 한 옥타브 위 살짝) + 부드러운 피리
		for n in TUNE[bar]:
			var f: float = midi_hz(n[2])
			var t: float = t0 + n[0] * step
			var d: float = n[1] * step
			_tone(b, MRATE, t, d + step, f, f, 0, 0.14, 0.002, 5.5)
			_tone(b, MRATE, t, d * 0.6, f * 2.0, f * 2.0, 0, 0.04, 0.001, 12)
			_tone(b, MRATE, t, d * 0.95, f, f, 3, 0.04, 0.03, 1.5)
	return b


static func build_music(kind: String) -> PackedFloat32Array:
	var m: Dictionary = MUSIC[kind]
	if m.get("tune", false):
		return _build_tune(m)
	var step: float = 60.0 / float(m.bpm) / 4.0
	var bars := 4
	var b := _buf(step * 16 * bars, MRATE)
	var r := RandomNumberGenerator.new()
	r.seed = m.seed
	var scale: Array = m.scale
	var deg := 0
	for bar in bars:
		var chord: int = m.prog[bar]
		var t0: float = bar * 16 * step
		# 북
		for i in 16:
			var t: float = t0 + i * step
			if _on(m.kick, i):
				_kick(b, MRATE, t, 0.9)
			if _on(m.snare, i):
				_snare(b, MRATE, r, t, 0.45)
			if _on(m.hat, i):
				_noise(b, MRATE, r, t, 0.035, 0.16 if i % 4 else 0.22, 0.95, 70, 0.0)
		if m.boom and bar % 2 == 0:
			_tone(b, MRATE, t0, 1.2, 70, 38, 0, 0.55, 0.004, 2.5)
			_noise(b, MRATE, r, t0, 0.9, 0.25, 0.12, 3.5, 0.0)
		# 베이스 (근음과 5음)
		for i in 16:
			if _on(m.bass, i):
				var bn: int = m.root - 12 + _note(scale, chord + (4 if i % 8 == 6 else 0))
				var f: float = midi_hz(bn)
				_tone(b, MRATE, t0 + i * step, step * 1.6, f, f, 2, 0.26, 0.004, 9)
		# 깔리는 화음
		for k in [0, 2, 4]:
			var f: float = midi_hz(m.root + _note(scale, chord + k))
			_tone(b, MRATE, t0, step * 16, f, f * 1.003, 3, 0.05, 0.08, 0.6)
		# 멜로디: 화음 음을 중심으로 한 칸씩 움직여요
		for i in 16:
			if not _on(m.lead, i):
				continue
			if i == 0:
				deg = chord + [0, 2, 4][r.randi() % 3]
			else:
				deg += [-2, -1, -1, 1, 1, 2, 0][r.randi() % 7]
				deg = clampi(deg, chord - 2, chord + 9)
			var length := 1
			while i + length < 16 and not _on(m.lead, i + length) and length < 4:
				length += 1
			var f: float = midi_hz(m.root + 12 + _note(scale, deg))
			_tone(b, MRATE, t0 + i * step, step * length * 0.95, f, f, m.wave, 0.15, 0.006, 3.5)
	return b


static func _on(pattern: String, i: int) -> bool:
	return i < pattern.length() and pattern[i] == "x"


static func _note(scale: Array, degree: int) -> int:
	var oct := floori(degree / float(scale.size()))
	return scale[posmod(degree, scale.size())] + 12 * oct


static func midi_hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


static func _kick(b: PackedFloat32Array, rate: int, t: float, vol: float) -> void:
	_tone(b, rate, t, 0.22, 150, 42, 0, vol, 0.001, 14)


static func _snare(b: PackedFloat32Array, rate: int, r: RandomNumberGenerator, t: float, vol: float) -> void:
	_noise(b, rate, r, t, 0.16, vol, 0.7, 20, 0.0)
	_tone(b, rate, t, 0.08, 220, 160, 3, vol * 0.6, 0.001, 30)


# ------------------------------------------------------------------ 소리 재료

static func _buf(sec: float, rate: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * rate) + 1)
	return b


## 음 하나를 더해요. wave: 0 사인, 1 네모, 2 톱니, 3 세모. decay: 클수록 빨리 작아져요.
static func _tone(b: PackedFloat32Array, rate: int, start: float, dur: float, f0: float, f1: float, wave: int, vol: float, attack: float, decay: float) -> void:
	var i0 := int(start * rate)
	var n := mini(int(dur * rate), b.size() - i0)
	if n <= 0:
		return
	var ph := 0.0
	var rel := mini(int(0.01 * rate), n)
	var att := maxf(attack * rate, 1.0)
	var k := exp(-decay / rate)
	var env := 1.0
	for i in n:
		var f := f0 + (f1 - f0) * (float(i) / n)
		ph += f / rate
		var x: float
		var p := ph - floorf(ph)
		match wave:
			0:
				x = sin(TAU * p)
			1:
				x = 0.7 if p < 0.5 else -0.7
			2:
				x = (p * 2.0 - 1.0) * 0.8
			_:
				x = 1.0 - 4.0 * absf(p - 0.5)
		var a := env * minf(i / att, 1.0)
		if i > n - rel:
			a *= float(n - i) / rel
		b[i0 + i] += x * a * vol
		env *= k


## 잡음을 더해요. lp: 0~1 (작을수록 둔탁), hp_mix: 높은 소리만 남기는 정도. swell: 0보다 크면 가운데가 커지는 쉭- 소리.
static func _noise(b: PackedFloat32Array, rate: int, r: RandomNumberGenerator, start: float, dur: float, vol: float, lp: float, decay: float, swell: float) -> void:
	var i0 := int(start * rate)
	var n := mini(int(dur * rate), b.size() - i0)
	if n <= 0:
		return
	var y := 0.0
	var k := exp(-decay / rate)
	var env := 1.0
	var hp := lp > 0.9
	var prev := 0.0
	for i in n:
		var w := r.randf_range(-1.0, 1.0)
		y += lp * (w - y)
		var x := y
		if hp:
			x = w - prev
			prev = w
		var a := env
		if swell > 0.0:
			var t := float(i) / n
			a = sin(PI * t)
		b[i0 + i] += x * a * vol
		env *= k


static func to_wav(b: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		var x := b[i]
		var ax := absf(x)
		if ax > 0.7:
			# 부드럽게 눌러서 찢어지는 소리 대신 묵직하게 (박력)
			x = signf(x) * (0.7 + 0.3 * tanh((ax - 0.7) / 0.3))
		bytes.encode_s16(i * 2, int(x * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = b.size()
	return s
