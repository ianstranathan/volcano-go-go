#get info from ItemManager and pass to hotbar_slot. redraws all slots every call. if standard item is null texture 
#remains null and that will tell the hotbar_slot.gd- set_slot_display to draw an empty slot. doing texture lookup here
#should i just pass it in?
extends Control
class_name HotbarUi

@onready var standard_slots = $HotBarWindow/StandardSlots.get_children()
@onready var special_slot: HotbarSlot = $HotBarWindow/SpecialSlot

var last_selected_index = -1
func _ready() -> void:
	Events.inventory_changed.connect( set_inventory_display )
	Events.item_used.connect( func( i: int):
		assert( standard_slots.size() > i )
		standard_slots[i].on_item_used())
	
	for slot in standard_slots:
		slot.cool_down_finished.connect( func():
			slot.set_selection_on_mat_callback( slot == standard_slots.get(last_selected_index)))


var special_item_cooldown: float = 1.;

func set_inventory_display(item_db_enums: Array, item_db_cooldowns: Array, selected_index: int, special_item) -> void:
	"""
	Needs an array of enums from ItemDb
	"""
	last_selected_index = selected_index
	# -- do standard items
	#var num_items = item_db_enums.size
	for i in range(standard_slots.size()):
		standard_slots[i].set_slot_display(
			ItemsDb.get_texture(item_db_enums[i]) if item_db_enums[i] != -1 else null,
			item_db_cooldowns[i],
			i == selected_index)
		#standard_slots[i].set_cool_down()
	# -- do special item
	if special_item != null:
		special_slot.set_slot_display(ItemsDb.get_texture(special_item),
									  special_item_cooldown,
									  false)
	
