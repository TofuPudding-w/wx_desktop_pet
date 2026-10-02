class_name PetSettings
extends RefCounted

const SIZES := [1.0, 1.25, 1.5, 1.75, 2.0]
var requested_size := 1.0
var paused := false
var automatic_interactions := true

func load_from(path: String) -> void:
	requested_size = 1.0
	paused = false
	automatic_interactions = true
	if path.is_empty():
		return
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
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
	config.set_value("display", "pet_size", requested_size)
	config.set_value("behavior", "paused", paused)
	config.set_value("behavior", "automatic_interactions", automatic_interactions)
	return config.save(path)

func effective_size(area: Rect2) -> float:
	# Keep both characters and their menus usable on smaller work areas.
	return minf(requested_size, minf(area.size.y / 384.0, area.size.x / 540.0))
