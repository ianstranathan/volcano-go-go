extends Sprite2D

class_name FullScreenBgPll

@export var camera: Camera2D
@export var plane_index: int
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

var layer_scroll_speed: Vector2 = Vector2.ONE
var layer_scale: float = 1.0
var layer_brightness: float = 1.0
var layer_contrast: float = 1.0
var layer_saturation: float = 1.0
var layer_blur_radius: float = 0.0
var layer_opacity: float = 1.0
var layer_fog_amount: float = 0.0


func _process(_delta: float) -> void:
	# -- we're just moving out full screen bg sprite along with the camera
	# -- we're doing all out parallaxing in a vertex shader
	if not camera:
		return
	global_position = camera.global_position


func _ready() -> void:
	if not camera:
		camera = get_viewport().get_camera_2d()
	rescale_to_viewport()
	# -- vp changed callback
	if not Engine.is_editor_hint():
		assert(texture, "Invalid texture on background sprite in : {_name}".format(
			{"_name": name}))
		assert( plane_index != null )
		# -- meaningless to have is_fullscreen_bg if sprite hasn't been assigned
		get_viewport().size_changed.connect( rescale_to_viewport )


func rescale_to_viewport() -> void:
	var viewport_size: Vector2
	if Engine.is_editor_hint():
		# In the editor, grab the target resolution defined in Project Settings
		var w = ProjectSettings.get_setting("display/window/size/viewport_width")
		var h = ProjectSettings.get_setting("display/window/size/viewport_height")
		viewport_size = Vector2(w, h)
	else:
		# At runtime, get the actual active window/viewport size
		viewport_size = get_viewport().get_visible_rect().size
	
	scale = viewport_size / texture.get_size()


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

	# -------------------------------
	# -- TODO NOTE
	# -- hardcoding scale in shader right now, need this to be reflective of game eventually
	
	material.set_shader_parameter("texture_scale", Vector2(15000., 15000.))
	material.set_shader_parameter("scroll_scale", layer_scroll_speed)
