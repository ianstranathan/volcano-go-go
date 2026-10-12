extends AnimatedSprite2D

@export var min_speed: float = 0.4   
@export var max_speed: float = 2.5 
@export var speed_duration: float = 2.0

func _ready() -> void:
	visibility_changed.connect( func():
		if visible:
			start_cackle_loop() )

	visible = false

func start_cackle_loop() -> void:
	play("cackle")
	var tween = create_tween().set_loops()
	
	# Speed up
	tween.tween_property(self, "speed_scale", max_speed, speed_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
		
	# Slow down
	tween.tween_property(self, "speed_scale", min_speed, speed_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
