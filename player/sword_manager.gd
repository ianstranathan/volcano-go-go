extends Area2D


@onready var player = get_parent() as Player
@onready var offset = position.x #player.global_position.x - global_position.x

@onready var timer: TickTimer = TickTimer.new(0.2)

func _ready() -> void:
	timer.timeout.connect( func():
		$CollisionShape2D.set_deferred( "disabled", true))


func _physics_process(delta: float) -> void:
	#print(offset * sign(player.last_non_zero_move_input.x))
	position.x = offset * sign(player.last_non_zero_move_input.x)


func swing_sword():
	$CollisionShape2D.set_deferred( "disabled", false)
	timer.start()
