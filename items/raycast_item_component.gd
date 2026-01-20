extends Node2D

# -- TODO
# -- this is really more of an interface than a component now
class_name RayCastItemComponent

signal intersected_something( pos_or_null )
signal target_position_changed( the_target_position: Vector2)
@onready var ray = $RayCast2D


var ray_dir_fn: Callable

# -- NOTE
# -- Maybe pass this all in one signal 
func _physics_process(_delta: float) -> void:
	if ray_dir_fn:
		ray_dir_fn.call( ray )
		#ray.look_at(input_manager.aiming_pos())
		emit_signal("intersected_something", get_intersection_pos())
		emit_signal("target_position_changed", ray.to_global(ray.target_position))


func get_intersection_pos():
	if ray.is_colliding():
		return ray.get_collision_point()
	else:
		return null


func initialize_ray( ray_dist: float, _ray_dir_fn: Callable):
	ray_dir_fn = _ray_dir_fn
	ray.target_position = Vector2(ray_dist, 0.0)
