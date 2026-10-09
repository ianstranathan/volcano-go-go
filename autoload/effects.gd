extends Node

enum EffectNames {
	LANDING_SMOKE,
	DIRECTION_CHANGE,
	WALL_JUMP,
	JUMPED_OUT_OF_METABALL,
	SPAWNED
}

var effects = {
	EffectNames.LANDING_SMOKE: preload("res://VFX/player effects/landing_smoke_sprite/landing_smoke_sprite.tscn"),
	EffectNames.DIRECTION_CHANGE: preload("res://VFX/player effects/direction_change/direction_change_1.tscn"),
	EffectNames.WALL_JUMP: preload("res://VFX/player effects/wall_jump_sprite/wall_jump_sprite.tscn"),
	EffectNames.JUMPED_OUT_OF_METABALL: preload("res://VFX/player effects/metaball_splash/metaball_jump_out_vfx.tscn"),
	EffectNames.SPAWNED: preload("res://VFX/poof_particles/darren_poof_effect.tscn")
}
