extends ItemComponent
class_name SpawnComponent

@export var scene: PackedScene

# -- spawn its resource into a designated spot in the game heirarchy
func spawn( container_node: Node, a_global_position: Vector2):
	var scene_instance = scene.instantiate()
	container_node.add_child( scene_instance )
	scene_instance.global_position = a_global_position
