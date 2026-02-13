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
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal connection_failed
#signal player_info_updated(id: int, player_name: String, spawn_index:int)
signal player_info_updated(id: int, player_name: String, spawn_index: int)

const PORT := 8910
const MAX_CLIENTS := 3 # Host + 3 clients = 4 total players

# dictionary: id_num : player_name
var player_instances_by_player_id  := {}
var player_data := {} # id : { "name": string, "index": int, "color": Color }

# -- interesting solution
var current_tick: int = 0
var _timer: float = 0.0
const TICK_RATE := 1.0 / 60.0

# Using constants prevents typos across your whole project!
const KEY_NAME = "name"
const KEY_INDEX = "index"
const KEY_COLOR = "color"

func create_player_entry(p_name: String, p_index: int) -> Dictionary:
	return {
		KEY_NAME: p_name,
		KEY_INDEX: p_index,
		KEY_COLOR: Color.WHITE # Default
	}

func _physics_process(delta: float) -> void:
	_timer += delta
	while _timer >= TICK_RATE:
		current_tick += 1
		_timer -= TICK_RATE
		
		# --- BROADCAST LOGIC FOR LISTEN SERVER ---
		if multiplayer.is_server():
			# Every tick, the Host tells all Clients the current "Truth"
			for id in player_instances_by_player_id:
				var p = player_instances_by_player_id[id]
				# We send the tick number so clients can handle interpolation/jitter later
				sync_player_state.rpc(id, p.global_position, current_tick)

# The "State" broadcast from Host to Clients
@rpc("authority", "unreliable")
func sync_player_state(id: int, pos: Vector2, _server_tick: int):
	# Clients receive this
	if player_instances_by_player_id.has(id):
		var p = player_instances_by_player_id[id]
		
		# Don't let the server snap the position of our LOCAL player 
		# (Unless we are doing professional server reconciliation)
		if not p.is_multiplayer_authority():
			p.global_position = pos
			# We can store server_tick here later for interpolation logic
			

# Start hosting a server
func host(player_name: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT, MAX_CLIENTS) != OK:
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	player_data[1] = create_player_entry(player_name, 0)
	# Manually emit for host since peer_connected doesn't fire for yourself
	player_info_updated.emit(1, player_name, 0)


# Join an existing server
func join(ip: String, player_name: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, PORT) != OK:
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	#player_names_by_player_id [multiplayer.get_unique_id()] = player_name
	player_data[multiplayer.get_unique_id()] = create_player_entry(player_name, -1)

func leave() -> void:
	multiplayer.multiplayer_peer = null
	player_data.clear()


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
		for peer_id in player_data :
			var d = player_data[peer_id]
			#_register_player.rpc_id(new_player_id,
						  			#peer_id,
						  			#player_names_by_player_id [peer_id])
			_register_player.rpc_id(new_player_id, peer_id, d[KEY_NAME], d[KEY_INDEX])


func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)
	player_data.erase(peer_id)


func _on_client_connected_to_server() -> void:
	# -- client locally sends its associated name to the server / host
	# -- 1 is always host
	var my_id = multiplayer.get_unique_id()
	_update_player_name.rpc_id(1, player_data[my_id][KEY_NAME])
	#_update_player_name.rpc_id(1, player_names_by_player_id [multiplayer.get_unique_id()])


# RPC: A Client -> To Server: updates client display name
@rpc("any_peer", "reliable")
func _update_player_name(player_name: String) -> void:
	# -- only do this on the host
	if not multiplayer.is_server():
		return
	# Host calculates index ONCE
	
	# -- get id whoever is caling this for dict lookup
	# -- we accept the client's truth for its name (player_name)
	# -- we don't trust the client's truth for its id => get_remote_sender_id
	var sender_id = multiplayer.get_remote_sender_id()
	
	var spawn_index = player_data.size() 
	player_data[sender_id] = create_player_entry(player_name, spawn_index)

	# Broadcast updated name to all clients
	#var total_players = player_names_by_player_id.size()
	#var spawn_index = (total_players - 1)
	_register_player.rpc(sender_id, player_name, spawn_index)


# RPC: Server -> To All Clients
@rpc("authority", "call_local", "reliable")
func _register_player(id: int, p_name: String, s_index: int) -> void:
	# Everyone saves the server's dictated data
	player_data[id] = create_player_entry(p_name, s_index)
	player_info_updated.emit(id, p_name, s_index)
#@rpc("authority", "call_local", "reliable")
#func _register_player(id: int, player_name: String) -> void:
	#player_names_by_player_id [id] = player_name
	#player_info_updated.emit(id, player_name)


@rpc("authority", "call_local", "reliable")
func load_game_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


@rpc("authority", "reliable")
func sync_clock(server_tick: int):
	# We add a bit of "buffer" for the travel time (latency)
	# In a pro setup, you'd calculate RTT (Round Trip Time) here
	current_tick = server_tick + 2


# -- let the game actually tell you the lookup reference
# -- i.e. game injects this when player is spawned
func register_player_instance(peer_id: int, player: Player) -> void:
	player_instances_by_player_id[peer_id] = player


func unregister_player(peer_id: int) -> void:
	player_instances_by_player_id.erase(peer_id)


# -- small optimization to not do an RPC if 
func process_authoritative_command(peer_id, cmd: PlayerCommand) -> void:
	player_instances_by_player_id[peer_id].apply_command(cmd)


# -- this just routes a command to a player
@rpc("any_peer", "unreliable")
func send_input_to_host(byte_arr: PackedByteArray) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var cmd = PlayerCommand.deserialize(byte_arr)
	player_instances_by_player_id[sender_id].apply_command(cmd)
