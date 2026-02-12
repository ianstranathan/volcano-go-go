extends RefCounted
class_name PlayerCommand

var move_input: Vector2 = Vector2.ZERO
var jump_pressed := false
var jump_released := false
var aiming_input: Vector2 = Vector2.ZERO
var using_controller := false
var carrying_item := false
var sequence_id := 0

func serialize() -> PackedByteArray:
	# -- 16 bytes
	var spb = StreamPeerBuffer.new()
	spb.put_float(move_input.x)
	spb.put_float(move_input.y)
	spb.put_float(aiming_input.x)
	spb.put_float(aiming_input.y)

	# -- bit shifting and OR-ing to
	# -- but all bools in 1 byte
	var flags := 0
	if jump_pressed:    flags |= 1 << 0
	if jump_released:   flags |= 1 << 1
	if using_controller: flags |= 1 << 2
	if carrying_item:   flags |= 1 << 3
	spb.put_u8(flags)

	# -- 1 byte
	spb.put_u32(sequence_id)
	return spb.data_array
	
	# --> 21 bytes total

static func deserialize(bytes: PackedByteArray) -> PlayerCommand:
	var cmd = PlayerCommand.new()
	var spb = StreamPeerBuffer.new()
	spb.data_array = bytes

	cmd.move_input.x = spb.get_float()
	cmd.move_input.y = spb.get_float()
	cmd.aiming_input.x = spb.get_float()
	cmd.aiming_input.y = spb.get_float()

	# Unpack the booleans using bitwise AND
	var flags = spb.get_u8()
	cmd.jump_pressed    = bool(flags & (1 << 0))
	cmd.jump_released   = bool(flags & (1 << 1))
	cmd.using_controller = bool(flags & (1 << 2))
	cmd.carrying_item   = bool(flags & (1 << 3))

	cmd.sequence_id = spb.get_u32()
	return cmd
