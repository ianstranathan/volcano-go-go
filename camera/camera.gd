extends Camera2D

signal camera_centered_on_player()

# -- shaking vars
var noise = FastNoiseLite.new()
var noise_time: float = 0.0
var current_shake: ShakeData = null
var shake_timer: float = 0.0

# -- general target stuff
var target: Player
var horizontal_look_ahead_distance: float
var deadzone_height
var last_x_dir: float
var turn_around_delay_timer: float = 0.
var turn_around_delay_time_threshold = 0.12
var turning_around: bool = false
var current_look_ahead_offset = 0.

func _ready():
	Events.shake_cam.connect( camera_shake_fn )
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 20.0
	
	viewport_size_change_callback()
	var vp : Viewport = get_viewport()
	vp.size_changed.connect( viewport_size_change_callback )

	vp.set_canvas_cull_mask_bit(1, false)


func _physics_process(delta: float) -> void:
	queue_redraw()
	
	 
	if not target:
		return
	
	# -- TODO if player teleports or there's a very large change in the players global_position
	if (target.pos_current.x - target.pos_previous.x) > 1000:
		global_position = target.global_position
		return
	
	# --- DEATH LOCK BEHAVIOR ---
	# --- DEATH LOCK BEHAVIOR ---
	if is_dead:
		current_look_ahead_offset = move_toward(current_look_ahead_offset, 0.0, 500.0 * delta)
		
		global_position.x = move_toward(global_position.x, target.global_position.x, abs(global_position.x - target.global_position.x) * 10.0 * delta)
		global_position.y = move_toward(global_position.y, target.global_position.y, abs(global_position.y - target.global_position.y) * 10.0 * delta)
		
		print( global_position )
		# Check if we have arrived close enough to the player
		if not has_centered:
			if global_position.distance_squared_to(target.global_position) < 4.0:
				global_position = target.global_position
				has_centered = true
				camera_centered_on_player.emit()
				
		return
	# ----------------------------------------------------------------------------- Horizontal stuff

	if not is_zero_approx(target.move_input.x):
		if (last_x_dir != target.move_input.x):
			if turn_around_delay_timer < turn_around_delay_time_threshold:
				turn_around_delay_timer += delta
			else:
				last_x_dir = target.move_input.x
				turning_around = true
				turn_around_delay_timer = 0.0

	if turning_around :
		var target_offset: float = last_x_dir * horizontal_look_ahead_distance
		# -- max => to avoid asymptotic decay
		# -- 
		var offset_distance: float = abs(target_offset - current_look_ahead_offset)
		var dynamic_speed: float = max(offset_distance * 3.0, 25.)
		#print(dynamic_speed)
		current_look_ahead_offset = move_toward(current_look_ahead_offset, target_offset, dynamic_speed * delta)
		global_position.x = target.global_position.x + current_look_ahead_offset
		
		if is_equal_approx( current_look_ahead_offset, target_offset):
			turning_around = false
	else:
		# -- regular constant offset
		global_position.x = target.global_position.x + last_x_dir * horizontal_look_ahead_distance
	
	# ------------------------------------------------------------------------------- Vertical stuff
	#  -- bias it to be above the player maybe?
	global_position.y =lerp(global_position.y, target.global_position.y, 10. * delta)
	
	var _shake_offset = Vector2.ZERO
	if shake_timer > 0.0 and current_shake:
		_shake_offset = shake_offset( delta )
		global_position += _shake_offset


var debug_rect_width: float
func viewport_size_change_callback():
	var vp = get_viewport()
	horizontal_look_ahead_distance = vp.size.x / 12.0
	
	# -- from watching mario wonder, it looks like this should be pretty generous
	deadzone_height = 0.85 * vp.size.y
	debug_rect_width = 0.85 * vp.size.x


func target_initialize( player: Player) -> void:
	target = player
	global_position = player.global_position



func camera_shake_fn( shake_data: ShakeData) -> void:
	if shake_data.is_authority:
		current_shake = shake_data
		shake_timer = shake_data.duration
		noise.frequency = shake_data.frequency


func shake_offset( delta: float) -> Vector2:
	shake_timer -= delta
	
	# -- [0, 1]
	var t = 1.0 - (shake_timer / current_shake.duration)
	
	# Evaluate the modular curve if assigned, otherwise linear decay
	var envelope = 1.0 - t
	if current_shake.falloff_curve:
		envelope = current_shake.falloff_curve.sample(t)
	
	# -- 
	noise_time += delta * current_shake.frequency
	
	# -- 
	#var sample_x = noise.get_noise_2d(noise_time, 0.0)
	#var sample_y = noise.get_noise_2d(0.0, noise_time)
	var noise_offset = Vector2( noise.get_noise_2d(noise_time, 0.0), noise.get_noise_2d(0.0, noise_time) )
	var direction = current_shake.direction.normalized()
	
	if direction == Vector2.ZERO: 
		if shake_timer <= 0.0: 
			current_shake = null 
			return Vector2.ZERO 
		return noise_offset * current_shake.amplitude * envelope
	
	var perpendicular = Vector2(-direction.y, direction.x)
	
	# -- noise along each axis:
	var directional_noise = noise_offset.dot(direction) 
	var lateral_noise = noise_offset.dot(perpendicular)
	
	var ret = direction * directional_noise + perpendicular * lateral_noise * current_shake.randomness
	
	if shake_timer <= 0.0: 
		current_shake = null 
		return Vector2.ZERO 
	return ret * current_shake.amplitude * envelope

func _draw() -> void:
	var rect := Rect2(
		Vector2(-debug_rect_width * 0.5, -deadzone_height * 0.5),
		Vector2(debug_rect_width, deadzone_height)
	)

	draw_rect(rect, Color(1., 0., 1., 0.5), false, 2.0)
	draw_circle(Vector2.ZERO, 10., Color(1., 0., 0., 0.5))

	draw_dashed_line(Vector2(0., -deadzone_height * 0.5), Vector2(0., deadzone_height * 0.5), Color(0.1, 0.1, 0.6), 5, 5)
	
var is_dead: bool = false
var has_centered: bool = false
func on_player_died() -> void:
	is_dead = true
	shake_timer = 0.0
	current_shake = null
