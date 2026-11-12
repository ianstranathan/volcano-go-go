@tool
extends Area2D


@onready var offset = position.x #player.global_position.x - global_position.x
@onready var timer: TickTimer = TickTimer.new(0.2)

@export var sword_sprite: Sprite2D

@export var remake_line := false:
	set(value):
		_update_line()
		#refresh = false

@export_group("Mesh Variables")
@export var path_line_copies: Path2D
@export var line2d: Line2D
var _last_points: PackedVector2Array

func _update_line() -> void:
	if not is_instance_valid(path_line_copies) or not is_instance_valid(line2d):
		return

	var curve := path_line_copies.curve

	if curve == null:
		line2d.clear_points()
		return

	var points := curve.get_baked_points()

	if points != _last_points:
		line2d.points = points
		_last_points = points

func _ready() -> void:
	timer.timeout.connect( func():
		$CollisionShape2D.set_deferred( "disabled", true))


var last_swing_time: int = 0
const DOUBLE_TAP_WINDOW := 250 # milliseconds


func swing_sword( dir_scalar: float):
	var current_time = Time.get_ticks_msec()
	var double_tap = current_time - last_swing_time <= DOUBLE_TAP_WINDOW
	
	if dir_scalar < 0:
		if double_tap:
			$AnimationPlayer.play("slash_up_left")
		else:
			$AnimationPlayer.play("slash_down_left")
	else:
		if double_tap:
			$AnimationPlayer.play("slash_up_right")
		else:
			$AnimationPlayer.play("slash_down_right")
	
	last_swing_time = current_time

	$CollisionShape2D.set_deferred("disabled", false)
	timer.start()
	#flash_slash()




@export var flip_x := false:
	set(value):
		if value:
			reflect_points(true)
		flip_x = false

@export var flip_y := false:
	set(value):
		if value:
			reflect_points(false)
		flip_y = false


func reflect_points(horizontal: bool) -> void:
	for i in range(line2d.get_point_count()):
		var p = line2d.to_global(line2d.get_point_position(i))

		if horizontal:
			p.x = -p.x
		else:
			p.y = -p.y

		line2d.set_point_position(i, to_local(p))
