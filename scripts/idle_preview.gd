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
	window.size = Vector2i(600, 390)
	window.content_scale_size = Vector2i(600, 390)
	window.title = "忘羡待机素材预览 · 1 FPS"
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 600, 390), Color("e4e8ef"))
	draw_string(FONT, Vector2(30, 38), "待机预览：256 px · 平滑过滤 · 1 FPS", HORIZONTAL_ALIGNMENT_LEFT, 540, 20, Color("253346"))
	draw_line(Vector2(60, 330), Vector2(540, 330), Color("8995a6"), 1)
	draw_string(FONT, Vector2(185, 362), "魏无羡", HORIZONTAL_ALIGNMENT_LEFT, 150, 18, Color("253346"))
	draw_string(FONT, Vector2(345, 362), "蓝忘机", HORIZONTAL_ALIGNMENT_LEFT, 150, 18, Color("253346"))
