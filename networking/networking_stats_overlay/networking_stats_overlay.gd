extends Control

var DEBUG := true
@export var label: Label

func _ready() -> void:
	assert( label != null )
	#GeneralUtils.print_parents_recursive( self )
	if !DEBUG:
		set_physics_process( false )
		visible = false

# -- no need to burn unecessary cycles in process for simple debug information
func _physics_process(_delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		label.text = "Not Connected"
		return
	
	var stats = ""
	stats += "Role: %s\n" % ("Host" if multiplayer.is_server() else "Client")
	stats += "Tick: %d\n" % NetManager.current_tick
	stats += "Uptime: %.2fs\n" % (Time.get_ticks_msec() / 1000.0)
	
	if !multiplayer.is_server():
		# -- diff compared to the last host packet
		# -- TODO assert that tick_multiplier is pure function
		stats += "Tick lead: %d\n" % NetManager.tick_lead
		stats += "Tick Speed: %.2f%%\n" % (NetManager.overlay_tick_multiplier * 100.0)
		stats += "Tick: average_offset - tick_lead: %d\n" % NetManager.tick_error()
		stats += "Clock Synced: %s\n" % str(NetManager.clock_synced)
	
	label.text = stats
