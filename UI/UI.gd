extends Control

signal death_fault_selection_made

@export var DEBUG: bool = true # -- networking stats overlay uses this


var game_ref
@onready var minimap_cam: Camera2D = $HudMargin/HudLayout/BottomArea/BottomRight/SubViewportContainer/SubViewport/Camera2D
var player_ref: Player

@onready var hotbar_ui: HotbarUi = $HudMargin/HudLayout/BottomArea/BottomCenter/CenterContainer/HotbarUi

@export var track: TextureRect
@export var leader_icon_bar: Control

@export var minimap_viewport: SubViewport


# -- TODO probably don't do this every tick to save some cycles as an ez heuristic
func execute_tick( _delta: float ):
	
	if game_ref:
		var ordered_players = game_ref.ordered_players_by_height()

		# -- CHANGE ME TODO NOTE FIXME
		track.update_track(ordered_players.map( func(c): return c.global_position),
						   ordered_players.map( func(c): 
							return game_ref.player_data_dict[c.name.to_int()].turban_color))
		
		leader_icon_bar.refresh_leaderboard( 
			ordered_players.map( func(c): return c.name.to_int()),
			game_ref.player_data_dict)

# -- TODO
@onready var skull_texture_height = 80;

func _ready() -> void:
	$StateTextContainer.visible = true
	race_state_label.visible = false
	
	$DeathRadialMenu.choice_made.connect( func():
		$DeathRadialMenu.hide()
		death_fault_selection_made.emit()
		)
	
	$DeathRadialMenu.visible = false
	$PlayerVisualsManager.visible = false
	
	$skull.visible = false
	# -- main camera is using a zoom other than 1
	# -- so, we need to match it for the player visual for death framing
	
	# -- TODO put this somewhere dude
	var vp = get_viewport()
	var s = vp.get_camera_2d().zoom
	$PlayerVisualsManager.scale = s
	$skull.scale = $skull.scale * s
	$PlayerVisualsManager.position = size / 2.0
	$skull.position = Vector2(size.x / 2., $skull.position.y)
	vp.size_changed.connect( func():
		var _s = vp.get_camera_2d().zoom
		$skull.scale = $skull.scale * s
		$skull.position = Vector2(size.x / 2., $skull.position.y)
		$PlayerVisualsManager.scale = _s
		$PlayerVisualsManager.position = size / 2.0)
	

func _physics_process(_delta: float) -> void:
	if player_ref:
		minimap_cam.global_position = player_ref.global_position


func set_minimap_world2d( w: World2D):
	minimap_viewport.world_2d = w
	
	minimap_viewport.set_canvas_cull_mask_bit(0, false)
	minimap_viewport.set_canvas_cull_mask_bit(1, true)
	#debug_check_layer_hierarchy( minimap_viewport, 1)


@onready var race_state_label := $StateTextContainer/MarginContainer/RaceStateLabel
func display_race_state_message( s: String, toggle_off=false):
	race_state_label.text = s
	race_state_label.visible = true
	if toggle_off:
		await get_tree().create_timer(1.0).timeout
		race_state_label.visible = false



func show_dead_player():
	$HudMargin.visible = false
	# -- this is saving a static var to just do whatever the last death was
	$PlayerVisualsManager.set_visual_from_death_type()
	$PlayerVisualsManager.visible = true
	$skull.visible = true
	$DeathRadialMenu.show()

func hide_dead_player():
	$HudMargin.visible = true
	$PlayerVisualsManager.visible = false
	$skull.visible = false
	
#func show_death_radial_choice_menu():
	#$DeathRadialMenu.show()
