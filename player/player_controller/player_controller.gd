extends Node2D
class_name PlayerController


"""
Local: run command immediately, sends command to the host via rpc_id(1, args)
Host: Receives command, runs it on their version the player

Host broadcasts their remote copies state (See _physics_process in  NetManager) 
to everyone else at a lower hz

When a client recieves this broadcast (see sync_player_state in NetManager )
it either updates the remote data (See update_remote_state in this script )
if it's a remote copy
Or it reconciles the state (checks to make sure the position, velocity, and
state variables agree to within a certain margin)
"""

@onready var TICK_RATE = NetManager.TICK_RATE
@onready var player: Player = get_parent()

# - -assigned in game script to player at spawn
# -- a reference to the level managers moving_platform_components dictionary
# -- for state assignment in update remote state
var moving_platform_components_dict

# -- reference for dynamic objects, assigned in game script to player at spawn
var dynamic_objects_manager_ref

# -- either RemotePlayerController or LocalPlayerController
var controller: LocalPlayerController

# -- so we're keeping 60 ticks, or 2 second a 60hz physics sim
var input_and_state_buffer_size: int = 240
var command_history_buffer: Array[PlayerCommand] = []
var reconciliation_state_buffer: Array[PlayerState] = []

# -- 
var interpolation_buffer: Array[PlayerState] = []
var interpolation_buffer_size: int = 30

# -- 
var last_command_executed: PlayerCommand = PlayerCommand.new()
var last_confirmed_interpolation_tick: int = -1
var last_confirmed_reconcilliation_tick: int = -1

var recent_cmds: Array[PlayerCommand] = []
var recent_cmd_range := 5 # -- we're sending 5 commands or 105 bytes to host every tick

# -- NOTE
# -- This requires the spawning logic to give authority to a node before
# -- that node enters the scene tree
func _ready() -> void:
	# -- if we're a local player, we're going to be predicting & reconciling
	if is_multiplayer_authority():
		controller = LocalPlayerController.new()
		add_child(controller)
		
	# -- for now, let's just put them on everybody, but I think I can cut this out
	command_history_buffer.resize( input_and_state_buffer_size )
	reconciliation_state_buffer.resize( input_and_state_buffer_size )
	interpolation_buffer.resize( interpolation_buffer_size )
	recent_cmds.resize(recent_cmd_range)
	reset_all_buffers()


func reset_all_buffers():
	for i in range(input_and_state_buffer_size):
		command_history_buffer[i] = PlayerCommand.new()
		reconciliation_state_buffer[i] = PlayerState.new()
		
		# -- size recent cmd buffer
		if i < recent_cmd_range:
			recent_cmds[i] = PlayerCommand.new()
		if i < interpolation_buffer_size:
			interpolation_buffer[i] = PlayerState.new()


func get_player_state( a_tick: int) -> PlayerState:
	return reconciliation_state_buffer[ get_circular_index( a_tick ) ]


func get_circular_index( a_tick: int) -> int:
	return a_tick % input_and_state_buffer_size


func update_remote_state(host_state: PlayerState):
	#print("Client received state for: ", host_state.tick, " Buffer size: ", interpolation_buffer.size())
	var incoming_tick = host_state.tick
	if incoming_tick <= 0:
		# -- ignore, I chose -1 as intialization value
		return
	# -- actually look up the local platform
	# -- see in game.tscn:
	# 	a_player.get_node_or_null("PlayerController").moving_platform_components_dict = world_level_manager.moving_platform_components_dict

	if host_state.platform_id != -1:
		host_state.platform = moving_platform_components_dict.get(host_state.platform_id)
	
	#if host_state.grabbed_dyanmic_object_id != -1 and player.grabbed_dynamic_object_ref == null:
		## -- do we even need to be recording this?
		#host_state.grabbed_dyanmic_item = dynamic_objects_manager_ref.get_object(host_state.grabbed_dyanmic_object_id)
		#player.grab_dynamic_object( host_state.grabbed_dyanmic_item )

	
	interpolation_buffer[incoming_tick % interpolation_buffer_size] = host_state
	
	if incoming_tick > last_confirmed_interpolation_tick:
		last_confirmed_interpolation_tick = incoming_tick


# -- TODO, check args using delta
# -- Called from netmanager on a local controller
# -- this allows a deterministic delta time (NetManager's TICK_RATE)
func on_tick_generated(tick: int, delta: float):
	# -- we don't need to check is_multiplayer_authority as this is
	# -- already being done from NetManager checking IDs
	
	# -- this is being called from NetManager, so no need to make a function call
	# -- or accessor back to NetManager
	var _index = get_circular_index(tick)
	# ----------------------------------------------------- record cmd and state
	var current_command = command_history_buffer[_index]
	current_command.tick = tick                       # -- timestamp the command
	# -- reset all transient data
	#current_command.collided_id = -1
	#current_command.impulse = Vector2.ZERO
	controller.update_command(current_command, delta) # -- update the command

	player.execute_tick(delta, current_command) # -- client prediction
	last_command_executed = current_command
	reconciliation_state_buffer[_index].set_state( player, tick )

	# -- no need to rpc if this is the host (host is the truth afterall)
	if !multiplayer.is_server():
		for i in range(recent_cmd_range):
			# -- get last N commands from existing command history
			var check_tick = tick - i # i is zero we're at tick, i is -5, we're 5 cmds back
			if check_tick > 0: # -- only do this if it's a valid tick
				# -- is this actually aligned to tick modulo?
				#var _idx = check_tick % recent_cmd_range
				#recent_cmds[_idx] = command_history_buffer[get_circular_index(check_tick)]
				recent_cmds[i] = command_history_buffer[get_circular_index(check_tick)]
		#print("Client sending state for: ", current_command.tick)
		# -- send the command to the host for it to move its remote copies
		# -- and tell the other players that this player moved
		#NetManager.send_input_to_host.rpc_id(1, current_command.serialize())
		NetManager.send_input_to_host.rpc_id(1, PlayerCommand.serialize_list_of_commands(recent_cmds))


# -- TODO
@onready var min_offset: float = NetManager.tick_lead
@onready var max_offset: float = 2 * NetManager.tick_lead
@onready var current_offset: float = min_offset
#var shortage_frames: int = 0

# -- maybe this is called "Entity Interpolation" in the literature
func _process(delta: float):
	# -- no interpolating on a client controlled player
	if is_multiplayer_authority(): 
		return
	
	if !player.is_interpolatable:
		player.state_fn_from_state( delta )
		return
	# -- NetManager.current_tick + NetManager.fract_tick is the actual current
	# -- time on this local client's machine.
	# -- We shift this time backward (by at least NetManager.tick_lead) to have
	# -- gaurenteed data from server for these ticks; then we can
	# -- slide in a continuous manner between them for visual fidelity
	var render_tick = (NetManager.current_tick + NetManager.fract_tick) - current_offset
	#print("Client render_tick: ", render_tick, " Buffer has: ", interpolation_buffer.map(func(d): return d.tick))
	var point_a: PlayerState = null
	var point_b: PlayerState = null

	# ----------------------------------------------- OPTIMIZING walking backwards
	for i in range(interpolation_buffer_size):
		# -- e.g. last confirmed is 100 => we start at 100 and walk backwards
		# -- to ~70 or 80 (depending on how large the interpolation buffer is)
		var check_tick = last_confirmed_interpolation_tick - i
		var data = interpolation_buffer[check_tick % interpolation_buffer_size]
		
		# -- skipping over missed/ empty slots (host is sending this data at like 30hz)
		# -- so not every slot will be filled
		if data == null or data.tick == -1:
			continue
		
		if data.tick <= render_tick:
			point_a = data
			# Since we are walking backwards, the very first tick <= render_tick 
			# we find is guaranteed to be the right one
			#var next_data = interpolation_buffer[(check_tick + 1) % interpolation_buffer_size]
			#if next_data != null and next_data.tick > render_tick:
				#point_b = next_data
			break 
		else:
			point_b = data # This was > render_tick, so it's a candidate for point_b

	player.pos_previous = player.global_position
	if point_a and point_b:
		# -- slowly lerp towards the min offset
		current_offset = lerp(current_offset, min_offset, 0.1 * delta)
		# -- normalize (0, 1) t
		var t = (render_tick - point_a.tick) / float(point_b.tick - point_a.tick)
		t = clamp(t, 0.0, 1.0)
		
		var visual_velocity:= point_a.vel.lerp(point_b.vel,t)
		player.update_visual_facing(visual_velocity.x)
		
		# -- NOTE
		# -- we're not interpolating the player's world position while they're on a moving platform.
		# -- wee're interpolating their position relative to the platform, then reconstructing their world position 
		# -- using the platform's current transform
		
		# -- same mathematical idea used throughout computer graphics with hierarchical transforms (parent/child transforms), 
		# -- except we're applying it to network interpolation.
		
		# Local-space snapshot interpolation for moving platforms. 
		# While attached to a moving platform, player snapshots store the player's 
		# position in the platform's local coordinate space. 
		# Clients interpolate this local-space position and 
		# reconstruct world-space positions each render frame using the platform's current transform
		
		if point_a.is_on_platform and point_b.is_on_platform and point_a.platform_id == point_b.platform_id:
			var platform = point_a.platform
			#print("id: ", point_a.platform_id, "and instance:", platform)
			if platform:
				# Interpolate in local space relative to the platform
				var interpolated_local_pos = point_a.local_pos.lerp(point_b.local_pos, t)
				# Bring it into the present world space using the platform's current position
				# so, where is this local coordinate right now, using the platform's current transform
				# (we're using platform's present position, not the one from either network snapshot)
				player.global_position = platform.to_global(interpolated_local_pos)
			# -- We're already doing this
			#else:
				## Fallback if the platform was destroyed or not found
				#player.global_position = point_a.pos.lerp(point_b.pos, t)
		else:
			# Fallback to standard global interpolation (transitioning on/off platforms, or on the ground)
			player.global_position = point_a.pos.lerp(point_b.pos, t)
		
		
		player.movement_state_transition_to(point_a.movement_state)

	# -- handling case where network lags and there's no future packet
	elif point_a:
		current_offset = min(current_offset + 0.2, max_offset)
		if point_a.is_on_platform:
			var platform = point_a.platform
			if platform:
				player.global_position = platform.to_global(point_a.local_pos)
			else:
				player.global_position = point_a.pos
		else:
			player.global_position = point_a.pos
		player.update_visual_facing(point_a.vel.x)
		player.movement_state_transition_to(point_a.movement_state)
		
	player.pos_current = player.global_position

#func _process(delta):
	#if is_multiplayer_authority(): 
		#return
#
	## 1. Determine exactly what tick we want to be rendering
	#var render_tick_float = (NetManager.current_tick + NetManager.fract_tick) - current_offset
	#var tick_a = floori(render_tick_float)
	#var tick_b = tick_a + 1
#
	## 2. Direct Indexing (No searching!)
	#var data_a = interpolation_buffer[tick_a % interpolation_buffer_size]
	#var data_b = interpolation_buffer[tick_b % interpolation_buffer_size]
#
	## 3. Validation: Ensure these aren't stale data from the last wrap-around
	## (Check if the tick stored at that index is actually the tick we want)
	#if data_a.tick == tick_a and data_b.tick == tick_b:
		#var t = render_tick_float - tick_a
		#player.global_position = data_a.pos.lerp(data_b.pos, t)
		#player.movement_state_transition_to(data_a.movement_state)
		#current_offset = lerp(current_offset, min_offset, 0.1 * delta)
	#elif data_a.tick == tick_a:
		## We have the past but not the future (buffer shortage)
		#player.global_position = data_a.pos
		#current_offset = min(current_offset + 0.2, max_offset)
	#else:
		## Complete desync - we don't even have point A
		## This usually happens during lag spikes
		#pass
#
	#player.pos_current = player.global_position

# -- where should we put these consts?
const BASE_POS_TOLERANCE: float = 5.0 # in pixels
#const ROT_TOLERANCE: float = 0.06 # in radians (i.e. about 3.5 degrees)


func reconcile(host_state: PlayerState, _time_in_transit: float):
	# -- we don't care about reconciling to an uninitialized state
	if host_state.tick <= 0:
		return
	
	
	# -- maybe we dropped some frames and accidentally indexed into a past
	# -- state from our circular buffer
	if last_confirmed_reconcilliation_tick > host_state.tick:
		return
	last_confirmed_reconcilliation_tick = host_state.tick
	
	var past_idx = get_circular_index(host_state.tick)
	var stored_state = reconciliation_state_buffer[past_idx]
	
	# -- if we don't have it in the buffer, we can't do anything with it
	if stored_state.tick != host_state.tick:
		return
	
	
	# -- this is velocity adjusted, how much could we have diverged while
	# -- message was being sent, not perfect but seems to fix the hookshot
	var pos_tolerance = BASE_POS_TOLERANCE + player.velocity.length() * _time_in_transit
	#pos_tolerance = min() # what's a good min?
	
	var is_grabbed = (stored_state.movement_state == Player.MovementStates.GRABBED
		and host_state.movement_state == Player.MovementStates.GRABBED
	)
	
	var is_pos_error = false
	if !is_grabbed:
		is_pos_error = (stored_state.pos.distance_squared_to(
			host_state.pos) > pos_tolerance * pos_tolerance)

	#var is_pos_error = (stored_state.pos.distance_squared_to(host_state.pos) >
						#pos_tolerance * pos_tolerance)
	#var rot_error = abs(angle_difference(stored_state.rot, host_state.rot))
	var needs_reconciled = (
		is_pos_error or
		#rot_error > ROT_TOLERANCE or 
		stored_state.movement_state != host_state.movement_state
	)

	# -- snap to the correct position in the past
	# -- and replay all the commands saved between this tick and the current tick
	if needs_reconciled:
		print("ahhh")
		#print(stored_state.movement_state != host_state.movement_state)
		# -- this is the vector from the old/non-reconciled position
		# --  to the new/ reconciled position
		player.reconciled.emit( host_state.pos - player.global_position )
		#print("is_pos_error: ", is_pos_error, "& hosts version's pos:", stored_state.pos, "vs.", host_state.pos )
		#print("stored_state: ", stored_state.movement_state, "& hosts version's state:", host_state.movement_state)
		# -- correct the past record to authoritative host
		var copy_host_state = PlayerState.new()
		copy_host_state.copy_state(host_state)
		reconciliation_state_buffer[past_idx] = copy_host_state
		#stored_state.set_state(player, host_state.tick)
		
		# -- reset all the state variables to that moment
		player.global_position = host_state.pos
		player.velocity = host_state.vel
		player.rotation = host_state.rot
		player.movement_state = host_state.movement_state as Player.MovementStates

		
		
		# -- now we need to re-run all our commands starting after this tick
		var replay_tick = host_state.tick + 1
		# -- add a flag so sounds and other stuff don't play while reconciling
		player.is_replaying = true
		
		while replay_tick <= NetManager.current_tick:
			var r_idx = get_circular_index(replay_tick)
			var cmd = command_history_buffer[r_idx]

			# -- maybe we need to gaurd against accidentally getting a
			# -- time discontinuous command or non-monotonic-ish
			#if cmd.tick < replay_tick:
				#replay_tick += 1 # -- no infinite loops here friend
				#continue
			# -- we always do a thing then save it
			player.execute_tick(TICK_RATE, cmd)
			last_command_executed = cmd
			reconciliation_state_buffer[r_idx].set_state(player, replay_tick)

			replay_tick += 1
		
		player.is_replaying = false
		
# -- when local client hits a remote player
#func inject_predicted_state(predicted_vel: Vector2):
	## -- most recent interpolated state
	#var last_state = interpolation_buffer[last_confirmed_interpolation_tick % interpolation_buffer_size]
	#
	## -- future predicted state from collision
	#var future_state = PlayerState.new()
	#future_state.tick = last_confirmed_interpolation_tick + 1
	#future_state.vel = predicted_vel
	#future_state.pos = last_state.pos + predicted_vel
	#future_state.movement_state = last_state.movement_state 
#
	#update_remote_state(future_state)

func inject_predicted_state(new_velocity: Vector2):
	var base_data = interpolation_buffer[last_confirmed_interpolation_tick % interpolation_buffer_size]
	var base_tick = last_confirmed_interpolation_tick
	var base_pos = base_data.pos #if base_data.pos != Vector2.ZERO else player.global_position
	
	if base_pos == Vector2.ZERO:
		base_pos = player.global_position
		
	for i in range(1, 5):
		var future_state = PlayerState.new()
		future_state.tick = base_tick + i
		future_state.vel = new_velocity
		# Linear prediction from the point of impact
		future_state.pos = base_pos + (new_velocity * TICK_RATE * i)
		future_state.movement_state = base_data.movement_state
		update_remote_state(future_state)

	# If our render clock is too far in the past, we won't see the injection.
	# We can "heat up" the interpolation by reducing the offset temporarily.
	# This forces the _process loop to look closer to 'base_tick + i'
	#current_offset = clamp(current_offset - 1.0, min_offset, max_offset)
	current_offset = min_offset
