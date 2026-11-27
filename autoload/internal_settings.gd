extends Node

# -- see the bg parallaxign sprites to do some post processing more
# -- performantly
const DOWNSAMPLE_RENDER_SIZE: Vector2 = Vector2(240, 135)

# -- parallaxing system (see parallaxing_depth_config) needs a reference
# -- to derive projection math (copying eyeball of hollow knight)
const MAIN_PLANE_INDEX: int = 4
