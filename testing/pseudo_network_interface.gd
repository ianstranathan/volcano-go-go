extends Node2D

@export var players_container: Node2D
@export var tick_rate := 60.0
@export var decision_interval_min := 0.8
@export var decision_interval_max := 2.5
@export var jump_chance := 0.25

var _tick_accum := 0.0
var _sequence_counter := 0 # To simulate incrementing sequence IDs
var controllers: Array = []
var controller_states := {}

# ---------------------------------------------------------
# Setup
# ---------------------------------------------------------

func _ready():
	randomize()
	controllers.clear()
	controller_states.clear()

	for player in players_container.get_children():
		if player.DEBUG_IS_LOCAL:
			continue
		
		# Getting the controller child (RemotePlayerController)
		var pc_node = player.get_node("PlayerController")
		if pc_node.get_child_count() > 0:
			var controller = pc_node.get_child(0)
			if controller is RemotePlayerController:
				controllers.append(controller)
				controller_states[controller] = _new_controller_state()


func _new_controller_state() -> Dictionary:
	return {
		"move": _random_direction(),
		"time_left": randf_range(decision_interval_min, decision_interval_max),
		"jumping": false,
		"jump_timer": 0.0,
		"last_jump": false,
	}

# ---------------------------------------------------------
# Fixed-step tick
# ---------------------------------------------------------

func _physics_process(delta: float) -> void:
	_tick_accum += delta
	var step := 1.0 / tick_rate

	while _tick_accum >= step:
		_tick_accum -= step
		_emit_commands(step)

# ---------------------------------------------------------
# Refactored Emission: Testing Serialization Round-trip
# ---------------------------------------------------------

func _emit_commands(delta: float) -> void:
	_sequence_counter += 1
	
	for pc in controllers:
		var state = controller_states[pc]

		# 1. Update internal "AI" behavior
		state.time_left -= delta
		if state.time_left <= 0.0:
			_pick_new_behavior(state)

		if state.jumping:
			state.jump_timer -= delta
			if state.jump_timer <= 0.0:
				state.jumping = false

		# 2. CREATE the command object
		var cmd = PlayerCommand.new()
		cmd.move_input = state.move
		cmd.jump_pressed = state.jumping and not state.last_jump
		cmd.jump_released = not state.jumping and state.last_jump
		cmd.sequence_id = _sequence_counter
		

		pc.inject_remote_intent( cmd.serialize() )
		
		state.last_jump = state.jumping

# ---------------------------------------------------------
# Behavior selection
# ---------------------------------------------------------

func _pick_new_behavior(state: Dictionary) -> void:
	if randf() < 0.2:
		state.move = Vector2.ZERO 
	else:
		state.move = _random_direction()

	if randf() < jump_chance:
		state.jumping = true
		state.jump_timer = randf_range(0.08, 0.18) 

	state.time_left = randf_range(decision_interval_min, decision_interval_max)

func _random_direction() -> Vector2:
	return Vector2.LEFT if randf() < 0.5 else Vector2.RIGHT
