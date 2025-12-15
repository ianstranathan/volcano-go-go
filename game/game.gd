extends Node2D

@export var player: CharacterBody2D
@onready var player_initial_position = player.global_position

@export var lava_view: Sprite2D

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		player.velocity = Vector2.ZERO
		player.global_rotation = 0
		player.global_position = player_initial_position
