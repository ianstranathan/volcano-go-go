extends Node2D

"""
offloading some stuff from game to here
"""
@onready var children_who_need_player_ref: Array = [$SpriteLayerPseudoPostProcessing]
# -- world should tell allocate dependencies @ ready
var player_ref: Player:
	set(p):
		assert( children_who_need_player_ref.size() > 0)
		for c in children_who_need_player_ref:
			c.player_ref = p
