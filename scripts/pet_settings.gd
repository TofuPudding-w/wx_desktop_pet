class_name PetSettings
extends RefCounted

const DEFAULT_BACKGROUND := Color("faf9f4")
const DEFAULT_TEXT := Color("253346")
var menu_background := DEFAULT_BACKGROUND
var menu_text := DEFAULT_TEXT

const SIZES := [1.0, 1.25, 1.5, 1.75, 2.0]
var requested_size := 1.0
var paused := false
var automatic_interactions := true

func load_from(path: String) -> void:
	menu_background = DEFAULT_BACKGROUND
	menu_text = DEFAULT_TEXT
	requested_size = 1.0
	paused = false
	automatic_interactions = true
	if path.is_empty():
		return
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	menu_background = read_color(config.get_value("appearance", "menu_background", ""), DEFAULT_BACKGROUND)
	menu_text = read_color(config.get_value("appearance", "menu_text", ""), DEFAULT_TEXT)
	var value: Variant = config.get_value("display", "pet_size", 1.0)
	if (value is float or value is int) and float(value) in SIZES:
		requested_size = float(value)

	var pause_value: Variant = config.get_value("behavior", "paused", false)
	var auto_value: Variant = config.get_value("behavior", "automatic_interactions", true)
	if pause_value is bool:
		paused = pause_value
	if auto_value is bool:
		automatic_interactions = auto_value

func save_to(path: String) -> Error:
	if path.is_empty():
		return OK
	var config := ConfigFile.new()
	config.load(path) # Preserve unrelated settings when more preferences are added.
	config.set_value("appearance", "menu_background", menu_background.to_html(false))
	config.set_value("appearance", "menu_text", menu_text.to_html(false))
	config.set_value("display", "pet_size", requested_size)
	config.set_value("behavior", "paused", paused)
	config.set_value("behavior", "automatic_interactions", automatic_interactions)
	return config.save(path)

func effective_size(area: Rect2) -> float:
	# Keep both characters and their menus usable on smaller work areas.
	return minf(requested_size, minf(area.size.y / 384.0, area.size.x / 540.0))

static func read_color(value: Variant, fallback: Color) -> Color:
	if value is String and value.length() == 6 and Color.html_is_valid(value):
		return Color.html(value)
	return fallback

func menu_color(role: String) -> Color:
	# Preserve the original palette exactly until users customize it.
	if menu_background == DEFAULT_BACKGROUND and menu_text == DEFAULT_TEXT:
		return Color({"background":"faf9f4", "text":"253346", "title":"30473f", "muted":"7d897f", "border":"dce2d8", "separator":"e2e7dd", "hover":"e6eee3", "subtle":"f0f2eb", "disabled":"777777", "exit":"985847"}.get(role, "253346"))
	match role:
		"background": return menu_background
		"border", "separator": return menu_background.lerp(menu_text, 0.25)
		"hover": return menu_background.lerp(menu_text, 0.14)
		"subtle": return menu_background.lerp(menu_text, 0.07)
		"muted", "disabled": return menu_background.lerp(menu_text, 0.7)
	return menu_text
