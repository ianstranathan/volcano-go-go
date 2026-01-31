extends RigidBody2D

var holder

func _ready() -> void:
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	
	$Grabbable.got_tossed.connect( func(dir: Vector2):
		$CollisionShape2D.set_deferred("disabled", false)
		set_deferred("freeze", false)
		set_deferred("lock_rotation", false)
		apply_impulse( dir ))
	$Grabbable.got_grabbed.connect( func(node_ref: Node2D):
		holder = node_ref
		set_deferred("freeze", true)
		set_deferred("linear_velocity", Vector2.ZERO)
		set_deferred("lock_rotation", true)
		$CollisionShape2D.set_deferred("disabled", true))

func _physics_process(_delta: float) -> void:
	if holder and $CollisionShape2D.disabled:
		global_position = holder.global_position
