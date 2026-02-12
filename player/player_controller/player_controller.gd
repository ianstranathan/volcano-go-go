extends Node2D
class_name PlayerController

@onready var player: Player = get_parent()

var current_command := PlayerCommand.new()
var controller: Node2D

var input_buffer: Array[PlayerCommand] = []
var last_confirmed_id: int = 0

var DEBUG_IS_LOCAL := false
func _ready() -> void:
	DEBUG_IS_LOCAL = player.DEBUG_IS_LOCAL
	if DEBUG_IS_LOCAL: #if is_multiplayer_authority():
		controller = LocalPlayerController.new()
	else:
		controller = RemotePlayerController.new()
		controller.player = player
	add_child(controller)


func _physics_process(delta):
	# -- we need a data packet
	# -- it's either filled by the network
	# -- or filled by local client
	if controller:
		controller.update_command(current_command, delta)
	# -- then it's just passed to player
	# -- player doesn't care who it's from
	if player:
		player.apply_command(current_command)


func inject_remote_intent( data_packet: PackedByteArray) -> void:
	if DEBUG_IS_LOCAL:
		return
	else:
		controller.inject_remote_intent(data_packet)


#func _physics_process(delta: float) -> void:
	#if is_multiplayer_authority():
		## 1. Update our sequence ID
		#current_command.sequence_id += 1
#
		## 2. Get input from local (keyboard/mouse/gamepad)
		#controller.update_command(current_command, delta)
#
		## 3. Client-Side Prediction: Apply it locally now
		#player.apply_command(current_command)
#
		## 4. Save a copy for potential reconciliation
		## We must duplicate() so the buffer has a snapshot of these values
		#var buffer_copy = PlayerCommand.deserialize(current_command.serialize())
		#input_buffer.append(buffer_copy)
#
		## 5. Send to Server
		##_server_receive_input.rpc_id(1, current_command.serialize())
	#else:
		## Remote proxies rely on the server state sent to the RemoteController
		#controller.update_command(current_command, delta)
		#player.apply_command(current_command)

# -----------------------------------------------------
#@rpc("any_peer", "unreliable")
#func _server_receive_input(command_byte_arr: PackedByteArray) -> void:
	#if not multiplayer.is_server():
		#return
	#
	#var cmd = PlayerCommand.deserialize(command_byte_arr)
	#
	## --
	#var sender_id = multiplayer.get_remote_sender_id()
	#
	## Server applies the command to its authoritative version of this player
	#player.apply_command(cmd)
	#
	## Send the "Truth" back to everyone
	## WHO IS SENDING THIS
	## PLAYERCONTROLELR OR REMOTE CONTROLLER
	#var state = {
		#"id": cmd.sequence_id,
		#"pos": player.global_position,
		#"vel": player.velocity if "velocity" in player else Vector2.ZERO
		#}
	#_client_receive_world_state.rpc(state)
#
## -- host let's everyone know
#@rpc("authority", "unreliable")
#func _client_receive_world_state(state: Dictionary) -> void:
	#if is_multiplayer_authority():
		## --- RECONCILIATION ---
		#last_confirmed_id = state.id
		#
		## 1. Snap to the server's authoritative position
		#player.global_position = state.pos
		#
		## 2. Clear out the buffer for everything the server has already seen
		#while input_buffer.size() > 0 and input_buffer[0].sequence_id <= last_confirmed_id:
			#input_buffer.remove_at(0)
			#
		## 3. REPLAY: Fast-forward the local player to the present
		#for pending_cmd in input_buffer:
			#player.apply_command(pending_cmd)
	#else:
		## --- INTERPOLATION ---
		## Tell the RemotePlayerController where the server says this player is
		#if controller.has_method("on_server_state_received"):
			#controller.on_server_state_received(state.pos, state.id)
# ------------------------------------------------------------------------------
