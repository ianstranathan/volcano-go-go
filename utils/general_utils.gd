extends Node


func sprite_size(s: Sprite2D) -> Vector2:
	return s.texture.get_size() * s.scale


func curve_sample_t(timer: Timer, reversed=false):
	var t  = (timer.wait_time - timer.time_left) / timer.wait_time
	if reversed:
		t = (1. - t)
	return t


func is_in_same_direction_1D(x: float, y: float) -> bool:
	return x * y > 0.0


func is_in_opposite_direction_1D( x: float, y: float) -> bool:
	# -- this is actually then <=, not <, careful
	#return not is_in_same_direction_1D(x, y)
	return x * y < 0.0
