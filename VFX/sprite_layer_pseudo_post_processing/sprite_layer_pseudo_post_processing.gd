extends Node2D

"""
Player framing sprites inspired by hollow knight silksong

This is responsible for the player vignette draw calls (fake post processing vignette
with second noise version to fake volumetric vignette )

&

Player backlight that uses interleaved gradient noise + gaussian drop off
"""

var player_ref: Player
@onready var viewport = get_viewport()
@onready var camera: Camera2D = viewport.get_camera_2d()
@export var base_vignette_sprite: Sprite2D
@export var backlight_sprite: Sprite2D
@export var noise_vignette_sprite: Sprite2D


func _ready() -> void:
	viewport.size_changed.connect(_scale_to_viewport)
	#_on_viewport_size_changed()
	_scale_to_viewport()


#func _on_viewport_size_changed() -> void:
	#_scale_to_viewport()


func _scale_to_viewport() -> void:
	_viewport_size = get_viewport().size
	_viewport_size = Vector2(float(_viewport_size.x), float(_viewport_size.y))
	var v =  _viewport_size / camera.zoom
	var tex_size = backlight_sprite.texture.get_size()
	var s = v / tex_size
	base_vignette_sprite.scale = s
	noise_vignette_sprite.scale = s
	backlight_sprite.scale = s


func _process(_delta: float) -> void:
	if camera and player_ref:
		global_position = camera.global_position
		# -- material uniforms should change for both (non-instance uniforms)
		# -- i.e. setting just on layer zero (base vignette) changes it for
		# -- layer 1 (noise vignette) as they're using the same materials
		var uv_pos = player_uv_pos()
		base_vignette_sprite.material.set_shader_parameter("player_screen_pos", uv_pos)
		# -- backlight_sprite is using a diff. mat because backlight is blend_add
		backlight_sprite.material.set_shader_parameter("player_screen_pos", uv_pos)


var _viewport_size: Vector2
#func _on_viewport_size_changed() -> void:
	#var viewport_size = viewport.get_visible_rect().size
	#viewport_rect_size = Vector2( viewport_size.x, viewport_size.y)
	## -- Resize sprites to cover the entire viewport (they're all the same icon.svg)
	#var s = viewport_size / base_vignette_sprite.texture.get_size()
	#base_vignette_sprite.scale = s
	#noise_vignette_sprite.scale = s
	#backlight_sprite.scale = s


func player_uv_pos() -> Vector2:
	return (player_ref.global_position - camera.global_position) / (_viewport_size / 2.)
