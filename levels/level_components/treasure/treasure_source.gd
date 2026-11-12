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

var is_broken: bool = false
var num_times_hit: int = 0:
	set(value):
		if value != num_times_hit:
			num_times_hit = value
			_on_hits_changed()

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


#func on_weapon_area_entered( _area: Area2D):
	#num_times_hit += 1
	#if $chest_pieces_particles.emitting:
		#$chest_pieces_particles.restart()
	#else:
		#var mat = $chest_pieces_particles.process_material as ParticleProcessMaterial
		##$chest_pieces_particles.look_at(_area.global_position)
		#if mat:
			## -- change direction based on hit
			#mat.direction = Vector3(-sign(global_position.x - _area.global_position.x), mat.direction.y, 0.)
		#$chest_pieces_particles.emitting = true
	#if num_times_hit >= hits_to_break:
		#was_broken.emit()
		#queue_free()

func on_weapon_area_entered(_area: Area2D) -> void:
	# -- does area belong to a local player
	# -- sword area is on player
	var player = _area.owner
	if player and player.is_multiplayer_authority() and multiplayer.is_server() == false:
		return

	# -- local visuals immediately for predictive feel
	_play_hit_particles(_area)


func _play_hit_particles(_area: Area2D) -> void:
	if $chest_pieces_particles.emitting:
		$chest_pieces_particles.restart()
	else:
		var mat = $chest_pieces_particles.process_material as ParticleProcessMaterial
		if mat:
			mat.direction = Vector3(-sign(global_position.x - _area.global_position.x), mat.direction.y, 0.)
		$chest_pieces_particles.emitting = true


# Called when the Host's authoritative snapshot updates this chest's state
func apply_authoritative_snapshot(auth_hits: int, auth_broken: bool) -> void:
	# The host dictates the truth
	if auth_hits != num_times_hit:
		num_times_hit = auth_hits
		
	if auth_broken and not is_broken:
		_break_chest()


func _on_hits_changed() -> void:
	# -- do stuff if this changes, maybe becomes beefier or something
	pass


func _break_chest() -> void:
	is_broken = true
	was_broken.emit()
	queue_free()


#func _is_local_player_weapon(area: Area2D) -> bool:
	## Helper to verify if the area hitting the chest is controlled locally
	## (Adjust based on how your nodes/groups are structured)
	#var player = area.owner # Assuming weapon is owned by the player
	#return player and player.is_multiplayer_authority() and multiplayer.is_server() == false
