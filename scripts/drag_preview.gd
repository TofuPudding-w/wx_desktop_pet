extends "res://scripts/walking_preview.gd"

const GROUND := 480.0
var dragged_pet: Node2D
var drag_offset := Vector2.ZERO
var falling: Dictionary = {}

func _ready() -> void:
	super._ready()
	get_window().size = Vector2i(1000, 600)
	get_window().content_scale_size = Vector2i(1000, 600)
	get_window().title = "忘羡拖起预览 · 左键拖拽"
	get_window().focus_exited.connect(end_drag)
	# Start stationary so the user can inspect and pick up either character.
	moving = false
	queue_redraw()

func set_wwx_direction(value: float) -> void:
	super.set_wwx_direction(value)
	$WeiWuxian/DragPose.face(value)

func set_lwj_direction(value: float) -> void:
	super.set_lwj_direction(value)
	$LanWangji/DragPose.face(value)

func visible_art(pet: Node2D) -> Node2D:
	return pet.get_node("DragPose") if pet.get_node("DragPose").visible else pet.get_node("Sprite")

func hit_pet(pet: Node2D, point: Vector2) -> bool:
	var art = visible_art(pet)
	var texture: Texture2D
	if art is AnimatedSprite2D:
		texture = art.sprite_frames.get_frame_texture(art.animation, art.frame)
	else:
		texture = art.texture
	var pixel: Vector2 = art.to_local(point) - art.offset
	if art.centered:
		pixel += texture.get_size() * 0.5
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= texture.get_width() or pixel.y >= texture.get_height():
		return false
	if art.flip_h:
		pixel.x = texture.get_width() - 1 - floorf(pixel.x)
	return texture.get_image().get_pixelv(Vector2i(pixel)).a > 0.05

func begin_drag(pet: Node2D, point: Vector2) -> void:
	if dragged_pet != null:
		end_drag()
	falling.erase(pet)
	dragged_pet = pet
	drag_offset = pet.position - point
	pet.get_node("Sprite").hide()
	pet.get_node("DragPose").show()

func move_drag(point: Vector2) -> void:
	if dragged_pet == null:
		return
	var limits := bounds_for(dragged_pet)
	var desired := point + drag_offset
	# The full drag canvas remains visible; no artwork is cropped or stretched.
	dragged_pet.position = Vector2(clampf(desired.x, limits.x, limits.y), clampf(desired.y, 296.0, GROUND))

func end_drag() -> void:
	if dragged_pet == null:
		return
	falling[dragged_pet] = 0.0
	dragged_pet = null

func bounds_for(pet: Node2D) -> Vector2:
	return Vector2(LEFT_EDGE, RIGHT_EDGE) if pet == $WeiWuxian else Vector2(LWJ_LEFT_EDGE, LWJ_RIGHT_EDGE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Last drawn character wins where images overlap; transparent pixels pass through.
			for pet in [$LanWangji, $WeiWuxian]:
				if hit_pet(pet, get_global_mouse_position()):
					begin_drag(pet, get_global_mouse_position())
					get_viewport().set_input_as_handled()
					break
		else:
			end_drag()
	elif event is InputEventMouseMotion and dragged_pet != null:
		move_drag(get_global_mouse_position())

func _process(delta: float) -> void:
	if dragged_pet != null:
		move_drag(get_global_mouse_position())
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			end_drag()
	step_characters(delta)

func step_characters(delta: float) -> void:
	for pet in [$WeiWuxian, $LanWangji]:
		if pet == dragged_pet:
			continue
		if falling.has(pet):
			falling[pet] += 1000.0 * delta
			pet.position.y = minf(GROUND, pet.position.y + falling[pet] * delta)
			if pet.position.y >= GROUND:
				falling.erase(pet)
				pet.get_node("DragPose").hide()
				pet.get_node("Sprite").show()
			continue
		if not moving:
			continue
		var is_wwx: bool = pet == $WeiWuxian
		var facing := direction if is_wwx else lwj_direction
		var speed := walk_speed if is_wwx else walk_speed * LWJ_SPEED_RATIO
		var limits := bounds_for(pet)
		pet.position.x += facing * speed * delta
		if pet.position.x <= limits.x or pet.position.x >= limits.y:
			pet.position.x = clampf(pet.position.x, limits.x, limits.y)
			var next_direction := 1.0 if pet.position.x <= limits.x else -1.0
			if is_wwx:
				set_wwx_direction(next_direction)
			else:
				set_lwj_direction(next_direction)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1000, 600), Color("e4e8ef"))
	draw_string(FONT, Vector2(30, 35), "拖起预览：左键按住人物拖动，松手落回底部", HORIZONTAL_ALIGNMENT_LEFT, 940, 22, Color("253346"))
	draw_line(Vector2(30, GROUND), Vector2(970, GROUND), Color("8995a6"), 1)
	draw_string(FONT, Vector2(30, 519), "← / →：切换朝向（拖动时也可用）   空格：走动 / 原地播放", HORIZONTAL_ALIGNMENT_LEFT, 940, 18, Color("253346"))
	draw_string(FONT, Vector2(30, 551), "魏无羡：左右独立画稿   蓝忘机：单张翻转   原图比例保持不变", HORIZONTAL_ALIGNMENT_LEFT, 940, 18, Color("253346"))
	draw_string(FONT, Vector2(30, 583), "↑ / ↓ 调速：魏无羡 %d / 蓝忘机 %d px/s；走路仍为 6 FPS" % [int(walk_speed), int(walk_speed * LWJ_SPEED_RATIO)], HORIZONTAL_ALIGNMENT_LEFT, 940, 17, Color("253346"))
