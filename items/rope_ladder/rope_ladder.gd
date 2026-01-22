extends Node2D

var target: Vector2
var rope_length: float
# -- do a little shader animation

# -- up
# -- down



func _ready() -> void:
	assert( target ) # -- must have a target from spawner
	$Line2D.set_point_position(1, to_local(target))
	
	# -- line2d is in local space
	var line_height = $Line2D.get_point_position(1).y
	#$Area2D/CollisionShape2D.shape.size = Vector2(2.0 * $Line2D.width, line_height)
	var shape : RectangleShape2D = $Area2D/CollisionShape2D.shape.duplicate()
	$Area2D/CollisionShape2D.shape = shape
	$Area2D/CollisionShape2D.shape.size = Vector2(1.3 * $Line2D.width, floor(abs(line_height)))
	$Area2D/CollisionShape2D.position.y = line_height / 2.
	
	# -- this feels ugly
	$Area2D.body_entered.connect( func(body):
		if body is Player:
			body.can_climb = true)
	$Area2D.body_exited.connect( func(body):
		if body is Player:
			body.can_climb = false)
