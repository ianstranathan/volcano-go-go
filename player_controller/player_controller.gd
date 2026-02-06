
# PlayerController.gd
extends Node2D
class_name PlayerController

@export var player: Player

var current_command := PlayerCommand.new()
var controller: Node

func _ready() -> void:
	if is_multiplayer_authority():
		controller = LocalPlayerController.new()
	else:
		controller = RemotePlayerController.new()
	add_child(controller)

func _physics_process(delta):
	# -- we need a data packet
	# -- it's either filled by the network
	# -- or filled by local client
	if controller:
		controller.update_command(current_command, delta)
	if player:
		player.apply_command(current_command)
