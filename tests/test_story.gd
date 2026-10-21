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
	var path := "user://test-story-" + Crypto.new().generate_random_bytes(8).hex_encode() + ".json"
	var library := StoryLibrary.new()
	library.load_from(path)
	var project := library.create("测试对白")
	check(not StoryLibrary.playable(project).is_empty(), "empty script cannot play")
	project.lines = [{"speaker":"A", "text":"蓝湛！", "seconds":2.0}, {"speaker":"B", "text":"魏婴。", "seconds":3.0}]
	check(StoryLibrary.playable(project).is_empty(), "valid Chinese script")
	check(library.save(), "save initial script")
	project.title = "修改后"
	check(library.save(), "save replacement with backup")
	var restored := StoryLibrary.new()
	restored.load_from(path)
	check(restored.projects[0].title == "修改后", "reload saved changes")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	restored.load_from(path)
	check(restored.writable and restored.projects[0].title == "测试对白", "recover previous valid backup")
	check(restored.save(), "replace corrupt primary safely")
	var invalid := project.duplicate(true)
	for value in [0, 61, "4", NAN]:
		invalid.lines[0].seconds = value
		check(not StoryLibrary.valid_project(invalid), "reject invalid duration")
	invalid = project.duplicate(true)
	invalid.lines[0].text = "字".repeat(161)
	check(not StoryLibrary.valid_project(invalid), "reject oversized text")
	invalid.lines[0].text = " "
	check(not StoryLibrary.playable(invalid).is_empty(), "blank lines cannot play")
	for suffix in ["", ".bak"]:
		file = FileAccess.open(path + suffix, FileAccess.WRITE)
		file.store_string("broken")
		file.close()
	restored.load_from(path)
	check(not restored.writable and not restored.save(), "preserve unrecoverable library")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	var app = load("res://scenes/Main.tscn").instantiate()
	app.settings_path = ""
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	var player: StoryPlayer = app.story_player
	player.set_process(false)
	check(player.start(project).is_empty(), "start dialogue")
	check(app.pets[0].paused and app.pets[1].paused and app.interaction.paused, "reserve both idle pets")
	project.lines[0].text = "changed"
	check(player.lines[0].text == "蓝湛！", "playback snapshot isolates edits")
	player.step(2)
	check(player.index == 1, "advance to other speaker")
	player.toggle_pause()
	player.step(30)
	check(player.active and player.index == 1, "pause holds current line")
	player.toggle_pause()
	player.step(3)
	check(not player.active and not app.pets[0].paused and not app.interaction.paused, "completion restores autonomous behavior")
	app.pets[0].paused = true
	app.interaction.paused = true
	player.start(project)
	player.stop()
	check(app.pets[0].paused and app.interaction.paused, "restore prior paused state")
	app.pets[0].paused = false
	app.interaction.paused = false
	player.start(project)
	app.pets[0].change_state(Pet.State.DRAGGED)
	app.pets[0].drag_started.emit(app.pets[0])
	check(not player.active and app.pets[0].state == Pet.State.DRAGGED, "drag cancels without overwriting dragged state")
	app.pets[0].change_state(Pet.State.IDLE)
	player.start(project)
	app.hide_pets()
	check(not player.active and not player.bubble.visible, "hide cancels bubble")
	check(not player.start(project).is_empty(), "cannot play hidden pets")
	app.show_pets()
	app.show_story_editor()
	await process_frame
	var editor: StoryEditor = app.story_editor
	editor.add_line()
	editor.body.text = "第一句"
	editor.edit_line()
	editor.add_line()
	editor.body.text = "第二句"
	editor.edit_line()
	editor.move_line(-1)
	check(editor.current().lines[0].text == "第二句", "reorder editor lines")
	editor.duplicate_project()
	check(editor.library.projects.size() == 2, "copy script")
	editor.current().lines[0].text = "copy edit"
	check(editor.library.projects[0].lines[0].text == "第二句", "copy is independent")
	editor.delete_project()
	check(editor.library.projects.size() == 1, "delete script")
	editor.play()
	check(player.active, "editor starts playback")
	await process_frame
	await process_frame
	await process_frame
	check(player.bubble.visible, "bubble visible")
	if DisplayServer.get_name() != "headless":
		check(player.bubble.mouse_passthrough and player.bubble.unfocusable, "native bubble cannot capture input")
	check(player.bubble.size.y < 150, "short bubble sizes to text")
	player.bubble.present(app.pets[0], "长句".repeat(80), app.settings)
	await process_frame
	await process_frame
	check(DesktopWindowController.work_area().encloses(Rect2(Vector2(player.bubble.position), Vector2(player.bubble.size))), "long Chinese bubble fits screen")
	player.bubble.present(app.pets[1], "嗯。", app.settings)
	check(player.bubble.size.y < 100, "bubble shrinks for shorter reply")
	player.stop()
	await process_frame
	check(not player.bubble.visible, "pending presentation cannot resurrect stopped bubble")
	app.queue_free()
	await process_frame
	print("STORY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
