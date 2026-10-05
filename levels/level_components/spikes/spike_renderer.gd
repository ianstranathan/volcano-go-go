@tool
extends Node2D
class_name SpikeRenderer

@export var spike_container: Node2D
@export var texture: Texture2D
# -- TODO this should be more than one, just connect the signals for each to each
@export var treasure_altar: Node2D: 
	set(v):
		treasure_altar = v
		v.on_item_sacrificed.connect( recede_spike )

@export_category("Debug Recede")

@export var recede: bool = false:
	set(value):
		recede = value
		if is_inside_tree():
			_recede_instance(0, value)

@export var recede_distance: float = -128.0
@export var recede_duration: float = 0.35

var base_transforms: Array[Transform2D] = []
var recede_tweens: Dictionary = {}
var spike_indices: Dictionary = {}

@export var make: bool = false:
	set(value):
		make = value


@onready var multimesh_instance: MultiMeshInstance2D = $MultiMeshInstance2D


func _ready() -> void:
	_rebuild()


func _process(_delta: float) -> void:
	if make:
		make = false
		_rebuild()


func _rebuild() -> void:
	if spike_container == null:
		push_warning("SpikeRenderer: spike_container is not assigned.")
		return

	var strips: Array[SpikeStrip] = []

	_collect_spike_strips(
		spike_container,
		strips
	)

	if strips.is_empty():
		return

	var mm := multimesh_instance.multimesh

	mm.instance_count = strips.size()
	mm.visible_instance_count = strips.size()

	# Rebuild the mapping every time.
	spike_indices.clear()

	base_transforms.clear()
	base_transforms.resize(strips.size())

	var texture_size := (
		texture.get_size()
		if texture != null
		else Vector2.ONE
	)

	for i in range(strips.size()):
		var strip := strips[i]

		# ------------------------------------------------------------
		# IMPORTANT:
		# This is the designer-facing -> MultiMesh mapping.
		# ------------------------------------------------------------

		spike_indices[strip] = i

		var data := strip.get_visual_data()

		if data.is_empty():
			continue

		var collision_transform: Transform2D = data["transform"]
		var collision_size: Vector2 = data["size"]

		var xform := (
			multimesh_instance.global_transform.affine_inverse()
			* collision_transform
		)

		xform = xform.scaled_local(collision_size)

		base_transforms[i] = xform

		mm.set_instance_transform_2d(
			i,
			xform
		)

		var uv_domain := collision_size / texture_size

		mm.set_instance_custom_data(
			i,
			Color(
				uv_domain.x,
				uv_domain.y,
				0.0,
				0.0
			)
		)

func recede_spike(strip: SpikeStrip) -> void:
	if not spike_indices.has(strip):
		push_warning(
			"SpikeStrip is not registered with this SpikeRenderer."
		)
		return

	var index: int = spike_indices[strip]

	_recede_instance(index, true)


func _recede_instance(index: int, should_recede: bool) -> void:
	if index < 0 or index >= base_transforms.size():
		return

	var mm := multimesh_instance.multimesh

	if recede_tweens.has(index):
		recede_tweens[index].kill()

	var base := base_transforms[index]

	var start_transform := mm.get_instance_transform_2d(index)

	var target_transform := base

	if should_recede:
		# Local negative Y axis.
		var direction := -base.y.normalized()

		target_transform.origin += direction * recede_distance

	var tween := create_tween()

	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_method(
		func(transform: Transform2D):
			mm.set_instance_transform_2d(
				index,
				transform
			),
		start_transform,
		target_transform,
		recede_duration
	)

	tween.finished.connect(func():
		recede_tweens.erase(index)
	)

	recede_tweens[index] = tween



func _collect_spike_strips(
	node: Node,
	result: Array[SpikeStrip]
) -> void:

	for child in node.get_children():

		if child is SpikeStrip:
			result.append(child)

		_collect_spike_strips(
			child,
			result
		)
