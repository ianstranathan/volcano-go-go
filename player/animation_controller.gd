class_name PlayerAnimationController
extends Node

@export var player_animated_sprite: AnimatedSprite2D

var current_animation: StringName = &""
var current_state: Player.MovementStates = Player.MovementStates.IDLE


func set_movement_state(new_state: Player.MovementStates) -> void:
	current_state = new_state

	var next_animation := animation_for_state(new_state)
	play_animation(next_animation)

#enum MovementStates
#{
	#IDLE,
	#WALKING,
	#RUNNING,
	#JUMPING,
	#FALLING,
	#CROUCHING,
	#WALL_SLIDING,
	#LEDGE_GRABBING,
	#ITEM_MOVING,
	#CLIMBING,
	#CLOUD,
	#PORTAL,
	#SLIDING,
	#METABALL,
	#LOG_ROLL,
	#GRABBED,
	#DEAD,
	#RESPAWNED
	## GENIE_HAND
#}
func animation_for_state(state: Player.MovementStates) -> StringName:
	
	match state:
		Player.MovementStates.IDLE:
			return &"Idle"
			#return &"idle"

		Player.MovementStates.WALKING:
			return &"Jogging"
		
		Player.MovementStates.RUNNING:
			return &"Sprinting"

		Player.MovementStates.JUMPING, \
		Player.MovementStates.ITEM_MOVING:
			return &"jump"
			
		Player.MovementStates.FALLING:
			return &"falling"
			
		Player.MovementStates.WALL_SLIDING:
			return &"wall_sliding"
			
		Player.MovementStates.LEDGE_GRABBING:
			return &"ledge_grabbing"	
		_:
			return &"idle"

func set_facing_direction(horizontal_direction: float) -> void:
	if is_zero_approx(horizontal_direction):
		return

	player_animated_sprite.flip_h = horizontal_direction < 0.0

var is_moving: bool = false
var last_pos: Vector2 = Vector2.ZERO

#func _physics_process(delta: float) -> void:
	#(last_pos - global_position).x
func play_animation(animation_name: StringName) -> void:
	if current_animation == animation_name:
		return

	current_animation = animation_name
	player_animated_sprite.play(animation_name)
