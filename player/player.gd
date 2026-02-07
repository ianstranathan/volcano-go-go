extends CharacterBody2D

class_name Player


@export_group("Kinematics")
@export var baseline_speed: float = 250.0
@onready var move_speed: float = baseline_speed

@export var ACCL := 50.0
@onready var MOV_ACCL := ACCL
@export var DECL := 40.0
@export var TERMINAL_FALL_SPEED = 1400

@export var jump_height: float = 200;
@export var jump_distance_to_peak: float = 120
@export var fall_distance_from_peak: float = 100
## is a coeeficient of the jump velocity, so jump speed * this
@export var somersault_factor = 1.2

# -- NOTE: these are all kinematically decided, i.e. functions
# -------- of jump_height, jump_distance_to_peak, baseline_speed
@onready var time_to_peak = jump_distance_to_peak / baseline_speed
@onready var time_to_ground = fall_distance_from_peak / baseline_speed

@onready var jump_gravity = 2 * jump_height / (time_to_peak * time_to_peak);
@onready var fall_gravity = 2 * jump_height / (time_to_ground * time_to_ground);
@onready var wall_slide_gravity = fall_gravity / 100.0

@onready var jump_speed = -2 * jump_height / time_to_peak;
@export var climb_speed = baseline_speed * 0.7

@export var ledge_climb_duration := 0.6
var ledge_grab_climb_target_pos
var ledge_grab_start_pos
var is_ledge_climbing := false
var ledge_climb_tween: Tween
var ledge_climb_progress := 0.0

@onready var g: float = jump_gravity

# -------------------------------------------------- Movement Modifiers
var move_speed_modifier = 1.0
var jump_speed_modifier = 1.0
var gravity_modifier = 1.0
var hang_time_modifier = 1.0
## curve sample for jumping and falling state
## makes gravity less near peak of jump, see falling or jump state fn
@export var hang_time_curve: Curve

# -------------------------------------------------- Utils var for platforming
var current_platform = null # -- for calculating relative velocities
var last_move_input: Vector2
var last_wall_normal: Vector2 = Vector2.ZERO

# -------------------------------------------------- Buffer Timers
# -- wait times are set in inspector
@onready var coyote_timer: Timer = $BufferTimersContainer/CoyoteTimeTimer
@onready var jump_buffer_timer: Timer = $BufferTimersContainer/JumpBufferTimer
@onready var wall_jump_coyote_timer: Timer = $BufferTimersContainer/WallJumpCoyoteTimeTimer
@onready var ledge_grab_buffer_timer: Timer = $BufferTimersContainer/LedgeGrabBufferTimer
@onready var disable_horizontal_movement_timer: Timer = $BufferTimersContainer/LedgeGrabBufferTimer

# -- misc
var can_climb := false
var is_on_ground := true # -- our "truth" about being on the ground (e.g. slightly off ledge)

#@export var lava_ref: Node2D

enum MovementStates
{
	IDLE,
	WALKING,
	JUMPING,
	FALLING,
	CROUCHING,
	WALL_SLIDING,
	LEDGE_GRABBING,
	ITEM_MOVING,
	CLIMBING
}
@export var movement_state: MovementStates = MovementStates.IDLE

@export_category("Scene Heirarchy Stuff")

## the dedicated container in the same scene depth as the player that holds item instances
@export var items_container: Node2D

@export_category("NETWORKING DEBUG")
@export var NETWORK_DEBUG: bool

func _ready() -> void:
	$ClimbingInterface.climbing_area_entered.connect( func(): can_climb = true )
	$ClimbingInterface.climbing_area_exited.connect( func(): can_climb = false)
	#--------------------------------------------- grabbable component
	#signal got_tossed( dir: Vector2)
	#signal got_grabbed( n: Node2D)
	#--------------------------------------------- grab manager
	if !NETWORK_DEBUG:
		assert(items_container)
		
		$ItemManager.items_container = items_container
		#--------------------------------------------- this controls aiming line
		$InputManager.aim_input_detected.connect( func():
			$AimingVisual.update_aiming_visual())
		#--------------------------------------------- this controls aiming target
		$ItemManager.item_targeted_something.connect( func(pos_or_null):
			$AimingVisual.update_target_pos( pos_or_null))
		$ItemManager.item_ray_target_position_changed.connect( func(pos: Vector2):
			$AimingVisual.update_dir( pos ))
		$ItemManager.targeting_item_removed.connect( func():
			$AimingVisual.stop_aiming( ))
		$ItemManager.targeting_item_added.connect( func():
			$AimingVisual.start_aiming( ))
			
		$ItemManager.item_moving_started.connect( func():
			movement_state_transition_to( MovementStates.ITEM_MOVING))
		$ItemManager.item_moving_stopped.connect( func():
			coyote_timer.start())
	else:
		$ItemManager.set_physics_process(false)
		$ItemManager.set_process(false)
		$ItemManager.hide()
	

	coyote_timer.timeout.connect( coyote_time_resolution)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_buffer_timer.start()
	# -- this is for short jumps
	if (event.is_action_released("jump") and 
		movement_state == MovementStates.JUMPING):
		velocity.y *= 0.4
		movement_state_transition_to(MovementStates.FALLING)


enum JumpTypes
{
	REGULAR,
	SOMERSAULT_FLIP,
	WALL
}

func check_for_jump() -> void:
	if !jump_buffer_timer.is_stopped():
		if is_on_ground:
			is_on_ground = false
			if !$SideSomersaultTimer.is_stopped():
				do_jump(JumpTypes.SOMERSAULT_FLIP)
			else:
				do_jump(JumpTypes.REGULAR)
		elif can_wall_jump():
			disable_horizontal_movement_timer.start()
			wall_jump_coyote_timer.stop()
			do_jump(JumpTypes.WALL)
		elif is_ledge_grabbing():
			do_jump(JumpTypes.REGULAR)
		# NOTE change this man
		elif movement_state == MovementStates.CLIMBING:
			do_jump(JumpTypes.REGULAR)

func do_jump(jump_type):
	# -- logic of what to do for a specific jump
	jump_buffer_timer.stop()
	match jump_type:
		JumpTypes.REGULAR:
			velocity.y = jump_speed * jump_speed_modifier
		JumpTypes.SOMERSAULT_FLIP:
			velocity.y = jump_speed * jump_speed_modifier * somersault_factor
			var tween = create_tween()
			tween.tween_property(self, 
						"global_rotation",
						global_rotation + sign(last_move_input.x) * TAU, time_to_peak)
		JumpTypes.WALL:
			# TODO this needs to be played with / isn't quite right
			velocity.y = (jump_speed / 1.5) * jump_speed_modifier
			velocity.x = -last_wall_normal.x * (jump_speed / 2.2)
			#velocity = jump_speed * jump_speed_modifier * (-last_wall_normal  +  Vector2.DOWN).normalized()
	movement_state_transition_to(MovementStates.JUMPING)


func coyote_time_resolution() -> void:
	# the transition should only happen if we're coming from a certain set
	# of states, otherwise we'll jump in coyote time but be in falling state
	match movement_state:
		MovementStates.IDLE:
			movement_state_transition_to(MovementStates.FALLING)
		MovementStates.WALKING:
			movement_state_transition_to(MovementStates.FALLING)
		MovementStates.ITEM_MOVING:
			if is_falling():
				movement_state_transition_to(MovementStates.FALLING)
			else:
				movement_state_transition_to(MovementStates.IDLE)
	is_on_ground = false


func _physics_process(delta: float) -> void:
	if !last_move_input:
		last_move_input = $InputManager.movement_vector()
	
	# -- climbing check
	if should_start_climbing():
		start_climbing()
	
	# -- call the movement state function matching the movement_state variable
	call(MovementStates.keys()[movement_state].to_lower() + "_state_fn", delta)
	
	
	#tmp_burn_handle() # TODO # -- temporary burn visual feedback
	
	if current_platform: # -- account for relative velocities
		move_and_collide(current_platform.get_velocity() * delta)
	
	# -- velocity verlet update
	global_position += (velocity * delta) + Vector2(0., (0.5 * delta * delta * g))
	if velocity.y < TERMINAL_FALL_SPEED:
		velocity.y += get_g() * delta
	var collision = move_and_collide(Vector2.ZERO)
	if collision:
		# -- projection of ground normal is mostly vertical
		is_on_ground = collision.get_normal().dot(Vector2.UP) > 0.7
		if is_on_ground:
			current_platform_check( collision )
			velocity.y = 0

	last_move_input = $InputManager.movement_vector()


func current_platform_check(coll: KinematicCollision2D):
	var collider = coll.get_collider()
	if collider is MoveablePlatform:
		current_platform = collider


func there_is_move_input():
	return !is_zero_approx($InputManager.movement_vector().x)


func my_is_on_floor() -> bool:
	# -- is any downward pointing ray colliding with something?
	# -- the built in "is_on_floor()" only works with move_and_slide
	return $FloorCheckContainer.get_children().reduce(func(accum, child):
		return (accum or child.is_colliding()), false)


func is_falling():
	return velocity.y >= 0 and not my_is_on_floor()


@onready var rhs_ledge_grab_pair: Array[RayCast2D] = [$LedgeRayContainer/RHS, $WallCheckContainer/RHS1]
@onready var lhs_ledge_grab_pair: Array[RayCast2D] = [$LedgeRayContainer/LHS, $WallCheckContainer/LHS1]
@onready var ledge_grab_arrs = [rhs_ledge_grab_pair, lhs_ledge_grab_pair]
func is_ledge_grabbing() -> bool:
	var arr = lhs_ledge_grab_pair if last_move_input.x < 0 else rhs_ledge_grab_pair
	var ledge_ray = arr[0]
	var wall_ray = arr[1]
	return wall_ray.is_colliding() and !ledge_ray.is_colliding()


func ledge_grabbing_climb_position():
	var arr = lhs_ledge_grab_pair if last_move_input.x < 0 else rhs_ledge_grab_pair
	var ledge_ray = arr[0]
	var wall_ray = arr[1]
	# -- the world position of where the ray is pointing right now
	var ledge_ray_world_pos = ledge_ray.global_position + ledge_ray.target_position
	# -- there's a small offset due to the height difference between the ledge ray and
	# -- and the wall ray
	# -- I'm making this slightly smaller so we're avoid unreachable spots or whatever
	var ledge_ray_height_diff = 0.9 * (ledge_ray_world_pos.y - wall_ray.global_position.y)
	var target_pos = ledge_ray_world_pos - Vector2(0., ($CollisionShape2D.shape.height / 2.0 )
														+ ledge_ray_height_diff)
	return target_pos


func set_debug_label(new_movement_state: MovementStates) -> void:
	$Label.text = MovementStates.keys()[new_movement_state]


#------------------------------------------------- movement state fns
func move(target_speed: float, 
		  x_rate_change: float, 
		  should_check_for_falling: bool = false) -> void:
	#if disable_horizontal_movement_timer.is_stopped():
	velocity.x = move_toward(velocity.x, target_speed, x_rate_change)
	if should_check_for_falling and is_falling() and coyote_timer.is_stopped():
		coyote_timer.start()  # -- transitions to FALLING on timeout

# -- consolidate the stuff that's always true on the ground
func idle_state_fn(_delta) -> void:
	check_for_jump()
	move(0.0, DECL, true)
	if there_is_move_input():
		movement_state_transition_to( MovementStates.WALKING)


func walking_state_fn(_delta) -> void:
	check_for_jump()
	## -- side somersault check:
	## -- two -tive nums multiplied together is a positive
	## -- two +tive nums multiplied together is a positive
	## -- two differnt signed nums multiplied together is a negative
	if there_is_move_input():
		move($InputManager.movement_vector().x * move_speed * move_speed_modifier, MOV_ACCL, true)
		var switched_dir = true if last_move_input.x * $InputManager.movement_vector().x < 0 else false
		if switched_dir:
			$SideSomersaultTimer.start()
	else:
		movement_state_transition_to(MovementStates.IDLE)


func jumping_state_fn(_delta) -> void:
	# -- be carefule, I consciously took away an absolute value check
	# -- jumping should always be a negative direction
	hang_time_modifier = hang_time_curve.sample(1. - (velocity.y / jump_speed))
	
	handle_corner_correction()
	if there_is_move_input():
		move($InputManager.movement_vector().x * move_speed * move_speed_modifier, MOV_ACCL)
	if is_falling():
		movement_state_transition_to(MovementStates.FALLING)


# -- Climbing utils
func should_start_climbing():
	return (can_climb and $InputManager.movement_vector().y > 0.2 and movement_state != MovementStates.CLIMBING)


func start_climbing() -> void:
	velocity = Vector2.ZERO
	g = 0.0
	movement_state_transition_to(MovementStates.CLIMBING)


func climbing_state_fn(_delta):
	var d = $InputManager.movement_vector()
	if there_is_move_input():
		move(d.x * move_speed * move_speed_modifier, MOV_ACCL)
	else:
		move(0.0, DECL, true)
	# -- do stuff with data, e.g. velocity curve mutation from slipperiness
	velocity.y = move_toward(velocity.y, climb_speed * - d.y, MOV_ACCL)
	check_for_jump() # -- will change to jump state
	if !can_climb:
		g = fall_gravity
		movement_state_transition_to(MovementStates.FALLING)

# -- Utility functions to make platforming easier
# NOTE handle_platform_fall_near_miss_correction
#      &
#      handle_corner_correction
#      are the same up to a sign change (they do opposite nudging)
#      and the raycast container names => should probably consolidate

## nudges player in direction toward edge of platform if hitting from above, i.e falling
var nudge_to_edge_speed := 3.0 # in px
func handle_platform_fall_near_miss_correction():
	# -- should only run during fall state
	if ($FloorCheckContainer/LHS.is_colliding() and 
	   !$FloorCheckContainer/RHS.is_colliding()):
		# Move player right to clear the corner
		global_position.x -= nudge_to_edge_speed
	elif ($FloorCheckContainer/RHS.is_colliding() and 
		 !$FloorCheckContainer/LHS.is_colliding()):
		# Move player left to clear the corner
		global_position.x += nudge_to_edge_speed

## nudges player in direction toward edge of platform if hitting from below, i.e jumping
func handle_corner_correction():
	# -- should only run during jump state
	if velocity.y < 0: # Only while jumping up
		if ($CeilingCheckContainer/LHS.is_colliding() and 
		   !$CeilingCheckContainer/RHS.is_colliding()):
			# Move player right to clear the corner
			global_position.x += nudge_to_edge_speed
		elif ($CeilingCheckContainer/RHS.is_colliding() and 
			 !$CeilingCheckContainer/LHS.is_colliding()):
			# Move player left to clear the corner
			global_position.x -= nudge_to_edge_speed


func can_wall_slide():
	var input = $InputManager.movement_vector()
	var _wall_normal = wall_normal()
	last_wall_normal = _wall_normal
	var is_touching_wall = !_wall_normal.is_equal_approx(Vector2.ZERO)
	var is_pressing_into_wall = _wall_normal.x * input.x < 0
	return (is_touching_wall and is_pressing_into_wall and input.y > -0.65)


# -- TODO 
# -- abstract out repeating ledge grab check!
func falling_state_fn(_delta) -> void:
	# -- be carefule, I consciously took away an absolute value check
	# -- falling should always be positive direction
	hang_time_modifier = hang_time_curve.sample(velocity.y / TERMINAL_FALL_SPEED)
	handle_platform_fall_near_miss_correction()
	if there_is_move_input():
		# -- maybe we wanna go through the air slightly slower?
		move($InputManager.movement_vector().x * move_speed * move_speed_modifier, MOV_ACCL)
	if is_ledge_grabbing() and ledge_grab_buffer_timer.is_stopped():
		# -- we stop gravity and falling velocity, save the climbing pos
		velocity = Vector2.ZERO
		g = 0
		ledge_grab_climb_target_pos = ledge_grabbing_climb_position()
		movement_state_transition_to(MovementStates.LEDGE_GRABBING)
	
	if !wall_jump_coyote_timer.is_stopped():
		check_for_jump()
	elif can_wall_slide():
		movement_state_transition_to(MovementStates.WALL_SLIDING)
	elif my_is_on_floor():
		movement_state_transition_to(MovementStates.IDLE)


func wall_normal() -> Vector2:	
	for ray in $WallCheckContainer.get_children():
		if ray.is_colliding():
			return ray.get_collision_normal()
	return Vector2.ZERO


# -- a buffered version of wall-sliding
func can_wall_jump():
	return (!last_wall_normal.is_equal_approx(Vector2.ZERO) and 
			!wall_jump_coyote_timer.is_stopped())


func wall_sliding_state_fn(_delta) -> void:
	if can_wall_slide():
		if wall_jump_coyote_timer.is_stopped():
			wall_jump_coyote_timer.start()
	else:
		movement_state_transition_to(MovementStates.FALLING)
	
	check_for_jump()
	
	if my_is_on_floor():
		movement_state_transition_to(MovementStates.IDLE)
	elif is_ledge_grabbing():
		velocity = Vector2.ZERO
		g = 0
		ledge_grab_climb_target_pos = ledge_grabbing_climb_position()
		movement_state_transition_to(MovementStates.LEDGE_GRABBING)

# -- probably move this elsewhere
func item_moving_state_fn(_delta) -> void:
	if $ItemManager.active_movement_override.allows_horizontal_movement():
		move($InputManager.movement_vector().x * move_speed * move_speed_modifier, MOV_ACCL)
	if $ItemManager.active_movement_override.allows_jump() and !jump_buffer_timer.is_stopped():
			$ItemManager.stop_using_item()
			velocity.y += jump_speed * jump_speed_modifier
			movement_state_transition_to(MovementStates.JUMPING)
	if ($ItemManager.active_movement_override.allows_ledge_grab() and 
		is_ledge_grabbing() and 
		ledge_grab_buffer_timer.is_stopped()):
		# -- we stop gravity and falling velocity, save the climbing pos
		$ItemManager.stop_using_item()
		velocity = Vector2.ZERO
		g = 0
		ledge_grab_climb_target_pos = ledge_grabbing_climb_position()
		movement_state_transition_to(MovementStates.LEDGE_GRABBING)
	# -- does this allow me to remove fall check in parachute?
	if $ItemManager.active_movement_override.stops_on_floor() and my_is_on_floor():
		$ItemManager.stop_using_item()
		movement_state_transition_to(MovementStates.IDLE)
	if $ItemManager.active_movement_override.allows_rope_climb() and should_start_climbing():
		$ItemManager.stop_using_item()
		start_climbing()


func try_ledge_climb():
	if is_ledge_climbing or !ledge_grab_climb_target_pos or !Input.is_action_just_pressed("move_up"):
		return
	start_ledge_climb()


func start_ledge_climb():
	ledge_grab_start_pos = global_position
	# -- put into state fn
	is_ledge_climbing = true
	# -- kill any leftover tween
	# -- how to flush all tweens on game reset state?
	if ledge_climb_tween and ledge_climb_tween.is_valid():
		ledge_climb_tween.kill()

	ledge_climb_tween = create_tween()
	ledge_climb_tween.set_trans(Tween.TRANS_SINE)
	ledge_climb_tween.set_ease(Tween.EASE_OUT)

	ledge_climb_tween.tween_property(self, "ledge_climb_progress", 1.0, ledge_climb_duration)
	ledge_climb_tween.finished.connect( func():
		global_position = ledge_grab_climb_target_pos
		velocity = Vector2.ZERO
		ledge_climb_progress = 0.0
		is_ledge_climbing = false
		ledge_grab_start_pos = null
		ledge_grab_climb_target_pos = null
		movement_state_transition_to( MovementStates.IDLE))


func ledge_grabbing_state_fn(delta) -> void:
	check_for_jump()
	try_ledge_climb() # if OK, starts tween which we're sampling below
	if ledge_grab_start_pos:
		# -- target position is being lerped from @start climbing pos to @ climb target pos
		var target_pos : Vector2 = ledge_grab_start_pos.lerp(
			ledge_grab_climb_target_pos,
			ledge_climb_progress
		)
		velocity = (target_pos - global_position) / delta
		velocity = velocity.clamp( -Vector2(move_speed * move_speed_modifier, move_speed * move_speed_modifier),  Vector2(move_speed * move_speed_modifier, move_speed * move_speed_modifier))

	if Input.is_action_just_pressed("move_down"):
		ledge_grab_climb_target_pos = null
		ledge_grab_buffer_timer.start()
		movement_state_transition_to( MovementStates.FALLING)


# -- wrap this up into a more functional, modular thing to inject states into matches
func movement_state_transition_to(new_movement_state: MovementStates):
	if movement_state != new_movement_state:
		match movement_state:
			MovementStates.IDLE:
				# -- exit code here
				match new_movement_state:
					# -- enter code here
					MovementStates.WALKING:
						pass
					MovementStates.JUMPING:
						g = jump_gravity
						current_platform = null
					MovementStates.FALLING:
						g = fall_gravity
						current_platform = null
					#MovementStates.ITEM_MOVING:
						#pass
			MovementStates.WALKING:
				match new_movement_state:
					MovementStates.IDLE:
						pass
					MovementStates.JUMPING:
						g = jump_gravity
						current_platform = null
					MovementStates.FALLING:
						g = fall_gravity
						current_platform = null
			MovementStates.JUMPING:
				match new_movement_state:
					MovementStates.FALLING:
						hang_time_modifier = 1.0
						g = fall_gravity
					MovementStates.WALL_SLIDING:
						velocity = velocity.clamp(Vector2(0., 50), Vector2(0., 100))
						g = fall_gravity / 100.0
						#g = _wall_slide_gravity()
					MovementStates.LEDGE_GRABBING:
						pass
			MovementStates.FALLING:
				hang_time_modifier = 1.0
				match new_movement_state:
					MovementStates.IDLE:
						g = fall_gravity
					
					# -- CASE wall jumping coyote time
					MovementStates.JUMPING:
						g = jump_gravity
					MovementStates.WALL_SLIDING:
						# -- design choice
						# -- the wall slide should be predictable, but not boring
						velocity = velocity.clamp(Vector2(0., 50), Vector2(0., 150))
						g = fall_gravity / 100.0
						#_wall_slide_gravity()
					MovementStates.LEDGE_GRABBING:
						pass
			MovementStates.CROUCHING:
				pass
			MovementStates.WALL_SLIDING:
				match new_movement_state:
					MovementStates.IDLE:
						pass
					MovementStates.JUMPING:
						g = jump_gravity
					MovementStates.FALLING:
						g = fall_gravity
			MovementStates.LEDGE_GRABBING:
				match new_movement_state:
					MovementStates.IDLE:
						pass
					MovementStates.FALLING:
						g = fall_gravity
					MovementStates.JUMPING:
						g = jump_gravity
			MovementStates.ITEM_MOVING:
				g = jump_gravity
			MovementStates.CLIMBING:
				match new_movement_state:
					MovementStates.JUMPING:
						g = jump_gravity

		# ----------------------------------
		set_debug_label( new_movement_state )
		movement_state = new_movement_state

# ------------------------------------------------------- utils

func slow(b: bool):
	var slow_factor = 0.5
	if b:
		move_speed_modifier *= slow_factor
		jump_speed_modifier *= slow_factor
		gravity_modifier *= slow_factor
	else:
		move_speed_modifier /= slow_factor
		jump_speed_modifier /= slow_factor
		gravity_modifier /= slow_factor
	

# -- Utils to keep kinematic state straight with the outside world
func get_g() -> float:
	return (g * gravity_modifier * hang_time_modifier)

func can_parachute() -> bool:
	return (movement_state == MovementStates.FALLING or movement_state == MovementStates.JUMPING)

#
#--TODO
# -- completely replace this w/ proper visual, just here for tmp feedback
#var can_burn: bool = true
#func tmp_burn_handle() -> void:
	#var d = abs((global_position.y + 0.5 * $CollisionShape2D.shape.height)- lava_ref.lava_fn( global_position.x))
	#var hit_lava = d < 5
	#
	#if can_burn and hit_lava and lava_ref:
		#var mat = $Sprite2D.material
		#var burn_tween = create_tween()
		#mat.set_shader_parameter("dummy_burn_timer", 0.)
		#burn_tween.tween_property(mat, "shader_parameter/dummy_burn_timer", 5.0, 3.)
		#can_burn = false
#
	## -- going back accross lava threshold after getting burned
	#if !can_burn and hit_lava:
		#can_burn = true
