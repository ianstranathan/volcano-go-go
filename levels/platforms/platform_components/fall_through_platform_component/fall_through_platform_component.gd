@tool
extends Node2D

class_name FallThroughPlatformComponent

@export var p: BasePlatform:
	set(_p):
		p = _p

@export var apply_material: bool:
	set(b):
		apply_mat()

"""
Just change this collision shape to be one way
"""
const FALL_THROUGH_MAT := preload(
"res://levels/platforms/platform_components/fall_through_platform_component/fall_through_platform_mat.tres")

func _ready():
	if !Engine.is_editor_hint():
		
		assert(p)
		# -- one way platform ===> toggles a collision layer
		p.set_collision_layer_value(1, false)
		p.set_collision_layer_value(9, true)
		
		#var coll_shape = p.get_node("CollisionShape2D") as CollisionShape2D
		#assert( coll_shape )
		#coll_shape.one_way_collision = true
		#coll_shape.one_way_collision_margin = 5.
		p.add_to_group("one_way_platforms")
		apply_mat()


func apply_mat():
	var sprite = p.get_node_or_null("Sprite2D")
	if sprite:
		sprite.material = FALL_THROUGH_MAT
		sprite.material.set_shader_parameter("src_col", Color(0.384, 0.216, 0.02, 1.0))
	else:
		print("fall through plat component; what is wrong with you....?? ")
