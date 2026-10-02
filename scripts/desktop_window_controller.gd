class_name DesktopWindowController
extends RefCounted

const SIZE := Vector2i(320, 384)
const FOOT := Vector2(160, 376)
const BODY := Rect2(40, 100, 240, 276)
const MENU := Rect2(30, 8, 260, 204)
var scale_factor := 1.0
var menu_rect := MENU
var window: Window
var debug_mode := false
var body_polygon := PackedVector2Array()

func configure(target: Window, label: String, debug: bool, factor := 1.0) -> void:
	window = target
	debug_mode = debug
	window.title = label
	set_size_factor(factor)
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
		points.append_array(PackedVector2Array([menu_rect.position, Vector2(menu_rect.end.x, menu_rect.position.y), menu_rect.end, Vector2(menu_rect.position.x, menu_rect.end.y)]))
		points = Geometry2D.convex_hull(points)
	for i in points.size():
		points[i] *= scale_factor
	window.mouse_passthrough_polygon = points

static func work_area() -> Rect2:
	if DisplayServer.get_name() == "headless":
		return Rect2(0, 0, 1280, 720)
	return Rect2(DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen()))

static func clamp_foot(point: Vector2, area: Rect2, factor := 1.0) -> Vector2:
	return Vector2(clampf(point.x, area.position.x + FOOT.x * factor, maxf(area.position.x + FOOT.x * factor, area.end.x - (SIZE.x - FOOT.x) * factor)),
		clampf(point.y, area.position.y + FOOT.y * factor, maxf(area.position.y + FOOT.y * factor, area.end.y - 8 * factor)))

func move_foot(point: Vector2) -> void:
	var desired := Vector2i((point - FOOT * scale_factor).round())
	if window.position != desired:
		window.position = desired

func set_size_factor(value: float) -> void:
	scale_factor = value
	if window:
		window.size = Vector2i((Vector2(SIZE) * value).round())
		# Render at native resolution; scale the scene, not a small raster viewport.
		window.content_scale_size = window.size
