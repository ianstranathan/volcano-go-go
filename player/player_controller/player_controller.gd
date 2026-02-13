extends Node2D
class_name PlayerController


"""
Local: Runs the logic immediately
Local: Sends Command to the host via rpc_id(1, args)
Host: Receives command, runs it on their "Server version" the player, 
and then broadcasts that everyone else.


Methods:
	- serialize_command
	- deserialize_command: 
	- serialize_state
	- deserialize_state
"""

@onready var player: Player = get_parent()

# -- stuff to send over network that can get serialized
var current_command := PlayerCommand.new()
var current_player_state := PlayerState.new()

# -- either RemotePlayerController or LocalPlayerController
var controller: Node2D

# -- so we're keeping 60 ticks, or 1 second a 60hz physics sim
var buffer_size: int = 60 # -- how many states and inputs to keep a record of
var input_buffer: Array[PlayerCommand] = []
var player_state_buffer: Array[PlayerState] = []
var last_confirmed_tick: int = 0

# -- NOTE
# -- This requires the spawning logic to give authority to a node before
# -- that node enters the scene tree
func _ready() -> void:
	if is_multiplayer_authority():
		controller = LocalPlayerController.new()
	else:
		controller = RemotePlayerController.new()
	add_child(controller)


func _physics_process(delta):
	if not is_multiplayer_authority():
		return
	controller.update_command(current_command, delta)
	if multiplayer.is_server():
		# -- skip RPC 
		NetManager.process_authoritative_command( multiplayer.get_unique_id(),
												  current_command)
	else:
		# predict locally
		player.apply_command(current_command)
		NetManager.send_input_to_host.rpc_id(1, current_command.serialize())
