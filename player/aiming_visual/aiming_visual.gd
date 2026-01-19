extends Node2D

# -- TODO There's no need to have the targetVisual as a separate scene

@export var targeted_visual: Sprite2D
@export var input_manager: InputManager
"""
This is just a "dumb" aiming visual, it's just a visual callback to the
item targeting something
e.g. grappling hook has a successful ray intersection check
it emits a signal with that intersection position
it percolates up and ends up connecting to update_aiming_visual
(player connects aiming visual to input manager on _ready() )

Timer:
	everytime there's input from the player's controller (specifically aiming)
	aiming visual toggle visibility and hide timer is started
"""

func _ready() -> void:
	assert(targeted_visual)
	$Timer.timeout.connect( func():
		set_physics_process(false)
		hide())

# -- the direction lines indicating aim
func update_aiming_visual( ):
	# -- this is a callback to the input manager detecting 
	# -- mouse input or controller R-stick input
	set_physics_process(true)
	show()
	$Timer.start()

func _physics_process(_delta: float) -> void:
	var p : Vector2
	if targeted_visual.visible:
		p = targeted_visual.global_position
	else:
		p = input_manager.aiming_pos()
	$Line2D.set_point_position(1, to_local( p ))

# -- the reticle / target pos
# -- indicating that you can do something
func update_target_pos(pos_or_null):
	if pos_or_null:
		targeted_visual.visible = true
		targeted_visual.global_position = pos_or_null
	else:
		targeted_visual.visible = false
