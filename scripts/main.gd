extends Node

var controller := DesktopWindowController.new()
var foot := Vector2(500, 600)
var dragged := false
var offset := Vector2.ZERO

func _ready() -> void:
	controller.configure(get_window(), "CP Pet M0", false)
	foot = DesktopWindowController.clamp_foot(foot, controller.work_area())
	controller.move_foot(foot)
	get_window().close_requested.connect(func(): get_tree().quit())
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array([Vector2(72,104), Vector2(168,104), Vector2(168,232), Vector2(72,232)])
	shape.color = Color("79b8ed")
	add_child(shape)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			get_tree().quit()
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragged = event.pressed
			offset = foot - Vector2(DisplayServer.mouse_get_position())

func _process(_delta: float) -> void:
	if dragged:
		foot = controller.clamp_foot(Vector2(DisplayServer.mouse_get_position()) + offset, controller.work_area())
		controller.move_foot(foot)
