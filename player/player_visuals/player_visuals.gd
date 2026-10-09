extends Node2D

signal death_animation_finished

static var last_death_type: Player.DeathTypes

# ------------------------------------------------------------------ member vars
@export var DEBUG := false:
	set(b):
		DEBUG = b
		if b:
			$DebugVisuals.visible = true
			$ProdVisuals.visible = false
		else:
			$ProdVisuals.visible = true
			$DebugVisuals.visible = false

@onready var animation_controller : PlayerAnimationController = $PlayerAnimationController

# ---------------------------------------------------------------------- methods

func color_randomly_from_peer_name( _name: String):
	var my_seed = _name.hash()
	seed(my_seed)
	$DebugVisuals/DebugCharacterVisual.material.set_shader_parameter("src_col", Vector4( 0.3 * randf(), randf() * 0.5 + 0.1, randf() + 0.5, 1.))


func _ready() -> void:
	if DEBUG:
		var my_seed = get_parent.hash()
		seed(my_seed)
		$DebugVisuals.visible = true
		$ProdVisuals.visible = false
		$DebugVisuals/DebugCharacterVisual.material.set_shader_parameter("src_col", Vector4( 0.3 * randf(), randf() * 0.5 + 0.1, randf() + 0.5, 1.))
	else:
		$ProdVisuals.visible = true
		$DebugVisuals.visible = false


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


# -- just pass on to animation_controller
func set_movement_state(new_state: Player.MovementStates) -> void:
	animation_controller.set_movement_state( new_state )


func set_facing_direction(horizontal_direction: float) -> void:
	$PlayerAnimationController.set_facing_direction( horizontal_direction )


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
