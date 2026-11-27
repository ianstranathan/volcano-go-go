extends Camera2D

#@export var main_camera: Camera2D
#@onready var main_camera: Camera2D = get_viewport().get_camera_2d()
@onready var main_camera: Camera2D = get_tree().root.get_camera_2d()

func _process(_delta: float) -> void:
	global_position = main_camera.global_position
