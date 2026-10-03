extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var app = load("res://scenes/Main.tscn").instantiate()
	app.settings_path = ""
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	for pet in app.pets:
		pet.set_process(false)
	app.interaction.cancel()
	app.interaction.automatic_enabled = false
	app.reset_positions()
	app.interaction.cooldowns.clear()
	app.interaction.rest_remaining = 0
	app.interaction.step(0.1, app.area)
	check(app.interaction.phase == InteractionManager.Phase.FREE, "automatic off suppresses encounter")
	app.toggle_menu(app.pets[0])
	app.show_interactions()
	check(not app.interaction_buttons.hug.disabled, "eligible manual hug enabled even with auto off")
	app.interaction_buttons.hug.pressed.emit()
	check(app.interaction.phase == InteractionManager.Phase.APPROACHING and app.interaction.current.id == "hug", "button selects hug")
	check(not app.interaction.request("natural_approach", app.area), "second request cannot replace reserved pair")
	app.interaction.cancel()
	check(not app.interaction.request("hug", app.area), "manual respects cooldown")
	app.toggle_menu(app.pets[1])
	app.show_interactions()
	check(app.interaction_buttons.hug.disabled and "冷却" in app.interaction_buttons.hug.text, "cooldown reason visible")
	app.interaction.step(31, app.area)
	app.refresh_interaction_buttons()
	check(not app.interaction_buttons.hug.disabled, "menu enables after cooldown without reopening")
	app.interaction_buttons.natural_approach.pressed.emit()
	check(app.interaction.current.id == "natural_approach", "button selects eye contact")
	app.pets[1].start_drag(app.pets[1].foot)
	check(app.interaction.phase == InteractionManager.Phase.FREE, "manual interaction cancellable by dragging")
	check(not app.interaction.request("hug", app.area), "cannot request while dragging")
	app.reset_positions()
	app.interaction.cooldowns.clear()
	app.interaction.rest_remaining = 0
	app.pets[0].foot.x = app.pets[1].foot.x + 50
	check("魏左蓝右" in app.interaction.request_reason("hug", app.area), "wrong arrangement explained")
	app.reset_positions()
	app.pets[0].foot.x -= 200
	check("拖近" in app.interaction.request_reason("hug", app.area), "distance explained")
	app.reset_positions()
	app.toggle_pause()
	check(not app.interaction.request("hug", app.area), "paused cannot manually start")
	app.hide_pets()
	check(app.hiding_icon.visible, "restore icon appears")
	check(app.hiding_icon.get_child(0).size == Vector2(64, 64), "icon texture is displayed at 64px rather than source canvas size")
	check(not app.pets[0].controller.window.visible and not app.pets[1].controller.window.visible, "hide removes both windows")
	check(app.paused and app.interaction.paused, "hidden state preserves user pause")
	app._process(3600)
	check(app.pets_hidden, "hidden indefinitely, even after an hour")
	app.hiding_icon.show_menu()
	app.hiding_icon.menu.get_child(0).get_child(0).pressed.emit()
	check(not app.pets_hidden and app.pets[0].controller.window.visible and app.pets[1].controller.window.visible, "icon menu restores both")
	check(app.paused and app.pets[0].paused, "restoration preserves pause")
	app.toggle_pause()
	app.interaction.cooldowns.clear()
	app.interaction.rest_remaining = 0
	app.interaction.request("hug", app.area)
	app.pets[0].foot.x = app.pets[0].target_x
	app.interaction.step(0.01, app.area)
	app.hug_overlay.sync()
	app.hide_pets()
	check(not app.hug_overlay.visible and app.interaction.phase == InteractionManager.Phase.FREE, "hiding active hug clears combined window and lock")
	app.show_pets()
	check(not app.paused and not app.interaction.paused and app.pets[0].art_sprite.visible, "manual restoration resumes normally")
	check(not app.hiding_icon.visible, "restore icon disappears after restoring")
	check(app.hiding_icon.icon_hit(app.hiding_icon.icon_rect.get_center()), "opaque icon receives input")
	check(not app.hiding_icon.icon_hit(app.hiding_icon.icon_rect.position), "transparent icon corner ignored")
	app.hiding_icon.reposition(Rect2(0, 0, 800, 600))
	check(Rect2(Vector2.ZERO, Vector2(800, 600)).encloses(Rect2(Vector2(app.hiding_icon.position), Vector2(app.hiding_icon.size))), "restore control stays within display")
	var icon: HiddenPetIcon = app.hiding_icon
	var screen := Rect2(-800, 40, 800, 600)
	icon.reposition(screen)
	icon.show()
	for corner in [screen.position, Vector2(screen.end.x, screen.position.y), screen.end, Vector2(screen.position.x, screen.end.y), screen.get_center()]:
		icon.show_menu()
		var offset := Vector2(20, 24) * icon.ui_scale
		icon.begin_icon_drag(icon.icon_position + offset)
		check(icon.dragging and icon.menu == null, "drag closes icon menu")
		icon.drag_to(corner + offset, screen)
		check(Rect2(screen.position, screen.size).encloses(Rect2(icon.icon_position, icon.icon_rect.size * icon.ui_scale)), "icon remains visible at each edge")
		icon.stop_drag()
		icon.show_menu()
		check(Rect2(Vector2.ZERO, Vector2(232, 152)).encloses(icon.menu_rect), "restore menu remains reachable at each edge")
		await process_frame
		await process_frame
		var rendered_menu := Rect2(icon.menu.position, icon.menu.size)
		check(icon.menu_rect.encloses(rendered_menu), "rendered menu fits declared clickable area after layout")
		check(Rect2(Vector2.ZERO, Vector2(232, 152)).encloses(rendered_menu), "rendered menu border is not clipped by window at screen edges")
		check(icon.icon_hit(icon.icon_rect.get_center()), "hit testing follows relocated icon")
	var remembered := icon.icon_position
	icon.dismiss()
	icon.open_at(screen)
	check(icon.icon_position == remembered and not icon.dragging, "icon position survives hide/show within session")
	icon.begin_icon_drag(icon.icon_position)
	icon.dismiss()
	check(not icon.dragging, "dismiss cancels drag")
	app.reset_positions()
	app.interaction.cooldowns.clear()
	app.interaction.rest_remaining = 0
	app.interaction.automatic_enabled = false
	check(app.interaction.request("hug", app.area), "manual hug starts when eligible")
	app.pets[0].foot.x = app.pets[0].target_x
	app.interaction.step(0.01, app.area)
	app.interaction.step(4, app.area)
	check(app.interaction.cooldowns.hug == 30 and app.interaction.cooldowns.get("natural_approach", 0) == 0, "finishing hug does not cool eye contact")
	check("间隔" in app.interaction.request_reason("natural_approach", app.area), "different action observes short rest")
	app.interaction.step(5, app.area)
	check(app.interaction.request("natural_approach", app.area), "eye contact can start five seconds after hug")
	check(is_equal_approx(app.interaction.cooldowns.hug, 25), "manual request does not reset other cooldown")
	app.pets[0].foot.x = app.pets[0].target_x
	app.interaction.step(0.01, app.area)
	app.interaction.step(8, app.area)
	check(app.interaction.cooldowns.natural_approach == 30 and app.interaction.cooldowns.hug < 25, "eye completion leaves remaining hug cooldown intact")
	app.hide_pets()
	app._process(31)
	check(app.interaction.rest_remaining == 0 and app.interaction.cooldowns.hug == 0 and app.interaction.cooldowns.natural_approach == 0, "hidden time advances all cooldowns")
	app.show_pets()
	app.reset_positions()
	app.interaction.pool = {"hug": app.interaction.pool.hug}
	app.interaction.automatic_enabled = true
	app.interaction.step(0.01, app.area)
	check(app.interaction.phase == InteractionManager.Phase.APPROACHING, "automatic starts eligible hug")
	app.interaction.cancel()
	check(app.interaction.cooldowns.hug == 30 and app.interaction.rest_remaining == 5, "automatic cancellation uses same cooldown policy")
	app.interaction.paused = true
	app.interaction.step(0.05, app.area, 30)
	check(app.interaction.cooldowns.hug == 0, "cooldown uses actual elapsed time even when animation delta is clamped")
	app.interaction.paused = false
	app.settings_path = "user://test-controls.cfg"
	app.toggle_menu(app.pets[0])
	app.show_settings()
	app.toggle_automatic()
	app.toggle_pause()
	var settings := PetSettings.new()
	settings.load_from(app.settings_path)
	check(not settings.automatic_interactions and settings.paused, "both preferences persist")
	var config := ConfigFile.new()
	config.set_value("behavior", "paused", "yes")
	config.set_value("behavior", "automatic_interactions", 4)
	config.save(app.settings_path)
	settings.load_from(app.settings_path)
	check(not settings.paused and settings.automatic_interactions, "invalid preference types use defaults")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(app.settings_path))
	app.toggle_menu(app.pets[0])
	app.show_help()
	app.show_guides()
	var opened: Array[String] = []
	app.guide_locator = func(): return "/tmp/忘羡 pet/START_HERE.html"
	app.guide_opener = func(path): opened.append(path); return OK
	app.guide_button.pressed.emit()
	check(opened == ["/tmp/忘羡 pet/START_HERE.html"] and app.menu == null, "Help dispatches exact local path and closes menu")
	app.toggle_menu(app.pets[0])
	app.show_help()
	app.show_guides()
	app.online.guide_url = ""
	app.guide_locator = func(): return ""
	app.guide_button.pressed.emit()
	check(opened.size() == 1 and "完整解压" in app.guide_button.text, "missing guide gives visible recovery instruction without launching")
	app.guide_locator = func(): return "/tmp/guide.html"
	app.guide_opener = func(_path): return ERR_CANT_OPEN
	app.guide_button.pressed.emit()
	check("未能打开" in app.guide_button.text and app.guide_button.tooltip_text == "/tmp/guide.html", "opener failure leaves a useful fallback")
	check(LocalGuide.candidates("C:/Pet folder/CPPet.exe", "", "Windows", false)[0] == "C:/Pet folder/START_HERE.html", "Windows guide resolves beside executable")
	check(LocalGuide.candidates("/Apps/Pet.app/Contents/MacOS/Pet", "", "macOS", false)[1] == "/Apps/START_HERE.html", "macOS guide resolves beside app bundle")
	check(LocalGuide.candidates("/tools/Godot", "/project", "Linux", true)[1] == "/project/dist/guide-preview/START_HERE.html", "development guide resolves without cwd dependency")
	app.queue_free()
	await process_frame
	print("CONTROLS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
