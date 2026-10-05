extends Area2D
class_name TreasureSource

signal was_broken

enum TreasureType {
	COPPER = 0,
	SILVER = 1,
	GOLD = 2,
	RUBY = 3,
	EMERALD = 4,
	DIAMOND = 5,
	AMETHYST = 6,
	MYTHIC = 7
}

var num_times_hit: int = 0

@export var hits_to_break: int = 3
@export var treasure_count: int = 20

# -- corresponding to the treasure atlas, manager needs this to pass to multimesh at simulation
@export var treasure_types: Array[TreasureType] = [] 
# -- starting index in the multimeshes' flat arr, assigned by manager
var start_index: int 

func _ready() -> void:
	$chest_pieces_particles.emitting = false
	#print( "TREASURE SOURCE GLOBAL POSITION: ", global_position )
	assert(hits_to_break != 0 and treasure_count != 0)
	# -- we're lowkey asserting this is only on a single collision area
	area_entered.connect( on_weapon_area_entered )

func get_intersection_pt_from_handed_ray(_r: RayCast2D):
	if _r.is_colliding():
		return _r.get_collision_point()
	else:
		return Vector2(INF, INF)


func RHS_intersection():
	return get_intersection_pt_from_handed_ray( $RHS )


func LHS_intersection():
	return get_intersection_pt_from_handed_ray( $LHS )


func on_weapon_area_entered( _area: Area2D):
	num_times_hit += 1
	if $chest_pieces_particles.emitting:
		$chest_pieces_particles.restart()
	else:
		var mat = $chest_pieces_particles.process_material as ParticleProcessMaterial
		#$chest_pieces_particles.look_at(_area.global_position)
		if mat:
			# -- change direction based on hit
			mat.direction = Vector3(-sign(global_position.x - _area.global_position.x), mat.direction.y, 0.)
		$chest_pieces_particles.emitting = true
	if num_times_hit >= hits_to_break:
		was_broken.emit()
		queue_free()
