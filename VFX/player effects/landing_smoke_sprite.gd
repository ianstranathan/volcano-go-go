extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _fade_alpha():
	$AnimatedSprite2D.play("default")

func _fade_alpha_stop():
	$AnimatedSprite2D.stop()
