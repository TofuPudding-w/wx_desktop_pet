extends Node2D

const FONT = preload("res://assets/fonts/DroidSansFallbackFull.ttf")

func _ready() -> void:
	var window := get_window()
	window.borderless = false
	window.always_on_top = false
	window.unfocusable = false
	window.transparent = false
	window.transparent_bg = false
	window.mouse_passthrough_polygon = PackedVector2Array()
	window.size = Vector2i(760, 490)
	window.content_scale_size = Vector2i(760, 490)
	window.title = "忘羡对视预览 · 待机对齐"
	$Pair.start()

func _process(_delta: float) -> void:
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			$Pair.start()
		KEY_1:
			$Pair.show_idle()
		KEY_2:
			$Pair.show_first_frame()
		KEY_UP:
			$Pair.set_fps($Pair.fps + 0.5)
		KEY_DOWN:
			$Pair.set_fps($Pair.fps - 0.5)
		KEY_R:
			var x: float = $Pair/WeiWuxian.position.x
			$Pair/WeiWuxian.position.x = $Pair/LanWangji.position.x
			$Pair/LanWangji.position.x = x
			$Pair.start()
		_:
			return
	get_viewport().set_input_as_handled()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 760, 490), Color("e4e8ef"))
	draw_string(FONT, Vector2(25, 35), "对视预览：%.1f FPS（试播速度）· 共用待机缩放" % $Pair.fps, HORIZONTAL_ALIGNMENT_LEFT, 710, 20, Color("253346"))
	draw_line(Vector2(60, 330), Vector2(700, 330), Color("8995a6"), 1)
	var status := "待机第 1 帧"
	if $Pair.blocked:
		status = "站位不符：必须魏无羡在左、蓝忘机在右，对视已禁用"
	elif $Pair.showing_eye:
		status = "对视第 %d / 5 帧" % ($Pair/WeiWuxian/EyeContact/Sprite.frame + 1)
	draw_string(FONT, Vector2(25, 369), status, HORIZONTAL_ALIGNMENT_LEFT, 710, 18, Color("253346"))
	draw_string(FONT, Vector2(25, 405), "空格：重播   1：待机首帧   2：对视首帧（对比位置）", HORIZONTAL_ALIGNMENT_LEFT, 710, 18, Color("253346"))
	draw_string(FONT, Vector2(25, 441), "↑ / ↓：试播调速   R：交换站位，检查对视限制", HORIZONTAL_ALIGNMENT_LEFT, 710, 18, Color("253346"))
