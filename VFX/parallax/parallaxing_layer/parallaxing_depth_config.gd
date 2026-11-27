
@tool
class_name ParallaxDepthConfig
extends Resource

"""
Saturation decreases.                               
Contrast decreases.                                 
Dark shadows become lighter.                        
Colors shift toward the atmosphere's dominant color.
Fine details become less prominent.                 

The further away something is, the slower it moves relative to the camera:
0.75 ^ d

"""

# ------------------------------------------------------------------------------
#d<0: Background.
#d=0: Main playing plane.
#d>0: Foreground.
# -- NOTE plane_index defined on parent
#var depth := plane_index - depth_config.main_plane_index
func get_depth(index: int) -> int:
	return index - InternalSettings.MAIN_PLANE_INDEX

# ------------------------------------------------------------------------------

# -- default ratio is 0.75
#Background moves faster relative to the camera's parallax reference.
#Main plane moves at 1.0.
#Foreground moves slower.
#-- applies to Parallax2D.scroll_scale
@export_group("Movement")
@export_range(0.01, 1.0, 0.01)
var horizontal_movement_ratio: float = 0.75:
	set(value):
		if is_equal_approx(horizontal_movement_ratio, value):
			return
		horizontal_movement_ratio = value
		emit_changed()

@export_range(0.01, 1.0, 0.01)
var vertical_movement_ratio: float = 0.90:
	set(value):
		if is_equal_approx(vertical_movement_ratio, value):
			return
		vertical_movement_ratio = value
		emit_changed()

func get_movement_factor(index: int) -> Vector2:
	return Vector2( pow(horizontal_movement_ratio, -get_depth(index)),
					pow(vertical_movement_ratio, -get_depth(index)))

# ------------------------------------------------------------------------------

# -- default ratio is 1.1
#Background gets smaller.
#Main plane remains at 1.0.
#Foreground gets larger.
@export_group("Scale")
@export_range(1.0, 2.0, 0.01)
var scale_ratio: float = 1.10:
	set(value):
		if is_equal_approx(scale_ratio, value):
			return
		scale_ratio = value
		emit_changed()

func get_scale_factor(index: int) -> float:
	return pow(scale_ratio, get_depth(index))

# ------------------------------------------------------------------------------

@export_group("Brightness")
@export_range(0.0, 1.0, 0.01)
var background_brightness_falloff: float = 0.08:
	set(value):
		if is_equal_approx(background_brightness_falloff, value):
			return
		background_brightness_falloff = value
		emit_changed()

@export_range(0.0, 1.0, 0.01)
var min_brightness: float = 0.60:
	set(value):
		if is_equal_approx(min_brightness, value):
			return
		min_brightness = value
		emit_changed()

func get_atmospheric_fade( index: int):
	var ret = 1.0 - background_brightness_falloff * max(0, -get_depth(index))
	return max(ret, min_brightness)

# ---------------------------------------------------------- atmospheric effects
# -- distant things should become less contrasted, saturated and eventually blurred

# -- contrast
# -- distant scenery becomes less contrasted
@export_group("Contrast")
@export_range(0.0, 1.0, 0.01)
var contrast_falloff: float = 0.10:
	set(value):
		if is_equal_approx(contrast_falloff, value):
			return
		contrast_falloff = value
		emit_changed()

@export_range(0.0, 1.0, 0.01)
var min_contrast: float = 0.50:
	set(value):
		if is_equal_approx(min_contrast, value):
			return
		min_contrast = value
		emit_changed()

func get_contrast(index:int) -> float:
	return max( min_contrast, 1.0 - contrast_falloff * max(0, -get_depth(index)))

# ------------------------------------------------------------------------------

# -- contrast
# -- distant scenery becomes less saturated
@export_group("Saturation")

@export_range(0.0, 1.0, 0.01)
var saturation_falloff: float = 0.12:
	set(value):
		if is_equal_approx(saturation_falloff, value):
			return
		saturation_falloff = value
		emit_changed()

@export_range(0.0, 1.0, 0.01)
var min_saturation: float = 0.30:
	set(value):
		if is_equal_approx(min_saturation, value):
			return
		min_saturation = value
		emit_changed()

func get_saturation(index:int) -> float:
	return max(min_saturation,1.0 - saturation_falloff * max(0, -get_depth(index)))

# ------------------------------------------------------------------------------

@export_group("Blur")
@export_range(0.0, 10.0, 0.1)
var blur_strength: float = 1.5:
	set(value):
		if is_equal_approx(blur_strength, value):
			return
		blur_strength = value
		emit_changed()

@export_range(0.1, 3.0, 0.1)
var blur_exponent: float = 1.2:
	set(value):
		if is_equal_approx(blur_exponent, value):
			return
		blur_exponent = value
		emit_changed()

func get_blur(index:int):
	return blur_strength * pow(max(0, -get_depth(index)), blur_exponent)

# ------------------------------------------------------------------------------

@export_group("Opacity")
@export_range(0.0, 1.0, 0.01)
var opacity_falloff: float = 0.0:
	set(value):
		if is_equal_approx(opacity_falloff, value):
			return
		opacity_falloff = value
		emit_changed()

@export_range(0.0, 1.0, 0.01)
var min_opacity: float = 0.5:
	set(value):
		if is_equal_approx(min_opacity, value):
			return
		min_opacity = value
		emit_changed()

func get_opacity( index: int ):
	return max(min_opacity,1.0 - (opacity_falloff* max(0, -get_depth(index))))

#-------------------------------------------------------------------------------

# -- Atmospheric fog / tint
# -- distant objects blend toward an atmospheric color.
@export_group("Atmosphere")
@export var fog_color: Color = Color(0.65, 0.75, 0.85):
	set(value):
		if fog_color.is_equal_approx(value):
			return
		fog_color = value
		emit_changed()

@export_range(0.0, 2.0, 0.01)
var fog_strength: float = 0.15:
	set(value):
		if is_equal_approx(fog_strength, value):
			return
		fog_strength = value
		emit_changed()

func get_atmospheric_fog(index:int) -> float:
	# -- returns blend amount between the original sprite color and the layer's chosen atmospheric tint
	return 1.0 - exp(-fog_strength * max(0, -get_depth(index)))
