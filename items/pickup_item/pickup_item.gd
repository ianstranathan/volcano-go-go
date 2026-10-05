@tool
extends CharacterBody2D
class_name PickupItem

var spawn_id = -1
signal prediction_picked_up( id, item_enum )

enum ItemType {
	MOBILITY,
	CREATION,
	DESTRUCTION
}

enum State{
	NORMAL,
	SACRIFICED
}
var state := State.NORMAL

# -- backing variables for editor vs non-editor
var _pickup_radius: float = 35.0
var _type: ItemType = ItemType.MOBILITY


# -- Exports
@export var item_lookup: ItemsDb.ItemNames:
	set(value):
		item_lookup = value
		_update_texture()

@export var _texture: Texture2D:
	set(value):
		_texture = value
		if sprite:
			sprite.texture = value
			_update_sprite_scale()
	get:
		return _texture


@export var pickup_radius: float:
	set(value):
		_pickup_radius = value
		_update_collision()
		_update_sprite_scale()
	get:
		return _pickup_radius

@export var sprite: Sprite2D

@export var type: ItemType:
	set(value):
		_type = value
		_update_sprite_color()
	get:
		return _type


func _update_texture():
	_texture = ItemsDb.get_texture(item_lookup)


func _update_collision():
	var area_coll = get_node_or_null("Area2D/CollisionShape2D")
	var coll_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if coll_shape and coll_shape.shape:
		coll_shape.shape.radius = _pickup_radius
	if area_coll and area_coll.shape:
		# -- let's make it just a slightly bigger to favor player
		area_coll.shape.radius = 1.1 * _pickup_radius


func _update_sprite_scale():
	if not sprite or not sprite.texture:
		return
	var tex_size: Vector2 = sprite.texture.get_size()
	sprite.scale = 2.0 * Vector2(_pickup_radius, _pickup_radius) / tex_size

func _update_sprite_color():
	if sprite and sprite.material:
		sprite.material.set_shader_parameter("src_col", color_from_type())
		
# ===============================
# Utilities
# ===============================

func color_from_type() -> Color:
	match _type:
		ItemType.MOBILITY:
			return Color(0.504, 0.214, 1.0, 1.0)
		ItemType.CREATION:
			return Color(0.788, 0.294, 0.0, 1.0)
		ItemType.DESTRUCTION:
			return Color(0.045, 0.27, 0.943, 1.0)
	return Color(0.0, 0.0, 0.0, 1.0)


@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
#@onready var spawn_component: ItemSpawnComponent = $ItemSpawnComponent

func _ready() -> void:
	if Engine.is_editor_hint():
		return # Stop execution here if we are inside the editor
	
	_update_sprite_color()
	$Area2D.body_entered.connect(_on_body_entered)
	#$Area2D.body_exited.connect( _on_body_exited)


var gravity := 980 # -- default, but should steal from player
func set_spawn_kinematics(player_kinematic_data: Array):
	# -- what player is passing in drop
	# [global_position, 
	# max_pickup_item_throw_magnitude * c.aiming_input, 
	# get_g()]
	global_position = player_kinematic_data[0]
	velocity = player_kinematic_data[1]
	gravity = player_kinematic_data[2]

var can_execute_tick := false
func make_kinematic():
	can_execute_tick = true
	
var is_resting: bool = false
var min_bounce_velocity: float = 60.0 # Velocity threshold to stop bouncing
var bounce_decay: float = 0.6

# -- we need to keep a reference to the last player it touched
# -- for when it spawns
var last_peer_that_picked_up: int
func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		var peer_id = body.name.to_int()
		if peer_id == multiplayer.get_unique_id():
			if body.can_pick_up_item() and visible:
				if last_peer_that_picked_up != peer_id:
					last_peer_that_picked_up = peer_id
					#predict_hide()
					prediction_picked_up.emit( spawn_id, item_lookup)
				else:
					last_peer_that_picked_up = -1


func bounce_fn(collision: KinematicCollision2D) -> void:
	if is_resting:
		return
	# -- downward speed is below the threshold => come to a rest
	if velocity.y < min_bounce_velocity and is_on_floor():
		velocity = Vector2.ZERO
		is_resting = true
		return

	# -- DONT WRITE IN GDSCRIPT WHAT CAN BE WRITTEN IN C++
	velocity = velocity.bounce(collision.get_normal()) * bounce_decay

func toggle(b):
	is_resting = !b
	velocity = Vector2.ZERO
	$Sprite2D.visible = b
	$CollisionShape2D.set_deferred("disabled", !b) 
	$Area2D.set_deferred("monitoring", b)


var TERMINAL_FALL_SPEED = 1400


func execute_tick( delta: float ) -> void:
	match state:
		State.NORMAL:
			if !$Sprite2D.visible or is_resting or !can_execute_tick:
				return
			if velocity.y < TERMINAL_FALL_SPEED:
				velocity.y += gravity * delta
			global_position += (velocity * delta) + Vector2(0., (0.5 * delta * delta * gravity))
			var collision_info = move_and_collide(velocity * delta)
			if collision_info:
				bounce_fn(collision_info)
		State.SACRIFICED:
			return


@rpc("call_local", "any_peer", "reliable")
func sacrifice( sacrifical_location: Vector2 ):
	state = State.SACRIFICED
	set_collision_layer_value.call_deferred(7, false)
	var tween = create_tween().set_parallel(false)
	
	# purely visual tween
	tween.tween_property(self, "global_position", sacrifical_location, 0.4)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_BACK)
