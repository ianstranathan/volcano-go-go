extends Node2D

var item: Node2D
signal item_started()
signal item_finished

@export var input_manager: InputManager
@export var player_ref: Player

func _ready() -> void:
	assert( input_manager )


func pick_up(_item_type: ItemGlobals.ItemType, item_rsc: PackedScene, fn: Callable):
	# -> add item to manager
	# -> and turn on input polling
	item = item_rsc.instantiate()
	# -------------------------------------------- initializing vars
	item.type = _item_type
	item.input_manager = input_manager
	item.player_ref = player_ref
	#item.used_up.connect( func():
		## -> turn off input polling
		#set_physics_process( false ))
	
	# -------------------------------------------- signals
	item.item_started.connect( func(type: ItemGlobals.ItemType):
		if type == ItemGlobals.ItemType.MOBILITY:
			emit_signal("item_started"))
	item.item_finished.connect( func(type: ItemGlobals.ItemType):
		if type == ItemGlobals.ItemType.MOBILITY:
			emit_signal("item_finished"))
	# --------------------------------------------
	add_child(item)
	set_physics_process( true )
	fn.call() # -- whatever the pickup item needs to do to clean up
