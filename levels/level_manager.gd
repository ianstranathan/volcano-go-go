extends Node2D
class_name LevelManager


"""
This is just a thing that
keeps a running treadmill (bookends on either side of a calculated player position
domain, i.e. where the players are, we wanna have some level above and below to give
the illusion of a continuous space) 
uses a LevelChunk class
(where a level chunk class knows how big it is)
"""

# -- TODO rename this to first level ready or something
signal level_ready(spawn_points )

var LEVEL_CHUNK_DB: Dictionary # -- at initialization, this 
const BUFFER_CHUNKS: int = 1 

# --TODO
# --there are a few places where the ultimate size of the playspace
# -- is needed, so this has gotta move somewhere accessible by those thigns
const LEVEL_TOP_Y: float = -10000.0 

var chunks_to_tick: Array
var instantiated_chunks: Dictionary = {} # index -> Node instance
var chunk_idx_is_loading: Dictionary = {}
var chunk_positions: Dictionary = {}     # index -> Vector2(top_y, bottom_y)

var next_spawn_y: float = LEVEL_TOP_Y

@onready var chunk_container: Node2D = $ChunkContainer
@export var lava_ref: Node2D 
@export var player_container_ref: Node2D

var current_chunk_idx: int = 0

var moving_platform_network_id = 0

var cam_ref: Camera2D # -- for parallaxing, to give to children chunks
# ------------------------------------------------------------------------------
func _ready() -> void:
	_load_level_chunks_globally()
	

func _load_level_chunks_globally() -> void:
	var path = "res://levels/level_data_rscs/"
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var index = 0
		
		while file_name != "":
			# Ignore folders and ensure it's a resource file
			# Note: Godot exports convert .tres to .remap or .res, so we check for extensions starting with .tre or .re
			if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".res") or file_name.ends_with(".tres.remap")):
				# Clean the file name if it has an export suffix (.remap)
				var clean_name = file_name.replace(".remap", "")
				var full_path = path + clean_name
				
				var resource = load(full_path)
				if resource is LevelChunkData:
					assert(resource.level_index >= 0)
					LEVEL_CHUNK_DB[resource.level_index] = resource
					print("Loaded chunk index ", index, ": ", clean_name)
					index += 1

			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("An error occurred when trying to access the path: ", path)


func execute_tick(_delta: float) -> void:
	# -- if there's a chunk waiting to load from another thread, load it
	_poll_threaded_loads()
	
	for c in chunks_to_tick:
		if is_instance_valid( c ):
			c.execute_tick( _delta )
	# -- we don't need to check chunk math every frame
	# -- this is just low hanging optimization / heuristic, idk what's best
	if NetManager.current_tick % 10 == 0:
		if player_container_ref.get_child_count() == 0:
			return
			
		var lava_y: float = lava_ref.lava_fn(0)
		var required_range := _calculate_required_chunk_range(lava_y)
		
		_maintain_chunks(required_range, lava_y)


func _calculate_required_chunk_range(lava_y: float) -> Vector2i:
	var min_y: float = INF  
	var max_y: float = -INF 
	
	for player in player_container_ref.get_children():
		var pos_y = player.global_position.y
		if pos_y < min_y: min_y = pos_y
		if pos_y > max_y: max_y = pos_y
	
	if max_y > lava_y:
		max_y = lava_y
		
	var target_min_idx: int = 0
	var target_max_idx: int = current_chunk_idx # Default fallback
	
	# -- which chunk indices contain the players
	for idx in chunk_positions:
		var bounds = chunk_positions[idx]
		if min_y >= bounds.x and min_y <= bounds.y:
			target_min_idx = idx
		if max_y >= bounds.x and max_y <= bounds.y:
			target_max_idx = idx

	# -- the furthest chunk reached by the lead player
	if target_max_idx > current_chunk_idx:
		current_chunk_idx = target_max_idx
		# -- do stuff maybe if the chunk increments
		#_on_current_chunk_changed(current_chunk_idx)

	# Calculate ranges based on the BUFFER_CHUNKS around our targets
	var min_chunk_idx: int = target_min_idx - BUFFER_CHUNKS
	var max_chunk_idx: int = target_max_idx + BUFFER_CHUNKS
	
	return Vector2i(
		clamp(min_chunk_idx, 0, LEVEL_CHUNK_DB.size() - 1),
		clamp(max_chunk_idx, 0, LEVEL_CHUNK_DB.size() - 1)
	)


#func _on_current_chunk_changed(new_index: int) -> void:
	#print("Players have progressed to Chunk: ", new_index)

# -- take this out
func setup_networked_level_player_connections(p: Player):
	pass

var active_chunk_idxs: Array
func _maintain_chunks(required_range: Vector2i, lava_y: float) -> void:
	for idx in range(required_range.x, required_range.y + 1):
		# -- we're mapping the positions to a floored / grid which
		# -- is what required_range is
		# -- so if the instantiated_chunks doesn't have these chunk idx / ids
		# -- load it on another thread
		if not instantiated_chunks.has(idx) and not chunk_idx_is_loading.has(idx):
			_request_chunk_load(idx)


	for idx in active_chunk_idxs:
		var chunk_bounds = chunk_positions[idx]
		
		# -- get rid of this stuff if it's completely subsumed by lava
		if lava_y < chunk_bounds.x or idx < required_range.x or idx > required_range.y:
			_unload_and_clear_chunk(idx)


func _request_chunk_load(idx: int) -> void:
	if not LEVEL_CHUNK_DB.has(idx): 
		return
	# -- load the packedscene on another thread
	# -- from docs, load_threaded_request return type is of type Error 
	# -- which is an enum, so OK
	var chunk_data = LEVEL_CHUNK_DB[idx] as LevelChunkData
	if ResourceLoader.load_threaded_request(chunk_data.chunk_scene_path, "PackedScene", false, 1) == OK:
		chunk_idx_is_loading[idx] = true
	#if ResourceLoader.load_threaded_request(LEVEL_CHUNK_DB[idx], "PackedScene", false, 1) == OK:
		#chunk_idx_is_loading[idx] = true

func _poll_threaded_loads() -> void:
	var active_loading_chunk_indices = chunk_idx_is_loading.keys()
	for idx in active_loading_chunk_indices:
		var chunk_data = LEVEL_CHUNK_DB[idx] as LevelChunkData
		var scene_path = chunk_data.chunk_scene_path
		
		# Edge case safety guard
		if scene_path.is_empty():
			push_error("Chunk Data at index ", idx, " has an empty chunk_scene_path! Re-bake your level.")
			chunk_idx_is_loading.erase(idx)
			continue

		var status = ResourceLoader.load_threaded_get_status(scene_path)

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed_scene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
			
			if packed_scene == null:
				push_error("Thread loaded successfully but PackedScene returned null for path: ", scene_path)
			else:
				_instantiate_chunk(idx, packed_scene)
				
			chunk_idx_is_loading.erase(idx)
			break
			
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Failed to thread-load chunk at index: ", idx, " Path: ", scene_path)
			chunk_idx_is_loading.erase(idx)
			break


var moving_platform_components_dict : Dictionary = {}

func _instantiate_chunk(idx: int, packed_scene: PackedScene) -> void:
	var chunk_instance = packed_scene.instantiate() as LevelChunk
	
	chunk_instance.players_container_ref = player_container_ref
	
	# -- the chunk's callback takes care of whatever (like tagging the object)
	# -- we just need to increment the global network id
	chunk_instance.moveable_platform_made.connect( func(c: MovingPlatformComponent):
		moving_platform_components_dict[moving_platform_network_id] = c
		c.network_id = moving_platform_network_id
		moving_platform_network_id += 1)
	
	chunk_instance.cam_ref = cam_ref
	
	# -- so, next_spawn_y starts at top of volcano and steps down by chunk height
	chunk_instance.global_position = Vector2(0, 
		next_spawn_y - chunk_instance.level_data.offset_to_chunk_origin)
	chunk_container.add_child(chunk_instance)
	
	var height = chunk_instance.level_data.level_height
	# -- what are the bounds for this chunk [next_spawn_y, next_spawn_y + however tall
	# -- this chunk is, but we're inverting the y, cause godot
	chunk_positions[idx] = Vector2(next_spawn_y, next_spawn_y - height)
	# -- increment
	next_spawn_y += height
	
	instantiated_chunks[idx] = chunk_instance
	# -- we're getting the indices / keys on this dict so we don't have
	# -- to needlessly burn cycles in _maintain_chunks
	active_chunk_idxs = instantiated_chunks.keys()
	chunks_to_tick = chunk_container.get_children()
	#print("Chunk root: ", chunk_instance.global_position.y)
	#print("Top marker: ", chunk_instance.top_marker.global_position.y)
	#print("Bottom marker: ", chunk_instance.bottom_marker.global_position.y)
	#print("Height: ", chunk_instance.bottom_marker.global_position.y - chunk_instance.top_marker.global_position.y)
	#print("LevelManager:", global_position)
	#print("ChunkContainer:", chunk_container.global_position)
	#print("Chunk:", chunk_instance.global_position)
	#print("Chunk local:", chunk_instance.position)

func _unload_and_clear_chunk(idx: int) -> void:
	var chunk = instantiated_chunks.get(idx)
	if is_instance_valid(chunk):
		chunk.process_mode = PROCESS_MODE_DISABLED
		chunk.visible = false 
		chunk.queue_free()
		
	instantiated_chunks.erase(idx)
	chunk_idx_is_loading.erase(idx) # Clears it out regardless of whether it was active or loading
	chunks_to_tick = chunk_container.get_children()


func start_level() -> void:
	instantiated_chunks.clear()
	
	# -- no thread-load chunk 0 because the game can't start without it
	var chunk_data = LEVEL_CHUNK_DB[0] as LevelChunkData
	var first_chunk_scene = load(chunk_data.chunk_scene_path) as PackedScene
	_instantiate_chunk(0, first_chunk_scene)
	
	var markers = instantiated_chunks[0].get_node_or_null("SpawnPoints").get_children()
	if markers:
		var marker_positions = markers.map( func(m: Marker2D):
			return m.global_position)
		level_ready.emit(marker_positions)

	$ParallaxinglayersManager.visible = true
	# -- start loading chunk 1 in the background
	_request_chunk_load(1)


# -- NOTE
# -- we're kind of repeating ourselves (do the same treadmill height increments)
# -- but I don't see how else to do this in advance at runtime
# -- (we're doing the same incr math as in _instantiate_chunk)


# -- TODO
# consolidate logic for
# ------ get_all_dynamic_object_definitions
# ------ get_all_pickup_item_definitions
# -- they're basically the same thing keep it DRY
func get_all_pickup_item_definitions() -> Array[ Dictionary ]:
	var ret : Array[ Dictionary] = []
	var _local_next_spawn_y = LEVEL_TOP_Y

	assert(!LEVEL_CHUNK_DB.is_empty())
	
	# -- since we're filling our LEVEL_CHUNK_DB
	# -- automatically from a folder, the layout can vary (dir fns do things
	# -- alphabetically, so we need to gaurentee that we're doing things
	# -- sequentially (i.e. 0, 1, 2, ... , N)
	var sorted_indices = LEVEL_CHUNK_DB.keys()
	sorted_indices.sort()
	
	for chunk_index in sorted_indices:
		var level_chunk_data = LEVEL_CHUNK_DB[chunk_index]
		
		if (level_chunk_data.pickup_definitions is Array and 
			!level_chunk_data.pickup_definitions.is_empty()):
			var _chunk_global_position = Vector2(0, 
					_local_next_spawn_y - level_chunk_data.offset_to_chunk_origin)
			
			for pickup_definition in level_chunk_data.pickup_definitions:
				var p = {"global_position": 
						 _chunk_global_position + pickup_definition["position"],
						 "item_enum": pickup_definition["item_enum"]}
				ret.append(p)
				
		_local_next_spawn_y += level_chunk_data.level_height
		
	return ret


func get_all_dynamic_object_definitions() -> Array[ Dictionary ]:
	var ret : Array[ Dictionary] = []
	var _local_next_spawn_y = LEVEL_TOP_Y

	assert(!LEVEL_CHUNK_DB.is_empty())
	
	# -- since we're filling our LEVEL_CHUNK_DB
	# -- automatically from a folder, the layout can vary (dir fns do things
	# -- alphabetically, so we need to gaurentee that we're doing things
	# -- sequentially (i.e. 0, 1, 2, ... , N)
	var sorted_indices = LEVEL_CHUNK_DB.keys()
	sorted_indices.sort()
	
	for chunk_index in sorted_indices:
		var level_chunk_data = LEVEL_CHUNK_DB[chunk_index]
		
		if (level_chunk_data.dynamic_object_definitions is Array and 
			!level_chunk_data.dynamic_object_definitions.is_empty()):
			var _chunk_global_position = Vector2(0, 
					_local_next_spawn_y - level_chunk_data.offset_to_chunk_origin)
			
		
			for dynamic_object_def in level_chunk_data.dynamic_object_definitions:
				var p = {"global_position": 
						 _chunk_global_position + dynamic_object_def["position"],
						 "dynamic_object_type": dynamic_object_def["dynamic_object_type"]}
				ret.append(p)
				
		_local_next_spawn_y += level_chunk_data.level_height
		
	return ret


func get_level_bottom_y() -> float:
	var y := LEVEL_TOP_Y
	var indices = LEVEL_CHUNK_DB.keys()
	indices.sort()

	for idx in indices:
		var data := LEVEL_CHUNK_DB[idx] as LevelChunkData
		y += data.level_height

	return y
