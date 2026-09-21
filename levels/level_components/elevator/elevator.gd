@tool
extends Node2D


"""
NOTE
the vec3 shader param is: interpolant [0., 1], direction ( -1, or 1 ) and on/off (0. or 1.)
"""


enum Positions {BOTTOM, TOP}
@export var location = Positions.BOTTOM

enum State {
	IDLE,
	MOVING_UP,
	MOVING_DOWN,
}
var state := State.IDLE
var requests := {
	Positions.BOTTOM: false,
	Positions.TOP: false
}

@export var call_down_switch: Node2D
@export var call_up_switch: Node2D
@export var speed: float = 100.0:
	set(v):
		speed = v
		if is_node_ready():
			$BasePlatform/MovingPlatformComponent.speed = v

@export var set_platform_position: bool:
	set(b):
		generate_elevator()
		pass

@onready var platform: BasePlatform = $BasePlatform
@onready var player_trigger_area := $BasePlatform/Area2D2

# -- NOTE
# -- I'm inheriting parents material on the side chains
# -- that's why they're coupled
@export var top_anchor: Marker2D:
	set(m):
		top_anchor = m
		if m:
			set_line_index_2_relative_dist(1, m)


@export var bottom_anchor: Marker2D:
	set(m):
		bottom_anchor = m
		if m:
			set_line_index_2_relative_dist(0, m)


@onready var line_2ds = $Node2D.get_children() + [$Line2D]
func set_line_index_2_relative_dist( i: int, m: Marker2D) -> void:
	if is_node_ready():
		var dist = m.position.y#m.global_position.y# - $BasePlatform.global_position.y
		for c in line_2ds:
			assert( c is Line2D)
			# -- make the y at index 0 the relative distance to the marker
			c.set_point_position(i, Vector2(0., dist))
		
		# -- now set the path curve points
		#if $BasePlatform/PathFollowPlatformComponent:
		var _c = $PathFollowPlatformComponent.curve
		_c.clear_points()
		_c.add_point(line_2ds[0].points[0])
		_c.add_point(line_2ds[0].points[1])


@onready var mov_comp: MovingPlatformComponent = platform.get_node("MovingPlatformComponent")
var _ticking = true

func _ready() -> void:
	if !Engine.is_editor_hint():
		#print("this is the initial location enum: ",  location)
		# -------------------------------------------------------------------------- elevator params
		mov_comp.speed = speed
		mov_comp.movement_finished.connect( on_movement_finished )
		
		assert(mov_comp.movement_type == mov_comp.MoveType.ONE_SHOT)
		# ------------------------------------------------------------------------- elevator buttons
		assert( call_down_switch )
		assert( call_up_switch )
		call_down_switch.switch_finished.connect( 
			func(): on_call_btn_pressed( Positions.BOTTOM) )
		call_up_switch.switch_finished.connect( 
			func(): on_call_btn_pressed( Positions.TOP) )

		# ---------------------------------------------------------------- initialize platform stuff
		# -- size
		assert($BasePlatform != null )
		$BasePlatform/Area2D2/CollisionShape2D.shape.size = platform.coll_extents
		# -- area callbacks
		player_trigger_area.position = Vector2(0., -platform.coll_extents.y)
		# -- set area player entered callback
		player_trigger_area.body_entered.connect( func(body):
			if body is Player:
				on_player_entered_trigger_area())
		
		platform = $BasePlatform
		generate_elevator()


func generate_elevator() -> void:
	
	# Fallback to direct lookup if @onready hasn't populated yet
	var current_platform = platform if platform else get_node_or_null("BasePlatform")
	if not current_platform:
		return
		
	if not top_anchor or not bottom_anchor:
		return

	set_line_index_2_relative_dist(1, top_anchor)
	set_line_index_2_relative_dist(0, bottom_anchor)
	if location == Positions.BOTTOM:
		current_platform.global_position = bottom_anchor.global_position
	else:
		current_platform.global_position = top_anchor.global_position



func execute_tick( delta: float ) -> void:
	if _ticking:
		mov_comp.execute_tick( delta )


func _process(_delta: float) -> void:
	if !Engine.is_editor_hint():
		$GPUParticles2D.global_position = $BasePlatform.global_position
		if state == State.MOVING_UP:
			var t = mov_comp.progress_ratio
			$GPUParticles2D.amount = max( 1., 10. * (-1. * (3.*t*t - 2.*t*t*t) + 1))
			$Line2D.material.set_shader_parameter("ratio_and_dir", Vector3(t, 1.0, 1.0))
		elif state == State.MOVING_DOWN:
			var t = mov_comp.progress_ratio
			$GPUParticles2D.amount = max(1., 10. * (3.*t*t - 2.*t*t*t))
			$Line2D.material.set_shader_parameter("ratio_and_dir", Vector3(t, -1.0, 1.0))
			#$Node2D.material.set_shader_paremeter("sroll_speed", mov_comp.progress_ratio ) 


func on_player_entered_trigger_area():
	if state == State.IDLE:
		# -- just toggling the location and going there
		state_transition_fn( 
			State.MOVING_UP if (1 - location) == Positions.TOP else State.MOVING_DOWN)


func on_movement_finished():
	location = Positions.TOP if (location == Positions.BOTTOM) else Positions.BOTTOM
	#print( location )
	requests[location] = false
	
	for request_loc in requests:
		if requests[ request_loc ] and location != request_loc:
			state_transition_fn( 
				State.MOVING_UP if (1 - location) == Positions.TOP else State.MOVING_DOWN)
		# -- if there's a request and that request isn't where we're at
		#print( request_loc, ": ", requests[ request_loc ] )
		
		else:
			if location == Positions.BOTTOM:
				call_down_switch.queue_restore()
			else:
				call_up_switch.queue_restore()
	
	state_transition_fn( State.IDLE )


func on_call_btn_pressed( request_type: Positions ):	
	if state == State.IDLE:
		# -- move immediately if IDLE
		state_transition_fn( 
			State.MOVING_UP if request_type == Positions.TOP else State.MOVING_DOWN)
	else:
		# -- otherwise add to queue
		assert(request_type == Positions.BOTTOM or request_type == Positions.TOP)
		requests[request_type] = true


func state_transition_fn( _new_state: State):
	if state != _new_state:
		match _new_state:
			State.IDLE:
				$Line2D.material.set_shader_parameter("ratio_and_dir", Vector3.ZERO)
				$GPUParticles2D.emitting = false
				_ticking = false
			State.MOVING_UP:
				$GPUParticles2D.emitting = true
				$GPUParticles2D.rotation = PI
				_ticking = true
				mov_comp.set_target_time( 1.0 )
			State.MOVING_DOWN:
				$GPUParticles2D.rotation = 0.
				$GPUParticles2D.emitting = true
				_ticking = true
				mov_comp.set_target_time( -1.0 )
		
		state = _new_state
	
