class_name DesktopWindowController
extends RefCounted

const SIZE := Vector2i(320, 384)
const FOOT := Vector2(160, 376)
const BODY := Rect2(40, 100, 240, 276)
const MENU := Rect2(30, 8, 260, 96)
var window: Window
var debug_mode := false
var body_polygon := PackedVector2Array()

func configure(target: Window, label: String, debug: bool) -> void:
	window = target
	debug_mode = debug
	window.title = label
	window.size = SIZE
	window.content_scale_size = SIZE
	window.unresizable = true
	window.borderless = not debug
	window.transparent = not debug
	window.transparent_bg = not debug
	window.always_on_top = not debug
	window.unfocusable = not debug
	window.gui_embed_subwindows = false
	body_polygon = PackedVector2Array([BODY.position, Vector2(BODY.end.x, BODY.position.y), BODY.end, Vector2(BODY.position.x, BODY.end.y)])
	update_input(false)

func update_input(expanded: bool, polygon := PackedVector2Array()) -> void:
	if not polygon.is_empty():
		body_polygon = polygon
	if window == null:
		return
	if debug_mode:
		window.mouse_passthrough_polygon = PackedVector2Array()
		return
	var points := body_polygon.duplicate()
	if expanded:
		points.append_array(PackedVector2Array([MENU.position, Vector2(MENU.end.x, MENU.position.y), MENU.end, Vector2(MENU.position.x, MENU.end.y)]))
		points = Geometry2D.convex_hull(points)
	window.mouse_passthrough_polygon = points

static func work_area() -> Rect2:
	if DisplayServer.get_name() == "headless":
		return Rect2(0, 0, 1280, 720)
	return Rect2(DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen()))

static func clamp_foot(point: Vector2, area: Rect2) -> Vector2:
	return Vector2(clampf(point.x, area.position.x + FOOT.x, maxf(area.position.x + FOOT.x, area.end.x - (SIZE.x - FOOT.x))),
		clampf(point.y, area.position.y + FOOT.y, maxf(area.position.y + FOOT.y, area.end.y - 8)))

func move_foot(point: Vector2) -> void:
	var desired := Vector2i((point - FOOT).round())
	if window.position != desired:
		window.position = desired
