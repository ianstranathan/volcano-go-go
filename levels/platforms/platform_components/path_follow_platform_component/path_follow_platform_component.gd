extends Path2D
class_name PathFollowPlatformComponent

"""
Small utility class to make setting platform paths more ergonomic
"""
func _ready() -> void:
	assert($PathFollow2D)
	if curve:
		curve = curve.duplicate()

func set_progress_ratio(r: float) -> void:
	$PathFollow2D.progress_ratio = r

func set_loop(b: bool) -> void:
	$PathFollow2D.loop = b

func get_path_global_position() -> Vector2:
	return $PathFollow2D.global_position
	
func get_progress_ratio() -> float:
	return $PathFollow2D.progress_ratio
