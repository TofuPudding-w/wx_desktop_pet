extends Node2D

const FONT = preload("res://assets/fonts/DroidSansFallbackFull.ttf")
# Both source canvases are 631px wide; use the same scale, not equal heights.
const LEFT_EDGE := 140.0
const RIGHT_EDGE := 600.0
const LWJ_LEFT_EDGE := 400.0
const LWJ_RIGHT_EDGE := 860.0
const LWJ_SPEED_RATIO := 0.85
var moving := true
var direction := 1.0
var lwj_direction := 1.0
var walk_speed := 80.0

func _ready() -> void:
	var window := get_window()
	window.borderless = false
	window.always_on_top = false
	window.unfocusable = false
	window.transparent = false
	window.transparent_bg = false
	window.mouse_passthrough_polygon = PackedVector2Array()
	window.size = Vector2i(1000, 450)
	window.content_scale_size = Vector2i(1000, 450)
	window.title = "忘羡走路预览 · 图片等宽 · 6 FPS"
	$LanWangji/Sprite.play("walk")
	set_direction(1.0)
	queue_redraw()

func set_direction(value: float) -> void:
	set_wwx_direction(value)
	set_lwj_direction(value)

func set_wwx_direction(value: float) -> void:
	direction = value
	$WeiWuxian/Sprite.flip_h = false
	$WeiWuxian/Sprite.play("left_to_right" if direction > 0 else "right_to_left")

func set_lwj_direction(value: float) -> void:
	lwj_direction = value
	$LanWangji/Sprite.flip_h = lwj_direction < 0

func _process(delta: float) -> void:
	if not moving:
		return
	$WeiWuxian.position.x += direction * walk_speed * delta
	if $WeiWuxian.position.x >= RIGHT_EDGE:
		$WeiWuxian.position.x = RIGHT_EDGE
		set_wwx_direction(-1.0)
	elif $WeiWuxian.position.x <= LEFT_EDGE:
		$WeiWuxian.position.x = LEFT_EDGE
		set_wwx_direction(1.0)
	$LanWangji.position.x += lwj_direction * walk_speed * LWJ_SPEED_RATIO * delta
	if $LanWangji.position.x >= LWJ_RIGHT_EDGE:
		$LanWangji.position.x = LWJ_RIGHT_EDGE
		set_lwj_direction(-1.0)
	elif $LanWangji.position.x <= LWJ_LEFT_EDGE:
		$LanWangji.position.x = LWJ_LEFT_EDGE
		set_lwj_direction(1.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			moving = not moving
		KEY_UP:
			walk_speed = minf(200.0, walk_speed + 10.0)
		KEY_DOWN:
			walk_speed = maxf(20.0, walk_speed - 10.0)
		KEY_LEFT:
			set_direction(-1.0)
		KEY_RIGHT:
			set_direction(1.0)
		_:
			return
	get_viewport().set_input_as_handled()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1000, 450), Color("e4e8ef"))
	var mode := "来回走动" if moving else "原地播放"
	draw_string(FONT, Vector2(30, 35), "忘羡走路：6 FPS · 图片等宽约 236.5 px · " + mode, HORIZONTAL_ALIGNMENT_LEFT, 940, 20, Color("253346"))
	draw_line(Vector2(30, 350), Vector2(970, 350), Color("8995a6"), 1)
	draw_string(FONT, Vector2(30, 387), "速度：魏无羡 %d / 蓝忘机 %d px/s   ↑↓ 调速   ←→ 朝向   空格：走动 / 原地" % [int(walk_speed), int(walk_speed * LWJ_SPEED_RATIO)], HORIZONTAL_ALIGNMENT_LEFT, 940, 18, Color("253346"))
	draw_string(FONT, Vector2(30, 422), "魏无羡：左右独立帧   蓝忘机：同组帧左右翻转   保留原画比例与身高差", HORIZONTAL_ALIGNMENT_LEFT, 940, 18, Color("253346"))
