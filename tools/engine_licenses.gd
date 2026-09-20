extends SceneTree
func _initialize() -> void:
	var file := FileAccess.open("res://docs/GODOT-LICENSE.txt", FileAccess.WRITE)
	file.store_string(Engine.get_license_text())
	var third := FileAccess.open("res://docs/GODOT-THIRD-PARTY.json", FileAccess.WRITE)
	third.store_string(JSON.stringify({"components": Engine.get_copyright_info(), "licenses": Engine.get_license_info()}, "  "))
	quit()
