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


func align_sprite_to_world_origin_offset(s: CanvasItem) -> Vector2:
	assert(s is Sprite2D or s is AnimatedSprite2D)
	if s is AnimatedSprite2D:
		var _texture = s.sprite_frames.get_frame_texture(s.animation, s.frame)
		return (_texture.get_size() * s.scale) / 2.
	return sprite_size(s) / 2.


func print_parents_recursive(current_node: Node) -> void:
	if current_node == null:
		return
	var parent: Node = current_node.get_parent()
	if parent:
		print("-> Parent: %s (%s)" % [parent.name, parent.get_class()])
		print_parents_recursive(parent)
	else:
		print("--- Reached Scene Root / Top ---")
