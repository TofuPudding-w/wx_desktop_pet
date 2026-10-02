extends Node

const PET_SCENE := preload("res://scenes/Pet.tscn")
var pets: Array[Pet] = []
var interaction := InteractionManager.new()
var hug_overlay: HugOverlay
var debug_mode := false
var paused := false
var menu: PanelContainer
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

func _ready() -> void:
	initialize.call_deferred()

func initialize() -> void:
	Engine.max_fps = 30
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
	add_menu_button(column, "回到桌面中央", reset_positions)
	add_menu_button(column, "设置", show_settings)
	add_menu_button(column, "互动", show_interactions)
	add_menu_button(column, "隐藏桌宠", hide_pets)
	add_menu_button(column, "帮助", show_help)
	add_menu_button(column, "退出桌宠", func(): get_tree().quit())

func add_menu_button(parent: Control, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(260, 28)
	button.add_theme_font_override("font", pets[0].font)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("253346"))
	button.add_theme_color_override("font_disabled_color", Color("777777"))
	button.add_theme_stylebox_override("normal", Pet.rounded(Color("fffaf0"), 8))
	button.add_theme_stylebox_override("hover", Pet.rounded(Color("e4eef2"), 8))
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func close_menu() -> void:
	interaction_buttons.clear()
	if is_instance_valid(menu):
		menu.queue_free()
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
	var column := make_menu(pet, 6)
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

func make_menu(pet: Pet, rows: int) -> VBoxContainer:
	close_menu()
	menu_pet = pet
	pet.stop_drag()
	pet.menu_open = true
	pet.controller.menu_rect = Rect2(30, 8, 260, rows * 28 + 8)
	menu = PanelContainer.new()
	menu.position = pet.controller.menu_rect.position
	menu.size = pet.controller.menu_rect.size
	menu.add_theme_stylebox_override("panel", Pet.rounded(Color("fffaf0"), 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	menu.add_child(column)
	pet.add_child(menu)
	pet.controller.update_input(true)
	return column

func show_settings() -> void:
	var pet := menu_pet
	var column := make_menu(pet, 3)
	add_menu_button(column, "角色大小 · %d%%" % roundi(settings.requested_size * 100), show_size_settings)
	add_menu_button(column, "自动互动：" + ("开" if settings.automatic_interactions else "关"), toggle_automatic)
	add_menu_button(column, "返回", func(): close_menu(); toggle_menu(pet))

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
	var column := make_menu(pet, 3)
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
	var column := make_menu(pet, 2)
	guide_button = add_menu_button(column, "使用指南（离线）", open_guide)
	add_menu_button(column, "返回", func(): close_menu(); toggle_menu(pet))

func open_guide() -> void:
	var path: String = guide_locator.call()
	if path.is_empty():
		if is_instance_valid(guide_button):
			guide_button.text = "指南缺失，请完整解压"
		return
	var result: int = guide_opener.call(path)
	if result == OK:
		close_menu()
	elif is_instance_valid(guide_button):
		guide_button.text = "未能打开，请直接打开 HTML"
		guide_button.tooltip_text = path
