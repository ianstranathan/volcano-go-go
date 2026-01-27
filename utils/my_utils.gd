extends Node


func sprite_size(s: Sprite2D) -> Vector2:
	return s.texture.get_size() * s.scale
