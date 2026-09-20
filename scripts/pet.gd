class_name Pet
extends Node2D

signal state_changed(previous: int, current: int)
signal drag_started(pet: Pet)
signal menu_requested(pet: Pet)
enum State { IDLE, WALK, DRAGGED, FALL, APPROACH, INTERACT }
var state: State = State.IDLE
var character_id := "A"
var display_name := "蓝蓝"
var tint := Color("79b8ed")
var speed := 80.0
var foot := Vector2.ZERO
var facing := 1.0
var paused := false
var menu_open := false
var bubble := ""
var heart := false
var controller: DesktopWindowController
var drag_offset := Vector2.ZERO
var velocity_y := 0.0
var state_time := 0.0
var idle_duration := 2.0
var animation_time := 0.0
var target_x := 0.0
var font: Font = preload("res://assets/fonts/DroidSansFallbackFull.ttf")
var rng := RandomNumberGenerator.new()

func configure(config: Dictionary, desktop: DesktopWindowController, initial: Vector2) -> void:
	character_id = config.get("id", "A")
	display_name = config.get("name", character_id)
	tint = Color(config.get("color", "79b8ed"))
	speed = float(config.get("walk_speed", 80))
	controller = desktop
	foot = initial
	rng.randomize()
	idle_duration = rng.randf_range(1.5, 3.5)
	controller.move_foot(foot)

func change_state(next: State) -> void:
	if state == next:
		return
	var previous := state
	state = next
	state_time = 0.0
	if next == State.IDLE:
		idle_duration = rng.randf_range(2.0, 4.0)
	if next == State.FALL:
		velocity_y = 0
	state_changed.emit(previous, state)

func available() -> bool:
	return not paused and not menu_open and state in [State.IDLE, State.WALK]

func start_drag(mouse: Vector2) -> void:
	# Reserve the dragged state before cancellation releases the partner.
	change_state(State.DRAGGED)
	drag_offset = foot - mouse
	drag_started.emit(self)

func stop_drag() -> void:
	if state == State.DRAGGED:
		change_state(State.FALL)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not menu_open and DesktopWindowController.BODY.has_point(event.position):
				start_drag(Vector2(DisplayServer.mouse_get_position()))
			elif not event.pressed:
				stop_drag()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			menu_requested.emit(self)

func _process(delta: float) -> void:
	if controller == null:
		return
	if state == State.DRAGGED:
		foot = Vector2(DisplayServer.mouse_get_position()) + drag_offset
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			stop_drag()
	step(minf(delta, 0.05), DesktopWindowController.work_area())
	controller.move_foot(foot)
	queue_redraw()

func step(delta: float, area: Rect2) -> void:
	animation_time += delta
	state_time += delta
	var ground := area.end.y - 8.0
	if state == State.FALL:
		velocity_y += 1200.0 * delta
		foot.y = minf(ground, foot.y + velocity_y * delta)
		if foot.y >= ground:
			change_state(State.IDLE)
	elif not paused and not menu_open:
		match state:
			State.IDLE:
				if state_time >= idle_duration:
					facing = -1.0 if rng.randf() < 0.5 else 1.0
					change_state(State.WALK)
			State.WALK:
				foot.x += facing * speed * delta
				if foot.x <= area.position.x + 120 or foot.x >= area.end.x - 120:
					facing *= -1
					change_state(State.IDLE)
				elif state_time >= 2.5:
					change_state(State.IDLE)
			State.APPROACH:
				foot.x = move_toward(foot.x, target_x, speed * delta)
	foot = DesktopWindowController.clamp_foot(foot, area)

func set_bubble(text: String) -> void:
	bubble = text
	if controller:
		controller.update_input(not text.is_empty() or menu_open)
	queue_redraw()

func _draw() -> void:
	# Code-drawn placeholders: shared foot anchor, no external animation dependency.
	var bob := sin(animation_time * 3) * 2
	if state in [State.WALK, State.APPROACH]:
		bob = absf(sin(animation_time * 12)) * -5
	var center := Vector2(120, 164 + bob)
	var dark := Color("253346")
	draw_ellipse_shadow()
	draw_circle(center + Vector2(-26, -39), 16, tint)
	draw_circle(center + Vector2(26, -39), 16, tint)
	draw_style_box(rounded(tint, 32), Rect2(80, 126 + bob, 80, 83))
	var stride := sin(animation_time * 12) * 5 if state == State.WALK else 0.0
	draw_style_box(rounded(tint.darkened(0.15), 10), Rect2(87, 205 + stride, 25, 24 - stride))
	draw_style_box(rounded(tint.darkened(0.15), 10), Rect2(128, 205 - stride, 25, 24 + stride))
	for eye_x in [-15, 15]:
		draw_circle(center + Vector2(eye_x + facing * 3, -5), 4, dark)
	draw_arc(center + Vector2(0, 3), 8, 0.15, PI - 0.15, 12, dark, 2, true)
	draw_circle(center + Vector2(-26, 7), 7, Color(1, 0.65, 0.66, 0.6))
	draw_circle(center + Vector2(26, 7), 7, Color(1, 0.65, 0.66, 0.6))
	if state == State.DRAGGED:
		draw_line(Vector2(87,180), Vector2(75,162), dark, 3, true)
		draw_line(Vector2(153,180), Vector2(165,162), dark, 3, true)
	if heart:
		var p := Vector2(120, 111)
		var pink := Color("ef7189")
		draw_circle(p + Vector2(-5,-4), 6, pink)
		draw_circle(p + Vector2(5,-4), 6, pink)
		draw_colored_polygon(PackedVector2Array([p+Vector2(-11,-2),p+Vector2(11,-2),p+Vector2(0,11)]),pink)
	if not bubble.is_empty():
		draw_style_box(rounded(Color("fffaf0"), 14), Rect2(10, 12, 220, 74))
		draw_colored_polygon(PackedVector2Array([Vector2(108,85),Vector2(130,85),Vector2(120,96)]),Color("fffaf0"))
		draw_string(font, Vector2(24,38), display_name, HORIZONTAL_ALIGNMENT_LEFT, 192, 15, tint.darkened(0.45))
		draw_string(font, Vector2(24,65), bubble, HORIZONTAL_ALIGNMENT_LEFT, 192, 17, dark)
	if controller and controller.debug_mode:
		draw_string(font, Vector2(8,101), State.keys()[state], HORIZONTAL_ALIGNMENT_LEFT, 220, 12, Color.WHITE)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(120,230), 0, Vector2(1,0.18))
	draw_circle(Vector2.ZERO, 44, Color(0.1,0.15,0.2,0.15))
	draw_set_transform(Vector2.ZERO)

static func rounded(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style
