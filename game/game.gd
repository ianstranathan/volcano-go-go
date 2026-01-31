extends Node2D

@onready var players: Node = $Players
@onready var spawn_points: Node = $SpawnPoints

const PLAYER_SCENE := preload("res://player/player.tscn")

var local_player: CharacterBody2D
var local_player_spawn_position: Vector2

func _ready() -> void:
	players.child_entered_tree.connect(_on_players_child_entered)

	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

		_spawn_player_for_peer(1) # host
		for id in multiplayer.get_peers():
			_spawn_player_for_peer(id)

func _on_peer_connected(peer_id: int) -> void:
	_spawn_player_for_peer(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	var p := players.get_node_or_null(str(peer_id))
	if p:
		p.queue_free()

func _spawn_player_for_peer(peer_id: int) -> void:
	# Prevent duplicate spawn if reconnect / scene reload
	if players.get_node_or_null(str(peer_id)):
		return

	var p: CharacterBody2D = PLAYER_SCENE.instantiate()
	p.name = str(peer_id)

	var spawn_index := peer_id % spawn_points.get_child_count()
	p.position = spawn_points.get_child(spawn_index).position

	players.add_child(p) 

func _on_players_child_entered(n: Node) -> void:
	var p := n as CharacterBody2D
	if p == null:
		return

	# Follow the locally-authoritative player on each machine
	if p.is_multiplayer_authority():
		local_player = p
		local_player_spawn_position = p.global_position
		$Camera.target = p
