class_name ContentLoader
extends RefCounted

var errors: Array[String] = []

func read_json(path: String, fallback: Variant) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("无法读取 " + path)
		return fallback
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		errors.append("JSON 格式错误 %s:%d %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return fallback
	return parser.data

func characters(raw: Variant) -> Array[Dictionary]:
	var defaults: Array[Dictionary] = [
		{"id":"A", "name":"蓝蓝", "color":"79b8ed", "walk_speed":80.0},
		{"id":"B", "name":"橙橙", "color":"f5b47b", "walk_speed":65.0}]
	if not raw is Array or raw.size() != 2:
		errors.append("characters: 需要两个角色，已使用默认角色")
		return defaults
	for index in range(2):
		var item: Variant = raw[index]
		if not item is Dictionary or item.get("id") != defaults[index].id:
			errors.append("characters: 角色顺序必须为 A、B，已使用默认角色")
			return defaults
		if not item.get("name") is String or str(item.name).is_empty() or not item.get("color") is String:
			errors.append("characters: 名称或颜色无效，已使用默认角色")
			return defaults
		if not Color.html_is_valid(item.color) or not positive(item.get("walk_speed")):
			errors.append("characters: 颜色或速度无效，已使用默认角色")
			return defaults
	return [raw[0], raw[1]]

func interactions(raw: Variant, text: Variant) -> Dictionary:
	var valid := {}
	if not raw is Dictionary or not text is Dictionary:
		errors.append("interactions/dialogues: 顶层必须是对象，互动已禁用")
		return valid
	for id in raw:
		var item: Variant = raw[id]
		var okay := item is Dictionary
		if okay:
			for field in ["weight", "trigger_distance", "spacing", "cooldown", "duration", "approach_timeout"]:
				if not positive(item.get(field)):
					okay = false
		if okay:
			okay = item.get("dialogue") is String and text.has(item.dialogue)
		if okay:
			var lines: Variant = text[item.dialogue]
			okay = lines is Array and not lines.is_empty()
			if okay:
				for line in lines:
					if not line is Dictionary or line.get("speaker") not in ["A", "B"]:
						okay = false
						break
					if not line.get("text") is String or str(line.text).is_empty() or str(line.text).length() > 11:
						okay = false
						break
		if okay:
			valid[id] = item
		else:
			errors.append("interaction '%s': 参数或对白无效，该互动已禁用（每句最多 11 字）" % id)
	return valid

static func positive(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) > 0
