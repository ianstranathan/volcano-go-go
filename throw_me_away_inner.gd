extends Sprite2D

@onready var parent_subviewport: SubViewport = get_parent()
@export var inner_camera: Camera2D
@onready var main_camera: Camera2D = get_viewport().get_camera_2d()

func _ready() -> void:
	var vp_size := Vector2(parent_subviewport.size)
	#$Camera2D.zoom = camera.zoom
	inner_camera.global_position = main_camera.get_screen_center_position()
	var ratio := float(parent_subviewport.size.x) / get_viewport_rect().size.x   # 480 / 1920
	inner_camera.zoom = main_camera.zoom * ratio
	# -- scale inner bg sprite to size of subviewport
	scale = vp_size / texture.get_size()


func _process(_delta: float) -> void:
	global_position = main_camera.global_position
