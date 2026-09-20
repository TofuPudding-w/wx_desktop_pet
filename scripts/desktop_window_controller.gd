class_name DesktopWindowController
extends RefCounted

const SIZE := Vector2i(240, 240)
const FOOT := Vector2(120, 232)
const BODY := Rect2(72, 104, 96, 128)
var window: Window
var debug_mode := false

func configure(target: Window, label: String, debug: bool) -> void:
	window = target
	debug_mode = debug
	window.title = label
	window.size = SIZE
	window.unresizable = true
	window.borderless = not debug
	window.transparent = not debug
	window.transparent_bg = not debug
	window.always_on_top = not debug
	window.unfocusable = not debug
	window.gui_embed_subwindows = false
	update_input(false)

func update_input(expanded: bool) -> void:
	if debug_mode:
		window.mouse_passthrough_polygon = PackedVector2Array()
		return
	var r := Rect2(8, 8, 224, 224) if expanded else BODY
	window.mouse_passthrough_polygon = PackedVector2Array([
		r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

static func work_area() -> Rect2:
	if DisplayServer.get_name() == "headless":
		return Rect2(0, 0, 1280, 720)
	return Rect2(DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen()))

static func clamp_foot(point: Vector2, area: Rect2) -> Vector2:
	return Vector2(clampf(point.x, area.position.x + 120, maxf(area.position.x + 120, area.end.x - 120)),
		clampf(point.y, area.position.y + 232, maxf(area.position.y + 232, area.end.y - 8)))

func move_foot(point: Vector2) -> void:
	var desired := Vector2i((point - FOOT).round())
	if window.position != desired:
		window.position = desired
