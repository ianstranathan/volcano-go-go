@tool
extends CanvasGroup

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
		_update_shader_parameters()

@export var layer_index: int = 0 :
	set(value):
		layer_index = value
		update_depth_properties()
		_update_shader_parameters()

func _ready() -> void:
	if depth_config:
		depth_config.changed.connect(_update_shader_parameters)
		_update_shader_parameters()


func _update_shader_parameters() -> void:
	# Ensure we have a material and a config resource assigned
	var mat := material as ShaderMaterial
	if not mat or not depth_config:
		return
	
	# Call your resource's exact calculation functions using the layer's index!
	var blur_val = depth_config.get_blur(layer_index)
	var contrast_val = depth_config.get_contrast(layer_index)
	var saturation_val = depth_config.get_saturation(layer_index)
	var brightness_val = depth_config.get_atmospheric_fade(layer_index)
	var fog_amount_val = depth_config.get_atmospheric_fog(layer_index)
	
	# Push the evaluated results directly to the shader uniforms
	mat.set_shader_parameter("radius", blur_val)
	mat.set_shader_parameter("contrast_mult", contrast_val)
	mat.set_shader_parameter("saturation_mult", saturation_val)
	mat.set_shader_parameter("brightness", brightness_val)
	mat.set_shader_parameter("fog_color", depth_config.fog_color)
	mat.set_shader_parameter("fog_amount", fog_amount_val)


var layer_scroll_speed: Vector2 = Vector2.ONE
var layer_scale: float = 1.0
var layer_brightness: float = 1.0
var layer_contrast: float = 1.0
var layer_saturation: float = 1.0
var layer_blur_radius: float = 0.0
var layer_opacity: float = 1.0
var layer_fog_amount: float = 0.0

func update_depth_properties():
	if depth_config == null:
		return

	# ------------------------------------------- derived layer vars from config
	layer_scroll_speed = depth_config.get_movement_factor( layer_index )
	layer_scale = depth_config.get_scale_factor( layer_index )
	layer_brightness = depth_config.get_atmospheric_fade( layer_index )
	layer_contrast = depth_config.get_contrast( layer_index )
	layer_saturation = depth_config.get_saturation( layer_index )
	layer_blur_radius = depth_config.get_blur( layer_index )
	layer_opacity = depth_config.get_opacity( layer_index )
	layer_fog_amount = depth_config.get_atmospheric_fog( layer_index )

	# -- Group render vars

	modulate = Color(
		layer_brightness,
		layer_brightness,
		layer_brightness,
		layer_opacity
	)
