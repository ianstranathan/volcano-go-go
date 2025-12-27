extends Node2D

var item: Node2D

@export var input_manager: InputManager
@export var player_ref: Player

func _ready() -> void:
	assert( input_manager )


func pick_up(item_rsc: PackedScene, fn: Callable):
	# -> add item to manager
	# -> and turn on input polling
	item = item_rsc.instantiate()
	item.input_manager = input_manager
	item.player_ref = player_ref
	#item.used_up.connect( func():
		## -> turn off input polling
		#set_physics_process( false ))
	add_child(item)
	set_physics_process( true )
	fn.call() # -- whatever the pickup item needs to do to clean up


func _physics_process(_delta: float) -> void:
	if item and input_manager.pressed_action("use_item"):
		item.use()
