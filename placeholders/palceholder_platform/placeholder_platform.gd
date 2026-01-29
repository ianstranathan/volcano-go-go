@tool
extends Node2D

@export var sync_component: SpriteCollisionSync

# Exported property in parent with setter/getter forwarding
@export var coll_extents: Vector2:
	set(value):
		if sync_component:
			sync_component.coll_extents = value  # forward to child
	get:
		return sync_component.coll_extents if sync_component else Vector2(50, 50)

@export var color: Color:
	set(value):
		if sync_component:
			sync_component.color = value
	get:
		return sync_component.color if sync_component else Color(1,1,1,1)
