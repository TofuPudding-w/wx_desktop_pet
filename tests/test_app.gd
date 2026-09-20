extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var app: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
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
	app.queue_free()
	await process_frame
	print("APP RESULT: 12 checks, %d failures" % failures)
	quit(1 if failures else 0)
