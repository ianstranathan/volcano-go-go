extends RefCounted
class_name PlayerCommand


var move_input: Vector2 = Vector2.ZERO
var aiming_input: Vector2 = Vector2.ZERO
#var impulse: Vector2 = Vector2.ZERO
#var collided_id := -1
var jump_pressed     := false
var jump_released    := false
var using_controller := false
var grab_pressed    := false
var item_use_pressed := false
var item_use_held    := false
var sprint_held      := false
var item_dropped     := false
var crouch_pressed   := false
var sword_swung      := false

var tick := -1


static func serialize_list_of_commands(commands: Array[PlayerCommand]) -> PackedByteArray:
	var spb = StreamPeerBuffer.new()
	spb.put_u8(commands.size())

	for cmd in commands:
		# -- bit mask for inputs
		# -- bitwise or to fill up le bit
		var flags := 0
		if cmd.jump_pressed:     flags |= 1 << 0
		if cmd.jump_released:    flags |= 1 << 1
		if cmd.using_controller: flags |= 1 << 2
		if cmd.grab_pressed:    flags |= 1 << 3
		if cmd.item_use_pressed: flags |= 1 << 4
		if cmd.item_use_held:    flags |= 1 << 5
		if cmd.sprint_held:      flags |= 1 << 6
		if cmd.item_dropped:     flags |= 1 << 7
		if cmd.crouch_pressed:   flags |= 1 << 8
		if cmd.sword_swung:      flags |= 1 << 9
		#var has_collision = cmd.collided_id > 0
		#if has_collision:
			#flags |= 1 << 9

		spb.put_float(cmd.move_input.x)
		spb.put_float(cmd.move_input.y)
		spb.put_float(cmd.aiming_input.x)
		spb.put_float(cmd.aiming_input.y)
		spb.put_u16(flags)
		spb.put_u32(cmd.tick)
		
		# -- int, float, float is like 20 bytes, so save some bandwith man
		#if has_collision:
			#spb.put_u32(cmd.collided_id)
			#spb.put_float(cmd.impulse.x)
			#spb.put_float(cmd.impulse.y)

	return spb.data_array

static func deserialize_list_of_commands(byte_arr: PackedByteArray) -> Array[PlayerCommand]:
	var cmds: Array[PlayerCommand] = []
	if byte_arr.size() < 1: 
		return cmds
	var spb = StreamPeerBuffer.new()
	spb.data_array = byte_arr

	# -- 
	var count = spb.get_u8()
	# -- 
	for i in range(count):
		var cmd = PlayerCommand.new()
		
		cmd.move_input.x = spb.get_float()
		cmd.move_input.y = spb.get_float()
		cmd.aiming_input.x = spb.get_float()
		cmd.aiming_input.y = spb.get_float()
		
		
		var flags = spb.get_u16()
		cmd.tick = spb.get_u32()

		# -- bitshift over and superposition the bit (bitwise and)
		cmd.jump_pressed     = bool(flags & (1 << 0))
		cmd.jump_released    = bool(flags & (1 << 1))
		cmd.using_controller = bool(flags & (1 << 2))
		cmd.grab_pressed    = bool(flags & (1 << 3))
		cmd.item_use_pressed = bool(flags & (1 << 4))
		cmd.item_use_held    = bool(flags & (1 << 5))
		cmd.sprint_held      = bool(flags & (1 << 6))
		cmd.item_dropped     = bool(flags & (1 << 7))
		cmd.crouch_pressed   = bool(flags & (1 << 8))
		cmd.sword_swung      = bool(flags & (1 << 9))
		#if bool(flags & (1 << 9)):
			#cmd.collided_id = spb.get_u32()
			#cmd.impulse.x = spb.get_float()
			#cmd.impulse.y = spb.get_float()
		#else:
			## No collision data followed; reset to defaults
			#cmd.collided_id = -1
			#cmd.impulse = Vector2.ZERO

		cmds.append(cmd)

	return cmds

func print_cmd() -> void:
	print("--- Command State ---")
	print("tick: ", tick)
	#print("move_input: ", move_input)
	#print("aiming_input: ", aiming_input)
	#print("jump_pressed: ", jump_pressed)
	#print("jump_released: ", jump_released)
	#print("using_controller: ", using_controller)
	#print("grab_pressed: ", grab_pressed)
	#print("item_use_pressed: ", item_use_pressed)
	#print("item_use_held: ", item_use_held)
	#print("sprint_held: ", sprint_held)
	#print("item_dropped: ", item_dropped)
	#print("crouch_pressed: ", crouch_pressed)
	#print("sword_swung: ", sword_swung)
