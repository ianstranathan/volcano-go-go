extends Node2D

class_name ItemManager

var item_interface: ItemInterface
var items_container

signal item_moving_started()
signal item_moving_stopped()
signal item_targeted_something( pos_or_null )
signal item_ray_target_position_changed( pos: Vector2 )


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
	if item_interface:
		item_interface.destroy()
	
	var item = item_rsc.instantiate()
	item_interface = item.item_interface
	if is_moving_item() or is_spawning_item():
		# NOTE
		var components = item.get_children().filter( func(c): 
			return c is RayCastItemComponent)
		var raycast_component = components[0] if components.size() > 0 else null
		if raycast_component:
			raycast_component.intersected_something.connect( func(pos_or_null):
				emit_signal("item_targeted_something", pos_or_null))
			raycast_component.target_position_changed.connect( func(pos: Vector2):
				emit_signal("item_ray_target_position_changed", pos))


		if is_moving_item():
			item.input_manager = input_manager
			item.player_ref = player_ref
		elif items_container:
			item.items_container_ref = items_container
		add_child(item)
	# -- this is a callback from the pickup item handle to clean up after itself
	fn.call()


func stop_using_item() -> void:
	item_interface.stop()

# ------------------------------------------ small utils
func is_spawning_item() -> bool:
	return item_interface.use_mode == item_interface.ItemUseMode.ITEM_SPAWNING

func is_moving_item() -> bool:
	return item_interface.use_mode == item_interface.ItemUseMode.PLAYER_MOVING
