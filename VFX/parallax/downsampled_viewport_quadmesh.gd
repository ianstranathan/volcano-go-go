extends MeshInstance2D


var camera: Camera2D
@export var sub_viewport: SubViewport

func _ready() -> void:
	#sub_viewport.size = Vector2i(480, 270)
	#sub_viewport.size_2d_override = Vector2i.ZERO # Ensure no override is interfering
	#sub_viewport.transparent_bg = false
	sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# -- I need to wait until the subviewport is good / initialized
	# -- from docs:
	# -- "Emitted at the end of the frame, after the RenderingServer 
	# -- has finished updating all the Viewports."
	# -- "One-shot connections disconnect themselves after emission."
	RenderingServer.frame_post_draw.connect(func():
		configure_texture()
		, CONNECT_ONE_SHOT)
	_scale_to_viewport()
	#var vp = get_viewport()
	camera = get_viewport().get_camera_2d()
	## -- window changing callabck
	#vp.get_viewport().size_changed.connect(
		#_scale_to_viewport)


func _process(_delta: float) -> void:
	if not is_instance_valid(camera):
		return
	global_position = camera.global_position


func _scale_to_viewport() -> void:
	var screen_size := get_viewport_rect().size
	var tex_size := Vector2(sub_viewport.size)

	var quad := mesh as QuadMesh
	quad.size = tex_size

	scale = screen_size / tex_size
	
	print("Scale: ", scale)
	print("Quad size: ", quad.size)
	print("Quad AABB: ", quad.get_aabb())
	


func configure_texture():
	texture = sub_viewport.get_texture()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	
	#texture = sub_viewport.get_texture()
	#texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	#
	## -- scale last
	print("=====================")
	#print("Mesh type: ", mesh.get_class())
	#print("Mesh AABB: ", mesh.get_aabb())
	print("Texture size: ", texture.get_size())
	print("Viewport size: ", sub_viewport.size)
	#print("Texture: ", texture)
	#print("Mesh resource: ", mesh)
#
	#var arrays = mesh.get_mesh_arrays()
	#var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
#
	#print("UV coordinates:")
	#for uv in uvs:
		#print(uv)
#
	#print("UV count: ", uvs.size())
	#
	#_scale_to_viewport()
