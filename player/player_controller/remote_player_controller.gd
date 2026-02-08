# RemoteController.gd
extends Node2D
class_name RemotePlayerController

var last_command := PlayerCommand.new()

func update_command(player_command_ref: PlayerCommand, _delta):
	player_command_ref.move_input = last_command.move_input
	player_command_ref.jump_pressed = last_command.jump_pressed
	player_command_ref.jump_released = last_command.jump_released
	player_command_ref.aiming_input = last_command.aiming_input
	player_command_ref.using_controller = last_command.using_controller


@rpc("unreliable")
func receive_command(remote_player_command_ref: PlayerCommand):
	last_command = remote_player_command_ref
