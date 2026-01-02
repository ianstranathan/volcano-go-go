extends Node2D

class_name Item

var input_manager: InputManager
var player_ref :Player
var type: ItemGlobals.ItemType

signal item_started( _type: ItemGlobals.ItemType)
signal item_finished

func _ready():
	assert( type )
	assert( input_manager )
	assert( player_ref )

## template for when the is used
func use():
	item_started.emit( type )

## template for when the item naturally stops being used
func finish_using():
	item_finished.emit( type )


## template for when the item is stopped by the item manager (i.e. player interruption)
func stop_using():
	pass
