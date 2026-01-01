extends Node2D

@export var player: CharacterBody2D
@onready var player_initial_position = player.global_position

@export var lava: Node2D
@export var lava_bodies_manager: Node2D
func _ready() -> void:
	pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		player.velocity = Vector2.ZERO
		player.global_rotation = 0
		player.global_position = player_initial_position
