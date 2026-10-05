@tool
extends Node
class_name PlatformMaterial

@export var material: Material:
	set(value):
		material = value
		_apply_material()


func _ready() -> void:
	_apply_material()


func _apply_material() -> void:
	if not Engine.is_editor_hint() and not is_inside_tree():
		return

	var parent := get_parent()
	if parent == null:
		return

	var sprite := parent.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		push_warning("PlatformMaterial: Parent does not have a Sprite2D child.")
		return

	sprite.material = material
