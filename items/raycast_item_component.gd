extends Node2D

class_name RayCastItemComponent

signal intersected_something( pos_or_null )
signal target_position_changed( the_target_position: Vector2)
@onready var ray = $RayCast2D

## input manager is dyanimically assigned by an item (i.e. parent)
# -- we need this to be able to manipulate item's direction
# -- note: it feels a little convoluted to send signals accross
# -- intermediary signal buses (i.e. the player or item manager,
# -- but the item has to be able to decide what it's doing and the
# -- rest should declaritvely react
var input_manager: InputManager


# -- NOTE
# -- Maybe pass this all in one signal 
func _physics_process(_delta: float) -> void:
	ray.look_at(input_manager.aiming_pos())
	emit_signal("intersected_something", get_intersection_pos())
	emit_signal("target_position_changed", ray.to_global(ray.target_position))


func get_intersection_pos():
	if ray.is_colliding():
		return ray.get_collision_point()
	else:
		return null


func initialize_input( ray_dist: float, _input_manager: InputManager):
	ray.target_position = Vector2(ray_dist, 0.0)
	input_manager = _input_manager
	assert(input_manager)
