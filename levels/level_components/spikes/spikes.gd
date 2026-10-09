@tool
extends Node2D
class_name SpikeStrip


@export_category("Collision")

@export var make: bool = false:
	set(value):
		make = value


@export var thickness: float = 32.0:
	set(value):
		thickness = max(value, 0.0)


func _ready() -> void:
	#if !Engine.is_editor_hint():
	_make_collision()

func _process(_delta: float) -> void:
	if make:
		make = false
		_make_collision()

# -- TODO clean up slop
func _make_collision() -> void:
	var path := get_node_or_null("Path2D") as Path2D
	var collision_shape := get_node_or_null(
		"Area2D/CollisionShape2D"
	) as CollisionShape2D

	if path == null or collision_shape == null:
		return

	var curve := path.curve

	if curve == null or curve.point_count < 2:
		return

	var length := curve.get_baked_length()

	if length <= 0.0:
		return

	var start := curve.sample_baked(0.0)
	var end := curve.sample_baked(length)

	var direction := end - start

	if direction.length_squared() < 0.000001:
		return

	var center := (start + end) * 0.5
	var angle := direction.angle()

	var rectangle := RectangleShape2D.new()

	rectangle.size = Vector2(
		length,
		thickness
	)

	collision_shape.shape = rectangle
	collision_shape.position = center
	collision_shape.rotation = angle


func get_visual_data() -> Dictionary:
	var collision_shape := get_node_or_null(
		"Area2D/CollisionShape2D"
	) as CollisionShape2D

	if collision_shape == null:
		return {}

	var rectangle := collision_shape.shape as RectangleShape2D

	if rectangle == null:
		return {}

	return {
		"transform": collision_shape.global_transform,
		"size": rectangle.size,
	}

func disable_spike_area(b):
	$Area2D.set_deferred("monitoring", !b)
	$Area2D.set_deferred("monitorable", !b)
