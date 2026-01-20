extends Node2D

# -- TODO There's no need to have the targetVisual as a separate scene

@export var targeted_visual: Sprite2D
@export var item_manager: ItemManager

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
	# -- (we want the aiming to hide after a certain amount of time)
	set_physics_process(true)
	show()
	$Timer.start()

# -- this is a callback from the item manager
var target_position_for_line: Vector2 = Vector2.ZERO
func update_dir(pos: Vector2):
	target_position_for_line = pos


# -- NOTE
# -- the aiming visual is connected via player (intermediary signal bus)
# -- the item tells it which way it's looking
func _physics_process(_delta: float) -> void:
	var p = (targeted_visual.global_position if targeted_visual.visible
			 else target_position_for_line)
	$Line2D.set_point_position(1, to_local( p ))


# -- the reticle / target pos
# -- indicating that you can do something
func update_target_pos(pos_or_null):
	if pos_or_null:
		targeted_visual.visible = true
		$Line2D.material.set_shader_parameter("hit_modulation", 1.0)
		targeted_visual.global_position = pos_or_null
	else:
		$Line2D.material.set_shader_parameter("hit_modulation", 0.0)
		targeted_visual.visible = false
