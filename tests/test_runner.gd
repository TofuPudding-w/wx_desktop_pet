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
	var lines: Dictionary = loader.read_json("res://data/dialogues.json", {})
	var pool := loader.interactions(loader.read_json("res://data/interactions.json", {}), lines)
	check(pool.size() == 1, "valid interaction loads")
	check(loader.errors.is_empty(), "bundled content has no errors")
	var broken := pool.duplicate(true)
	broken.look_and_talk.duration = 0
	check(loader.interactions(broken, lines).is_empty(), "zero duration rejected")
	broken = pool.duplicate(true)
	broken.look_and_talk.weight = "10"
	check(loader.interactions(broken, lines).is_empty(), "non-numeric weight rejected")
	check(loader.interactions(pool, {"first_meeting":[{"speaker":"C", "text":"bad"}]}).is_empty(), "unknown speaker rejected")
	check(loader.interactions(pool, []).is_empty(), "bad document type rejected")
	check(loader.interactions({"bad":null}, lines).is_empty(), "null interaction rejected")
	check(loader.characters(null).size() == 2, "invalid characters fall back")
	check(loader.read_json("res://tests/invalid.json", {}) == {}, "malformed JSON falls back")
	var a := Pet.new()
	var b := Pet.new()
	a.character_id = "A"
	b.character_id = "B"
	a.foot = Vector2(565, 712)
	b.foot = Vector2(715, 712)
	var pair: Array[Pet] = [a,b]
	var manager := InteractionManager.new()
	manager.setup(pair, pool, lines)
	manager.step(0.01, area)
	check(manager.phase == InteractionManager.Phase.APPROACHING, "encounter locks pair")
	check(not a.available() and not b.available(), "reserved pets cannot re-enter")
	for i in range(60):
		a.step(1.0/30, area)
		b.step(1.0/30, area)
		manager.step(1.0/30, area)
	check(manager.phase == InteractionManager.Phase.PLAYING, "approach reaches interaction")
	check(a.heart and b.heart, "both show heart")
	check(a.bubble != "" and b.bubble == "", "first speaker only")
	manager.step(2.1, area)
	check(a.bubble == "" and b.bubble != "", "second speaker only")
	a.start_drag(Vector2(500,500))
	check(a.state == Pet.State.DRAGGED, "cancellation preserves dragged state")
	check(b.state == Pet.State.IDLE, "partner released on drag")
	check(manager.phase == InteractionManager.Phase.FREE and not a.heart and a.bubble == "" and b.bubble == "", "cancel clears visuals and lock")
	a.stop_drag()
	for i in range(120):
		a.step(1.0/30, area)
	check(a.state != Pet.State.FALL and a.foot.y == 712, "drop lands on bottom")
	a.foot = Vector2(565, 712)
	b.foot = Vector2(715, 712)
	a.change_state(Pet.State.IDLE)
	b.change_state(Pet.State.IDLE)
	manager.step(0.1, area)
	check(manager.phase == InteractionManager.Phase.FREE, "cooldown prevents restart")
	manager.step(31, area)
	check(manager.phase == InteractionManager.Phase.APPROACHING, "cooldown expires")
	manager.step(6, area)
	check(manager.phase == InteractionManager.Phase.FREE and a.available() and b.available(), "approach timeout releases both")
	manager.cooldowns.clear()
	manager.step(0.1, area)
	manager.cancel()
	manager.paused = true
	a.paused = true
	b.paused = true
	manager.cooldowns.clear()
	manager.step(60, area)
	check(manager.phase == InteractionManager.Phase.FREE, "pause blocks interaction")
	a.start_drag(Vector2.ZERO)
	check(a.state == Pet.State.DRAGGED, "pause still allows drag")
	a.foot.y = 400
	a.stop_drag()
	for i in range(100):
		a.step(1.0/30, area)
	check(a.foot.y == 712 and a.state == Pet.State.IDLE, "paused drop still lands")
	var clamped := DesktopWindowController.clamp_foot(Vector2(-9999,9999), Rect2(-1280,40,1280,680))
	check(clamped == Vector2(-1160,712), "negative monitor origin boundary")
	# Deterministic simulated two-hour stress pass, separate from real desktop soak.
	manager.paused = false
	a.paused = false
	b.paused = false
	for tick in range(216000):
		if manager.phase == InteractionManager.Phase.FREE and a.available() and b.available():
			a.foot = Vector2(565,712)
			b.foot = Vector2(715,712)
			a.change_state(Pet.State.IDLE)
			b.change_state(Pet.State.IDLE)
		if tick % 3001 == 0:
			a.start_drag(a.foot)
			a.stop_drag()
		a.step(1.0/30, area)
		b.step(1.0/30, area)
		manager.step(1.0/30, area)
	check(manager.completed > 150, "two-hour simulation repeatedly completes interactions")
	check(manager.cancelled > 5, "stress includes repeated interruptions")
	check(a.state_time < 31 and b.state_time < 31, "stress has no stuck states")
	print("RESULT: %d checks, %d failures; simulated 7200 s; completed=%d cancelled=%d" % [checks,failures,manager.completed,manager.cancelled])
	manager.cancel()
	a.free()
	b.free()
	quit(1 if failures else 0)
