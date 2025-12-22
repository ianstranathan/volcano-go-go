extends MoveablePlatform

class_name LavableBody

## how close to the lava in pixels to count as in lava
@export var lava_dist_threshold: float = 5
@export var lava_ref: Node2D
var is_in_lava: bool = false

@export var is_falling: bool

# TODO
# --------- Melting feedback
# * timer
# * visual
# * sound

# TODO
# -- this needs to be modular (i.e. not fail when shape type changes)
## the amound popping out of the lava
@onready var lava_level_offset = $CollisionShape2D.shape.size.y / 2.


func _physics_process(delta: float) -> void:
	super(delta)
	if is_in_lava:
		var y = lava_ref.lava_fn( global_position.x) - lava_level_offset
		var a = lava_ref.angle_to_lava_fn( global_position.x)
		
		global_transform = Transform2D(lerp(global_rotation, a, delta),
									   Vector2(global_position.x, y))
		#print(lava_ref.angle_to_lav_fn( global_position.x))
	else:
		if is_falling:
			global_position.y += delta * get_gravity().y
		is_in_lava = hit_lava()


func hit_lava() -> bool:
	if lava_ref:
		return abs(global_position.y - lava_ref.lava_fn( global_position.x)) < lava_dist_threshold
	return false
