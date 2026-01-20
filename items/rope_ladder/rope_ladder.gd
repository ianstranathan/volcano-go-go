extends Node2D

var target: Vector2
var rope_length: float
# -- do a little shader animation

# -- up
# -- down



func _ready() -> void:
	assert( target ) # -- has to have a target from spawner

	$Line2D.set_point_position(1, to_local(target))
	print("Target global:", target)
	print("Rope global pos:", global_position)
	print("Line global pos:", $Line2D.global_position)
	print("Line local:", $Line2D.to_local(target))
	#var tween = create_tween()
	#tween.tween_property( self, "global_position", target, rope_anim_length)
	#tween.tween_callback( func():
		#var next_tween = create_tween()
		#next_tween.tween_property( self, "global_position", target, rope_anim_length)
		#)
