extends Node

"""
NetManager
==========

Authoritative host + client-prediction networking manager.

HIGH-LEVEL MODEL
----------------

The host is authoritative.

Clients:
    1. Run their local simulation predictively.
    2. Generate tick-stamped PlayerCommands.
    3. Send recent commands to the host.
    4. Intentionally simulate some number of ticks ahead of the host.
    5. Receive authoritative snapshots from the host.
    6. Reconcile their local predicted state against those snapshots.

The host:

    1. Runs the authoritative simulation.
    2. Receives future PlayerCommands from clients.
    3. Stores them in per-client circular buffers.
    4. When host tick N arrives, consumes command N.
    5. Sends authoritative snapshots.
    6. Monitors how much future input each client has supplied.
    7. Slowly adjusts the client's desired tick lead.

 Current simulation tick.
 Host:
     authoritative simulation tick
 Client:
     host tick + tick_lead
	
- tick_lead
    Controls how far ahead the client tries to generate input.
	The number of simulation ticks the client intentionally attempts to remain
	ahead of the host.

	Example:

	    HOST:
	        current_tick = 100

	    CLIENT:
	        current_tick = 108

	    tick_lead = 8

	The client is therefore generating command 108 while the host is currently
	processing command 100.	
	The host will eventually need those future commands.
	
- tick_multiplier()
    Makes the client's local clock very slightly faster/slower to
    compensate for long-term clock drift.

Because the network has latency and reliable RPCs can be queued, those
commands could arrive after the situation had already changed.
"""


# ------------------------------------------------------------ signals for lobby
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal player_info_updated(id: int, player_name: String, spawn_index: int)

# -----------------------------------------------------------------
var player_instances_by_player_id  := {}
var player_data := {} 
const INPUT_BUFFER_SIZE = 240  # -- at 60hz, this is 4 seconds of input
var remote_input_buffers := {} # -- future command buffers per client

# ---------------------------------------------------------- other stuff to tick
var game_world: Node2D

# ----------------------------------------------------------------- ticking vars
var current_tick: int = 0     # -- each machines tick number for state reconcile
var _timer: float = 0.0       # -- just counting up delta for tick increment
const TICK_RATE := 1.0 / 60.0 # --
var fract_tick: float = 0.0   # -- decimal remainder of the tick
var update_remote_modulo : int = 2 # -- e.g. 60hz -> 30hz
var clock_synced := false
var tick_lead: int = 10 # -- from initial ping, then dynamically updated
const MIN_TICK_LEAD := 4
const TARGET_TICK_LEAD := 8
const MAX_TICK_LEAD := 20

var remote_tick_leads: Dictionary = {}
"""
Highest command tick received from each client.
This is useful for diagnostics.

IMPORTANT:
    newest_input_tick - current_tick

does NOT tell us how many usable commands are actually available.

For example:

    current_tick = 100

    received:
        100
        101
        102
        104
        105

Newest = 105

But command 103 is missing, so the host can only safely continue through
102 before starvation.

Therefore we also calculate consecutive input availability.
"""
var remote_latest_input_tick: Dictionary = {}
# -------------------------------------------------------------------------
# Number of consecutive commands available beginning at current_tick.
# -------------------------------------------------------------------------
var remote_consecutive_input_ticks: Dictionary = {} # -- 
"""
host = 100

received:
[100 101 102 103 104 105]
=> consecutive = 6

As opposed to:
received:
100 101 102 [104 105 106]

consecutive = 3
"""

"""
Do not evaluate/change lead every simulation tick.

At 60 Hz:
    15 ticks = 250 ms
Therefore this controller runs roughly 4 times per second.
"""
const LEAD_EVALUATION_INTERVAL_TICKS := 15
var lead_evaluation_counter: int = 0

"""
STARVATION
----------

If fewer than this many consecutive commands are available, the client is
dangerously close to starving.

HEALTHY BUFFER
--------------

If more than this many consecutive commands are available, the client has
substantial spare input buffered.

The controller intentionally has hysteresis:

    increase lead quickly-ish
    decrease lead slowly

This prevents:
    +1
    -1
    +1
    -1

oscillation under ordinary jitter.
"""
const STARVATION_EVALUATIONS_REQUIRED := 2
const HEALTHY_EVALUATIONS_REQUIRED := 4

# -------------------------------------------------------------------------
# Per-client hysteresis counters.
# -------------------------------------------------------------------------
var remote_starvation_counts: Dictionary = {}
var remote_healthy_counts: Dictionary = {}

#var last_host_tick: int = 0
var average_offset: float = 0
const OFFSET_LERP_WEIGHT := 0.01 # 0.03
const MAX_CLOCK_ADJUST := 0.001  # 0.005
# ------------------------------------------------------------------------------
var tick_scheduler := TickScheduler.new()

# ------------------------------------------------------------------------------
var local_player_name: String = "Unknown Player"
const KEY_NAME = "name"
const KEY_INDEX = "index"
const KEY_COLOR = "color"

# ------------------------------------------------------------------------------
var drift_history: Array[float] = []
const DRIFT_WINDOW_SIZE = 61          # Odd number for exact median
const median_index = (DRIFT_WINDOW_SIZE - 1) / 2.

var pings: Array[float] = []
var ping_samples_needed: int = 10
# ------------------------------------------------------------------------------
# -- Steam debugging
var max_ticks_per_frame = 5
# ------------------------------------------------------------------------------
func _ready() -> void:
	multiplayer.peer_connected.connect(network_handshake)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_client_connected_to_server)

	player_info_updated.connect( _on_player_info_updated )
# problem: server is starting simuilation way before clients
# due to steam initialization lag
# Solution => clear the history of the player when it gets its ideal lead time

func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	
	if !clock_synced:
		if multiplayer.is_server():
			pass 
		else:
			# -- we're a client and we just bail out of here
			return
	
	var ticks_processed = 0
	
	_timer += delta * tick_multiplier()
	while _timer >= TICK_RATE and ticks_processed < max_ticks_per_frame:
		current_tick += 1
		_timer -= TICK_RATE
		ticks_processed += 1
		# ----------------------------------------------------------------------
		tick_scheduler.tick(current_tick)
		
		# ---------------------------------------------------- game world update
		if game_world:
			game_world.execute_tick(TICK_RATE)
		
		# ------------------------------------------------------- players update
		for id in player_instances_by_player_id:
			var _player = player_instances_by_player_id[id]
			
			# -- is this the machine running this NetManager's instance? (host or client)
			if id == multiplayer.get_unique_id():
				# -- then step the local player's tick immediately (prediction)
				# -- this is sent to the server's client keyed buffer of 
				# -- tick-marked / saved commands
				_player.player_controller.on_tick_generated(current_tick, TICK_RATE)
			
			# -- go through buffer of tick-marked / saved local player commands
			elif multiplayer.is_server():
				host_process_remote_client(id, _player)
			
			# -- at a slower Hz, host sends out RPC to give interpolation and
			# -- reconciliation data for client's local version
			if multiplayer.is_server() and (current_tick % update_remote_modulo == 0):
				var _state = _player.player_controller.get_player_state( current_tick )
				if _state.tick > 0: # -- don't reconcile against an unintialized state
					sync_player_state.rpc(current_tick,
										  id,
										  _state.serialize())
										
		if multiplayer.is_server():
			lead_evaluation_counter += 1
			if ( lead_evaluation_counter >= LEAD_EVALUATION_INTERVAL_TICKS):
				lead_evaluation_counter = 0
		
				#evaluate_remote_input_buffers()
		if (ticks_processed == max_ticks_per_frame and _timer >= TICK_RATE):
			pass
			# for diagnosing frame stalls.
			#
			#print(
			#	"WARNING: max_ticks_per_frame reached. ",
			#	"Remaining accumulator: ",
			#	_timer
			#)

		
	# -- this is used for smoothly moving remote copies
	fract_tick = _timer / TICK_RATE


func create_player_entry(p_name: String, p_index: int) -> Dictionary:
	return {
		KEY_NAME: p_name,
		KEY_INDEX: p_index,
		KEY_COLOR: Color.WHITE # Default
	}


func _on_client_connected_to_server() -> void:
	var my_id = multiplayer.get_unique_id()
	player_data[my_id] = create_player_entry(local_player_name, -1)
	_update_player_name.rpc_id(1, local_player_name)


func leave() -> void:
	player_data.clear()


func setup_remote_buffer(id: int):
	var buffer: Array[PlayerCommand] = []
	buffer.resize(INPUT_BUFFER_SIZE)
	# -- prefill with empty commands to avoid null checks
	for i in range(INPUT_BUFFER_SIZE):
		buffer[i] = PlayerCommand.new()
	remote_input_buffers[id] = buffer
	
	remote_latest_input_tick[id] = 0
	remote_consecutive_input_ticks[id] = 0
	remote_starvation_counts[id] = 0
	remote_healthy_counts[id] = 0

func network_handshake(new_player_id):
	if NetworkGateway.using_steam():
		wait_for_steam_handshake(new_player_id)
	else:
		player_registration(new_player_id)

#
#func wait_for_steam_handshake(id: int):
	#var steam_backend = NetworkGateway.active_backend
	#var steam_id = steam_backend.peer.get_steam_id_for_peer_id(id)
	#
	## If it's 0, the handshake isn't finished yet
	## -- this fully blocks until the connection works
	#if steam_id == 0:
		## Check again in a few frames
		#await get_tree().create_timer(0.1).timeout
		#wait_for_steam_handshake(id)
		#return
	#
	#print("Steam Handshake complete for Peer: ", id, " SteamID: ", steam_id)
	#player_registration(id)
func wait_for_steam_handshake(id: int, attempts: int = 0):
	var max_attempts = 50 # 5 seconds total (50 * 0.1)
	# case: the peer disconnected while we were waiting
	if not multiplayer.get_peers().has(id):
		print("Aborting handshake: Peer ", id, " disappeared.")
		return
	var steam_backend = NetworkGateway.active_backend
	var steam_id = steam_backend.peer.get_steam_id_for_peer_id(id)
	if steam_id == 0:
		if attempts >= max_attempts:
			print("Steam Handshake timed out for Peer: ", id)
			# -- gotta do something here, like remove the client
			return
			
		await get_tree().create_timer(0.1).timeout
		# -- recurse
		wait_for_steam_handshake(id, attempts + 1)
		return
	
	print("Steam Handshake complete for Peer: ", id, " SteamID: ", steam_id)
	player_registration(id)


# Called on server when a new peer connects
func player_registration(new_player_id: int) -> void:
	# -- ui shouldn't know anything about Network readiness
	NetworkGateway.get_avatar(new_player_id)
	# -- tell whoever is listening (i.e. a lobby)
	peer_connected.emit( new_player_id )
	if multiplayer.is_server():		
		# -- Send the new peer all the already existing players
		for id in player_data :
			var d = player_data[ id ]
			_register_player.rpc_id(new_player_id, id, d[KEY_NAME], d[KEY_INDEX])
	else:
		start_network_ping()


func _on_peer_disconnected(id: int) -> void:
	# -- tell whoever is listening (i.e. some way to catch the player leaving)
	peer_disconnected.emit(id)
	player_data.erase(id)


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


# RPC: Host -> To All Clients
@rpc("authority", "call_local", "reliable")
func _register_player(id: int, p_name: String, s_index: int) -> void:
	# Everyone saves the server's dictated data
	player_data[id] = create_player_entry(p_name, s_index)
	player_info_updated.emit(id, p_name, s_index)


func _on_player_info_updated(peer_id: int, _name: String, _idx: int) -> void:
	NetworkGateway.get_avatar(peer_id)

# -- let the game actually tell you the lookup reference
# -- i.e. game injects this when player is spawned
func register_player_instance(peer_id: int, player: Player) -> void:
	player_instances_by_player_id[peer_id] = player


func unregister_player(peer_id: int) -> void:
	player_instances_by_player_id.erase(peer_id)


# -- we're looping through each player, if we're the host, we send out our
# -- authoritative version of each player to every player (rpc generally)
# -- if it's not the client controlled player, we give it data to interpolate
# -- otherwise, we give it a reconcilliation check
# -- additionally, we're updating our dynamic tick multiplier

# -- NOTE
# -- we should be avoiding all these calls to PlayerState.new()
# -- hidden in PlayerState.deserialize( byte_arr )
# -- just make a local buffer to always put the deserialization in
@rpc("authority", "unreliable") 
func sync_player_state(hosts_current_tick: int, id: int, byte_arr: PackedByteArray):
	var host_versions_state = PlayerState.deserialize( byte_arr )
	
	# -- rpcs by default go to everyone but the caller
	# -- authority additionally guards against non-authority player nodes from
	# -- using this function
	# -- this implies that all checks are unecessary here of the form:
	# ------ multiplayer.is_server() &
	# ------ id == multiplayer.get_unique_id()

	# ---------------------------------------------------- tick drift per client
	update_average_offset(hosts_current_tick)
	
	# ----------------------------------------- interpolation and reconciliation
	var _player = player_instances_by_player_id.get(id)
	if !_player:
		return
	else:
		# -- if this is the locally controller player
		if id == multiplayer.get_unique_id():
			# -- we're adjusting how much our reconcile threshold is in pixels
			# -- based on the velocity which has to account for this
			var time_in_transit = average_offset * TICK_RATE
			_player.player_controller.reconcile( host_versions_state, time_in_transit)               
		else:
			# -- we just tell the client to save this state, the interpolation
			# -- happens on the local machine
			_player.player_controller.update_remote_state( host_versions_state )


# -- this is just filtering out the spikes in a collection of something
# -- in this case, we're saving the offset (how far away from the host's tick
# -- are we in sync_player rpc / frame
func get_median_drift(_tick: int, new_sample:float) -> float:
	if drift_history.size() == 0:
		drift_history.resize(DRIFT_WINDOW_SIZE)
	var _idx = _tick % DRIFT_WINDOW_SIZE
	drift_history[_idx] = new_sample
	var sorted = drift_history.duplicate()
	sorted.sort()
	return sorted[median_index]


var out_of_sync_frames = 0 # -- trying to soften how often hardsnapping happens

func update_average_offset(host_tick: int):
	var raw_offset = float(current_tick - host_tick)
	var filtered_offset = get_median_drift(host_tick, raw_offset)
	average_offset = lerp(average_offset, filtered_offset, OFFSET_LERP_WEIGHT)
	
	var current_error = tick_error()
	
	# -- clock snap if there's a massive desync
	# -- 30 ticks @60Hz is half of a second. i.e. 500ms
	# -- I don't think it can reasonably be higher than this
	if abs(current_error) > 30:
		out_of_sync_frames += 1
		if out_of_sync_frames > 20:
			print("Massive clock drift detected (", current_error, "). Snapping clock.")
			local_resync_to_host(host_tick)
	else:
		out_of_sync_frames = 0


func tick_error() -> float:
	"""
	Desired state: average_offset ~= tick_lead
	Example:
	    average_offset = 8
	    tick_lead      = 8
	    error = 0
	Let's say:
	    average_offset = 5
	    tick_lead      = 8
	    error = -3
	=> Client is not far enough ahead.
	On the other hand, let's say:
	    average_offset = 11
	    tick_lead      = 8
	    error = +3
	=> Client is too far ahead.
	"""
	return (average_offset - tick_lead)


var overlay_tick_multiplier = 1.0 # -- for debugging ui / overlay

func tick_multiplier() -> float:
	# -- Host clock is authoritative => 1.0
	# -- Don't adjust an unsynchronized client
	if multiplayer.is_server() or !clock_synced:
		return 1.0
	var _tick_error = tick_error()
	if abs(_tick_error) <= 2.0:
		return 1.0
	
	# We want to fix the drift over the course of seconds, not frames.
	# 0.001 means for every 1 tick of error, we adjust speed by 0.1%
	var adjustment = _tick_error * 0.001 
	
	# -- Negative, tick_error < 0 => that we're less than ideal tick lead and need to speed up
	# -- Positive, tick_error > 0 => that we're greater than ideal tick lead and need to slow down
	# -- remote client's ticking can't run faster than 1 + MAX_CLOCK_ADJUST 
	# -- or slower than 1 - MAX_CLOCK_ADJUST.
	# -- this is to prevent the giant oscillations I was seeing .80 - 1.20
	adjustment = clamp(adjustment, -MAX_CLOCK_ADJUST, MAX_CLOCK_ADJUST)
	overlay_tick_multiplier = 1.0 - adjustment
	return 1.0 - adjustment


# -- the client has to live in the "future" because of RTT & jitter
# -- the host needs a way of getting data and then calling
# --  them at the approritate tick
#func host_process_remote_client(id: int, _player: Player):
	## -- remote buffers are initialized when steam handshake completes
	#var buffer = remote_input_buffers.get(id)
	#if buffer == null:
		#return
#
	#var cmd: PlayerCommand = buffer[current_tick % INPUT_BUFFER_SIZE]
	#
	#var _controller =  _player.player_controller
	#var last_command_executed = _controller.last_command_executed
#
	## How far from the current tick is the command in the current-tick slot?
	#var buffer_fullness = cmd.tick - current_tick
	#if buffer_fullness > 15:
		#request_smaller_lead.rpc_id(id)
	#
	#if cmd.tick == current_tick:
		#_player.execute_tick(TICK_RATE, cmd)
		#_controller.last_command_executed = cmd
		##if cmd.collided_id > 0:
			##var other_player = player_instances_by_player_id.get(cmd.collided_id)
			##if other_player:
				##other_player.apply_external_impulse( -cmd.impulse )
	#else:
		## -- if it's an initialized player command
		#if cmd.tick > 0:
			##print("ewww")
			#_player.execute_tick(TICK_RATE, _controller.last_command_executed)
			## -- we're starving for input now
			## -- we need to dynamically increase this client's tick_lead
			#client_increase_tick_lead.rpc_id( id )
	## -- regardless we need to update the reconcilliation_state_buffer after doing
	#var _idx = _controller.get_circular_index(current_tick)
	#_controller.reconciliation_state_buffer[_idx].set_state(_player, current_tick)


# -- the client has to live in the "future" because of RTT & jitter
# -- the host needs a way of getting data and then calling
# -- them at the approritate tick
# -- simulation function should just do simulation....
# -- does the host have input for this tick? execute it : use fallback
func host_process_remote_client(id: int, player: Player) -> void:
	var buffer = remote_input_buffers.get(id)
	if buffer == null:
		return

	var controller = player.player_controller
	var cmd: PlayerCommand = buffer[current_tick % INPUT_BUFFER_SIZE]

	if cmd.tick == current_tick:
		player.execute_tick(TICK_RATE, cmd)
		controller.last_command_executed = cmd
	else:
		# Hold last known input/state.
		player.execute_tick(
			TICK_RATE,
			controller.last_command_executed
		)

	var idx = controller.get_circular_index(current_tick)
	controller.reconciliation_state_buffer[idx].set_state(
		player,
		current_tick
	)


# -- calculate contiguous availability
# -- how many contiguous commands do we have left to execute
func get_remote_consecutive_input_ticks(id: int) -> int:
	var buffer = remote_input_buffers.get(id)
	if buffer == null:
		return 0

	var available := 0

	for i in range(INPUT_BUFFER_SIZE):
		var tick := current_tick + i
		var cmd: PlayerCommand = buffer[tick % INPUT_BUFFER_SIZE]

		if cmd == null or cmd.tick != tick:
			break

		available += 1

	return available

# -- periodically, we're going to check the contiguous availability
#func evaluate_remote_input_buffers() -> void:
	#for id in remote_input_buffers:
		#var consecutive = get_remote_consecutive_input_ticks(id)
#
		#remote_consecutive_input_ticks[id] = consecutive
#
		#var latest: PlayerCommand = null
#
		## Find newest command we actually have.
		#for i in range(INPUT_BUFFER_SIZE):
			#var tick = current_tick + i
			#var cmd: PlayerCommand = remote_input_buffers[id][tick % INPUT_BUFFER_SIZE]
#
			#if cmd == null or cmd.tick != tick:
				#break
#
			#latest = cmd
#
		#if latest:
			#remote_latest_input_tick[id] = latest.tick
#
		#_update_remote_lead(id, consecutive)

#@rpc("authority", "reliable")
#func request_smaller_lead():
	#tick_lead -= 1
#
#@rpc("authority", "reliable")
#func client_increase_tick_lead():
	#tick_lead += 1

@rpc("authority", "reliable")
func client_increase_tick_lead():
	var old = tick_lead
	tick_lead = min(MAX_TICK_LEAD, tick_lead + 1)
	#print("LEAD +1: ", old, " -> ", tick_lead)

@rpc("authority", "reliable")
func request_smaller_lead():
	var old = tick_lead
	tick_lead = max(MIN_TICK_LEAD, tick_lead - 1)
	#print("LEAD -1: ", old, " -> ", tick_lead)


@rpc("any_peer", "unreliable")
func send_input_to_host(byte_arr: PackedByteArray) -> void:
	if not multiplayer.is_server(): 
		return
	var sender_id = multiplayer.get_remote_sender_id()
	var incoming_cmds = PlayerCommand.deserialize_list_of_commands(byte_arr) 

	if not remote_input_buffers.has(sender_id):
		return
	
	#if remote_input_buffers.has(sender_id):
	var buffer = remote_input_buffers[sender_id]
	for cmd in incoming_cmds:
		var idx = cmd.tick % INPUT_BUFFER_SIZE
		#remote_latest_input_tick[sender_id] = max(
				#remote_latest_input_tick.get(sender_id, 0),
				#cmd.tick
			#)
		# -- overwrite if the data is actually newer than what is 
		# -- currently in that buffer slot.
		if buffer[idx].tick < cmd.tick:
			buffer[idx] = cmd

# -- TODO
# -- it should actually be client predicted / driven
# -- so... 
# -- also, this should probably be in game or something, not here

# -- see pickup.gd
# -- only copy on the host's machine can trigger the pickup
#@rpc("authority", "call_local", "reliable")
#func sync_item_pickup(a_world_id:int, a_peer_id: int, item_lookup_enum: ItemsDb.ItemNames):
	## -- we want to tell the other players that this pickup exists
	#Events.item_picked_up.emit( a_world_id ) # -- what used to be a callback to delete the pickup
	#var _player = player_instances_by_player_id[ a_peer_id ]
	#if _player:
		##print("Picking up from id: ", multiplayer.get_unique_id())
		#_player.get_node("ItemManager").pick_up(item_lookup_enum)

# ------------------------------------------------------------ initial ping test
# ------------------------------------------------------------ for RRT value
func start_network_ping():
	pings.clear()
	_send_ping()


func _send_ping():
	var send_time = Time.get_ticks_msec()
	host_acknowledge_ping.rpc_id(1, send_time)


@rpc("any_peer", "reliable")
func host_acknowledge_ping(client_send_time: int):
	if multiplayer.is_server():
		client_receive_pong.rpc_id(multiplayer.get_remote_sender_id(), client_send_time)


@rpc("authority", "reliable")
func client_receive_pong(original_send_time: int):
	var arrival_time = Time.get_ticks_msec()
	var current_rtt = arrival_time - original_send_time
	pings.append(current_rtt)

	if pings.size() < ping_samples_needed:
		# Wait a tiny bit and ping again
		await get_tree().create_timer(0.1).timeout
		_send_ping()
	else:
		# -- get RTT
		tick_lead = clamp( _calculate_final_offset(),
							MIN_TICK_LEAD,
							MAX_TICK_LEAD)
		
		#tick_lead = _calculate_final_offset()
		# -- then start simulating on this client
		request_host_start.rpc_id(1)


@rpc("any_peer", "reliable")
func request_host_start():
	# -- maybe unecessary, but host guard
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	# -- clear the remote buffer for this player
	# -- we're reinitializing to make sure sure
	# -- that we have a clean slate to reconcile against
	setup_remote_buffer(sender_id)
	
	# -- maybe initialize them or something? but the host
	# -- shouldn't be calling anything in host_process_remote_client yet
	
	#var _player = player_instances_by_player_id.get( sender_id )
	#_player.velocity
	# -- now rpc the player to tell them they can start
	client_recieve_start_signal_and_tick.rpc_id( sender_id, sender_id, current_tick)
	
	# -- clear the host's version of this player's controller buffers
	var _player = player_instances_by_player_id.get( sender_id )
	if _player:
		_player.player_controller.reset_all_buffers()
		#_player.is_ready = true


# -- why 2x ideal tick lead?
# -- well, host sends his snapshot of a tick, it taks RTT / 2 to get there
# -- we sync to that, but now the host is T + ideal_lead on his end
# -- and we want to be + ideal_lead ahead => 2x
@rpc("authority", "reliable")
func client_recieve_start_signal_and_tick(id: int, ht: int):
	var _player = player_instances_by_player_id.get( id )
	#_player.is_ready = true
	current_tick = ht + tick_lead
	_timer = 0.0
	clock_synced = true
	average_offset = float(tick_lead)
	drift_history.fill(tick_lead)


func _calculate_final_offset() -> int:
	if pings.is_empty():
		# -- fallback / default
		return 5 
	# # -- get average
	var sum = 0.0
	for p in pings:
		sum += p
	var avg_rtt = sum / pings.size()
	
	# # -- calculate variance
	var variance_sum = 0.0
	for p in pings:
		variance_sum += pow(p - avg_rtt, 2)
	var variance = variance_sum / pings.size()
	
	# -- 2 * std_dev covers almost all the jitter population
	var jitter_ms = (2.0 * sqrt(variance)) 
	var jitter_ticks = ceil((jitter_ms / 1000.0) / TICK_RATE)
	
	var RTT_ms = avg_rtt
	var RTT_ticks = ceil((RTT_ms / 1000.0) / TICK_RATE)

	var base_buffer = lerp(2, 6, clamp(RTT_ms / 500.0, 0.0, 1.0))
	var lead = RTT_ticks + jitter_ticks + int(base_buffer)
	print("Initial Ping with avg RTT: ", avg_rtt, "ms")
	print("Initial Ping with std dev jitter: ", jitter_ms, "ms")
	return lead


func local_resync_to_host(host_tick: int):
	current_tick = host_tick + tick_lead
	_timer = 0.0
	average_offset = float(tick_lead)
	drift_history.fill(float(tick_lead))


#func _calculate_final_offset() -> int:
	#var max_rtt = 0
	## keeping track of max_rtt here
	#var avg_rtt = pings.reduce( func(acc, p): 
		#max_rtt = max(max_rtt, p)
		#return acc + p, 0) / pings.size()
	 ## -- scale base according to how much lag or jitter there was
	#var max_jitter_ms = (max_rtt - avg_rtt) / 1000.0
	#var jitter_ticks = ceil( max_jitter_ms / TICK_RATE )
	#var RTT_ms = avg_rtt / 1000.0
	#var RTT_ticks = ceil( RTT_ms / TICK_RATE)
	
	
	# ----------------------------------------------------------------- Refactor
	#var avg_rtt = pings.reduce( func(acc, x): return acc + x, 0) / pings.size()
	#var one_way_latency = (avg_rtt / 2.0) / 1000.0 # -- msec -> sec
	#
	#var max_rtt = 0
	#for p in pings: 
		#max_rtt = max(max_rtt, p)
	#var jitter_ms = max_rtt - avg_rtt
	#
	## -- sec -> ticks
	## -- 1 / 60 
	## -- NOTE magic number
	#var one_way_latency_in_ticks = ceil(one_way_latency / TICK_RATE) + 5 # -- + 2 for safety/jitter
	#var jitter_ticks = ceil((jitter_ms / 1000.0) / TICK_RATE)
	#
	#var lead = one_way_latency_in_ticks + jitter_ticks + 2
	#print("Initial Ping with Average RTT: ", avg_rtt, "ms")
	#print("Initial Ping with max jitter: ", max_jitter_ms, "ms")
	#
	#var lead = RTT_ticks + jitter_ticks + lerp(2, 7, clamp(RTT_ms / 500.0, 0., 1.))
	#print("Total lead: ", lead)
	#return lead
