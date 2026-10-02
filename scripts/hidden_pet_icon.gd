class_name HiddenPetIcon
extends Window

signal restore_requested
signal exit_requested
const ICON := preload("res://assets/characters/icon/hiding_icon.png")
const ICON_RECT := Rect2(160, 80, 64, 64)
const MENU_RECT := Rect2(0, 8, 224, 64)
var icon_image: Image
var icon_polygon := PackedVector2Array()
var menu: PanelContainer
var ui_scale := 1.0
var picture: TextureRect
var icon_rect := ICON_RECT
var menu_rect := MENU_RECT
var icon_position := Vector2.ZERO
var positioned := false
var dragging := false
var drag_offset := Vector2.ZERO

func setup() -> void:
	title = "CP Pet Hidden"
	visible = false
	borderless = true
	transparent = true
	transparent_bg = true
	always_on_top = true
	unfocusable = true
	unresizable = true
	gui_embed_subwindows = false
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture = ICON
	picture.position = ICON_RECT.position
	picture.size = ICON_RECT.size
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	icon_image = ICON.get_image()
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(icon_image, 0.1)
	var points := PackedVector2Array()
	for polygon in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, icon_image.get_size()), 2.0):
		for point in polygon:
			points.append(ICON_RECT.position + point / Vector2(icon_image.get_size()) * ICON_RECT.size)
	icon_polygon = Geometry2D.convex_hull(points)
	window_input.connect(handle_input)
	close_requested.connect(func(): exit_requested.emit())
	reposition(DesktopWindowController.work_area())

func reposition(area: Rect2) -> void:
	ui_scale = minf(1.0, minf(area.size.x / 248.0, area.size.y / 160.0))
	size = Vector2i((Vector2(232, 152) * ui_scale).round())
	content_scale_size = Vector2i(232, 152)
	content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if not positioned:
		icon_position = Vector2(area.end.x - 72 * ui_scale, area.get_center().y - 32 * ui_scale)
		positioned = true
	place_icon(icon_position, area)

func place_icon(point: Vector2, area: Rect2) -> void:
	var icon_size := ICON_RECT.size * ui_scale
	icon_position = point.clamp(area.position, area.end - icon_size)
	# Keep the icon under the cursor while fitting its menu above or below it.
	var above := icon_position.y - area.position.y >= 72 * ui_scale
	var desired := icon_position - Vector2(160, 80 if above else 8) * ui_scale
	position = Vector2i(desired.clamp(area.position, area.end - Vector2(size)).round())
	icon_rect = Rect2((icon_position - Vector2(position)) / ui_scale, ICON_RECT.size)
	picture.position = icon_rect.position
	var menu_y := icon_rect.position.y - 72 if above else icon_rect.end.y + 8
	menu_rect = Rect2(Vector2(clampf(icon_rect.get_center().x - 112, 0, 8), menu_y), MENU_RECT.size)
	if is_instance_valid(menu):
		menu.position = menu_rect.position
	update_input_region()

func begin_icon_drag(mouse: Vector2) -> void:
	close_menu()
	dragging = true
	drag_offset = icon_position - mouse

func drag_to(mouse: Vector2, area: Rect2) -> void:
	if dragging:
		place_icon(mouse + drag_offset, area)

func stop_drag() -> void:
	dragging = false

func _process(_delta: float) -> void:
	if not visible or not dragging:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		stop_drag()
		return
	drag_to(Vector2(DisplayServer.mouse_get_position()), DesktopWindowController.work_area())

func open_at(area: Rect2) -> void:
	stop_drag()
	close_menu()
	reposition(area)
	show()
	update_input_region()

func dismiss() -> void:
	stop_drag()
	close_menu()
	hide()

func icon_hit(point: Vector2) -> bool:
	if not icon_rect.has_point(point):
		return false
	var pixel := Vector2i((point - icon_rect.position) / icon_rect.size * Vector2(icon_image.get_size()))
	return icon_image.get_pixelv(pixel).a > 0.1

func handle_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		stop_drag()
		return
	if not event.pressed or not icon_hit(event.position):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		begin_icon_drag(Vector2(DisplayServer.mouse_get_position()))
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		stop_drag()
		if is_instance_valid(menu):
			close_menu()
		else:
			show_menu()

func show_menu() -> void:
	stop_drag()
	close_menu()
	menu = PanelContainer.new()
	menu.position = menu_rect.position
	menu.size = menu_rect.size
	menu.add_theme_stylebox_override("panel", Pet.rounded(Color("fffaf0"), 10))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	menu.add_child(column)
	add_child(menu)
	add_button(column, "显示桌宠", func(): restore_requested.emit())
	add_button(column, "退出桌宠", func(): exit_requested.emit())
	update_input_region()

func add_button(column: VBoxContainer, label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(224, 28)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", preload("res://assets/fonts/DroidSansFallbackFull.ttf"))
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("253346"))
	button.add_theme_stylebox_override("normal", Pet.rounded(Color("fffaf0"), 8))
	button.add_theme_stylebox_override("hover", Pet.rounded(Color("e4eef2"), 8))
	button.pressed.connect(action)
	column.add_child(button)

func close_menu() -> void:
	if is_instance_valid(menu):
		menu.queue_free()
	menu = null
	update_input_region()

func update_input_region() -> void:
	var points := icon_polygon.duplicate()
	for index in points.size():
		points[index] += icon_rect.position - ICON_RECT.position
	if is_instance_valid(menu):
		points.append_array(PackedVector2Array([menu_rect.position, Vector2(menu_rect.end.x, menu_rect.position.y), menu_rect.end, Vector2(menu_rect.position.x, menu_rect.end.y)]))
		points = Geometry2D.convex_hull(points)
	for index in points.size():
		points[index] *= ui_scale
	mouse_passthrough_polygon = points
