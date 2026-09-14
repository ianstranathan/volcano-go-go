extends CharacterBody2D
class_name DynamicObject

"""
Dynamic object just connects to its manager to makes things more performant
and have network ids
Pseudo-ish strategy pattern with the dynamic_object_profile
(can hook up a different script to handle collisions or do whatever
i.e. rock can roll, lantern just stops etc)
"""

signal put_to_sleep( _self: DynamicObject)
signal woke_up(_self: DynamicObject)
signal got_grabbed( id: int )

# -- this is set from the manager loading / instancing it.
var dynamic_object_profile: DynamicObjectProfile: 
	set( v ):
		dynamic_object_profile = v

		# -- visual
		add_child( v.visual_scene.instantiate() )
		# -- update collision shape
		assert(v.collision_shape)
		$CollisionShape2D.shape = v.collision_shape
		
		# -- updat area collision shape
		if v.grab_area_collision_shape:
			$Area2D/CollisionShape2D.shape = v.grab_area_collision_shape
		else:
			# -- fallback to physics shape
			$Area2D/CollisionShape2D.shape = v.collision_shape
			print("Yo, you forgot an grabbing area in rsc: ", v)


var spawn_id = -1
var grabbing_player_area: Area2D

enum DynamicObjectState{
	SLEEPING,
	ACTIVE,
	GRABBED
}
var state: DynamicObjectState = DynamicObjectState.ACTIVE
var sleep_threshold = 20  # -- num ticks to go to sleep
var sleep_threshold_t = 0
@onready var last_pos = global_position

#  -- probably event throw this guy on the physics component
var TERMINAL_FALL_SPEED: float = 1400.0

func _ready() -> void:
	assert( dynamic_object_profile )
	assert( dynamic_object_profile.physics_script )
	$Area2D.area_entered.connect( on_player_grab_area_entered )


func execute_tick( delta: float) -> void:
	last_pos = global_position
	match state:
		DynamicObjectState.ACTIVE:
			
			if velocity.y <= TERMINAL_FALL_SPEED:
				velocity.y += get_g() * delta
				
			global_position += (velocity * delta) + Vector2(0., (0.5 * delta * delta * get_g()))
			
			var collision = move_and_collide(Vector2.ZERO)
			
			# -- all objects should be able to do whatever / bespoke motion
			if collision:
				dynamic_object_profile.physics_script.collision_response( self, dynamic_object_profile,collision, delta )
			
			# -- we need all dynamic objects to be querying their sleep / active state
			if last_pos.is_equal_approx(global_position):
				sleep_threshold_t += delta
				if sleep_threshold_t >= sleep_threshold:
					set_state(DynamicObjectState.SLEEPING)
					return
			else:
				sleep_threshold_t = 0.0
				return

		DynamicObjectState.GRABBED:
			global_position = grabbing_player_area.global_position
			return


func set_state(new_state: DynamicObjectState) -> void:
	if state == new_state:
		return
	state = new_state
	match state:
		DynamicObjectState.SLEEPING:
			put_to_sleep.emit( self )
		DynamicObjectState.ACTIVE:
			woke_up.emit( self)
		DynamicObjectState.GRABBED:
			if state == DynamicObjectState.SLEEPING:
				woke_up.emit( self)


func get_g() -> float:
	return 980


func on_player_grab_area_entered( area: Area2D) -> void:
	"""
	maybe do some visuals, highlight the item or something to
	indicate it can be grabbed
	"""
	pass


func can_be_grabbed():
	return (grabbing_player_area == null)


func get_grabbed( grabbing_area: Area2D) -> void:
	$CollisionShape2D.set_deferred("disabled", true)
	$Area2D.set_deferred("monitorable", false)
	$Area2D.set_deferred("monitoring", false)
	velocity = Vector2.ZERO
	grabbing_player_area = grabbing_area
	set_state( DynamicObjectState.GRABBED )


func get_thrown(throw_vel: Vector2) -> void :
	$CollisionShape2D.set_deferred("disabled", false)
	$Area2D.set_deferred("monitorable", true)
	$Area2D.set_deferred("monitoring", true)
	set_state( DynamicObjectState.ACTIVE )
	# -- collision test to get outside of player?
	velocity = throw_vel / dynamic_object_profile.mass
	#print( velocity )
