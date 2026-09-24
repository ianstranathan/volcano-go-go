extends CharacterBody2D

class_name Player

# -- emitted from player_controller when reconcilliation happens for
# -- visual smoothing in the PlayerVisualInterpolator (sprite & item_manager)
signal reconciled

signal touched_bottom( peer_id: int)
signal dropped_pickup_item( item_key: ItemsDb.ItemNames, item_slot: int, pos: Vector2)

var integrate_motion := true
@export var kd: PlayerKinematicData

var is_interpolatable := true

enum AcclCoeffs {
	GROUND_ACCL,
	GROUND_DECL,
	TURN_ACCL, # -- move_toward amt when turning
	AIR_ACCL,
	AIR_DECL,
	GROUND_LERP_TO_ZERO,
	GROUND_LERP_TO_TARGET_SPEED,
	AIR_LERP_TO_ZERO,
	AIR_LERP_TO_TARGET_SPEED
}

@onready var g: float = kd.jump_gravity

# -- aliases of kinematic data for reference to player (e.g. items need this)
@onready var TERMINAL_FALL_SPEED = kd.TERMINAL_FALL_SPEED


# --------------------------------------------------------- ledge grabbing stuff
var target_ledge_grabbing_climb_pos: Vector2 = Vector2.ZERO
var ledge_grabbing_starting_player_pos
var is_ledge_climbing := false
var ledge_climb_progress := 0.0


# ----------------------------------------------------------- movement modifiers
var move_speed_modifier = 1.0
var jump_speed_modifier = 1.0
var gravity_modifier = 1.0
var hang_time_modifier = 1.0
## curve sample for jumping and falling state
## makes gravity less near peak of jump, see falling or jump state fn
@export var hang_time_curve: Curve

# -------------------------------------------------- Utils var for platforming
var current_platform_displacement_ref = null # -- for moving platforms displacement
var move_input: Vector2 = Vector2.ZERO
var last_move_input: Vector2 = Vector2.ZERO
var last_non_zero_move_input: Vector2 = Vector2.RIGHT
var last_wall_normal: Vector2 = Vector2.ZERO

# -------------------------------------------------- Buffer Timers
var coyote_timer: TickTimer            = TickTimer.new(0.15)
var jump_buffer_timer: TickTimer       = TickTimer.new(0.15)
var wall_jump_coyote_timer: TickTimer  = TickTimer.new(0.25)
var ledge_grab_buffer_timer: TickTimer = TickTimer.new(0.30)
#var side_somersault_timer: TickTimer   = TickTimer.new(0.25)


# -- The number of frames where you can't move horizontally after wall jump 
var manual_wall_jump_frame_counter: int = 0
@export var num_frame_you_cant_move_after_wall_jump :int = 6

# ------------------------------------------------------------------------- misc
var can_climb := false
# -- our "truth" about being on the ground (e.g. slightly off ledge)
var is_on_ground := true 


#@export var lava_ref: Node2D

var input_manager: LocalPlayerController
@onready var player_controller = $PlayerController
var is_replaying: bool = false
@onready var animation_controller: PlayerAnimationController = ($PlayerAnimationController)

# --------------------------------------------------- state sprite effects stuff
var last_tocuhing_surface_state: MovementStates


enum MovementStates
{
	IDLE,
	WALKING,
	RUNNING,
	JUMPING,
	FALLING,
	CROUCHING,
	WALL_SLIDING,
	LEDGE_GRABBING,
	ITEM_MOVING,
	CLIMBING,
	CLOUD,
	PORTAL,
	SLIDING,
	METABALL,
	LOG_ROLL,
	GRABBED,
	# GENIE_HAND
}
@export var movement_state: MovementStates = MovementStates.IDLE

@export_category("Scene Heirarchy Stuff")

# the dedicated container in the same scene depth as the player that holds item instances
#var items_container: Node2D

#------------------------------------------------------------------- sprite vars
var color: Color = Color(1., 1., 1., 1.);

var can_run: bool = true

var projectiles_container_ref: Node2D:
	set(v):
		projectiles_container_ref = v
		if is_node_ready():
			$ItemManager.projectiles_container_ref = projectiles_container_ref

var default_land_shake_data = ShakeData.new(Vector2.UP)

var dynamic_objects_manager_ref

func _ready() -> void:
	if !$CharacterVisuals.visible:
		var my_seed = name.hash()
		seed(my_seed)
		$DebugCharacterVisual.visible = true
		$DebugCharacterVisual.material.set_shader_parameter("src_col", Vector4(randf(), randf(), randf(), 1.))
	else:
		$DebugCharacterVisual.visible = false
	#if is_multiplayer_authority():
		#is_interpolatable = false
	
	print( MovementStates )
	$GrabManager.dynamic_objects_manager_ref = dynamic_objects_manager_ref
	$GrabManager.grabbed_a_player_or_dynamic_object.connect( func( d: CharacterBody2D):
		pass)
		#grabbed_dynamic_object_ref = d)
	$GrabManager.threw_a_player_or_dynamic_object.connect( func():
		pass)
		#grabbed_dynamic_object_ref = null)
	
	$Cloud.visible = false
	# -- camera shouldn't react for non-authority players
	default_land_shake_data.is_authority = get_multiplayer_authority()
	
	animation_controller.set_movement_state(movement_state)
	#----------------------------------------------------------- Running signals
	$StaminaVisual.stamina_depleted.connect( func(): 
		can_run = false)
	$StaminaVisual.stamina_started_recharging.connect( func(): 
		can_run = true)

	$ClimbingInterface.climbing_area_entered.connect( func(): can_climb = true )
	$ClimbingInterface.climbing_area_exited.connect( func(): can_climb = false)
	#------------------------------------------------------- grabbable component
	#signal got_tossed( dir: Vector2)
	#signal got_grabbed( n: Node2D)
	#---------------------------------------------
	#assert(items_container)
	#$ItemManager.items_container = items_container
	
	#-------------------------------------------------- Local and remote signals
	#----------------------------- this controls items being able to move player
	# TODO this should only be valid on either host or local player
	# -- should have some kind of error that signal isn't connecting to anything on
	# -- remotes
	$ItemManager.item_moving_started.connect( func():
			movement_state_transition_to( MovementStates.ITEM_MOVING))
	$ItemManager.item_moving_stopped.connect( func():
			if is_falling():
				coyote_timer.start()
			else:
				movement_state_transition_to( MovementStates.IDLE))
	
	
	# ------------------------------------------------------------ Local signals
	if is_multiplayer_authority():
		# -- TODO get_child(0) is terrible
		input_manager = $PlayerController.get_child(0)
		#local_controller_added.emit( input_manager )
		assert($PlayerController.get_children().size() == 1)
		assert(input_manager is LocalPlayerController)
		
		# -- raycast visual TODO change scene path name
		var aiming_visual  = load("res://player/aiming_visual/aiming_visual.tscn").instantiate()
		add_child(aiming_visual)
		
		
		
		# -------------------------------------------- this controls aiming line
		input_manager.aim_input_detected.connect( func():
			aiming_visual.update_aiming_visual())
			
		
		# ------------------------------------------ this controls aiming target
		$ItemManager.item_targeted_something.connect( func(pos_or_null):
			aiming_visual.update_target_pos( pos_or_null))
		$ItemManager.item_ray_target_position_changed.connect( func(pos: Vector2):
			aiming_visual.update_dir( pos ))
		# --
		$ItemManager.item_switched.connect( func( aim_type):
			aiming_visual.handle_aim_type( aim_type ) )

		#$ItemManager.targeting_item_added.connect( func():
			#aiming_visual.start_aiming( ))
		input_manager.inventory_slot_selected.connect( func(slot_index: int):
			$ItemManager.select_inventory_slot.rpc(slot_index))

	coyote_timer.timeout.connect( coyote_time_resolution)


enum JumpTypes
{
	REGULAR,
	SOMERSAULT_FLIP,
	WALL,
	METABALL
}

func check_for_jump(do_jump_override=null) -> void:
	if !jump_buffer_timer.is_stopped():
		if do_jump_override:
			do_jump(do_jump_override)
			return
		if is_on_ground:
			is_on_ground = false
			#if !side_somersault_timer.is_stopped():
				#do_jump(JumpTypes.SOMERSAULT_FLIP)
			#else:
			do_jump(JumpTypes.REGULAR)
		elif can_wall_jump():
			move_input = Vector2(-last_wall_normal.x, move_input.y)
			manual_wall_jump_frame_counter = num_frame_you_cant_move_after_wall_jump
			wall_jump_coyote_timer.stop()
			do_jump(JumpTypes.WALL)
		elif is_ledge_grabbing():
			do_jump(JumpTypes.REGULAR)
		# NOTE change this man
		elif movement_state == MovementStates.CLIMBING:
			do_jump(JumpTypes.REGULAR)


func do_jump(jump_type, velocity_override=null):
	# -- logic of what to do for a specific jump
	jump_buffer_timer.stop()
	match jump_type:
		JumpTypes.REGULAR:
			velocity.y = kd.jump_speed
		#JumpTypes.SOMERSAULT_FLIP:
			#velocity.y = kd.jump_speed * jump_speed_modifier * somersault_factor
			#var tween = create_tween()
			#tween.tween_property(self, 
						#"global_rotation",
						#global_rotation + sign(last_move_input.x) * TAU, time_to_peak)
		JumpTypes.WALL:
			if !velocity_override:
				velocity = Vector2(-last_wall_normal.x * kd.wall_jump_scale.x,
									kd.wall_jump_scale.y)
			else:
				velocity = velocity_override
			# -- maybe want both components to be affected?
		JumpTypes.METABALL:
			var v = -(global_position - $MetaballManager.platform_ref.global_position).normalized()
			var y_dir = 1. if is_zero_approx(v.y) else v.y
			velocity =  Vector2(v.x *  kd.jump_speed / 2., 
								y_dir * kd.jump_speed)
	velocity.y *= jump_speed_modifier

	movement_state_transition_to(MovementStates.JUMPING)
	
	if is_multiplayer_authority() and not is_replaying:
		Events.emit_signal("play_world_sound",
							AudioDb.WorldSoundId.JUMP,
							global_position,0,randf_range(0.8, 1.20),
							{})
	

func coyote_time_resolution() -> void:
	# the transition should only happen if we're coming from a certain set
	# of states, otherwise we'll jump in coyote time but be in falling state
	match movement_state:
		MovementStates.IDLE:
			movement_state_transition_to(MovementStates.FALLING)
		MovementStates.WALKING:
			movement_state_transition_to(MovementStates.FALLING)
		MovementStates.RUNNING:
			movement_state_transition_to(MovementStates.FALLING)
		MovementStates.SLIDING:
			movement_state_transition_to(MovementStates.FALLING)
		MovementStates.ITEM_MOVING:
			if is_falling():
				movement_state_transition_to(MovementStates.FALLING)
			else:
				movement_state_transition_to(MovementStates.IDLE)
	is_on_ground = false

# ------------------------------------------------------------------------------

# -- for itnerpolating sprite / visual smoothing in reconcilliation
var pos_previous: Vector2 = Vector2.ZERO
var pos_current: Vector2 = Vector2.ZERO

func frame_disp() -> Vector2:
	return (pos_current - pos_previous)


# -- small optimization, no need to make a new array that's ghoing to repeate
# -- itself / never change
@onready var movement_states_keys = MovementStates.keys()

# -- if the moving platform loops ( modulo ) we don't want to be stuck to it
var disp_threshold_squared = 25000 # -- i.e. 50 px

# -- for incline logic
const MIN_GROUND_COS = 0.3
const SLIDE_COS_THRESHOLD = 0.95 #  -- lt 30 deg

func execute_tick(delta: float, cmd: PlayerCommand):
	pos_previous = global_position
	# -- we guarenteed that we ticked through all the world geometry that can move
	if current_platform_displacement_ref:
		var disp: Vector2 = current_platform_displacement_ref.displacement
		if disp.length_squared() < disp_threshold_squared:
			if ledge_grabbing_starting_player_pos:
				ledge_grabbing_starting_player_pos += disp
			if target_ledge_grabbing_climb_pos:
				target_ledge_grabbing_climb_pos += disp
			global_position += disp
		else:
			current_platform_displacement_ref = null
			
	apply_command(cmd)
	$ItemManager.process_item_tick(delta, cmd)
	
	if !last_move_input:
		last_move_input = move_input
	
	$StaminaVisual.update_tick( delta )
	
	# -- climbing check
	if should_start_climbing():
		start_climbing()
	
	# -- manual wall jumping frame management:
	if manual_wall_jump_frame_counter > 0:
		manual_wall_jump_frame_counter -= 1
	
	# -- call the movement state function matching the movement_state variable
	call(movement_states_keys[movement_state].to_lower() + "_state_fn", delta)

	# ---------------------------------------------------------------------------
	if integrate_motion:
		var motion = (velocity * delta) + Vector2(0., (0.5 * delta * delta * get_g()))
		var virtual_collision = move_and_collide(motion, true)
		if virtual_collision:
			var virtual_collider = virtual_collision.get_collider()
			# -- TODO
			if virtual_collider is Player:
				MyPhysicsUtils.resolve_collision(self, virtual_collider, virtual_collision)
				motion = (velocity * delta) + Vector2(0., (0.5 * delta * delta * get_g()))
				
		global_position += motion #(velocity * delta) + Vector2(0., (0.5 * delta * delta * get_g()))
	
		# -- NOTE
		if last_move_input.length_squared() > 0:
			last_non_zero_move_input = last_move_input
		last_move_input = move_input
		pos_current = global_position
	
		# -- NOTE
		if velocity.y < kd.TERMINAL_FALL_SPEED:
			velocity.y += get_g() * delta
		
		# -- NOTE
		var collision = move_and_collide(Vector2.ZERO)
		if collision:
			var normal = collision.get_normal()
			
			# -- are we colliding with something vertically?
			# -- at least partially?
			# -- if the collision is the direction of UP or DOWN?
			var cos_angle = normal.dot(Vector2.UP)
			if cos_angle > 0.:
				# -- are we colliding with something that we stand on
				# -- i.e. is the angle between the normal and straight up 
				# -- v dot a if = |v||a|cos(theta) => this is just the cos of an angle
				# -- cos(pi/2.5) ~= 0.3; pi/2.5 = 72 degrees
				is_on_ground = cos_angle >= MIN_GROUND_COS
				if is_on_ground:
					# -- sliding check
					var is_steep_enough_to_slide = cos_angle < SLIDE_COS_THRESHOLD
					if is_steep_enough_to_slide and going_downhill(normal):
						movement_state_transition_to(MovementStates.SLIDING)
						return
					# -- clear gravity accumulation
					velocity.y = 0.0
					var slope_tangent = normal.orthogonal()
					if slope_tangent.x * sign(normal.y) > 0:
						slope_tangent = -slope_tangent
					#var steepness_factor = inverse_lerp(MIN_GROUND_COS, 1.0, cos_angle)
					#
					#var t = (1. - (steepness_factor * steepness_factor) 
							#if movement_state == MovementStates.SLIDING else steepness_factor)
					#var thr = 0.7 if movement_state == MovementStates.SLIDING else 0.3
					#print(lerp(MIN_GROUND_COS, 1.0, t))
					#var adjusted_speed =  abs(velocity.x) * lerp(MIN_GROUND_COS, 1.0, t)

					velocity = slope_tangent * abs(velocity.x) * sign(velocity.x)
					#if is_equal_approx(cos_angle, 1.):
						#print("on flat ground")
						#velocity.y = 0.
					#else:
						#var vel_along_hill = velocity.slide(normal)
						##p#rint(cos_angle)
						#if going_downhill(normal):
							#velocity = vel_along_hill
							#print("going downhill")
						#else:
							#var min_mov = move_input.slide( normal ) * kd.baseline_speed *0.6
							#velocity = (vel_along_hill if ( min_mov.length_squared() < vel_along_hill.length_squared() )
										#else min_mov)
							#print("going uphill")
					
					current_platform_displacement_ref_check(collision)
			else:
				# -- we're hitting out head
				if velocity.y < 0:
					velocity.y = 0.1 * velocity.y
				velocity = velocity.slide(normal)

	# -- moving this so we don't miss it while returning early from a state transition
	
	#if last_move_input.length_squared() > 0:
		#last_non_zero_move_input = last_move_input
	#last_move_input = move_input
	#pos_current = global_position


func receive_shove(position_offset: Vector2, instigator_velocity: Vector2) -> void:
	# -- 
	global_position += position_offset
	# -- heuristic for decay
	velocity += instigator_velocity * 0.25
	# no inf
	velocity = velocity.limit_length(kd.MAX_PUSH_SPEED if "MAX_PUSH_SPEED" in kd else 1200.0)


# ------------------------------------------------------------------------------
func scale_vel_along_tangent( _tangent : Vector2) -> void:
	var tangent = _tangent
	if move_input.x != 0.0 and tangent.x * move_input.x < 0.0:
		tangent = -tangent
	var speed = velocity.length()
	if abs(tangent.x) > 0.1:
		var scale_factor = clamp(velocity.x / tangent.x, -speed * 10, speed * 10)
		velocity = tangent * scale_factor


@rpc("any_peer", "unreliable")
func predict_impact_notification( impulse: Vector2):
	# -- locally predict on the client B now, -tive, equal but opposite
	velocity -= kd.inv_mass * impulse
	# -- update interpolated client A now
	var id = multiplayer.get_remote_sender_id()
	var caller = NetManager.player_instances_by_player_id.get( id )
	if caller:
		# -- it's +tive, equal but opposite
		caller.player_controller.inject_predicted_state(
			caller.kd.inv_mass * impulse
		)

# ------------------------------------------------------------------------------
# -- TODO
var is_on_one_way_platform: bool = false
func current_platform_displacement_ref_check(coll: KinematicCollision2D):
	var collider = coll.get_collider()
	if collider and collider.is_in_group("moving_platforms"):
		current_platform_displacement_ref = collider.get_node_or_null("MovingPlatformComponent")

	if collider and collider.is_in_group("one_way_platforms"):
		is_on_one_way_platform = true


func current_platform_for_remote_interpolating() -> void:
	if my_is_on_floor():
		current_platform_displacement_ref_check(move_and_collide(Vector2.ZERO, true))


func my_is_on_floor() -> bool:
	# -- is any downward pointing ray colliding with something?
	# -- the built in "is_on_floor()" only works with move_and_slide
	return $FloorCheckContainer.get_children().reduce(func(accum, child):
		return (accum or child.is_colliding()), false)


func is_falling():
	return velocity.y >= 0 and not my_is_on_floor()


@onready var lhs_wall_rays:  Array[RayCast2D] = [
	$WallCheckContainer/LHS1,
	$WallCheckContainer/LHS2,
	$WallCheckContainer/LHS3
]
@onready var rhs_wall_rays:  Array[RayCast2D] = [
	$WallCheckContainer/RHS1,
	$WallCheckContainer/RHS2,
	$WallCheckContainer/RHS3
]

# -- NOTE
# -- this also sets a ledge grabbing position
# -- and a grabbing_climb_to position


func is_ledge_grabbing(_set_global_position=false) -> bool:
	var grabbing_left = last_move_input.x < 0
	var wall_arr := lhs_wall_rays if grabbing_left else rhs_wall_rays
	var top_down_ray := $TopDownRayContainer/LHS if grabbing_left else $TopDownRayContainer/RHS
	var ledge_ray := $LedgeRayContainer/LHS if grabbing_left else $LedgeRayContainer/RHS
	# -- if any of the wall rays are colliding and the ledge ray isn't colliding
	var ret = false
	var ledge_grab_position: Vector2

	for _ray in wall_arr:
		if _ray.is_colliding() and !ledge_ray.is_colliding() and top_down_ray.is_colliding():
			ret = true
			
			var _coll =  _ray.get_collider()
			if _coll.is_in_group("moving_platforms") and _coll !=current_platform_displacement_ref:
				current_platform_displacement_ref = _coll.get_node_or_null("MovingPlatformComponent")
			ledge_grab_position = Vector2(
				_ray.get_collision_point().x,
				top_down_ray.get_collision_point().y)
			# -- taget climb up should be the player just standing on the edge
			target_ledge_grabbing_climb_pos = (ledge_grab_position +
				Vector2(sign(last_move_input.x) * $CollisionShape2D.shape.radius,
						-0.5 * $CollisionShape2D.shape.height))
	if ret and _set_global_position:
		# -- magic number is to just make it look slightly more natural (we don't want the very top)
		# -- of the collshape to be at the ledge
		global_position.y = ledge_grab_position.y + 0.7 * $CollisionShape2D.shape.height / 2.

	return ret


func set_debug_label(new_movement_state: MovementStates) -> void:
	$Label.text = MovementStates.keys()[new_movement_state]


func check_for_falling() -> bool:
	return is_falling() and coyote_timer.is_stopped()


func crouching_state_fn(_delta: float):
	grounded_horizontal_movement(_delta)
	if check_for_falling():
		coyote_timer.start()

var surface_rotation_vel: float = 0.
var log_normal: Vector2 = Vector2.ZERO
var log_tangent: Vector2 = Vector2.ZERO
func start_log_rolling( w: float, n: Vector2) -> void:
	is_on_ground = true
	# -- zero normal part of velocity:
	var vel_in_normal_dir := velocity.dot( n ) * n
	velocity -= vel_in_normal_dir
	surface_rotation_vel = w
	log_normal = n
	log_tangent = Vector2(n.y, -n.x)
	#print("normal", log_normal)
	#print("velocity direction", log_normal * surface_rotation_vel)
	movement_state_transition_to(MovementStates.LOG_ROLL)

# -- called by the log area

func fall_off_log() -> void:
	if movement_state != MovementStates.JUMPING:
		movement_state_transition_to(MovementStates.FALLING)
		is_on_ground = false
	#elif velocity.y > 0:
		#is_on_ground = false

func apply_log_tangent_movement( _tangent : Vector2) -> void:
	var tangent = _tangent
	if move_input.x != 0.0 and tangent.x * move_input.x < 0.0:
		tangent = -tangent
	
	# -- project/scale only the component moving along the tangent, or blend
	var current_speed = velocity.length()
	if abs(tangent.x) > 0.1:
		var scale_factor = clamp(velocity.x / tangent.x, -current_speed * 1.5, current_speed * 1.5)
		
		# -- keep normal component while updating the tangent component
		var tangent_velocity = tangent * scale_factor
		var normal_component = velocity.project(log_normal)
		velocity = tangent_velocity + normal_component
		

func log_roll_state_fn(_delta:):
	grounded_horizontal_movement( _delta )
	apply_log_tangent_movement(log_tangent)
	check_for_jump()
	velocity += log_normal * _delta * 10. * (surface_rotation_vel - move_input.y * kd.baseline_speed)



# -- callback from metaball's area2d
func transition_to_metaball(collision_pt: Vector2,
							platform_ref: BasePlatform) -> void:
	if movement_state != MovementStates.METABALL:
		$MetaballManager.initialize_metaball_state( collision_pt, platform_ref )
		do_jump_out_of_metaball_vfx()
		go_2_circle_shape()
		#$CollisionShape2D.set_deferred("disabled", true)
		$CharacterVisuals/Body.visible = false
		movement_state_transition_to(MovementStates.METABALL)
		velocity = Vector2.ZERO
	
	# -- switch over the collision stuff

# -- used for crouching and metaball state currently
var capsule_coll_shape_height = 100.0 # -- in px
var default_coll_shape_radius = 20.0
var circle_coll_shape_height: float = 2.0 * default_coll_shape_radius
var default_2_circle_scale = (circle_coll_shape_height / capsule_coll_shape_height)

@onready var all_raycasts_arr = [$WallCheckContainer,$LedgeRayContainer, 
								$FloorCheckContainer, $CeilingCheckContainer,
								$TopDownRayContainer]

# -- NOTE we're not currently changing the radius ever, but more general I guess
func my_change_collision_shape(h: float, r: float, s: float) -> void:
	# -- params are height, radius, scale (see raycast_container.gd)
	# -- set the collision shape in a deferred call
	# -- recursively change all the positions of the raycasts
	for ray_container in all_raycasts_arr:
		ray_container.scale_raycast_positions(s)
	$CollisionShape2D.shape.set_deferred("height", h)
	$CollisionShape2D.shape.set_deferred("radius", r)

# -- 
func go_2_circle_shape():
	my_change_collision_shape(circle_coll_shape_height, 
							  default_coll_shape_radius, 
							  default_2_circle_scale)


func go_2_capsule_shape():
	my_change_collision_shape(capsule_coll_shape_height, 
							  default_coll_shape_radius, 
							  1. / default_2_circle_scale)


#func metaball_state_fn(delta):
	## -- ok, so we're gaurenteeing that the player is in a circle shape
	## -- so whatever the global_position is, we can just offset it by the rel_pos direction
	## -- of the platform + the radius
	#var rel_pos : Vector2 = (global_position - 
		#$MetaballManager.platform_ref.global_position).normalized()
	#var offset_vector = rel_pos * 1.5 * $CollisionShape2D.shape.radius
	## -- increment perimeter, based on input
	#global_position = offset_vector + $MetaballManager.increment_perimeter(
		#delta,
		#Vector2(move_input.x, -move_input.y))
	#
	#check_for_jump(JumpTypes.METABALL)
func metaball_state_fn(delta):
	var plat = $MetaballManager.platform_ref
	# the metaball manager returns paltform local space coordinates
	var local_target = $MetaballManager.increment_perimeter(
		delta,
		Vector2(move_input.x, -move_input.y)
	)

	#  -- compute the outward normal in local space
	var local_normal = $MetaballManager.perimeter_normal()
	# -- still in locall space, don't change coords til end
	var local_offset = local_normal * (
		$CollisionShape2D.shape.radius * 1.5
	)
	var local_position = local_target + local_offset

	# convert into world coordinates.
	#global_position = plat.to_global(local_position)
	global_position = global_position.move_toward(
		plat.to_global(local_position),
		kd.baseline_speed * delta
		)
	
	check_for_jump(JumpTypes.METABALL)

#func fall_through_one_way_platform(y_input: float, _jump_pressed: bool):
	#
		
# -- consolidate the stuff that's always true on the ground

func idle_state_fn(_delta) -> void:
	check_for_jump()
	velocity.x = move_toward(velocity.x, 0.0, kd.MOV_ACCL)
	#fn(_delta)
	
	
	if !is_zero_approx(move_input.x):
		movement_state_transition_to( MovementStates.WALKING)
		return
	if check_for_falling():
		coyote_timer.start()
		

func grounded_easing(t: float, reversing: bool, b: bool = true) -> float:
	if b:
		return t * t if !reversing else (1. - t) * (1. - t)
	return t if !reversing else (1. - t)


func grounded_horizontal_movement( delta ):
	var target_speed : float= move_input.x * state_target_x_speed
	# -- 0 at 0 and 1 at state speed
	var t : float = clamp(abs(velocity.x) / state_target_x_speed, 0.0, 1.0)
	var reversing := (
		move_input.x != 0
		and velocity.x * move_input.x < 0
	)
	if reversing:
		# -- we're inverting the interpolant
		# -- if reversing
		# -- so it's 0 when we're at speed
		# -- and 1 if we're at zero
		t = 1.0 - t

	#TODO NOTE
	# -- these don't have to be the same, they can also change or have pairs
	# -- depending on what we're doing
	var a0 = 8000.0
	var a1 = 2000.0
	
	var accel : float = lerp( a0, a1,
		# -- this is giving us that satisfying start delay
		pow((1. - t), 3.0) if !reversing else t
		#grounded_easing(t, reversing, false)
	)
	velocity.x = move_toward(
		velocity.x,
		target_speed,
		accel * delta
	)


func walking_state_fn(delta) -> void:
	check_for_jump()
	grounded_horizontal_movement( delta )
	step_over(delta)
	if check_for_falling():
		coyote_timer.start()
	#if #!has_horizontal_intent(): #and side_somersault_timer.is_stopped():
	if is_zero_approx(velocity.x):
		movement_state_transition_to( MovementStates.IDLE)
		return


func running_state_fn( _delta) -> void:
	check_for_jump()
	grounded_horizontal_movement( _delta )
	step_over( _delta )
	if check_for_falling():
		coyote_timer.start()
	if is_zero_approx(velocity.x):
		movement_state_transition_to( MovementStates.IDLE)
		return

var time_sliding = 0.0
var exp_coeff = 0.3
func sliding_state_fn( _delta) -> void:
	time_sliding += _delta
	#print(time_sliding)
	assert( integrate_motion == true)
	check_for_jump()
	if check_for_falling():
		coyote_timer.start()
	if abs(velocity.x) < kd.baseline_speed:
		movement_state_transition_to( MovementStates.WALKING)
		return
	if is_zero_approx(velocity.x):
		movement_state_transition_to( MovementStates.IDLE)
	
	velocity = velocity * exp(-time_sliding * exp_coeff)


# -- case: where we want a wall jump as fast as possible
func wall_jump_fast_utility():
	if !jump_buffer_timer.is_stopped():
		var _normal := wall_normal()
		if _normal != Vector2.ZERO:
			do_jump(JumpTypes.WALL,  kd.wall_jump_scale * Vector2(-_normal.x, 1.))


func jumping_state_fn(_delta) -> void:
	# -- be careful, I consciously took away an absolute value check
	# -- jumping should always be a negative direction
	hang_time_modifier = hang_time_curve.sample(1. - (velocity.y / kd.jump_speed))
	handle_corner_correction()
	wall_jump_fast_utility()
	non_grounded_horizontal_movement( _delta )
	
	if is_falling():
		movement_state_transition_to(MovementStates.FALLING)
		return


func non_grounded_horizontal_movement( _delta):
	# -- if overspeed and not turning, keep riding the wave
	# -- if overspeed and turning hard turn
	#if manual_wall_jump_frame_counter > 0:
		#return
	var reversing := (
		move_input.x != 0
		and velocity.x * move_input.x < 0
	)
	#var is_overspeed = abs(velocity.x) > state_target_x_speed# * 1.05
	var is_overspeed = velocity.length_squared() > state_target_x_speed * state_target_x_speed
	#print(is_overspeed)
	if is_overspeed:
		if reversing:
			velocity.x = lerp(velocity.x, 
							  state_target_x_speed * move_input.x, 
							  0.5)
		else:
			return
	else:
		velocity.x = move_toward(
			velocity.x,
			state_target_x_speed * move_input.x,
			kd.air_accl
		)

# -- Climbing utils
func should_start_climbing():
	return (can_climb and move_input.y > 0.2 and movement_state != MovementStates.CLIMBING)


func start_climbing() -> void:
	velocity = Vector2.ZERO
	g = 0.0
	movement_state_transition_to(MovementStates.CLIMBING)


var climb_move_override: Callable = (func():
	var _inverted_y_move_input = Vector2(move_input.x, -move_input.y)
	velocity = velocity.move_toward(_inverted_y_move_input * kd.climb_speed * move_speed_modifier, kd.MOV_ACCL))


func climbing_state_fn(_delta):
	$ItemManager.stop_using_item()
	check_for_jump()
	if !can_climb:
		g = kd.fall_gravity
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
	#var input = move_input
	var _wall_normal = wall_normal()
	last_wall_normal = _wall_normal
	var is_touching_wall = !_wall_normal.is_equal_approx(Vector2.ZERO)
	var is_pressing_into_wall = _wall_normal.x * move_input.x < 0
	return (is_touching_wall and is_pressing_into_wall and move_input.y > -0.65)


# -- TODO 
# -- abstract out repeating ledge grab check!
func falling_state_fn(_delta) -> void:
	# -- be careful, I consciously took away an absolute value check
	# -- falling should always be positive direction
	hang_time_modifier = hang_time_curve.sample(velocity.y / kd.TERMINAL_FALL_SPEED)
	handle_platform_fall_near_miss_correction()
	# -- maybe we wanna go through the air slightly slower?
	
	wall_jump_fast_utility()
	non_grounded_horizontal_movement( _delta )
	# -- ledge climbing target position is mutated / saved in is_ledge_grabbing()
	if is_ledge_grabbing(true) and ledge_grab_buffer_timer.is_stopped():
		velocity = Vector2.ZERO
		g = 0
		start_ledge_grab()
	
	if !wall_jump_coyote_timer.is_stopped():
		check_for_jump()
	elif can_wall_slide():
		movement_state_transition_to(MovementStates.WALL_SLIDING)
	elif my_is_on_floor():
			#var land_shake = ShakeInstance.new(0.5, 0.1, Vector2.DOWN, MyMathUtils.inverted_parabola, false)
			#Events.shake_cam.emit(land_shake)
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
		start_ledge_grab()


# -- NOTE
# -- UTIL
#func transition_to_jump():
	## -- don't interact with 1-way platforms
	#set_collision_mask_value(9, false)
	#movement_state_transition_to(MovementStates.JUMPING)


# -- probably move this elsewhere
func item_moving_state_fn(_delta) -> void:
	if $ItemManager.active_movement_override.allows_horizontal_movement():
		if !move_input.is_zero_approx():
			velocity.x = move_toward(velocity.x, move_input.x * kd.baseline_speed, kd.DECL / 2.)
		else:
			velocity.x = move_toward(velocity.x, 0.0, kd.DECL / 12.0)

	if $ItemManager.active_movement_override.allows_jump() and !jump_buffer_timer.is_stopped():
			$ItemManager.stop_using_item()
			velocity.y += kd.jump_speed * jump_speed_modifier
			movement_state_transition_to(MovementStates.JUMPING)
	if ($ItemManager.active_movement_override.allows_ledge_grab() and 
		is_ledge_grabbing() and 
		ledge_grab_buffer_timer.is_stopped()):
		# -- we stop gravity and falling velocity, save the climbing pos
		$ItemManager.stop_using_item()
		velocity = Vector2.ZERO
		g = 0
		start_ledge_grab()

	# -- does this allow me to remove fall check in parachute?
	if $ItemManager.active_movement_override.stops_on_floor() and my_is_on_floor():
		$ItemManager.stop_using_item()
		movement_state_transition_to(MovementStates.IDLE)
	if $ItemManager.active_movement_override.allows_rope_climb() and should_start_climbing():
		$ItemManager.stop_using_item()
		start_climbing()


func start_ledge_grab():
	is_ledge_climbing = false # -- the actual motion hasn't started yet
	if target_ledge_grabbing_climb_pos:
		ledge_climb_progress = 0.0
		movement_state_transition_to(MovementStates.LEDGE_GRABBING)
	else:
		movement_state_transition_to( MovementStates.FALLING)


func ledge_grabbing_state_fn(delta) -> void:
	check_for_jump()
	
	# -- start climbing if you press up and you can
	if move_input.y > 0.6 and !is_ledge_climbing:
		is_ledge_climbing = true
		$CollisionShape2D.set_deferred("disabled", true)
		ledge_grabbing_starting_player_pos = global_position
	
	if is_ledge_climbing:
		ledge_climb_progress += 4. * delta
		global_position = ledge_grabbing_starting_player_pos.lerp(
			target_ledge_grabbing_climb_pos,
			ledge_climb_progress * ledge_climb_progress # -- x^2 easing
		)

	if ledge_climb_progress >= 1.0 or move_input.y < -0.6:
		$CollisionShape2D.set_deferred("disabled", false)
		ledge_grab_buffer_timer.start()
		movement_state_transition_to( MovementStates.FALLING)


var other_grab_manager
var _pause := false
#func disable_collision():
	#print_stack()
	#$CollisionShape2D.set_deferred("disabled", true)
	
	
func get_grabbed( _other_grab_manager: Area2D ) -> void:
	#print(
		#"In get_grabbed, ", 
		#"GRAB tick=", NetManager.current_tick,
		#" player=", name,
		#" grabber=", _other_grab_manager.name,
		#" pos=", global_position
	#)
	other_grab_manager = _other_grab_manager
	integrate_motion = false
	is_interpolatable = false
	velocity = Vector2.ZERO
	global_position = other_grab_manager.global_position
	
	#print("calling from in get_grabbed from peer: ", multiplayer.get_unique_id(),
		  #" from player ", _other_grab_manager.get_parent().name, 
		  #" onto player: ", name)

	#print("in grabbed fn before: ", global_rotation)
	global_rotation = PI / 3.
	#print("in grabbed fn after: ", global_rotation)
	movement_state_transition_to( MovementStates.GRABBED )
	
	$CollisionShape2D.set_deferred("disabled", true)
	_pause = true
	# -- does z-fighting actually happen?
	z_index += 10


# -- reversing all the stuff that happens in get_grabbed
func get_thrown( throw_vel: Vector2) -> void:
	global_rotation = 0.0
	velocity = throw_vel / kd.mass
	z_index -= 10
	other_grab_manager = null
	integrate_motion = true
	is_interpolatable = true
	$CollisionShape2D.set_deferred("disabled", false)
	movement_state_transition_to( MovementStates.FALLING)
	


func return_grabbed_object():
	return $GrabManager.get_grabbed_object()


func grabbed_state_fn( _delta: float) -> void:
	# -- play some struggle vfx
	# -- maybe like beads of sweat pouring off of him or something
	# -- check for break out conditions
	# -- accumulate something from apply_cmd --> enough then breakout
	global_position = other_grab_manager.global_position
	
	#global_rotation = other_grab_manager.global_rotation + PI / 4.0
	#print("in grab state fn: ", global_rotation)
	#print(
		#"GRAB tick=", NetManager.current_tick,
		#" player=", name,
		#" grabber=", other_grab_manager.name,
		#" pos=", global_position
	#)

	# -- 
	
	#movement_state_transition_to( MovementStates.FALLING)
	
# -- using this to run state function on an interpolating remote player
func state_fn_from_state( delta ):
	match movement_state:
		MovementStates.GRABBED:
			assert( other_grab_manager != null)
			grabbed_state_fn( delta )
		_:
			return 


func portal_state_fn( _delta: float ) -> void:
	# -- maybe do some vfx here
	pass


@onready var floor_checking_rays: Array[RayCast2D] = [$FloorCheckContainer/RHS,
$FloorCheckContainer/RayCast2D, $FloorCheckContainer/LHS]

func toggle_all_collision_masks(b: bool) -> void:
	# -- on player capsule
	set_collision_mask_value(1, b)
	set_collision_mask_value(2, b)
	set_collision_mask_value(3, b)
	set_collision_mask_value(4, b)
	
	# -- on floor checking rays
	for _ray in floor_checking_rays:
		_ray.set_collision_mask_value(1, b)
		_ray.set_collision_mask_value(3, b)


func start_cloud_descent():
	toggle_all_collision_masks(false)
	movement_state_transition_to(MovementStates.CLOUD)

@onready var cloud_move_speed = 4. * kd.baseline_speed
func cloud_state_fn( _delta: float ) -> void:
	#if !$Cloud.visible:
		#$Cloud.visible = true
	velocity.y = max(move_toward(velocity.y, -move_input.y * cloud_move_speed, kd.MOV_ACCL),
					0.1 * cloud_move_speed)
	velocity.x = move_toward(velocity.x, move_input.x * cloud_move_speed, kd.MOV_ACCL)
	if my_is_on_floor():
		#print(name.to_int())
		touched_bottom.emit( name.to_int() )
		$Cloud.visible = false
		toggle_all_collision_masks(true)
		movement_state_transition_to( MovementStates.IDLE )




func movement_state_transition_to(new_movement_state: MovementStates):
	if movement_state != new_movement_state:
		match movement_state:
			MovementStates.IDLE:
				match new_movement_state:
					MovementStates.JUMPING:
						current_platform_displacement_ref = null
						is_on_one_way_platform = false
					MovementStates.FALLING:
						current_platform_displacement_ref = null
						is_on_one_way_platform = false
			MovementStates.WALKING:
				match new_movement_state:
					MovementStates.JUMPING:
						current_platform_displacement_ref = null
						is_on_one_way_platform = false
					MovementStates.FALLING:
						current_platform_displacement_ref = null
						is_on_one_way_platform = false
				# step over mechanic catch
				$CollisionShape2D.set_deferred("disabled", false)
			MovementStates.JUMPING:
				match new_movement_state:
					MovementStates.FALLING:
						hang_time_modifier = 1.0
					MovementStates.WALL_SLIDING:
						velocity = velocity.clamp(Vector2(0., 50), Vector2(0., 100))
			MovementStates.FALLING:
				hang_time_modifier = 1.0
				var play_landing_effect = false
				match new_movement_state:
					MovementStates.CLOUD:
						$Cloud.visible = true
						#print(multiplayer.get_unique_id())
					MovementStates.IDLE:
						g = kd.fall_gravity
						play_landing_effect = true
						if velocity.y >= 0.8 * TERMINAL_FALL_SPEED:
							Events.shake_cam.emit(default_land_shake_data)
					MovementStates.WALL_SLIDING:
						velocity = velocity.clamp(Vector2(0., 50), Vector2(0., 150))
					MovementStates.JUMPING:
						if last_tocuhing_surface_state == MovementStates.WALL_SLIDING:
							do_wall_jump_vfx()
					
				
				if play_landing_effect:
					set_collision_mask_value(9, true)
					do_landing_vfx()
					Events.emit_signal("play_world_sound",
										AudioDb.WorldSoundId.JUMP_LAND,
										global_position,0,randf_range(0.8, 1.20),
										{})
			MovementStates.WALL_SLIDING:
				match new_movement_state:
					MovementStates.JUMPING:
						do_wall_jump_vfx()
			MovementStates.RUNNING:
				$StaminaVisual.use( false )
				# -- step over catch
				$CollisionShape2D.set_deferred("disabled", false)
			#MovementStates.ITEM_MOVING:
				#if $CollisionShape2D.disabled:
					#$CollisionShape2D.set_deferred("disabled", false)
			MovementStates.METABALL:
				$CharacterVisuals/Body.visible = true
				go_2_capsule_shape()
				do_jump_out_of_metaball_vfx()

				integrate_motion = true
			MovementStates.LEDGE_GRABBING:
				$CollisionShape2D.set_deferred("disabled", false)
		
		match new_movement_state:
			MovementStates.JUMPING:
				toggle_one_way_platform_collisions(false)
			MovementStates.FALLING:
				toggle_one_way_platform_collisions(true)
			MovementStates.SLIDING:
				#velocity *= 2.0
				time_sliding = 0.
		state_target_x_speed = get_horizontal_target_speed_from_state( new_movement_state )
		# -----------------------------------------
		# ----------------------------------
		if new_movement_state == MovementStates.METABALL:
			integrate_motion = false
		# ----------------------------------
		if new_movement_state in [MovementStates.IDLE, MovementStates.WALKING, MovementStates.WALL_SLIDING]:
			last_tocuhing_surface_state = new_movement_state
		set_debug_label( new_movement_state )
		movement_state = new_movement_state
		animation_controller.set_movement_state(new_movement_state)

@onready var one_way_collision_structs: Array = $CeilingCheckContainer.get_children() + $FloorCheckContainer.get_children()
func toggle_one_way_platform_collisions(b: bool) -> void:
	# -- all the rays that have logic assoc with them
	for c in one_way_collision_structs:
		c.set_collision_mask_value(9, b)
	# -- our own coll
	set_collision_mask_value(9, b)
# --------------------------------------------------------------------------------------------------
# -- move this all to a vfx manager on the player
# -- this is really just a dictionary or struct with some editor sugar
# -- (i.e. it's really just a data container, but if it's a class, I don't forget the params)
@onready var landing_effect = EffectParameters.new(Effects.EffectNames.LANDING_SMOKE, Vector2.ZERO, false, Vector2.ZERO)
@onready var wall_jump_effect = EffectParameters.new(Effects.EffectNames.WALL_JUMP, Vector2.ZERO, false, Vector2.ZERO)
@onready var metaball_jump_out_effect = EffectParameters.new(Effects.EffectNames.JUMPED_OUT_OF_METABALL, Vector2.ZERO, false, Vector2.ZERO)

func do_landing_vfx():
	landing_effect.pos = global_position - Vector2(0., $CollisionShape2D.shape.height / 2.)
	landing_effect.flip = false
	Events.world_effect.emit( name.to_int(), landing_effect )

func do_wall_jump_vfx():
	wall_jump_effect.pos = global_position - Vector2(0., $CollisionShape2D.shape.height / 2.)
	wall_jump_effect.flip = true if last_wall_normal.x < 0 else false
	Events.world_effect.emit( name.to_int(), wall_jump_effect )

func do_jump_out_of_metaball_vfx():
	var n = $MetaballManager.perimeter_normal()
	metaball_jump_out_effect.pos = global_position - $CollisionShape2D.shape.height * n
	metaball_jump_out_effect.dir = n
	Events.world_effect.emit( name.to_int(), metaball_jump_out_effect )

# -------------------------------------------------------------------------------------------- utils
@onready var state_target_x_speed : float = kd.baseline_speed
func get_horizontal_target_speed_from_state( s: MovementStates) -> float:
	match s:
		MovementStates.IDLE:
			return 0.0
		MovementStates.WALKING:
			return kd.baseline_speed
		MovementStates.RUNNING:
			return kd.baseline_speed * kd.running_2_baseline_ratio
		MovementStates.JUMPING:
			return kd.baseline_speed
		MovementStates.FALLING:
			return kd.v_x_peak_2_fall
		MovementStates.CROUCHING:
			return kd.crouching_speed
		MovementStates.WALL_SLIDING:
			return kd.baseline_speed
		#MovementStates.LEDGE_GRABBING:
			#return kd.baseline_speed
		MovementStates.CLIMBING:
			return kd.climb_speed
		MovementStates.CLOUD:
			return 2. * kd.baseline_speed
		MovementStates.LOG_ROLL:
			return kd.baseline_speed
		MovementStates.PORTAL:
			return 0.0
		_:
			return 0.0


func gravity_from_state() -> float:
	match movement_state:
		MovementStates.IDLE:
			return kd.jump_gravity
		MovementStates.WALKING:
			return  kd.jump_gravity
		MovementStates.RUNNING:
			return  kd.jump_gravity
		MovementStates.JUMPING:
			return kd.jump_gravity
		MovementStates.FALLING:
			return kd.fall_gravity
		MovementStates.CROUCHING:
			return kd.jump_gravity
		MovementStates.WALL_SLIDING:
			return kd.fall_gravity / 100.0
		MovementStates.LEDGE_GRABBING:
			return 0.0
		MovementStates.ITEM_MOVING:
			return kd.jump_gravity
		MovementStates.CLIMBING:
			return 0.0
		MovementStates.CLOUD:
			return 0.0
		MovementStates.LOG_ROLL:
			return 0.0
		MovementStates.PORTAL:
			return 0.0
		_:
			return 0.0

func entered_portal():
	velocity = Vector2.ZERO
	movement_state_transition_to( MovementStates.PORTAL )


func exited_portal():
	movement_state_transition_to( MovementStates.IDLE )


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
	#print((gravity_from_state() * gravity_modifier * hang_time_modifier))
	return (gravity_from_state() * gravity_modifier * hang_time_modifier)

var stash_push_gravity: float
func disable_gravity_modifier(b: bool):
	if b:
		stash_push_gravity = gravity_modifier
		gravity_modifier = 0.0
	else:
		gravity_modifier = stash_push_gravity


func can_parachute() -> bool:
	return (movement_state == MovementStates.FALLING or movement_state == MovementStates.JUMPING)


func can_pick_up_item():
	return $ItemManager.can_pick_up()


func take_pickup_item(spawn_id:int, item_lookup: ItemsDb.ItemNames):
	$ItemManager.pick_up(spawn_id, item_lookup)


func drop_pickup_item(item_slot_index=null, delete_now=false):
	$ItemManager.drop_item(item_slot_index, delete_now)


func host_confirmed_drop():
	$ItemManager.host_confirmed_item_deletion()


func can_collect_coints() -> bool:
	return movement_state != MovementStates.CLOUD


# -- this should be called from walking, running
func should_step_over():
	var stepping_left = last_move_input.x < 0
	var bottom_ray = $StepOverContainer/BottomLeft if stepping_left else $StepOverContainer/BottomRight
	
	# -- sloped surface check
	if bottom_ray.is_colliding():
		var normal = bottom_ray.get_collision_normal()
		if abs(normal.x) < 0.95:
			return false

	if stepping_left:
		return ($StepOverContainer/BottomLeft.is_colliding() and !$StepOverContainer/TopLeft.is_colliding())
	return ($StepOverContainer/BottomRight.is_colliding() and !$StepOverContainer/TopRight.is_colliding())

var step_over_starting_player_pos
var step_over_target_pos
var is_stepping_over: bool = false
var step_over_progress: float = 0
func step_over( delta: float ):
	#print(should_step_over()	)
	if !is_stepping_over and should_step_over():
		is_stepping_over = true
		$CollisionShape2D.set_deferred("disabled", true)
		step_over_starting_player_pos = global_position
		var stepping_left = last_move_input.x < 0
		var top_down_ray := $TopDownRayContainer/LHS if stepping_left else $TopDownRayContainer/RHS
		var step_ray := $StepOverContainer/BottomLeft if stepping_left else $StepOverContainer/BottomRight
		var step_over_position = Vector2( 
			step_ray.get_collision_point().x,
			top_down_ray.get_collision_point().y)
			# -- taget climb up should be the player just standing on the edge
		step_over_target_pos = (step_over_position +
			Vector2(sign(last_move_input.x) * $CollisionShape2D.shape.radius,
					-0.5 * $CollisionShape2D.shape.height))
	
	if is_stepping_over:
		g = 0
		velocity.y = 0
		step_over_progress += 5. * delta
		global_position = step_over_starting_player_pos.lerp(
			step_over_target_pos,
			step_over_progress * step_over_progress # -- x^2 easing
		)

	if step_over_progress >= 1.0:
		step_over_progress = 0.
		is_stepping_over = false
		$CollisionShape2D.set_deferred("disabled", false)


# ------------------------------------------------------------------------------
var throw_speed := 500.
#var grabbed_dynamic_object_ref: CharacterBody2D # --player state tracks grabbed_dynamic_object_ref

func apply_command( c: PlayerCommand):
	move_input = c.move_input
	update_visual_facing(move_input.x)
	
	if c.sword_swung:
		$TEMP_SWORD.swing_sword()
		return

	if (c.move_input.y < 0 and is_on_one_way_platform and  c.jump_pressed):
		set_collision_mask_value(9, false)
		return
	
	# -- 
	if c.grab_pressed:
		$GrabManager.on_grab_pressed()
	
	if c.jump_pressed:
		jump_buffer_timer.start()
		return
		
	if c.jump_released and movement_state == MovementStates.JUMPING:
		velocity.y *= 0.5
		movement_state_transition_to(MovementStates.FALLING)
		return
		
	if c.crouch_pressed:
		if movement_state == MovementStates.CROUCHING:
			go_2_capsule_shape()
			movement_state_transition_to(MovementStates.IDLE)
		else:
			go_2_circle_shape()
			movement_state_transition_to(MovementStates.CROUCHING)
		return

	# -- FIXME in local player controller
	# -- I'm accounting for this in dropped_pickup_item
	# -- this is cruft from the aiming visuals and needs to be corrected
	#func aiming_pos() -> Vector2:
	#	return (aiming_vector() + global_position)

	if c.item_dropped:
		var item_data = $ItemManager.get_current_item_data()
		if item_data[0] >= 0: # -- the item db enum
			# -- signal connected to world_pickup_items_manager:
			# -- on_player_dropped_pickup_item
			if is_multiplayer_authority():
				drop_pickup_item()
				dropped_pickup_item.emit( item_data[0], 
										  item_data[1],
										  [global_position,
										   Vector2.ZERO,
										   #max_pickup_item_throw_magnitude * 
										  #(c.aiming_input - global_position).normalized(), 
										   get_g()])

	# -- can_run, because there needs to be a cue from running out of stamina
	var _run_bool = c.sprint_held and can_run
	$StaminaVisual.use( _run_bool )
	#print(_run_bool)
	if _run_bool:
		if (movement_state == MovementStates.IDLE or
			movement_state == MovementStates.WALKING):
			movement_state_transition_to(MovementStates.RUNNING)
	else:
		# -- we were running and we just let off of run
		if movement_state == MovementStates.RUNNING:
			movement_state_transition_to(MovementStates.WALKING)


func update_visual_facing(horizontal_direction: float) -> void:
	if absf(horizontal_direction) < 0.01:
		return
	animation_controller.set_facing_direction(horizontal_direction)

# ------------------------------------------------------------------------------
# -- assumes this is only called in like walking or running (grounded state)
func going_uphill(_normal : Vector2) -> bool:
	# -- if we're going uphill, the x component of the normal vector
	# -- is pointing in the opposite dir as vel
	return not( going_downhill )


func going_downhill(_normal : Vector2) -> bool:
	return (velocity.x * _normal.x > 0) and (last_move_input.x * _normal.x > 0)


# ------------------------------------------------------------------------------

# -- NOTE we're kind of mandating that this is only one layer deep for Node2d
# --      children
func toggle_raycast2d(c: RayCast2D, is_enabled: bool):
	c.enabled = is_enabled
	if not is_enabled:
		c.clear_exceptions()

func set_container_raycasts_enabled(container: Node2D, is_enabled: bool) -> void:
	container.set_physics_process(is_enabled)
	for child in container.get_children():
		if child is RayCast2D:
			toggle_raycast2d( child, is_enabled)
		else:
			for nested_child in child:
				if child is RayCast2D:
					toggle_raycast2d( child, is_enabled)
		
