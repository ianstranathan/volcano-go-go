extends Node2D

class_name Item

var input_manager: InputManager
var player_ref :Player

func _ready():
	assert( input_manager and player_ref )

## virtual function use
func use():
	pass
