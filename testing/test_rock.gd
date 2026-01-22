extends RigidBody2D

var holder

func _ready() -> void:
	$Grabbable.got_tossed.connect( func(dir: Vector2):
		$CollisionShape2D.set_deferred("disabled", false)
		apply_impulse( dir ))
	$Grabbable.got_grabbed.connect( func(node_ref: Node2D):
		holder = node_ref
		$CollisionShape2D.set_deferred("disabled", true))

func _physics_process(_delta: float) -> void:
	if holder and $CollisionShape2D.disabled:
		global_position = holder.global_position
