extends Node2D

@export var players_container: Node2D
var effects_container = {}

@onready var recurring_effects_arr = [
	Effects.EffectNames.LANDING_SMOKE,
	Effects.EffectNames.WALL_JUMP,
	Effects.EffectNames.DIRECTION_CHANGE,
	Effects.EffectNames.JUMPED_OUT_OF_METABALL,
	Effects.EffectNames.SPAWNED
]

func initialize_recurring_player_vfx():
	for player in players_container.get_children():
		var _id = player.name.to_int()
		effects_container[_id] = {}
		
		for effect_enum in recurring_effects_arr:
			var _effect = Effects.effects.get(effect_enum).instantiate()
			# -- we're keeping this stuff on a differnt, higher scope, so
			# -- we can just reuse it
			add_child(_effect)
			effects_container[_id][effect_enum] = _effect


func _ready() -> void:
	Events.world_effect.connect(do_effect)


func do_effect(player_id: int, params: EffectParameters):
	var player_set = effects_container.get(player_id)
	if not player_set: 
		return
	
	var effect = player_set.get(params.type)
	
	if not effect: 
		return
	
	var sprite = effect.get_node_or_null("Sprite2D")
	if not sprite:
		sprite = effect.get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.flip_h = params.flip
	effect.global_position = params.pos
	
	# -- we're mandating that all effects have a vfx component
	assert(effect.get_node("VfxEffectComponent"))
	effect.get_node("VfxEffectComponent").start.call(params)
