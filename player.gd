extends CharacterBody2D

# -- TODO
# -- account for terminal velocity
# -- (should only be able to fall so fast)
# -- [X] Side somersault
# -- [X] Wall Slide
# -- Wall Bonk
# -- Head Bonk

@export_group("Kinematics")
@export var move_speed: float = 200
@export var ACCL = 20
@export var DECL = 30
@export var jump_height: float = 200;
@export var jump_distance_to_peak: float = 120
@export var fall_distance_from_peak: float = 100
@export var somersault_factor = 1.25 ## as a ratio of the jump velocity

@onready var time_to_peak = jump_distance_to_peak / move_speed
@onready var time_to_ground = fall_distance_from_peak / move_speed

@onready var jump_gravity = 2 * jump_height / (time_to_peak * time_to_peak);
@onready var fall_gravity = 2 * jump_height / (time_to_ground * time_to_ground);
@onready var wall_slide_gravity =fall_gravity / 1000.0
@onready var jump_speed = -2 * jump_height / time_to_peak;


@export_group("platformer stuff")
## Time to allow jump after leaving ground
@export var COYOTE_TIME_DURATION: float = 0.15
# Time to hold jump input for later jump
@export var JUMP_BUFFER_DURATION: float = 0.15

@onready var coyote_timer: Timer = $CoyoteTimeTimer
@onready var jump_buffer_timer: Timer = $JumpBufferTimer

@onready var new_y_vel: float = velocity.y

var is_on_ground := true # -- our "truth" about being on the ground (e.g. slightly off ledge)
var can_jump := true
@onready var g: float = jump_gravity

func _ready() -> void:
	coyote_timer.wait_time = COYOTE_TIME_DURATION
	jump_buffer_timer.wait_time = JUMP_BUFFER_DURATION

	coyote_timer.timeout.connect( func():
		is_on_ground = false)

	$WallJumpTimer.timeout.connect( func():
		# -- turn on all the wall raycasts after a certain amount time after wall jump
		$WallCheckContainer.get_children().map( 
			func(child): child.enabled = true))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_buffer_timer.start()
	if (event.is_action_released("jump") and 
		movement_state == MovementStates.JUMPING):
		velocity.y *= 0.5


# -- TODO
# -- refactor this to not think about why it's happening, just what needs to happen
enum JumpTypes
{
	REGULAR,
	SOMERSAULT_FLIP,
	WALL
}
func handle_jump():
	# -- logic of when to to jump
	if !jump_buffer_timer.is_stopped():
		if is_on_ground:
			is_on_ground = false
			if !$SideSomersaultTimer.is_stopped():
				do_jump(JumpTypes.SOMERSAULT_FLIP)
			else:
				do_jump(JumpTypes.REGULAR)
		else:
			do_jump(JumpTypes.WALL)


func do_jump(jump_type):
	# -- logic of what to jump
	match jump_type:
		JumpTypes.REGULAR:
			velocity.y = jump_speed
		JumpTypes.SOMERSAULT_FLIP:
			velocity.y = jump_speed * somersault_factor
			var tween = create_tween()
			tween.tween_property(self, "global_rotation", global_rotation + sign(last_move_input) * TAU, time_to_peak)
		JumpTypes.WALL:
			var _wall_normal = wall_normal()
			if _wall_normal:
				velocity = jump_speed * (-_wall_normal  + Vector2.DOWN).normalized()
			#print( direction_of_wall() )
			#velocity = Vector2(-direction_of_wall().x, -1.) * 0.5 * jump_speed

	movement_state_transition(MovementStates.JUMPING)


func handle_falling():
	if is_falling():
		#print( is_falling())
		# -- are we wall sliding?
		# -- => is last input and the wall normal direction aligned
		if is_wall_sliding():
			movement_state_transition(MovementStates.WALL_SLIDING)
		else:
			movement_state_transition(MovementStates.FALLING)
			coyote_timer.start()

func _physics_process(delta: float) -> void:
	move();
	handle_jump()
	handle_falling()

	#var g = fall_gravity if velocity.y >= 0  else jump_gravity

	# -----------------------------------------------------------  kinematic update
	global_position += (velocity * delta) + Vector2(0., (0.5 * delta * delta * g))
	velocity.y += g * delta

	var coll = move_and_collide(Vector2.ZERO)
	if coll:
		var normal = coll.get_normal()
		# -- logic for transitioning to ground, idle
		if normal.y < 0:
			movement_state_transition(MovementStates.IDLE)
			is_on_ground = true
			velocity.y = 0


var last_move_input: float
func move():
	var move_input := Input.get_axis("move_left", "move_right")
	if !last_move_input:
		last_move_input = move_input
	var there_is_input: bool = !is_zero_approx(move_input)
	velocity.x = move_toward(velocity.x, 
							move_input * move_speed,
							ACCL if there_is_input else DECL)
	if is_on_ground:
		# -- side somersault:
		# -- two -tive nums multiplied together is a positive
		# -- two +tive nums multiplied together is a positive
		# -- two differnt signed nums multiplied together is a negative
		if there_is_input:
			var switched_dir = true if last_move_input * move_input < 0 else false
			if switched_dir:
				$SideSomersaultTimer.start()
			movement_state_transition(MovementStates.WALKING)
		else:
			movement_state_transition(MovementStates.IDLE)
	
	last_move_input = move_input


func my_is_on_floor() -> bool:
	# -- is any downward pointing ray colliding with something?
	# -- is_on_floor only works with move_and_slide
	return $FloorCheckContainer.get_children().reduce(func(accum, child):
		return (accum or child.is_colliding()), false)


func is_falling():
	return velocity.y >= 0 and not my_is_on_floor()


func is_wall_sliding() -> bool:
	# -- is the wall ray pointed in the opposite direction as the wall normal
	var _wall_normal = wall_normal()
	if _wall_normal:
		return last_move_input * _wall_normal.x < 0
	return false


func wall_normal():
	# -- return the first raycast collision normal
	# -- TODO
	# -- this will fail if there collisions on both side of player
	for ray in $WallCheckContainer.get_children():
		if ray.is_colliding():
			return ray.get_collision_normal()


enum MovementStates
{
	IDLE,
	WALKING,
	JUMPING,
	FALLING,
	CROUCHING,
	WALL_SLIDING,
}
const MOVEMENT_STATE_PRIORIOTY_ARR = [ 
	MovementStates.IDLE,
	MovementStates.WALKING,
	MovementStates.JUMPING,
	MovementStates.FALLING,
	MovementStates.CROUCHING,
	MovementStates.WALL_SLIDING
]

var movement_state: MovementStates = MovementStates.IDLE
var prev_movement_state: MovementStates = movement_state

# -- TODO wrap this up into a more functional, modular thing to inject states into matches
func movement_state_transition(new_movement_state: MovementStates):
	#print("Curr: ", movement_state, " & next: ", new_movement_state)
	if movement_state != new_movement_state:
		match movement_state:
			MovementStates.IDLE:
				# -- exit code here
				match new_movement_state:
					# -- enter code here
					MovementStates.WALKING:
						#print("from idle to walking")
						$Label.text = "WALKING"
					MovementStates.JUMPING:
						#print("from idle to jumping")
						g = jump_gravity
						$Label.text = "JUMPING"
					MovementStates.FALLING:
						#print("from idle to falling")
						g = fall_gravity
						$Label.text = "FALLING"
			MovementStates.WALKING:
				match new_movement_state:
					MovementStates.IDLE:
						$Label.text = "IDLE"
					MovementStates.JUMPING:
						g = jump_gravity
						$Label.text = "JUMPING"
					MovementStates.FALLING:
						g = fall_gravity
						$Label.text = "FALLING"
			MovementStates.JUMPING:
				match new_movement_state:
					MovementStates.FALLING:
						g = fall_gravity
						$Label.text = "FALLING"
					MovementStates.WALL_SLIDING:
						g = _wall_slide_gravity()
						$Label.text = "WALL SLIDING"
			MovementStates.FALLING:
				match new_movement_state:
					MovementStates.IDLE:
						$Label.text = "IDLE"
					MovementStates.WALL_SLIDING:
						g = _wall_slide_gravity()
						$Label.text = "WALL_SLIDING"
			MovementStates.CROUCHING:
				pass
			MovementStates.WALL_SLIDING:
				match new_movement_state:
					MovementStates.IDLE:
						$Label.text = "IDLE"
					MovementStates.JUMPING:
						g = jump_gravity
					MovementStates.FALLING:
						g = fall_gravity
						#$WallJumpTimer.start()
						#$WallCheckContainer.get_children().map( 
							#func(child): child.enabled = false)
						$Label.text = "JUMPING"
		# ----------------------------------
		prev_movement_state = movement_state
		movement_state = new_movement_state
		# ----------------------------------

# -- the wall slide gravity is too low when velocity is near 0
# -- but it feels about right for faster downward velocitys
func _wall_slide_gravity() -> float:
	## -- t: normalization var based on velocity value
	## -- b: the maximum magnitude of the downward velocity
	## --    (I just printed out some jumps from the physics loop at picked the highest ~1800
	## -- a: always zero
	var b = 1800.0
	# -- normalizing on range: t = b - x / b - a
	# -- simplifies to t = b - x / b
	# -- need to guarentee velocity is not above this
	var v_y = clamp(abs(velocity.y), 0., b)
	var t = (b - v_y) / b
	
	# -- linear interpolation of the wall gravity value
	# -- TODO should play around with different interpolation curves base
	# -- on game feel at some later point
	var A = 0.5 * wall_slide_gravity
	var wall_slide_gravvity_at_zero_vel = 20 * wall_slide_gravity
	var B = wall_slide_gravvity_at_zero_vel
	var _t = t * t
	var ret = (1. - _t) * A + _t * B
	#print("ret: ", ret, "at t: ", t)
	return ret
