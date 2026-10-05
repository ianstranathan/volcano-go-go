@tool
extends Node2D

class_name LevelChunk

signal moveable_platform_made( c: MovingPlatformComponent, fn: Callable )

@onready var players_container_ref: Node2D
@export var treasure_path_manager: Node2D
@export var treasure_src_manager: Node2D
@export var tickable_geometry_container: Node2D
@export var parallax_manager:Node2D
var tickable_geometry: Array

# -- NOTE DELETE ME FIX BUG
@export var enemy_container: Node2D
@onready var enemy_container_children = enemy_container.get_children()

var cam_ref: Camera2D # -- from: game -> level manager -> chunkinstance


func execute_tick( delta: float ):
	if !tickable_geometry.is_empty():
		for c in tickable_geometry:
			c.execute_tick( delta )
	if enemy_container and enemy_container_children.size() > 0:
		for c in enemy_container_children:
			c.execute_tick( delta )
	if treasure_path_manager:
		treasure_path_manager.execute_tick( delta )
	if treasure_src_manager:
		treasure_src_manager.execute_tick( delta )
	
	if parallax_manager:
		parallax_manager.cam_ref = cam_ref

@export var bottom_marker: Marker2D
@export var top_marker: Marker2D
@export var left_marker: Marker2D
@export var right_marker: Marker2D
@export var level_data: LevelChunkData

var has_started_cloud_list: Array[Player]

#var moving_platform_network_id_tag_fn = func( id:int, c: MovingPlatformComponent): 
	#c.network_id = id

func _ready() -> void:
	
	if !Engine.is_editor_hint():
		assert(players_container_ref)
		
		if tickable_geometry_container:
			tickable_geometry = tickable_geometry_container.get_children()
			
			#var moveable_plats = tickable_geometry.filter( func(c: Node2D):
				#return c is MovingPlatformPlaceholder)
			#for 
			for c in tickable_geometry:
				if c is MovingPlatformPlaceholder:
					#assert(c.moving_platform_component )
					#print("Here's the component: ", c.moving_platform_component )
					moveable_platform_made.emit( c.moving_platform_component )
		#var cm =  get_node_or_null("CoinManager")
		if treasure_path_manager:
			treasure_path_manager.players_container_ref = players_container_ref
		if treasure_src_manager:
			treasure_src_manager.players_container_ref = players_container_ref
		# -- TODO
		# -- MOVE THIS
		var cloud_start_area = get_node_or_null("CloudStart")
		if cloud_start_area:
			cloud_start_area.body_entered.connect( func(b):
				if b is Player and b not in has_started_cloud_list:
					has_started_cloud_list.append( b )
					b.start_cloud_descent())


# -- built-in Godot function; it triggers automatically scene is saved
# -- so, workflow is, set the markers and save
func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		bake_level_data()
	if Engine.is_editor_hint() and minimap_geometry_container and minimap_geometry_container.get_children().size() == 0:
		_generate_minimap()


func bake_level_data() -> void:
	if level_data and top_marker and bottom_marker:
		# -- path name for a packed scene
		level_data.chunk_scene_path = scene_file_path
		
		# -- level dimensions
		# -- we're enforcing that scenes are in model space => abs calc is redundant
		var height = bottom_marker.global_position.y - top_marker.global_position.y
		level_data.level_height = height
		var width = right_marker.global_position.x - left_marker.global_position.x
		level_data.level_width = width
		
		# -- spawn pts
		var spawn_points_node = get_node_or_null("SpawnPoints")
		if spawn_points_node:
			level_data.player_spawn_points = spawn_points_node.get_children().map( func(c): return c.global_position)
		
		level_data.offset_to_chunk_origin = top_marker.position.y
		
		# -- pickup items:
		var found_pickups: Array[Dictionary] = []
		var placeholder_container = get_node_or_null("PickupPlaceholders")
		if placeholder_container:
			for child in placeholder_container.get_children():
				if child is PickupEditorPlaceholder:
					found_pickups.append({
						"item_enum": child.item_enum_type,
						"position": child.position # Using local pos so it easily stacks in world coords
					})
		level_data.pickup_definitions = found_pickups
		
		
		# -- dyanmic items (e.g. rocks you can grab and throw)
		var found_dynamic_objects: Array[Dictionary] = []
		var dynamic_object_placeholders_container = get_node_or_null("DynamicObjectPlaceholders")
		if dynamic_object_placeholders_container:
			for child in dynamic_object_placeholders_container.get_children():
				if child is DynamicObjectPlaceholder:
					found_dynamic_objects.append({
						"dynamic_object_type": child.dynamic_object_type,
						"position": child.position # Using local pos so it easily stacks in world coords
					})
		level_data.dynamic_object_definitions = found_dynamic_objects


		# -- from docs:
		#level_data.emit_changed()
		#var save_path = "res://levels/level_data_rscs/" + name.to_snake_case() + "_data.tres"
		#ResourceSaver.save(level_data)
		#print("Baked level height, width and spawn points")
		var save_path = "res://levels/level_data_rscs/" + name.to_snake_case() + "_data.tres"
		var error = ResourceSaver.save(level_data, save_path)

		if error == OK:
			print("Successfully baked and saved to: ", save_path)
		else:
			push_error("Failed to save resource! Error code: ", error)


@export var platforms_root: Node2D
@export var minimap_geometry_container: Node2D

func _generate_minimap() -> void:
	if not platforms_root or not minimap_geometry_container:
		push_warning("Platforms Root or Minimap Container is not assigned")
		return
		
	for child in minimap_geometry_container.get_children():
		child.free()
		
	_recurse_platforms(platforms_root)
	print("Minimap geometry successfully generated")
	

func _recurse_platforms(current_node: Node) -> void:
	# -- actually make the polygon
	if current_node is CollisionPolygon2D:
		var minimap_poly = Polygon2D.new()
		minimap_poly.polygon = current_node.polygon
		minimap_poly.color = Color.WHITE
		
		minimap_geometry_container.add_child(minimap_poly)
		minimap_poly.set_visibility_layer_bit(0, false)
		minimap_poly.set_visibility_layer_bit(1, true)
		# -- // I did not know this
		# CRITICAL FOR TOOL SCRIPTS: 
		# If running in the editor, you must set the owner so the nodes save with the scene.
		if Engine.is_editor_hint():
			minimap_poly.owner = get_tree().edited_scene_root

		# Match transforms
		minimap_poly.global_position = current_node.global_position
		minimap_poly.global_rotation = current_node.global_rotation
		minimap_poly.scale = current_node.global_scale

	# -- recurse through node tree
	for child in current_node.get_children():
		_recurse_platforms(child)



func debug_check_layer_hierarchy(node: Node, target_bit: int) -> void:
	var current = node
	print("--- STARTING HIERARCHY CULL CHECK FOR: ", node.name, " ---")
	
	while current is Node:
		if current is CanvasItem:
			# Check if the node has the target bit enabled in its visibility_layer
			var has_bit = (current.visibility_layer & (1 << target_bit)) != 0
			print("Node: ", current.name, " | Type: ", current.get_class(), " | Layer Bit ", target_bit, " Enabled: ", has_bit)
			
			if not has_bit:
				print(" --> BREAKDOWN FOUND HERE! Node '", current.name, "' does not have bit ", target_bit, " enabled.")
		else:
			print("Node: ", current.name, " | Type: ", current.get_class(), " (Not a CanvasItem, skips culling)")
			
		current = current.get_parent()
	print("--- CHECK COMPLETE ---")
