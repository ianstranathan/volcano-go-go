@tool
extends Node2D

class_name PickupItem

# NOTE
# 
enum ItemType{
	MOBILITY,
	CREATION,
	DESTRUCTION
}
# -- Change the icon to reflect what it is
@export var scene_resource: PackedScene
@export var pickup_radius: float = 35:
	set( value ):
		pickup_radius = value
		if sprite:
			match_sprite_to_coll_radius( sprite.texture.get_size() )
		var coll_shape = $Area2D/CollisionShape2D
		if coll_shape:
			coll_shape.shape.radius = value


@export var sprite: Sprite2D
@export var _type: ItemType:
	set(value):
		_type = value
		if sprite:
			$Sprite2D.material.set_shader_parameter("src_col", color_from_type())


@export var _texture: Texture2D:
	set(value):	
		_texture = value
		if sprite:
			sprite.texture = value
			#var _size = value.get_size()
			match_sprite_to_coll_radius( value.get_size() )
			# -- 2.0 because we're use a radius, not a diameter
			#sprite.scale = 2.0 * Vector2(pickup_radius, pickup_radius) / _size

func match_sprite_to_coll_radius(_size: Vector2):
	#var _size = value.get_size()
	# -- 2.0 because we're use a radius, not a diameter
	sprite.scale = 2.0 * Vector2(pickup_radius, pickup_radius) / _size


# -- different types should be visually distinct to allow gestalt decision making
func color_from_type() -> Color:
	match _type:
		ItemType.MOBILITY:
			return Color(0.504, 0.214, 1.0, 1.0)
		ItemType.CREATION:
			return Color(0.788, 0.294, 0.0, 1.0)	
		ItemType.DESTRUCTION:
			return Color(0.045, 0.27, 0.943, 1.0)
	return Color(0.0, 0.0, 0.0, 1.0)


func _ready() -> void:
	if !Engine.is_editor_hint():
		var assert_fail_str = "Attach an item to the pickup item: %s"
		#assert( scene_resource, assert_fail_str % name )
		assert( scene_resource, assert_fail_str % name )
		$Sprite2D.material.set_shader_parameter("color_type", color_from_type())
		$Area2D.body_entered.connect( func(body):
			if body is Player:
				# -- player picks up item and does soemthing with it
				# -- pass a clean up function to do whatever whenvever the player
				# -- pickup logic is finished
				body.get_node("ItemManager").pick_up(scene_resource,
													 pick_up_finished_callback))


func pick_up_finished_callback():
	queue_free()
