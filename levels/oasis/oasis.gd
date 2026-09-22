extends Node2D


signal portal_entered( body, pos )

var players_within_reveal_threshold : Array[CharacterBody2D]
@export var portal: Node2D
@onready var portal_area: Area2D = portal.get_node("Area2D")

func _ready() -> void:
	portal_area.body_entered.connect( func(body):
			portal_entered.emit(body,
			portal_area.global_position))
	portal_area.body_exited.connect( func(body):
		if body is Player:
			body.exited_portal())
	# -- we initialize the visuals to be on
	# -- and the area to be off
	# -- we're starting in the oasis
	#$Area2D.monitorable = false
	#$Area2D.monitoring = false
	#
	#$Area2D.body_entered.connect( func(body):
		#if body is Player:
			#players_within_reveal_threshold.append( body ))
#
#
## -- we can totally decouple this from networking stuff as usual
#func _physics_process(_delta: float) -> void:
	#if !players_within_reveal_threshold.is_empty():
		#var d_sqrd = INF
		#for player in players_within_reveal_threshold:
			#var _d_sqrd = global_position.distance_squared_to( player.global_position ) 
			#if _d_sqrd < d_sqrd:
				#d_sqrd = _d_sqrd
		#noramlize_reveal_param( d_sqrd )


#@onready var rad = $Area2D/CollisionShape2D.shape.radius
#@onready var rad_sqrd = rad * rad
#func noramlize_reveal_param( d: float) -> void:
	#$Sprite2D.material.set_shader_parameter( "amt", 
		#1. - pow((d / rad_sqrd), 2.0))
		
