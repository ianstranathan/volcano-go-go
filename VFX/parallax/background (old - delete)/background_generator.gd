@tool
extends Node2D

@export var buffer_amount: int:
	set(v):
		buffer_amount = v
		_rebuild()

@export var _apply: bool = false:
	set(v):
		_rebuild()

@export var texture: Texture2D:
	set(value):
		texture = value
		_rebuild()

@export var mat: ShaderMaterial:
	set(value):
		mat = value
		_rebuild()

@export var tile_size := Vector2i(512, 512):
	set(value):
		tile_size = value
		_rebuild()

@export var top: Marker2D:
	set(value):
		top = value
		_rebuild()

@export var bottom: Marker2D:
	set(value):
		bottom = value
		_rebuild()

@export var left: Marker2D:
	set(value):
		left = value
		_rebuild()

@export var right: Marker2D:
	set(value):
		right = value
		_rebuild()

var _multimesh_instance: MultiMeshInstance2D


func _ready():
	if !Engine.is_editor_hint():
		_rebuild(true)


func _rebuild(override=null):
	if !Engine.is_editor_hint() and !override:
		return

	if mat != null:
		mat.set_shader_parameter(
				"level_dims",
				Vector2(
					right.global_position.x - left.global_position.x,
					bottom.global_position.y - top.global_position.y
				)
			)

		mat.set_shader_parameter(
			"level_origin",
			Vector2.ZERO
		)

	if texture == null or mat == null or !top or !bottom or !left or !right:
		return

	if !is_instance_valid(_multimesh_instance):
		_multimesh_instance = MultiMeshInstance2D.new()
		add_child(_multimesh_instance)

	# -- Apply the material directly to the MultiMeshInstance2D node
	_multimesh_instance.material = mat

	# -- bounds
	var min_x = left.global_position.x
	var max_x = right.global_position.x
	var min_y = top.global_position.y
	var max_y = bottom.global_position.y
	
	var total_width = abs(max_x - min_x)
	var total_height = abs(max_y - min_y)
	
	var cols = ceili(total_width / tile_size.x) + (buffer_amount * buffer_amount)
	var rows = ceili(total_height / tile_size.y) + (buffer_amount * buffer_amount)
	
	# -- so we're starting at top left cvorner
	var multimesh_starting_pos = Vector2(min_x, min_y)
	# -- then we're pushing up by however many rows/ cols we're buffering by
	var offset_by_buffer_amount = buffer_amount * (Vector2(tile_size.x, tile_size.y) + (tile_size * 0.5))
	_multimesh_instance.global_position = multimesh_starting_pos - offset_by_buffer_amount
	_multimesh_instance.texture = texture

	var multimesh := _multimesh_instance.multimesh
	if multimesh == null:
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.use_custom_data = false
		multimesh.use_colors = false
		_multimesh_instance.multimesh = multimesh

	multimesh.mesh = _create_quad_mesh(tile_size)
	multimesh.instance_count = cols * rows

	var index := 0
	for y in range(rows):
		for x in range(cols):
			var pos := Vector2(x * tile_size.x, y * tile_size.y) + (tile_size * 0.5)
			multimesh.set_instance_transform_2d(index, Transform2D(0.0, pos))
			index += 1

func _create_quad_mesh(size: Vector2) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = size
	return mesh
