class_name AlarmWindow
extends Window

var alarm := DailyAlarm.new()
var settings_path := "user://alarm.cfg"
var sound: CheckButton
var player: AudioStreamPlayer
var hours: SpinBox
var minutes: SpinBox
var display: Label
var status: Label
var primary: Button
var cancel_button: Button
var last_status := ""

func setup(font: Font, path := "user://alarm.cfg") -> void:
	settings_path = path
	alarm.load_from(settings_path)
	title = "每日闹钟 · Daily Alarm"
	size = Vector2i(420, 430)
	min_size = size
	unresizable = true
	always_on_top = true
	visible = false
	var theme_data := Theme.new()
	theme_data.default_font = font
	theme_data.default_font_size = 16
	theme = theme_data
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("faf9f4")
	background.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", background)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var heading := label("每日闹钟", 22)
	column.add_child(heading)
	column.add_child(label("Daily Alarm", 13))
	display = label("09:00", 38)
	display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(display)
	var inputs := HBoxContainer.new()
	inputs.add_theme_constant_override("separation", 10)
	column.add_child(inputs)
	hours = time_input(inputs, "时（24 小时制）", 23, alarm.hour)
	minutes = time_input(inputs, "分", 59, alarm.minute)
	sound = CheckButton.new()
	sound.text = "提示音"
	sound.button_pressed = alarm.sound_enabled
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		sound.add_theme_color_override(key, Color("30473f"))
	sound.toggled.connect(func(value):
		alarm.sound_enabled = value
		if not value:
			player.stop()
		save_alarm())
	column.add_child(sound)
	status = label("按本机时间，每天提醒一次。", 14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 42
	column.add_child(status)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)
	primary = button("开启每日闹钟", act)
	cancel_button = button("修改时间", secondary_action)
	actions.add_child(primary)
	actions.add_child(cancel_button)
	var note := label("关闭窗口不影响提醒；桌宠退出期间不会提醒。", 12)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	close_requested.connect(func(): alarm.acknowledge(); player.stop(); hide())
	player = AudioStreamPlayer.new()
	player.volume_db = -14
	player.stream = chime()
	add_child(player)
	alarm.rang.connect(on_alarm)
	refresh()

func label(text: String, font_size: int) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_color_override("font_color", Color("30473f"))
	item.add_theme_font_size_override("font_size", font_size)
	return item

func button(text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 38
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("dce8d8") if key in ["hover", "pressed"] else Color("edf1e8")
		style.set_corner_radius_all(8)
		item.add_theme_stylebox_override(key, style)
		item.add_theme_color_override("font_" + key + "_color" if key != "normal" else "font_color", Color("30473f"))
	item.pressed.connect(action)
	return item

func time_input(parent: Control, caption: String, maximum: int, initial: int) -> SpinBox:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	column.add_child(label(caption, 13))
	var input := SpinBox.new()
	input.min_value = 0
	input.max_value = maximum
	input.step = 1
	input.value = initial
	input.custom_minimum_size = Vector2(110, 36)
	var edit := input.get_line_edit()
	edit.add_theme_color_override("font_color", Color("30473f"))
	edit.add_theme_color_override("font_uneditable_color", Color("6f7f74"))
	edit.add_theme_color_override("caret_color", Color("30473f"))
	for key in ["normal", "read_only", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("ffffff") if key == "normal" else Color("edf1e8")
		style.set_corner_radius_all(5)
		style.set_border_width_all(1)
		style.border_color = Color("829b78") if key == "focus" else Color("dce2d8")
		style.content_margin_left = 8
		style.content_margin_right = 8
		edit.add_theme_stylebox_override(key, style)
	column.add_child(input)
	input.value_changed.connect(func(_value): refresh())
	return input

func open() -> void:
	unfocusable = false
	position = Vector2i(DesktopWindowController.work_area().get_center()) - size / 2
	show()
	grab_focus() # Only on an explicit user action, never on completion.
	refresh()

func act() -> void:
	if alarm.enabled:
		alarm.disable()
		player.stop()
	else:
		hours.apply()
		minutes.apply()
		alarm.enable(int(hours.value), int(minutes.value))
	unfocusable = false
	save_alarm()
	refresh()

func secondary_action() -> void:
	if alarm.ringing:
		alarm.acknowledge()
	else:
		alarm.disable()
	player.stop()
	unfocusable = false
	save_alarm()
	refresh()

func save_alarm() -> void:
	if alarm.save_to(settings_path) != OK:
		push_warning("无法保存闹钟设置。")

func _process(_delta: float) -> void:
	alarm.poll()
	if is_instance_valid(display):
		refresh()

func refresh() -> void:
	if not is_instance_valid(minutes) or not is_instance_valid(primary):
		return
	display.text = "%02d:%02d" % [hours.value, minutes.value]
	var key := "%s/%s/%d" % [alarm.enabled, alarm.ringing, alarm.next_at]
	if key == last_status:
		return
	last_status = key
	for input in [hours, minutes]:
		input.editable = not alarm.enabled
	primary.text = "关闭闹钟" if alarm.enabled else "开启每日闹钟"
	cancel_button.text = "知道了" if alarm.ringing else "修改时间"
	cancel_button.disabled = not alarm.enabled
	if alarm.ringing:
		status.text = "闹钟时间到了！明天仍会按时提醒。"
	elif alarm.enabled:
		var date := Time.get_datetime_dict_from_unix_time(alarm.next_at)
		status.text = "下次：%d 月 %d 日 %02d:%02d\n隐藏或暂停桌宠不影响提醒。" % [date.month, date.day, alarm.hour, alarm.minute]
	else:
		status.text = "按本机时间，每天提醒一次。"

func on_alarm() -> void:
	save_alarm()
	if not visible:
		unfocusable = true
		position = Vector2i(DesktopWindowController.work_area().get_center()) - size / 2
		show()
	if alarm.sound_enabled:
		player.play()
	refresh()

static func chime() -> AudioStreamWAV:
	# A short, locally generated two-note chime; no external sound assets.
	var rate := 22050
	var samples := PackedByteArray()
	var count := int(rate * 0.9)
	samples.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var phase := fmod(t, 0.45)
		var envelope := minf(phase / 0.02, 1.0) * maxf(0, 1.0 - phase / 0.38)
		var frequency := 660.0 if t < 0.45 else 880.0
		samples.encode_s16(i * 2, int(sin(TAU * frequency * t) * envelope * 16000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = samples
	return stream
