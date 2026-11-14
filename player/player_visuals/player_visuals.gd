extends Node2D

signal death_animation_finished

static var last_death_type: Player.DeathTypes
# ------------------------------------------------------------------ member vars

var last_pos: Vector2
var is_stationary: bool = true
var last_dir_x: float = 1.
@export var player_animated_sprite: AnimatedSprite2D
var current_animation: StringName = &""
var current_state: Player.MovementStates = Player.MovementStates.IDLE
var is_moving: bool = false


# --
@onready var player_ref = get_parent()


@export var DEBUG := false:
	set(b):
		DEBUG = b
		if b:
			$DebugVisuals.visible = true
			$ProdVisuals.visible = false
		else:
			$ProdVisuals.visible = true
			$DebugVisuals.visible = false

# ---------------------------------------------------------------------- methods

func color_randomly_from_peer_name( _name: String):
	var my_seed = _name.hash()
	seed(my_seed)
	$DebugVisuals/DebugCharacterVisual.material.set_shader_parameter("src_col", Vector4( 0.3 * randf(), randf() * 0.5 + 0.1, randf() + 0.5, 1.))


func _ready() -> void:
	if !player_ref is Player:
		player_ref = null
	last_pos = global_position
	
	$"DarrenCharacterVisuals/Player Animations".animation_finished.connect( on_animation_finished )
	if DEBUG:
		var my_seed = get_parent.hash()
		seed(my_seed)
		$DebugVisuals.visible = true
		$ProdVisuals.visible = false
		$DebugVisuals/DebugCharacterVisual.material.set_shader_parameter("src_col", Vector4( 0.3 * randf(), randf() * 0.5 + 0.1, randf() + 0.5, 1.))
	else:
		get_parent().ready.connect( func():
			# -- we're connecting the parent's (player) on state_chagned signal
			get_parent().on_state_changed.connect( set_movement_state))
		
		#$ProdVisuals.visible = true
		$DebugVisuals.visible = false


func _physics_process(_delta: float) -> void:
	if !player_ref:
		return
	var _dir_x = player_ref.last_move_input.x
	if !is_zero_approx( _dir_x ) and last_dir_x != _dir_x:
		last_dir_x = _dir_x
		set_facing_direction( _dir_x )
	
	
	last_pos = global_position
	is_stationary = global_position.distance_squared_to(last_pos) < 1
	on_animation_movement_change( is_stationary )

# -- some stretch & squash on both
func on_jump():
	var tween := create_tween()
	tween.tween_property(
		$DebugVisuals/DebugCharacterVisual.material,
		"shader_parameter/progress",
		1.0,
		0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		$DebugVisuals/DebugCharacterVisual.material,
		"shader_parameter/progress",
		0.0,
		0.18
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# TODO
# we should be able to skip to the end when not emitting
# so that we're showing the same thing on the UI canvas layer as whatever
# is shown at the end of the death animation
func set_visual_from_death_type( death_type=null ):
	# -- the player died and we're setting this
	if death_type:
		assert( death_type is Player.DeathTypes)
		# -- the static var is set by the death
		last_death_type = death_type
		# -- UI uses this var, so just feeds it back here to recreate the visual
		#visible = false
		death_animation_finished.emit()
	
	# -- regardless, if UI or normal player visuals manager
	# -- play the associated death
	match last_death_type:
		Player.DeathTypes.SPIKED:
			pass








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
	if !(state == Player.MovementStates.WALL_SLIDING or 
		state == Player.MovementStates.LEDGE_GRABBING):
		set_facing_direction( last_dir_x)
	else:
		set_facing_direction( -last_dir_x)
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
			return &"Jumping"
			
		Player.MovementStates.FALLING:
			return &"Falling"
			
		Player.MovementStates.WALL_SLIDING:
			
			return &"Wall Slide"
		Player.MovementStates.CROUCHING:
			return &"Crouch Walk"
		Player.MovementStates.LEDGE_GRABBING:
			return &"Ledge Grab"	
		_:
			return &"Idle"


func set_facing_direction(horizontal_direction: float) -> void:
	if is_zero_approx(horizontal_direction):
		return
	
	#var ADHOC = (player_animated_sprite.animation == "Wall Slide" or
				#player_animated_sprite.animation == "Ledge Grab")
	
	player_animated_sprite.flip_h = horizontal_direction > 0.0


func play_animation(animation_name: StringName) -> void:
	if current_animation == animation_name:
		return

	current_animation = animation_name
	player_animated_sprite.play(animation_name)


func on_animation_movement_change(_is_stationary: bool):
	match player_animated_sprite.animation:
		"Crouch Idle":
			if !_is_stationary:
				player_animated_sprite.play("Crouch Walk")
		"Crouch Walk":
			if _is_stationary:
				player_animated_sprite.play("Crouch Idle")

func on_animation_finished():
	# -- we need to acocunt for transitioning to secondary or tertiary
	# -- animations following a state change animation
	match player_animated_sprite.animation:
		"Falling":
			player_animated_sprite.play("Falling Idle")
		_:
			return
