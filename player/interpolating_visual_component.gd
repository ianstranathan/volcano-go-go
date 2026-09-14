extends Node2D

class_name PlayerVisualInterpolator
"""
Basic component to decouple visual from networked simulation
(to try to make things look smoother)
NOTE
It's hardcoded right now to only use with player, but this should probably
be generalized eventually
- being used on item_manager & player sprite
"""

@onready var p = get_parent()
@export var player_ref: Player
var reconciliation_offset := Vector2.ZERO
var is_reconciling: bool = false
@export var smooth_speed := 15.0
@export var transform_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	p.set_as_top_level(true) # -- decouples transform
	player_ref.reconciled.connect(_on_player_reconciled)


func _on_player_reconciled(offset: Vector2):
	is_reconciling = true
	reconciliation_offset += offset

func _process(delta: float) -> void:
	#var pos_a = player_ref.pos_previous
	#var pos_b = player_ref.pos_current
	#p.global_position = pos_a.lerp(pos_b, NetManager.fract_tick)
	var pos_a = player_ref.pos_previous
	var pos_b = player_ref.pos_current
	var interpolated_pos = pos_a.lerp(pos_b, NetManager.fract_tick)
	
	if is_reconciling:
		reconciliation_offset = reconciliation_offset.lerp(Vector2.ZERO, delta * smooth_speed)
		if reconciliation_offset.length() < 0.1:
			is_reconciling = false
			reconciliation_offset = Vector2.ZERO

	p.global_position = transform_offset + interpolated_pos + reconciliation_offset
	p.global_rotation = player_ref.global_rotation
