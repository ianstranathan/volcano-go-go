@tool
extends Node2D

signal on_item_sacrificed( s: SpikeStrip )

@export var spike_strip_to_recede: SpikeStrip
@export var _size: Vector2 = Vector2(100, 100):
	set(value):
		_size = value
		_update_children()
		queue_redraw()


func _ready() -> void:
	if not Engine.is_editor_hint():
		$Area2D.body_entered.connect(on_item_entered)
	_update_children()
	queue_redraw()

# -- TODO this needs to be deterministic from host
func on_item_entered(body):
	if body is PickupItem:
		if multiplayer.is_server():
			body.sacrifice.rpc(global_position)
			do_visual_stuff_for_sacrifice_feedback.rpc()
			if spike_strip_to_recede != null:
				emit_the_receding_signal_on_everyone.rpc()


@rpc("any_peer", "reliable", "call_local")
func emit_the_receding_signal_on_everyone():
	spike_strip_to_recede.disable_spike_area( true )
	on_item_sacrificed.emit( spike_strip_to_recede )

@rpc("any_peer", "reliable", "call_local")
func do_visual_stuff_for_sacrifice_feedback():
	$PutInIndicator.visible = false
	$Polygon2D.color = Color(0.047, 0.282, 1.0, 0.741)

func _update_children() -> void:
	# Update Polygon2D
	var polygon := get_node_or_null("Polygon2D") as Polygon2D

	if polygon:
		var half_size := _size / 2.0

		polygon.polygon = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2( half_size.x, -half_size.y),
			Vector2( half_size.x,   half_size.y),
			Vector2(-half_size.x,   half_size.y),
		])

	# Update Area2D collision
	_update_collision_shape("Area2D/CollisionShape2D", 1.2)

	# Update StaticBody2D collision
	_update_collision_shape("StaticBody2D/CollisionShape2D")
	
	# Update Sprite2D scale and position
	var sprite := get_node_or_null("PutInIndicator") as Sprite2D
	if sprite and sprite.texture:
		var tex_size := sprite.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			# Scale sprite to be 1.25 times the scale required to match _size
			sprite.scale = (_size / tex_size)
			
			# Set Y position to be 0.25 of the sprite's total height
			var half_height := tex_size.y * sprite.scale.y / 2.
			sprite.position.y = -half_height * 1.5


func _update_collision_shape(path: NodePath, scale_override=0.) -> void:
	var collision := get_node_or_null(path) as CollisionShape2D

	if collision == null:
		return

	var rectangle := collision.shape as RectangleShape2D

	# If the rectangle is null OR it's still sharing the base scene's resource,
	# create a new local resource so edits in inherited scenes remain isolated.
	if rectangle == null or not rectangle.resource_local_to_scene:
		rectangle = RectangleShape2D.new()
		rectangle.resource_local_to_scene = true
		collision.shape = rectangle
	
	if scale_override != 0.:
		rectangle.size = _size * scale_override
	else:
		rectangle.size = _size
