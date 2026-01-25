extends Node2D

# Parachute:
# Can used whenever, but should try for cases:
# 1) we're on the ground and we're in a windgust region
# 2) we're not on the ground (falling state) and we're in a windgust region

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
	# -- half the sprite size, see my utils
	var sprite_offset_contribution = Vector2(0., (($Sprite2D.texture.get_size() * $Sprite2D.scale) / 2.0).y)
	assert( player_ref )
	# -- half the players capsule size
	var to_top_of_player = Vector2(0., player_ref.get_node("CollisionShape2D").shape.height / 2.0)
	offset = sprite_offset_contribution + to_top_of_player
	player_ref.touched_ground.connect( func():
		parachute_type = ParachuteTypes.NONE
		stop())
	
	#----------------------------------- item interface / dependency injection
	item_interface.can_use_fn = func(): return true # you can always try this
	item_interface.used.connect( try_parachute )
	item_interface.stopped.connect( stop )
	item_interface.destroyed.connect( func(): call_deferred("queue_free"))
	

	set_physics_process( false )
	$Area2D/CollisionShape2D.disabled = true
	$Sprite2D.visible = false	
	
	$TryTimer.timeout.connect( func():
		if parachute_type == ParachuteTypes.NONE:
			call_deferred("set_physics_process", false))
	$Area2D.area_entered.connect( func(area):
		if !$Area2D/CollisionShape2D.disabled and area is WindGustLift:
			gust_area = area
			start( ParachuteTypes.GUSTING ))
	$Area2D.area_exited.connect( func(area): 
		if area is WindGustLift:
			parachute_type = ParachuteTypes.PARACHUTING)


func stop():
	$MovementOverrideComponent.finish()
	$Sprite2D.visible = false
	$TryTimer.stop()
	$Area2D/CollisionShape2D.set_deferred("disabled", true)
	call_deferred("set_physics_process", false)


func start(_type: ParachuteTypes):
	$DeploymentTimer.start()
	player_ref.velocity.y = 0.
	parachute_type = _type
	$MovementOverrideComponent.start()
	$Sprite2D.visible = true
	$TryTimer.stop()
	call_deferred("set_physics_process", true)


func _physics_process(delta: float) -> void:
	print(ParachuteTypes.find_key(parachute_type))
	match parachute_type:
		ParachuteTypes.GUSTING:
			player_ref.velocity.y -= 5000 * delta
			#var t = curve_sample_t() if !$DeploymentTimer.is_stopped() else 1.0
			#player_ref.velocity.y = move_toward(player_ref.velocity.y, 
												#10. * gust_area.get_wind_strength( t ),
												#10. * accl_curve.sample(t))
		ParachuteTypes.PARACHUTING:
			player_ref.velocity.y = 5000.0 * delta
	#var offset = $Area2D.global_position + Vector2(0., $Area2D/CollisionShape2D.shape.radius)
	global_position = player_ref.global_position - offset
	#print(player_ref.velocity.y)

func try_parachute():
	$Area2D/CollisionShape2D.set_deferred("disabled", false)
	call_deferred("set_physics_process", true)
	$TryTimer.start()


func curve_sample_t(reversed=false):
	var t  = ($DeploymentTimer.wait_time - $DeploymentTimer.time_left) / $DeploymentTimer.wait_time
	if reversed:
		t = (1. - t)
	return t
