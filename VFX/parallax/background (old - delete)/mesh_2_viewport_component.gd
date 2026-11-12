extends MeshInstance2D

@export var cam: Camera2D

func _ready() -> void:
	assert( cam )
	_scale_to_viewport()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _scale_to_viewport() -> void:
	var viewport_size = get_viewport().size
	var target_size = Vector2(float(viewport_size.x), float(viewport_size.y)) / cam.zoom
	if mesh is QuadMesh:
		(mesh as QuadMesh).size = target_size

func _on_viewport_size_changed() -> void:
	_scale_to_viewport()
