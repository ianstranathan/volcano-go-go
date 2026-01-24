extends Area2D

@export var player_ref: Player
@export var throw_speed: float = 200

signal weighed_down

var grabbable_items_near_player: Array[Grabbable] # -- overly generic, CHANGE ME
var grabbed_item_ref = null

func _ready() -> void:
	area_entered.connect( func( area: Area2D):
		if area is Grabbable:
			grabbable_items_near_player.append(area))
	area_exited.connect( func(area):
		if grabbable_items_near_player.has( area):
			grabbable_items_near_player.erase( area ))


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("grab"):
		if grabbed_item_ref:
			grabbed_item_ref.toss( player_ref.last_horizontal_move_input * throw_speed)
			grabbed_item_ref = null
		elif grabbable_items_near_player.size() > 0:
			grabbed_item_ref = get_closest_grabbable()
			if grabbed_item_ref:
				if grabbed_item_ref.can_be_grabbed():
					# -- see ret of grabble.grab
					set_props_from_grabbed_item( grabbed_item_ref.grab( self ))
				else:
					grabbed_item_ref = null


func set_props_from_grabbed_item( data: Dictionary):
	if data.has("weight"):
		var weight_factor = data["weight"]
		assert( weight_factor > 0 and weight_factor <= 1.)
		emit_signal("weighed_down", weight_factor)


func can_grab( grabbable_item : Node2D) -> bool:
	# -- are we facing the way? / is the item in front of us
	var r = grabbable_item.global_position - global_position
	var facing_dir = player_ref.last_horizontal_move_input
	return (facing_dir * r.x >= 0)


# -- will either return a grabbable or none
func get_closest_grabbable():
	# -- reduce down the grabables based on facing the same dir and dist:
	#var item_to_grab = grabbable_items_near_player.reduce( func(prev, curr):
		#var dist_to_curr = global_position.distance_to(curr)
		#return curr if (can_grab(curr) and dist_to_curr
	#)
	var valid_grabbables := grabbable_items_near_player.filter(func(node):
		return can_grab(node)
	)
	# -- easy, quick broad phase check
	if valid_grabbables.size() > 0:
		return valid_grabbables.reduce(func(a, b):
			return a if a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position) else b
		)
