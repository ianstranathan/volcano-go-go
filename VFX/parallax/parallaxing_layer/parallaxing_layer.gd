@tool
extends Node2D
class_name ParallaxingLayer

"""
basically, just a data structure to hold a plane index + choices
about that layer (e.g. blurred)

ParallaxDepthConfig: 
	stores global main player index and derives all parallaxing values from it.

"""
# -- NOTE
# -- this should come from chunking information
var world_dimensions  = Vector2(15000, 15000)
@export var depth_config: ParallaxDepthConfig:
	set(value):
		if depth_config == value:
			return

		if depth_config != null:
			if depth_config.changed.is_connected( update_depth_properties ):
				depth_config.changed.disconnect( update_depth_properties )

		depth_config = value

		if depth_config != null:
			if not depth_config.changed.is_connected( update_depth_properties):
				depth_config.changed.connect( update_depth_properties )

		update_depth_properties()

	
@export var plane_index: int = 0:
	set(value):
		plane_index = value
		update_depth_properties()

@export var _parallax_2D: Parallax2D:
	set(p):
		_parallax_2D = p
		_parallax_2D.scroll_scale = layer_scroll_speed


# --------------------------------------------- Derived from ParallaxDepthConfig
var layer_scroll_speed: Vector2 = Vector2.ONE
var layer_scale: float = 1.0
var layer_brightness: float = 1.0
var layer_contrast: float = 1.0
var layer_saturation: float = 1.0
var layer_blur_radius: float = 0.0
var layer_opacity: float = 1.0
var layer_fog_amount: float = 0.0


var vp_size



func _ready() -> void:
	connect_depth_config()
	update_depth_properties()


func _exit_tree() -> void:
	if depth_config != null:
		if depth_config.changed.is_connected( update_depth_properties ):
			depth_config.changed.disconnect( update_depth_properties )


func connect_depth_config() -> void:
	if depth_config == null:
		return
	if not depth_config.changed.is_connected(update_depth_properties):
		depth_config.changed.connect(update_depth_properties)


func set_depth_config(value: ParallaxDepthConfig) -> void:
	if depth_config != null:
		if depth_config.changed.is_connected(update_depth_properties):
			depth_config.changed.disconnect(update_depth_properties)
	depth_config = value
	connect_depth_config()
	update_depth_properties()


func update_depth_properties():
	if depth_config == null:
		return
	# ------------------------------------------- derived layer vars from config
	layer_scroll_speed = depth_config.get_movement_factor( plane_index )
	layer_scale = depth_config.get_scale_factor( plane_index )
	layer_brightness = depth_config.get_atmospheric_fade( plane_index )
	layer_contrast = depth_config.get_contrast( plane_index )
	layer_saturation = depth_config.get_saturation( plane_index )
	layer_blur_radius = depth_config.get_blur( plane_index )
	layer_opacity = depth_config.get_opacity( plane_index )
	layer_fog_amount = depth_config.get_atmospheric_fog( plane_index )

	if _parallax_2D:
		_parallax_2D.scroll_scale = Vector2(layer_scale, layer_scale)
		
