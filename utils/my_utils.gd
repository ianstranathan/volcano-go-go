extends Node


func sprite_size(s: Sprite2D) -> Vector2:
	return s.texture.get_size() * s.scale


func curve_sample_t(timer: Timer, reversed=false):
	var t  = (timer.wait_time - timer.time_left) / timer.wait_time
	if reversed:
		t = (1. - t)
	return t
