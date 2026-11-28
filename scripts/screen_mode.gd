extends RefCounted
## 화면 방향 (2026-11-28 사용자 요청: 게임 전체를 세로로).
## 기본은 세로 720x1280이에요. 아직 세로로 바꾸지 않은 장은 들어갈 때 가로 1280x720으로 돌려요.

const PORTRAIT := Vector2i(720, 1280)
const LANDSCAPE := Vector2i(1280, 720)


static func portrait(tree: SceneTree) -> void:
	_apply(tree, PORTRAIT, DisplayServer.SCREEN_PORTRAIT)


static func landscape(tree: SceneTree) -> void:
	_apply(tree, LANDSCAPE, DisplayServer.SCREEN_SENSOR_LANDSCAPE)


## 세로로 든 폰에서 가로로 만든 장을 통째로 보여줘요 (위아래는 검은 띠).
## 2026-11-28 사용자: "스토리 모드 세로인데 잘 안 보여" → 잘라서 따라가는 대신 판 전체를 화면 너비에 맞춰요.
static func fit_landscape(tree: SceneTree) -> void:
	var root := tree.root
	if root.content_scale_size == LANDSCAPE:
		return
	root.content_scale_size = LANDSCAPE
	if OS.has_feature("mobile"):
		# 세로로 들면 판 전체가 보이고, 폰을 옆으로 돌리면 화면 가득 커져요
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)


static func is_portrait(tree: SceneTree) -> bool:
	return tree.root.content_scale_size.y > tree.root.content_scale_size.x


static func _apply(tree: SceneTree, size: Vector2i, orientation: int) -> void:
	var root := tree.root
	if root.content_scale_size == size:
		return
	root.content_scale_size = size
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(orientation)
	elif not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		# PC 창도 돌려요 (가로 960x540 ↔ 세로 405x720 비율)
		var win := DisplayServer.window_get_size()
		if (win.x > win.y) != (size.x > size.y):
			DisplayServer.window_set_size(Vector2i(win.y, win.x))
