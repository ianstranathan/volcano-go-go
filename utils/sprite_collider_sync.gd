@tool
extends Node2D
class_name SpriteCollisionSync

@export var sprite: Sprite2D
@export var coll_shape: CollisionShape2D
@export var moveable: bool = false

# Backing variables for setters
var _coll_extents: Vector2 = Vector2(50, 50)
var _color: Color = Color(0.5, 0.5, 0.5, 1.0)

# Extents setter
@export var coll_extents: Vector2:
	set(value):
		_coll_extents = value
		_update_collision_shape()
		_update_sprite_scale()
	get:
		return _coll_extents

# Color setter
@export var color: Color:
	set(value):
		_color = value
		if sprite and sprite.material:
			sprite.material.set_shader_parameter("source_col", _color)
	get:
		return _color

func _ready():
	if Engine.is_editor_hint():
		_update_collision_shape()
		_update_sprite_scale()

func _physics_process(_delta: float) -> void:
	if moveable and sprite and coll_shape:
		sprite.global_position = coll_shape.global_position
		sprite.global_rotation = coll_shape.global_rotation

func _update_collision_shape():
	if not coll_shape:
		return
	# Duplicate shape if it’s shared
	if not coll_shape.shape.is_local_to_scene():
		coll_shape.shape = coll_shape.shape.duplicate()
	if coll_shape.shape is RectangleShape2D:
		coll_shape.shape.extents = _coll_extents / 2.0

func _update_sprite_scale():
	if not sprite or not coll_shape or not sprite.texture:
		return
	var tex_size = sprite.texture.get_size()
	sprite.scale = Vector2(
		_coll_extents.x / tex_size.x,
		_coll_extents.y / tex_size.y
	)
