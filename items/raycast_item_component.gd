extends Node2D

class_name RayCastItemComponent

signal intersected_something( pos_or_null )
@onready var ray = $RayCast2D
## input manager is dyanimically assigned by an item (i.e. parent)
var input_manager: InputManager


func _physics_process(_delta: float) -> void:
	ray.look_at(input_manager.aiming_pos())
	emit_signal("intersected_something", get_intersection_pos())


func get_intersection_pos():
	if ray.is_colliding():
		return ray.get_collision_point()
	else:
		return null


func initialize_input( ray_dist: float, _input_manager: InputManager):
	ray.target_position = Vector2(ray_dist, 0.0)
	input_manager = _input_manager
	assert(input_manager)
