class_name StoryEditor
extends Window
var library := StoryLibrary.new()
var player: StoryPlayer
var project_index := -1
var line_index := -1
var updating := false
var dirty := false
var project_picker: OptionButton
var title_edit: LineEdit
var line_list: ItemList
var speaker: OptionButton
var duration: SpinBox
var body: TextEdit
var count_label: Label
var message: Label
var playback_status: Label
var play_button: Button
var pause_button: Button
var stop_button: Button
var autosave: Timer
var deletion: ConfirmationDialog

func setup(font: Font, playback: StoryPlayer, path: String, palette: PetSettings) -> void:
	player = playback
	library.load_from(path)
	title = "气泡对白 · Bubble Dialogue"
	min_size = Vector2i(660, 420)
	size = Vector2i(860, 600)
	gui_embed_subwindows = false
	var ui := Theme.new()
	ui.default_font = font
	ui.default_font_size = 16
	for type in ["Label", "Button", "OptionButton", "LineEdit", "TextEdit", "ItemList", "PopupMenu", "SpinBox"]:
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "caret_color", "font_outline_color"]:
			ui.set_color(key, type, palette.menu_text)
		ui.set_color("font_selected_color", type, palette.menu_text if type in ["ItemList", "PopupMenu"] else palette.menu_background)
		ui.set_color("selection_color", type, palette.menu_text)
		for state in ["normal", "hover", "pressed", "read_only", "panel", "bg", "selected", "selected_focus"]:
			var style := Pet.rounded(palette.menu_color("hover" if state in ["hover", "pressed", "selected", "selected_focus"] else "subtle"), 5)
			style.set_content_margin_all(6)
			ui.set_stylebox(state, type, style)
	theme = ui
	var surface := PanelContainer.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := Pet.rounded(palette.menu_background, 0)
	panel.set_content_margin_all(16)
	surface.add_theme_stylebox_override("panel", panel)
	add_child(surface)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	surface.add_child(column)
	var projects := HBoxContainer.new()
	column.add_child(projects)
	project_picker = OptionButton.new()
	project_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	project_picker.item_selected.connect(select_project)
	projects.add_child(project_picker)
	button(projects, "新建", new_project)
	button(projects, "复制", duplicate_project)
	button(projects, "删除剧本", func():
		if project_index >= 0:
			deletion.dialog_text = "删除「%s」？" % current().title
			deletion.popup_centered())
	title_edit = LineEdit.new()
	title_edit.placeholder_text = "剧本名称"
	title_edit.max_length = 80
	title_edit.text_changed.connect(func(value):
		if not updating and project_index >= 0:
			current().title = value
			mark_dirty())
	column.add_child(title_edit)
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	column.add_child(content)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 230
	content.add_child(left)
	line_list = ItemList.new()
	line_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line_list.item_selected.connect(select_line)
	left.add_child(line_list)
	var rows := HBoxContainer.new()
	left.add_child(rows)
	button(rows, "＋", add_line)
	button(rows, "－", remove_line)
	button(rows, "↑", func(): move_line(-1))
	button(rows, "↓", func(): move_line(1))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(right)
	var options := HBoxContainer.new()
	right.add_child(options)
	speaker = OptionButton.new()
	speaker.add_item("魏无羡")
	speaker.add_item("蓝忘机")
	speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker.item_selected.connect(func(_index): edit_line())
	options.add_child(speaker)
	duration = SpinBox.new()
	duration.custom_minimum_size.x = 115
	duration.min_value = 1
	duration.max_value = 60
	duration.step = 0.5
	duration.suffix = "秒"
	duration.value = 4
	duration.value_changed.connect(func(_value): edit_line())
	options.add_child(duration)
	body = TextEdit.new()
	body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	body.placeholder_text = "输入这一句对白……"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.text_changed.connect(edit_line)
	right.add_child(body)
	count_label = Label.new()
	count_label.add_theme_font_size_override("font_size", 13)
	right.add_child(count_label)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	button(actions, "保存", save_current)
	play_button = button(actions, "播放", play)
	pause_button = button(actions, "暂停", player.toggle_pause)
	stop_button = button(actions, "停止", player.stop)
	playback_status = Label.new()
	playback_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(playback_status)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.y = 44
	message.add_theme_font_size_override("font_size", 13)
	column.add_child(message)
	autosave = Timer.new()
	autosave.one_shot = true
	autosave.wait_time = 0.8
	autosave.timeout.connect(save_current)
	add_child(autosave)
	deletion = ConfirmationDialog.new()
	deletion.title = "删除剧本"
	deletion.ok_button_text = "删除"
	deletion.cancel_button_text = "取消"
	deletion.confirmed.connect(delete_project)
	add_child(deletion)
	close_requested.connect(func():
		if save_current(): hide())
	tree_exiting.connect(save_current)
	player.changed.connect(refresh_playback)
	if library.projects.is_empty() and library.writable:
		library.create()
	refresh_projects()
	if not library.projects.is_empty():
		load_project(0)
	else:
		select_line(-1)
	message.text = library.error if not library.error.is_empty() else "编辑会自动保存。每句最多 160 字、4 个换行。收起窗口后仍可播放。"
	refresh_playback()

func button(parent: Control, text: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 34
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

func current() -> Dictionary:
	return library.projects[project_index] if project_index >= 0 else {}

func refresh_projects() -> void:
	project_picker.clear()
	for project in library.projects:
		project_picker.add_item(project.title if not project.title.strip_edges().is_empty() else "未命名对白")
	if project_index >= 0 and project_index < library.projects.size():
		project_picker.select(project_index)

func select_project(index: int) -> void:
	if not save_current():
		project_picker.select(project_index)
		return
	load_project(index)

func load_project(index: int) -> void:
	project_index = index
	project_picker.select(index)
	updating = true
	title_edit.text = current().title
	updating = false
	refresh_lines()
	select_line(0 if not current().lines.is_empty() else -1)
	dirty = false

func line_caption(index: int) -> String:
	var line: Dictionary = current().lines[index]
	return "%d · %s：%s" % [index + 1, "魏" if line.speaker == "A" else "蓝", line.text.replace("\n", " ").left(20)]

func refresh_lines() -> void:
	line_list.clear()
	for i in current().get("lines", []).size():
		line_list.add_item(line_caption(i))

func select_line(index: int) -> void:
	line_index = index
	updating = true
	var valid: bool = index >= 0 and index < current().get("lines", []).size()
	speaker.disabled = not valid
	duration.editable = valid
	body.editable = valid
	body.text = current().lines[index].text if valid else ""
	if valid:
		line_list.select(index)
		speaker.select(0 if current().lines[index].speaker == "A" else 1)
		duration.value = current().lines[index].seconds
	count_label.text = "%d / 160 字 · 最多 4 个换行" % body.text.length()
	updating = false

func edit_line() -> void:
	if updating or project_index < 0 or line_index < 0:
		return
	current().lines[line_index] = {"speaker": "A" if speaker.selected == 0 else "B", "text": body.text, "seconds": duration.value}
	line_list.set_item_text(line_index, line_caption(line_index))
	count_label.text = "%d / 160 字 · 最多 4 个换行" % body.text.length()
	mark_dirty()

func mark_dirty() -> void:
	dirty = true
	autosave.start()
	message.text = "有修改，正在等待自动保存……"

func save_current() -> bool:
	if not library.writable:
		message.text = library.error
		return false
	for project in library.projects:
		if not StoryLibrary.valid_project(project):
			message.text = "未保存：请把长句拆开，每句最多 160 字、4 个换行。"
			return false
	if dirty and not library.save():
		message.text = library.error
		return false
	dirty = false
	autosave.stop()
	refresh_projects()
	message.text = "已保存。播放使用开始时的内容；修改后可重新播放。"
	return true

func new_project() -> void:
	if not save_current(): return
	if library.create().is_empty():
		message.text = library.error
		return
	refresh_projects()
	load_project(library.projects.size() - 1)
	mark_dirty()

func duplicate_project() -> void:
	if project_index < 0 or not save_current(): return
	var original := current().duplicate(true)
	var copy := library.create(original.title.left(76) + " 副本")
	if copy.is_empty():
		message.text = library.error
		return
	copy.lines = original.lines.duplicate(true)
	refresh_projects()
	load_project(library.projects.size() - 1)
	mark_dirty()

func delete_project() -> void:
	if project_index < 0 or not library.writable: return
	player.stop("删除剧本，播放已停止")
	library.projects.remove_at(project_index)
	if library.projects.is_empty(): library.create()
	project_index = 0
	refresh_projects()
	load_project(0)
	mark_dirty()
	save_current()

func add_line() -> void:
	if project_index < 0: return
	if current().lines.size() >= StoryLibrary.MAX_LINES:
		message.text = "每个剧本最多 200 句。"
		return
	current().lines.append({"speaker": "A" if current().lines.size() % 2 == 0 else "B", "text": "", "seconds": 4.0})
	refresh_lines()
	select_line(current().lines.size() - 1)
	mark_dirty()

func remove_line() -> void:
	if line_index < 0: return
	current().lines.remove_at(line_index)
	refresh_lines()
	select_line(mini(line_index, current().lines.size() - 1))
	mark_dirty()

func move_line(direction: int) -> void:
	var target := line_index + direction
	if line_index < 0 or target < 0 or target >= current().lines.size(): return
	var line: Dictionary = current().lines.pop_at(line_index)
	current().lines.insert(target, line)
	refresh_lines()
	select_line(target)
	mark_dirty()

func play() -> void:
	duration.apply()
	if not save_current(): return
	if project_index < 0: return
	var result := player.start(current())
	message.text = result if not result.is_empty() else "收起窗口后仍可播放；可从工具菜单重新打开。拖动或隐藏角色会停止播放。"

func refresh_playback() -> void:
	pause_button.disabled = not player.active
	stop_button.disabled = not player.active
	pause_button.text = "继续" if player.paused else "暂停"
	play_button.text = "重新播放" if player.active else "播放"
	playback_status.text = player.status

func open() -> void:
	var area := DesktopWindowController.work_area()
	size = Vector2i(Vector2(860, 600).min(area.size - Vector2(24, 24)))
	position = Vector2i(area.get_center()) - size / 2
	show()
	grab_focus()
