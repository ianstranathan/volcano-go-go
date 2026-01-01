extends Node2D

@export var input_manager: InputManager

var is_aiming: bool = true:
	set(value):
		is_aiming = value
		set_process(is_aiming)
		$Reticle.visible = is_aiming
		$Line2D.visible = is_aiming


func _ready() -> void:
	assert(input_manager)


func _process(_delta: float) -> void:
	var pos = input_manager.aiming_pos()
	$Reticle.global_position = pos
	$Line2D.set_point_position(1, to_local( pos ))
