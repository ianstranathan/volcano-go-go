extends Node2D

var target_player: Player

@onready var crt_shader = preload("res://levels/oasis/death_tv/death_tv.gdshader")
@onready var noise_shader = preload("res://levels/oasis/death_tv/noise_signal_visual.gdshader")

@export var starting_position_marker: Marker2D

func _ready() -> void:
	global_position = starting_position_marker.global_position
	$TV_target.material.shader = noise_shader

func set_subviewports_game_world(w: World2D):
	$SubViewport/Camera2D.make_current()
	# -- set viewport to use the game world's rendering data
	$SubViewport.world_2d = w
	#$SubViewport.own_world_2d = false
	$SubViewport.transparent_bg = false

func _physics_process(_delta: float) -> void:
	if target_player:
		$SubViewport/Camera2D.global_position = target_player.global_position
