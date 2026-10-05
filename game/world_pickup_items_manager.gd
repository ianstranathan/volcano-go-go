extends Node2D

var pickup_items_pool: Dictionary
var active_pickups: Array = []
var id_to_index: Array[int] = []
var next_id = 0

var pickup_scene = preload("res://items/pickup_item/pickup_item.tscn")
func _ready() -> void:
	# -- we make the pool
	for item_name in ItemsDb.ItemNames.values():
		pickup_items_pool[ item_name ] = []


func load_pickup_items_from_level_chunks( all_pickup_item_definitions: Array[Dictionary] ):
	var s = all_pickup_item_definitions.size()
	active_pickups.resize( s )
	id_to_index.resize( s )
	id_to_index.fill(-1) # -- unassigned positions default to an invalid index (-1) instead of 0
	
	# -- for all the pickup items that in scene, we need to tag them
	for i in range(s):
		var c = pickup_scene.instantiate()# all_pickup_item_definitions[i] # get_child( i )
		c.item_lookup = all_pickup_item_definitions[i].get("item_enum")
		call_deferred("add_child", c)
		c.set_deferred("global_position", 
					   all_pickup_item_definitions[i].get("global_position"))
		assert( c.spawn_id == -1, "incorrectly initialized pickup item" )
		c.spawn_id = next_id
		# -- map from ids to indices in active_pickups
		id_to_index[next_id] = i
		next_id += 1
		# --
		c.prediction_picked_up.connect( on_authority_player_walked_over_pickup )
		active_pickups[i] = c


func execute_tick( delta: float) -> void:
	# -- the whole reason why I actually did this data structue / pattern
	# -- is so this stuff is contiguous-ish
	for pickup in active_pickups:
		pickup.execute_tick( delta )
	
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------ despawn fns
# ------------------------------------------------------------------------------

# -- this is a callback from the pickup's area2D on body entered
# -- NOTE that pickup items only fire if it's a authority client
func on_authority_player_walked_over_pickup(spawn_id_to_remove: int,
											item_enum: ItemsDb.ItemNames) -> void:
	if spawn_id_to_remove >= id_to_index.size(): 
		return
	var target_index: int = id_to_index[spawn_id_to_remove]
	if target_index == -1: 
		return 
	
	# -- client prediction, authority client takes item
	var local_peer_id = multiplayer.get_unique_id()
	var local_player = NetManager.player_instances_by_player_id[local_peer_id]
	if local_player:
		local_player.take_pickup_item(spawn_id_to_remove, item_enum)
	
	# -- local despawn swap is destructive and we need this to be host authoritative
	# -- so, we need to broadcast the spawn before chaning our data structures
	if multiplayer.is_server():
		broadcast_pickup_despawn.rpc(spawn_id_to_remove, item_enum, 1)
	else:
		request_host_despawn_pickup.rpc_id(1, spawn_id_to_remove, item_enum)

	local_despawn(spawn_id_to_remove, item_enum)

@rpc("any_peer", "reliable")
func request_host_despawn_pickup(spawn_id_to_remove: int, 
								 item_enum: ItemsDb.ItemNames) -> void:
	if not multiplayer.is_server(): 
		return

	# -- does host still have this? (i.e. was there a race condition, reject the slower rpc)
	if spawn_id_to_remove < id_to_index.size() and id_to_index[spawn_id_to_remove] != -1:
		broadcast_pickup_despawn.rpc(spawn_id_to_remove, 
									 item_enum, 
									 multiplayer.get_remote_sender_id())


@rpc("authority", "call_local", "reliable")
func broadcast_pickup_despawn( spawn_id_to_remove: int, 
							   item_enum: ItemsDb.ItemNames, 
							   successful_peer_id: int) -> void:

	# -- just skip this if we're the player who did this (we predicted it already)
	if multiplayer.get_unique_id() == successful_peer_id:
		return
	if (spawn_id_to_remove < id_to_index.size() and 
		id_to_index[spawn_id_to_remove] != -1):
		
		# -- we tell the version of this player to take the item
		var remote_player: Player = NetManager.player_instances_by_player_id[successful_peer_id]
		if remote_player:
			remote_player.take_pickup_item(spawn_id_to_remove, item_enum)
		# -- we take care of the pickup item cleanup
		local_despawn(spawn_id_to_remove, item_enum)


# -- NOTE this is using the swap pop pattern
func local_despawn(spawn_id_to_remove: int, item_enum: ItemsDb.ItemNames) -> void:
	var target_index: int = id_to_index[spawn_id_to_remove]
	active_pickups[target_index].toggle(false)
	active_pickups[target_index].make_kinematic()
	var item_to_pool = active_pickups[target_index]
	pickup_items_pool[item_enum].append(item_to_pool)

	var last_index = active_pickups.size() - 1
	
	if target_index != last_index:
		#print( multiplayer.get_unique_id())
		#print( "in here \n ----------------")
		var last_item = active_pickups[last_index]
		active_pickups[target_index] = last_item
		id_to_index[last_item.spawn_id] = target_index
	
	id_to_index[spawn_id_to_remove] = -1
	active_pickups.pop_back()


# ------------------------------------------------------------------------------
# -------------------------------------------------------------------- spawn fns 
# ------------------------------------------------------------------------------

# -- this is a callback for the player emitting dropped_pickup_item
# -- NOTE this is what it looks in player.gd
			#if c.item_dropped:
				#var item_data = $ItemManager.get_current_item_data()
				#if item_data[0] >= 0: # -- the item db enum
					## -- signal connected to world_pickup_items_manager:
					## -- on_player_dropped_pickup_item
					#if is_multiplayer_authority():
						#dropped_pickup_item.emit( item_data[0], item_data[1], global_position )
						##print("in player: ", name, " w/ pos:", global_position)
						## -- need to drop item on all clients
						#drop_pickup_item()
# -- SO, we're already (predictively) dropping on authority client
# --     => skip the broadcast the caller 
func on_player_dropped_pickup_item(item_enum: ItemsDb.ItemNames,
								   item_slot_index: int,
								   player_kinematic_data: Array) -> void:
	#print("yooo")
	if multiplayer.is_server():
		broadcast_pickup_spawn.rpc( item_enum, 
									item_slot_index, 
									player_kinematic_data,
									1,
									next_id)
		local_spawn(item_enum, player_kinematic_data, next_id)
		next_id += 1
	else:
		request_host_spawn_pickup.rpc_id(1, item_enum, item_slot_index, player_kinematic_data)


# -- we need to have handling for rejecting the spawn request
@rpc("any_peer", "call_local", "reliable")
func request_host_spawn_pickup(item_enum: ItemsDb.ItemNames, 
							   item_slot_index: int, # -- to delete on remotes
							   player_kinematic_data: Array) -> void:
	if not multiplayer.is_server(): 
		return
	
	# -- tell everyone to spawn it with the same/ new id so arrays stay same
	broadcast_pickup_spawn.rpc( item_enum, 
								item_slot_index, 
								player_kinematic_data,
								multiplayer.get_remote_sender_id(),
								next_id)
	next_id += 1


@rpc("authority", "call_local", "reliable")
func broadcast_pickup_spawn(item_enum: ItemsDb.ItemNames, 
					 		item_slot_index: int, 
					 		player_kinematic_data: Array,
							successful_peer_id: int,
					 		server_assigned_id: int) -> void:
	# -- everyone spawns the pickup
	# -- and has the associated remote drop the item
	# -- except for the local player who has already predicted this in their
	# -- player script (see above at start of spawn stuff)

	local_spawn(item_enum, player_kinematic_data, server_assigned_id)
	var remote_player_version = NetManager.player_instances_by_player_id[successful_peer_id]
	if remote_player_version:
		if multiplayer.get_unique_id() == successful_peer_id:
			remote_player_version.host_confirmed_drop()
		else:
			remote_player_version.drop_pickup_item(item_slot_index, true)


func local_spawn(item_enum: ItemsDb.ItemNames,
				 player_kinematic_data: Array,
				 spawn_id: int) -> void:
	var pool: Array = pickup_items_pool[item_enum]
	var item: Node2D
	
	if pool.is_empty():
		# item = pickup_scene.instantiate()
		# item.spawn_id = spawn_id
		# item.prediction_picked_up.connect(on_authority_player_walked_over_pickup)
		# add_child(item)
		return 
	else:
		item = pool.pop_back()
	
	item.spawn_id = spawn_id
	
	item.toggle(true)
	item.set_spawn_kinematics( player_kinematic_data )
	
	
	active_pickups.append(item)

	if spawn_id >= id_to_index.size():
		var old_size = id_to_index.size()
		id_to_index.resize(spawn_id + 1)
		
		# -- NOTE allocate bigger chunks of blocks probably
		for idx in range(old_size, id_to_index.size()):
			id_to_index[idx] = -1

	id_to_index[spawn_id] = active_pickups.size() - 1
