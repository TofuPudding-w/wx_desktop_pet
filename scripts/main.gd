extends Node

const PET_SCENE := preload("res://scenes/Pet.tscn")
var pets: Array[Pet] = []
var interaction := InteractionManager.new()
var hug_overlay: HugOverlay
var debug_mode := false
var paused := false
var menu: PanelContainer
var menu_window: Window
var menu_column: VBoxContainer
var menu_pet: Pet
var pause_button: Button
var area := Rect2()
var boundary_elapsed := 0.0
var run_elapsed := 0.0
var quit_after := 0.0
var telemetry_path := ""
var soak := false
var report_elapsed := 0.0
var settings := PetSettings.new()
var settings_path := "user://settings.cfg"
var size_factor := 1.0
var interaction_buttons: Dictionary = {}
var pets_hidden := false
var hiding_icon: HiddenPetIcon
var guide_opener: Callable = OS.shell_open
var guide_locator: Callable = LocalGuide.find_path
var guide_button: Button
var online: Dictionary = {}
var update_checker: UpdateChecker
var update_status: Label
var update_button: Button
var update_panel := false
var alarm_window: AlarmWindow

func _ready() -> void:
	initialize.call_deferred()

func initialize() -> void:
	Engine.max_fps = 30
	var online_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/online.json"))
	if online_data is Dictionary:
		online = online_data
	update_checker = UpdateChecker.new()
	add_child(update_checker)
	update_checker.changed.connect(refresh_update_menu)
	var args := OS.get_cmdline_user_args()
	debug_mode = "--debug-window" in args
	paused = "--paused" in args
	soak = "--soak" in args
	for arg in args:
		if arg.begins_with("--quit-after="):
			quit_after = float(arg.get_slice("=", 1))
		if arg.begins_with("--telemetry="):
			telemetry_path = arg.trim_prefix("--telemetry=")
	if DisplayServer.get_name() == "Wayland" and not debug_mode:
		push_error("桌面模式需要 X11 后端：请使用 ./run.sh，或 --display-driver x11")
		get_tree().quit(1)
		return
	print("PLATFORM ", JSON.stringify(DesktopPlatform.snapshot()))
	area = DesktopWindowController.work_area()
	if "--no-settings" in args:
		settings_path = ""
	settings.load_from(settings_path)
	paused = paused or settings.paused
	size_factor = settings.effective_size(area)
	var loader := ContentLoader.new()
	var configs := loader.characters(loader.read_json("res://data/characters.json", []))
	var dialogue_data: Variant = loader.read_json("res://data/dialogues.json", {})
	var pool := loader.interactions(loader.read_json("res://data/interactions.json", {}), dialogue_data)
	if "--eye-demo" in args and pool.has("natural_approach"):
		pool = {"natural_approach": pool.natural_approach}
	if "--hug-demo" in args and pool.has("hug"):
		pool = {"hug": pool.hug}
	for error in loader.errors:
		push_warning(error)
	# Godot cannot hide its main Window. Keep a transparent, click-through host
	# and use two native child windows so hiding works on every backend.
	var host := get_window()
	host.title = "CP Pet Host"
	host.size = Vector2i.ONE
	host.content_scale_size = Vector2i.ONE
	host.borderless = true
	host.transparent = true
	host.transparent_bg = true
	host.unfocusable = true
	host.mouse_passthrough = true
	host.gui_embed_subwindows = false
	host.close_requested.connect(func(): get_tree().quit())
	var count := 1 if "--single" in args else 2
	for index in range(count):
		var window := Window.new()
		window.visible = false
		add_child(window)
		var desktop := DesktopWindowController.new()
		desktop.configure(window, "CP Pet " + configs[index].id, debug_mode, size_factor)
		window.close_requested.connect(func(): get_tree().quit())
		var pet: Pet = PET_SCENE.instantiate()
		window.add_child(pet)
		pet.configure(configs[index], desktop, initial_position(index))
		pet.facing = 1 if index == 0 else -1
		pet.menu_requested.connect(toggle_menu)
		pet.drag_started.connect(func(_pet): close_menu())
		pet.paused = paused
		pets.append(pet)
		window.show()
	interaction.setup(pets, pool, dialogue_data if dialogue_data is Dictionary else {})
	interaction.automatic_enabled = settings.automatic_interactions
	interaction.paused = paused
	interaction.size_factor = size_factor
	hug_overlay = HugOverlay.new()
	hug_overlay.visible = false
	add_child(hug_overlay)
	hug_overlay.setup(pets, interaction, debug_mode)
	hug_overlay.set_size_factor(size_factor)
	hiding_icon = HiddenPetIcon.new()
	hiding_icon.visible = false
	add_child(hiding_icon)
	hiding_icon.setup()
	hiding_icon.restore_requested.connect(show_pets)
	hiding_icon.exit_requested.connect(func(): get_tree().quit())
	alarm_window = AlarmWindow.new()
	alarm_window.visible = false
	add_child(alarm_window)
	alarm_window.setup(pets[0].font, "" if settings_path.is_empty() else "user://alarm.cfg")
	print("CP Pet ready: backend=%s, pets=%d, work_area=%s" % [DisplayServer.get_name(), pets.size(), area])

func initial_position(index: int) -> Vector2:
	return DesktopWindowController.clamp_foot(Vector2(area.get_center().x + (-110 if index == 0 else 110) * size_factor, area.end.y - 8 * size_factor), area, size_factor)

func _process(delta: float) -> void:
	if pets.is_empty():
		return
	run_elapsed += delta
	if pets_hidden:
		interaction.advance_cooldowns(delta)
		boundary_elapsed += delta
		if boundary_elapsed >= 1:
			boundary_elapsed = 0
			var next := DesktopWindowController.work_area()
			if next != area:
				area = next
				hiding_icon.reposition(area)
		if quit_after > 0 and run_elapsed >= quit_after:
			write_report()
			get_tree().quit()
		return
	refresh_interaction_buttons()
	boundary_elapsed += delta
	if boundary_elapsed >= 1.0:
		boundary_elapsed = 0
		var next := DesktopWindowController.work_area()
		if next != area or delta > 1.0:
			interaction.cancel()
			area = next
			apply_size(settings.requested_size, false)
			for pet in pets:
				pet.foot = DesktopWindowController.clamp_foot(pet.foot, area, size_factor)
				if pet.state != Pet.State.DRAGGED:
					pet.change_state(Pet.State.FALL)
	interaction.step(minf(delta, 0.05), area, delta)
	hug_overlay.sync()
	# Opt-in unattended soak: repeatedly bring idle pets together, without input injection.
	if soak and interaction.phase == InteractionManager.Phase.FREE and pets.size() == 2:
		if pets[0].available() and pets[1].available():
			for index in range(2):
				pets[index].foot = initial_position(index)
				pets[index].change_state(Pet.State.IDLE)
	report_elapsed += delta
	if report_elapsed >= 30:
		report_elapsed = 0
		write_report()
	if quit_after > 0 and run_elapsed >= quit_after:
		write_report()
		get_tree().quit()

func toggle_menu(pet: Pet) -> void:
	if is_instance_valid(menu):
		var same := menu_pet == pet
		close_menu()
		if same:
			return
	interaction.cancel()
	var column := make_menu(pet, 7)
	pause_button = add_menu_button(column, "继续活动" if paused else "暂停活动", toggle_pause)
	add_menu_button(column, "互动  ›", show_interactions)
	add_menu_button(column, "隐藏桌宠", hide_pets)
	add_menu_button(column, "设置  ›", show_settings)
	add_menu_button(column, "工具  ›", show_tools)
	add_menu_button(column, "帮助  ›", show_help)
	var exit_button := add_menu_button(column, "退出桌宠", func(): get_tree().quit())
	exit_button.add_theme_color_override("font_color", Color("985847"))

func add_menu_button(parent: Control, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(256, 32)
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = label
	button.add_theme_font_override("font", pets[0].font)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("253346"))
	button.add_theme_color_override("font_hover_color", Color("30473f"))
	button.add_theme_color_override("font_pressed_color", Color("30473f"))
	button.add_theme_color_override("font_disabled_color", Color("777777"))
	var normal := Pet.rounded(Color(0, 0, 0, 0), 6)
	normal.content_margin_left = 12
	normal.content_margin_right = 28
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("e6eee3")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", normal)
	if "›" in label:
		button.text = label.replace("  ›", "").replace(" ›", "")
		var arrow := Label.new()
		arrow.text = "›"
		arrow.add_theme_color_override("font_color", Color("7e8e80"))
		arrow.position = Vector2(234, 3)
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(arrow)
	if "返回" in label or "退出" in label:
		normal = normal.duplicate()
		normal.bg_color = Color("f0f2eb")
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_font_size_override("font_size", 13)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func close_menu() -> void:
	update_panel = false
	interaction_buttons.clear()
	if is_instance_valid(menu_window):
		menu_window.hide()
		menu_window.queue_free()
	elif is_instance_valid(menu):
		menu.queue_free()
	menu_window = null
	menu = null
	if is_instance_valid(menu_pet):
		menu_pet.menu_open = false
		menu_pet.controller.menu_rect = DesktopWindowController.MENU
		menu_pet.controller.update_input(not menu_pet.bubble.is_empty())
	menu_pet = null

func toggle_pause() -> void:
	paused = not paused
	interaction.cancel()
	interaction.paused = paused
	for pet in pets:
		pet.paused = paused
		if pet.state == Pet.State.WALK:
			pet.change_state(Pet.State.IDLE)
	close_menu()
	settings.paused = paused
	save_settings()

func reset_positions() -> void:
	interaction.cancel()
	close_menu()
	for index in range(pets.size()):
		pets[index].foot = initial_position(index)
		pets[index].change_state(Pet.State.IDLE)

func write_report() -> void:
	if telemetry_path.is_empty():
		return
	var states := []
	for pet in pets:
		states.append({"id":pet.character_id, "state":Pet.State.keys()[pet.state],
			"x":pet.foot.x, "y":pet.foot.y, "state_seconds":pet.state_time,
			"paused":pet.paused, "menu_open":pet.menu_open, "available":pet.available(),
			"input_button_events":pet.input_button_events, "art":pet.art_key, "facing":pet.facing})
	var report := {"elapsed_seconds":run_elapsed, "completed":interaction.completed,
		"cancelled":interaction.cancelled, "phase":InteractionManager.Phase.keys()[interaction.phase],
		"pets":states, "paused":paused, "hidden":pets_hidden, "automatic_interactions":settings.automatic_interactions, "menu_open":is_instance_valid(menu),
		"memory_bytes":OS.get_static_memory_usage()}
	var file := FileAccess.open(telemetry_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))

func show_size_settings() -> void:
	var pet := menu_pet
	var column := make_menu(pet, 6, "角色大小", "Character Size")
	for value in PetSettings.SIZES:
		var label := ("✓ " if is_equal_approx(value, settings.requested_size) else "") + "%d%%" % roundi(value * 100)
		add_menu_button(column, label, func(): apply_size(value))
	add_menu_button(column, "返回", show_settings)
	pet.controller.update_input(true)

func apply_size(value: float, persist := true) -> void:
	if value not in PetSettings.SIZES:
		return
	interaction.cancel()
	hug_overlay.stop()
	close_menu()
	var previous := size_factor
	settings.requested_size = value
	size_factor = settings.effective_size(area)
	interaction.size_factor = size_factor
	hug_overlay.set_size_factor(size_factor)
	var center := 0.0
	for pet in pets:
		center += pet.foot.x / pets.size()
	for pet in pets:
		pet.foot = DesktopWindowController.clamp_foot(Vector2(center + (pet.foot.x - center) * size_factor / previous, area.end.y - 8 * size_factor), area, size_factor)
		pet.change_state(Pet.State.IDLE)
		pet.set_size_factor(size_factor)
	if persist:
		save_settings()

func make_menu(pet: Pet, rows: int, title := "忘羡桌宠", subtitle := "WangXian Desktop Pet") -> VBoxContainer:
	close_menu()
	menu_pet = pet
	pet.stop_drag()
	pet.menu_open = true
	pet.controller.menu_rect = Rect2(22, 8, 276, rows * 34 + 64)
	menu = PanelContainer.new()
	menu.position = Vector2.ZERO
	menu.size = pet.controller.menu_rect.size
	var panel_style := Pet.rounded(Color("faf9f4"), 14)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color("dce2d8")
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	menu.add_theme_stylebox_override("panel", panel_style)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 8)
	menu.add_child(shell)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 38
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(header)
	header.draw.connect(func(): header.draw_line(Vector2(0, 42), Vector2(256, 42), Color("e2e7dd"), 1))
	var headings := VBoxContainer.new()
	headings.add_theme_constant_override("separation", 0)
	var header_inset := MarginContainer.new()
	header_inset.add_theme_constant_override("margin_left", 12)
	header_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(header_inset)
	header_inset.add_child(headings)
	for item in [[title, 15, "30473f"], [subtitle, 11, "7d897f"]]:
		var heading := Label.new()
		heading.text = item[0]
		heading.add_theme_font_override("font", pets[0].font)
		heading.add_theme_font_size_override("font_size", item[1])
		heading.add_theme_color_override("font_color", Color(item[2]))
		headings.add_child(heading)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	shell.add_child(column)
	menu_column = column
	# A separate menu surface stacks above either pet without remapping
	# character windows (which destroys their native surface and flashes).
	menu_window = Window.new()
	menu_window.visible = false
	menu_window.title = "CP Pet Menu"
	menu_window.borderless = true
	menu_window.transparent = true
	menu_window.transparent_bg = true
	menu_window.always_on_top = true
	menu_window.unfocusable = true
	menu_window.unresizable = true
	menu_window.gui_embed_subwindows = false
	menu_window.size = Vector2i((menu.size * size_factor).ceil())
	menu_window.content_scale_size = menu_window.size
	menu_window.position = pet.controller.window.position + Vector2i(pet.controller.menu_rect.position * size_factor)
	menu.scale = Vector2.ONE * size_factor
	add_child(menu_window)
	menu_window.add_child(menu)
	menu_window.close_requested.connect(close_menu)
	# The separate window receives menu clicks; the pet keeps its art-only
	# input region, allowing surrounding transparent desktop space through.
	pet.controller.update_input(not pet.bubble.is_empty())
	show_menu_window.call_deferred(menu_window)
	return column

func show_menu_window(expected: Window) -> void:
	# Let containers finish layout before the first visible frame.
	await get_tree().process_frame
	if is_instance_valid(expected) and expected == menu_window:
		expected.show()

func show_settings() -> void:
	var pet := menu_pet
	var column := make_menu(pet, 5, "设置", "Settings")
	add_menu_button(column, "角色大小 · %d%%  ›" % roundi(settings.requested_size * 100), show_size_settings)
	add_menu_button(column, "自动互动：" + ("开" if settings.automatic_interactions else "关"), toggle_automatic)
	add_menu_button(column, "重置位置", reset_positions)
	add_menu_button(column, "检查更新  ›", show_updates)
	add_menu_button(column, "‹  返回主菜单", func(): close_menu(); toggle_menu(pet))

func toggle_automatic() -> void:
	settings.automatic_interactions = not settings.automatic_interactions
	interaction.automatic_enabled = settings.automatic_interactions
	save_settings()
	show_settings()

func save_settings() -> void:
	if settings.save_to(settings_path) != OK:
		push_warning("无法保存桌宠设置。")

func show_interactions() -> void:
	var pet := menu_pet
	var column := make_menu(pet, 3, "双人互动", "Pair Interactions")
	for id in ["natural_approach", "hug"]:
		interaction_buttons[id] = add_menu_button(column, "", func(): select_interaction(id))
	add_menu_button(column, "返回", func(): close_menu(); toggle_menu(pet))
	refresh_interaction_buttons()

func refresh_interaction_buttons() -> void:
	for id in interaction_buttons:
		var button: Button = interaction_buttons[id]
		var reason := interaction.request_reason(id, area, true)
		button.disabled = not reason.is_empty()
		button.text = ("对视" if id == "natural_approach" else "拥抱") + (" · " + reason if not reason.is_empty() else "")

func select_interaction(id: String) -> void:
	var pet := menu_pet
	close_menu()
	if not interaction.request(id, area) and is_instance_valid(pet):
		menu_pet = pet
		show_interactions()

func hide_pets() -> void:
	if pets_hidden:
		return
	interaction.cancel()
	hug_overlay.stop()
	close_menu()
	pets_hidden = true
	interaction.paused = true
	for pet in pets:
		pet.change_state(Pet.State.IDLE)
		pet.set_process(false)
		pet.controller.window.hide()
	hiding_icon.open_at(DesktopWindowController.work_area())

func show_pets() -> void:
	if not pets_hidden:
		return
	pets_hidden = false
	hiding_icon.dismiss()
	area = DesktopWindowController.work_area()
	apply_size(settings.requested_size, false)
	interaction.paused = paused
	for pet in pets:
		pet.paused = paused
		pet.set_process(true)
		pet.controller.window.show()

func show_help() -> void:
	var pet := menu_pet
	var column := make_menu(pet, 4, "帮助", "Help")
	add_menu_button(column, "使用指南  ›", show_guides)
	add_online_button(column, "访问网站 ↗", "downloads_url")
	add_menu_button(column, "联系与反馈  ›", show_feedback)
	add_menu_button(column, "‹  返回主菜单", func(): close_menu(); toggle_menu(pet))

func show_guides() -> void:
	var column := make_menu(menu_pet, 3, "使用指南", "User Guide")
	guide_button = add_menu_button(column, "离线指南", open_guide)
	add_online_button(column, "在线指南 ↗", "guide_url")
	add_menu_button(column, "‹  返回帮助", show_help)

func open_guide() -> void:
	var path: String = guide_locator.call()
	if path.is_empty():
		if is_instance_valid(guide_button):
			guide_button.text = "指南缺失，请点下方在线指南" if UpdateChecker.https_url(online.get("guide_url", "")) else "指南缺失，请完整解压"
		return
	var result: int = guide_opener.call(path)
	if result == OK:
		close_menu()
	elif is_instance_valid(guide_button):
		guide_button.text = "未能打开，请直接打开 HTML"
		guide_button.tooltip_text = path

func add_online_button(column: Control, title: String, key: String) -> void:
	var button := add_menu_button(column, title, func(): open_online(key))
	button.disabled = not UpdateChecker.https_url(online.get(key, ""))
	if button.disabled:
		button.text = title.trim_suffix("（联网）") + "（尚未配置）"

func open_online(key: String) -> void:
	var url: Variant = online.get(key, "")
	if UpdateChecker.https_url(url):
		if guide_opener.call(url) == OK:
			close_menu()
		else:
			var column := make_menu(menu_pet, 3)
			var label := add_menu_button(column, "无法打开浏览器，请手动访问", func(): pass)
			label.tooltip_text = url
			add_menu_button(column, "返回帮助", show_help)

func show_updates() -> void:
	var pet := menu_pet
	var column := make_menu(pet, 6, "检查更新", "Check for Updates")
	update_panel = true
	update_status = Label.new()
	update_status.custom_minimum_size = Vector2(256, 84)
	update_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	update_status.add_theme_font_override("font", pets[0].font)
	update_status.add_theme_font_size_override("font_size", 15)
	update_status.add_theme_color_override("font_color", Color("253346"))
	column.add_child(update_status)
	update_button = add_menu_button(column, "检查更新（需要联网）", check_updates)
	add_online_button(column, "前往下载页面", "downloads_url")
	add_menu_button(column, "‹  返回设置", show_settings)
	refresh_update_menu()

func check_updates() -> void:
	var endpoints: Variant = online.get("update_endpoints", [])
	update_checker.start(endpoints if endpoints is Array else [], str(ProjectSettings.get_setting("application/config/version", "")))

func refresh_update_menu() -> void:
	if update_panel and is_instance_valid(update_status):
		update_status.text = "当前版本：%s\n%s" % [ProjectSettings.get_setting("application/config/version", ""), update_checker.message]
		update_button.disabled = update_checker.busy

func show_feedback() -> void:
	var pet := menu_pet
	var column := make_menu(pet, 4, "联系与反馈", "Contact & Feedback")
	var address := str(online.get("feedback_email", ""))
	var label := add_menu_button(column, address if not address.is_empty() else "邮箱尚未配置", func(): pass)
	label.tooltip_text = "请附版本、系统、复现步骤；截图请遮挡个人信息。"
	var button := add_menu_button(column, "使用邮件应用写反馈", func():
		var target := "mailto:" + address + "?subject=" + "忘羡桌宠反馈".uri_encode()
		if guide_opener.call(target) == OK:
			close_menu()
		else:
			label.text = "无法打开邮件应用，请手动发邮件"
			label.tooltip_text = address)
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")
	button.disabled = regex.search(address) == null
	add_menu_button(column, "复制邮箱", func(): DisplayServer.clipboard_set(address))
	add_menu_button(column, "返回", show_help)

func show_tools() -> void:
	var pet := menu_pet
	var column := make_menu(pet, 2, "工具", "Tools")
	add_menu_button(column, "每日闹钟", func(): close_menu(); alarm_window.open())
	add_menu_button(column, "‹  返回主菜单", func(): close_menu(); toggle_menu(pet))
