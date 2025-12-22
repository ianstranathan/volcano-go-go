extends AnimatableBody2D

class_name MoveablePlatform

var velocity: Vector2 = Vector2.ZERO
var last_position: Vector2 = Vector2.ZERO

func _physics_process(delta):
	# Calculate velocity based on movement since last frame
	velocity = (global_position - last_position) / delta
	last_position = global_position


func get_velocity() -> Vector2:
	return velocity
