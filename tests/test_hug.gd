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
	for pair in [[0.0, 0], [0.166, 0], [1.0/6, 1], [1.0/3, 2], [0.832, 2], [5.0/6, 3], [1.333, 3], [4.0/3, 2], [7.0/3, 2], [3.333, 3], [10.0/3, -1], [3.5, -1]]:
		check(HugSequence.frame_at(pair[0]) == pair[1], "mixed duration boundary %s" % str(pair))
	var app = load("res://scenes/Main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	for pet in app.pets:
		pet.set_process(false)
	var manager: InteractionManager = app.interaction
	var hug: Dictionary = manager.pool.hug
	var loader := ContentLoader.new()
	var invalid := hug.duplicate(true)
	invalid.frame_durations = [0.1, -1, 0.5, 0.5]
	check(loader.interactions({"hug": invalid}, {}).is_empty(), "invalid frame durations rejected")
	for count in [0, -1, 1.5, 31]:
		invalid = hug.duplicate(true)
		invalid.hold_repeats = count
		check(loader.interactions({"hug": invalid}, {}).is_empty(), "invalid repeat count rejected")
	check(is_equal_approx(HugSequence.total_duration(), float(hug.duration)), "configured duration includes entry and repetitions only")
	for dragged_index in 2:
		manager.cancel()
		app.reset_positions()
		manager.begin("hug", app.area)
		var a: Pet = app.pets[0]
		var b: Pet = app.pets[1]
		a.foot.x = a.target_x - 41
		a.step(0.02, app.area)
		a.refresh_art()
		check(is_equal_approx(b.foot.x - a.foot.x, HugSequence.SPACING), "snap to first frame spacing")
		check(a.art_key == "idle0", "no idle sliding")
		manager.step(0.01, app.area)
		app.hug_overlay.sync()
		check(manager.combined_frame == 0 and app.hug_overlay.visible, "combined window appears at frame one")
		for pet in app.pets:
			check(not pet.art_sprite.visible and (DisplayServer.get_name() == "headless" or pet.controller.window.mouse_passthrough), "ordinary sprites and their hit regions disabled")
		for frame in app.hug_overlay.art.frames.values():
			for point in frame.polygon:
				var local: Vector2 = point + HugOverlay.ORIGIN - DesktopWindowController.FOOT
				check(Rect2(Vector2.ZERO, Vector2(512, 384)).has_point(local), "combined frame fits window")
		manager.step(1.0/3, app.area)
		app.hug_overlay.sync()
		check(manager.combined_frame == 2, "contact enters third frame")
		app.pets[dragged_index].start_drag(app.pets[dragged_index].foot)
		app.hug_overlay.sync()
		check(not app.hug_overlay.visible and manager.phase == InteractionManager.Phase.FREE, "either drag cancels combined frame")
		for pet in app.pets:
			check(pet.art_sprite.visible and not pet.controller.window.mouse_passthrough, "sprites and input restored")
		check(app.pets[dragged_index].state == Pet.State.DRAGGED, "drag state preserved")
		check(manager.cooldowns.natural_approach > 0 and manager.cooldowns.hug > 0, "shared cooldown prevents immediate other interaction")
	app.reset_positions()
	manager.begin("hug", app.area)
	app.pets[0].foot.x = app.pets[0].target_x
	manager.step(0.01, app.area)
	manager.step(3.3, app.area)
	app.hug_overlay.sync()
	check(manager.combined_frame == 3 and app.hug_overlay.visible, "last hold remains frame four")
	manager.step(1.0/30 + 0.00001, app.area)
	app.hug_overlay.sync()
	check(manager.phase == InteractionManager.Phase.FREE and not app.hug_overlay.visible, "completion restores independent idle")
	app.queue_free()
	await process_frame
	print("HUG: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
