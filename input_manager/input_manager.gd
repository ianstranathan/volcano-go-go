extends Node2D
class_name InputManager

signal input_source_type_changed
signal aim_input_detected
 
enum InputSourceType{
	CONTROLLER,
	KEYBOARD
}

var current_input_source: InputSourceType = InputSourceType.CONTROLLER

const DEADZONE := 0.1



func _input(event: InputEvent) -> void:
	# -------------------------------------- change controller types
	if (current_input_source == InputSourceType.CONTROLLER and
		(event is InputEventKey or event is InputEventMouse)):
		set_input_source(InputSourceType.KEYBOARD)
		# -- something for the UI later
		emit_signal("input_source_type_changed", InputSourceType.KEYBOARD)
	elif (current_input_source == InputSourceType.KEYBOARD and 
		 (event is InputEventJoypadButton or event is InputEventJoypadMotion
		 or event is InputEventJoypadButton)):
		set_input_source(InputSourceType.CONTROLLER)
		# -- something for the UI later
		emit_signal("input_source_type_changed", InputSourceType.CONTROLLER)
	
	# -------------------------------------- emit_signal if aiming input
	if (current_input_source == InputSourceType.KEYBOARD and 
		event is InputEventMouseMotion):
		emit_signal("aim_input_detected")
	elif (current_input_source == InputSourceType.CONTROLLER and
		  event is InputEventJoypadMotion):
		if abs(event.axis_value) < DEADZONE:
			return
		match event.axis:
			JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
				emit_signal("aim_input_detected")
			#JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
				#on_left_stick_input()

func movement_vector():
	return Input.get_vector("move_left", "move_right", "move_down", "move_up") 

# -- NOTE
# -- CHANGE ME
## the distance in pixels that the controller can aim to
@export var controller_aiming_chain_length: float = 400.0 

func aiming_vector() -> Vector2:
	var rez := Vector2.ZERO
	if current_input_source == InputSourceType.CONTROLLER:
		rez = (Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down").normalized() *
				controller_aiming_chain_length)
	elif current_input_source == InputSourceType.KEYBOARD:
		# -- NOTE
		# var _from = global_position if !from_position else from_position
		#return (get_global_mouse_position() - _from)
		rez = (get_global_mouse_position() - global_position)
	return rez


func aiming_pos() -> Vector2:
	return (aiming_vector() + global_position)


func just_pressed_action(action_name: String):
	return Input.is_action_just_pressed(action_name)


func just_released_action(action_name: String) -> bool:
	return Input.is_action_just_released(action_name)


var last_pressed_action: StringName
func pressed_action(action_name: String) -> bool: #, return_name=false):
	var rez = Input.is_action_pressed(action_name)
	if rez:
		if !last_pressed_action or last_pressed_action != action_name:
			last_pressed_action = action_name
	return rez


func get_last_pressed_action() -> StringName:
	return last_pressed_action


func set_input_source(_source_type: InputSourceType):
	if current_input_source != _source_type:
		current_input_source = _source_type


func is_using_keyboard_and_mouse() -> bool:
	return current_input_source == InputSourceType.KEYBOARD


func is_using_controller() -> bool:
	return current_input_source == InputSourceType.CONTROLLER
