class_name Pet
extends Node2D

signal state_changed(previous: int, current: int)
signal drag_started(pet: Pet)
signal menu_requested(pet: Pet)
enum State { IDLE, WALK, DRAGGED, FALL, APPROACH, INTERACT }
var state: State = State.IDLE
var character_id := "A"
var display_name := "魏无羡"
var tint := Color("79b8ed")
var speed := 80.0
var foot := Vector2.ZERO
var facing := 1.0
var paused := false
var menu_open := false
var input_button_events := 0
var bubble := ""
var heart := false
var controller: DesktopWindowController
var drag_offset := Vector2.ZERO
var velocity_y := 0.0
var state_time := 0.0
var idle_duration := 2.0
var animation_time := 0.0
var target_x := 0.0
var approach_walk_stop := 40.0
var interaction_frame := -1
var artwork: PetArtwork
var art_sprite: Sprite2D
var art_key := ""
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
	idle_duration = rng.randf_range(6.0, 12.0)
	controller.move_foot(foot)
	artwork = PetArtwork.new()
	artwork.setup(character_id)
	art_sprite = Sprite2D.new()
	art_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art_sprite.position = DesktopWindowController.FOOT
	add_child(art_sprite)
	refresh_art()

func change_state(next: State) -> void:
	if state == next:
		return
	var previous := state
	state = next
	state_time = 0.0
	if next == State.IDLE:
		idle_duration = rng.randf_range(6.0, 12.0)
	if next == State.FALL:
		velocity_y = 0
	if next != State.INTERACT:
		interaction_frame = -1
	refresh_art()
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
		input_button_events += 1
		if "--trace-input" in OS.get_cmdline_user_args():
			print("INPUT ", character_id, " ", event, " state=", State.keys()[state])
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			stop_drag()
			return
		# Let menu Controls handle their own left clicks instead of starting a drag.
		if menu_open and DesktopWindowController.MENU.has_point(event.position):
			return
		if not event.pressed or artwork == null or not artwork.opaque_at(art_key, event.position):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			start_drag(Vector2(DisplayServer.mouse_get_position()))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
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
	refresh_art()
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
				if foot.x <= area.position.x + DesktopWindowController.FOOT.x or foot.x >= area.end.x - DesktopWindowController.FOOT.x:
					facing *= -1
					change_state(State.IDLE)
				elif state_time >= 2.5:
					change_state(State.IDLE)
			State.APPROACH:
				foot.x = move_toward(foot.x, target_x, speed * delta)
				# Switch pose and position together: never slide using idle artwork.
				if absf(foot.x - target_x) <= approach_walk_stop:
					foot.x = target_x
	foot = DesktopWindowController.clamp_foot(foot, area)

func set_bubble(text: String) -> void:
	bubble = text
	if controller:
		controller.update_input(not text.is_empty() or menu_open)
	queue_redraw()

func refresh_art() -> void:
	if artwork == null:
		return
	var seconds := 0.0 if paused or menu_open else state_time
	var key := artwork.key_for(state, facing, seconds, interaction_frame, absf(foot.x - target_x) > 0.01)
	if key == art_key:
		return
	art_key = key
	var frame: Dictionary = artwork.frames[key]
	art_sprite.texture = frame.texture
	art_sprite.offset = frame.offset + frame.texture.get_size() * 0.5
	art_sprite.scale = Vector2.ONE * frame.scale
	art_sprite.flip_h = frame.flip
	controller.update_input(menu_open or not bubble.is_empty(), frame.polygon)

func _draw() -> void:
	if controller and controller.debug_mode:
		draw_string(font, Vector2(12, 118), display_name + " · " + State.keys()[state], HORIZONTAL_ALIGNMENT_LEFT, 296, 14, Color.WHITE)

static func rounded(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style
