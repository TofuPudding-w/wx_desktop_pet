class_name HugSequence
extends RefCounted

const SCALE := 256.0 / 713.0
const SPACING := 411.0 * SCALE
const OFFSET := Vector2(-747.5, -713)
const HOLD_REPEATS := 3
const DURATIONS := [1.0 / 6.0, 1.0 / 6.0, 0.5, 0.5]
const FRAMES := [preload("res://assets/characters/hug/1.png"), preload("res://assets/characters/hug/2.png"), preload("res://assets/characters/hug/3.png"), preload("res://assets/characters/hug/4.png")]

static func total_duration(durations: Array = DURATIONS, repeats: int = HOLD_REPEATS) -> float:
	return (float(durations[0]) + float(durations[1])) + repeats * (float(durations[2]) + float(durations[3]))

static func frame_at(seconds: float, durations: Array = DURATIONS, repeats: int = HOLD_REPEATS) -> int:
	var order: Array[int] = [0, 1]
	for _i in repeats:
		order.append_array([2, 3])
	var end := 0.0
	for index in order:
		end += float(durations[index])
		if seconds < end - 0.000001:
			return index
	return -1

static func apply(sprite: Sprite2D, index: int) -> void:
	sprite.texture = FRAMES[index]
	sprite.centered = false
	sprite.offset = OFFSET
	sprite.scale = Vector2.ONE * SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
