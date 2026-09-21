#Keeping this as self contained as possible. should just update the visual component of the slot based on
#info passed in through set_slot_display. clear slot by passing a null texture. is that a good idea? probably not

extends Control
class_name HotbarSlot


@onready var selected_outline: Control = $SelectedOutline
@onready var icon: TextureRect = $MarginContainer/Icon
@onready var timer: TickTimer = TickTimer.new(1., true)

func _ready() -> void:
	$Backing.material.set_shader_parameter("available", 1.);
	timer.timeout.connect( on_timer_timeout )
	selected_outline.visible = false

#for i in range(standard_slots.size()):
		#standard_slots[i].set_slot_display(
			#ItemsDb.get_texture(item_db_enums[i]) if item_db_enums[i] != -1 else null,
			#item_db_cooldowns[i],
			#i == selected_index)
func set_slot_display(new_icon: Texture2D,
					  cool_down_time: float,
					  is_selected: bool,
					 _selected_outline_visible=false) -> void:
	if new_icon:
		icon.texture = new_icon
		icon.visible = true
		timer.wait_time = cool_down_time
		#selected_outline.visible = is_selected
		print(is_selected)
		$Backing.material.set_shader_parameter("selected", 1. if is_selected else 0.)
	else:
		icon.visible = false
		#selected_outline.visible = false
		$Backing.material.set_shader_parameter("selected", 0.)
	
	# -- picking up first item (when inventory is empty, i.e. array of enums
	# -- passed size == 1) we want to indicate that you're auto picking up
	# -- this seemed easier than adding more signals and connections to item_manager
	#if selected_outline_visible:
		#selected_outline.visible = true

func on_item_used():
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
	#if timer.is_stopped():
	$Backing.material.set_shader_parameter("selected", 1.)
	$Backing.material.set_shader_parameter("recharging", 0.)
	$Backing.material.set_shader_parameter("progress", 1.);
	$MarginContainer/Icon.material.set_shader_parameter("available", 1.);
