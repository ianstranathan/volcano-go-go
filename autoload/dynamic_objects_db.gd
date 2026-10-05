@tool
extends Node

# -----------------------------------------------------------------------------
enum DynamicObjectType { ROCK, LANTERN, SKULL, METABALL_TOTEM }


@export var profiles: Dictionary = {
	DynamicObjectType.ROCK:           preload("res://levels/dynamic_objects/data/rock/dynamic_rock.tres"),
	DynamicObjectType.LANTERN:        preload("res://levels/dynamic_objects/data/lantern/dynamic_lantern.tres"),
	DynamicObjectType.METABALL_TOTEM: preload("res://levels/dynamic_objects/data/metaball_totem/metaball_totem_profile.tres")
}


func get_profile(type: DynamicObjectType) -> DynamicObjectProfile:
	return profiles.get(type)
