# RemoteController.gd
extends Node
class_name RemotePlayerController

var last_command := PlayerCommand.new()

func update_command(player_command_ref: PlayerCommand, _delta):
	player_command_ref.move = last_command.move
	player_command_ref.jump_pressed = last_command.jump_pressed
	player_command_ref.jump_released = last_command.jump_released
	player_command_ref.aiming_vector = last_command.aiming_vector
	player_command_ref.using_controller = last_command.aiming_vector


@rpc("unreliable")
func receive_command(remote_player_command_ref: PlayerCommand):
	last_command = remote_player_command_ref
