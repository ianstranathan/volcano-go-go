extends Node2D

# Parachute:
# Can used whenever, but cases:
# 1) in a windgust region -> actively blows player upward
# 2) falling / parachuting -> slows player descent

@export var item_interface: ItemInterface
@export var accl_curve: Curve
#var input_manager: LocalPlayerController
var player_ref: Player
var cool_down

enum ParachuteTypes {
	NONE,
	GUSTING,
	PARACHUTING
}
var parachute_type: ParachuteTypes = ParachuteTypes.NONE
var offset: Vector2

var try_timer: TickTimer    = TickTimer.new(0.1)
var deploy_timer: TickTimer = TickTimer.new(1.5)

func _ready() -> void:
	# -- we're limiting the collision masks to exclude everything that isn't a
	# -- a wind area and something that can pop this

	# ------------------------------------------------------- offset calculation
	# -- half the sprite size, use my utils
	var sprite_offset_contribution = Vector2(0., (($Sprite2D.texture.get_size() * $Sprite2D.scale) / 2.0).y)
	
	# -- half the players capsule size
	var to_top_of_player = Vector2(0., player_ref.get_node("CollisionShape2D").shape.height / 2.0)
	offset = sprite_offset_contribution + to_top_of_player
	
	position = -offset
	
	#------------------------------------- item interface / dependency injection
	#item_interface.can_use_fn = func(): return true # you can always try this
	item_interface.tick_update_fn = tick_update
	item_interface.stopped.connect( stop )
	#item_interface.destroyed.connect( _sync_destruction)
	
	#-------------------------------------- initialize
	turn_off_coll_and_sprite( true )
	
	# ------------------------------------- signals
	try_timer.timeout.connect( func():
		# if the area2d hasn't overlapped with something, turn stuff off
		if parachute_type == ParachuteTypes.NONE:
			turn_off_coll_and_sprite( true ))
	$Area2D.area_entered.connect( func(area):
		if !$Area2D/CollisionShape2D.disabled and area is WindGustLift:
			start( ParachuteTypes.GUSTING ))
	$Area2D.area_exited.connect( func(area): 
		if (area is WindGustLift and 
			parachute_type == ParachuteTypes.GUSTING and 
			!$Area2D/CollisionShape2D.disabled):
			player_ref.velocity.y *= 0.1
			parachute_type = ParachuteTypes.PARACHUTING)


func turn_off_coll_and_sprite(b: bool, try_just_coll: bool = false):
	if try_just_coll:
		$Area2D/CollisionShape2D.set_deferred("disabled", b)
	else: # default
		$Area2D/CollisionShape2D.set_deferred("disabled", b)
		$Sprite2D.visible = !b


func stop():
	#print("STOPPED")
	parachute_type = ParachuteTypes.NONE
	
	#if is_multiplayer_authority():
	show_parachute_on_interpolated_remote.rpc(false, offset)
	
	turn_off_coll_and_sprite(true)
	$MovementOverrideComponent.finish()
	try_timer.stop()
	
	if is_multiplayer_authority():
		Events.emit_signal("stop_world_loop", _get_loop_key())
		
		#Events.emit_signal(
			#"play_world_sound",
			#AudioDb.WorldSoundId.PARACHUTE_OPEN,#using open for closed for now
			#global_position,
			#{}
		#)

func start(_type: ParachuteTypes):
	gust_interpolant = 0.0
	$DeploymentTimer.start()           # to sample accl, gust curves
	parachute_type = _type             #
	$MovementOverrideComponent.start() # 
	$Sprite2D.visible = true           #
	player_ref.velocity = Vector2.ZERO
	#if is_multiplayer_authority():
	show_parachute_on_interpolated_remote.rpc(true, offset)
	
	try_timer.stop()                   # stop to prevent timeout callback
	turn_off_coll_and_sprite( false ) 
	 # 
	if is_multiplayer_authority and not player_ref.is_replaying:
		Events.emit_signal("play_world_sound",
							AudioDb.WorldSoundId.PARACHUTE_OPEN,
							global_position,0,1,
							{}
							)
		
		Events.emit_signal(
			"start_world_loop",
			_get_loop_key(),
			AudioDb.WorldLoopId.PARACHUTE_DESCEND,
			self,2,1,
			{}
		)
var gust_interpolant = 0.0

func tick_update(delta: float, cmd: PlayerCommand):
	if cmd.item_use_pressed:
		if parachute_type != ParachuteTypes.NONE:
			stop()
		else:
			try_parachute()
	match parachute_type:
		ParachuteTypes.NONE:
			return
		ParachuteTypes.GUSTING:
			
			if gust_interpolant <= 1.0:
				gust_interpolant += delta
				player_ref.velocity.y -= 4000 * delta * accl_curve.sample(gust_interpolant)
				gust_interpolant = clamp(gust_interpolant, 0., 1.)
			pass
		ParachuteTypes.PARACHUTING:
			player_ref.velocity.y -= 0.97 * player_ref.get_g() * delta
			


func try_parachute():
	# if player is falling, change to parachuting
	if player_ref.can_parachute():
		start( ParachuteTypes.PARACHUTING )
	else:
		turn_off_coll_and_sprite( false, true ) # -- allow area2d to change state
		try_timer.start() # if the area2d doesn't change state after X time
						  # stop needlessly checking


func set_player_ref(p: Player) -> void:
	player_ref = p


@rpc("any_peer", "reliable")
func show_parachute_on_interpolated_remote(b: bool, _offset: Vector2):
	# -- we only wanna turn this stuff off on the dummies
	#if !is_multiplayer_authority():
	if !offset:
		# -- initialize the offset if it doesn't exist on interpolated remote
		offset = _offset
		position = -offset
	$Sprite2D.visible = b


func _get_loop_key() -> StringName:
	return StringName("parachute_%s" % player_ref.get_multiplayer_authority())
#@rpc("authority", "call_local", "reliable")
#func _sync_destruction():
	#call_deferred("queue_free")
