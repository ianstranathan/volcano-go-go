extends Node2D

"""

"""
# -- TODO
var player_data_dict:Dictionary = {} # -- id to player_data

@export var player_scene: PackedScene
@export var players_container: Node2D
@export var spawn_points: Node2D
@export var ui: Control
@export var wager_window: WagerWindow
@export var post_processing_quad: Sprite2D
@export var world_pickup_items_manager: Node2D
@export var world_dynamic_objects_manager: Node2D
@export var world_level_manager: Node2D
@export var oasis: Node2D
@export var wager_manager: WagerManager

@onready var the_lava: TheLava = $World/Lava
#@onready var lava_scene: PackedScene = preload("res://lava/lava.tscn")
@export var camera: Camera2D
@export var world_effects_container: Node2D

func _ready():
	camera.camera_centered_on_player.connect( ui.show_dead_player )
	# -- we're gaurenteed that all children (level manager and world pickup items
	# -- manager) are intialized
	# ==> can just set the prev. world pickup items ready stuff to here
	post_processing_quad.transition_finished.connect(
		func(): world_level_manager.call_deferred("start_level")
	)
	world_pickup_items_manager.load_pickup_items_from_level_chunks(
		world_level_manager.get_all_pickup_item_definitions()
	)
	world_dynamic_objects_manager.load_dynamic_objects_from_level_chunks(
		world_level_manager.get_all_dynamic_object_definitions()
	)
	assert( camera )
	
	world_level_manager.cam_ref = camera
	world_level_manager.level_ready.connect( on_level_manager_loaded_first_chunk )
	#post_processing_quad.transition_finished.connect( func():
		 #)
	
	oasis.portal_entered.connect( on_oasis_portal_entered )
	
	assert(spawn_points)
	assert(players_container)

	await get_tree().create_timer(0.1).timeout
	
	#print("Spawning Game with ", NetManager.player_data.size(), " players.")
	
	for id in NetManager.player_data:
		var d = NetManager.player_data[id]
		spawn_player(id, d[NetManager.KEY_NAME], d[NetManager.KEY_INDEX])
	
	NetManager.game_world = self
	wager_manager.set_player_data(player_data_dict)
	
	# ------------------------------------------------------- UI hookups
	ui.game_ref = self

	wager_window.set_player_data(player_data_dict)
	wager_window.set_wager_manager(wager_manager)

	Events.emit_signal("play_music", AudioDb.MusicTrackId.GAMEPLAY,-10,1)
	
	test_death_tv()
	#print( get_tree_string_pretty() )

var world_is_ticking := false
@onready var world_tickables : Array = [
	world_level_manager, 
	#lava, 
	world_pickup_items_manager, 
	post_processing_quad, 
	ui,
	$World/ProjectilesContainer,
	world_dynamic_objects_manager
]


var race_started := false

func execute_tick( delta: float ):
	#print(players_container.get_child(0).global_position)
	post_processing_quad.execute_tick( delta )
	#if race_started:
	if world_is_ticking:
		for tickable in world_tickables:
			tickable.execute_tick( delta )


func _on_player_info_received(peer_id: int, _name: String, spawn_index: int):
	spawn_player(peer_id, _name, spawn_index)
	

# -- we're just piping this ID from the NetManager
var id_2_spawn_index: Dictionary = {}
func spawn_player(peer_id: int, _name: String, spawn_index: int):
	# -- scene name is the peer id to keep things straight
	var a_players_name = str(peer_id)
	
	# -- no duplicates (don't spawn the same id twice)
	if players_container.has_node( a_players_name ):
		return
	
	# -- TODO Need to formalize player intialization into its own thing
	# -- there's too much going on here
	var a_player = player_scene.instantiate()
	a_player.name = a_players_name
	
	# -- ahhh so messy
	a_player.get_node_or_null("PlayerController").moving_platform_components_dict = world_level_manager.moving_platform_components_dict
	#a_player.get_node_or_null("PlayerController").dynamic_objects_manager_ref = $World/WorldDynamicObjectsManager
	#a_player.dynamic_objects_manager_ref = $World/WorldDynamicObjectsManager
	a_player.dynamic_objects_manager_ref = $World/WorldDynamicObjectsManager
	# -- assign multiplayer authority to the player before
	# -- it's added to scene tree
	# -- otherwise the controller logic breaks (remote vs local)
	NetManager.register_player_instance(peer_id, a_player)
	
	
	a_player.set_multiplayer_authority(peer_id)
	
	# --------------------------------------------- replace player color with UI
	var _col = rand_player_color( peer_id )
	a_player.color = _col
	
	# ------------------------------------------------ set up data struct for UI
	var a_player_data = PlayerData.new()
	a_player_data.id = peer_id
	a_player_data.display_name = _name
	a_player_data.turban_color = _col
	 
	a_player_data.skin_tone = rand_skin_tone( peer_id )
	player_data_dict[peer_id] = a_player_data
	
	# --------------------------------------------------- connect player signals
	a_player.touched_bottom.connect( on_player_touched_bottom )
	a_player.dropped_pickup_item.connect(
		world_pickup_items_manager.on_player_dropped_pickup_item
	)
	world_level_manager.setup_networked_level_player_connections(a_player)

	players_container.add_child(a_player)
	
	assert( a_player.dynamic_objects_manager_ref != null )
	# -- Adding after child is added to player container so that the local transformation
	# -- (the displacement of the original world)
	# -- doesn't add to the players position
	
	# -- Spawn index has to be deterministic
	# -- The Host must be the one to decide that
	var points_count = spawn_points.get_child_count()
	id_2_spawn_index[ peer_id ] = spawn_index
	var spawn_marker_pos = spawn_points.get_child(spawn_index % points_count).global_position
	a_player.global_position = spawn_marker_pos
	
	a_player.projectiles_container_ref = $World/ProjectilesContainer
	
	if peer_id == multiplayer.get_unique_id():
		camera.target_initialize(a_player)
		camera.global_position = a_player.global_position
		ui.player_ref = a_player
		a_player.died.connect(camera.on_player_died)
		
		print($World/ProjectilesContainer)
	# -- we need the players to spawn before running this
	world_effects_container.initialize_recurring_player_vfx()
	#print_tree_pretty()

func get_spawn_point_from_child_node(spawn_points_node: Node2D, peer_id: int) -> Vector2:
	var points_count = spawn_points_node.get_child_count()
	var actual_point = spawn_points_node.get_child(id_2_spawn_index[peer_id] % points_count)
	return actual_point.global_position


# ------------------------------------------------------------------------ Utils
func ordered_players_by_height() -> Array:
	"""
	Used in UI to decide relative heights of players
	sorts players by global_position.y and returns an array of their ids
	"""
	var ret = players_container.get_children()
	# -- sort_custom sorts in place
	ret.sort_custom( func(a: Player, b: Player):
		if abs(a.global_position.y - b.global_position.y) < 1:
			# -- using id as a tie-breaker to prevent jitter
			return int(a.name) < int(b.name) 
		return (a.global_position.y < b.global_position.y))
	return ret


@onready var rng = RandomNumberGenerator.new()

func rand_player_color( seed_val: int) -> Color:
	rng.seed = seed_val + 100
	var r = rng.randf()
	var g = rng.randf()
	var b = rng.randf()
	return Color(r, g, b)


func rand_skin_tone( seed_val: int) -> int:
	rng.seed = seed_val
	return rng.randi_range(0, 4)


# -- hardcoding until someone makes a level
@export var level_x_length = 10000
@export var level_y_length = 10000
@export var world_origin: Vector2 = Vector2.ZERO

func get_level_dimensions() -> Vector2:
	return Vector2(level_x_length, level_y_length)


var num_players_initialized = 0
func on_oasis_portal_entered( body, portal_pos: Vector2 ) -> void:
	if body is Player:
		num_players_initialized += 1
		body.entered_portal() # -- state and vfx stuff
	if num_players_initialized == players_container.get_children().size():
		# -- relative vector for origin of transition point; can change or w/e
		post_processing_quad.start_transition_anim(
			(portal_pos  - camera.global_position))
		#world_level_manager.call_deferred("start_level")


func on_level_manager_loaded_first_chunk( _spawn_points: Array ):
	var idx = 0 # -- python enumerate would be nice or lisp macro to do two arr at once
	for id in id_2_spawn_index:
		var _player = NetManager.player_instances_by_player_id[ id ]
		_player.global_position = _spawn_points[ idx]
		idx += 1
	post_processing_quad.start_transition_anim_back()
	world_is_ticking = true
	
	the_lava.global_position = Vector2(0., $World/LevelManager.get_level_bottom_y() - 600)
	print("bottom of volcano: ", $World/LevelManager.get_level_bottom_y())
	the_lava.start_lava(Vector2(level_x_length, level_y_length))
	
	ui.set_minimap_world2d( $World.get_world_2d() )


func on_player_touched_bottom( _player_id):
	#lava.global_position = Vector2(0., 0.)
	#lava.start_race()
	race_started = true
	ui.visible = true
	#camera.zoom = Vector2(1.2, 1.2)

func test_death_tv():
	$DeathTv.set_subviewports_game_world( $World.get_world_2d() )
	$DeathTv.target_player = players_container.get_children()[0]
