extends Area2D

@export var player_ref: Player
@export var throw_speed: float = 200

# -- just for local convenience
# -- so I don't forget to set it in the player for the intermediary state stuff
signal grabbed_a_player_or_dynamic_object( d: CharacterBody2D )
signal threw_a_player_or_dynamic_object()

#signal was_grabbed_by_another_player( peer_id: int)
#signal grabbed_another_player( peer_id: int)


var dynamic_objects_manager_ref

var grabbed_player_or_dynamic_object_ref = null:
	set(v):
		grabbed_player_or_dynamic_object_ref = v
		if v:
			grabbed_a_player_or_dynamic_object.emit( v )
		else:
			threw_a_player_or_dynamic_object.emit()
 

@onready var player: Player = get_parent()

func _ready() -> void:
	$CollisionShape2D.debug_color = Color(0, 0.6, 0.7, 0.42)


# -- what the player calls
func on_grab_pressed():
	# -- TODO
	# -- which to prioritize in the grab?
	# -- should favor player agency always => the closest one?
	if !grabbed_player_or_dynamic_object_ref:
		grab_player_or_dynamic_object()
	else:
		throw_player_or_dynamic_object()


@rpc("call_remote", "any_peer", "reliable")
func grab_rpc_everyone_else( peer_id: int, _id: int, grabbed_object: bool):
	# -- call_remote & only called from server, so host can't call it anyway
	if multiplayer.get_unique_id() != peer_id:
		if grabbed_object:
			grab_player_or_dynamic_object( dynamic_objects_manager_ref.get_object( _id ) )
		else:
			grab_player_or_dynamic_object( NetManager.player_instances_by_player_id[ _id ])


@rpc("authority", "reliable")
func make_authority_drop_it():
	throw_player_or_dynamic_object( Vector2.ZERO )


func grab_player_or_dynamic_object(object_override=null) -> void:
	var success = false
	# -- grab
	if !grabbed_player_or_dynamic_object_ref:
		# -- remote versions of local client need to grab same object or Player
		if object_override:
			# -- CASE is dynamic object
			grabbed_player_or_dynamic_object_ref = object_override
			grabbed_player_or_dynamic_object_ref.get_grabbed( self )
			# -- CASE is Player
		
		# -- this is how local player picks up a dynamic object
		else:
			var areas_that_can_be_grabbed = get_overlapping_areas().filter( func(grabbable_area):
					return can_grab( grabbable_area ))
			#print(areas_that_can_be_grabbed)
			var closest_area  = get_closest_grabbable( areas_that_can_be_grabbed )
			#print(closest_area)
			if closest_area:
				# -- Grab manager's area strictly interacts with dynamic grab layer
				# -- so, can see other grab manager areas and dynamic object areas
				var _parent = closest_area.get_parent()
				grabbed_player_or_dynamic_object_ref = closest_area.get_parent()
				assert(grabbed_player_or_dynamic_object_ref)
				# -- NOTE
				# -- this is a little slippery
				# -- I can't think of a better name than "get_grabbed"
				# -- so, we don't have to make a distinction on the type (DynamicObject or Player)
				#print("calling get_grabbed from peer: ", multiplayer.get_unique_id(),
					  #" from player ", player_ref.name, 
					  #" onto player: ", grabbed_player_or_dynamic_object_ref.name)
				grabbed_player_or_dynamic_object_ref.get_grabbed( self )

					
		success = (grabbed_player_or_dynamic_object_ref != null)
	
	if success and multiplayer.is_server():
		var grabbed_object_not_a_player = grabbed_player_or_dynamic_object_ref is DynamicObject
		var _id: int = (grabbed_player_or_dynamic_object_ref.spawn_id if 
			grabbed_object_not_a_player else int(grabbed_player_or_dynamic_object_ref.name) )
		grab_rpc_everyone_else.rpc( int(player_ref.name),
									_id,
									grabbed_object_not_a_player )


const sqrt_two_over_two = -1.41 / 2.;


@rpc("call_remote", "any_peer", "reliable")
func throw_rpc_everyone_else( peer_id: int, throw_vel):
	# -- call_remote & only called from server, so host can't call it anyway
	if multiplayer.get_unique_id() != peer_id:
		throw_player_or_dynamic_object( throw_vel )


func throw_player_or_dynamic_object(velocity_override=null):
	#print("--- calling on Peer ID: ", multiplayer.get_unique_id(), " ---")
	#print("object spawn id: ", grabbed_player_or_dynamic_object_ref.spawn_id)
	# -- projectile / thrown object should be 
	# -- RTT / 2. ahead, so you need to account for this
	assert(grabbed_player_or_dynamic_object_ref != null)
	# -- this can be a functional arg, might be cool to allow player
	# -- to have an upgrade or something (or a style like in downwell)
	# -- that allows throwing up or straight down or something
	var throw_dir = Vector2(sign(player.last_non_zero_move_input.x), -sqrt_two_over_two).normalized()
	var throw_vel = velocity_override if velocity_override else throw_dir * player.throw_speed
	#print("throwing: ", get_multiplayer_authority())
	#print("throwing is server: ", multiplayer.is_server())
	grabbed_player_or_dynamic_object_ref.global_position += throw_dir * 20.0
	grabbed_player_or_dynamic_object_ref.get_thrown( throw_vel )
	grabbed_player_or_dynamic_object_ref = null
	
	if multiplayer.is_server():
		# -- have to include throw_vel as last_non_zero_move_input might disagree between clients
		throw_rpc_everyone_else.rpc( int(player_ref.name), throw_vel )



func can_grab( grabbable_area : Area2D) -> bool:
	# -- are we facing the way? / is the item in front of us
	var r = grabbable_area.global_position - global_position
	var facing_dir = player_ref.last_non_zero_move_input.x
	return (facing_dir * r.x >= 0)


func _process(_delta: float) -> void:
	if get_tree().debug_collisions_hint:
		if has_overlapping_areas():
			$CollisionShape2D.debug_color = Color(1, 0, 1, 0.4) 
		else:
			$CollisionShape2D.debug_color = Color(0, 0.6, 0.7, 0.42)


func get_closest_grabbable( grabbable_areas: Array):
	if grabbable_areas.is_empty():
		return
	
	return grabbable_areas.reduce(func(a, b):
		return a if a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position) else b
	)


func set_player_weight_modifier():
	pass


func get_grabbed_object() -> CharacterBody2D:
	return grabbed_player_or_dynamic_object_ref
