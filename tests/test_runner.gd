extends SceneTree
var failures := 0
var checks := 0
var area := Rect2(0, 0, 1280, 720)
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var loader := ContentLoader.new()
	var pool := loader.interactions(loader.read_json("res://data/interactions.json", {}), {})
	check(pool.size() == 1 and loader.errors.is_empty(), "bundled interaction valid")
	for field in ["duration", "fps", "weight", "spacing", "approach_walk_stop"]:
		var bad := pool.duplicate(true)
		bad.natural_approach[field] = 0
		check(loader.interactions(bad, {}).is_empty(), "invalid positive parameter rejected")
	var bad := pool.duplicate(true)
	bad.natural_approach.layout = "either"
	check(loader.interactions(bad, {}).is_empty(), "unsupported mirrored layout rejected")
	bad = pool.duplicate(true)
	bad.natural_approach.duration = 1
	check(loader.interactions(bad, {}).is_empty(), "truncated eye sequence rejected")
	check(loader.interactions({"bad":null}, {}).is_empty(), "null content rejected")
	check(loader.characters(null).size() == 2, "characters fall back")
	check(loader.read_json("res://tests/invalid.json", {}) == {}, "malformed JSON falls back")
	var a := Pet.new()
	var b := Pet.new()
	a.character_id = "A"
	b.character_id = "B"
	a.speed = 80
	b.speed = 68
	a.foot = Vector2(500, 712)
	b.foot = Vector2(720, 712)
	var pair: Array[Pet] = [a, b]
	var manager := InteractionManager.new()
	manager.setup(pair, pool, {})
	manager.step(0.01, area)
	check(manager.phase == InteractionManager.Phase.APPROACHING and not a.available() and not b.available(), "approach reserves both")
	var receiver := b.foot
	for i in range(30):
		a.step(1.0 / 30, area)
		b.step(1.0 / 30, area)
		manager.step(1.0 / 30, area)
	check(b.foot == receiver, "LWJ waits while WWX approaches")
	check(manager.phase == InteractionManager.Phase.PLAYING, "approach reaches eye contact")
	check(a.interaction_frame == b.interaction_frame and a.interaction_frame >= 0, "shared eye timeline")
	check(manager.eye_frame(0) == 0 and manager.eye_frame(0.25) == 1 and manager.eye_frame(1.0) == 4, "4 FPS forward frames")
	check(manager.eye_frame(2) == 4 and manager.eye_frame(3.25) == 5 and manager.eye_frame(4.25) == 9 and manager.eye_frame(4.5) == -1, "hold return and shared idle")
	a.start_drag(a.foot)
	check(a.state == Pet.State.DRAGGED and b.state == Pet.State.IDLE and manager.phase == InteractionManager.Phase.FREE, "drag cancels pair without overriding dragged state")
	a.stop_drag()
	for i in range(100):
		a.step(1.0 / 30, area)
	check(a.foot.y == 712 and a.state != Pet.State.FALL, "release lands")
	a.change_state(Pet.State.IDLE)
	b.change_state(Pet.State.IDLE)
	manager.step(0.01, area)
	check(manager.phase == InteractionManager.Phase.FREE, "cooldown prevents restart")
	manager.step(31, area)
	check(manager.phase == InteractionManager.Phase.APPROACHING, "cooldown expires")
	manager.step(6, area)
	check(manager.phase == InteractionManager.Phase.FREE and a.available() and b.available(), "approach timeout releases both")
	manager.cooldowns.clear()
	a.foot.x = 800
	b.foot.x = 640
	manager.step(1, area)
	check(manager.phase == InteractionManager.Phase.FREE, "reverse order cannot trigger eye contact")
	a.foot.x = 500
	b.foot.x = 720
	manager.step(0.01, area)
	a.foot.x = 800
	manager.step(0.01, area)
	check(manager.phase == InteractionManager.Phase.FREE, "order change cancels active approach")
	a.foot = Vector2(500, 712)
	manager.cooldowns.clear()
	manager.step(0.01, area)
	b.menu_open = true
	manager.step(0.01, area)
	check(manager.phase == InteractionManager.Phase.FREE, "menu cancels reservation")
	b.menu_open = false
	manager.paused = true
	a.paused = true
	a.start_drag(a.foot)
	a.foot.y = 400
	a.stop_drag()
	for i in range(100):
		a.step(1.0 / 30, area)
	check(a.state == Pet.State.IDLE and a.foot.y == 712, "paused dragging still lands")
	var clamped := DesktopWindowController.clamp_foot(Vector2(-9999, 9999), Rect2(-1280, 40, 1280, 680))
	check(clamped == Vector2(-1120, 712), "expanded window respects negative display origin")
	manager.paused = false
	a.paused = false
	for tick in range(216000):
		if manager.phase == InteractionManager.Phase.FREE and a.available() and b.available():
			a.foot = Vector2(500, 712)
			b.foot = Vector2(720, 712)
			a.change_state(Pet.State.IDLE)
			b.change_state(Pet.State.IDLE)
		if tick % 3001 == 0:
			a.start_drag(a.foot)
			a.stop_drag()
		a.step(1.0 / 30, area)
		b.step(1.0 / 30, area)
		manager.step(1.0 / 30, area)
	check(manager.completed > 100 and manager.cancelled > 5, "simulated two hours completes and cancels repeatedly")
	check(a.state_time < 31 and b.state_time < 31, "no permanently reserved state")
	manager.cancel()
	a.free()
	b.free()
	print("RESULT: %d checks, %d failures; simulated 7200 s, completed=%d cancelled=%d" % [checks, failures, manager.completed, manager.cancelled])
	quit(1 if failures else 0)
