@tool
extends Node2D

@export var emit: bool = false
	#set(b):
		#emit = b
		#effect_start()

@onready var gpu_particle_children = get_children().filter( func(c): if c is GPUParticles2D: return c)

func effect_start() -> void:
	for c in gpu_particle_children:
		c.restart()

func _ready() -> void:
	assert( gpu_particle_children.size() > 0 )
	$VfxEffectComponent.start = func(_params): 
		show()
		effect_start()
		
	$VfxEffectComponent.end = func(): hide()
	
	hide()
