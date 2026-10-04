class_name DailyAlarm
extends RefCounted
## Compare local calendar times, not UTC offsets or a repeating 24-hour timer.
signal rang
const DAY := 86400
var enabled := false
var hour := 9
var minute := 0
var sound_enabled := true
var ringing := false
var next_at := 0
var last_fired_day := -1
var clock: Callable = func(): return Time.get_datetime_dict_from_system()

func local_now() -> int:
	return Time.get_unix_time_from_datetime_dict(clock.call())

func schedule_after(now: int) -> void:
	var day := int(now / DAY)
	next_at = day * DAY + hour * 3600 + minute * 60
	if next_at <= now or day <= last_fired_day:
		next_at = maxi(day + 1, last_fired_day + 1) * DAY + hour * 3600 + minute * 60

func enable(at_hour: int, at_minute: int) -> bool:
	if at_hour < 0 or at_hour > 23 or at_minute < 0 or at_minute > 59:
		return false
	hour = at_hour
	minute = at_minute
	enabled = true
	ringing = false
	schedule_after(local_now())
	return true

func disable() -> void:
	enabled = false
	ringing = false
	next_at = 0

func acknowledge() -> void:
	ringing = false

func poll() -> void:
	if not enabled:
		return
	var now := local_now()
	if now >= next_at:
		# Coalesce missed days after sleep into one reminder. Never fire twice
		# on one local date, including a repeated hour when clocks go back.
		var day := int(now / DAY)
		if day > last_fired_day:
			last_fired_day = day
			ringing = true
			schedule_after(now)
			rang.emit()
		else:
			schedule_after(now)

func save_to(path: String) -> Error:
	if path.is_empty():
		return OK
	var config := ConfigFile.new()
	for key in ["enabled", "hour", "minute", "sound_enabled", "last_fired_day"]:
		config.set_value("alarm", key, get(key))
	return config.save(path)

func load_from(path: String) -> void:
	if path.is_empty():
		return
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	var h: Variant = config.get_value("alarm", "hour", 9)
	var m: Variant = config.get_value("alarm", "minute", 0)
	var active: Variant = config.get_value("alarm", "enabled", false)
	var sound: Variant = config.get_value("alarm", "sound_enabled", true)
	var last: Variant = config.get_value("alarm", "last_fired_day", -1)
	if h is not int or m is not int or active is not bool or sound is not bool or last is not int or h < 0 or h > 23 or m < 0 or m > 59:
		push_warning("闹钟设置无效，已使用默认值。")
		return
	hour = h
	minute = m
	sound_enabled = sound
	# A future date from corrupt settings must not suppress alarms forever.
	last_fired_day = mini(last, int(local_now() / DAY))
	if active:
		enable(hour, minute) # No surprise catch-up reminder on app launch.
