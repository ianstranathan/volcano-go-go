@tool
extends Node2D

"""
Small placeholder for platforms
Sprite and collision shape change to match 
the editor exposed var: coll_extents
"""

# -- FIXME TODO
@export var color: Color = Color(0.5, 0.5, 0.5, 1.0):
	set(value):
		color = value
		#if sprite:
		sprite.material.set_shader_parameter("source_col", color)

@export var coll_extents: Vector2 = Vector2(50, 50):
	set(value):
		coll_extents = value
		if coll_shape:
			_update_collision_shape()
			_on_shape_size_changed() # Your custom callback function

@export var coll_shape: CollisionShape2D
@export var sprite: Sprite2D

func _update_collision_shape():
	if not coll_shape.shape.is_local_to_scene():
		coll_shape.shape = coll_shape.shape.duplicate()
	coll_shape.shape.extents = coll_extents / 2.0


func _on_shape_size_changed():
	var coll_size = coll_shape.shape.size
	var tex_size = sprite.texture.get_size()
	
	var scaled_tex_size = sprite.scale * tex_size
	if !(is_equal_approx(scaled_tex_size.x, coll_size.x) and 
		 is_equal_approx(scaled_tex_size.y, coll_size.y)):
		sprite.scale = coll_size / tex_size
