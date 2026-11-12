class_name NetworkCommandComponent
extends Node

signal command_executed(action: String, data: Dictionary, sender_id: int)

@export var authority_mode: AuthorityMode = AuthorityMode.OWNER_AUTH

enum AuthorityMode {
	SERVER_AUTH, # Only the server can initiate commands
	OWNER_AUTH   # The client who owns the parent node can initiate commands
}

## Universal RPC gateway for all actions on this object
@rpc("any_peer", "call_local", "reliable")
func _receive_command(action: String, data: Dictionary) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id() # Fallback for local calls

	# If we are the server, validate the request before processing/broadcasting
	if multiplayer.is_server():
		if not _validate_request(sender_id, action, data):
			return

	# Emit signal so the parent node (or sibling scripts) can react
	command_executed.emit(action, data, sender_id)


## Public method called by parent nodes to trigger an action locally + across network
func send_command(action: String, data: Dictionary = {}) -> void:
	if multiplayer.has_multiplayer_peer():
		# Send to the server (Peer ID 1) using call_local so it executes immediately on caller
		_receive_command.rpc_id(1, action, data)
	else:
		# Offline mode / singleplayer fallback
		_receive_command(action, data)


func _validate_request(sender_id: int, action: String, data: Dictionary) -> bool:
	# Basic validation: Check if sender matches the owner of the parent node
	if authority_mode == AuthorityMode.OWNER_AUTH:
		var parent_node = get_parent()
		if parent_node and parent_node.has_method("get_multiplayer_authority"):
			return sender_id == parent_node.get_multiplayer_authority()
			
	# Default to allowing if server-auth or fallback
	return true
