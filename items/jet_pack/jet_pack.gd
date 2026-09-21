extends Node2D


@export var item_interface: ItemInterface
@export var accl_curve: Curve
var player_ref: Player
var cool_down
var g
var accl_cut_off_speed: float

func _ready() -> void:
	toggle_visual( false )
	#----------------------------------- item interface / dependency injection
	item_interface.tick_update_fn = tick_update
	item_interface.stopped.connect(on_item_stopped)
	item_interface.destroyed.connect( func():
		call_deferred("queue_free"))
	if player_ref:
		g = player_ref.get_g()
		accl_cut_off_speed = 1.2 * player_ref.TERMINAL_FALL_SPEED


var interpolant := 0.0
@export var delta_increase_rate: float = 1.0

func accl_sample(delta: float) -> float:
	interpolant += delta * delta_increase_rate
	interpolant = clamp(interpolant, 0., 1)
	return accl_curve.sample(interpolant)

#@onready var shake_struct = ShakeInstance.new(0.3, 0.1, Vector2.ZERO, MyMathUtils.heavy_impact_curve, true)


var started: bool = false
func tick_update(delta: float, cmd: PlayerCommand):
	if cmd.item_use_held:
		#Events.shake_cam.emit(shake_struct)
		if !started:
			#player_ref.testing = true
			on_item_started()
			# -- we want it to feel stronger, less like asteroids
			if player_ref and player_ref.velocity.y < 0:
				player_ref.velocity.y *= 0.2
			started = true

		if player_ref and player_ref.velocity.y < accl_cut_off_speed:
			player_ref.velocity.y -= 1.5 * g * accl_sample( delta ) * delta
	else:
		if started:
			#shake_struct.stop()
			on_item_stopped()
			started = false


func on_item_started():
	$MovementOverrideComponent.start()
	toggle_visual( true )
	show_on_interpolated.rpc( true )


func on_item_stopped():
	interpolant = 0.0
	toggle_visual( false )
	show_on_interpolated.rpc( false )
	$MovementOverrideComponent.finish()


func toggle_visual(b: bool):
	$Sprite2D.material.set_shader_parameter("using", 1. if b else 0.)


@rpc("any_peer", "reliable")
func show_on_interpolated(b=true):
	if !multiplayer.is_server():
		toggle_visual( b )


func set_player_ref(p: Player) -> void:
	player_ref = p
