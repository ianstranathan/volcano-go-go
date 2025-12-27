extends Item

@export var grapple_max_distance: float = 800
@export var rest_length = 200.0
@export var stiffness = 15.0
@export var damping = 1.0

@onready var ray := $RayCast2D
@onready var rope := $Line2D


var launched = false
var target: Vector2


func _ready() -> void:
	$RayCast2D.target_position = Vector2(grapple_max_distance, 0.0)


func _physics_process(delta: float) -> void:
	ray.look_at(input_manager.aiming_pos())
	
	#if input_manager.pressed_action("use_item") and !launched:
		#launch()
	#if input_manager.pressed_action("use_item") and lau:
		#retract()
	if Input.is_action_just_pressed("use_item"):
		launch()
	if Input.is_action_just_released("use_item"):
		retract()
	if launched:
		handle_grapple(delta)


func launch():
	if ray.is_colliding():
		launched = true
		target = ray.get_collision_point()
		rope.set_point_position(1, to_local(target))
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
	#update_rope()

#func update_rope():
	#rope.set_point_position(1, to_local(target))
