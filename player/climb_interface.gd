extends Area2D

class_name ClimbArea

signal climbing_area_entered( )
signal climbing_area_exited( )


# -- NOTE
# -- You should probably architect an area to have a climbable component
# -- rather than having a dedicated collision layer...
var climbing_data 

# TODO
# this is assuming that all climb areas are on their own layer which
# seems kinda inflexible
func _ready() -> void:
	area_entered.connect( func(area):
		if area is not ClimbArea:
			climbing_data = area.get_parent().climbing_data
			climbing_area_entered.emit( ))
	area_exited.connect( func(_area): climbing_area_exited.emit() )
