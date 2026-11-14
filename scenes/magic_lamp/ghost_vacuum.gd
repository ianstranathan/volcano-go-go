extends Sprite2D
## Attach to the ghost Sprite2D that uses a ShaderMaterial with vacuum_suction.gdshader.
## Call `start_suction(nozzle_node)` when the vacuum catches the ghost.

signal sucked_in

@export var suction_duration: float = 1.2

var _mat: ShaderMaterial
var _nozzle: Node2D
var _tween: Tween


func _ready() -> void:
	# Each ghost needs its own material instance, or they would all swirl together.
	_mat = (material as ShaderMaterial).duplicate()
	material = _mat
	_mat.set_shader_parameter("suction_progress", 0.0)
	_mat.set_shader_parameter("ghost_center", Vector2(0.5, 0.5))


func start_suction(nozzle: Node2D, duration: float = -1.0) -> void:
	_nozzle = nozzle
	if duration < 0.0:
		duration = suction_duration

	_update_target()  # avoid a one-frame glitch at the old target

	if _tween:
		_tween.kill()
	_tween = create_tween()
	# Linear here: the shader's `suction_curve` already makes it accelerate.
	_tween.tween_method(_set_progress, 0.0, 1.0, duration)
	_tween.tween_callback(_on_finished)


func cancel_suction() -> void:
	# Ghost escapes: play the effect backwards.
	if _tween:
		_tween.kill()
	var current: float = _mat.get_shader_parameter("suction_progress")
	_tween = create_tween()
	_tween.tween_method(_set_progress, current, 0.0, 0.35 * current)
	_tween.tween_callback(func(): _nozzle = null)


func _process(_delta: float) -> void:
	# Keep following the nozzle while the player moves it around.
	if _nozzle:
		_update_target()


func _set_progress(value: float) -> void:
	_mat.set_shader_parameter("suction_progress", value)


func _update_target() -> void:
	_mat.set_shader_parameter("target_pos", global_to_uv(_nozzle.global_position))


func _on_finished() -> void:
	_nozzle = null
	sucked_in.emit()
	hide()  # or queue_free()


## World position -> this sprite's UV space (0..1 over the texture).
## Handles node position, rotation, scale, `centered` and `offset`.
## (Does not account for flip_h/flip_v or region_rect.)
func global_to_uv(world_pos: Vector2) -> Vector2:
	var tex_size: Vector2 = texture.get_size()
	var local := to_local(world_pos)
	var top_left := offset - (tex_size * 0.5 if centered else Vector2.ZERO)
	return (local - top_left) / tex_size


## Example hook from a vacuum script:
##   func _on_ghost_caught(ghost: Sprite2D) -> void:
##       ghost.start_suction($Nozzle)
##       ghost.sucked_in.connect(func(): score += 1)
