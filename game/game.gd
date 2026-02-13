extends Node2D

#@export var player: CharacterBody2D
#@onready var player_initial_position = player.global_position

#@export var lava: Node2D
#@export var lava_bodies_manager: Node2D

"""
It's important for your mental model to be correct
In this networking model (i.e. Godot's multiplayer's API)
Authority is per node not per peer/ machine

So, a player assigned to a peer id:
	a_player.set_multiplayer_authority(id)
will only have authority from that peer

"""

@export var player_scene: PackedScene
@export var players_container: Node2D
@export var spawn_points: Node2D
func _ready():
	assert(spawn_points)
	assert(players_container)
	# -- general callback if someone joins
	#NetManager.player_info_updated.connect(_on_player_info_received)
	
	# -- on each machine
	# -- for every id in the NetManager's player_names
	#for peer_id in NetManager.player_names_by_player_id:
		#spawn_player(peer_id)
	for id in NetManager.player_data:
		var d = NetManager.player_data[id]
		spawn_player(id, d[NetManager.KEY_NAME], d[NetManager.KEY_INDEX])


func _on_player_info_received(peer_id: int, _name: String, spawn_index: int):
	spawn_player(peer_id, _name, spawn_index)


# -- we're just piping this ID from the NetManager
func spawn_player(peer_id: int, _name: String, spawn_index: int):
	# -- no duplicates (don't spawn the same id twice)
	var a_players_name = str(peer_id)
	if players_container.has_node( a_players_name ):
		return
	# -- 
	var a_player = player_scene.instantiate()
	a_player.name = a_players_name
	
	# -- Spawn index has to be deterministic
	# -- The Host must be the one to decide that
	var points_count = spawn_points.get_child_count()
	var actual_point = spawn_points.get_child(spawn_index % points_count)
	a_player.global_position = actual_point.global_position
	
	# -- assign multiplayer authority to the player before
	# -- it's added to scene tree
	# -- otherwise the controller logic breaks (remote vs local)
	NetManager.register_player_instance(peer_id, a_player)
	a_player.set_multiplayer_authority(peer_id)
	
	a_player.color = rand_player_color( peer_id )
	if peer_id == multiplayer.get_unique_id():
		$Camera.target_initialize(a_player)
	players_container.add_child(a_player)
	

var rng = RandomNumberGenerator.new()

func rand_player_color( seed_val: int) -> Color:
	rng.seed = seed_val
	var r = rng.randf()
	var g = rng.randf()
	var b = rng.randf()
	return Color(r, g, b)
