extends SceneTree
var checks := 0
var failures := 0
func check(okay: bool, message: String) -> void:
	checks += 1
	if not okay:
		failures += 1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var pair = load("res://scenes/EyeContactPair.tscn").instantiate()
	root.add_child(pair)
	await process_frame
	pair.set_process(false)
	for info in [["WeiWuxian", 24.0], ["LanWangji", 19.0]]:
		var idle = pair.get_node(info[0] + "/Idle/Sprite")
		var eye = pair.get_node(info[0] + "/EyeContact/Sprite")
		check(idle.global_scale.is_equal_approx(eye.global_scale), "idle and eye share scale")
		var idle_point = idle.to_global(idle.offset + Vector2(120, 300))
		var eye_point = eye.to_global(eye.offset + Vector2(120 + info[1], 300))
		check(idle_point.is_equal_approx(eye_point), "translated first-frame feature aligns exactly")
		check(eye.sprite_frames.get_frame_count("eye_contact") == 5, "all five frames available")
		check(not eye.flip_h and eye.global_scale.x > 0, "no mirrored eye contact")
	check(pair.start(), "valid left/right order starts")
	pair.advance(0.3)
	for sprite in pair.eye_sprites():
		check(sprite.frame == 1, "both characters share timeline")
	pair.set_fps(2)
	check(is_equal_approx(pair.elapsed * pair.fps, 1.2), "rate adjustment preserves fractional frame")
	pair.advance(2)
	check(not pair.playing and pair.showing_eye, "holds final pose without looping")
	for sprite in pair.eye_sprites():
		check(sprite.frame == 4, "final frame is held")
	pair.show_idle()
	check(pair.get_node("WeiWuxian/Idle").visible and not pair.showing_eye, "can return to idle for comparison")
	check(pair.show_first_frame() and not pair.playing, "first-frame alignment comparison is stationary")
	pair.get_node("WeiWuxian").position.x = 500
	pair.advance(0)
	check(pair.blocked and not pair.showing_eye, "swapping positions cancels even held eye contact")
	check(not pair.start(), "reversed order cannot restart")
	pair.get_node("WeiWuxian").position.x = pair.get_node("LanWangji").position.x
	check(not pair.start(), "overlapping anchors are not accepted as left/right order")
	pair.get_node("WeiWuxian").position.x = 220
	check(pair.start() and not pair.blocked, "restoring valid order permits replay")
	print("EYE CONTACT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
