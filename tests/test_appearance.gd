extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var settings := PetSettings.new()
	check(settings.menu_background == PetSettings.DEFAULT_BACKGROUND, "default background preserved")
	check(settings.menu_color("hover") == Color("e6eee3"), "original hover palette preserved")
	settings.menu_background = Color("182334")
	settings.menu_text = Color("f0ddb0")
	settings.requested_size = 1.5
	settings.paused = true
	var path := "user://test-appearance.cfg"
	check(settings.save_to(path) == OK, "save custom colors")
	var restored := PetSettings.new()
	restored.load_from(path)
	check(restored.menu_background == settings.menu_background and restored.menu_text == settings.menu_text, "colors survive restart")
	check(restored.paused and restored.requested_size == 1.5, "appearance preserves existing preferences")
	check(restored.menu_color("title") == settings.menu_text and restored.menu_color("exit") == settings.menu_text, "custom text applies consistently")
	var config := ConfigFile.new()
	config.set_value("appearance", "menu_background", "not-a-color")
	config.set_value("appearance", "menu_text", 123)
	config.save(path)
	restored.load_from(path)
	check(restored.menu_background == PetSettings.DEFAULT_BACKGROUND and restored.menu_text == PetSettings.DEFAULT_TEXT, "invalid saved colors fall back safely")
	DirAccess.remove_absolute(path)
	var app = load("res://scenes/Main.tscn").instantiate()
	app.settings_path = ""
	root.add_child(app)
	await process_frame
	await process_frame
	app.show_appearance()
	await process_frame
	await process_frame
	var editor: AppearanceWindow = app.appearance_window
	check(editor.surface.get_theme_stylebox("panel").bg_color == PetSettings.DEFAULT_BACKGROUND, "editor opens with saved background")
	check(editor.warning.get_theme_color("font_color") == PetSettings.DEFAULT_TEXT, "editor text uses saved foreground")
	check(editor.picker.picker_shape == ColorPicker.SHAPE_HSV_WHEEL and not editor.picker.edit_alpha, "opaque circular color picker")
	editor.picker.color_changed.emit(Color("182334"))
	editor.select_color(false)
	editor.picker.color_changed.emit(Color("f0ddb0"))
	check(editor.surface.get_theme_stylebox("panel").bg_color == PetSettings.DEFAULT_BACKGROUND, "unsaved picker changes do not recolor editor chrome")
	editor.hide()
	check(app.settings.menu_background == PetSettings.DEFAULT_BACKGROUND, "cancel leaves applied colors unchanged")
	app.show_appearance()
	await process_frame
	await process_frame
	check(editor.background == PetSettings.DEFAULT_BACKGROUND, "reopen discards unsaved draft")
	editor.background = Color("182334")
	editor.foreground = Color("f0ddb0")
	editor.apply_colors()
	app.toggle_menu(app.pets[0])
	check(app.menu.get_theme_stylebox("panel").bg_color == Color("182334"), "main menu uses custom background")
	check(app.menu_column.get_child(0).get_theme_color("font_color") == Color("f0ddb0"), "main menu uses custom text")
	app.show_settings()
	check("菜单配色" in app.menu_column.get_child(4).text, "settings exposes appearance editor")
	app.close_menu()
	app.hide_pets()
	app.hiding_icon.show_menu()
	check(app.hiding_icon.menu.get_theme_stylebox("panel").bg_color == Color("182334"), "hidden icon menu shares palette")
	app.show_appearance()
	await process_frame
	await process_frame
	check(editor.surface.get_theme_stylebox("panel").bg_color == Color("182334"), "editor reopens using latest applied background")
	check(editor.background_button.get_theme_color("font_color") == Color("f0ddb0"), "editor buttons use latest applied text")
	editor.reset_draft()
	check(app.settings.menu_background == Color("182334"), "reset is previewed until applied")
	editor.apply_colors()
	check(app.settings.menu_background == PetSettings.DEFAULT_BACKGROUND and app.settings.menu_text == PetSettings.DEFAULT_TEXT, "restore defaults applies both colors")
	editor.background = Color.BLACK
	editor.foreground = Color.BLACK
	editor.refresh_preview()
	check("建议" in editor.warning.text, "low-contrast combination has readable warning outside preview")
	var area := Rect2(66, 32, 1854, 1168)
	var position := DesktopWindowController.menu_position(Vector2i(900, 816), Vector2i(276, 302), 1, area)
	check(position.y == 704, "menu raised by 120 pixels at default size")
	for factor in [1.0, 1.5, 2.0]:
		var extent := Vector2i(Vector2(276, 302) * factor)
		for corner in [area.position, area.end]:
			var location := DesktopWindowController.menu_position(Vector2i(corner), extent, factor, area)
			check(area.encloses(Rect2(Vector2(location), Vector2(extent))), "raised menu clamped inside work area at screen edges")
	app.queue_free()
	await process_frame
	print("APPEARANCE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
