extends Resource

class_name ItemInterface

signal item_depleted
signal stopped
signal destroyed

#@export var use_mode: ItemUseMode
#
#
#enum ItemUseMode 
#{
	#INSTANT,       # -- e.g. immediately affects player, like health potion
	#ITEM_SPAWNING, # -- ice block, obstruction block, rope ladder
	#PLAYER_MOVING  # -- grappling hook
#}

var tick_update_fn: Callable
var finished_using_item: bool = false # did the thing being interfaced with stop?
var timer = TickTimer.new(1.0)

# -- we're asserting that every item has a tick_update
# -- (i.e. deterministic _physics_process) but what that looks like
# -- depends on the item
func tick_update(delta_tick: float, command: PlayerCommand) -> void:
	if tick_update_fn.is_valid():
		tick_update_fn.call(delta_tick, command)


func on_used():
	timer.start()


func not_on_cool_down() -> bool:
	return timer.is_stopped()


func stop():
	stopped.emit()


func destroy():
	destroyed.emit()


func depleted():
	item_depleted.emit()
