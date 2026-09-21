@tool
extends Node


enum ItemNames{
	GRAPPLING_HOOK,
	HOOKSHOT,
	JETPACK,
	PARACHUTE,
	SWAP_GUN,
	#ROPE,
	#ROPE_LADDER
}


var items = {
	ItemNames.GRAPPLING_HOOK: preload("res://items/grappling_hook/grappling_hook.tscn"),
	ItemNames.HOOKSHOT:       preload("res://items/hookshot/hookshot.tscn"),
	ItemNames.JETPACK:        preload("res://items/jet_pack/jet_pack.tscn"),
	ItemNames.PARACHUTE:      preload("res://items/parachute/parachute.tscn"),
	ItemNames.SWAP_GUN:       preload("res://items/swap_gun/swap_gun.tscn")
	#ItemNames.ROPE:           preload("res://items/rope_ladder/rope_ladder_spawner.tscn"),
	#ItemNames.ROPE_LADDER:    preload("res://items/rope_ladder/rope_ladder.tscn")
}

var item_base_cooldowns = {
	ItemNames.GRAPPLING_HOOK: 1.5,
	ItemNames.HOOKSHOT: 3.0,
	ItemNames.JETPACK: 0.0,
	ItemNames.PARACHUTE: 5.0,
	ItemNames.SWAP_GUN: 3.0
}

var item_pickup_textures = {
	ItemNames.GRAPPLING_HOOK: preload("res://assets/grappling_hook.svg"),
	ItemNames.HOOKSHOT:       preload("res://assets/hookshot.svg"),
	ItemNames.JETPACK:        preload("res://assets/jetpack.svg"),
	ItemNames.PARACHUTE:      preload("res://assets/parachute.svg"),
	ItemNames.SWAP_GUN:       preload("res://assets/body-swapping.svg")
	#ItemNames.ROPE:           preload("res://assets/rope-coil.svg"),
}


func get_texture(item_key: ItemNames) -> Texture2D:
	#print("in get_tex: ", item_key)
	assert(item_key in items)
	return item_pickup_textures[ item_key ]


func get_item_from_lookup( item_key: ItemNames ) -> PackedScene:
	assert(item_key in items)
	return items[item_key]
