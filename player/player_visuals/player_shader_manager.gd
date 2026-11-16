@tool
extends AnimatedSprite2D

func _ready() -> void:
	if material and material is ShaderMaterial:
		material = material.duplicate()

	if not is_connected("frame_changed", Callable(self, "_update_shader_params")):
		frame_changed.connect(_update_shader_params)
	if not is_connected("animation_changed", Callable(self, "_update_shader_params")):
		animation_changed.connect(_update_shader_params)

	_update_shader_params()

func _update_shader_params() -> void:
	if not material is ShaderMaterial or not sprite_frames:
		return
	
	if animation == "" or not sprite_frames.has_animation(animation):
		return
		
	var frame_tex = sprite_frames.get_frame_texture(animation, frame)
	var frame_offset = Vector2.ZERO
	var frame_size = Vector2.ONE
	
	# Extract sub-UV region if the frame is an AtlasTexture (sliced sprite sheet)
	if frame_tex is AtlasTexture:
		var atlas = frame_tex.atlas
		if atlas:
			var region = frame_tex.region
			var atlas_size = atlas.get_size()
			if atlas_size.x > 0 and atlas_size.y > 0:
				frame_offset = region.position / atlas_size
				frame_size = region.size / atlas_size
			
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("frame_offset", frame_offset)
	mat.set_shader_parameter("frame_size", frame_size)
	
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if not material or not sprite_frames:
			return
		
		if animation == "" or not sprite_frames.has_animation(animation):
			return
			
		var frame_tex = sprite_frames.get_frame_texture(animation, frame)
		var frame_offset = Vector2.ZERO
		var frame_size = Vector2.ONE
		
		# Extract sub-UV region if the frame is an AtlasTexture (sliced sprite sheet)
		if frame_tex is AtlasTexture:
			var atlas = frame_tex.atlas
			if atlas:
				var region = frame_tex.region
				var atlas_size = atlas.get_size()
				if atlas_size.x > 0 and atlas_size.y > 0:
					frame_offset = region.position / atlas_size
					frame_size = region.size / atlas_size
				
		material.set_shader_parameter("frame_offset", frame_offset)
		material.set_shader_parameter("frame_size", frame_size)
