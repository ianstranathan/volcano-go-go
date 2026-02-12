extends Node

"""
@rpc decoration string args:
"authority": only server can send out rpc
"call_local": run it on my machine too (normally rpc would run on everyone but the callers)

When you decorate a function with @rpc, you generate helper methods for
that function:
	
fn(args): Calling it normally

fn.rpc(args): This sends the function call to everyone else connected to the session.

fn.rpc_id(target_peer_id, args): This sends the function call only to one specific person.

"""
# Signals for connection events
signal peer_connected(id: int) # -- for: peer_connected.emit( new_player_id )
signal peer_disconnected(id: int)
signal connection_failed
signal player_info_updated(id: int, player_name: String)

const PORT := 8910
const MAX_CLIENTS := 3 # Host + 3 clients = 4 total players

# dictionary: id_num : player_name
var player_names := {}

# Start hosting a server
func host(player_name: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT, MAX_CLIENTS) != OK:
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	player_names[1] = player_name
	# Manually emit for host since peer_connected doesn't fire for yourself
	player_info_updated.emit(1, player_name)


# Join an existing server
func join(ip: String, player_name: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, PORT) != OK:
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	player_names[multiplayer.get_unique_id()] = player_name


func leave() -> void:
	multiplayer.multiplayer_peer = null
	player_names.clear()


func _ready() -> void:
	# -- this is actually a wrapper around the signal for design purposes
	# -- (From general / tutorial high level multiplayer article on Godot's doc website)
	# -- From docs: peer_connected( id: int)   : emitted with the new id on each
	#                                            other peer
	#               peer_disconected( id: int) : emitted on every remaining
	#                                            peer when one disconnects
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_client_connected_to_server)

	# -- there are more signals:
	# connection_failed()
	# server_disconnected()

# Called on server when a new peer connects
func _on_peer_connected(new_player_id: int) -> void:
	# -- this is what it would be doing normally
	peer_connected.emit( new_player_id )

	# -- this is so it fits our "Listen Server" architecture,
	# -- where one player acts as both a player and the host
	if multiplayer.is_server():		
	# -- Send the new peer all the already existing players
		for peer_id in player_names:
			_register_player.rpc_id(new_player_id,
						  			peer_id,
						  			player_names[peer_id])


func _on_peer_disconnected(id: int) -> void:
	peer_disconnected.emit(id)
	player_names.erase(id)


func _on_client_connected_to_server() -> void:
	# -- client locally sends its associated name to the server / host
	# -- 1 is always host
	_update_player_name.rpc_id(1, player_names[multiplayer.get_unique_id()])


# RPC: A Client -> To Server: updates client display name
@rpc("any_peer", "reliable")
func _update_player_name(player_name: String) -> void:
	# -- only do this on the host
	if not multiplayer.is_server():
		return
	# -- get id whoever is caling this for dict lookup
	# -- we accept the client's truth for its name (player_name)
	# -- we don't trust the client's truth for its id => get_remote_sender_id
	var sender_id = multiplayer.get_remote_sender_id()
	# -- add to servers copy of players
	player_names[sender_id] = player_name

	# Broadcast updated name to all clients
	_register_player.rpc(sender_id, player_name)


# RPC: Server -> To All Clients
@rpc("authority", "call_local", "reliable")
func _register_player(id: int, player_name: String) -> void:
	player_names[id] = player_name
	player_info_updated.emit(id, player_name)


@rpc("authority", "call_local", "reliable")
func load_game_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


#@rpc("authority", "call_local", "reliable")
#func spawn_item(item_type: String, item_id: int, spawn_pos: Vector2):
	#var item = load(item_paths[item_type]).instantiate()
	#item.name = str(item_id)
	#item.global_position = spawn_pos
	#get_tree().root.add_child(item)

# -------------------------------------------------------------

#extends Node
#
## Signals for connection events
#signal peer_connected(id: int)
#signal peer_disconnected(id: int)
#signal connection_failed
#signal player_info_updated(id: int, player_name: String)
#
#const PORT := 8910
#const MAX_CLIENTS := 3 # Host + 3 clients = 4 total players
#
## Tracks all connected players and their names
#var player_names := {}  # peer_id -> name
#
## Start hosting a server
#func host(player_name: String) -> void:
	#var peer := ENetMultiplayerPeer.new()
	#if peer.create_server(PORT, MAX_CLIENTS) != OK:
		#connection_failed.emit()
		#return
	#
	#multiplayer.multiplayer_peer = peer
	#player_names[1] = player_name
	## Manually emit for host since peer_connected doesn't fire for yourself
	#player_info_updated.emit(1, player_name)
#
## Join an existing server
#func join(ip: String, player_name: String) -> void:
	#var peer := ENetMultiplayerPeer.new()
	#if peer.create_client(ip, PORT) != OK:
		#connection_failed.emit()
		#return
	#
	#multiplayer.multiplayer_peer = peer
	#player_names[multiplayer.get_unique_id()] = player_name
#
## Disconnect from current session
#func leave() -> void:
	#multiplayer.multiplayer_peer = null
	#player_names.clear()
#
#func _ready() -> void:
	## Connect to Godot's built-in multiplayer signals
	#multiplayer.peer_connected.connect(_on_peer_connected)
	#multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	#multiplayer.connected_to_server.connect(_on_connected)
#
## Called on server when a new peer connects
#func _on_peer_connected(id: int) -> void:
	#peer_connected.emit(id)
	#if multiplayer.is_server():
		## Send all existing players to the new peer
		#for peer_id in player_names:
			#_register_player.rpc_id(id, peer_id, player_names[peer_id])
		## Broadcast new peer to everyone (placeholder name until they send theirs)
		#_register_player.rpc(id, "Player %d" % id)
#
## Called when any peer disconnects
#func _on_peer_disconnected(id: int) -> void:
	#peer_disconnected.emit(id)
	#player_names.erase(id)
#
## Called on client when successfully connected to server
#func _on_connected() -> void:
	## Client sends their chosen name to the server
	#var my_id = multiplayer.get_unique_id()
	#_update_player_name.rpc_id(1, player_names.get(my_id, "Player"))
#
## RPC: Client -> Server to update their display name
#@rpc("any_peer", "reliable")
#func _update_player_name(player_name: String) -> void:
	#if not multiplayer.is_server():
		#return
	#
	#var sender_id = multiplayer.get_remote_sender_id()
	#player_names[sender_id] = player_name
	## Broadcast updated name to all clients
	#_register_player.rpc(sender_id, player_name)
#
## RPC: Server -> All clients to register/update a player
#@rpc("authority", "call_local", "reliable")
#func _register_player(id: int, player_name: String) -> void:
	#player_names[id] = player_name
	#player_info_updated.emit(id, player_name)
