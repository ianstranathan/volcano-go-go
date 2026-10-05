extends Node2D

@onready var multimesh_instance: MultiMeshInstance2D = $MultiMeshInstance2D

var players_container_ref: Node2D
var players: Array[Player] = []

const CELL_SIZE: float = 256.0
const COLLECTION_RADIUS = 64.0
const COLLECTION_RADIUS_SQ = COLLECTION_RADIUS * COLLECTION_RADIUS
const step_dirs = [-1, 0, 1]

# The Grid: Vector2i(x, y) -> Array of gem indices
var grid: Dictionary = {}

# Flat arrays for fast lookup by index
var treasure_positions_list: Array[Vector2] = []
var treasure_active: Array[bool] = []
var treasure_types: Array[int] = [] 

enum TreasureStates{
	UNSPAWNED,
	FLYING,
	BOUNCING,
	LANDED,
	COLLECTED
}

var treasure_states: Array[TreasureStates] = []

# Track flying gems for custom arc animations
var flying_treasure: Array[Dictionary] = []


@export var total_treasure_types: int = 8

var rng = RandomNumberGenerator.new()

func _ready() -> void:
	if players_container_ref:
		players = players_container_ref.get_children().filter( func(c): if c is Player: return c)
	visible = true
	rng.randomize()
	setup_breakables()
	$MultiMeshInstance2D.material.set_shader_parameter("is_path", false)


func _physics_process(delta: float) -> void:
	var mat := multimesh_instance.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("current_time", Time.get_ticks_msec() / 1000.0)
		
		# -- TODO (also for path manager)
		var pos_array: Array[Vector2] = []
		if players:
			for p in players:
				if p: pos_array.append(p.global_position)
				else: pos_array.append(Vector2.ZERO)
		mat.set_shader_parameter("player_positions", pos_array)



func setup_breakables() -> void:
	var total_instances = 0
	for child in get_children():
		if child is TreasureSource:
			child.start_index = total_instances
			total_instances += child.treasure_count
			# -- closure around child for was_broken callback
			child.was_broken.connect(func(): 
				trigger_break(child))

	if total_instances == 0:
		return

	# Initialize MultiMesh capacity for ALL potential gems across all containers
	var mm: MultiMesh = multimesh_instance.multimesh
	mm.instance_count = 0
	mm.use_custom_data = true
	mm.instance_count = total_instances
	mm.visible_instance_count = total_instances
	
	treasure_positions_list.resize(total_instances)
	treasure_active.resize(total_instances)
	treasure_types.resize(total_instances)
	treasure_states.resize(total_instances)
	
	var zero_xform = Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO)
	
	for i in range(total_instances):
		treasure_active[i] = false
		treasure_states[i] = TreasureStates.UNSPAWNED
		mm.set_instance_transform_2d(i, zero_xform) # Hide them initially


func trigger_break(source: TreasureSource) -> void:
	var mm := multimesh_instance.multimesh
	var treasure_count := source.treasure_count

	var floor_left :Vector2 = source.LHS_intersection()
	var floor_right : Vector2= source.RHS_intersection()


	if floor_left == Vector2(INF, INF) or floor_right == Vector2(INF, INF):
		push_error("Treasure source has no valid floor intersections")
		return

	for i in range(treasure_count):
		var global_index := source.start_index + i

		if treasure_states[global_index] != TreasureStates.UNSPAWNED:
			continue

		var g_type := (
			source.treasure_types[i]
			if i < source.treasure_types.size()
			else rng.randi_range(0, total_treasure_types - 1)
		)

		treasure_types[global_index] = g_type
		treasure_active[global_index] = true
		treasure_states[global_index] = TreasureStates.FLYING

		var t_ratio := float(i) / float(max(1, treasure_count - 1))
		var jitter := sin(global_index * 12.9898) * 15.0

		var target_global_pos : Vector2 = (
			floor_left.lerp(floor_right, t_ratio)
			+ Vector2(jitter, 0)
		)

		treasure_positions_list[global_index] = target_global_pos

		var normalized_gem_id := (
			float(g_type) /
			float(max(1, total_treasure_types - 1))
		)

		var anim_offset := (
			float(global_index) /
			float(max(1, treasure_states.size()))
		)

		mm.set_instance_custom_data(
			global_index,
			Color(
				normalized_gem_id,
				anim_offset,
				0.0,
				0.0
			)
		)

	
		var duration = rng.randf_range(0.35, 0.55)
		flying_treasure.append({
			"index": global_index,
			"start_pos": source.global_position,
			"target_pos": target_global_pos + Vector2(0., -15.),

			"elapsed": 0.0,
			"duration": duration,

			"arc_height": rng.randf_range(50.0, 200.0),

			# Material property.
			"bounce_restitution": rng.randf_range(0.3, 0.5),

			"bounce_time": 0.0,
			"bounce_height": 0.0,
			"bounce_origin": target_global_pos,
			"horizontal_velocity": (
				(target_global_pos.x - source.global_position.x)
				/ duration
			),
			"horizontal_friction": 0.65,
		})


func update_flying_gems(delta: float) -> void:
	var finished_indices: Array[int] = []
	var mm := multimesh_instance.multimesh

	const GRAVITY := 1800.0
	const MIN_BOUNCE_HEIGHT := 2.0

	for i in range(flying_treasure.size()):
		var flight = flying_treasure[i]
		var index: int = flight["index"]

		var current_pos: Vector2

		# ============================================================
		# FLYING
		# ============================================================

		if treasure_states[index] == TreasureStates.FLYING:

			flight["elapsed"] += delta

			var t: float = clamp(
				flight["elapsed"] / flight["duration"],
				0.0,
				1.0
			)

			current_pos = flight["start_pos"].lerp(
				flight["target_pos"],
				t
			)

			# Initial launch parabola.
			var height_arc: float = (
				flight["arc_height"]
				* 4.0
				* t
				* (1.0 - t)
			)

			current_pos.y -= height_arc

			if t >= 1.0:
				treasure_states[index] = TreasureStates.BOUNCING

				flight["bounce_height"] = (
					flight["arc_height"]
					* flight["bounce_restitution"]
					* flight["bounce_restitution"]
				)

				flight["bounce_time"] = 0.0
				flight["bounce_origin"] = flight["target_pos"]

				current_pos = flight["target_pos"]

		# ============================================================
		# BOUNCING
		# ============================================================

		elif treasure_states[index] == TreasureStates.BOUNCING:
			var bounce_height: float = flight["bounce_height"]

			if bounce_height < MIN_BOUNCE_HEIGHT:
				current_pos = flight["bounce_origin"]

				finished_indices.append(i)

				landing_treasure(
					index,
					current_pos
				)

				continue

			flight["bounce_time"] += delta

			var bounce_time: float = flight["bounce_time"]

			var bounce_duration: float = (
				2.0 * sqrt(2.0 * bounce_height / GRAVITY)
			)

			var t: float = clamp(
				bounce_time / bounce_duration,
				0.0,
				1.0
			)

			# Vertical parabola.
			var bounce_offset: float = (
				bounce_height
				* 4.0
				* t
				* (1.0 - t)
			)

			# Horizontal movement from current bounce origin.
			var horizontal_velocity: float = flight["horizontal_velocity"]

			current_pos = flight["bounce_origin"]

			current_pos.x += horizontal_velocity * bounce_time
			current_pos.y -= bounce_offset

			if t >= 1.0:
				# We've reached the floor at the end of this bounce.
				flight["bounce_origin"] = current_pos

				# Lose horizontal momentum on impact.
				flight["horizontal_velocity"] *= (
					flight["horizontal_friction"]
				)

				# Lose vertical energy on impact.
				flight["bounce_height"] *= (
					flight["bounce_restitution"]
					* flight["bounce_restitution"]
				)

				flight["bounce_time"] = 0.0


		# ============================================================
		# WRITE TRANSFORM
		# ============================================================

		var local_pos := multimesh_instance.to_local(current_pos)

		var xform := Transform2D.IDENTITY
		xform.origin = local_pos

		mm.set_instance_transform_2d(
			index,
			xform
		)

	finished_indices.reverse()

	for idx in finished_indices:
		flying_treasure.remove_at(idx)


#func update_flying_gems(delta: float) -> void:
	#
	#var finished_indices: Array[int] = []
	#var mm := multimesh_instance.multimesh
#
	#for i in range(flying_treasure.size()):
		#var flight = flying_treasure[i]
#
		#flight["elapsed"] += delta
#
		#var t : float = clamp(
			#flight["elapsed"] / flight["duration"],
			#0.0,
			#1.0
		#)
#
		#var current_pos: Vector2 = flight["start_pos"].lerp(
			#flight["target_pos"],
			#t
		#)
		##var arc_height := 450.0 + fmod(abs(sin(i * 12.9898) * 43758.5453), 1.0) * 300.0
		#var height_arc : float = flight["arc_height"] * 4.0 * t * (1.0 - t)
		#current_pos.y -= height_arc
#
		## IMPORTANT:
		## MultiMeshInstance2D wants local coordinates.
		#var local_pos := multimesh_instance.to_local(current_pos)
#
		#var xform := Transform2D.IDENTITY
		#xform.origin = local_pos
#
		#mm.set_instance_transform_2d(
			#flight["index"],
			#xform
		#)
#
		#if t >= 1.0:
			#finished_indices.append(i)
#
			#landing_treasure(
				#flight["index"],
				#flight["target_pos"]
			#)
#
	#finished_indices.reverse()
#
	#for idx in finished_indices:
		#flying_treasure.remove_at(idx)
#
#
##func landing_treasure(index: int, final_pos: Vector2) -> void:
	##treasure_states[index] = TreasureStates.LANDED
	##treasure_positions_list[index] = final_pos
	##
	##register_treasure_to_grid(index, final_pos, treasure_types[index])
	##
	##var mm = multimesh_instance.multimesh
	##var xform = Transform2D.IDENTITY
	##xform.origin = final_pos
	##mm.set_instance_transform_2d(index, xform)
func landing_treasure(index: int, final_pos: Vector2) -> void:
	treasure_states[index] = TreasureStates.LANDED
	treasure_positions_list[index] = final_pos

	register_treasure_to_grid(
		index,
		final_pos,
		treasure_types[index]
	)

	var mm := multimesh_instance.multimesh

	var xform := Transform2D.IDENTITY
	xform.origin = multimesh_instance.to_local(final_pos)

	mm.set_instance_transform_2d(index, xform)


func register_treasure_to_grid(index: int, pos: Vector2, g_type: int) -> void:
	var cell = get_grid_cell(pos)
	if not grid.has(cell):
		grid[cell] = []
	grid[cell].append(index)


func get_grid_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floor(pos.x / CELL_SIZE), floor(pos.y / CELL_SIZE))

var collected_players = false
func execute_tick(delta: float) -> void:
	if !collected_players:
		collected_players = true
		for p in players_container_ref.get_children():
			players.append(p)

	if not flying_treasure.is_empty():
		update_flying_gems(delta)

	for player in players:
		var p_pos: Vector2 = player.global_position
		var p_cell: Vector2i = get_grid_cell(p_pos)
		
		for x_offset in step_dirs:
			for y_offset in step_dirs:
				var target_cell = p_cell + Vector2i(x_offset, y_offset)
				if not grid.has(target_cell):
					continue

				var cell_coins: Array = grid[target_cell]
				# Sliced backwards loop to safely inspect/remove elements during iteration
				for i in range(cell_coins.size() - 1, -1, -1):
					var treasure_index = cell_coins[i]
					if treasure_states[treasure_index] != TreasureStates.LANDED: 
						continue
						
					var coin_pos: Vector2 = treasure_positions_list[treasure_index]
					
					if p_pos.distance_squared_to(coin_pos) < COLLECTION_RADIUS_SQ:
						var coll_shape = player.get_node_or_null("CollisionShape2D")
						if coll_shape and MyMathUtils.is_circle_overlapping_capsule(
								coin_pos, COLLECTION_RADIUS, p_pos, 
								coll_shape.shape.height, coll_shape.shape.radius
							):
							
							# --- O(1) SWAP-AND-POP REMOVAL ---
							var last_index = cell_coins.size() - 1
							if i != last_index:
								cell_coins[i] = cell_coins[last_index]
							cell_coins.pop_back()
							# ---------------------------------
							
							collect_treasure(treasure_index, player.name.to_int())


@onready var zero_transform = Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO)

func collect_treasure(index: int, collector_id: int):
	if treasure_states[index] != TreasureStates.LANDED:
		return
	treasure_states[index] = TreasureStates.COLLECTED
	treasure_active[index] = false
	
	var player_array_index = 0
	for i in range(players.size()):
		if players[i] and players[i].name.to_int() == collector_id:
			player_array_index = i
			break
			
	var mm = multimesh_instance.multimesh
	var current_custom = mm.get_instance_custom_data(index)
	current_custom.b = Time.get_ticks_msec() / 1000.0
	current_custom.a = float(player_array_index) / 3.0 
	mm.set_instance_custom_data(index, current_custom)

	get_tree().create_timer(0.45).timeout.connect(func():
		$NumberPool.spawn_number(treasure_types[index], players[player_array_index].global_position)
		mm.set_instance_transform_2d(index, zero_transform)
	)
