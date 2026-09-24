extends Node

# Treasure type enum matching your 1-8 requirement
enum TreasureType {
	COPPER = 1,
	SILVER = 2,
	GOLD = 3,
	RUBY = 4,
	EMERALD = 5,
	DIAMOND = 6,
	AMETHYST = 7,
	MYTHIC = 8
}
enum TreasureDataSlot{
	VALUE_TEXT,
	COLOR
}
@export var pool_size: int = 50

var _pool: Array[Control] = []
var _available_labels: Array[Control] = []

func _ready() -> void:
	_initialize_pool()

func _initialize_pool() -> void:
	for i in range(pool_size):
		var lbl = _create_label_node()
		lbl.visible = false
		add_child(lbl)
		_pool.append(lbl)
		_available_labels.append(lbl)

func _create_label_node() -> Control:
	var lbl = Label.new()
	lbl.z_index = 100 # Ensure numbers render on top of tiles/sprites
	lbl.add_theme_font_size_override("font_size", 18)
	# Optional outline setup for readability against backgrounds
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	return lbl


func spawn_number(type: int, global_pos: Vector2) -> void:
	#assert(type < 7)
	if _available_labels.is_empty():
		# Dynamic expansion if traffic spikes beyond pool_size
		var extra_lbl = _create_label_node()
		add_child(extra_lbl)
		_pool.append(extra_lbl)
		_available_labels.append(extra_lbl)
	
	var label_node = _available_labels.pop_back() as Label
	if not label_node:
		return

	# Configure data based on treasure type
	var data = _get_treasure_config(type)
	label_node.text = data[ TreasureDataSlot.VALUE_TEXT ]
	label_node.add_theme_color_override("font_color", data[ TreasureDataSlot.COLOR ])
	
	# Set position in 2D space and make visible
	label_node.global_position = global_pos
	label_node.visible = true
	label_node.scale = Vector2.ONE * 0.5
	label_node.modulate.a = 1.0

	# Animate float-up (pixels) and scale-pop
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label_node, "global_position", global_pos + Vector2(0, -45), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label_node, "scale", Vector2.ONE * 1.2, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Fade out near the end of the animation
	var fade_tween = create_tween()
	fade_tween.tween_interval(0.4)
	fade_tween.tween_property(label_node, "modulate:a", 0.0, 0.4)

	# Return to pool upon completion
	tween.chain().tween_callback(func():
		label_node.visible = false
		_available_labels.append(label_node)
	)

const TREASURE_TEXTS: PackedStringArray = [
	"+1", # Fallback for index 0
	"+10", "+25", "+50", "+100", "+250", "+500", "+1000", "+5000"
]

const TREASURE_COLORS: Array[Color] = [
	Color.WHITE,
	Color.PERU, Color.SILVER, Color.GOLD, Color.CRIMSON, 
	Color.SPRING_GREEN, Color.CYAN, Color.PURPLE, Color.HOT_PINK
]
func _get_treasure_config(type: TreasureType) -> Array:
	var idx = clamp(type, 1, TREASURE_TEXTS.size() - 1)
	return [TREASURE_TEXTS[idx], TREASURE_COLORS[idx]]
