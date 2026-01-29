extends Node2D


@export var rope_ladder_spawn_scene: PackedScene
# -- move icon to UI component
@export var icon: Texture2D # UI representation of item
# -- item interface is a component
@export var item_interface: ItemInterface
# -- 
@export var max_deploy_distance: float = 800 # in px

@onready var ray_interface := $RaycastItemComponent

var deployed = false
var can_deploy = false
var items_container_ref: Node2D

#emit_signal("intersected_something", get_intersection_pos())
		#emit_signal("target_position_changed", global_target_pos())
func _ready() -> void:
	assert(item_interface)
	# ---------------------------------------------- raycast interface
	# -- NOTE clean this up maybe, default to no arity?
	ray_interface.intersected_something.connect( func(pos_or_null):
		can_deploy = true if pos_or_null else false)
	ray_interface.initialize_ray(max_deploy_distance, func(_r: RayCast2D): pass)
	ray_interface.global_rotation = -PI/ 2.0
	# ---------------------------------------------- item interface
	item_interface.can_use_fn = func(): return !deployed and can_deploy
	item_interface.used.connect( deploy )
	item_interface.stopped.connect( func(): pass )
	item_interface.destroyed.connect( func(): call_deferred("queue_free"))


func deploy():
	deployed = true
	var rope_ladder = rope_ladder_spawn_scene.instantiate()
	rope_ladder.target = ray_interface.get_intersection_pos()
	rope_ladder.global_position = global_position
	#print(rope_ladder.target)
	items_container_ref.add_child( rope_ladder )
	
	call_deferred("queue_free")
