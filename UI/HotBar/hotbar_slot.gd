#Keeping this as self contained as possible. should just update the visual component of the slot based on
#info passed in through set_slot_display. clear slot by passing a null texture. is that a good idea? probably not

extends Control
class_name HotbarSlot

signal cool_down_finished

@onready var selected_outline: Control = $SelectedOutline
@onready var icon: TextureRect = $MarginContainer/Icon
@onready var timer: TickTimer = TickTimer.new(1., true)

func _ready() -> void:
	$Backing.material.set_shader_parameter("available", 1.);
	timer.timeout.connect( on_timer_timeout )
	selected_outline.visible = false


func set_slot_display(new_icon: Texture2D,
					  cool_down_time: float,
					  is_selected: bool,
					 _selected_outline_visible=false) -> void:
	if new_icon:
		icon.texture = new_icon
		icon.visible = true
		timer.wait_time = cool_down_time
		$Backing.material.set_shader_parameter("selected", 1. if is_selected else 0.)
	else:
		icon.visible = false
		$Backing.material.set_shader_parameter("selected", 0.)


func on_item_used():
	if timer.is_stopped():
		timer.start()
		$Backing.material.set_shader_parameter("selected", 0.)
		$Backing.material.set_shader_parameter("recharging", 1.)
		$MarginContainer/Icon.material.set_shader_parameter("available", 0.)


# -- as usual visual can be decoupled from ticking
func _physics_process(delta: float) -> void:
	if !timer.is_stopped():
		# -- just simple normalized time from timer
		$Backing.material.set_shader_parameter("progress", 1. - (timer.time_left / timer.wait_time))


func on_timer_timeout():
	cool_down_finished.emit() # -- ui hotbar tells it if it's still selected
	# -- otherwise we could have visually 2 items selected
	
	$Backing.material.set_shader_parameter("recharging", 0.)
	$Backing.material.set_shader_parameter("progress", 1.);
	$MarginContainer/Icon.material.set_shader_parameter("available", 1.);


func set_selection_on_mat_callback(b: bool):
	$Backing.material.set_shader_parameter("selected", 1. if b else 0.)
