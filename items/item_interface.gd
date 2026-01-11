extends Resource

class_name ItemInterface

signal used
signal stopped

@export var use_mode: ItemUseMode

enum ItemUseMode 
{
	INSTANT,  # -- e.g. immediately affects player, like health potion
	ITEM_SPAWNING, # -- ice block, obstruction block, rope ladder
	PLAYER_MOVING   # -- grappling hook
}

var can_use_fn: Callable
var finished_using_item: bool = false
# -- we require a can use, but we're letting the parent (rope, hookshot, potion)
# -- whatever, decide what that means
func can_use() -> bool:
	assert(can_use_fn.is_valid(), "ItemInterface.can_use_fn was never assigned")
	return can_use_fn.call()


func use():
	emit_signal("used")


func stop():
	emit_signal("stopped")
