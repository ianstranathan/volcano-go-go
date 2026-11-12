extends Line2D

@export_category("Scarf Physics")
@export var particle_count: int = 20
@export var segment_length: float = 10.0
@export var gravity: Vector2 = Vector2(0, 900.0)
@export var wind: Vector2 = Vector2(80.0, -30.0)
@export var damping: float = 0.94
@export var solver_iterations: int = 5
@export var rest_force_strength: float = 8.0

@export_category("Player Tethering")
#@export var player_path: NodePath
@export var velocity_influence: float = 0.2
@export var acceleration_influence: float = 0.08

var particles: Array[Vector2] = []
var old_particles: Array[Vector2] = []
var rest_offsets: Array[Vector2] = []

@export var target_anchor: Marker2D
var last_anchor_pos: Vector2 = Vector2.ZERO
var player_velocity: Vector2 = Vector2.ZERO
var player_acceleration: Vector2 = Vector2.ZERO

const FIXED_DELTA: float = 1.0 / 60.0
var time_accumulator: float = 0.0

func _ready() -> void:
	#if not player_path.is_empty():
		#target_anchor = get_node_or_null(player_path)
	
	if target_anchor:
		last_anchor_pos = target_anchor.global_position

	_initialize_particles()
	
	# Configure Line2D properties for smooth visual rendering
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND

func _initialize_particles() -> void:
	particles.clear()
	old_particles.clear()
	rest_offsets.clear()
	
	var start_pos = global_position
	if target_anchor:
		start_pos = target_anchor.global_position

	for i in range(particle_count):
		var p_pos = start_pos + Vector2(-i * segment_length, 0)
		particles.append(p_pos)
		old_particles.append(p_pos)
		rest_offsets.append(Vector2(-i * segment_length, sin(i * 0.3) * 5.0))

	points = PackedVector2Array(particles)

func _physics_process(delta: float) -> void:
	if not target_anchor:
		return

	# Track player kinematics for secondary motion feedback
	var current_anchor_pos = target_anchor.global_position
	var frame_velocity = (current_anchor_pos - last_anchor_pos) / max(delta, 0.001)
	player_acceleration = (frame_velocity - player_velocity) / max(delta, 0.001)
	player_velocity = frame_velocity
	last_anchor_pos = current_anchor_pos

	# Fixed timestep accumulator for simulation stability
	time_accumulator += delta
	while time_accumulator >= FIXED_DELTA:
		_simulate_verlet(FIXED_DELTA)
		time_accumulator -= FIXED_DELTA

	# Sync particle positions to Line2D points (convert to local space)
	for i in range(particle_count):
		set_point_position(i, to_local(particles[i]))

func _simulate_verlet(dt: float) -> void:
	# 1. Anchor the first particle firmly to the player
	particles[0] = target_anchor.global_position
	old_particles[0] = target_anchor.global_position

	# 2. Integrate physics for free particles
	for i in range(1, particle_count):
		var velocity = (particles[i] - old_particles[i]) * damping
		old_particles[i] = particles[i]
		
		# External forces: Gravity, Wind, and Player kinematic reactions
		var external_force = gravity + wind
		
		# Apply directional lag/momentum based on player acceleration & velocity
		var kinematic_reaction = (-player_velocity * velocity_influence) + (-player_acceleration * acceleration_influence)
		external_force += kinematic_reaction * (float(i) / float(particle_count)) # More effect further down the tail
		
		# Weak rest-pose force to maintain a natural silhouette
		var target_rest_pos = target_anchor.global_position + rest_offsets[i]
		var rest_force = (target_rest_pos - particles[i]) * rest_force_strength
		
		particles[i] += velocity + (external_force + rest_force) * (dt * dt)

	# 3. Solve distance constraints (multiple iterations for stiffness)
	for iteration in range(solver_iterations):
		for i in range(particle_count - 1):
			var p1 = particles[i]
			var p2 = particles[i + 1]
			var delta_pos = p2 - p1
			var current_distance = delta_pos.length()
			
			if current_distance < 0.0001:
				continue
				
			var error = (current_distance - segment_length) / current_distance
			var correction = delta_pos * 0.5 * error
			
			if i == 0:
				# Pin the head strictly to the player anchor
				particles[i + 1] -= correction * 2.0
			else:
				particles[i] += correction
				particles[i + 1] -= correction
