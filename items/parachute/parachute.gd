extends Node2D


@export var item_interface: ItemInterface

var input_manager: InputManager
var player_ref: Player

func _ready() -> void:
	
	$Area2D.area_exited.connect( func(area): 
		if area is WindGustLift:
			)
	#----------------------------------- item interface / dependency injection
	item_interface.can_use_fn = func(): return true # you can always use this
	item_interface.used.connect( try_parachute )
		#if target:
			#retract()
			#item_interface.finished_using_item = true
		#else:
			#item_interface.finished_using_item = false
			#launch())
	item_interface.stopped.connect( func(): pass )
	#item_interface.destroyed.connect( func(): call_deferred("queue_free"))

func try_parachute():
	
	pass
