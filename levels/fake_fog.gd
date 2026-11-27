extends Sprite2D

@onready var main_camera: Camera2D = get_tree().root.get_camera_2d()

func _process(_delta: float) -> void:
	global_position = main_camera.global_position

func _ready() -> void:
	get_viewport().size_changed.connect(_fit_display)
	_fit_display()

func _fit_display() -> void:
	scale = get_viewport_rect().size / texture.get_size()
