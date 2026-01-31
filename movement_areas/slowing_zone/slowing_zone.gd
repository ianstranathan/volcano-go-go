@tool
extends Node2D

var _psuedo_scale: float = 1.0
var baseline_rad := 64.0

@onready var area := $Area2D
@onready var collision := $Area2D/CollisionShape2D
@onready var sprite := $Sprite2D

@export var psuedo_scale: float:
	set(value):
		_psuedo_scale = max(1.0, value)
		if is_inside_tree():
			update_sprite_and_coll_radius()
	get:
		return _psuedo_scale


func _ready() -> void:
	update_sprite_and_coll_radius()

	area.body_entered.connect(func(body):
		if body is Player:
			body.slow(true)
	)
	area.body_exited.connect(func(body):
		if body is Player:
			body.slow(false)
	)


func update_sprite_and_coll_radius():
	if collision.shape:
		collision.shape.radius = baseline_rad * psuedo_scale
	sprite.scale = Vector2.ONE * psuedo_scale
