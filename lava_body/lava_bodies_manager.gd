extends Node2D


@export var lava_ref: Node2D

"""
Middleman for lava
Assigns lava ref to it's children at _ready & any subsequent child added
"""
func _ready() -> void:
	assert( lava_ref )
	# -- init lava ref on children
	get_children().map( func( child):
		if child is LavableBody:
			child.lava_ref = lava_ref)
	
	#get_children().map( func( child ):
		#if child is AnimatableBody2D:
			#child.lava_ref = lava_ref )
		
		#b.lava_ref = lava_ref)
		#-- TODO
		# -- I wrapped the original AnimatedBody2D into a Node2D
		# -- to use the dummy script to change it's color and coll extens
		# -- change this and change how you're accesing it here
		#child.get_node("AnimatedBody2D").lava_ref = lava_ref)
		#if child is LavableBody:
			#child.lava_ref = lava_ref)
	

#func add_body_to_lava( body: LavableBody):
	#body.lava_ref = lava_ref
	#add_child( body )
