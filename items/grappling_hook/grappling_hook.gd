extends Item

@export var swing_power: float = 100 # -- coefficient for swinging manually
@export var reel_in_speed: float = 50
@export var grapple_change_rate := 200.0
@export var swing_damping := 1.0
@export var grapple_max_distance: float = 800
@export var grapple_min_distance: float = 50
@onready var rest_length = grapple_min_distance
@onready var ray := $RayCast2D
@onready var rope := $Line2D

var launched = false
var target: Vector2

func _ready() -> void:
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
	#print("launching")
	if ray.is_colliding():
		launched = true
		target = ray.get_collision_point()
		rope.show()


func retract():
	launched = false
	rope.hide()

func handle_grapple(delta):
	var to_anchor = target - player_ref.global_position
	var current_dist = to_anchor.length()
	var target_dir = to_anchor.normalized()
	
	rest_length = max(rest_length - reel_in_speed * delta, 20.0)
	if current_dist > rest_length:
		var outward_vel = player_ref.velocity.dot(target_dir)
		if outward_vel < 0:
			player_ref.velocity -= target_dir * outward_vel
		var overshoot = current_dist - rest_length
		var responsiveness = 0.25
		player_ref.velocity += target_dir * (overshoot * responsiveness)
		
		# -- make player velocity tangent to swing
		player_ref.velocity = player_ref.velocity.project(player_ref.velocity.normalized())
		
	player_ref.velocity *= (1.0 - (swing_damping * delta)) # -- Damping / Friction
	rope.set_point_position(1, to_local(target))
