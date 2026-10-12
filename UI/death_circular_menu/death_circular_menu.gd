extends TextureRect

signal choice_made

@export var segment_count: int = 6
@export var inner_radius: float = 0.5
@export var outer_radius: float = 0.8
@export var hover_radius_expand: float = 0.08
@export var gap: float = 0.03

@onready var max_radius: float = outer_radius + hover_radius_expand
@onready var _inner_radius_squared = inner_radius * inner_radius
@onready var _max_radius_squared = max_radius * max_radius
# -1 means no segment is hovered/selected
var hovered_index: int = -1

func _ready() -> void:
	_update_shader_parameters()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = event.position
		var uv: Vector2 = local_pos / size

		# Ensure the UV is within [0, 1] bounds before checking
		if Rect2(Vector2.ZERO, Vector2.ONE).has_point(uv):
			var segment_id: int = get_segment_at_uv(uv)
			if segment_id != -1:
				choice_made.emit()
				print("Clicked on segment: ", segment_id)
			else:
				print("Click failed segment check")


func _process(_delta: float) -> void:
	if visible:
		var mouse_uv: Vector2 = get_local_mouse_position() / size
		hovered_index = get_segment_at_uv(mouse_uv)
		material.set_shader_parameter("hovered_index", hovered_index)


# Translates UV (0.0 to 1.0) to a segment index (-1 if none)
func get_segment_at_uv(uv: Vector2) -> int:
	# 1. Map UV (0 to 1) to centered coords (-1 to +1)
	var p: Vector2 = 2.0 * uv - Vector2.ONE
	
	var dist_sq: float = p.length_squared()
	
	
	if dist_sq < _inner_radius_squared or dist_sq > _max_radius_squared:
		return -1

	var step_angle: float = TAU / float(segment_count)
	var angle: float = wrapf(p.angle(), 0.0, TAU) # GDScript equivalent of get_angle()
	var index: int = int(floor(angle / step_angle))
	
	# 4. Gap check (Edge distance)
	var segment_center: float = (index + 0.5) * step_angle
	var delta: float = wrapf(angle - segment_center + PI, 0.0, TAU) - PI
	var half_step: float = step_angle * 0.5
	var side_distance: float = p.length() * sin(half_step - abs(delta))
	
	if side_distance < (gap * 0.5):
		return -1 # Mouse is inside the radial gap between buttons
		
	return index


func _update_shader_parameters() -> void:
	if material is ShaderMaterial:
		material.set_shader_parameter("segment_count", segment_count)
		material.set_shader_parameter("inner_radius", inner_radius)
		material.set_shader_parameter("outer_radius", outer_radius)
		material.set_shader_parameter("hover_radius_expand", hover_radius_expand)
		material.set_shader_parameter("gap", gap)


func select_with_joystick(stick_vector: Vector2) -> void:
	# -- TODO there should be global deadzone or something
	if stick_vector.length() < 0.2:
		return
		
	var angle: float = wrapf(stick_vector.angle(), 0.0, TAU)
	var step_angle: float = TAU / float(segment_count)
	hovered_index = int(floor(angle / step_angle))
