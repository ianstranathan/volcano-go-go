extends Node2D

class_name TheLava

enum LavaState{
	PAUSED,
	RISING
}
var lava_state: LavaState = LavaState.PAUSED
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

@export var initial_world_lava_level = 250
@onready var sprite: Sprite2D = $Sprite2D
var dims: Vector2 # = game_ref.get_level_dimensions()

var sinusoid_coeffs: Array[Vector3] #= [Vector3(40.0, 0.007, 0.0)]
var sinusoid_derivative_coeffs: Array[Vector3]
var number_of_sines: int = 10

var t := 0.0 # elapsed time, only counting in physics step


func start_lava(_dims):
	dims = _dims
	visible = true
	sprite.scale = Vector2(dims.x, 2048.0) / (sprite.texture.get_size() * sprite.scale)
	# -- coefficients are now in pixels
	# -- Asin(Bx - c)
	var A = 65.0
	var B = 0.001
	var C = 0.0 # NOTE not currently, using remove if you like
	var A_d = A * B # NOTE this can be cached, so you don't need do this over and over
	
	sinusoid_coeffs.append(Vector3(A, B, C))
	sinusoid_derivative_coeffs.append( Vector3(A_d, B, C))
	#print("from start_lava: \n global_position:", global_position,
	 #"\n visible: ", (visible and sprite.visible),
	 #"\n scale: ", scale, "\n sprite.scale: ", sprite.scale)
	#generate_tiles()
	
	#sprite.visible = true
	sprite.material.set_shader_parameter("sc", sinusoid_coeffs)
	
	sprite.material.set_shader_parameter("lava_level", global_position.y)
	# -- y is +tive down
	#global_position = Vector2(0., global_position.y)
	


# -- for later, when you're actually increasing the global_position to chase
# -- players
func translate_lava_vertically(y_amount: float):
	global_position.y += y_amount
	sprite.material.set_shader_parameter("lava_level", global_position.y)
	#get_children().map( func(tile): 
		#tile.set_shader_parameter_wrapper("lava_level", global_position.y))



# -- this is just for animating some surface noise
func execute_tick(delta):
	t += delta
	sprite.material.set_shader_parameter("t", t)
	match lava_state:
		LavaState.RISING:
			translate_lava_vertically( -50. * delta )
	#print(initial_world_lava_level)
	# -- for each lava tile, step it's t forward
	#for c in get_children():
		#if c:
			#c.set_shader_parameter_wrapper("t", t)


func lava_fn( world_x: float) -> float:
	var fn_ret = 0.0
	# -- From shader as reference
	# func +=  sc[i].x * sin(sc[i].y * uv.x + sc[i].y - _time);
	# func += fn_y_offset;
	for coeffs in sinusoid_coeffs:
		var A = coeffs.x
		var B = coeffs.y
		var x = world_x
		fn_ret -= A * sin((B * x) - t)
		#fn_ret += A * sin((B * x) - t)
		
	#initial_world_lava_level + fn_ret
	return fn_ret + global_position.y


# -- derivative; note the constant initial_world_lava_level drops
func angle_to_lava_fn( world_x: float ) -> float:
	var dx_fn_ret = 0.0
	for coeffs in sinusoid_coeffs:
		var A = coeffs.x
		var B = coeffs.y
		var x = world_x
		# -- why the shader time different from the CPU time?
		dx_fn_ret -= (A * B) * cos((B * x) - t)
	return atan(dx_fn_ret)


#func generate_tiles():
	#var tile_size = VolcanoBackgroundTile.tile_size
	#var start_x = -dims.x / 2.0
	#var tile_center_offset = tile_size.x / 2.0
	#var start_y = initial_world_lava_level 
	#for i in range(num_tiles_from_dist(dims.x, tile_size.x)):
		#var tile = lava_tile.instantiate()
		#add_child(tile)
		#var x_pos = start_x + tile_center_offset + (tile_size.x * i)
		#tile.global_position = Vector2(x_pos, start_y)
		#tile.set_shader_parameter_wrapper("sc", sinusoid_coeffs)
		#tile.set_shader_parameter_wrapper("lava_level", initial_world_lava_level)


func num_tiles_from_dist(dist: float, a_tile_dimension: float) -> int:
	return int(round(dist / a_tile_dimension))


func get_lava_information() -> Dictionary:
	return {"sc": sinusoid_coeffs, "lava_level": initial_world_lava_level}
