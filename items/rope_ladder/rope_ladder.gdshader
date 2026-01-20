shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

uniform float t: hint_range(0.0, 10.0, 1.);
uniform sampler2D tex: repeat_enable;

// line2d width -> line2D height
// so, UV is mapped to line2d[1] / line2d.width
//
// e.g. line2d is 20px wide
// -> texture is now 20x20 to fit on line
void fragment() {
	vec2 uv = 2. * UV - 1.;
	vec2 _UV = UV - (t-1.);
	float mask = step(0., _UV.x) * (1. - step(0.99, _UV.x));
	COLOR = vec4(texture(tex, UV).xyz, (1. - mask));
	COLOR += vec4(vec3(mask), mask);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
