extends Node2D

@export_range(1.0, 8.0, 0.5) var fps := 4.0
var elapsed := 0.0
var playing := false
var showing_eye := false
var blocked := false

func _ready() -> void:
	show_idle()

func order_allowed() -> bool:
	return $WeiWuxian.global_position.x < $LanWangji.global_position.x

func eye_sprites() -> Array:
	return [$WeiWuxian/EyeContact/Sprite, $LanWangji/EyeContact/Sprite]

func show_idle() -> void:
	playing = false
	showing_eye = false
	blocked = false
	for pet in [$WeiWuxian, $LanWangji]:
		pet.get_node("EyeContact").hide()
		pet.get_node("Idle").show()
		var sprite = pet.get_node("Idle/Sprite")
		# Exact baseline frame for checking the transition; idle's resource stays 1 FPS.
		sprite.stop()
		sprite.frame = 0

func start() -> bool:
	if not show_first_frame():
		return false
	playing = true
	return true

func show_first_frame() -> bool:
	show_idle()
	if not order_allowed():
		blocked = true
		return false
	elapsed = 0.0
	showing_eye = true
	for pet in [$WeiWuxian, $LanWangji]:
		pet.get_node("Idle").hide()
		pet.get_node("EyeContact").show()
	for sprite in eye_sprites():
		sprite.stop()
		sprite.frame = 0
		sprite.flip_h = false
	return true

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if showing_eye and not order_allowed():
		show_idle()
		blocked = true
		return
	if not playing:
		return
	elapsed += delta
	var index := mini(int(elapsed * fps), 4)
	# One clock advances both characters; no independent looping or mirroring.
	for sprite in eye_sprites():
		sprite.frame = index
	if elapsed >= 5.0 / fps:
		playing = false

func set_fps(value: float) -> void:
	# Keep the current fractional frame when changing preview speed.
	elapsed = elapsed * fps / clampf(value, 1.0, 8.0)
	fps = clampf(value, 1.0, 8.0)
