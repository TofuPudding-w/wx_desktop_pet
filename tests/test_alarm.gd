extends SceneTree
var checks := 0
var failures := 0
var now := Time.get_unix_time_from_datetime_string("2026-10-04T08:00:00")
var rings := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func make_alarm() -> DailyAlarm:
	var item := DailyAlarm.new()
	item.clock = func(): return Time.get_datetime_dict_from_unix_time(now)
	return item
func run() -> void:
	var alarm := make_alarm()
	alarm.rang.connect(func(): rings += 1)
	for pair in [[-1, 0], [24, 0], [8, -1], [8, 60]]:
		check(not alarm.enable(pair[0], pair[1]), "invalid time rejected")
	check(alarm.enable(9, 30), "enable daily alarm")
	check(alarm.next_at == now + 5400, "future time scheduled today")
	now += 5399
	alarm.poll()
	check(rings == 0, "no early reminder")
	now += 1
	alarm.poll()
	alarm.poll()
	check(rings == 1 and alarm.ringing, "due reminder emitted exactly once")
	check(alarm.enabled and alarm.next_at == now + DailyAlarm.DAY, "automatically schedules tomorrow")
	alarm.acknowledge()
	check(not alarm.ringing and alarm.enabled, "acknowledge keeps recurrence")
	now -= 3600
	alarm.poll()
	now += 3600
	alarm.poll()
	check(rings == 1, "backward clock/repeated hour does not duplicate reminder")
	now += 3 * DailyAlarm.DAY + 100
	alarm.poll()
	check(rings == 2, "missed days coalesced into one reminder after resume")
	check(alarm.next_at > now, "next reminder remains in future")
	alarm.disable()
	now += DailyAlarm.DAY
	alarm.poll()
	check(rings == 2 and not alarm.enabled, "disabled alarm never rings")
	now = Time.get_unix_time_from_datetime_string("2026-12-31T23:59:30")
	alarm.last_fired_day = -1
	alarm.enable(0, 0)
	check(alarm.next_at == now + 30, "midnight across year boundary")
	now += 30
	alarm.poll()
	check(rings == 3, "midnight alarm fires")
	alarm.sound_enabled = false
	var path := "user://test-daily-alarm.cfg"
	check(alarm.save_to(path) == OK, "save alarm")
	var restored := make_alarm()
	restored.load_from(path)
	check(restored.enabled and restored.hour == 0 and restored.minute == 0 and not restored.sound_enabled, "time/enabled/sound restored")
	check(restored.next_at == alarm.next_at and not restored.ringing, "restart on same day does not duplicate reminder")
	restored.disable()
	restored.save_to(path)
	var off := make_alarm()
	off.load_from(path)
	check(not off.enabled, "disabled state persists")
	var invalid := ConfigFile.new()
	invalid.set_value("alarm", "hour", 50)
	invalid.save(path)
	off.load_from(path)
	check(not off.enabled, "invalid saved time remains disabled")
	DirAccess.remove_absolute(path)
	var app = load("res://scenes/Main.tscn").instantiate()
	app.settings_path = ""
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	var window: AlarmWindow = app.alarm_window
	window.set_process(false)
	window.alarm.clock = func(): return Time.get_datetime_dict_from_unix_time(now)
	window.alarm.sound_enabled = false
	app.toggle_menu(app.pets[0])
	app.show_tools()
	check(app.menu_column.get_child(0).text == "每日闹钟", "Tools exposes alarm instead of timer")
	app.menu_column.get_child(0).pressed.emit()
	check(window.visible and app.menu == null, "alarm window opens from menu")
	window.hours.value = 0
	window.minutes.value = 1
	await process_frame
	window.act()
	check(window.alarm.enabled and not window.hours.editable, "enabling locks scheduled time")
	window.close_requested.emit()
	check(not window.visible and window.alarm.enabled, "closing window keeps alarm enabled")
	app.toggle_pause()
	app.hide_pets()
	now += 70
	window._process(0)
	check(window.visible and window.alarm.ringing and app.pets_hidden, "reminder appears while pets hidden/paused")
	check(window.unfocusable or DisplayServer.get_name() == "headless", "automatic reminder cannot take focus")
	window.secondary_action()
	check(window.alarm.enabled and not window.alarm.ringing, "dismiss keeps tomorrow's alarm")
	window.secondary_action()
	check(not window.alarm.enabled and window.hours.editable, "modify time restores editing")
	window.act()
	window.act()
	check(not window.alarm.enabled, "enable/disable button")
	await process_frame
	await process_frame
	check(Rect2(Vector2.ZERO, Vector2(window.size)).encloses(window.get_child(0).get_rect()), "alarm controls fit window")
	app.queue_free()
	await process_frame
	print("ALARM: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
