extends Node

class_name MyMathUtils

static func smoothstep_easing(t: float) -> float:
	return 3.0 * t * t - 2.0 * t * t * t

static func ease_in_out_quart( x: float):
	return (8 * x * x * x * x if x < 0.5 else 1 - pow(-2 * x + 2, 4) / 2)
	
## -- if you're curious, this is the slab method
# -- Slab Method, Kay and Kajiya
# -- https://ianstranathan.github.io/html/Demos/ray-box-intersection/

## Checks intersection between a ray and an aabb
static func intersect_line_bounds(ray_origin: Vector2, 
								  ray_dir: Vector2, 
								  box_pos: Vector2, 
								  box_size: Vector2) -> bool:
	var inv_dir = Vector2(1.0 / ray_dir.x, 1.0 / ray_dir.y)
	
	# Calculate the bounds manually (min and max corners)
	var box_min = box_pos
	var box_max = box_pos + box_size

	var t1 = (box_min.x - ray_origin.x) * inv_dir.x
	var t2 = (box_max.x - ray_origin.x) * inv_dir.x
	var t3 = (box_min.y - ray_origin.y) * inv_dir.y
	var t4 = (box_max.y - ray_origin.y) * inv_dir.y

	var t_min = max(min(t1, t2), min(t3, t4))
	var t_max = min(max(t1, t2), max(t3, t4))

	return t_max >= max(0.0, t_min)


## Returns distance to hit, or INF if no hit
static func get_line_bounds_distance(ray_origin: Vector2, 
									 ray_dir: Vector2, 
									 box_pos: Vector2, 
									 box_size: Vector2) -> float:
	# Pre-calculate reciprocals
	var inv_dir_x = 1.0 / ray_dir.x
	var inv_dir_y = 1.0 / ray_dir.y
	
	# Calculate half-extents
	var half_size = box_size * 0.5
	
	# Define the min and max corners relative to the center
	var b_min = box_pos - half_size
	var b_max = box_pos + half_size

	# X-axis slab
	var t1 = (b_min.x - ray_origin.x) * inv_dir_x
	var t2 = (b_max.x - ray_origin.x) * inv_dir_x
	
	# Y-axis slab
	var t3 = (b_min.y - ray_origin.y) * inv_dir_y
	var t4 = (b_max.y - ray_origin.y) * inv_dir_y

	# Standard Slab Method logic
	var t_min = max(min(t1, t2), min(t3, t4))
	var t_max = min(max(t1, t2), max(t3, t4))

	# Check for valid intersection
	if t_max >= max(0.0, t_min):
		return t_min
	
	return INF


## Checks if a point is inside a 2D capsule
## [param point]: The 2D point you want to test
## [param capsule_position]: The center position of the capsule
## [param capsule_height]: The total height of the capsule (tip-to-tip)
## [param capsule_radius]: The radius of the capsule caps
## [param capsule_rotation]: The rotation of the capsule in radians (default is vertical)
static func is_point_in_capsule(point: Vector2,
						 capsule_position: Vector2,
						 capsule_height: float,
						 capsule_radius: float,
						 capsule_rotation: float = 0.0) -> bool:
	# 1. Transform the point into the capsule's local coordinate space
	# This handles capsule position and rotation automatically
	var local_point := (point - capsule_position).rotated(-capsule_rotation)
	
	# 2. Calculate the length of the inner line segment (spine)
	# Godot's CapsuleShape2D clamps the segment length to 0 if height < radius * 2
	var segment_length :float = max(0.0, capsule_height - (capsule_radius * 2.0))
	var half_segment : float = segment_length / 2.0
	
	# 3. Find the closest point on the vertical spine segment to our local_point
	# By default, Godot 2D capsules are aligned vertically (along the Y axis)
	var closest_point := Vector2(
		0.0, 
		clamp(local_point.y, -half_segment, half_segment)
	)
	
	# 4. Check if the distance to the closest point is within the radius
	var distance_squared := local_point.distance_squared_to(closest_point)
	return distance_squared <= (capsule_radius * capsule_radius)

## Checks if a circle overlaps a 2D capsule
## [param circle_center]: The global or local center point of the circle
## [param circle_radius]: The radius of the circle
## [param capsule_position]: The center position of the capsule
## [param capsule_height]: The total height of the capsule (tip-to-tip)
## [param capsule_radius]: The radius of the capsule caps
## [param capsule_rotation]: The rotation of the capsule in radians (default is vertical)
static func is_circle_overlapping_capsule(
	circle_center: Vector2, 
	circle_radius: float, 
	capsule_position: Vector2, 
	capsule_height: float, 
	capsule_radius: float, 
	capsule_rotation: float = 0.0
) -> bool:
	# 1. Transform the circle's center point into the capsule's local coordinate space
	var local_circle_center := (circle_center - capsule_position).rotated(-capsule_rotation)
	
	# 2. Calculate the length of the inner line segment (spine)
	var segment_length :float= max(0.0, capsule_height - (capsule_radius * 2.0))
	var half_segment :float= segment_length / 2.0
	
	# 3. Find the closest point on the vertical spine segment to the local circle center
	var closest_point := Vector2(
		0.0, 
		clamp(local_circle_center.y, -half_segment, half_segment)
	)
	
	# 4. Calculate the combined radiuses
	var combined_radius := capsule_radius + circle_radius
	
	# 5. Check if the distance to the closest point is less than the combined radius
	var distance_squared := local_circle_center.distance_squared_to(closest_point)
	return distance_squared <= (combined_radius * combined_radius)

# ------------------------------------------------------------------------------
## Easing curves
static func inverted_parabola(t: float):
	assert(t <= 1 and t >= 0)
	return -pow((2 * t - 1.), 2.) + 1

func bounce(t: float) -> float:
	return 1.0 - abs(sin(t * PI * 2.5)) * (1.0 - t)

func linear(t: float) -> float:
	return clamp(t, 0.0, 1.0)
	
static func heavy_impact_curve(t: float) -> float:
	return sin(t * PI / 2.0) # Smooth start, aggressive finish
