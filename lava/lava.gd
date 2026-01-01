extends Node2D

# -- this should just be a thin interface between CPU and GPU
# -- 1
# --   it has a analytic function (a sinusoid) that it manages
# -- 2.
# --   it can tell if a bounding box / collision shape is lower than it's
# --   wave function
# -- 3.
# --   it can send the data that goes into it's CPU managed sinusoid
# --   correctly to its fragment shader view
 
# -- In General: y = A sin(B(x - C)) + D

# -- what it looks like in the shader:
# -- float func = 0.3 * sin(0.2 * uv.x - _time);
# -- 
# -- the space has to agree => scale of lava has to be the size of the volcano

@export var level_params: Resource
@onready var lava_view: Sprite2D = $Sprite2D
var sinusoid_coeffs: Array[Vector3]
var sinusoid_derivative_coeffs: Array[Vector3]
var number_of_sines: int = 10


var some_primes: Array[int] = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71]

var t := 0.0 # elapsed time, only counting in physics step
func _ready() -> void:
	assert(lava_view)
	
	# -- More interesting looking lava -> desmos
	#for i in range( number_of_sines):
		#var A = randf() / 100. # -- the amplitude
		#var B = randf() * PI#some_primes[randi_range(0, some_primes.size() - 1)] # -- the freq
#
		#var C = (1.0 if randf() > 0.5 else -1.0) * randf() * TAU # -- the offset
		#var V = Vector3(A, B, C)
		##print( V )
		#sinusoid_coeffs.append( V )
	
	#lava_view.material.set_shader_parameter("sc", sinusoid_coeffs)
	var A = 0.15
	var B = 1.0
	var C = 0.0
	var A_d = A * B
	
	sinusoid_coeffs.append(Vector3(A, B, C))
	sinusoid_derivative_coeffs.append( Vector3(A_d, B, C))
	
	lava_view.material.set_shader_parameter("sc", sinusoid_coeffs)
	#lava_view.material.set_shader_parameter("sdc", sinusoid_derivative_coeffs)
	scale_to_level()


## the initial starting position of the lava
@export var lava_world_y_offset = 300
func scale_to_level():
	var dims : Vector2 = level_params.level_dimensions
	assert(dims)
	assert( !dims.is_equal_approx( Vector2.ZERO), "level dimensions can't be zero")
	
	lava_view.scale = dims / lava_view.texture.get_size()
	
	# -- Only change the lava level in world, shader should scale it
	# -- I wrote the shader first and don't want to change the sign convention
	# -- Godot 2D: +tive y is down, shader +tive y is up
	lava_view.material.set_shader_parameter("fn_y_offset", 
		-lava_world_y_offset / half_y)


func _physics_process(delta: float) -> void:
	t += delta
	lava_view.material.set_shader_parameter("t", t)


@onready var half_y: float = level_params.level_dimensions.y / 2.0
@onready var half_x: float = level_params.level_dimensions.x / 2.0
func lava_fn( world_x: float) -> float:
	var fn_ret = 0.0
	# -- From shader as reference
	# func +=  sc[i].x * sin(sc[i].y * uv.x + sc[i].y - _time);
	# func += fn_y_offset;
	for coeffs in sinusoid_coeffs:
		var A = coeffs.x * half_y
		var B = coeffs.y
		var x = world_x / half_x
		fn_ret -= A * sin((B * x) - t)
	
	fn_ret += lava_world_y_offset
	return fn_ret

## return the derivative
func angle_to_lava_fn( world_x: float ) -> float:
	var dx_fn_ret = 0.0
	for coeffs in sinusoid_coeffs:
		var A = coeffs.x * half_y
		var B = coeffs.y
		var x = world_x / half_x
		# -- why the shader time different from the CPU time?
		dx_fn_ret -= ((A * B) / half_x) * cos((B * x) - t)
	return atan(dx_fn_ret)
