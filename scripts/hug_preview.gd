extends Node2D

const FONT = preload("res://assets/fonts/DroidSansFallbackFull.ttf")
var elapsed := 0.0
var durations: Array = HugSequence.DURATIONS
var hold_repeats := HugSequence.HOLD_REPEATS
var playing := false
var mode := "idle"
var combined := Sprite2D.new()
var idle_sprites: Array[Sprite2D] = []
var a_x := 340.0 - HugSequence.SPACING - 80
var target_x := 340.0 - HugSequence.SPACING
var anchor := Vector2(340, 340)
var walking := false
var artwork := PetArtwork.new()

func _ready() -> void:
	var loader := ContentLoader.new()
	var pool := loader.interactions(loader.read_json("res://data/interactions.json", {}), {})
	if pool.has("hug"):
		durations = pool.hug.frame_durations
		hold_repeats = int(pool.hug.hold_repeats)
	var window := get_window()
	window.borderless = false
	window.always_on_top = false
	window.unfocusable = false
	window.transparent = false
	window.transparent_bg = false
	window.size = Vector2i(660, 470)
	window.content_scale_size = window.size
	window.title = "忘羡拥抱预览"
	artwork.setup("A")
	for id in ["A", "B"]:
		var art := PetArtwork.new()
		art.setup(id)
		var sprite := Sprite2D.new()
		var frame: Dictionary = art.frames.idle0
		sprite.texture = frame.texture
		sprite.centered = false
		sprite.offset = frame.offset
		sprite.scale = Vector2.ONE * frame.scale
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)
		idle_sprites.append(sprite)
	add_child(combined)
	combined.position = anchor
	start()
	if "--capture-review" in OS.get_cmdline_user_args():
		capture_review.call_deferred()

func start() -> void:
	elapsed = 0
	playing = true
	walking = true
	a_x = target_x - 80
	mode = "approach"

func _process(delta: float) -> void:
	if playing:
		elapsed += delta
		if walking:
			a_x = move_toward(a_x, target_x, 80 * delta)
			if target_x - a_x <= 40:
				a_x = target_x
				walking = false
				elapsed = 0
				mode = "hug"
		elif HugSequence.frame_at(elapsed, durations, hold_repeats) < 0:
			playing = false
			mode = "idle"
	var index := HugSequence.frame_at(elapsed, durations, hold_repeats) if mode == "hug" else -1
	combined.visible = index >= 0
	if index >= 0:
		HugSequence.apply(combined, index)
	for i in 2:
		idle_sprites[i].visible = index < 0
		idle_sprites[i].position = Vector2(a_x if i == 0 else anchor.x, anchor.y)
	var key := "walk1_%d" % (int(elapsed * 6) % 8) if walking else "idle0"
	var frame: Dictionary = artwork.frames[key]
	idle_sprites[0].texture = frame.texture
	idle_sprites[0].offset = frame.offset
	idle_sprites[0].scale = Vector2.ONE * frame.scale
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			start()
		elif event.keycode in [KEY_1, KEY_2]:
			playing = false
			walking = false
			a_x = target_x
			elapsed = 0
			mode = "idle" if event.keycode == KEY_1 else "hug"
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 660, 470), Color("e4e8ef"))
	draw_string(FONT, Vector2(20, 30), "拥抱预览 · 3/4 帧循环 %d 次 · 直接回到待机" % hold_repeats, HORIZONTAL_ALIGNMENT_LEFT, 620, 20, Color("253346"))
	draw_line(Vector2(40, 340), Vector2(620, 340), Color("8995a6"))
	draw_string(FONT, Vector2(20, 385), "站位 %.2fpx · 走路提前 40px 结束 · %s" % [HugSequence.SPACING, mode], HORIZONTAL_ALIGNMENT_LEFT, 620, 17, Color("253346"))
	draw_string(FONT, Vector2(20, 425), "空格：靠近并重播   1：独立待机   2：拥抱首帧   Esc：关闭", HORIZONTAL_ALIGNMENT_LEFT, 620, 17, Color("253346"))

func capture_review() -> void:
	playing = false
	walking = false
	a_x = target_x
	for sample in [["idle", 0.0], ["hug", 0.0], ["hug", 0.2], ["hug", 0.4], ["hug", 0.9]]:
		mode = sample[0]
		elapsed = sample[1]
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/wx-hug-review-%s-%s.png" % [mode, str(elapsed)])
	print("HUG REVIEW: captured idle and all four combined frames")
	get_tree().quit()
