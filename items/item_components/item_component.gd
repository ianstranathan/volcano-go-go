extends Resource
class_name ItemComponent

@export var use_mode: ItemUseMode

enum ItemUseMode 
{
	INSTANT, # -- e.g. immediately affects player, like health potion
	SPAWNED, # -- ice block, obstruction block, rope ladder
	EQUIPED  # -- grappling hook
}
