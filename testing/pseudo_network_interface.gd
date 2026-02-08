extends Node2D
class_name PseudoNetworkDriver

@export var players_container: Node2D
@export var tick_rate := 60.0
@export var decision_interval_min := 0.8
@export var decision_interval_max := 2.5
@export var jump_chance := 0.25

var _tick_accum := 0.0
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
		# -- NOTE TODO fragile CHANGE ME
		var controller = player.get_node("PlayerController").get_children()[0]
		if controller is RemotePlayerController:
			controllers.append(controller)
			controller_states[controller] = _new_controller_state()


#func _discover_controllers():
	#controllers.clear()
	#controller_states.clear()
#
	#for player in get_tree().get_nodes_in_group("players"):
		#if player.DEBUG_IS_LOCAL:
			#continue
#
		#var pc: PlayerController = player.get_node("PlayerController")
		#controllers.append(pc)
#
		#controller_states[pc] = _new_controller_state()

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
# Behavior + command emission
# ---------------------------------------------------------

func _emit_commands(delta: float) -> void:
	for pc in controllers:
		var state = controller_states[pc]

		# --- update behavior timer
		state.time_left -= delta
		if state.time_left <= 0.0:
			_pick_new_behavior(state)

		# --- jumping logic (short press)
		if state.jumping:
			state.jump_timer -= delta
			if state.jump_timer <= 0.0:
				state.jumping = false

		var wants_jump = state.jumping

		pc.inject_remote_intent(
			state.move,
			wants_jump and not state.last_jump,
			not wants_jump and state.last_jump
		)

		state.last_jump = wants_jump

# ---------------------------------------------------------
# Behavior selection
# ---------------------------------------------------------

func _pick_new_behavior(state: Dictionary) -> void:
	# Choose movement
	if randf() < 0.2:
		state.move = Vector2.ZERO # idle
	else:
		state.move = _random_direction()

	# Maybe jump
	if randf() < jump_chance:
		state.jumping = true
		state.jump_timer = randf_range(0.08, 0.18) # tap jump

	state.time_left = randf_range(
		decision_interval_min,
		decision_interval_max
	)

func _random_direction() -> Vector2:
	return Vector2.LEFT if randf() < 0.5 else Vector2.RIGHT
