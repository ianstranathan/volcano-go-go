@tool
extends Node2D

@export var refresh := false:
	set(value):
		_update_line()
		refresh = false

@onready var path: Path2D = $Path2D
@export var line: Line2D
@export_tool_button("Bake texture", "Image")
var bake_button = bake_to_texture
@export var save_path: String = "res://player/sword/sword_slash_textures/sword_slash.png"

var _last_points: PackedVector2Array

@export_tool_button("Center slash sprite")
var center_btn: Callable = center_line2d_2_subviewport_midpoint

func center_line2d_2_subviewport_midpoint() -> void:
	line.position = sb_vp.size / 2.0

func _ready() -> void:
	if !Engine.is_editor_hint():
		_update_line()


func _update_line() -> void:
	if not is_instance_valid(path) or not is_instance_valid(line):
		return

	var curve := path.curve

	if curve == null:
		line.clear_points()
		return

	var points := curve.get_baked_points()

	if points != _last_points:
		line.points = points
		_last_points = points



@export var sb_vp: SubViewport
func bake_to_texture() -> void:
	if sb_vp == null:
		push_error("SubViewport is not assigned.")
		return

	await RenderingServer.frame_post_draw

	var image := sb_vp.get_texture().get_image()

	var dir := save_path.get_base_dir()
	var absolute_dir := ProjectSettings.globalize_path(dir)

	var error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("Could not create directory: " + dir)
		return

	error = image.save_png(save_path)

	if error == OK:
		print("Texture baked: ", save_path)
	else:
		push_error("Failed to save texture: ", error)
