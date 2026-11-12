extends MeshInstance2D

@export var cam: Camera2D

func _ready() -> void:
	assert( cam )
	_scale_to_viewport()


func _scale_to_viewport() -> void:
	var viewport_size = get_viewport().size
	var target_size = Vector2(float(viewport_size.x), float(viewport_size.y)) / cam.zoom
	if mesh is QuadMesh:
		(mesh as QuadMesh).size = target_size


func _process(_delta: float) -> void:
	# -- we're doing this in _process so there are no artifacts when
	# -- moving camera
	if cam:
		global_position = cam.global_position
		#print(global_position)
