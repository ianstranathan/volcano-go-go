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


func use():
	item_started.emit( type )


func finish_using():
	item_finished.emit( type )

#
#func is_mobility_item() -> bool:
	#return type == ItemGlobals.ItemType.MOBILITY
