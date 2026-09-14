extends Area2D


@onready var player = get_parent() as Player
@onready var offset = position.x #player.global_position.x - global_position.x

@onready var timer: Timer = Timer.new()

func _physics_process(delta: float) -> void:
	#print(offset * sign(player.last_non_zero_move_input.x))
	position.x = offset * sign(player.last_non_zero_move_input.x)
	timer.wait_time = 0.2
	timer.one_shot = true
	timer.timeout.connect( func():
		$CollisionShape2D.set_deferred( "disabled", true))


func swing_sword():
	pass
	#$CollisionShape2D.set_deferred( "disabled", false)
	#timer.start()
