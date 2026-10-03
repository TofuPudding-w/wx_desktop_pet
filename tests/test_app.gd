extends SceneTree
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var app: Node = load("res://scenes/Main.tscn").instantiate()
	app.settings_path = ""
	root.add_child(app)
	await process_frame
	await process_frame
	app.interaction.cancel()
	app.interaction.pool = {"natural_approach": app.interaction.pool.natural_approach}
	check(app.pets.size() == 2, "app creates two pets")
	check(app.pets[0].get_window() != app.pets[1].get_window(), "pets have separate windows")
	app.toggle_menu(app.pets[0])
	check(app.pets[0].menu_open and is_instance_valid(app.menu), "right menu opens")
	app.pets[0].start_drag(app.pets[0].foot)
	check(not app.pets[0].menu_open and app.menu == null, "drag closes menu")
	check(app.pets[0].state == Pet.State.DRAGGED, "drag survives menu close")
	app.pets[0].stop_drag()
	app.toggle_menu(app.pets[1])
	app.toggle_pause()
	check(app.paused and app.interaction.paused and app.pets[0].paused and app.pets[1].paused, "pause propagates to both pets")
	app.reset_positions()
	check(app.pets[0].foot == app.initial_position(0), "reset restores A")
	check(app.pets[1].foot == app.initial_position(1), "reset restores B")
	app.toggle_pause()
	check(not app.paused and not app.pets[0].paused, "resume works")
	app.interaction.step(0.01, app.area)
	check(app.interaction.phase == InteractionManager.Phase.FREE, "reset preserves cooldown")
	app.interaction.step(31, app.area)
	check(app.interaction.phase == InteractionManager.Phase.APPROACHING, "reset permits encounter")
	app.toggle_menu(app.pets[1])
	check(app.interaction.phase == InteractionManager.Phase.FREE and app.pets[0].available(), "menu cancels paired interaction")
	app.close_menu()
	app.reset_positions()
	app.interaction.cooldowns.clear()
	app.interaction.rest_remaining = 0
	app.interaction.step(0.01, app.area)
	var a = app.pets[0]
	var b = app.pets[1]
	a.foot.x = a.target_x - 41
	a.refresh_art()
	check(a.art_key.begins_with("walk"), "walking continues outside earlier cutoff")
	a.step(0.005, app.area)
	a.refresh_art()
	check(a.art_key.begins_with("walk") and b.foot.x - a.foot.x > 200, "walking remains outside cutoff")
	a.step(0.01, app.area)
	a.refresh_art()
	check(is_equal_approx(b.foot.x - a.foot.x, 160), "crossing cutoff immediately snaps to final spacing")
	check(a.art_key.begins_with("idle") and a.state == Pet.State.APPROACH, "idle begins at final position with reservation intact")
	var final_x: float = a.foot.x
	a.step(0.05, app.area)
	check(a.foot.x == final_x, "idle pose never slides after arrival")
	app.interaction.step(0.01, app.area)
	app.interaction.step(3.25, app.area)
	for pet in app.pets:
		pet.refresh_art()
		check(pet.art_key == "turn0" and pet.art_sprite.texture.resource_path.contains("/turn_back/1.png"), "return uses authored first frame")
	app.interaction.step(1.0, app.area)
	for pet in app.pets:
		pet.refresh_art()
		check(pet.art_key == "turn4" and pet.art_sprite.texture.resource_path.contains("/turn_back/5.png"), "return plays authored fifth frame in ascending order")
	a.start_drag(a.foot)
	check(a.state == Pet.State.DRAGGED and b.state == Pet.State.IDLE and app.interaction.phase == InteractionManager.Phase.FREE, "drag interrupts authored return without locking partner")

	for factor in PetSettings.SIZES:
		app.apply_size(factor, false)
		check(is_equal_approx(app.size_factor, app.settings.effective_size(app.area)), "size fits work area")
		check(app.pets[0].controller.window.size == Vector2i((Vector2(320, 384) * app.size_factor).round()), "native window scales")
		check(app.pets[0].scale == Vector2.ONE * app.size_factor, "art scales without changing source")
		check(app.hug_overlay.size_factor == app.size_factor and app.interaction.size_factor == app.size_factor, "hug and coordinator share scale")
		for pet in app.pets:
			for side in [-1, 1]:
				pet.foot.x = app.area.position.x + 160 * app.size_factor if side < 0 else app.area.end.x - 160 * app.size_factor
				for trial in 20:
					pet.change_state(Pet.State.IDLE)
					pet.state_time = 20
					pet.step(0.01, app.area)
					check(pet.state == Pet.State.WALK and pet.facing == -side, "edge selects only inward walk")
					pet.step(0.01, app.area)
					check(pet.state == Pet.State.WALK, "edge walk does not flash back to idle")
	app.apply_size(1.5, false)
	app.reset_positions()
	app.interaction.cooldowns.clear()
	app.interaction.rest_remaining = 0
	app.interaction.begin("natural_approach", app.area)
	check(is_equal_approx(app.pets[1].foot.x - app.pets[0].target_x, 240), "eye spacing scales")
	check(is_equal_approx(app.pets[0].approach_walk_stop, 60), "early walk cutoff scales")
	app.toggle_menu(app.pets[0])
	app.show_size_settings()
	check(app.menu_column.get_child_count() == 6, "settings contains five sizes and back")
	app.apply_size(1.0, false)
	check(app.menu == null and app.interaction.phase == InteractionManager.Phase.FREE, "size change cancels safely and closes menu")
	var prefs := PetSettings.new()
	var path := "user://test-pet-size.cfg"
	prefs.requested_size = 1.75
	check(prefs.save_to(path) == OK, "size saves")
	prefs.requested_size = 1.0
	prefs.load_from(path)
	check(prefs.requested_size == 1.75, "size survives reload")
	var invalid := ConfigFile.new()
	invalid.set_value("display", "pet_size", "bad")
	invalid.save(path)
	prefs.load_from(path)
	check(prefs.requested_size == 1.0, "invalid size falls back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	app.queue_free()
	await process_frame
	print("APP RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
