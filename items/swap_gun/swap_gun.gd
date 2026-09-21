extends Node2D

"""
Multiplayer authority is decided by item manager at spawn
"""

@export var item_interface: ItemInterface
var player_ref: Player
var cool_down: float
var projectiles_container_ref
@onready var projectile_component = $ProjectileItemComponent
@onready var swap_projectile_scene: PackedScene = preload("res://items/swap_gun/swap_projectile.tscn")

func _ready() -> void:
	assert( item_interface )
	#----------------------------------- item interface / dependency injection
	item_interface.tick_update_fn = tick_update
	#item_interface.stopped.connect(on_item_stopped)
	item_interface.destroyed.connect( func():
		call_deferred("queue_free"))
	
	#if is_multiplayer_authority() or multiplayer.is_server():
		#$ProjectileItemComponent
	

# -- NOTE
@rpc("any_peer", "reliable")
func shoot_on_interpolated_players(_dir):
	if !(multiplayer.is_server() or is_multiplayer_authority()):
		shoot_swap_projectile( _dir )


func tick_update(_delta: float, cmd: PlayerCommand):
	projectile_component.tick_update(cmd)
	if cmd.item_use_pressed and cmd.aiming_input.length_squared() > 0.05:
		var _dir = (cmd.aiming_input - player_ref.global_position).normalized()
		shoot_swap_projectile( _dir )
		shoot_on_interpolated_players.rpc( _dir )


@rpc("any_peer", "reliable")
func shoot_swap_projectile(_dir: Vector2):
	var swap_projectile = swap_projectile_scene.instantiate( )
	swap_projectile.origin_player_ref = player_ref
	# -- TODO
	# -- so, all development is happening with a mouse
	# -- but this needs to be aware of mouse or gamepad
	# -- not great, but whatever
	# -- From local_player_controller:
	# func aiming_pos() -> Vector2:
	#     return (aiming_vector() + global_position)
	
	swap_projectile.dir = _dir
	#print(cmd.aiming_input)
	projectiles_container_ref.add_swap_projectile( swap_projectile )

# -- should probably repalce this with a general world reference and just get
# -- whatever here
# -- otehrwise we're gonna need to percolate everytime
# -- world :: player:: item_manager:: item
func set_projectiles_container_ref(p: Node2D) -> void:
	projectiles_container_ref = p

func set_player_ref(p: Player) -> void:
	player_ref = p
	#print("setting player ref: ", player_ref.name)
