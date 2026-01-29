@tool
extends Node2D
class_name PickupItem

# NOTE
enum ItemType {
	MOBILITY,
	CREATION,
	DESTRUCTION
}

# -- backing variables
var _pickup_radius: float = 35.0
var _type: ItemType = ItemType.MOBILITY
var _texture: Texture2D

# -- Exports
@export var scene_resource: PackedScene
@export var pickup_radius: float:
	set(value):
		_pickup_radius = value
		_update_collision()
		_update_sprite_scale()
	get:
		return _pickup_radius

@export var sprite: Sprite2D

@export var type: ItemType:
	set(value):
		_type = value
		_update_sprite_color()
	get:
		return _type

@export var texture: Texture2D:
	set(value):
		_texture = value
		if sprite:
			sprite.texture = value
			_update_sprite_scale()
	get:
		return _texture


# ===============================
# Internal helper methods
# ===============================

func _update_collision():
	var coll_shape: CollisionShape2D = get_node_or_null("Area2D/CollisionShape2D")
	if coll_shape and coll_shape.shape:
		coll_shape.shape.radius = _pickup_radius

func _update_sprite_scale():
	if not sprite or not sprite.texture:
		return
	var tex_size: Vector2 = sprite.texture.get_size()
	sprite.scale = 2.0 * Vector2(_pickup_radius, _pickup_radius) / tex_size

func _update_sprite_color():
	if sprite and sprite.material:
		sprite.material.set_shader_parameter("src_col", color_from_type())
		
# ===============================
# Utilities
# ===============================

func color_from_type() -> Color:
	match _type:
		ItemType.MOBILITY:
			return Color(0.504, 0.214, 1.0, 1.0)
		ItemType.CREATION:
			return Color(0.788, 0.294, 0.0, 1.0)
		ItemType.DESTRUCTION:
			return Color(0.045, 0.27, 0.943, 1.0)
	return Color(0.0, 0.0, 0.0, 1.0)


# ===============================
# Runtime logic
# ===============================

func _ready() -> void:
	if not Engine.is_editor_hint():
		# Ensure scene_resource exists
		assert(scene_resource, "Attach an item to the pickup item: %s" % name)

		_update_sprite_color()

		$Area2D.body_entered.connect(func(body):
			if body is Player:
				body.get_node("ItemManager").pick_up(
					scene_resource,
					pick_up_finished_callback
				)
		)

func pick_up_finished_callback():
	queue_free()
