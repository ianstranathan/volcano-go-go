extends CharacterBody2D

# -- TODO
# -- 

@export_group("Kinematics")
@export var move_speed: float = 200
@export var ACCL = 20
@export var DECL = 30
@export var jump_height: float = 200;
@export var jump_distance_to_peak: float = 120
@export var fall_distance_from_peak: float = 100

@onready var time_to_peak = jump_distance_to_peak / move_speed
@onready var time_to_ground = fall_distance_from_peak / move_speed

@onready var jump_gravity = 2 * jump_height / (time_to_peak * time_to_peak);
@onready var fall_gravity = 2 * jump_height / (time_to_ground * time_to_ground);
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

func _ready() -> void:
	coyote_timer.wait_time = COYOTE_TIME_DURATION
	jump_buffer_timer.wait_time = JUMP_BUFFER_DURATION

	coyote_timer.timeout.connect( func():
		is_on_ground = false)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_buffer_timer.start()
	if (event.is_action_released("jump") and 
		movement_state == MovementStates.JUMPING):
		velocity.y *= 0.5


func handle_jump():
	if is_on_ground and !jump_buffer_timer.is_stopped():
		is_on_ground = false
		velocity.y = jump_speed
		movement_state_transition(MovementStates.JUMPING)


func _physics_process(delta: float) -> void:
	move();
	handle_jump()
	
	if is_falling(): # -- coyote time check
		movement_state_transition(MovementStates.FALLING)
		coyote_timer.start()
	
	var g = fall_gravity if velocity.y >= 0  else jump_gravity
	global_position += (velocity * delta) + Vector2(0., (0.5 * delta * delta * g))
	velocity.y += g * delta

	#move_and_slide(Vector2.ZERO)
	var coll = move_and_collide(Vector2.ZERO)
	if coll:
		var normal = coll.get_normal()
		# -- FIXME
		# -- this breaks on slopes
		if normal.y < 0:
			if is_falling():
				movement_state_transition(MovementStates.IDLE)
			is_on_ground = true
			velocity.y = 0


func move():
	var move_input := Input.get_axis("move_left", "move_right")
	
	var there_is_input: bool = !is_zero_approx(move_input)
	velocity.x = move_toward(velocity.x, 
							move_input * move_speed,
							ACCL if there_is_input else DECL)
	if is_on_ground:
		if there_is_input:
			movement_state_transition(MovementStates.WALKING)
		else:
			movement_state_transition(MovementStates.IDLE)


## this is a utility function to allow for the pill shape
func my_is_on_floor() -> bool:
	# -- is any ray colliding with something?
	return $FloorCheckContainer.get_children().reduce(func(accum, child):
		return (accum or child.is_colliding()), false)


func is_falling():
	return velocity.y >= 0 and not my_is_on_floor()


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
	if movement_state != new_movement_state:
		match movement_state:
			MovementStates.IDLE:
				match new_movement_state:
					MovementStates.WALKING:
						$Label.text = "WALKING"
					MovementStates.JUMPING:
						$Label.text = "JUMPING"
					MovementStates.FALLING:
						$Label.text = "FALLING"
			MovementStates.WALKING:
				match new_movement_state:
					MovementStates.IDLE:
						$Label.text = "IDLE"
					MovementStates.JUMPING:
						$Label.text = "JUMPING"
					MovementStates.FALLING:
						$Label.text = "FALLING"
			MovementStates.JUMPING:
				match new_movement_state:
					MovementStates.FALLING:
						$Label.text = "FALLING"
			MovementStates.FALLING:
				match new_movement_state:
					MovementStates.IDLE:
						$Label.text = "IDLE"
					#MovementStates.WALKING:
						#$Label.text = "IDLE"
			MovementStates.CROUCHING:
				pass
			MovementStates.WALL_SLIDING:
				pass
		# ----------------------------------
		prev_movement_state = movement_state
		movement_state = new_movement_state
		# ----------------------------------
	
