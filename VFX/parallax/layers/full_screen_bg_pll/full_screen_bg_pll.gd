extends Sprite2D

class_name FullScreenBgPll

"""
This is a sprite that scales to our render target size

It just pulls in information from a parallaxing layer
(i.e. the necessary parallax data required for the shader offsets))
"""
@export var parallaxing_layer: ParallaxingLayer
@export var parent_subviewport: SubViewport
@export var inner_camera: Camera2D
#@onready var main_camera: Camera2D = get_viewport().get_camera_2d()
@onready var main_camera: Camera2D = get_tree().root.get_camera_2d()
@onready var world_dims: Vector2 = parallaxing_layer.world_dimensions
@onready var scroll_speed: Vector2 = parallaxing_layer.layer_scroll_speed

func _ready() -> void:
	print(main_camera)
	print(inner_camera)
	print(main_camera == inner_camera)
	print("main: ", main_camera, " inner: ", inner_camera, " same: ", main_camera == inner_camera)
	print("main center: ", main_camera.get_screen_center_position())
	print("------------------------")
	var vp_size := Vector2(parent_subviewport.size)
	#$Camera2D.zoom = camera.zoom
	inner_camera.global_position = main_camera.global_position
	#var ratio := float(parent_subviewport.size.x) / get_viewport_rect().size.x   # 480 / 1920
	#var main_size := main_camera.get_viewport_rect().size
	#var ratio := vp_size.x / main_size.x
	#inner_camera.zoom = main_camera.zoom * ratio
	
	var ratio := float(parent_subviewport.size.x) / main_camera.get_viewport_rect().size.x   # 480 / 1920
	inner_camera.zoom = main_camera.zoom
	
	# -- scale inner bg sprite to size of subviewport
	scale = vp_size / texture.get_size()
	
	_sync()
	
	print("Ratio: ", ratio)
	print("Sprite scale: ", scale)
	print("Sprite total size: ", scale * texture.get_size())

func _process(_delta: float) -> void:
	_sync()
	#global_position = main_camera.global_position
	#set_shader_parallaxing_uniforms()


func _sync() -> void:
	
	global_position = main_camera.global_position
	if material:
		RenderingServer.global_shader_parameter_set("parallax_camera_pos", main_camera.global_position)
		material.set_shader_parameter("texture_scale", world_dims)
		#material.set_shader_parameter("scroll_scale", Vector2(scroll_speed.x * 0.5, 0.1))
		
#func set_shader_parallaxing_uniforms():
	#if material:
		#material.set_shader_parameter("camera_pos", inner_camera.global_position)
		#material.set_shader_parameter("texture_scale", world_dims)
		#material.set_shader_parameter("scroll_scale", scroll_speed)
