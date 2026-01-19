extends Node2D

# TODO:
# -- move icon to UI component
@export var icon: Texture2D # UI representation of item
# -- item interface is a component
@export var item_interface: ItemInterface
# -- 
@export var max_deploy_distance: float = 800 # in px
@onready var ray: RayCast2D = $RayCast2D
@onready var rope: Line2D = $Line2D

var input_manager: InputManager
var player_ref: Player
var is_deployed: bool = false

func _ready() -> void:
	assert(input_manager and item_interface)
	
	# ---------------------------------------------- interface
	item_interface.can_use_fn = func(): return (!is_deployed and ray.is_colliding())
	item_interface.used.connect( deploy )
	item_interface.stopped.connect( func(): pass )
	
	# --
	$Area2D/CollisionShape2D.disabled = true
	$Area2D.body_entered.connect( func(body): 
		if body is Player:
			var target_pos: Vector2 = to_global(rope.get_point_position(1))
			body.start_climbing( (target_pos - global_position).normalized() ))

	ray.target_position = Vector2(max_deploy_distance, 0.0)
	# -- 
	rope.hide()


func _physics_process(_delta: float) -> void:
	if !is_deployed:
		ray.look_at(input_manager.aiming_pos())
		$Area2D.global_rotation = PI/2.0 + ray.global_rotation


func deploy():
	# --! we need to tween these properties
	is_deployed = true
	# --
	var ray_intersect_pos = ray.get_collision_point()
	rope.set_point_position(1, to_local(ray_intersect_pos))
	
	$Area2D/CollisionShape2D.shape.size.y = global_position.distance_to( ray_intersect_pos )
	$Area2D/CollisionShape2D.set_deferred("disabled", false)
	
	rope.show()
