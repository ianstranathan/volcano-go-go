extends Node2D

@export var target_2_move: Node2D
@export var cam: Camera2D


func _ready() -> void:
	assert( target_2_move )
	assert( cam )


func _process(_delta: float) -> void:
	# -- we're doing this in _process so there are no artifacts when
	# -- moving camera
	if cam:
		target_2_move.global_position = cam.global_position
