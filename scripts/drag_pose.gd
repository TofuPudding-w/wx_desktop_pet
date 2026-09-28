extends Sprite2D

@export var right_texture: Texture2D
@export var left_texture: Texture2D

func face(direction: float) -> void:
	if direction < 0 and left_texture != null:
		texture = left_texture
		flip_h = false
	else:
		texture = right_texture
		flip_h = direction < 0
