extends CharacterBody2D

var pos_fn: Callable
var dx_fn: Callable
var dir = 1.0

@export var move_speed = 100.0

func _physics_process(delta: float) -> void:
	velocity += delta * get_gravity()
	if pos_fn:
		var pos_fn_val: float = pos_fn.call( global_position.x )
		var diff = global_position.y - pos_fn_val
		if diff < 0:
			# -- fake bouyancy
			velocity += diff * delta * get_gravity()
	move_and_slide()
	#if _x_boundary_upper and _x_boundary_lower:
		#velocity.x = dir * move_speed
		#move_and_slide()
		#if global_position.x >=_x_boundary_upper or global_position.x <=_x_boundary_lower:
			#dir *= -1.0

var _x_boundary_upper: float 
var _x_boundary_lower: float

func set_level_extens(x_boundaries: Vector2) -> void:
	_x_boundary_lower = x_boundaries.x + $CollisionShape2D.shape.size.x / 2.
	_x_boundary_upper = x_boundaries.y - $CollisionShape2D.shape.size.x / 2.
