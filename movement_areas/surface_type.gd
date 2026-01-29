extends Resource
class_name SurfaceType

#@export var id: String = "default"

# -- Add a curve if
#acceleration depends on speed
#nonlinear braking
#easing


@export var accl_modifier: float = 1.0
@export var decl_modifier: float = 1. / 100.0
@export var max_speed_modifier: float = 1.0

# -- TODO some semantic labling for other stuff
#@export var slippery := false
#@export var damaging := false

#@export var sfx: AudioStream
#@export var particles: PackedScene
