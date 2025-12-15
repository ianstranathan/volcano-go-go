extends Camera2D

# -- TODO + FIXME
# -- This is quick and deerty
"""
Goals for camera movement:
	1) frames jumping 
	   (shouldn't change elevation until the player goes beyond some threshold & lands OR goes off screen)
	   -> why? this allows more precise control over jumping (it's a platformer afterall)
	2) look ahead (orient in direction of player movement and be slightly ahead of it)
	 
	Lerping when changing directions should be faster than lerping in same dir
"""

var lerp_x_t:= 0.0
## coefficient on physics tick delta accumulation
@export var interpolation_speed = 0.25
@export var target: CharacterBody2D
@export var target_height_offset: float
var target_x_dir := 1.0
# -- maximum offset in pixels
var x_offset = 200.0
var y_offset = 100.0
var target_offset = Vector2(x_offset, y_offset)

# -- this is viewport dependent, might be good to export?
var platform_vertical_threshold
var falling_vertical_threshold

var lerping_to_turned_dir := false


func _ready():
	assert(target)
	set_vertical_movement_thresholds()
	# -- TODO
	get_tree().get_root().size_changed.connect(set_vertical_movement_thresholds)
	
	global_position = Vector2(target.global_position.x + (x_offset), 
							  target.global_position.y - 100.0)


# -- needs to be a separate function for callbacks
func set_vertical_movement_thresholds() -> void:
	var vp_size_y =  get_viewport().size.y
	platform_vertical_threshold = vp_size_y / 3.0
	falling_vertical_threshold = vp_size_y / 2.5


func _physics_process(delta):
	if !target:
		return

	# -- switch way it's pointing based on the players velocity
	if target.velocity.x != 0.0:
		var s = sign(target.velocity.x)
		if target_x_dir != s:
			lerping_to_turned_dir = true
			lerp_x_t = 0.0
			target_x_dir = s

	
	#var target_pos := target.global_position.x + Vector2(x_offset * target_x_dir,
													  #0)
													
	# -- we don't want to affect the y component of the camera, as this affects
	# -- platforming ability
	var target_x = target.global_position.x + (x_offset * target_x_dir)
	
	# -- purely arbitrary distance threshold (i.e. 2px)
	if !abs(target_x - global_position.x) < 2.0:
		if !lerping_to_turned_dir:
			# -- snapping to the target when lerping is over
			global_position.x = target_x
		else:
			lerp_x_t += interpolation_speed * delta
			# -- interpolation function (a.k.a. easing fn)
			var t = 1.0 - cos(lerp_x_t * PI / 2.0);
			global_position.x = (1. - t) * global_position.x + t * target_x 
			#global_position.x = lerp(global_position.x, target_x, delta * delta)
	else:
		if lerping_to_turned_dir:
			lerp_x_t = 0.0
			lerping_to_turned_dir = false

	# -- update y position if the player crosses some threshold & lands on the platform
	# -- this allows the player to make a jump without the camera changing
	# -- this is what's do that "Donkey Kong" style camera shift
	if abs(target.global_position.y - global_position.y) >= platform_vertical_threshold and target.is_on_floor():
		var tween = get_tree().create_tween()
		tween.tween_property(self, "global_position:y", target.global_position.y, 0.3)
		tween.set_parallel(true)
	# -- otherwise, change if the player nears the edge of the screen in y dir (falling)
	elif abs(target.global_position.y - global_position.y) >= falling_vertical_threshold:
		#global_position.y = target.global_position.y
		var tween = get_tree().create_tween()
		tween.tween_property(self, "global_position:y", target.global_position.y, 0.2)
		tween.set_parallel(true)
