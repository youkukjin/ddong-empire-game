extends RefCounted
## 장 목록이에요. 장 이름은 원작 챕터 구성표를 그대로 따라요.

const COUNT := 8
const TITLES := ["등장", "준비", "구멍 탐험", "성벽 돌파", "무사들과 대마왕", "재도전", "각성과 결말", "평화"]


static func title(n: int) -> String:
	return TITLES[n - 1]


static func scene(n: int) -> String:
	return "res://scenes/chapter%d/stage%d.tscn" % [n, n]


## 그 장의 화면이 프로젝트에 들어 있는지 (아직 만드는 중인 장은 false)
static func is_built(n: int) -> bool:
	return n >= 1 and n <= COUNT and ResourceLoader.exists(scene(n))
