extends Node2D

var target_pos
var rest_length
#var wrap_corner_pos: Vector2
#var pivot_points_stack: Array[Vector2]

@export var ray_check_max_distance := 900
@export var swing_damping = 0.05

@export var item_interface: ItemInterface
@onready var ray_component = $RaycastItemComponent
@onready var rope := $Line2D

# -- set by item manager
var player_ref: Player
var cool_down

func _ready() -> void:
	#----------------------------------- item interface / dependency injection
	item_interface.tick_update_fn = tick_update
	item_interface.stopped.connect(on_item_stopped)
	item_interface.destroyed.connect( func():
		call_deferred("queue_free"))
	
	if is_multiplayer_authority() or multiplayer.is_server():
		ray_component.initialize_ray( ray_check_max_distance )


# -- NOTE
# -- this needs to be replaced with something that scales better
# -- and integrates into deterministic tick
@rpc("any_peer", "reliable")
func set_target_on_interpolated(pos=null):
	if !multiplayer.is_server():
		target_pos = pos
		if pos:
			rope.show()
		else:
			rope.hide()


var intersection_data
func tick_update(delta: float, cmd: PlayerCommand):
	# --dir of the aiming ray
	ray_component.tick_update(cmd)
	
	if cmd.item_use_pressed:
		if !target_pos:
			intersection_data = ray_component.get_intersection_data()
			if intersection_data:
				target_pos = intersection_data[0]
				# -- set rest length at time of intersection
				rest_length = (target_pos - player_ref.global_position).length()
				rope.set_point_position(1, to_local(target_pos))
				rope.show()
				# -- send to everyone but yourself and the host
				set_target_on_interpolated.rpc( target_pos )
				$MovementOverrideComponent.start()
				if is_multiplayer_authority() and not player_ref.is_replaying:
					Events.emit_signal("play_world_sound",
										AudioDb.WorldSoundId.HOOKSHOT_FIRE,
										target_pos,0,1,
										{})
		else:
			on_item_stopped()
	
	if target_pos:
		handle_grapple(delta)


func on_item_stopped():
	target_pos = null
	rope.hide()
	set_target_on_interpolated.rpc()
	$MovementOverrideComponent.finish()


func handle_grapple(delta):
	var to_anchor = target_pos - player_ref.global_position
	var current_dist = to_anchor.length()
	var target_dir = to_anchor.normalized()
	
	if current_dist > rest_length:
		player_ref.global_position = target_pos - target_dir * rest_length
		var radial_velocity = player_ref.velocity.dot(target_dir)
		if radial_velocity < 0:
			player_ref.velocity -= target_dir * radial_velocity
			
	if current_dist >= rest_length:
		player_ref.velocity += player_ref.get_gravity() * delta * 0.5

	player_ref.velocity *= (1.0 - (swing_damping * delta))


func set_player_ref(p: Player) -> void:
	player_ref = p
	
# ---------------------------------------------------------------- DEBUG Drawing
#func _draw():
	#if target_pos:
		##var active_pivot = pivot_points_stack.back()
		##draw_line(to_local(active_pivot), to_local(wrap_corner_pos), Color.CYAN, 10.0)
		#draw_circle(to_local(intersection_data[0]), 20.0, Color.ORANGE)
		##draw_line(to_local(active_pivot), to_local(player_ref.global_position), Color.WHITE, 1.0)


func _physics_process(_delta: float) -> void:
	if target_pos:
		rope.set_point_position(1, to_local(target_pos))
	#queue_redraw() # Forces _draw() to update every frame
#func _process(_delta):
	
