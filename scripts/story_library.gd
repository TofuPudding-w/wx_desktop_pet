class_name StoryLibrary
extends RefCounted
const MAX_PROJECTS := 100
const MAX_LINES := 200
const MAX_TEXT := 160
var path := "user://stories/library.json"
var projects: Array = []
var error := ""
var writable := true
var primary_valid := false

static func valid_project(value: Variant) -> bool:
	if value is not Dictionary or value.get("id") is not String or value.id.is_empty() or value.get("title") is not String or value.title.length() > 80:
		return false
	if value.get("lines") is not Array or value.lines.size() > MAX_LINES:
		return false
	for line in value.lines:
		if line is not Dictionary or line.get("speaker") not in ["A", "B"] or line.get("text") is not String:
			return false
		if line.text.length() > MAX_TEXT or line.text.count("\n") > 4:
			return false
		var seconds: Variant = line.get("seconds")
		if (seconds is not float and seconds is not int) or not is_finite(float(seconds)) or seconds < 1 or seconds > 60:
			return false
	return true

static func playable(project: Dictionary) -> String:
	if not valid_project(project):
		return "剧本格式无效。"
	if project.lines.is_empty():
		return "请先添加一句对白。"
	for i in project.lines.size():
		if project.lines[i].text.strip_edges().is_empty():
			return "第 %d 行还没有台词。" % (i + 1)
	return ""

func read_document(file_path: String) -> Variant:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > 2_000_000:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	var document: Variant = parser.data
	if document is not Dictionary or document.get("version") != 1 or document.get("projects") is not Array or document.projects.size() > MAX_PROJECTS:
		return null
	var ids := {}
	for project in document.projects:
		if not valid_project(project) or ids.has(project.id):
			return null
		ids[project.id] = true
	return document

func load_from(file_path: String) -> void:
	path = file_path
	projects = []
	error = ""
	writable = true
	primary_valid = false
	if path.is_empty():
		return
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		return
	var document: Variant = read_document(path)
	primary_valid = document != null
	if document == null:
		document = read_document(path + ".bak")
		if document != null:
			error = "已从上次备份恢复剧本。"
	if document == null:
		writable = false
		error = "剧本文件无法读取，原文件已保留；请备份并修复 library.json 后重启。"
		return
	projects = document.projects

func save() -> bool:
	if not writable:
		return false
	if path.is_empty():
		return true
	if projects.size() > MAX_PROJECTS:
		return false
	for project in projects:
		if not valid_project(project):
			error = "剧本包含无效内容，未覆盖已保存文件。"
			return false
	var serialized := JSON.stringify({"version": 1, "projects": projects}, "  ")
	if serialized.to_utf8_buffer().size() > 2_000_000:
		error = "剧本库超过 2 MB，请删减内容后再保存。"
		return false
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		error = "无法创建剧本目录。"
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "无法写入剧本文件。"
		return false
	file.store_string(serialized)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		error = "剧本写入失败，原文件已保留。"
		return false
	if primary_valid and FileAccess.file_exists(path):
		if DirAccess.copy_absolute(absolute, absolute + ".bak") != OK:
			error = "备份失败，未覆盖原文件。"
			return false
	if DirAccess.rename_absolute(absolute + ".tmp", absolute) != OK:
		error = "保存失败，原文件已保留。"
		return false
	primary_valid = true
	error = ""
	return true

func create(title := "新对白") -> Dictionary:
	if not writable or projects.size() >= MAX_PROJECTS:
		error = "最多保存 %d 个剧本。" % MAX_PROJECTS if writable else error
		return {}
	var project := {"id": Crypto.new().generate_random_bytes(16).hex_encode(), "title": title, "lines": []}
	projects.append(project)
	return project
