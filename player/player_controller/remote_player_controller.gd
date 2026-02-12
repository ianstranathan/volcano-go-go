extends Node2D
class_name RemotePlayerController

var player: Player
var last_command := PlayerCommand.new()

func update_command(player_command_ref: PlayerCommand, _delta):
	player_command_ref.move_input = last_command.move_input
	player_command_ref.jump_pressed = last_command.jump_pressed
	player_command_ref.jump_released = last_command.jump_released
	player_command_ref.aiming_input = last_command.aiming_input
	player_command_ref.using_controller = last_command.using_controller


#@rpc("any_peer", "unreliable")
#func receive_command(move: Vector2,
					 #jump_pressed: bool,
					 #jump_released: bool,
					 #sequence_id: int) -> void:
	#last_command.move_input = move
	#last_command.jump_pressed = jump_pressed
	#last_command.jump_released = jump_released
	#last_command.sequence_id = sequence_id

func inject_remote_intent( data: PackedByteArray) -> void:
	var _command: PlayerCommand = PlayerCommand.deserialize(data)
	last_command.move_input = _command.move_input
	last_command.jump_pressed = _command.jump_pressed
	last_command.jump_released = _command.jump_released
