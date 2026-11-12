extends Node2D

@export var cam: Camera2D
@export var sub_cam: Camera2D

func _ready() -> void:
	assert( cam )
	sub_cam.zoom = cam.zoom


func _process(_delta: float) -> void:
	# -- we're doing this in _process so there are no artifacts when
	# -- moving camera
	if cam:
		global_position = cam.global_position
		sub_cam.zoom = cam.zoom
