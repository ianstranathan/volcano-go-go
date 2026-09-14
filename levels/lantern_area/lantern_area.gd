
extends MeshInstance2D

#@export var mesh_bounds: Vector2:
	#set(v):
		#mesh_bounds = v
		#$Area2D/CollisionShape2D.shape.size = v

func _ready() -> void:
	$Area2D/CollisionShape2D.shape.size = mesh.size
	#$Area2D.area_entered
	$Area2D.area_entered.connect( on_area_entered )
	material.set_shader_parameter("dim", mesh.size)
	assert( material is ShaderMaterial )
	#print( $Area2D.collision_layer)
	#print(  $Area2D.collision_mask)
	#assert( $Area2D.collision_layer == 5 and $Area2D.collision_mask == 5)
	
var lantern_ref: DynamicObject

func on_area_entered( area: Area2D) -> void:
	var player = area.get_parent() as Player
	if player:
		var obj = player.return_grabbed_object()
		if (obj and 
			obj is DynamicObject and
			obj.dynamic_object_profile.type == DynamicObjectsDb.DynamicObjectType.LANTERN):
			lantern_ref = obj
	#var p = area.get_parent() as DynamicObject
	#if p.dynamic_object_profile.type == DynamicObjectsDb.DynamicObjectType.LANTERN:
		#lantern_ref = p

func _physics_process(delta: float) -> void:
	if lantern_ref:
		#var local_pos = to_local(lantern_ref.global_position)
		#print("local_pos:", local_pos)
		#print("rel_pos:", lantern_ref.global_position - global_position)
		#print("YAS: ", local_pos ==  (lantern_ref.global_position - global_position))
		material.set_shader_parameter("lantern_pos",
			(lantern_ref.global_position - global_position) / (mesh.size / 2.))
