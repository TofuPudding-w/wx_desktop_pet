class_name StoryBubble
extends Window
var panel: PanelContainer
var speaker_label: Label
var text_label: Label

func setup(font: Font) -> void:
	title = "CP Pet Dialogue"
	visible = false
	borderless = true
	transparent = true
	transparent_bg = true
	always_on_top = true
	unfocusable = true
	unresizable = true
	mouse_passthrough = true
	gui_embed_subwindows = false
	panel = PanelContainer.new()
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	speaker_label = Label.new()
	speaker_label.add_theme_font_override("font", font)
	speaker_label.add_theme_font_size_override("font_size", 14)
	column.add_child(speaker_label)
	text_label = Label.new()
	text_label.add_theme_font_override("font", font)
	text_label.add_theme_font_size_override("font_size", 17)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(text_label)

func present(pet: Pet, text: String, palette: PetSettings) -> void:
	var area := DesktopWindowController.work_area()
	var width := minf(340, area.size.x - 16)
	var style := Pet.rounded(palette.menu_color("background"), 12)
	style.set_content_margin_all(12)
	style.set_border_width_all(1)
	style.border_color = palette.menu_color("border")
	panel.add_theme_stylebox_override("panel", style)
	speaker_label.add_theme_color_override("font_color", palette.menu_color("title"))
	text_label.add_theme_color_override("font_color", palette.menu_color("text"))
	speaker_label.text = pet.display_name
	text_label.text = text # Plain text: user content is never parsed as markup/code.
	text_label.custom_minimum_size.x = width - 24
	var font := text_label.get_theme_font("font")
	var text_height := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width - 24, 17, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE).y
	text_height += maxf(0, ceilf(text_height / font.get_height(17)) - 1) * text_label.get_theme_constant("line_spacing")
	var height := ceilf(text_height + speaker_label.get_theme_font("font").get_height(14) + 30)
	panel.size = Vector2(width, height)
	size = Vector2i(width, height)
	content_scale_size = size
	var desired := Vector2(pet.foot.x - size.x * 0.5, pet.controller.window.position.y + 130 * pet.size_factor - size.y - 10)
	position = Vector2i(desired.clamp(area.position, (area.end - Vector2(size)).max(area.position)))
	show()

func clear() -> void:
	hide()
