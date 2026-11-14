extends Node2D

func _ready() -> void:
	$Area2D.body_entered.connect( func(b):
		if b is Player:
			b.get_sucked_into_lamp() )
