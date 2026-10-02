class_name LocalGuide
extends RefCounted

static func candidates(executable: String, project_root: String, platform: String, development: bool) -> PackedStringArray:
	var folder := executable.get_base_dir()
	var paths := PackedStringArray([folder.path_join("START_HERE.html")])
	if platform == "macOS" and folder.get_file() == "MacOS":
		# The portable ZIP places the guide beside the .app bundle.
		paths.append(folder.get_base_dir().get_base_dir().get_base_dir().path_join("START_HERE.html"))
	if development:
		paths.append(project_root.path_join("dist/guide-preview/START_HERE.html"))
	return paths

static func find_path() -> String:
	for path in candidates(OS.get_executable_path(), ProjectSettings.globalize_path("res://"), OS.get_name(), OS.has_feature("editor")):
		if FileAccess.file_exists(path):
			return path
	return ""
