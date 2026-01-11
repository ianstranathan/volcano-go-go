extends Node2D

var item_interface: ItemInterface
signal item_moving_started()
signal item_moving_stopped()

@export var input_manager: InputManager # -- local source of input truth
@export var player_ref: Player

func _ready() -> void:
	assert( input_manager and player_ref)

func _physics_process(_delta: float) -> void:
	if !item_interface:
		return
	else:
		if input_manager.just_pressed_action("use_item") and item_interface.can_use():
			item_interface.use()
			if is_moving_item():
				if item_interface.finished_using_item:
					emit_signal("item_moving_stopped")
				else:
					emit_signal("item_moving_started")
		

func pick_up( item_rsc: PackedScene,  fn: Callable):
	var item = item_rsc.instantiate()
	item_interface = item.item_interface
	if is_moving_item():
		item.player_ref = player_ref
		item.input_manager = input_manager
		add_child(item)
		
	fn.call()
	

func stop_using_item() -> void:
	item_interface.stop()


func is_moving_item() -> bool:
	return item_interface.use_mode == item_interface.ItemUseMode.PLAYER_MOVING
#func pick_up(_item_type: ItemGlobals.ItemType, item_rsc: PackedScene, fn: Callable):
	#item = item_rsc.instantiate()
	## -------------------------------------------- initializing vars
	#item.type = _item_type
	#item.input_manager = input_manager
	#item.player_ref = player_ref
	## -------------------------------------------- signals
	#item.item_started.connect( func(type: ItemGlobals.ItemType):
		#if type == ItemGlobals.ItemType.MOBILITY:
			#emit_signal("item_started"))
	#item.item_finished.connect( func(type: ItemGlobals.ItemType, can_use_again: bool):
		#if type == ItemGlobals.ItemType.MOBILITY:
			#emit_signal("item_finished")
		#if not can_use_again:
			#item.queue_free()
		#)
	## --------------------------------------------
	#call_deferred("add_child", item)
	##add_child(item)
	#call_deferred("set_physics_process", true)
	##set_physics_process( true )
	#fn.call() # -- whatever the pickup item needs to do to clean up


#func handle_item_pickup(_item_type: ItemGlobals.ItemType, item_rsc: PackedScene):
	#match _item_type:
		#ItemGlobals.ItemType.MOBILITY:
			#pass
		#ItemGlobals.ItemType.CREATION:
			#pass
		

# -- control needs to flow both ways
# -- if the player runs into a situation where he should abruptly stop using
# -- the equipped item, it needs to stop
# -- => we need an interface of some kind
