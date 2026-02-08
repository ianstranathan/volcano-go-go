extends Node2D
class_name PlayerController

@onready var player: Player = get_parent()

var current_command := PlayerCommand.new()
var controller: Node2D


func _ready() -> void:
	if player.DEBUG_IS_LOCAL: #if is_multiplayer_authority():
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

func inject_remote_intent(
	move: Vector2,
	jump_pressed: bool,
	jump_released: bool
) -> void:
	# Only remote controllers accept external input
	if controller is RemotePlayerController:
		controller.inject_remote_intent(move, jump_pressed, jump_released)
