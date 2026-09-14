@tool
extends Node2D

# -- NOTE
# -- I'm inheriting parents material on the side chains
# -- that's why they're coupled
@export var top_anchor: Marker2D:
	set(m):
		top_anchor = m
		set_line_index_2_relative_dist(1, m)


@export var bottom_anchor: Marker2D:
	set(m):
		bottom_anchor = m
		set_line_index_2_relative_dist(0, m)


@onready var line_2ds = $Node2D.get_children() + [$Line2D]
func set_line_index_2_relative_dist( i: int, m: Marker2D) -> void:
	if is_node_ready():
		var dist = m.global_position.y - $BasePlatform.global_position.y
		for c in line_2ds:
			assert( c is Line2D)
			# -- make the y at index 0 the relative distance to the marker
			c.set_point_position(i, Vector2(0., dist))
		
		# -- now set the path curve points
		var _c = $BasePlatform/PathFollowPlatformComponent.curve
		_c.clear_points()
		_c.add_point(line_2ds[0].points[0])
		_c.add_point(line_2ds[0].points[1])
		

func execute_tick( delta: float ) -> void:
	$BasePlatform/MovingPlatformComponent.execute_tick( delta )
