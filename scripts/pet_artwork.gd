class_name PetArtwork
extends RefCounted

const IDLE_A = preload("res://assets/characters/wei_wuxian/idle/idle.tres")
const IDLE_B = preload("res://assets/characters/lan_wangji/idle/idle.tres")
const WALK_A = preload("res://assets/characters/wei_wuxian/walking/walking.tres")
const WALK_B = preload("res://assets/characters/lan_wangji/walking/walking.tres")
const EYE_A = preload("res://assets/characters/wei_wuxian/eye_contact/eye_contact.tres")
const EYE_B = preload("res://assets/characters/lan_wangji/eye_contact/eye_contact.tres")
const TURN_A = preload("res://assets/characters/wei_wuxian/eye_contact/turn_back/turn_back.tres")
const TURN_B = preload("res://assets/characters/lan_wangji/eye_contact/turn_back/turn_back.tres")
const DRAG_A_RIGHT = preload("res://assets/characters/wei_wuxian/drag_up/to_the_right.png")
const DRAG_A_LEFT = preload("res://assets/characters/wei_wuxian/drag_up/to_the_left.png")
const DRAG_B = preload("res://assets/characters/lan_wangji/drag_up/drag_up.png")
var frames: Dictionary = {}
var character_id := "A"

func setup(id: String) -> void:
	character_id = id
	var is_a := id == "A"
	var idle = IDLE_A if is_a else IDLE_B
	var walk = WALK_A if is_a else WALK_B
	var eye = EYE_A if is_a else EYE_B
	var turn = TURN_A if is_a else TURN_B
	for i in range(2):
		add_frame("idle%d" % i, idle.get_frame_texture("idle", i), Vector2(-258.5 if is_a else -243.5, -713), 256.0 / 713.0)
	for i in range(5):
		add_frame("eye%d" % i, eye.get_frame_texture("eye_contact", i), Vector2(-282.5 if is_a else -262.5, -713), 256.0 / 713.0)
	for i in range(5):
		add_frame("turn%d" % i, turn.get_frame_texture("turn_back", i), Vector2(-259.5 if is_a else -262.5, -713), 256.0 / 713.0)
	for sign in [-1, 1]:
		var animation := ("left_to_right" if sign > 0 else "right_to_left") if is_a else "walk"
		for i in range(walk.get_frame_count(animation)):
			add_frame("walk%d_%d" % [sign, i], walk.get_frame_texture(animation, i), Vector2(-315.5, -683 if is_a else -725), 256.0 / 683.0, not is_a and sign < 0)
		var drag = (DRAG_A_RIGHT if sign > 0 else DRAG_A_LEFT) if is_a else DRAG_B
		add_frame("drag%d" % sign, drag, Vector2(-256, -683), 256.0 / 683.0, not is_a and sign < 0)

func add_frame(key: String, texture: Texture2D, offset: Vector2, scale: float, flip := false) -> void:
	var image := texture.get_image()
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, 0.08)
	var points := PackedVector2Array()
	for contour in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), 2.0):
		for point in contour:
			if flip:
				point.x = image.get_width() - point.x
			points.append(DesktopWindowController.FOOT + (point + offset) * scale)
	# Native X11 supports one input polygon: envelope includes detached hair/ribbons.
	var polygon := Geometry2D.convex_hull(points)
	frames[key] = {"texture":texture, "image":image, "offset":offset, "scale":scale,
		"flip":flip, "polygon":polygon}

func key_for(state: int, facing: float, seconds: float, eye_frame: int, approaching: bool) -> String:
	var sign := 1 if facing >= 0 else -1
	if state in [Pet.State.DRAGGED, Pet.State.FALL]:
		return "drag%d" % sign
	if state == Pet.State.INTERACT and eye_frame >= 0:
		return "turn%d" % clampi(eye_frame - 5, 0, 4) if eye_frame >= 5 else "eye%d" % eye_frame
	if state == Pet.State.WALK or (state == Pet.State.APPROACH and approaching):
		return "walk%d_%d" % [sign, int(seconds * 6) % (8 if character_id == "A" else 4)]
	return "idle%d" % (int(seconds) % 2)

func opaque_at(key: String, point: Vector2) -> bool:
	if not frames.has(key):
		return false
	var frame: Dictionary = frames[key]
	var pixel: Vector2 = (point - DesktopWindowController.FOOT) / frame.scale - frame.offset
	var image: Image = frame.image
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= image.get_width() or pixel.y >= image.get_height():
		return false
	if frame.flip:
		pixel.x = image.get_width() - 1 - floorf(pixel.x)
	return image.get_pixelv(Vector2i(pixel)).a > 0.08
