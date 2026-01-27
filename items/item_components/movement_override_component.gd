extends Node

class_name MovementOverrideComponent

signal movement_override_started
signal movement_override_finished

@export var _allows_jump: bool
@export var _stops_on_floor: bool
@export var _allows_horizontal_movement: bool
@export var _allows_ledge_grab: bool
@export var _allows_rope_climb: bool
#@export var _allows_wall_slide
func _ready() -> void:
	assert( _allows_jump != null )
	assert( _stops_on_floor != null ) 
	assert( _allows_horizontal_movement != null ) 
	assert( _allows_ledge_grab != null )


func allows_rope_climb() -> bool:
	return _allows_rope_climb


func allows_jump() -> bool:
	return _allows_jump


func allows_horizontal_movement() -> bool:
	return _allows_horizontal_movement


func allows_ledge_grab() -> bool:
	return _allows_ledge_grab


func stops_on_floor() -> bool:
	return _stops_on_floor


func start():
	movement_override_started.emit()


func finish():
	movement_override_finished.emit()
