extends Area2D

signal player_finished_entering( id )

func _ready() -> void:
	body_entered.connect( func(b):
		if b is Player:
			var dir = (b.global_position - global_position).normalized()
			var world_hit_point = global_position + (dir * $CollisionShape2D.shape.radius)
			# -- purely visual
			b.get_sucked_into_lamp( world_hit_point,
					# -- closure around player
					func(): player_finished_entering.emit( int(b.name) )))
