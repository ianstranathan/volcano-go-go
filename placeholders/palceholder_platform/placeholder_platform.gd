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
		if $Sprite2D:
			$Sprite2D.material.set_shader_parameter("source_col", color)

@export var coll_extents: Vector2 = Vector2(50, 50):
	set(value):
		coll_extents = value
		if $StaticBody2D/CollisionShape2D:
			_update_collision_shape()
			_on_shape_size_changed() # Your custom callback function


func _update_collision_shape():
	if not $StaticBody2D/CollisionShape2D.shape.is_local_to_scene():
		$StaticBody2D/CollisionShape2D.shape = $StaticBody2D/CollisionShape2D.shape.duplicate()
	$StaticBody2D/CollisionShape2D.shape.extents = coll_extents / 2.0


func _on_shape_size_changed():
	var coll_size = $StaticBody2D/CollisionShape2D.shape.size
	var tex_size = $Sprite2D.texture.get_size()
	
	var scaled_tex_size = $Sprite2D.scale * tex_size
	if !(is_equal_approx(scaled_tex_size.x, coll_size.x) and 
		 is_equal_approx(scaled_tex_size.y, coll_size.y)):
		$Sprite2D.scale = coll_size / tex_size
