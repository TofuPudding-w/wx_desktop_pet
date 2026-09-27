extends Node

const PET_SCENE := preload("res://scenes/Pet.tscn")
var pets: Array[Pet] = []
var interaction := InteractionManager.new()
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
	area = DesktopWindowController.work_area()
	var loader := ContentLoader.new()
	var configs := loader.characters(loader.read_json("res://data/characters.json", []))
	var dialogue_data: Variant = loader.read_json("res://data/dialogues.json", {})
	var pool := loader.interactions(loader.read_json("res://data/interactions.json", {}), dialogue_data)
	for error in loader.errors:
		push_warning(error)
	var count := 1 if "--single" in args else 2
	for index in range(count):
		var window := get_window() if index == 0 else Window.new()
		if index > 0:
			window.visible = false
			add_child(window)
		var desktop := DesktopWindowController.new()
		desktop.configure(window, "CP Pet " + configs[index].id, debug_mode)
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
	interaction.paused = paused
	print("CP Pet ready: backend=%s, pets=%d, work_area=%s" % [DisplayServer.get_name(), pets.size(), area])

func initial_position(index: int) -> Vector2:
	return DesktopWindowController.clamp_foot(Vector2(area.get_center().x + (-75 if index == 0 else 75), area.end.y - 8), area)

func _process(delta: float) -> void:
	if pets.is_empty():
		return
	run_elapsed += delta
	boundary_elapsed += delta
	if boundary_elapsed >= 1.0:
		boundary_elapsed = 0
		var next := DesktopWindowController.work_area()
		if next != area or delta > 1.0:
			interaction.cancel()
			area = next
			for pet in pets:
				pet.foot = DesktopWindowController.clamp_foot(pet.foot, area)
				if pet.state != Pet.State.DRAGGED:
					pet.change_state(Pet.State.FALL)
	interaction.step(minf(delta, 0.05), area)
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
	menu_pet = pet
	pet.stop_drag()
	pet.menu_open = true
	pet.controller.update_input(true)
	menu = PanelContainer.new()
	menu.position = Vector2(10, 8)
	menu.size = Vector2(220, 94)
	menu.add_theme_stylebox_override("panel", Pet.rounded(Color("fffaf0"), 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	menu.add_child(column)
	pet.add_child(menu)
	pause_button = add_menu_button(column, "继续活动" if paused else "暂停活动", toggle_pause)
	add_menu_button(column, "回到桌面中央", reset_positions)
	add_menu_button(column, "退出桌宠", func(): get_tree().quit())

func add_menu_button(parent: Control, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(220, 28)
	button.add_theme_font_override("font", pets[0].font)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("253346"))
	button.add_theme_stylebox_override("normal", Pet.rounded(Color("fffaf0"), 8))
	button.add_theme_stylebox_override("hover", Pet.rounded(Color("e4eef2"), 8))
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func close_menu() -> void:
	if is_instance_valid(menu):
		menu.queue_free()
	menu = null
	if is_instance_valid(menu_pet):
		menu_pet.menu_open = false
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
			"input_button_events":pet.input_button_events})
	var report := {"elapsed_seconds":run_elapsed, "completed":interaction.completed,
		"cancelled":interaction.cancelled, "phase":InteractionManager.Phase.keys()[interaction.phase],
		"pets":states, "paused":paused, "menu_open":is_instance_valid(menu),
		"memory_bytes":OS.get_static_memory_usage()}
	var file := FileAccess.open(telemetry_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
