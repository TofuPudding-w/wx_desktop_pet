class_name HugOverlay
extends Window

const ORIGIN := Vector2(320, 376)
var pets: Array[Pet] = []
var manager: InteractionManager
var sprite := Sprite2D.new()
var art := PetArtwork.new()
var active := false
var size_factor := 1.0
var frame_key := "hug0"

func setup(pair: Array[Pet], interaction: InteractionManager, debug: bool) -> void:
	pets = pair
	manager = interaction
	title = "CP Pet Hug"
	size = Vector2i(512, 384)
	content_scale_size = size
	borderless = not debug
	transparent = not debug
	transparent_bg = not debug
	always_on_top = true
	unfocusable = true
	unresizable = true
	visible = false
	add_child(sprite)
	sprite.position = ORIGIN
	for i in 4:
		art.add_frame("hug%d" % i, HugSequence.FRAMES[i], HugSequence.OFFSET, HugSequence.SCALE)
	window_input.connect(handle_input)
	close_requested.connect(func(): get_tree().quit())

func sync() -> void:
	var index := manager.combined_frame
	if index < 0 or pets.size() != 2:
		stop()
		return
	active = true
	for pet in pets:
		pet.art_sprite.hide()
		pet.controller.window.mouse_passthrough = true
	position = Vector2i((pets[1].foot - ORIGIN * size_factor).round())
	frame_key = "hug%d" % index
	HugSequence.apply(sprite, index)
	sprite.scale *= size_factor
	var polygon: PackedVector2Array = art.frames[frame_key].polygon.duplicate()
	for i in polygon.size():
		polygon[i] = (polygon[i] + ORIGIN - DesktopWindowController.FOOT) * size_factor
	mouse_passthrough_polygon = polygon
	show()

func stop() -> void:
	if not active:
		return
	active = false
	hide()
	for pet in pets:
		pet.art_sprite.show()
		pet.controller.window.mouse_passthrough = false
		pet.refresh_art()

func handle_input(event: InputEvent) -> void:
	if not active or not event is InputEventMouseButton or not event.pressed:
		return
	if not art.opaque_at(frame_key, event.position / size_factor - ORIGIN + DesktopWindowController.FOOT):
		return
	var mouse := Vector2(DisplayServer.mouse_get_position())
	var pet := pets[0] if mouse.x < (pets[0].foot.x + pets[1].foot.x) * 0.5 else pets[1]
	if event.button_index == MOUSE_BUTTON_LEFT:
		pet.start_drag(mouse)
		stop()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		manager.cancel()
		stop()
		pet.menu_requested.emit(pet)

func set_size_factor(value: float) -> void:
	size_factor = value
	size = Vector2i((Vector2(512, 384) * value).round())
	content_scale_size = size
	sprite.position = ORIGIN * value
