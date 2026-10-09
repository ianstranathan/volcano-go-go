extends Control

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


func _ready() -> void:
	$PlayerVisualsManager.visible = false
	race_state_label.visible = false
	death_label.visible = false
	# -- main camera is using a zoom other than 1
	# -- so, we need to match it for the player visual for death framing
	var vp = get_viewport()
	$PlayerVisualsManager.scale = vp.get_camera_2d().zoom
	$PlayerVisualsManager.position = size / 2.0
	vp.size_changed.connect( func():
		$PlayerVisualsManager.scale = vp.get_camera_2d().zoom
		$PlayerVisualsManager.position = size / 2.0)
	

func _physics_process(_delta: float) -> void:
	if player_ref:
		minimap_cam.global_position = player_ref.global_position


func set_minimap_world2d( w: World2D):
	minimap_viewport.world_2d = w
	
	minimap_viewport.set_canvas_cull_mask_bit(0, false)
	minimap_viewport.set_canvas_cull_mask_bit(1, true)
	#debug_check_layer_hierarchy( minimap_viewport, 1)


const starting_state_texts: Array[String] = ["GET READY", "GO!"]

# -- context aware death string?
var died_state_text: String = ""

@onready var race_state_label := $StateTextContainer/MarginContainer/RaceStateLabel
@onready var death_label := $StateTextContainer/MarginContainer/DeathLabel

func on_start_race_signal( count: int):
	race_state_label.text = starting_state_texts[ count ]
	if count == 1:
		# -- await is fine here because it's purely visual the race has already started
		await get_tree().create_timer(1.0).timeout
		race_state_label.visible = false


func show_dead_player():
	$HudMargin.visible = false
	# -- this is saving a static var to just do whatever the last death was
	$PlayerVisualsManager.set_visual_from_death_type()
	$PlayerVisualsManager.visible = true
	death_label.visible = true


func hide_dead_player():
	$HudMargin.visible = true
	$PlayerVisualsManager.visible = false
	death_label.visible = false
