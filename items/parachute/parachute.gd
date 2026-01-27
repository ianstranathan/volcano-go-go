extends Node2D

# Parachute:
# Can used whenever, but cases:
# 1) in a windgust region -> actively blows player upward
# 2) falling / parachuting -> slows player descent

@export var item_interface: ItemInterface
@export var accl_curve: Curve
var input_manager: InputManager
var player_ref: Player

enum ParachuteTypes {
	NONE,
	GUSTING,
	PARACHUTING
}
var parachute_type: ParachuteTypes = ParachuteTypes.NONE
var gust_area: WindGustLift
var offset: Vector2
func _ready() -> void:
	# ------------------------------------------- offset calculation
	# -- half the sprite size, use my utils
	var sprite_offset_contribution = Vector2(0., (($Sprite2D.texture.get_size() * $Sprite2D.scale) / 2.0).y)
	assert( player_ref )
	# -- half the players capsule size
	var to_top_of_player = Vector2(0., player_ref.get_node("CollisionShape2D").shape.height / 2.0)
	offset = sprite_offset_contribution + to_top_of_player
	
	# ------------------------------------------ player touched_ground
	#player_ref.touched_ground.connect( func():
		#if parachute_type != ParachuteTypes.NONE:
			#stop())
	
	#----------------------------------- item interface / dependency injection
	item_interface.can_use_fn = func(): return true # you can always try this
	item_interface.used.connect( func():
		if parachute_type != ParachuteTypes.NONE:
			stop()
		else:
			try_parachute()
	)
	item_interface.stopped.connect( stop )
	item_interface.destroyed.connect( func(): call_deferred("queue_free"))
	
	#-------------------------------------- initialize
	turn_off_coll_and_sprite( true )
	
	# ------------------------------------- signals
	$TryTimer.timeout.connect( func():
		# if the area2d hasn't overlapped with something, turn stuff off
		if parachute_type == ParachuteTypes.NONE:
			turn_off_coll_and_sprite( true ))
	$Area2D.area_entered.connect( func(area):
		if !$Area2D/CollisionShape2D.disabled and area is WindGustLift:
			gust_area = area
			start( ParachuteTypes.GUSTING ))
	$Area2D.area_exited.connect( func(area): 
		if area is WindGustLift:
			player_ref.velocity.y *= 0.25
			parachute_type = ParachuteTypes.PARACHUTING)


func turn_off_coll_and_sprite(b: bool, try_just_coll: bool = false):
	if try_just_coll:
		$Area2D/CollisionShape2D.set_deferred("disabled", b)
	else: # default
		$Area2D/CollisionShape2D.set_deferred("disabled", b)
		$Sprite2D.visible = !b


func stop():
	print("STOPPED")
	parachute_type = ParachuteTypes.NONE
	turn_off_coll_and_sprite(true)
	$MovementOverrideComponent.finish()
	$TryTimer.stop()


func start(_type: ParachuteTypes):
	$DeploymentTimer.start()           # to sample accl, gust curves
	player_ref.velocity.y = 0.         # 
	parachute_type = _type             #
	$MovementOverrideComponent.start() # 
	$Sprite2D.visible = true           #
	$TryTimer.stop()                   # stop to prevent timeout callback
	turn_off_coll_and_sprite( false )  # 


func _physics_process(delta: float) -> void:
	#print(ParachuteTypes.find_key(parachute_type))
	match parachute_type:
		ParachuteTypes.NONE:
			return
		ParachuteTypes.GUSTING:
			player_ref.velocity.y -= 1.2 * player_ref.get_g() * delta
			#var t = curve_sample_t() if !$DeploymentTimer.is_stopped() else 1.0
			#player_ref.velocity.y = move_toward(player_ref.velocity.y, 
												#10. * gust_area.get_wind_strength( t ),
												#10. * accl_curve.sample(t))
		ParachuteTypes.PARACHUTING:
			player_ref.velocity.y -= 0.98 * player_ref.get_g() * delta
			if player_ref.my_is_on_floor():
				stop()
	print(player_ref.velocity.y)
	global_position = player_ref.global_position - offset


func try_parachute():
	# if player is falling, change to parachuting
	if player_ref.can_parachute():
		start( ParachuteTypes.PARACHUTING )
	else:
		turn_off_coll_and_sprite( false, true ) # -- allow area2d to change state
		$TryTimer.start() # if the area2d doesn't change state after X time
						  # stop needlessly checking


func curve_sample_t(reversed=false):
	var t  = ($DeploymentTimer.wait_time - $DeploymentTimer.time_left) / $DeploymentTimer.wait_time
	if reversed:
		t = (1. - t)
	return t
