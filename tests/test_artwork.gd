extends SceneTree
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	for id in ["A", "B"]:
		var art := PetArtwork.new()
		art.setup(id)
		check(art.key_for(Pet.State.IDLE, 1, 0.9, -1, false) == "idle0" and art.key_for(Pet.State.IDLE, 1, 1.1, -1, false) == "idle1", "idle 1 FPS")
		check(art.key_for(Pet.State.WALK, 1, 0.18, -1, false) == "walk1_1", "walk 6 FPS")
		check(art.key_for(Pet.State.APPROACH, 1, 0.5, -1, false) == "idle0", "waiting receiver does not walk in place")
		check(art.key_for(Pet.State.FALL, -1, 0, -1, false) == "drag-1", "fall reuses selected drag art")
		var right: Dictionary = art.frames["walk1_0"]
		var left: Dictionary = art.frames["walk-1_0"]
		if id == "A":
			check(right.texture != left.texture and not left.flip and not art.frames["drag-1"].flip, "WWX uses independent directions")
		else:
			check(right.texture == left.texture and left.flip and art.frames["drag-1"].flip, "LWJ reuses and mirrors frames")
		var idle: Dictionary = art.frames.idle0
		var eye: Dictionary = art.frames.eye0
		var shift := 24.0 if id == "A" else 19.0
		check(is_equal_approx(idle.scale, eye.scale) and idle.offset.is_equal_approx(eye.offset + Vector2(shift, 0)), "eye first frame maintains idle alignment")
		for key in art.frames:
			var frame: Dictionary = art.frames[key]
			check(frame.polygon.size() >= 3, "valid native input polygon")
			for point in frame.polygon:
				check(Rect2(Vector2.ZERO, Vector2(DesktopWindowController.SIZE)).has_point(point), "all visual hit points fit native window")
			check(not art.opaque_at(key, Vector2.ZERO), "transparent corner is not draggable")
			var image: Image = frame.image
			var found := false
			for y in range(100, image.get_height() - 50, 50):
				for x in range(50, image.get_width() - 50, 50):
					if image.get_pixel(x, y).a > 0.9:
						var px := image.get_width() - 1 - x if frame.flip else x
						var local: Vector2 = DesktopWindowController.FOOT + (Vector2(px + 0.5, y + 0.5) + frame.offset) * frame.scale
						check(art.opaque_at(key, local), "opaque pixels remain draggable in either orientation")
						check(Geometry2D.is_point_in_polygon(local, frame.polygon), "native shape contains clickable pixel")
						found = true
						break
				if found:
					break
	print("ARTWORK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
