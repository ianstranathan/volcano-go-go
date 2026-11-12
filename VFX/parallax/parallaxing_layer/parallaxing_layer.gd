@tool
extends Parallax2D

class_name ParallaxingLayer
"""
ParallaxDepthConfig: 
	stores global main player index and derives all parallaxing values from it.

ParallaxDepthManager: 
	Knows which plane is the main plane and coordinates the system.

ParallaxingLayer:
	└── CanvasGroup
	    ├── Sprite2D
	    ├── Sprite2D
	    ├── Sprite2D
	    └── Sprite2D
	Knows its own index and uses a ParallaxDepthConfig to set it's
	canvas group properties

	CanvasGroup: 
		Provides a convenient place to apply shared visual transformations.
"""
# -- NOTE! (from godot docs)
"""
Since CanvasGroup and CanvasItem.clip_children both utilize the backbuffer,
 children of a CanvasGroup who have their CanvasItem.clip_children set to anything other than CanvasItem.CLIP_CHILDREN_DISABLED
 will not function correctly.
"""

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
@export var layer_material: ShaderMaterial:
	set(v):
		if layer_material == v:
			return
		layer_material = v
		create_material_instance()
		update_shader_parameters()

var _layer_material_instance: ShaderMaterial
@export var blurred: bool = true:
	set(value):
		blurred = value
		update_shader_parameters()

@export var canvas_group: CanvasGroup
#@export_range(1, 100, 1) var z_index_spacing: int = 10

# --------------------------------------------------
# Derived from ParallaxDepthConfig
var layer_scroll_speed: Vector2 = Vector2.ONE
var layer_scale: float = 1.0
var layer_brightness: float = 1.0
var layer_contrast: float = 1.0
var layer_saturation: float = 1.0
var layer_blur_radius: float = 0.0
var layer_opacity: float = 1.0
var layer_fog_amount: float = 0.0



func _ready() -> void:
	create_material_instance()
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
	if canvas_group == null:
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


	# -------------------------------------------------- set parallax layer vals
	scroll_scale = layer_scroll_speed
	#z_index = plane_index * z_index_spacing
	
	if canvas_group != null:
		canvas_group.scale = Vector2.ONE * layer_scale
		canvas_group.modulate = Color(
			layer_brightness,
			layer_brightness,
			layer_brightness,
			layer_opacity
		)
	
	# ------------------------------------------------------ set shader uniforms
	update_shader_parameters()


func update_shader_parameters() -> void:
	if _layer_material_instance == null:
		return

	if depth_config == null:
		return

	var effective_blur := layer_blur_radius if blurred else 0.0

	_layer_material_instance.set_shader_parameter("contrast", layer_contrast)
	_layer_material_instance.set_shader_parameter("saturation", layer_saturation)
	_layer_material_instance.set_shader_parameter("blur_radius", effective_blur)
	_layer_material_instance.set_shader_parameter("fog_color", depth_config.fog_color)
	_layer_material_instance.set_shader_parameter("fog_amount", layer_fog_amount)


func create_material_instance() -> void:
	if layer_material == null:
		_layer_material_instance = null
		if canvas_group != null:
			canvas_group.material = null
		return
	_layer_material_instance = layer_material.duplicate() as ShaderMaterial
	if canvas_group != null:
		canvas_group.material = _layer_material_instance
