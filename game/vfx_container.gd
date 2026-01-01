extends Node2D

@export var lava_ref: Node2D
@export var camera_ref: Camera2D
@export var post_processing_quad: Sprite2D

func _ready() -> void:
	assert(camera_ref)
	assert(lava_ref)
	# -- scale the quad to match the viewport
	get_viewport().size_changed.connect(scale_quad_2_vp)
	scale_quad_2_vp()


func _physics_process(_delta: float) -> void:
	post_processing_quad.global_position = camera_ref.global_position
	post_processing_quad.material.set_shader_parameter("distortion_uv_height", heat_distortion_uv_pos())


func heat_distortion_uv_pos() -> float:
	# this is going to get a horizontal line's vertical position
	
	# -- the height of the lava function for the camera's world-x
	var lava_world_height_at_camera_x = lava_ref.lava_fn( camera_ref.global_position.x )
	var uv_height = (lava_world_height_at_camera_x - camera_ref.global_position.y) / get_viewport().size.y
	return uv_height


func scale_quad_2_vp():
	var vp_size = get_viewport().size
	var _zoom_factor = Vector2(1. / camera_ref.zoom.x, 1. / camera_ref.zoom.y)
	post_processing_quad.scale =  _zoom_factor * Vector2(vp_size.x, vp_size.y)/ (post_processing_quad.texture.get_size())
