extends Node2D

@onready var light: PointLight2D = $PointLight2D

var time := 0.0

func _process(delta: float) -> void:
	time += delta

	var slow = sin(time * 3.0)
	var fast = sin(time * 11.0)

	var flicker = 0.7 + (slow * 0.2 + fast * 0.1)

	light.energy = flicker
	light.texture_scale = 1.0 + (flicker - 0.7) * 0.5
