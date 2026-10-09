extends Sprite2D

signal transition_finished
signal fade_to_black_finished
signal fade_back_from_black_finished

@export var cam: Camera2D
@export var lava_ref: TheLava
#var lava_data: Dictionary

var transition_to_black_timer = TickTimer.new(1)
var transition_back_timer = TickTimer.new(1)


func _ready() -> void:
	material.set_shader_parameter("fade_progress", 0.0)
	material.set_shader_parameter("transition_data", 
		Vector2(0., 0.0))
		
	transition_back_timer.timeout.connect( func():
		material.set_shader_parameter("transition_data", 
		Vector2(0., 0.0)))
	# -- transition to black
	transition_to_black_timer.timeout.connect( func():
		transition_finished.emit())

	assert(cam)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_scale_to_viewport()


func _on_viewport_size_changed() -> void:
	_scale_to_viewport()


func _scale_to_viewport() -> void:
	var viewport_size = get_viewport().size
	var v = Vector2(float(viewport_size.x), float(viewport_size.y)) / cam.zoom
	var tex_size = texture.get_size()
	scale = v / tex_size


func start_transition_anim(rel_pos_to_portal: Vector2):
	transition_to_black_timer.start()
	material.set_shader_parameter("rel_pos_portal", rel_pos_to_portal)


func start_transition_anim_back():
	transition_back_timer.start()


func _process(_delta: float) -> void:
	# -- we're doing this in _process so there are no artifacts when
	# -- moving camera
	if cam:
		global_position = cam.global_position


func execute_tick(_delta: float) -> void:
	if lava_ref:
		material.set_shader_parameter("lava_level", lava_ref.global_position.y)
		material.set_shader_parameter("sc", lava_ref.sinusoid_coeffs)

	
	# -- send normalized timer [0, 1]
	if !transition_to_black_timer.is_stopped():
		var _t = transition_to_black_timer.normalized_time()
		material.set_shader_parameter("transition_data", 
			Vector2(_t * _t, 1.0))
	
	if !transition_back_timer.is_stopped():
		var _t = transition_back_timer.normalized_time()
		material.set_shader_parameter("transition_data", 
			Vector2(1. - (_t * _t), 1.0))


func material_uniform_float_fn(v: float, mat: Material, p: String):
	mat.set_shader_parameter(p, v)
	#print("v: ", v)
	#print("mat: ", mat)
	#print("param: ", mat.get_shader_parameter(p))

func fade_to_black(duration: float = 1.5) -> void:
	var tween := create_tween()
	tween.tween_method(
		material_uniform_float_fn.bind(material, "fade_progress"),
		0.,
		1.,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback( func():
		fade_to_black_finished.emit()
		var tween_back := create_tween()
		tween_back.tween_method(
			material_uniform_float_fn.bind(material, "fade_progress"),
			1,
			0.,
			duration * 1.2
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween_back.tween_callback( func():
			fade_back_from_black_finished.emit())
	)
