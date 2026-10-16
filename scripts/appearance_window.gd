class_name AppearanceWindow
extends Window
signal applied(background: Color, text: Color)
var background := PetSettings.DEFAULT_BACKGROUND
var foreground := PetSettings.DEFAULT_TEXT
var editing_background := true
var picker: ColorPicker
var surface: PanelContainer
var preview: PanelContainer
var preview_title: Label
var preview_option: Label
var warning: Label
var background_button: Button
var text_button: Button

func setup(font: Font) -> void:
	title = "菜单配色 · Menu Colors"
	min_size = Vector2i(420, 400)
	size = Vector2i(520, 740)
	always_on_top = true
	var ui_theme := Theme.new()
	ui_theme.default_font = font
	ui_theme.default_font_size = 16
	theme = ui_theme
	surface = PanelContainer.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var surface_style := StyleBoxFlat.new()
	surface_style.bg_color = Color("202622")
	surface.add_theme_stylebox_override("panel", surface_style)
	add_child(surface)
	var scroll := ScrollContainer.new()
	surface.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "菜单配色 / Menu Colors"
	column.add_child(heading)
	var choices := HBoxContainer.new()
	column.add_child(choices)
	background_button = add_button(choices, "背景颜色", func(): select_color(true))
	text_button = add_button(choices, "文字颜色", func(): select_color(false))
	preview = PanelContainer.new()
	column.add_child(preview)
	var labels := VBoxContainer.new()
	preview.add_child(labels)
	preview_title = Label.new()
	preview_title.text = "忘羡桌宠 · WangXian Desktop Pet"
	labels.add_child(preview_title)
	preview_option = Label.new()
	preview_option.text = "互动   ›     设置   ›     工具   ›"
	labels.add_child(preview_option)
	picker = ColorPicker.new()
	picker.edit_alpha = false
	picker.color_modes_visible = false
	picker.sliders_visible = false
	picker.presets_visible = false
	picker.sampler_visible = false
	picker.picker_shape = ColorPicker.SHAPE_HSV_WHEEL
	picker.color_changed.connect(func(color):
		color.a = 1.0
		if editing_background:
			background = color
		else:
			foreground = color
		refresh_preview())
	column.add_child(picker)
	warning = Label.new()
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size.y = 24
	column.add_child(warning)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	add_button(actions, "恢复默认", reset_draft)
	add_button(actions, "取消", hide)
	add_button(actions, "应用并保存", apply_colors)
	close_requested.connect(hide)

func add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func open(settings: PetSettings) -> void:
	background = settings.menu_background
	foreground = settings.menu_text
	apply_saved_palette(settings)
	select_color(true)
	var area := DesktopWindowController.work_area()
	size = Vector2i(Vector2(520, 740).min(area.size - Vector2(24, 24)))
	position = Vector2i(area.get_center()) - size / 2
	show()
	grab_focus() # Explicit user-opened editor, never automatic.

func select_color(is_background: bool) -> void:
	editing_background = is_background
	picker.color = background if editing_background else foreground
	background_button.text = ("✓ " if editing_background else "") + "背景颜色"
	text_button.text = ("" if editing_background else "✓ ") + "文字颜色"
	refresh_preview()

func reset_draft() -> void:
	background = PetSettings.DEFAULT_BACKGROUND
	foreground = PetSettings.DEFAULT_TEXT
	select_color(editing_background)

func refresh_preview() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_border_width_all(1)
	style.border_color = background.lerp(foreground, 0.25)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	preview.add_theme_stylebox_override("panel", style)
	preview_title.add_theme_color_override("font_color", foreground)
	preview_option.add_theme_color_override("font_color", foreground)
	var a := background.srgb_to_linear().get_luminance()
	var b := foreground.srgb_to_linear().get_luminance()
	var contrast := (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)
	warning.text = "文字与背景接近，建议调整颜色以便阅读。" if contrast < 3 else "预览效果如上；点击「应用并保存」生效。"

func apply_colors() -> void:
	applied.emit(background, foreground)
	hide()

func apply_saved_palette(settings: PetSettings) -> void:
	# Editor chrome uses the last applied palette; drafts affect only preview.
	var next_theme := theme.duplicate() as Theme
	var fill := StyleBoxFlat.new()
	fill.bg_color = settings.menu_background
	surface.add_theme_stylebox_override("panel", fill)
	for type in ["Label", "Button", "LineEdit", "ColorPicker"]:
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_uneditable_color"]:
			next_theme.set_color(key, type, settings.menu_text)
		next_theme.set_color("font_disabled_color", type, settings.menu_color("disabled"))
	next_theme.set_color("caret_color", "LineEdit", settings.menu_text)
	next_theme.set_color("selection_color", "LineEdit", settings.menu_text)
	next_theme.set_color("font_selected_color", "LineEdit", settings.menu_background)
	for type in ["Button", "LineEdit"]:
		for state in ["normal", "hover", "pressed", "disabled", "read_only", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = settings.menu_color("hover" if state in ["hover", "pressed"] else "subtle")
			style.set_corner_radius_all(6)
			style.set_content_margin_all(6)
			if state == "focus":
				style.draw_center = false
				style.set_border_width_all(1)
				style.border_color = settings.menu_text
			next_theme.set_stylebox(state, type, style)

	theme = next_theme
