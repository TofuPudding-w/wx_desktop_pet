extends SceneTree

var failures := 0
var checks := 0

func check(okay: bool, message: String) -> void:
	checks += 1
	if not okay:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var preview = load("res://scenes/DragPreview.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	preview.set_process(false)
	var a = preview.get_node("WeiWuxian")
	var b = preview.get_node("LanWangji")
	var a_pose = a.get_node("DragPose")
	var b_pose = b.get_node("DragPose")
	check(not a_pose.visible and not b_pose.visible, "poses start hidden")
	for pet in [a, b]:
		preview.begin_drag(pet, pet.position - Vector2(0, 80))
		check(pet.get_node("DragPose").visible and not pet.get_node("Sprite").visible, "drag replaces walking art")
		preview.move_drag(pet.position - Vector2(0, 230))
		check(pet.position.y < preview.GROUND, "drag lifts character")
		preview.moving = true
		var lifted: Vector2 = pet.position
		preview.step_characters(0.1)
		check(pet.position == lifted, "drag has priority over autonomous movement")
		preview.set_direction(-1)
		check(a_pose.texture.resource_path.ends_with("to_the_left.png") and not a_pose.flip_h, "WWX left uses independent art")
		check(b_pose.texture.resource_path.ends_with("drag_up.png") and b_pose.flip_h, "LWJ left mirrors shared art")
		preview.set_direction(1)
		check(a_pose.texture.resource_path.ends_with("to_the_right.png") and not a_pose.flip_h, "WWX right uses independent art")
		check(not b_pose.flip_h, "LWJ right is unflipped")
		# Check hit geometry in both orientations against pixels from the active pose.
		var pose = pet.get_node("DragPose")
		for facing in [-1, 1]:
			preview.set_direction(facing)
			var image = pose.texture.get_image()
			var tested := false
			for y in range(100, 500, 40):
				for x in range(80, 430, 40):
					if image.get_pixel(x, y).a > 0.5:
						var shown_x: float = 511 - x if pose.flip_h else x
						var point = pose.to_global(Vector2(shown_x + 0.5, y + 0.5) - pose.texture.get_size() * 0.5 + pose.offset)
						check(preview.hit_pet(pet, point), "opaque pose pixel can be picked in either direction")
						tested = true
						break
				if tested:
					break
			check(tested, "found an opaque sample")
		check(not preview.hit_pet(pet, pose.to_global(Vector2(-255, -682))), "transparent corner is not clickable")
		preview.end_drag()
		check(preview.dragged_pet == null and preview.falling.has(pet), "release starts falling and frees pointer")
		preview.begin_drag(pet, pet.position)
		check(not preview.falling.has(pet), "can pick up while falling")
		preview.end_drag()
		preview.moving = false
		for i in range(90):
			preview.step_characters(1.0 / 60.0)
		check(pet.position.y == preview.GROUND and not preview.falling.has(pet), "fall lands even with autonomous movement off")
		check(not pose.visible and pet.get_node("Sprite").visible, "landing restores walking preview")
	check(a.get_node("Sprite").sprite_frames.get_animation_speed("left_to_right") == 6, "WWX walk stays 6 FPS")
	check(b.get_node("Sprite").sprite_frames.get_animation_speed("walk") == 6, "LWJ walk stays 6 FPS")
	print("DRAG PREVIEW: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
