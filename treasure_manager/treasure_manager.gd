extends Node2D

@onready var multimesh_instance: MultiMeshInstance2D = $MultiMeshInstance2D

# NOTE
var players_container_ref: Node2D
var players : Array[Player]

const step_dirs = [-1, 0, 1]

# Configuration
const CELL_SIZE: float = 256.0 # Grid cell size in pixels
const COLLECTION_RADIUS = 64.0
const COLLECTION_RADIUS_SQ = COLLECTION_RADIUS * COLLECTION_RADIUS

# The Grid: Vector2i(x, y) -> Array of coin indices
var grid: Dictionary = {}

# Flat arrays for fast lookup by index
var coins_list: Array[Vector2] = [] 
var coins_active: Array[bool] = []
var coin_types: Array[int] = [] # Tracks which type of gem (0 to 7) each index is

# Multiple paths support

@onready var treasure_paths: Array = get_children().filter( func(c): if c is Path2D: return c)

# Randomized spacing configuration
@export var base_spacing: float = 80.0 # Average distance between each coin
@export var spacing_variance: float = 20.0 # Max random offset (+ or -) added to base spacing


@export var total_gem_types: int = 8

var rng = RandomNumberGenerator.new()

func _ready() -> void:
	visible = true
	assert(not treasure_paths.is_empty(), "At least one Path2D must be assigned as a child of the treasure manager")
	rng.randomize()
	generate_treasure_along_paths()

func _process(_delta: float) -> void:
	var mat := multimesh_instance.material as ShaderMaterial
	if not mat:
		return
		
	mat.set_shader_parameter("current_time", Time.get_ticks_msec() / 1000.0)
	
	# Gather all player global positions into an array for the shader uniform
	var pos_array: Array[Vector2] = []
	if players:
		for p in players:
			if p:
				pos_array.append(p.global_position)
			else:
				pos_array.append(Vector2.ZERO)
				
	mat.set_shader_parameter("player_positions", pos_array)
#func _process(delta: float) -> void:
	#var mat := multimesh_instance.material as ShaderMaterial
	#if not mat:
		#return
		#
	## Pass time forward for the idle floating animation
	#mat.set_shader_parameter("current_time", Time.get_ticks_msec() / 1000.0)
	#
	## Pass the target player's position so the GPU knows where to vacuum gems
	#if players and not players.is_empty() and players[0]:
		#mat.set_shader_parameter("player_global_position", players[0].global_position)
		

func register_coin_to_grid(index: int, pos: Vector2, g_type: int):
	coins_list.append(pos)
	coins_active.append(true)
	coin_types.append(g_type)
	
	var cell = get_grid_cell(pos)
	
	if not grid.has(cell):
		grid[cell] = []
	
	grid[cell].append(index)

# -----------------------------------------------------------------------------

func get_grid_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floor(pos.x / CELL_SIZE),
					floor(pos.y / CELL_SIZE))

var player_collision_shape : CollisionShape2D
var collected_players: bool = false

func execute_tick(_delta: float) -> void:
	if !collected_players:
		collected_players = true
		for p in players_container_ref.get_children():
			players.append(p)
	
	if players and !players.is_empty():
		for player in players:
			var p_pos: Vector2 = player.global_position
			var p_cell: Vector2i = get_grid_cell(p_pos)
			
			# Check the player's cell and the 8 surrounding 2D cells
			for x_offset in step_dirs:
				for y_offset in step_dirs:
					var target_cell = p_cell + Vector2i(x_offset, y_offset)

					if not grid.has(target_cell):
						continue
					
					# Loop through only the coins in this specific cell
					for coin_index in grid[target_cell]:
						if not coins_active[coin_index]:
							continue
							
						var coin_pos: Vector2 = coins_list[coin_index]
						
						if p_pos.distance_squared_to(coin_pos) < COLLECTION_RADIUS_SQ:
							var coll_shape = player.get_node("CollisionShape2D")
							if MyMathUtils.is_circle_overlapping_capsule(
									coin_pos,
									COLLECTION_RADIUS,
									p_pos, 
									coll_shape.shape.height, 
									coll_shape.shape.radius
								):
								on_player_walked_over_coin(coin_index, player.name.to_int())


func on_player_walked_over_coin(index: int, collector_id: int) -> void:
	# You can access coin_types[index] here to know exactly which gem was picked up!
	# Example: MetaProgressionManager.award_gem(collector_id, coin_types[index])
	collect_treasure(index, collector_id)


@onready var zero_transform = Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO)
#func collect_treasure(index: int, collector_id: int):
	#if not coins_active[index]:
		#return
	#coins_active[index] = false
	#multimesh_instance.multimesh.set_instance_transform_2d(index, zero_transform)

#func collect_treasure(index: int, collector_id: int):
	#if not coins_active[index]:
		#return
	#coins_active[index] = false
	#
	#var mm = multimesh_instance.multimesh
	#var current_custom = mm.get_instance_custom_data(index)
	#
	## Set the blue channel to the current engine time (in seconds)
	## This acts as the "ignition switch" for the vertex shader's flight math
	#current_custom.b = Time.get_ticks_msec() / 1000.0
	#mm.set_instance_custom_data(index, current_custom)
	#
	## Optional: Schedule full removal/cleanup from the grid dictionary 
	## after the 0.4s animation finishes, without burning per-frame CPU cycles.
	#get_tree().create_timer(0.45).timeout.connect(func():
		#mm.set_instance_transform_2d(index, zero_transform)
		## Award inventory/score here
	#)
func collect_treasure(index: int, collector_id: int):
	if not coins_active[index]:
		return
	coins_active[index] = false
	
	# Find index of the player in our `players` array
	var player_array_index = 0
	for i in range(players.size()):
		if players[i] and players[i].name.to_int() == collector_id:
			player_array_index = i
			break
			
	var mm = multimesh_instance.multimesh
	var current_custom = mm.get_instance_custom_data(index)
	
	current_custom.b = Time.get_ticks_msec() / 1000.0
	# Normalize player array index to 0.0 - 1.0 range for the alpha channel
	current_custom.a = float(player_array_index) / 3.0 
	
	mm.set_instance_custom_data(index, current_custom)

	get_tree().create_timer(0.45).timeout.connect(func():
		$NumberPool.spawn_number(coin_types[index], players[player_array_index].global_position)
		mm.set_instance_transform_2d(index, zero_transform)
	)
# ------------------------------------------------------------------------------
var total_treasure_data: Array = [] # Stores dictionaries of {pos: Vector2, type: int}

func generate_treasure_along_paths() -> void:
	# -- path data
	for path in treasure_paths:
		if not path or not path.curve:
			continue
			
		var curve: Curve2D = path.curve
		var path_length: float = curve.get_baked_length()
		var current_distance: float = 0.0
		
		while current_distance < path_length:
			var current_spacing = base_spacing + rng.randf_range(-spacing_variance, spacing_variance)
			current_spacing = max(current_spacing, 10.0) 
			
			current_distance += current_spacing
			if current_distance >= path_length:
				break
				
			var coin_position: Vector2 = curve.sample_baked(current_distance)
			var assigned_type: int = rng.randi() % total_gem_types
			
			
			total_treasure_data.append({
				"pos": coin_position,
				"type": assigned_type
			})
	
	var total_coins: int = total_treasure_data.size()
	if total_coins == 0:
		return
	print(total_coins)
	# -- initialize the MultiMesh capacity globally
	var mm: MultiMesh = multimesh_instance.multimesh
	mm.instance_count = 0
	mm.use_custom_data = true
	mm.instance_count = total_coins
	mm.visible_instance_count = total_coins
	
	# -- populate transforms, custom shader data, and register to the spatial grid
	for i in range(total_coins):
		var data = total_treasure_data[i]
		var coin_position: Vector2 = data["pos"]
		var gem_type: int = data["type"]
		
		var xform: Transform2D = Transform2D.IDENTITY
		xform = xform.translated(coin_position)
		
		mm.set_instance_transform_2d(i, xform)
		register_coin_to_grid(i, xform.origin + global_position, gem_type)
		
		# Pack data into custom Color channel:
		# R channel = Normalized gem type (0.0 to 1.0) so the shader can unpack it
		# G channel = Animation offset gradient along the total run
		var normalized_gem_id: float = float(gem_type) / float(max(1, total_gem_types - 1))
		var anim_offset: float = float(i) / float(total_coins)
		
		var custom_data = Color(normalized_gem_id, anim_offset, 0.0, 0.0)
		mm.set_instance_custom_data(i, custom_data)
