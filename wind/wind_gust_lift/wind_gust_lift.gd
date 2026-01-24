@tool
extends Node2D

class_name WindGustLift

# TODO
# there should probably be variable stregnths of gust
# naturally, these should be visually reflected and passed via item manager

#func _ready() -> void:
	#$Area2D.body_entered.connect( func(body):
		#if body is Player:
			#var item_manager = body.get_children().filter( func(c): return c is ItemManager))[0]
			#item_manager.emit_signal("player_entered_wind_gust_area")
# -------------------------------------------------

@export var coll_extents: Vector2 = Vector2(50, 50):
	set(value):
		coll_extents = value
		if Engine.is_editor_hint() and coll_shape:
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
