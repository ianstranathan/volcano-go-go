extends Item

@export var grapple_max_distance: float = 800
@export var grapple_min_distance: float = 2.0
@export var grapple_change_rate := 100.0
@onready var rest_length = grapple_min_distance
@export var stiffness = 15.0
@export var damping = 5.0

@onready var ray := $RayCast2D
@onready var rope := $Line2D


var launched = false
var target: Vector2


func _ready() -> void:
	print(player_ref)
	$RayCast2D.target_position = Vector2(grapple_max_distance, 0.0)


func _physics_process(delta: float) -> void:
	ray.look_at(input_manager.aiming_pos())
	if launched:
		handle_grapple(delta)
	if Input.is_action_just_pressed("use_item"):
		use()
	if Input.is_action_just_released("use_item"):
		finish_using()
	
	# -- inverting these to match intuion
	var move_input := Input.get_axis("move_up", "move_down")
	rest_length += delta * move_input * grapple_change_rate
	rest_length = clamp(rest_length, grapple_min_distance, grapple_max_distance)


func use():
	super()
	launch()

func finish_using():
	super()
	retract()

func launch():
	print("launching")
	if ray.is_colliding():
		launched = true
		target = ray.get_collision_point()
		#rope.set_point_position(1, to_local(target))
		rope.show()


func retract():
	launched = false
	rope.hide()


func handle_grapple(delta):
	var target_dir = player_ref.global_position.direction_to(target)
	var target_dist = player_ref.global_position.distance_to(target)
	var displacement = target_dist - rest_length
	var force = Vector2.ZERO
	if displacement > 0:
		var spring_force_magnitude = stiffness * displacement
		var spring_force = target_dir * spring_force_magnitude
		
		var vel_dot = player_ref.velocity.dot(target_dir)
		var _damping = -damping * vel_dot * target_dir
		force = spring_force + _damping
	player_ref.velocity += force * delta
	update_rope()


func update_rope():
	rope.set_point_position(1, to_local(target))
