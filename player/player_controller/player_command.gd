extends RefCounted

class_name PlayerCommand
"""
My attempt at a high level packet abstraction describing player
intent for one simulation step, basically a one way communication envelope
"""

var move_dir: Vector2 = Vector2.ZERO
var jump_pressed := false
var jump_released := false
var aim_dir: Vector2 = Vector2.ZERO
var using_controller := false
var carrying_item := false

# -- client side predication stuff
var sequence_id := 0
