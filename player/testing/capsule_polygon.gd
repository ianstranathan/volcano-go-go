extends Polygon2D

@export var collision_shape: CollisionShape2D
@export var num_points: int = 16 # More points for a smoother curve

func _ready() -> void:
	var capsule_shape_ref: CapsuleShape2D = collision_shape.get_shape()
	polygon = generate_capsule_polygon(capsule_shape_ref.radius,
									   capsule_shape_ref.height)

#func sdSegment( p: Vector2, a: Vector2, b: Vector2 ):
	#var pa = p - a
	#var ba = b - a
	#var h = clamp( pa.dot(ba)/ba.dot(ba), 0.0, 1.0 )
	#return (pa - ba*h).length()


func generate_capsule_polygon(radius: float, height: float) -> PackedVector2Array:
	var points: PackedVector2Array = []
	# -- what is a capsule? 
	# -- 1)
	# -- it's just a circle that has been divided an put ontop
	# -- of a rectangle
	
	# -- 2)
	# -- the set of all points a radius length away from a line segment
	
	# -- let's go with 1
	var theta = 0
	var theta_step = TAU / num_points
	var half_height = height / 2.0
	# -- top half
	for i in range(num_points):
		var offset = half_height if i <= num_points / 2 else -half_height	
		var circle_pt = radius * Vector2( cos(theta), sin(theta))
		points.append( circle_pt + Vector2(0., offset))
		print( offset )
		theta += theta_step
	
	return points
