extends Node2D

# Parachute:
# Can used whenever, but should try for cases:
# 1) we're on the ground and we're in a windgust region
# 2) we're not on the ground (falling state) and we're in a windgust region

@export var item_interface: ItemInterface

var input_manager: InputManager
var player_ref: Player

var gust_strength: float
var is_gusting: bool = false
func _ready() -> void:
	# -- initially we're not trying to check this area
	set_physics_process( false )
	# initially not check
	$Sprite2D.visible = false
	#$Area2D/CollisionShape2D.disabled = true
	
	$TryTimer.timeout.connect( func():
		call_deferred("set_physics_process", false))
		
	
	$Area2D.area_exited.connect( func(area): 
		if area is WindGustLift:
			gust_strength = area.gust_strength
			gust_upward())
		
	#----------------------------------- item interface / dependency injection
	item_interface.can_use_fn = func(): return true # you can always try this
	item_interface.used.connect( try_parachute )
		#if target:
			#retract()
			#item_interface.finished_using_item = true
		#else:
			#item_interface.finished_using_item = false
			#launch())
	item_interface.stopped.connect( func(): pass )
	#item_interface.destroyed.connect( func(): call_deferred("queue_free"))


func _physics_process(delta: float) -> void:
	if is_gusting:
		player.velocity += 100.0


func try_parachute():
	# -- two cases:
	# 1) we're on the ground and we're in a windgust region
	# -- take over players kinematics and gust in the direction of the wind
	call_deferred("set_physics_process", true)
	
	# 2) we're falling as the player and want the 
	#$Area2D/CollisionShape2D.set_deferred("disabled", false)
	$TryTimer.start()


# ------------------------------------------------
#func turn_on_area( b: bool) -> void:
	#call_deferred("set_physics_process", b)
	#$Area2D/CollisionShape2D.set_deferred("disabled", !b)
