extends Node2D

# TODO:
@export var icon: Texture2D # UI representation of item
@export var max_deploy_distance: float = 800 # in px
@onready var item_interface: ItemInterface
@onready var ray: RayCast2D = $RayCast2D
@onready var rope: Line2D = $Line2D
var input_manager: InputManager
var is_deployed: bool = false

func _ready() -> void:
	assert(item_interface)
	item_interface.can_use_checked.connect( func():
		return ray.is_colliding() and !is_deployed)
	$Area2D.body_entered.connect( func(body): if body is Player: body.start_climbing())
	ray.target_position = Vector2(max_deploy_distance, 0.0)


func _physics_process(_delta: float) -> void:
	ray.look_at(input_manager.aiming_pos())
	$Area2D.global_rotation = ray.global_rotation
	
	if (input_manager.just_pressed_action("use_item") and 
		ray.is_colliding() and !is_deployed):
		deploy()
	# -- give a visual indication that it can't be used?

func deploy():
	is_deployed = true
	var ray_intersect_pos = ray.get_collision_point()
	rope.set_point_position(1, to_local(ray_intersect_pos))
	# -- make the height of the area2d the distance from the input manager to the intersection pt
	$Area2D/CollisionShape2D.shape.size.y = ray_intersect_pos.distance_to(input_manager.global_position)
	rope.show()
