@tool
extends Node2D

"""
Simple utility component that is child of a AnimatableBody2D or StaticBody2D
- it just couples the placeholder sprite size and the collision shape to
  automate manual changing
"""
@export var body: StaticBody2D
@export var color: Color = Color(0.5, 0.5, 0.5, 1.0):
	set(value):
		color = value
		if body:
			var sprite = body.get_node("Sprite2D")
			if sprite:
				sprite.material.set_shader_parameter("source_col", color)


@export var coll_extents: Vector2 = Vector2(50, 50):
	set(value):
		coll_extents = value
		if body:
			var coll_shape = body.get_node("CollisionShape2D")
			if coll_shape:
				_update_collision_shape(coll_shape)
				_on_shape_size_changed() # Your custom callback function

func _ready():
	#if !Engine.is_editor_hint():
	assert( body )
	var coll_shape = body.get_node("CollisionShape2D")
	_on_shape_size_changed( )
	_update_collision_shape( coll_shape )


func _update_collision_shape(coll_shape: CollisionShape2D):
	if not coll_shape.shape.is_local_to_scene():
		coll_shape.shape = coll_shape.shape.duplicate()
	coll_shape.shape.extents = coll_extents / 2.0


func _on_shape_size_changed():
	#var coll_size = coll_shape.shape.size
	var sprite = body.get_node("Sprite2D")
	var tex_size = sprite.texture.get_size()
	
	var scaled_tex_size = sprite.scale * tex_size
	if !(is_equal_approx(scaled_tex_size.x, coll_extents.x) and 
		 is_equal_approx(scaled_tex_size.y, coll_extents.y)):
		sprite.scale = coll_extents / tex_size
