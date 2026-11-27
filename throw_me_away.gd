extends Sprite2D

@export var sub_viewport: SubViewport
#@export var main_camera: Camera2D
#@onready var main_camera: Camera2D = get_viewport().get_camera_2d()
@onready var main_camera: Camera2D = get_tree().root.get_camera_2d()

func _ready() -> void:
	# Display samples the SubViewport's texture.
	texture = sub_viewport.get_texture()
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	get_viewport().size_changed.connect(_fit_display)
	_fit_display()


func _fit_display() -> void:
	# Quad covers the full window; shader UV 0..1 maps the full texture onto it.
	scale = get_viewport_rect().size / Vector2(sub_viewport.size)

func _process(_delta: float) -> void:
	global_position = main_camera.global_position
